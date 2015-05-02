module ddbus.router;

import ddbus.thin;
import ddbus.c_lib;
import std.string;
import std.typecons;
import core.memory;

struct MessagePattern {
  string path;
  string iface;
  string method;
  string sender;

  this(Message msg) {
    path = msg.path();
    iface = msg.iface();
    method = msg.member();
    if(msg.type()==MessageType.Signal) {
      sender = msg.sender();
    } else {
      sender = null;
    }
  }

  this(string path, string iface, string method, string sender = null) {
    this.path = path;
    this.iface = iface;
    this.method = method;
    this.sender = sender;
  }

  size_t toHash() const @safe nothrow {
    size_t hash = 0;
    auto stringHash = &(typeid(path).getHash);
    hash += stringHash(&sender);
    hash += stringHash(&path);
    hash += stringHash(&iface);
    hash += stringHash(&method);
    return hash;
  }

  bool opEquals(ref const this s) const @safe pure nothrow {
    return (path == s.path) && (iface == s.iface) && (method == s.method) && (sender == s.sender);
  }
}

class MessageRouter {
  alias HandlerFunc = void delegate(Message call, Connection conn);
  HandlerFunc[MessagePattern] callTable;

  bool handle(Message msg, Connection conn) {
    MessageType type = msg.type();
    if(type != MessageType.Call && type != MessageType.Signal)
      return false;
    auto pattern = MessagePattern(msg);
    HandlerFunc* handler = (pattern in callTable);
    if(handler is null) return false;
    (*handler)(msg,conn);
    return true;
  }

  void setHandler(Ret, Args...)(MessagePattern patt, Ret delegate(Args) handler) {
    void handlerWrapper(Message call, Connection conn) {
      Tuple!Args args = call.readTuple!(Tuple!Args)();
      Ret ret = handler(args.expand);
      auto retMsg = call.createReturn();
      static if(!is(Ret == void)) {
        retMsg.build(ret);
      }
      conn.send(retMsg);
    }
    callTable[patt] = &handlerWrapper;
  }
}

extern(C) private DBusHandlerResult filterFunc(DBusConnection *dConn, DBusMessage *dMsg, void *routerP) {
  MessageRouter router = cast(MessageRouter)routerP;
  dbus_message_ref(dMsg);
  Message msg = Message(dMsg);
  dbus_connection_ref(dConn);
  Connection conn = Connection(dConn);
  bool handled = router.handle(msg, conn);
  if(handled) {
    return DBusHandlerResult.DBUS_HANDLER_RESULT_HANDLED;
  } else {
    return DBusHandlerResult.DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }
}

extern(C) private void unrootUserData(void *userdata) {
  GC.removeRoot(userdata);
}

void registerRouter(Connection conn, MessageRouter router) {
  void *routerP = cast(void*)router;
  GC.addRoot(routerP);
  dbus_connection_add_filter(conn.conn, &filterFunc, routerP, &unrootUserData);
}

unittest {
  import dunit.toolkit;
  auto msg = Message("org.example.test", "/test","org.example.testing","testMethod");
  auto patt= new MessagePattern(msg);
  patt.assertEqual(patt);
  patt.sender.assertNull();
  patt.path.assertEqual("/test");
}

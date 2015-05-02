module ddbus.router;

import ddbus.thin;
import ddbus.c_lib;
import ddbus.util;
import std.string;
import std.typecons;
import core.memory;
import std.array;
import std.algorithm;

struct MessagePattern {
  string path;
  string iface;
  string method;
  bool signal;

  this(Message msg) {
    path = msg.path();
    iface = msg.iface();
    method = msg.member();
    signal = (msg.type() == MessageType.Signal);
  }

  this(string path, string iface, string method, bool signal = false) {
    this.path = path;
    this.iface = iface;
    this.method = method;
    this.signal = signal;
  }

  size_t toHash() const @safe nothrow {
    size_t hash = 0;
    auto stringHash = &(typeid(path).getHash);
    hash += stringHash(&path);
    hash += stringHash(&iface);
    hash += stringHash(&method);
    hash += (signal?1:0);
    return hash;
  }

  bool opEquals(ref const this s) const @safe pure nothrow {
    return (path == s.path) && (iface == s.iface) && (method == s.method) && (signal == s.signal);
  }
}

struct MessageHandler {
  alias HandlerFunc = void delegate(Message call, Connection conn);
  HandlerFunc func;
  string[] argSig;
  string[] retSig;
}

class MessageRouter {
  MessageHandler[MessagePattern] callTable;

  bool handle(Message msg, Connection conn) {
    MessageType type = msg.type();
    if(type != MessageType.Call && type != MessageType.Signal)
      return false;
    auto pattern = MessagePattern(msg);
    // import std.stdio; debug writeln("Handling ", pattern);
    MessageHandler* handler = (pattern in callTable);
    if(handler is null) return false;

    // Check for matching argument types
    version(DDBusNoChecking) {
      
    } else {
      if(!equal(join(handler.argSig), msg.signature())) {
        return false;
      }
    }

    handler.func(msg,conn);
    return true;
  }

  void setHandler(Ret, Args...)(MessagePattern patt, Ret delegate(Args) handler) {
    void handlerWrapper(Message call, Connection conn) {
      Tuple!Args args = call.readTuple!(Tuple!Args)();
      auto retMsg = call.createReturn();
      static if(!is(Ret == void)) {
        Ret ret = handler(args.expand);
        retMsg.build(ret);
      } else {
        handler(args.expand);
      }
      if(!patt.signal)
        conn.send(retMsg);
    }
    static string[] args = typeSigArr!Args;
    static if(is(Ret==void)) {
      static string[] ret = [];
    } else {
      static string[] ret = [typeSig!Ret];
    }
    MessageHandler handleStruct = {func: &handlerWrapper, argSig: args, retSig: ret};
    callTable[patt] = handleStruct;
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
  patt.signal.assertFalse();
  patt.path.assertEqual("/test");
}

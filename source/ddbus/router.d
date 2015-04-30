module ddbus.router;

import ddbus.thin;
import std.string;
import std.typecons;

struct MessagePattern {
  string sender;
  string path;
  string iface;
  string method;

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
  Connection conn;
  HandlerFunc[MessagePattern] callTable;

  this(Connection conn) {
    this.conn = conn;
  }

  bool handle(Message msg) {
    MessageType type = msg.type();
    if(type != MessageType.Call && type != MessageType.Signal)
      return false;
    auto pattern = MessagePattern(msg);
    HandlerFunc* handler = (pattern in callTable);
    if(handler is null) return false;
    (*handler)(msg,conn);
    return true;
  }

  void setHandler(Ret, Args...)(MessagePattern patt, Connection conn, Ret delegate(Args) handler) {
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

unittest {
  import dunit.toolkit;
  auto msg = new Message("org.example.test", "/test","org.example.testing","testMethod");
  auto patt= new MessagePattern(msg);
  patt.assertEqual(patt);
  patt.sender.assertNull();
  patt.path.assertEqual("/test");
}

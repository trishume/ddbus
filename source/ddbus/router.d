module ddbus.router;

import ddbus.thin;
import ddbus.c_lib;
import ddbus.util;
import std.string;
import std.typecons;
import core.memory;
import std.array;
import std.algorithm;
import std.format;

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
    hash += (signal ? 1 : 0);
    return hash;
  }

  bool opEquals(ref const typeof(this) s) const @safe pure nothrow {
    return (path == s.path) && (iface == s.iface) && (method == s.method) && (signal == s.signal);
  }
}

unittest {
  import dunit.toolkit;

  auto msg = Message("org.example.test", "/test", "org.example.testing", "testMethod");
  auto patt = new MessagePattern(msg);
  patt.assertEqual(patt);
  patt.signal.assertFalse();
  patt.path.assertEqual("/test");
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
    if (type != MessageType.Call && type != MessageType.Signal) {
      return false;
    }

    auto pattern = MessagePattern(msg);
    // import std.stdio; debug writeln("Handling ", pattern);

    if (pattern.iface == "org.freedesktop.DBus.Introspectable"
        && pattern.method == "Introspect" && !pattern.signal) {
      handleIntrospect(pattern.path, msg, conn);
      return true;
    }

    MessageHandler* handler = (pattern in callTable);
    if (handler is null) {
      return false;
    }

    // Check for matching argument types
    version (DDBusNoChecking) {

    } else {
      if (!equal(join(handler.argSig), msg.signature())) {
        return false;
      }
    }

    handler.func(msg, conn);
    return true;
  }

  void setHandler(Ret, Args...)(MessagePattern patt, Ret delegate(Args) handler) {
    void handlerWrapper(Message call, Connection conn) {
      Tuple!Args args = call.readTuple!(Tuple!Args)();
      auto retMsg = call.createReturn();

      static if (!is(Ret == void)) {
        Ret ret = handler(args.expand);
        static if (is(Ret == Tuple!T, T...)) {
          retMsg.build!T(ret.expand);
        } else {
          retMsg.build(ret);
        }
      } else {
        handler(args.expand);
      }

      if (!patt.signal) {
        conn.send(retMsg);
      }
    }

    static string[] args = typeSigArr!Args;

    static if (is(Ret == void)) {
      static string[] ret = [];
    } else {
      static string[] ret = typeSigReturn!Ret;
    }

    // dfmt off
    MessageHandler handleStruct = {
      func: &handlerWrapper,
      argSig: args,
      retSig: ret
    };
    // dfmt on

    callTable[patt] = handleStruct;
  }

  static string introspectHeader = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node name="%s">`;

  string introspectXML(string path) {
    // dfmt off
    auto methods = callTable
      .byKey()
      .filter!(a => (a.path == path) && !a.signal)
      .array
      .sort!((a, b) => a.iface < b.iface)();
    // dfmt on

    auto ifaces = methods.groupBy();
    auto app = appender!string;
    formattedWrite(app, introspectHeader, path);
    foreach (iface; ifaces) {
      formattedWrite(app, `<interface name="%s">`, iface.front.iface);

      foreach (methodPatt; iface.array()) {
        formattedWrite(app, `<method name="%s">`, methodPatt.method);
        auto handler = callTable[methodPatt];

        foreach (arg; handler.argSig) {
          formattedWrite(app, `<arg type="%s" direction="in"/>`, arg);
        }

        foreach (arg; handler.retSig) {
          formattedWrite(app, `<arg type="%s" direction="out"/>`, arg);
        }

        app.put("</method>");
      }

      app.put("</interface>");
    }

    string childPath = path;
    if (!childPath.endsWith("/")) {
      childPath ~= "/";
    }

    auto children = callTable.byKey()
      .filter!(a => (a.path.startsWith(childPath)) && !a.signal)().map!(
          (s) => s.path.chompPrefix(childPath)).map!((s) => s.splitter('/')
          .front).array().sort().uniq();

    foreach (child; children) {
      formattedWrite(app, `<node name="%s"/>`, child);
    }

    app.put("</node>");
    return app.data;
  }

  void handleIntrospect(string path, Message call, Connection conn) {
    auto retMsg = call.createReturn();
    retMsg.build(introspectXML(path));
    conn.sendBlocking(retMsg);
  }
}

extern (C) private DBusHandlerResult filterFunc(DBusConnection* dConn,
    DBusMessage* dMsg, void* routerP) {
  MessageRouter router = cast(MessageRouter) routerP;
  dbus_message_ref(dMsg);
  Message msg = Message(dMsg);
  dbus_connection_ref(dConn);
  Connection conn = Connection(dConn);
  bool handled = router.handle(msg, conn);

  if (handled) {
    return DBusHandlerResult.DBUS_HANDLER_RESULT_HANDLED;
  } else {
    return DBusHandlerResult.DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
  }
}

extern (C) private void unrootUserData(void* userdata) {
  GC.removeRoot(userdata);
}

void registerRouter(Connection conn, MessageRouter router) {
  void* routerP = cast(void*) router;
  GC.addRoot(routerP);
  dbus_connection_add_filter(conn.conn, &filterFunc, routerP, &unrootUserData);
}

unittest {
  import dunit.toolkit;

  import std.typecons : BitFlags;
  import std.variant : Algebraic;

  auto router = new MessageRouter();
  // set up test messages
  MessagePattern patt = MessagePattern("/root", "ca.thume.test", "test");
  router.setHandler!(int, int)(patt, (int p) { return 6; });
  patt = MessagePattern("/root", "ca.thume.tester", "lolwut");
  router.setHandler!(void, int, string)(patt, (int p, string p2) {  });
  patt = MessagePattern("/root/wat", "ca.thume.tester", "lolwut");
  router.setHandler!(int, int)(patt, (int p) { return 6; });
  patt = MessagePattern("/root/bar", "ca.thume.tester", "lolwut");
  router.setHandler!(Variant!DBusAny, int)(patt, (int p) {
    return variant(DBusAny(p));
  });
  patt = MessagePattern("/root/foo", "ca.thume.tester", "lolwut");
  router.setHandler!(Tuple!(string, string, int), int,
      Variant!DBusAny)(patt, (int p, Variant!DBusAny any) {
    Tuple!(string, string, int) ret;
    ret[0] = "a";
    ret[1] = "b";
    ret[2] = p;
    return ret;
  });
  patt = MessagePattern("/troll", "ca.thume.tester", "wow");
  router.setHandler!(void)(patt, { return; });

  patt = MessagePattern("/root/fancy", "ca.thume.tester", "crazyTest");
  enum F : ushort {
    a = 1,
    b = 8,
    c = 16
  }

  struct S {
    byte b;
    ulong ul;
    F f;
  }

  router.setHandler!(int)(patt, (Algebraic!(ushort, BitFlags!F, S) v) {
    if (v.type is typeid(ushort) || v.type is typeid(BitFlags!F)) {
      return v.coerce!int;
    } else if (v.type is typeid(S)) {
      auto s = v.get!S;
      final switch (s.f) {
      case F.a:
        return s.b;
      case F.b:
        return cast(int) s.ul;
      case F.c:
        return cast(int) s.ul + s.b;
      }
    }

    assert(false);
  });

  static assert(!__traits(compiles, {
      patt = MessagePattern("/root/bar", "ca.thume.tester", "lolwut");
      router.setHandler!(void, DBusAny)(patt, (DBusAny wrongUsage) { return; });
    }));

  // TODO: these tests rely on nondeterministic hash map ordering
  static string introspectResult = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node name="/root"><interface name="ca.thume.test"><method name="test"><arg type="i" direction="in"/><arg type="i" direction="out"/></method></interface><interface name="ca.thume.tester"><method name="lolwut"><arg type="i" direction="in"/><arg type="s" direction="in"/></method></interface><node name="bar"/><node name="fancy"/><node name="foo"/><node name="wat"/></node>`;
  router.introspectXML("/root").assertEqual(introspectResult);
  static string introspectResult2 = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node name="/root/foo"><interface name="ca.thume.tester"><method name="lolwut"><arg type="i" direction="in"/><arg type="v" direction="in"/><arg type="s" direction="out"/><arg type="s" direction="out"/><arg type="i" direction="out"/></method></interface></node>`;
  router.introspectXML("/root/foo").assertEqual(introspectResult2);
  static string introspectResult3 = `<!DOCTYPE node PUBLIC "-//freedesktop//DTD D-BUS Object Introspection 1.0//EN" "http://www.freedesktop.org/standards/dbus/1.0/introspect.dtd">
<node name="/root/fancy"><interface name="ca.thume.tester"><method name="crazyTest"><arg type="v" direction="in"/><arg type="i" direction="out"/></method></interface></node>`;
  router.introspectXML("/root/fancy").assertEqual(introspectResult3);
  router.introspectXML("/")
    .assertEndsWith(`<node name="/"><node name="root"/><node name="troll"/></node>`);
}

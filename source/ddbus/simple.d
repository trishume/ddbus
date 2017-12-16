module ddbus.simple;

import ddbus.thin;
import ddbus.util;
import ddbus.c_lib;
import ddbus.router;
import std.string;
import std.traits;

class PathIface {
  this(Connection conn, string dest, ObjectPath path, string iface) {
    this(conn, dest, path.value, iface);
  }

  this(Connection conn, string dest, string path, string iface) {
    this.conn = conn;
    this.dest = dest.toStringz();
    this.path = path.toStringz();
    this.iface = iface.toStringz();
  }

  Ret call(Ret, Args...)(string meth, Args args)
      if (allCanDBus!Args && canDBus!Ret) {
    Message msg = Message(dbus_message_new_method_call(dest, path, iface, meth.toStringz()));
    msg.build(args);
    Message ret = conn.sendWithReplyBlocking(msg);
    return ret.read!Ret();
  }

  Message opDispatch(string meth, Args...)(Args args) {
    Message msg = Message(dbus_message_new_method_call(dest, path, iface, meth.toStringz()));
    msg.build(args);
    return conn.sendWithReplyBlocking(msg);
  }

  Connection conn;
  const(char)* dest;
  const(char)* path;
  const(char)* iface;
}

unittest {
  import dunit.toolkit;

  Connection conn = connectToBus();
  PathIface obj = new PathIface(conn, "org.freedesktop.DBus",
      "/org/freedesktop/DBus", "org.freedesktop.DBus");
  auto names = obj.GetNameOwner("org.freedesktop.DBus").to!string();
  names.assertEqual("org.freedesktop.DBus");
  obj.call!string("GetNameOwner", "org.freedesktop.DBus").assertEqual("org.freedesktop.DBus");
}

enum SignalMethod;

/**
   Registers all *possible* methods of an object in a router.
   It will not register methods that use types that ddbus can't handle.

   The implementation is rather hacky and uses the compiles trait to check for things
   working so if some methods randomly don't seem to be added, you should probably use
   setHandler on the router directly. It is also not efficient and creates a closure for every method.

   TODO: replace this with something that generates a wrapper class who's methods take and return messages
   and basically do what MessageRouter.setHandler does but avoiding duplication. Then this DBusWrapper!Class
   could be instantiated with any object efficiently and placed in the router table with minimal duplication.
 */
void registerMethods(T : Object)(MessageRouter router, string path, string iface, T obj) {
  MessagePattern patt = MessagePattern(path, iface, "", false);
  foreach (member; __traits(allMembers, T)) {
    // dfmt off
    static if (__traits(compiles, __traits(getOverloads, obj, member))
        && __traits(getOverloads, obj, member).length > 0
        && __traits(compiles, router.setHandler(patt, &__traits(getOverloads, obj, member)[0]))) {
      patt.method = member;
      patt.signal = hasUDA!(__traits(getOverloads, obj, member)[0], SignalMethod);
      router.setHandler(patt, &__traits(getOverloads, obj, member)[0]);
    }
    // dfmt on
  }
}

unittest {
  import dunit.toolkit;

  class Tester {
    int lol(int x, string s, string[string] map, Variant!DBusAny any) {
      return 5;
    }

    void wat() {
    }

    @SignalMethod void signalRecv() {
    }
  }

  auto o = new Tester;
  auto router = new MessageRouter;
  registerMethods(router, "/", "ca.thume.test", o);
  MessagePattern patt = MessagePattern("/", "ca.thume.test", "wat");
  router.callTable.assertHasKey(patt);
  patt.method = "signalRecv";
  patt.signal = true;
  router.callTable.assertHasKey(patt);
  patt.method = "lol";
  patt.signal = false;
  router.callTable.assertHasKey(patt);
  auto res = router.callTable[patt];
  res.argSig.assertEqual(["i", "s", "a{ss}", "v"]);
  res.retSig.assertEqual(["i"]);
}

module ddbus.simple;

import ddbus.thin;
import ddbus.util;
import ddbus.c_lib;
import ddbus.router;
import std.string;
import std.traits;

class PathIface {
  this(Connection conn, BusName dest, ObjectPath path, InterfaceName iface) {
    this.conn = conn;
    this.dest = dest.toStringz();
    this.path = path.value.toStringz();
    this.iface = iface.toStringz();
  }

  deprecated("Use the constructor taking BusName, ObjectPath and InterfaceName instead")
  this(Connection conn, string dest, ObjectPath path, string iface) {
    this(conn, busName(dest), path, interfaceName(iface));
  }

  deprecated("Use the constructor taking BusName, ObjectPath and InterfaceName instead")
  this(Connection conn, string dest, string path, string iface) {
    this(conn, busName(dest), ObjectPath(path), interfaceName(iface));
  }

  Ret call(Ret, Args...)(string meth, Args args)
      if (allCanDBus!Args && canDBus!Ret) {
    Message msg = Message(dbus_message_new_method_call(dest, path, iface, meth.toStringz()));
    msg.build(args);
    Message ret = conn.sendWithReplyBlocking(msg);
    return ret.read!Ret();
  }

  void call(Ret, Args...)(string meth, Args args)
      if (allCanDBus!Args && is(Ret == void)) {
    Message msg = Message(dbus_message_new_method_call(dest, path, iface, meth.toStringz()));
    msg.build(args);
    conn.sendBlocking(msg);
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
  PathIface obj = new PathIface(conn, busName("org.freedesktop.DBus"),
      ObjectPath("/org/freedesktop/DBus"), interfaceName("org.freedesktop.DBus"));
  auto names = obj.GetNameOwner(interfaceName("org.freedesktop.DBus")).to!BusName();
  names.assertEqual(busName("org.freedesktop.DBus"));
  obj.call!BusName("GetNameOwner", interfaceName("org.freedesktop.DBus")).assertEqual(busName("org.freedesktop.DBus"));
}

enum SignalMethod;

deprecated("Use the registerMethods overload taking an ObjectPath and InterfaceName instead")
void registerMethods(T : Object)(MessageRouter router, string path, string iface, T obj) {
  registerMethods(router, ObjectPath(path), interfaceName(iface), obj);
}

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
void registerMethods(T : Object)(MessageRouter router, ObjectPath path, InterfaceName iface, T obj) {
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
  registerMethods(router, ObjectPath("/"), interfaceName("ca.thume.test"), o);
  MessagePattern patt = MessagePattern(ObjectPath("/"), interfaceName("ca.thume.test"), "wat");
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

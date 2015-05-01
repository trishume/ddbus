module ddbus.simple;

import ddbus.thin;
import ddbus.util;
import ddbus.c_lib;
import std.string;

class PathIface {
  this(Connection conn, string dest, string path, string iface) {
    this.conn = conn;
    this.dest = dest.toStringz();
    this.path = path.toStringz();
    this.iface = iface.toStringz();
  }

  Ret call(Ret, Args...)(string meth, Args args) if(allCanDBus!Args && canDBus!Ret) {
    Message msg = Message(dbus_message_new_method_call(dest,path,iface,meth.toStringz()));
    msg.build(args);
    Message ret = conn.sendWithReplyBlocking(msg);
    return ret.read!Ret();
  }

  Message opDispatch(string meth, Args...)(Args args) {
    Message msg = Message(dbus_message_new_method_call(dest,path,iface,meth.toStringz()));
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
  PathIface obj = new PathIface(conn, "org.freedesktop.DBus","/org/freedesktop/DBus",
                                "org.freedesktop.DBus");
  auto names = obj.GetNameOwner("org.freedesktop.DBus").to!string();
  names.assertEqual("org.freedesktop.DBus");
  obj.call!string("GetNameOwner","org.freedesktop.DBus").assertEqual("org.freedesktop.DBus");
}

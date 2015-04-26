module ddbus.thin;

import ddbus.c_lib;
import std.string;

struct Message {
  this(string dest, string path, string iface, string method) {
    msg = dbus_message_new_method_call(dest.toStringz(), path.toStringz(), iface.toStringz(), method.toStringz());
  }

  ~this() {
    dbus_message_unref(msg);
  }

  DBusMessage *msg;
}

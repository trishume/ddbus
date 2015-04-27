module ddbus.thin;

import ddbus.c_lib;
import ddbus.conv;
import ddbus.util;
import std.string;
import std.typecons;

class Message {
  this(string dest, string path, string iface, string method) {
    msg = dbus_message_new_method_call(dest.toStringz(), path.toStringz(), iface.toStringz(), method.toStringz());
  }

  ~this() {
    dbus_message_unref(msg);
  }

  void build(TS...)(TS args) if(allCanDBus!TS) {
    DBusMessageIter iter;
    dbus_message_iter_init_append(msg, &iter);
    buildIter(&iter, args);
  }

  T read(T)() if(canDBus!T) {
    DBusMessageIter iter;
    dbus_message_iter_init(msg, &iter);
    return readIter!T(&iter);
  }

  Tup readTuple(Tup)() if(isTuple!Tup && allCanDBus!(Tup.Types)) {
    DBusMessageIter iter;
    dbus_message_iter_init(msg, &iter);
    Tup ret;
    readIterTuple(&iter, ret);
    return ret;
  }

  const(char)[] signature() {
    const(char)* cSig = dbus_message_get_signature(msg);
    return fromStringz(cSig);
  }

  DBusMessage *msg;
}

// class MessageBuilder {
//   DBusMessageIter iter;
//   // kept around for GC reasons, iterators need parent message.
//   Message parent;
//   this(Message msg) {
//     parent = msg;
//     dbus_message_iter_init(parent.msg, &iter);
//   }

//   void doBasic(int type, void *v) {
//     dbus_message_iter_append_basic(&iter, type, v);
//   }
// }

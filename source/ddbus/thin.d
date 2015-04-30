module ddbus.thin;

import ddbus.c_lib;
import ddbus.conv;
import ddbus.util;
import std.string;
import std.typecons;
import std.exception;

class DBusException : Exception {
  this(DBusError *err) {
    super(err.message.fromStringz().idup);
  }
}

T wrapErrors(T)(T delegate(DBusError *err) del) {
  DBusError error;
  dbus_error_init(&error);
  T ret = del(&error);
  if(dbus_error_is_set(&error)) {
    auto ex = new DBusException(&error);
    dbus_error_free(&error);
    throw ex;
  }
  return ret;
}

enum MessageType {
  Invalid = 0,
  Call, Return, Error, Signal
}

class Message {
  this(string dest, string path, string iface, string method) {
    msg = dbus_message_new_method_call(dest.toStringz(), path.toStringz(), iface.toStringz(), method.toStringz());
  }

  this(DBusMessage *m) {
    msg = m;
  }

  ~this() {
    dbus_message_unref(msg);
  }

  void build(TS...)(TS args) if(allCanDBus!TS) {
    DBusMessageIter iter;
    dbus_message_iter_init_append(msg, &iter);
    buildIter(&iter, args);
  }

  /**
     Reads the first argument of the message.
     Note that this creates a new iterator every time so calling it multiple times will always
     read the first argument. This is suitable for single item returns.
     To read multiple arguments use readTuple.
  */
  T read(T)() if(canDBus!T) {
    DBusMessageIter iter;
    dbus_message_iter_init(msg, &iter);
    return readIter!T(&iter);
  }
  alias read to;

  Tup readTuple(Tup)() if(isTuple!Tup && allCanDBus!(Tup.Types)) {
    DBusMessageIter iter;
    dbus_message_iter_init(msg, &iter);
    Tup ret;
    readIterTuple(&iter, ret);
    return ret;
  }

  Message createReturn() {
    return new Message(dbus_message_new_method_return(msg));
  }

  MessageType type() {
    return cast(MessageType)dbus_message_get_type(msg);
  }

  bool isCall() {
    return type() == MessageType.Call;
  }

  // Various string members
  // TODO: make a mixin to avoid this copy-paste
  string signature() {
    const(char)* cStr = dbus_message_get_signature(msg);
    assert(cStr != null);
    return cStr.fromStringz().assumeUnique();
  }
  string path() {
    const(char)* cStr = dbus_message_get_path(msg);
    assert(cStr != null);
    return cStr.fromStringz().assumeUnique();
  }
  string iface() {
    const(char)* cStr = dbus_message_get_interface(msg);
    assert(cStr != null);
    return cStr.fromStringz().assumeUnique();
  }
  string member() {
    const(char)* cStr = dbus_message_get_member(msg);
    assert(cStr != null);
    return cStr.fromStringz().assumeUnique();
  }
  string sender() {
    const(char)* cStr = dbus_message_get_sender(msg);
    assert(cStr != null);
    return cStr.fromStringz().assumeUnique();
  }

  DBusMessage *msg;
}

unittest {
  import dunit.toolkit;
  auto msg = new Message("org.example.test", "/test","org.example.testing","testMethod");
  msg.path().assertEqual("/test");
}

class Connection {
  DBusConnection *conn;
  this(DBusConnection *connection) {
    conn = connection;
  }

  void send(Message msg) {
    dbus_connection_send(conn,msg.msg, null);
  }

  void sendBlocking(Message msg) {
    send(msg);
    dbus_connection_flush(conn);
  }

  Message sendWithReplyBlocking(Message msg, int timeout = 100) {
    DBusMessage *reply = wrapErrors((err) {
        return dbus_connection_send_with_reply_and_block(conn,msg.msg,timeout,err);
      });
    return new Message(reply);
  }

  ~this() {
    dbus_connection_unref(conn);
  }
}

Connection connectToBus(DBusBusType bus = DBusBusType.DBUS_BUS_SESSION) {
  DBusConnection *conn = wrapErrors((err) { return dbus_bus_get(bus,err); });
  return new Connection(conn);
}

unittest {
  import dunit.toolkit;
  // This test will only pass if DBus is installed.
  Connection conn = connectToBus();
  conn.conn.assertTruthy();
  // We can only count on no system bus on OSX
  version(OSX) {
    connectToBus(DBusBusType.DBUS_BUS_SYSTEM).assertThrow!DBusException();
  }
}

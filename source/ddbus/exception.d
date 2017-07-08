module ddbus.exception;

import ddbus.c_lib;

package T wrapErrors(T)(
  T delegate(DBusError *err) del,
  string file = __FILE__,
  size_t line = __LINE__,
  Throwable next = null
) {
  DBusError error;
  dbus_error_init(&error);
  T ret = del(&error);
  if(dbus_error_is_set(&error)) {
    auto ex = new DBusException(&error, file, line, next);
    dbus_error_free(&error);
    throw ex;
  }
  return ret;
}

/++
  Thrown when a DBus error code was returned by libdbus.
+/
class DBusException : Exception {
  private this(
    scope DBusError *err,
    string file = __FILE__,
    size_t line = __LINE__,
    Throwable next = null
  ) pure nothrow {
    import std.string : fromStringz;

    super(err.message.fromStringz().idup, file, line, next);
  }
}


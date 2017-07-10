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

/++
  Thrown when the signature of a message does not match the requested types.
+/
class TypeMismatchException : Exception {
  package this(
    int expectedType,
    int actualType,
    string file = __FILE__,
    size_t line = __LINE__,
    Throwable next = null
  ) pure nothrow @safe {
    _expectedType = expectedType;
    _actualType = actualType;
    super("The type of value at the current position in the message does not match the type of value to be read."
      ~ " Expected: " ~ cast(char) expectedType ~ ", Got: " ~ cast(char) actualType);
  }

  int expectedType() @property pure const nothrow @nogc {
    return _expectedType;
  }

  int actualType() @property pure const nothrow @nogc {
    return _actualType;
  }

  private:
  int _expectedType;
  int _actualType;
}

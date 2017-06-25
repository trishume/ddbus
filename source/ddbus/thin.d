/// Thin OO wrapper around DBus types
module ddbus.thin;

import ddbus.c_lib;
import ddbus.conv;
import ddbus.util;
import std.string;
import std.typecons;
import std.exception;
import std.traits;
import std.conv;
import std.range;
import std.algorithm;

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

struct ObjectPath {
  private string _value;

  this(string objPath) {
    enforce(_isValid(objPath));
    _value = objPath;
  }

  string toString() const {
    return _value;
  }

  size_t toHash() const pure nothrow @trusted {
    return hashOf(_value);
  }

  bool opEquals(const ObjectPath b) const {
    return _value == b._value;
  }

  private static bool _isValid(string objPath) {
    import std.regex : matchFirst, ctRegex;
    return cast(bool) objPath.matchFirst(ctRegex!("^((/[0-9A-Za-z_]+)+|/)$"));
  }
}

/// Structure allowing typeless parameters
struct DBusAny {
  /// DBus type of the value (never 'v'), see typeSig!T
  int type;
  /// Child signature for Arrays & Tuples
  const(char)[] signature;
  /// If true, this value will get serialized as variant value, otherwise it is serialized like it wasn't in a DBusAny wrapper.
  /// Same functionality as Variant!T but with dynamic types if true.
  bool explicitVariant;

  union
  {
    ///
    byte int8;
    ///
    short int16;
    ///
    ushort uint16;
    ///
    int int32;
    ///
    uint uint32;
    ///
    long int64;
    ///
    ulong uint64;
    ///
    double float64;
    ///
    string str;
    ///
    bool boolean;
    ///
    ObjectPath obj;
    ///
    DBusAny[] array;
    ///
    DBusAny[] tuple;
    ///
    DictionaryEntry!(DBusAny, DBusAny)* entry;
    ///
    ubyte[] binaryData;
  }

  /// Manually creates a DBusAny object using a type, signature and implicit specifier.
  this(int type, const(char)[] signature, bool explicit) {
    this.type = type;
    this.signature = signature;
    this.explicitVariant = explicit;
  }

  /// Automatically creates a DBusAny object with fitting parameters from a D type or Variant!T.
  /// Pass a `Variant!T` to make this an explicit variant.
  this(T)(T value) {
    static if(is(T == byte) || is(T == ubyte)) {
      this(typeCode!byte, null, false);
      int8 = cast(byte) value;
    } else static if(is(T == short)) {
      this(typeCode!short, null, false);
      int16 = cast(short) value;
    } else static if(is(T == ushort)) {
      this(typeCode!ushort, null, false);
      uint16 = cast(ushort) value;
    } else static if(is(T == int)) {
      this(typeCode!int, null, false);
      int32 = cast(int) value;
    } else static if(is(T == uint)) {
      this(typeCode!uint, null, false);
      uint32 = cast(uint) value;
    } else static if(is(T == long)) {
      this(typeCode!long, null, false);
      int64 = cast(long) value;
    } else static if(is(T == ulong)) {
      this(typeCode!ulong, null, false);
      uint64 = cast(ulong) value;
    } else static if(is(T == double)) {
      this(typeCode!double, null, false);
      float64 = cast(double) value;
    } else static if(isSomeString!T) {
      this(typeCode!string, null, false);
      str = value.to!string;
    } else static if(is(T == bool)) {
      this(typeCode!bool, null, false);
      boolean = cast(bool) value;
    } else static if(is(T == ObjectPath)) {
      this(typeCode!ObjectPath, null, false);
      obj = value;
    } else static if(is(T == Variant!R, R)) {
      static if(is(R == DBusAny)) {
        type = value.data.type;
        signature = value.data.signature;
        explicitVariant = true;
        if(type == 'a' || type == 'r') {
          if(signature == ['y'])
            binaryData = value.data.binaryData;
          else
            array = value.data.array;
        } else if(type == 's')
          str = value.data.str;
        else if(type == 'e')
          entry = value.data.entry;
        else
          uint64 = value.data.uint64;
      } else {
        this(value.data);
        explicitVariant = true;
      }
    } else static if(is(T : DictionaryEntry!(K, V), K, V)) {
      this('e', null, false);
      entry = new DictionaryEntry!(DBusAny, DBusAny)();
      static if(is(K == DBusAny))
        entry.key = value.key;
      else
        entry.key = DBusAny(value.key);
      static if(is(V == DBusAny))
        entry.value = value.value;
      else
        entry.value = DBusAny(value.value);
    } else static if(is(T == ubyte[]) || is(T == byte[])) {
      this('a', ['y'], false);
      binaryData = cast(ubyte[]) value;
    } else static if(isInputRange!T) {
      this.type = 'a';
      static assert(!is(ElementType!T == DBusAny), "Array must consist of the same type, use Variant!DBusAny or DBusAny(tuple(...)) instead");
      static assert(typeSig!(ElementType!T) != "y");
      this.signature = typeSig!(ElementType!T);
      this.explicitVariant = false;
      foreach(elem; value)
        array ~= DBusAny(elem);
    } else static if(isTuple!T) {
      this.type = 'r';
      this.signature = ['('];
      this.explicitVariant = false;
      foreach(index, R; value.Types) {
        auto var = DBusAny(value[index]);
        tuple ~= var;
        if(var.explicitVariant)
          this.signature ~= 'v';
        else {
          if (var.type != 'r')
            this.signature ~= cast(char) var.type;
          if(var.type == 'a' || var.type == 'r')
            this.signature ~= var.signature;
        }
      }
      this.signature ~= ')';
    } else static if(isAssociativeArray!T) {
      this(value.byDictionaryEntries);
    } else static assert(false, T.stringof ~ " not convertible to a Variant");
  }

  ///
  string toString() const {
    string valueStr;
    switch(type) {
    case typeCode!byte:
      valueStr = int8.to!string;
      break;
    case typeCode!short:
      valueStr = int16.to!string;
      break;
    case typeCode!ushort:
      valueStr = uint16.to!string;
      break;
    case typeCode!int:
      valueStr = int32.to!string;
      break;
    case typeCode!uint:
      valueStr = uint32.to!string;
      break;
    case typeCode!long:
      valueStr = int64.to!string;
      break;
    case typeCode!ulong:
      valueStr = uint64.to!string;
      break;
    case typeCode!double:
      valueStr = float64.to!string;
      break;
    case typeCode!string:
      valueStr = '"' ~ str ~ '"';
      break;
    case typeCode!ObjectPath:
      valueStr = '"' ~ obj.to!string ~ '"';
      break;
    case typeCode!bool:
      valueStr = boolean ? "true" : "false";
      break;
    case 'a':
      import std.digest.digest : toHexString;

      if(signature == ['y'])
        valueStr = "binary(" ~ binaryData.toHexString ~ ')';
      else
        valueStr = '[' ~ array.map!(a => a.toString).join(", ") ~ ']';
      break;
    case 'r':
      valueStr = '(' ~ array.map!(a => a.toString).join(", ") ~ ')';
      break;
    case 'e':
      valueStr = entry.key.toString ~ ": " ~ entry.value.toString;
      break;
    default:
      valueStr = "unknown";
      break;
    }
    return "DBusAny(" ~ cast(char) type
      ~ ", \"" ~ signature.idup
      ~ "\", " ~ (explicitVariant ? "explicit" : "implicit")
      ~ ", " ~ valueStr ~ ")";
  }

  /// If the value is an array of DictionaryEntries this will return a HashMap
  DBusAny[DBusAny] toAA() {
    enforce(type == 'a' && signature && signature[0] == '{');
    DBusAny[DBusAny] aa;
    foreach(val; array) {
      enforce(val.type == 'e');
      aa[val.entry.key] = val.entry.value;
    }
    return aa;
  }

  /// Converts a basic type, a tuple or an array to the D type with type checking. Tuples can get converted to an array too.
  T to(T)() {
    static if(is(T == Variant!R, R)) {
      static if(is(R == DBusAny)) {
        auto v = to!R;
        v.explicitVariant = false;
        return Variant!R(v);
      } else
        return Variant!R(to!R);
    } else static if(is(T == DBusAny)) {
      return this;
    } else static if(isIntegral!T || isFloatingPoint!T) {
      switch(type) {
      case typeCode!byte:
        return cast(T) int8;
      case typeCode!short:
        return cast(T) int16;
      case typeCode!ushort:
        return cast(T) uint16;
      case typeCode!int:
        return cast(T) int32;
      case typeCode!uint:
        return cast(T) uint32;
      case typeCode!long:
        return cast(T) int64;
      case typeCode!ulong:
        return cast(T) uint64;
      case typeCode!double:
        return cast(T) float64;
      default:
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to " ~ T.stringof);
      }
    } else static if(is(T == bool)) {
      if(type == 'b')
        return boolean;
      else
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to " ~ T.stringof);
    } else static if(isSomeString!T) {
      if(type == 's')
        return str.to!T;
      else if(type == 'o')
        return obj.toString();
      else
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to " ~ T.stringof);
    } else static if(is(T == ObjectPath)) {
      if(type == 'o')
        return obj;
      else
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to " ~ T.stringof);
    } else static if(isDynamicArray!T) {
      if(type != 'a' && type != 'r')
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to an array");
      T ret;
      if(signature == ['y']) {
        static if(isIntegral!(ElementType!T))
          foreach(elem; binaryData)
            ret ~= elem.to!(ElementType!T);
      } else
        foreach(elem; array)
          ret ~= elem.to!(ElementType!T);
      return ret;
    } else static if(isTuple!T) {
      if(type != 'r')
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to " ~ T.stringof);
      T ret;
      enforce(ret.Types.length == tuple.length, "Tuple length mismatch");
      foreach(index, T; ret.Types)
        ret[index] = tuple[index].to!T;
      return ret;
    } else static if(isAssociativeArray!T) {
      if(type != 'a' || !signature || signature[0] != '{')
        throw new Exception("Can't convert type " ~ cast(char) type ~ " to " ~ T.stringof);
      T ret;
      foreach(pair; array) {
        enforce(pair.type == 'e');
        ret[pair.entry.key.to!(KeyType!T)] = pair.entry.value.to!(ValueType!T);
      }
      return ret;
    } else static assert(false, "Can't convert variant to " ~ T.stringof);
  }

  bool opEquals(ref in DBusAny b) const {
    if(b.type != type || b.explicitVariant != explicitVariant)
      return false;
    if((type == 'a' || type == 'r') && b.signature != signature)
      return false;
    if(type == 'a' && signature == ['y'])
      return binaryData == b.binaryData;
    if(type == 'a')
      return array == b.array;
    else if(type == 'r')
      return tuple == b.tuple;
    else if(type == 's')
      return str == b.str;
    else if(type == 'o')
      return obj == b.obj;
    else if(type == 'e')
      return entry == b.entry || (entry && b.entry && *entry == *b.entry);
    else
      return uint64 == b.uint64;
  }
}

unittest {
  import dunit.toolkit;
  DBusAny set(string member, T)(DBusAny v, T value) {
    mixin("v." ~ member ~ " = value;");
    return v;
  }

  void test(T)(T value, DBusAny b) {
    assertEqual(DBusAny(value), b);
    assertEqual(b.to!T, value);
    b.toString();
  }

  test(cast(ubyte) 184, set!"int8"(DBusAny('y', null, false), cast(byte) 184));
  test(cast(short) 184, set!"int16"(DBusAny('n', null, false), cast(short) 184));
  test(cast(ushort) 184, set!"uint16"(DBusAny('q', null, false), cast(ushort) 184));
  test(cast(int) 184, set!"int32"(DBusAny('i', null, false), cast(int) 184));
  test(cast(uint) 184, set!"uint32"(DBusAny('u', null, false), cast(uint) 184));
  test(cast(long) 184, set!"int64"(DBusAny('x', null, false), cast(long) 184));
  test(cast(ulong) 184, set!"uint64"(DBusAny('t', null, false), cast(ulong) 184));
  test(true, set!"boolean"(DBusAny('b', null, false), true));
  test(cast(ubyte[]) [1, 2, 3], set!"binaryData"(DBusAny('a', ['y'], false), cast(ubyte[]) [1, 2, 3]));

  test(variant(cast(ubyte) 184), set!"int8"(DBusAny('y', null, true), cast(byte) 184));
  test(variant(cast(short) 184), set!"int16"(DBusAny('n', null, true), cast(short) 184));
  test(variant(cast(ushort) 184), set!"uint16"(DBusAny('q', null, true), cast(ushort) 184));
  test(variant(cast(int) 184), set!"int32"(DBusAny('i', null, true), cast(int) 184));
  test(variant(cast(uint) 184), set!"uint32"(DBusAny('u', null, true), cast(uint) 184));
  test(variant(cast(long) 184), set!"int64"(DBusAny('x', null, true), cast(long) 184));
  test(variant(cast(ulong) 184), set!"uint64"(DBusAny('t', null, true), cast(ulong) 184));
  test(variant(true), set!"boolean"(DBusAny('b', null, true), true));
  test(variant(cast(ubyte[]) [1, 2, 3]), set!"binaryData"(DBusAny('a', ['y'], true), cast(ubyte[]) [1, 2, 3]));

  test(variant(DBusAny(5)), set!"int32"(DBusAny('i', null, true), 5));

  test([1, 2, 3], set!"array"(DBusAny('a', ['i'], false), [DBusAny(1), DBusAny(2), DBusAny(3)]));
  test(variant([1, 2, 3]), set!"array"(DBusAny('a', ['i'], true), [DBusAny(1), DBusAny(2), DBusAny(3)]));

  test(tuple("a", 4, [1, 2]), set!"tuple"(DBusAny('r', "(siai)".dup, false), [DBusAny("a"), DBusAny(4), DBusAny([1, 2])]));
  test(tuple("a", variant(4), variant([1, 2])), set!"tuple"(DBusAny('r', "(svv)", false), [DBusAny("a"), DBusAny(variant(4)), DBusAny(variant([1, 2]))]));

  test(["a": "b"], set!"array"(DBusAny('a', "{ss}", false), [DBusAny(DictionaryEntry!(DBusAny, DBusAny)(DBusAny("a"), DBusAny("b")))]));
  test([variant("a"): 4], set!"array"(DBusAny('a', "{vi}", false), [DBusAny(DictionaryEntry!(DBusAny, DBusAny)(DBusAny(variant("a")), DBusAny(4)))]));
}

/// Marks the data as variant on serialization
struct Variant(T) {
  ///
  T data;
}

Variant!T variant(T)(T data) {
  return Variant!T(data);
}

enum MessageType {
  Invalid = 0,
  Call, Return, Error, Signal
}

struct Message {
  DBusMessage *msg;

  this(string dest, string path, string iface, string method) {
    msg = dbus_message_new_method_call(dest.toStringz(), path.toStringz(), iface.toStringz(), method.toStringz());
  }

  this(DBusMessage *m) {
    msg = m;
  }

  this(this) {
    dbus_message_ref(msg);
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
    return Message(dbus_message_new_method_return(msg));
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
    return cStr.fromStringz().idup;
  }
  string path() {
    const(char)* cStr = dbus_message_get_path(msg);
    assert(cStr != null);
    return cStr.fromStringz().idup;
  }
  string iface() {
    const(char)* cStr = dbus_message_get_interface(msg);
    assert(cStr != null);
    return cStr.fromStringz().idup;
  }
  string member() {
    const(char)* cStr = dbus_message_get_member(msg);
    assert(cStr != null);
    return cStr.fromStringz().idup;
  }
  string sender() {
    const(char)* cStr = dbus_message_get_sender(msg);
    assert(cStr != null);
    return cStr.fromStringz().idup;
  }
}

unittest {
  import dunit.toolkit;
  auto msg = Message("org.example.test", "/test","org.example.testing","testMethod");
  msg.path().assertEqual("/test");
}

struct Connection {
  DBusConnection *conn;
  this(DBusConnection *connection) {
    conn = connection;
  }

  this(this) {
    dbus_connection_ref(conn);
  }

  ~this() {
    dbus_connection_unref(conn);
  }

  void close() {
    dbus_connection_close(conn);
  }

  void send(Message msg) {
    dbus_connection_send(conn,msg.msg, null);
  }

  void sendBlocking(Message msg) {
    send(msg);
    dbus_connection_flush(conn);
  }

  Message sendWithReplyBlocking(Message msg, int timeout = -1) {
    DBusMessage *dbusMsg = msg.msg;
    dbus_message_ref(dbusMsg);
    DBusMessage *reply = wrapErrors((err) {
        auto ret = dbus_connection_send_with_reply_and_block(conn,dbusMsg,timeout,err);
        dbus_message_unref(dbusMsg);
        return ret;
      });
    return Message(reply);
  }
}

Connection connectToBus(DBusBusType bus = DBusBusType.DBUS_BUS_SESSION) {
  DBusConnection *conn = wrapErrors((err) { return dbus_bus_get(bus,err); });
  return Connection(conn);
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

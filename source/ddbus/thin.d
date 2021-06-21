/// Thin OO wrapper around DBus types
module ddbus.thin;

import core.time : Duration;

import ddbus.attributes : isAllowedField;
import ddbus.c_lib;
import ddbus.conv;
import ddbus.exception : TypeMismatchException;
import ddbus.util;

import std.meta : ApplyRight, Filter, staticIndexOf;
import std.string;
import std.typecons;
import std.exception;
import std.traits;
import std.conv;
import std.range;
import std.algorithm;

// This import is public for backwards compatibility
public import ddbus.exception : wrapErrors, DBusException;

struct ObjectPath {
  enum root = ObjectPath("/");

  private string _value;

  this(string objPath) pure @safe {
    enforce(isValid(objPath));
    _value = objPath;
  }

  string toString() const {
    return _value;
  }

  /++
    Returns the string representation of this ObjectPath.
   +/
  string value() const pure @nogc nothrow @safe {
    return _value;
  }

  size_t toHash() const pure @nogc nothrow @trusted {
    return hashOf(_value);
  }

  T opCast(T : ObjectPath)() const pure @nogc nothrow @safe {
    return this;
  }

  T opCast(T : string)() const pure @nogc nothrow @safe {
    return value;
  }

  bool opEquals(ref const typeof(this) b) const pure @nogc nothrow @safe {
    return _value == b._value;
  }

  bool opEquals(const typeof(this) b) const pure @nogc nothrow @safe {
    return _value == b._value;
  }

  bool opEquals(string b) const pure @nogc nothrow @safe {
    return _value == b;
  }

  ObjectPath opBinary(string op : "~")(string rhs) const pure @safe {
    if (!rhs.startsWith("/")) {
      return opBinary!"~"(ObjectPath("/" ~ rhs));
    } else {
      return opBinary!"~"(ObjectPath(rhs));
    }
  }

  ObjectPath opBinary(string op : "~")(ObjectPath rhs) const pure @safe
  in {
    assert(ObjectPath.isValid(_value) && ObjectPath.isValid(rhs._value));
  }
  out (v) {
    assert(ObjectPath.isValid(v._value));
  }
  do {
    ObjectPath ret;

    if (_value == "/") {
      ret._value = rhs._value;
    } else {
      ret._value = _value ~ rhs._value;
    }

    return ret;
  }

  void opOpAssign(string op : "~")(string rhs) pure @safe {
    _value = opBinary!"~"(rhs)._value;
  }

  void opOpAssign(string op : "~")(ObjectPath rhs) pure @safe {
    _value = opBinary!"~"(rhs)._value;
  }

  bool startsWith(ObjectPath withThat) pure @nogc nothrow @safe {
    if (withThat._value == "/")
      return true;
    else if (_value == "/")
      return false;
    else
      return _value.representation.splitter('/').startsWith(withThat._value.representation.splitter('/'));
  }

  /// Removes a prefix from this path and returns the remainder. Keeps leading slashes.
  /// Returns this unmodified if the prefix doesn't match.
  ObjectPath chompPrefix(ObjectPath prefix) pure @nogc nothrow @safe {
    if (prefix._value == "/" || !startsWith(prefix))
      return this;
    else if (prefix._value == _value)
      return ObjectPath.root;
    else
      return ObjectPath.assumePath(_value[prefix._value.length .. $]);
  }

  /++
    Returns: `false` for empty strings or strings that don't match the
    pattern `(/[0-9A-Za-z_]+)+|/`.
   +/
  static bool isValid(string objPath) pure @nogc nothrow @safe {
    import std.ascii : isAlphaNum;

    if (!objPath.length) {
      return false;
    }

    if (objPath == "/") {
      return true;
    }

    if (objPath[0] != '/' || objPath[$ - 1] == '/') {
      return false;
    }

    // .representation to avoid unicode exceptions -> @nogc & nothrow
    return objPath.representation.splitter('/').drop(1).all!(a => a.length
        && a.all!(c => c.isAlphaNum || c == '_'));
  }

  /// Does an unsafe assignment to an ObjectPath.
  static ObjectPath assumePath(string path) pure @nogc nothrow @safe {
    ObjectPath ret;
    ret._value = path;
    return ret;
  }
}

/// Serves as typesafe alias. Instances should be created using busName instead of casting.
/// It prevents accidental usage of bus names in other string parameter fields and makes the API clearer.
enum BusName : string {
  none = null
}

/// Casts a bus name argument to a BusName type. May include additional validation in the future.
BusName busName(string name) pure @nogc nothrow @safe {
  return cast(BusName) name;
}

/// Serves as typesafe alias. Instances should be created using interfaceName instead of casting.
/// It prevents accidental usage of interface paths in other string parameter fields and makes the API clearer.
enum InterfaceName : string {
  none = null
}

/// Casts a interface path argument to an InterfaceName type. May include additional validation in the future.
InterfaceName interfaceName(string path) pure @nogc nothrow @safe {
  return cast(InterfaceName) path;
}

/// Serving as a typesafe alias for a FileDescriptor.
enum FileDescriptor : uint {
  none   = uint.max,
  stdin  = 0,
  stdout = 1,
  stderr = 2
}

/// Casts an integer to a FileDescriptor.
FileDescriptor fileDescriptor(uint fileNo) pure @nogc nothrow @safe {
  return cast(FileDescriptor) fileNo;
}

unittest {
  import dunit.toolkit;

  ObjectPath("some.invalid/object_path").assertThrow();
  ObjectPath("/path/with/TrailingSlash/").assertThrow();
  ObjectPath("/path/without/TrailingSlash").assertNotThrown();
  string path = "/org/freedesktop/DBus";
  auto obj = ObjectPath(path);
  obj.value.assertEqual(path);
  obj.toHash().assertEqual(path.hashOf);

  ObjectPath("/some/path").startsWith(ObjectPath("/some")).assertTrue();
  ObjectPath("/some/path").startsWith(ObjectPath("/path")).assertFalse();
  ObjectPath("/some/path").startsWith(ObjectPath("/")).assertTrue();
  ObjectPath("/").startsWith(ObjectPath("/")).assertTrue();
  ObjectPath("/").startsWith(ObjectPath("/some/path")).assertFalse();

  ObjectPath("/some/path").chompPrefix(ObjectPath("/some")).assertEqual(ObjectPath("/path"));
  ObjectPath("/some/path").chompPrefix(ObjectPath("/bar")).assertEqual(ObjectPath("/some/path"));
  ObjectPath("/some/path").chompPrefix(ObjectPath("/")).assertEqual(ObjectPath("/some/path"));
  ObjectPath("/some/path").chompPrefix(ObjectPath("/some/path")).assertEqual(ObjectPath("/"));
  ObjectPath("/some/path").chompPrefix(ObjectPath("/some/path/extra")).assertEqual(ObjectPath("/some/path"));
  ObjectPath("/").chompPrefix(ObjectPath("/some")).assertEqual(ObjectPath("/"));
  ObjectPath("/").chompPrefix(ObjectPath("/")).assertEqual(ObjectPath("/"));
}

unittest {
  import dunit.toolkit;

  ObjectPath a = ObjectPath("/org/freedesktop");
  a.assertEqual(ObjectPath("/org/freedesktop"));
  a ~= ObjectPath("/UPower");
  a.assertEqual(ObjectPath("/org/freedesktop/UPower"));
  a ~= "Device";
  a.assertEqual(ObjectPath("/org/freedesktop/UPower/Device"));
  (a ~ "0").assertEqual(ObjectPath("/org/freedesktop/UPower/Device/0"));
  a.assertEqual(ObjectPath("/org/freedesktop/UPower/Device"));
}

/// Structure allowing typeless parameters
struct DBusAny {
  /// DBus type of the value (never 'v'), see typeSig!T
  int type;
  /// Child signature for Arrays & Tuples
  string signature;
  /// If true, this value will get serialized as variant value, otherwise it is serialized like it wasn't in a DBusAny wrapper.
  /// Same functionality as Variant!T but with dynamic types if true.
  bool explicitVariant;

  union {
    ///
    ubyte uint8;
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
    alias tuple = array;
    ///
    DictionaryEntry!(DBusAny, DBusAny)* entry;
    ///
    ubyte[] binaryData;
    ///
    FileDescriptor fd;
  }

  /++
    Manually creates a DBusAny object using a type, signature and explicit
    variant specifier.

    Direct use of this constructor from user code should be avoided.
   +/
  this(int type, string signature, bool explicit) {
    this.type = type;
    this.signature = signature;
    this.explicitVariant = explicit;
  }

  /++
    Automatically creates a DBusAny object with fitting parameters from a D
    type or Variant!T.

    Pass a `Variant!T` to make this an explicit variant.
   +/
  this(T)(T value) {
    static if (is(T == byte) || is(T == ubyte)) {
      this(typeCode!ubyte, null, false);
      uint8 = cast(ubyte) value;
    } else static if (is(T == short)) {
      this(typeCode!short, null, false);
      int16 = cast(short) value;
    } else static if (is(T == ushort)) {
      this(typeCode!ushort, null, false);
      uint16 = cast(ushort) value;
    } else static if (is(T == int)) {
      this(typeCode!int, null, false);
      int32 = cast(int) value;
    } else static if (is(T == FileDescriptor)) {
      this(typeCode!FileDescriptor, null, false);
      fd = cast(FileDescriptor) value;
    } else static if (is(T == uint)) {
      this(typeCode!uint, null, false);
      uint32 = cast(uint) value;
    } else static if (is(T == long)) {
      this(typeCode!long, null, false);
      int64 = cast(long) value;
    } else static if (is(T == ulong)) {
      this(typeCode!ulong, null, false);
      uint64 = cast(ulong) value;
    } else static if (is(T == double)) {
      this(typeCode!double, null, false);
      float64 = cast(double) value;
    } else static if (isSomeString!T) {
      this(typeCode!string, null, false);
      str = value.to!string;
    } else static if (is(T == bool)) {
      this(typeCode!bool, null, false);
      boolean = cast(bool) value;
    } else static if (is(T == ObjectPath)) {
      this(typeCode!ObjectPath, null, false);
      obj = value;
    } else static if (is(T == Variant!R, R)) {
      static if (is(R == DBusAny)) {
        type = value.data.type;
        signature = value.data.signature;
        explicitVariant = true;
        if (type == 'a' || type == 'r') {
          if (signature == ['y']) {
            binaryData = value.data.binaryData;
          } else {
            array = value.data.array;
          }
        } else if (type == 's') {
          str = value.data.str;
        } else if (type == 'e') {
          entry = value.data.entry;
        } else {
          uint64 = value.data.uint64;
        }
      } else {
        this(value.data);
        explicitVariant = true;
      }
    } else static if (is(T : DictionaryEntry!(K, V), K, V)) {
      this('e', null, false);
      entry = new DictionaryEntry!(DBusAny, DBusAny)();
      static if (is(K == DBusAny)) {
        entry.key = value.key;
      } else {
        entry.key = DBusAny(value.key);
      }
      static if (is(V == DBusAny)) {
        entry.value = value.value;
      } else {
        entry.value = DBusAny(value.value);
      }
    } else static if (is(T == ubyte[]) || is(T == byte[])) {
      this('a', ['y'], false);
      binaryData = cast(ubyte[]) value;
    } else static if (isInputRange!T) {
      this.type = 'a';

      static assert(!is(ElementType!T == DBusAny),
          "Array must consist of the same type, use Variant!DBusAny or DBusAny(tuple(...)) instead");

      static assert(.typeSig!(ElementType!T) != "y");

      this.signature = .typeSig!(ElementType!T);
      this.explicitVariant = false;

      foreach (elem; value) {
        array ~= DBusAny(elem);
      }
    } else static if (isTuple!T) {
      this.type = 'r';
      this.signature = ['('];
      this.explicitVariant = false;

      foreach (index, R; value.Types) {
        auto var = DBusAny(value[index]);
        tuple ~= var;

        if (var.explicitVariant) {
          this.signature ~= 'v';
        } else {
          if (var.type != 'r') {
            this.signature ~= cast(char) var.type;
          }

          if (var.type == 'a' || var.type == 'r') {
            this.signature ~= var.signature;
          }
        }
      }

      this.signature ~= ')';
    } else static if (is(T == struct) && canDBus!T) {
      this.type = 'r';
      this.signature = ['('];
      this.explicitVariant = false;
      foreach (index, R; Fields!T) {
        static if (isAllowedField!(value.tupleof[index])) {
          auto var = DBusAny(value.tupleof[index]);
          tuple ~= var;
          if (var.explicitVariant)
            this.signature ~= 'v';
          else {
            if (var.type != 'r')
              this.signature ~= cast(char) var.type;
            if (var.type == 'a' || var.type == 'r')
              this.signature ~= var.signature;
          }
        }
      }
      this.signature ~= ')';
    } else static if (isAssociativeArray!T) {
      this(value.byDictionaryEntries);
    } else {
      static assert(false, T.stringof ~ " not convertible to a Variant");
    }
  }

  ///
  string toString() const {
    string valueStr;
    switch (type) {
    case typeCode!ubyte:
      valueStr = uint8.to!string;
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
      import std.digest : toHexString;

      if (signature == ['y']) {
        valueStr = "binary(" ~ binaryData.toHexString ~ ')';
      } else {
        valueStr = '[' ~ array.map!(a => a.toString).join(", ") ~ ']';
      }

      break;
    case 'r':
      valueStr = '(' ~ tuple.map!(a => a.toString).join(", ") ~ ')';
      break;
    case 'e':
      valueStr = entry.key.toString ~ ": " ~ entry.value.toString;
      break;
    case 'h':
      valueStr = int32.to!string;
      break;
    default:
      valueStr = "unknown";
      break;
    }

    return "DBusAny(" ~ cast(char) type ~ ", \"" ~ signature.idup ~ "\", " ~ (explicitVariant
        ? "explicit" : "implicit") ~ ", " ~ valueStr ~ ")";
  }

  /++
    Get the value stored in the DBusAny object.

    Parameters:
      T = The requested type. The currently stored value must match the
        requested type exactly.

    Returns:
      The current value of the DBusAny object.

    Throws:
      TypeMismatchException if the DBus type of the current value of the
      DBusAny object is not the same as the DBus type used to represent T.
  +/
  U get(U)() @property const
      if (staticIndexOf!(Unqual!U, BasicTypes) >= 0) {
    alias T = Unqual!U;
    enforce(type == typeCode!T, new TypeMismatchException(
        "Cannot get a " ~ T.stringof ~ " from a DBusAny with" ~ " a value of DBus type '" ~ typeSig ~ "'.",
        typeCode!T, type));

    static if (is(T == FileDescriptor)) {
      return cast(U) fd;
    } else  static if (isIntegral!T) {
      enum memberName = (isUnsigned!T ? "uint" : "int") ~ (T.sizeof * 8).to!string;
      return cast(U) __traits(getMember, this, memberName);
    } else static if (is(T == double)) {
      return cast(U) float64;
    } else static if (is(T == string)) {
      return cast(U) str;
    } else static if (is(T == InterfaceName) || is(T == BusName)) {
      return cast(U) str;
    } else static if (is(T == ObjectPath)) {
      return cast(U) obj;
    } else static if (is(T == bool)) {
      return cast(U) boolean;
    } else {
      static assert(false);
    }
  }

  /// ditto
  T get(T)() @property const
      if (is(T == const(DBusAny)[])) {
    enforce((type == 'a' && signature != "y") || type == 'r', new TypeMismatchException(
        "Cannot get a " ~ T.stringof ~ " from a DBusAny with" ~ " a value of DBus type '" ~ this.typeSig ~ "'.",
        'a', type));

    return array;
  }

  /// ditto
  T get(T)() @property const
      if (is(T == const(ubyte)[])) {
    enforce(type == 'a' && signature == "y", new TypeMismatchException(
        "Cannot get a " ~ T.stringof ~ " from a DBusAny with" ~ " a value of DBus type '" ~ this.typeSig ~ "'.",
        'a', type));

    return binaryData;
  }

  /// If the value is an array of DictionaryEntries this will return a HashMap
  deprecated("Please use to!(V[K])") DBusAny[DBusAny] toAA() {
    enforce(type == 'a' && signature && signature[0] == '{');
    DBusAny[DBusAny] aa;

    foreach (val; array) {
      enforce(val.type == 'e');
      aa[val.entry.key] = val.entry.value;
    }

    return aa;
  }

  /++
    Get the DBus type signature of the value stored in the DBusAny object.

    Returns:
      The type signature of the value stored in this DBusAny object.
   +/
  string typeSig() @property const pure nothrow @safe {
    if (type == 'a') {
      return "a" ~ signature;
    } else if (type == 'r') {
      return signature;
    } else if (type == 'e') {
      return () @trusted{
        return "{" ~ entry.key.signature ~ entry.value.signature ~ "}";
      }();
    } else {
      return [cast(char) type];
    }
  }

  /++
    Converts a basic type, a tuple or an array to the D type with type checking.

    Tuples can be converted to an array of DBusAny, but not to any other array.
   +/
  T to(T)() @property const pure {
    // Just use `get` if possible
    static if (canDBus!T && __traits(compiles, get!T)) {
      if (this.typeSig == .typeSig!T)
        return get!T;
    }

    // If we get here, we need some type conversion
    static if (is(T == Variant!R, R)) {
      static if (is(R == DBusAny)) {
        auto v = to!R;
        v.explicitVariant = false;
        return Variant!R(v);
      } else {
        return Variant!R(to!R);
      }
    } else static if (is(T == DBusAny)) {
      return this;
    } else {
      // In here are all static if blocks that may fall through to the throw
      // statement at the bottom of this block.

      static if (is(T == DictionaryEntry!(K, V), K, V)) {
        if (type == 'e') {
          static if (is(T == typeof(entry))) {
            return entry;
          } else {
            return DictionaryEntry(entry.key.to!K, entry.value.to!V);
          }
        }
      } else static if (isAssociativeArray!T) {
        if (type == 'a' && (!array.length || array[0].type == 'e')) {
          alias K = Unqual!(KeyType!T);
          alias V = Unqual!(ValueType!T);
          V[K] ret;

          foreach (pair; array) {
            assert(pair.type == 'e');
            ret[pair.entry.key.to!K] = pair.entry.value.to!V;
          }

          return cast(T) ret;
        }
      } else static if (isDynamicArray!T && !isSomeString!T) {
        alias E = Unqual!(ElementType!T);

        if (typeSig == "ay") {
          auto data = get!(const(ubyte)[]);
          static if (is(E == ubyte) || is(E == byte)) {
            return cast(T) data.dup;
          } else {
            return cast(T) data.map!(elem => elem.to!E).array;
          }
        } else if (type == 'a' || (type == 'r' && is(E == DBusAny))) {
          return cast(T) get!(const(DBusAny)[]).map!(elem => elem.to!E).array;
        }
      } else static if (isTuple!T) {
        if (type == 'r') {
          T ret;

          foreach (i, T; ret.Types) {
            ret[i] = tuple[i].to!T;
          }

          return ret;
        }
      } else static if (is(T == struct) && canDBus!T) {
        if (type == 'r') {
          T ret;
          size_t j;

          foreach (i, F; Fields!T) {
            static if (isAllowedField!(ret.tupleof[i])) {
              ret.tupleof[i] = tuple[j++].to!F;
            }
          }

          return ret;
        }
      } else {
        alias isPreciselyConvertible = ApplyRight!(isImplicitlyConvertible, T);

        template isUnpreciselyConvertible(S) {
          enum isUnpreciselyConvertible = !isPreciselyConvertible!S
              && __traits(compiles, get!S.to!T);
        }

        // Try to be precise
        foreach (B; Filter!(isPreciselyConvertible, BasicTypes)) {
          if (type == typeCode!B)
            return get!B;
        }

        // Try to convert
        foreach (B; Filter!(isUnpreciselyConvertible, BasicTypes)) {
          if (type == typeCode!B)
            return get!B.to!T;
        }
      }

      throw new ConvException("Cannot convert from DBus type '" ~ this.typeSig ~ "' to "
          ~ T.stringof);
    }
  }

  bool opEquals(ref in DBusAny b) const {
    if (b.type != type || b.explicitVariant != explicitVariant) {
      return false;
    }

    if ((type == 'a' || type == 'r') && b.signature != signature) {
      return false;
    }

    if (type == 'a' && signature == ['y']) {
      return binaryData == b.binaryData;
    }

    if (type == 'a') {
      return array == b.array;
    } else if (type == 'r') {
      return tuple == b.tuple;
    } else if (type == 's') {
      return str == b.str;
    } else if (type == 'o') {
      return obj == b.obj;
    } else if (type == 'e') {
      return entry == b.entry || (entry && b.entry && *entry == *b.entry);
    } else {
      return uint64 == b.uint64;
    }
  }

  /// Returns: true if this variant is an integer.
  bool typeIsIntegral() const @property {
    return type.dbusIsIntegral;
  }

  /// Returns: true if this variant is a floating point value.
  bool typeIsFloating() const @property {
    return type.dbusIsFloating;
  }

  /// Returns: true if this variant is an integer or a floating point value.
  bool typeIsNumeric() const @property {
    return type.dbusIsNumeric;
  }
}

unittest {
  import dunit.toolkit;

  DBusAny set(string member, T)(DBusAny v, T value) {
    mixin("v." ~ member ~ " = value;");
    return v;
  }

  void test(bool testGet = false, T)(T value, DBusAny b) {
    assertEqual(DBusAny(value), b);
    assertEqual(b.to!T, value);
    static if (testGet)
      assertEqual(b.get!T, value);
    b.toString();
  }

  test!true(cast(ubyte) 184, set!"uint8"(DBusAny('y', null, false), cast(ubyte) 184));
  test(cast(byte) 184, set!"uint8"(DBusAny('y', null, false), cast(byte) 184));
  test!true(cast(short) 184, set!"int16"(DBusAny('n', null, false), cast(short) 184));
  test!true(cast(ushort) 184, set!"uint16"(DBusAny('q', null, false), cast(ushort) 184));
  test!true(cast(int) 184, set!"int32"(DBusAny('i', null, false), cast(int) 184));
  test!true(cast(uint) 184, set!"uint32"(DBusAny('u', null, false), cast(uint) 184));
  test!true(cast(long) 184, set!"int64"(DBusAny('x', null, false), cast(long) 184));
  test!true(cast(ulong) 184, set!"uint64"(DBusAny('t', null, false), cast(ulong) 184));
  test!true(1.84, set!"float64"(DBusAny('d', null, false), 1.84));
  test!true(true, set!"boolean"(DBusAny('b', null, false), true));
  test!true("abc", set!"str"(DBusAny('s', null, false), "abc"));
  test!true(ObjectPath("/foo/Bar"), set!"obj"(DBusAny('o', null, false), ObjectPath("/foo/Bar")));
  test(cast(ubyte[])[1, 2, 3], set!"binaryData"(DBusAny('a', ['y'], false),
      cast(ubyte[])[1, 2, 3]));

  test(variant(cast(ubyte) 184), set!"uint8"(DBusAny('y', null, true), cast(ubyte) 184));
  test(variant(cast(short) 184), set!"int16"(DBusAny('n', null, true), cast(short) 184));
  test(variant(cast(ushort) 184), set!"uint16"(DBusAny('q', null, true), cast(ushort) 184));
  test(variant(cast(int) 184), set!"int32"(DBusAny('i', null, true), cast(int) 184));
  test(variant(cast(FileDescriptor) 184), set!"uint32"(DBusAny('h', null, true), cast(FileDescriptor) 184));
  test(variant(cast(FileDescriptor) FileDescriptor.none), set!"uint32"(DBusAny('h', null, true), cast(FileDescriptor) FileDescriptor.none));
  test(variant(cast(uint) 184), set!"uint32"(DBusAny('u', null, true), cast(uint) 184));
  test(variant(cast(long) 184), set!"int64"(DBusAny('x', null, true), cast(long) 184));
  test(variant(cast(ulong) 184), set!"uint64"(DBusAny('t', null, true), cast(ulong) 184));
  test(variant(1.84), set!"float64"(DBusAny('d', null, true), 1.84));
  test(variant(true), set!"boolean"(DBusAny('b', null, true), true));
  test(variant("abc"), set!"str"(DBusAny('s', null, true), "abc"));
  test(variant(ObjectPath("/foo/Bar")), set!"obj"(DBusAny('o', null, true),
      ObjectPath("/foo/Bar")));
  test(variant(cast(ubyte[])[1, 2, 3]), set!"binaryData"(DBusAny('a', ['y'],
      true), cast(ubyte[])[1, 2, 3]));

  test(variant(DBusAny(5)), set!"int32"(DBusAny('i', null, true), 5));

  test([1, 2, 3], set!"array"(DBusAny('a', ['i'], false), [DBusAny(1), DBusAny(2), DBusAny(3)]));
  test(variant([1, 2, 3]), set!"array"(DBusAny('a', ['i'], true), [DBusAny(1),
      DBusAny(2), DBusAny(3)]));

  test(tuple("a", 4, [1, 2]), set!"tuple"(DBusAny('r', "(siai)".dup, false),
      [DBusAny("a"), DBusAny(4), DBusAny([1, 2])]));
  test(tuple("a", variant(4), variant([1, 2])), set!"tuple"(DBusAny('r',
      "(svv)", false), [DBusAny("a"), DBusAny(variant(4)), DBusAny(variant([1, 2]))]));

  test(["a" : "b"], set!"array"(DBusAny('a', "{ss}", false),
      [DBusAny(DictionaryEntry!(DBusAny, DBusAny)(DBusAny("a"), DBusAny("b")))]));
  test([variant("a") : 4], set!"array"(DBusAny('a', "{vi}", false),
      [DBusAny(DictionaryEntry!(DBusAny, DBusAny)(DBusAny(variant("a")), DBusAny(4)))]));
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
  Call,
  Return,
  Error,
  Signal
}

/// Represents a message in the dbus system. Use the constructor to 
struct Message {
  DBusMessage* msg;

  deprecated("Use the constructor taking a BusName, ObjectPath and InterfaceName instead")
  this(string dest, string path, string iface, string method) {
    msg = dbus_message_new_method_call(dest.toStringz(), path.toStringz(),
        iface.toStringz(), method.toStringz());
  }

  /// Prepares a new method call to an "instance" "object" "interface" "method".
  this(BusName dest, ObjectPath path, InterfaceName iface, string method) {
    msg = dbus_message_new_method_call(dest.toStringz(),
        path.value.toStringz(), iface.toStringz(), method.toStringz());
  }

  /// Wraps an existing low level message object.
  this(DBusMessage* m) {
    msg = m;
  }

  this(this) {
    dbus_message_ref(msg);
  }

  ~this() {
    if (msg) {
      dbus_message_unref(msg);
      msg = null;
    }
  }

  /// Creates a new iterator and puts in the arguments for calling a method.
  void build(TS...)(TS args)
      if (allCanDBus!TS) {
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
  T read(T)()
      if (canDBus!T) {
    DBusMessageIter iter;
    dbus_message_iter_init(msg, &iter);
    return readIter!T(&iter);
  }

  alias read to;

  Tup readTuple(Tup)()
      if (isTuple!Tup && allCanDBus!(Tup.Types)) {
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
    return cast(MessageType) dbus_message_get_type(msg);
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

  ObjectPath path() {
    const(char)* cStr = dbus_message_get_path(msg);
    assert(cStr != null);
    return ObjectPath(cStr.fromStringz().idup);
  }

  InterfaceName iface() {
    const(char)* cStr = dbus_message_get_interface(msg);
    assert(cStr != null);
    return interfaceName(cStr.fromStringz().idup);
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

///
unittest {
  import dunit.toolkit;

  auto msg = Message(busName("org.example.test"), ObjectPath("/test"), interfaceName("org.example.testing"), "testMethod");
  msg.path().assertEqual("/test");
}

struct Connection {
  DBusConnection* conn;
  this(DBusConnection* connection) {
    conn = connection;
  }

  this(this) {
    dbus_connection_ref(conn);
  }

  ~this() {
    if (conn) {
      dbus_connection_unref(conn);
      conn = null;
    }
  }

  void close() {
    if (conn) {
      dbus_connection_close(conn);
    }
  }

  void send(Message msg) {
    dbus_connection_send(conn, msg.msg, null);
  }

  void sendBlocking(Message msg) {
    send(msg);
    dbus_connection_flush(conn);
  }

  Message sendWithReplyBlocking(Message msg, int timeout = -1) {
    DBusMessage* dbusMsg = msg.msg;
    dbus_message_ref(dbusMsg);
    DBusMessage* reply = wrapErrors((err) {
      auto ret = dbus_connection_send_with_reply_and_block(conn, dbusMsg, timeout, err);
      dbus_message_unref(dbusMsg);
      return ret;
    });
    return Message(reply);
  }

  Message sendWithReplyBlocking(Message msg, Duration timeout) {
    return sendWithReplyBlocking(msg, timeout.total!"msecs"().to!int);
  }
}

unittest {
  import dunit.toolkit;
  import ddbus.attributes : dbusMarshaling, MarshalingFlag;

  struct S1 {
    private int a;
    private @(Yes.DBusMarshal) double b;
    string s;
  }

  @dbusMarshaling(MarshalingFlag.manualOnly)
  struct S2 {
    int h, i;
    @(Yes.DBusMarshal) int j, k;
    int* p;
  }

  @dbusMarshaling(MarshalingFlag.includePrivateFields)
  struct S3 {
    private Variant!int c;
    string d;
    S1 e;
    S2 f;
    @(No.DBusMarshal) uint g;
  }

  Message msg = Message(busName("org.example.wow"), ObjectPath("/wut"), interfaceName("org.test.iface"), "meth3");

  __gshared int dummy;

  enum testStruct = S3(variant(5), "blah", S1(-7, 63.5, "test"), S2(84, -123,
        78, 432, &dummy), 16);

  // Non-marshaled fields should appear as freshly initialized
  enum expectedResult = S3(variant(5), "blah", S1(int.init, 63.5, "test"),
        S2(int.init, int.init, 78, 432, null), uint.init);

  // Test struct conversion in building/reading messages
  msg.build(testStruct);
  msg.read!S3().assertEqual(expectedResult);

  // Test struct conversion in DBusAny
  DBusAny(testStruct).to!S3.assertEqual(expectedResult);
}

Connection connectToBus(DBusBusType bus = DBusBusType.DBUS_BUS_SESSION) {
  DBusConnection* conn = wrapErrors((err) { return dbus_bus_get(bus, err); });
  return Connection(conn);
}

unittest {
  import dunit.toolkit;

  // This test will only pass if DBus is installed.
  Connection conn = connectToBus();
  conn.conn.assertTruthy();
  // We can only count on no system bus on OSX
  version (OSX) {
    connectToBus(DBusBusType.DBUS_BUS_SYSTEM).assertThrow!DBusException();
  }
}

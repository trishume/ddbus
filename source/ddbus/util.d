module ddbus.util;

import ddbus.thin;
import std.meta : AliasSeq, staticIndexOf;
import std.range;
import std.traits;
import std.typecons : BitFlags, isTuple, Tuple;
import std.variant : VariantN;

struct DictionaryEntry(K, V) {
  K key;
  V value;
}

auto byDictionaryEntries(K, V)(V[K] aa) {
  import std.algorithm : map;

  return aa.byKeyValue.map!(pair => DictionaryEntry!(K, V)(pair.key, pair.value));
}

/+
  Predicate template indicating whether T is an instance of ddbus.thin.Variant.

  Deprecated:
    This template used to be undocumented and user code should not depend on it.
    Its meaning became unclear when support for Phobos-style variants was added.
    It seemed best to remove it at that point.
+/
deprecated("Use std.traits.isInstanceOf instead.") template isVariant(T) {
  static if (isBasicType!T || isInputRange!T) {
    enum isVariant = false;
  } else static if (__traits(compiles, TemplateOf!T) && __traits(isSame, TemplateOf!T, Variant)) {
    enum isVariant = true;
  } else {
    enum isVariant = false;
  }
}

template VariantType(T) {
  alias VariantType = TemplateArgsOf!(T)[0];
}

template allCanDBus(TS...) {
  static if (TS.length == 0) {
    enum allCanDBus = true;
  } else static if (!canDBus!(TS[0])) {
    enum allCanDBus = false;
  } else {
    enum allCanDBus = allCanDBus!(TS[1 .. $]);
  }
}

/++
  AliasSeq of all basic types in terms of the DBus typesystem
 +/
package  // Don't add to the API yet, 'cause I intend to move it later
alias BasicTypes = AliasSeq!(bool, ubyte, short, ushort, int, uint, long, ulong,
    double, string, ObjectPath, InterfaceName, BusName, FileDescriptor);

template basicDBus(U) {
  alias T = Unqual!U;
  static if (staticIndexOf!(T, BasicTypes) >= 0) {
    enum basicDBus = true;
  } else static if (is(T B == enum)) {
    enum basicDBus = basicDBus!B;
  } else static if (isInstanceOf!(BitFlags, T)) {
    alias TemplateArgsOf!T[0] E;
    enum basicDBus = basicDBus!E;
  } else {
    enum basicDBus = false;
  }
}

template canDBus(U) {
  alias T = Unqual!U;
  static if (basicDBus!T || is(T == DBusAny)) {
    enum canDBus = true;
  } else static if (isInstanceOf!(Variant, T)) {
    enum canDBus = canDBus!(VariantType!T);
  } else static if (isInstanceOf!(VariantN, T)) {
    // Phobos-style variants are supported if limited to DBus compatible types.
    enum canDBus = (T.AllowedTypes.length > 0) && allCanDBus!(T.AllowedTypes);
  } else static if (isTuple!T) {
    enum canDBus = allCanDBus!(T.Types);
  } else static if (isInputRange!T) {
    static if (is(ElementType!T == DictionaryEntry!(K, V), K, V)) {
      enum canDBus = basicDBus!K && canDBus!V;
    } else {
      enum canDBus = canDBus!(ElementType!T);
    }
  } else static if (isAssociativeArray!T) {
    enum canDBus = basicDBus!(KeyType!T) && canDBus!(ValueType!T);
  } else static if (is(T == struct) && !isInstanceOf!(DictionaryEntry, T)) {
    enum canDBus = allCanDBus!(AllowedFieldTypes!T);
  } else {
    enum canDBus = false;
  }
}

unittest {
  import dunit.toolkit;

  (canDBus!int).assertTrue();
  (canDBus!(int[])).assertTrue();
  (allCanDBus!(int, string, bool)).assertTrue();
  (canDBus!(Tuple!(int[], bool, Variant!short))).assertTrue();
  (canDBus!(Tuple!(int[], int[string]))).assertTrue();
  (canDBus!(int[string])).assertTrue();
  (canDBus!FileDescriptor).assertTrue();
}

string typeSig(U)()
    if (canDBus!U) {
  alias T = Unqual!U;
  static if (is(T == ubyte)) {
    return "y";
  } else static if (is(T == bool)) {
    return "b";
  } else static if (is(T == short)) {
    return "n";
  } else static if (is(T == ushort)) {
    return "q";
  } else static if (is(T == FileDescriptor)) {
    return "h";
  } else static if (is(T == int)) {
    return "i";
  } else static if (is(T == uint)) {
    return "u";
  } else static if (is(T == long)) {
    return "x";
  } else static if (is(T == ulong)) {
    return "t";
  } else static if (is(T == double)) {
    return "d";
  } else static if (is(T == string) || is(T == InterfaceName) || is(T == BusName)) {
    return "s";
  } else static if (is(T == ObjectPath)) {
    return "o";
  } else static if (isInstanceOf!(Variant, T) || isInstanceOf!(VariantN, T)) {
    return "v";
  } else static if (is(T B == enum)) {
    return typeSig!B;
  } else static if (isInstanceOf!(BitFlags, T)) {
    alias TemplateArgsOf!T[0] E;
    return typeSig!E;
  } else static if (is(T == DBusAny)) {
    static assert(false,
        "Cannot determine type signature of DBusAny. Change to Variant!DBusAny if a variant was desired.");
  } else static if (isTuple!T) {
    string sig = "(";
    foreach (i, S; T.Types) {
      sig ~= typeSig!S();
    }
    sig ~= ")";
    return sig;
  } else static if (isInputRange!T) {
    return "a" ~ typeSig!(ElementType!T)();
  } else static if (isAssociativeArray!T) {
    return "a{" ~ typeSig!(KeyType!T) ~ typeSig!(ValueType!T) ~ "}";
  } else static if (is(T == struct)) {
    string sig = "(";
    foreach (i, S; AllowedFieldTypes!T) {
      sig ~= typeSig!S();
    }
    sig ~= ")";
    return sig;
  }
}

string typeSig(T)()
    if (isInstanceOf!(DictionaryEntry, T)) {
  alias typeof(T.key) K;
  alias typeof(T.value) V;
  return "{" ~ typeSig!K ~ typeSig!V ~ '}';
}

string[] typeSigReturn(T)()
    if (canDBus!T) {
  static if (is(T == Tuple!TS, TS...))
    return typeSigArr!TS;
  else
    return [typeSig!T];
}

string typeSigAll(TS...)()
    if (allCanDBus!TS) {
  string sig = "";
  foreach (i, T; TS) {
    sig ~= typeSig!T();
  }
  return sig;
}

string[] typeSigArr(TS...)()
    if (allCanDBus!TS) {
  string[] sig = [];
  foreach (i, T; TS) {
    sig ~= typeSig!T();
  }
  return sig;
}

int typeCode(T)()
    if (canDBus!T) {
  int code = typeSig!T()[0];
  return (code != '(') ? code : 'r';
}

int typeCode(T)()
    if (isInstanceOf!(DictionaryEntry, T) && canDBus!(T[])) {
  return 'e';
}

/**
  Params:
    type = the type code of a type (first character in a type string)
  Returns: true if the given type is an integer.
*/
bool dbusIsIntegral(int type) @property {
  return type == 'y' || type == 'n' || type == 'q' || type == 'i' || type == 'u' || type == 'x' || type == 't';
}

/**
  Params:
    type = the type code of a type (first character in a type string)
  Returns: true if the given type is a floating point value.
*/
bool dbusIsFloating(int type) @property {
  return type == 'd';
}

/**
  Params:
    type = the type code of a type (first character in a type string)
  Returns: true if the given type is an integer or a floating point value.
*/
bool dbusIsNumeric(int type) @property {
  return dbusIsIntegral(type) || dbusIsFloating(type);
}

unittest {
  import dunit.toolkit;

  static assert(canDBus!ObjectPath);
  static assert(canDBus!InterfaceName);
  static assert(canDBus!BusName);

  // basics
  typeSig!int().assertEqual("i");
  typeSig!bool().assertEqual("b");
  typeSig!string().assertEqual("s");
  typeSig!InterfaceName().assertEqual("s");
  typeSig!(immutable(InterfaceName))().assertEqual("s");
  typeSig!ObjectPath().assertEqual("o");
  typeSig!(immutable(ObjectPath))().assertEqual("o");
  typeSig!(Variant!int)().assertEqual("v");
  typeSig!FileDescriptor().assertEqual("h");
  // enums
  enum E : ubyte {
    a,
    b,
    c
  }

  typeSig!E().assertEqual(typeSig!ubyte());
  enum U : string {
    One = "One",
    Two = "Two"
  }

  typeSig!U().assertEqual(typeSig!string());
  // bit flags
  enum F : uint {
    a = 1,
    b = 2,
    c = 4
  }

  typeSig!(BitFlags!F)().assertEqual(typeSig!uint());
  // tuples (represented as structs in DBus)
  typeSig!(Tuple!(int, string, string)).assertEqual("(iss)");
  typeSig!(Tuple!(int, string, Variant!int, Tuple!(int, "k", double, "x"))).assertEqual(
      "(isv(id))");
  // structs
  struct S1 {
    int a;
    double b;
    string s;
  }

  typeSig!S1.assertEqual("(ids)");
  struct S2 {
    Variant!int c;
    string d;
    S1 e;
    uint f;
    FileDescriptor g;
  }

  typeSig!S2.assertEqual("(vs(ids)uh)");
  // arrays
  typeSig!(int[]).assertEqual("ai");
  typeSig!(Variant!int[]).assertEqual("av");
  typeSig!(Tuple!(ubyte)[][]).assertEqual("aa(y)");
  // dictionaries
  typeSig!(int[string]).assertEqual("a{si}");
  typeSig!(DictionaryEntry!(string, int)[]).assertEqual("a{si}");
  // multiple arguments
  typeSigAll!(int, bool).assertEqual("ib");
  // Phobos-style variants
  canDBus!(std.variant.Variant).assertFalse();
  typeSig!(std.variant.Algebraic!(int, double, string)).assertEqual("v");
  // type codes
  typeCode!int().assertEqual(cast(int)('i'));
  typeCode!bool().assertEqual(cast(int)('b'));
  typeCode!(Tuple!(int, string))().assertEqual(cast(int)('r'));
  // ctfe-capable
  static string sig = typeSig!ulong();
  sig.assertEqual("t");
  static string sig2 = typeSig!(Tuple!(int, string, string));
  sig2.assertEqual("(iss)");
  static string sig3 = typeSigAll!(int, string, InterfaceName, BusName);
  sig3.assertEqual("isss");
}

private template AllowedFieldTypes(S)
    if (is(S == struct)) {
  import ddbus.attributes : isAllowedField;
  import std.meta : Filter, staticMap;

  static alias TypeOf(alias sym) = typeof(sym);

  alias AllowedFieldTypes = staticMap!(TypeOf, Filter!(isAllowedField, S.tupleof));
}

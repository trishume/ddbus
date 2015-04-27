module ddbus.util;
import std.typecons;
import std.range;

template allCanDBus(TS...) {
  static if (TS.length == 0) {
    enum allCanDBus = true; 
  } else static if(!canDBus!(TS[0])) {
    enum allCanDBus = false;
  } else {
    enum allCanDBus = allCanDBus!(TS[1..$]);
  }
}

template basicDBus(T) {
  static if(is(T == byte) || is(T == short) || is (T == ushort) || is (T == int)
            || is (T == uint) || is (T == long) || is (T == ulong)
            || is (T == double) || is (T == string) || is(T == bool)) {
    enum basicDBus = true;
  } else {
    enum basicDBus = false;
  }
}

template canDBus(T) {
  static if(basicDBus!T) {
    enum canDBus = true;
  } else static if(isTuple!T) {
    enum canDBus = allCanDBus!(T.Types);
  } else static if(isInputRange!T) {
    enum canDBus = canDBus!(ElementType!T);
  } else {
    enum canDBus = false;
  }
}
unittest {
  import dunit.toolkit;
  (canDBus!int).assertTrue();
  (canDBus!(int[])).assertTrue();
  (allCanDBus!(int,string,bool)).assertTrue();
  (canDBus!(Tuple!(int[],bool))).assertTrue();
  (canDBus!(Tuple!(int[],int[string]))).assertFalse();
  (canDBus!(int[string])).assertFalse();
}

string typeSig(T)() if(canDBus!T) {
  static if(is(T == byte)) {
    return "y";
  } else static if(is(T == bool)) {
    return "b";
  } else static if(is(T == short)) {
    return "n";
  } else static if(is(T == ushort)) {
    return "q";
  } else static if(is(T == int)) {
    return "i";
  } else static if(is(T == uint)) {
    return "u";
  } else static if(is(T == long)) {
    return "x";
  } else static if(is(T == ulong)) {
    return "t";
  } else static if(is(T == double)) {
    return "d";
  } else static if(is(T == string)) {
    return "s";
  } else static if(isTuple!T) {
    string sig = "(";
    foreach(i, S; T.Types) {
      sig ~= typeSig!S();
    } 
    sig ~= ")";
    return sig;
  } else static if(isInputRange!T) {
    return "a" ~ typeSig!(ElementType!T)();
  }
}

string typeSigAll(TS...)() if(allCanDBus!TS) {
  string sig = "";
  foreach(i,T; TS) {
    sig ~= typeSig!T();
  }
  return sig;
}

int typeCode(T)() if(canDBus!T) {
  string sig = typeSig!T();
  return sig[0];
}

unittest {
  import dunit.toolkit;
  // basics
  typeSig!int().assertEqual("i");
  typeSig!bool().assertEqual("b");
  typeSig!string().assertEqual("s");
  // structs
  typeSig!(Tuple!(int,string,string)).assertEqual("(iss)");
  typeSig!(Tuple!(int,string,Tuple!(int,"k",double,"x"))).assertEqual("(is(id))");
  // arrays
  typeSig!(int[]).assertEqual("ai");
  typeSig!(Tuple!(byte)[][]).assertEqual("aa(y)");
  // multiple arguments
  typeSigAll!(int,bool).assertEqual("ib");
  // type codes
  typeCode!int().assertEqual(cast(int)('i'));
  typeCode!bool().assertEqual(cast(int)('b'));
  // ctfe-capable
  static string sig = typeSig!ulong();
  sig.assertEqual("t");
  static string sig2 = typeSig!(Tuple!(int,string,string));
  sig2.assertEqual("(iss)"); 
  static string sig3 = typeSigAll!(int,string,string);
  sig3.assertEqual("iss"); 
}


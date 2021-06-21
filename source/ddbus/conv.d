module ddbus.conv;

import ddbus.attributes : isAllowedField;
import ddbus.c_lib;
import ddbus.exception : InvalidValueException, TypeMismatchException;
import ddbus.util;
import ddbus.thin;

import std.exception : enforce;
import std.meta : allSatisfy;
import std.string;
import std.typecons;
import std.range;
import std.traits;
import std.variant : VariantN;

void buildIter(TS...)(DBusMessageIter* iter, TS args)
    if (allCanDBus!TS) {
  foreach (index, arg; args) {
    alias T = Unqual!(TS[index]);
    static if (is(T == string) || is(T == InterfaceName) || is(T == BusName)) {
      immutable(char)* cStr = arg.toStringz();
      dbus_message_iter_append_basic(iter, typeCode!T, &cStr);
    } else static if (is(T == ObjectPath)) {
      immutable(char)* cStr = arg.toString().toStringz();
      dbus_message_iter_append_basic(iter, typeCode!T, &cStr);
    } else static if (is(T == bool)) {
      dbus_bool_t longerBool = arg; // dbus bools are ints
      dbus_message_iter_append_basic(iter, typeCode!T, &longerBool);
    } else static if (isTuple!T) {
      DBusMessageIter sub;
      dbus_message_iter_open_container(iter, 'r', null, &sub);
      buildIter(&sub, arg.expand);
      dbus_message_iter_close_container(iter, &sub);
    } else static if (isInputRange!T) {
      DBusMessageIter sub;
      const(char)* subSig = (typeSig!(ElementType!T)()).toStringz();
      dbus_message_iter_open_container(iter, 'a', subSig, &sub);
      foreach (x; arg) {
        static if (isInstanceOf!(DictionaryEntry, typeof(x))) {
          DBusMessageIter entry;
          dbus_message_iter_open_container(&sub, 'e', null, &entry);
          buildIter(&entry, x.key);
          buildIter(&entry, x.value);
          dbus_message_iter_close_container(&sub, &entry);
        } else {
          buildIter(&sub, x);
        }
      }
      dbus_message_iter_close_container(iter, &sub);
    } else static if (isAssociativeArray!T) {
      DBusMessageIter sub;
      const(char)* subSig = typeSig!T[1 .. $].toStringz();
      dbus_message_iter_open_container(iter, 'a', subSig, &sub);
      foreach (k, v; arg) {
        DBusMessageIter entry;
        dbus_message_iter_open_container(&sub, 'e', null, &entry);
        buildIter(&entry, k);
        buildIter(&entry, v);
        dbus_message_iter_close_container(&sub, &entry);
      }
      dbus_message_iter_close_container(iter, &sub);
    } else static if (isInstanceOf!(VariantN, T)) {
      enforce(arg.hasValue, new InvalidValueException(arg, "dbus:" ~ cast(char) typeCode!T));

      DBusMessageIter sub;
      foreach (AT; T.AllowedTypes) {
        if (arg.peek!AT) {
          dbus_message_iter_open_container(iter, 'v', typeSig!AT.ptr, &sub);
          buildIter(&sub, arg.get!AT);
          dbus_message_iter_close_container(iter, &sub);
          break;
        }
      }
    } else static if (is(T == DBusAny) || is(T == Variant!DBusAny)) {
      static if (is(T == Variant!DBusAny)) {
        auto val = arg.data;
        val.explicitVariant = true;
      } else {
        auto val = arg;
      }
      DBusMessageIter subStore;
      DBusMessageIter* sub = &subStore;
      const(char)[] sig = [cast(char) val.type];
      if (val.type == 'a') {
        sig ~= val.signature;
      } else if (val.type == 'r') {
        sig = val.signature;
      }

      sig ~= '\0';

      if (!val.explicitVariant) {
        sub = iter;
      } else {
        dbus_message_iter_open_container(iter, 'v', sig.ptr, sub);
      }

      if (val.type == 's') {
        buildIter(sub, val.str);
      } else if (val.type == 'o') {
        buildIter(sub, val.obj);
      } else if (val.type == 'b') {
        buildIter(sub, val.boolean);
      } else if (dbus_type_is_basic(val.type)) {
        dbus_message_iter_append_basic(sub, val.type, &val.int64);
      } else if (val.type == 'a') {
        DBusMessageIter arr;
        dbus_message_iter_open_container(sub, 'a', sig[1 .. $].ptr, &arr);

        if (val.signature == ['y']) {
          foreach (item; val.binaryData) {
            dbus_message_iter_append_basic(&arr, 'y', &item);
          }
        } else {
          foreach (item; val.array) {
            buildIter(&arr, item);
          }
        }

        dbus_message_iter_close_container(sub, &arr);
      } else if (val.type == 'r') {
        DBusMessageIter arr;
        dbus_message_iter_open_container(sub, 'r', null, &arr);

        foreach (item; val.tuple) {
          buildIter(&arr, item);
        }

        dbus_message_iter_close_container(sub, &arr);
      } else if (val.type == 'e') {
        DBusMessageIter entry;
        dbus_message_iter_open_container(sub, 'e', null, &entry);
        buildIter(&entry, val.entry.key);
        buildIter(&entry, val.entry.value);
        dbus_message_iter_close_container(sub, &entry);
      }

      if (val.explicitVariant) {
        dbus_message_iter_close_container(iter, sub);
      }
    } else static if (isInstanceOf!(Variant, T)) {
      DBusMessageIter sub;
      const(char)* subSig = typeSig!(VariantType!T).toStringz();
      dbus_message_iter_open_container(iter, 'v', subSig, &sub);
      buildIter(&sub, arg.data);
      dbus_message_iter_close_container(iter, &sub);
    } else static if (is(T == struct)) {
      DBusMessageIter sub;
      dbus_message_iter_open_container(iter, 'r', null, &sub);

      // Following failed because of missing 'this' for members of arg.
      // That sucks. It worked without Filter.
      // Reported: https://issues.dlang.org/show_bug.cgi?id=17692
      //    buildIter(&sub, Filter!(isAllowedField, arg.tupleof));

      // Using foreach to work around the issue
      foreach (i, member; arg.tupleof) {
        // Ugly, but we need to use tupleof again in the condition, because when
        // we use `member`, isAllowedField will fail because it'll find this
        // nice `buildIter` function instead of T when it looks up the parent
        // scope of its argument.
        static if (isAllowedField!(arg.tupleof[i]))
          buildIter(&sub, member);
      }

      dbus_message_iter_close_container(iter, &sub);
    } else static if (basicDBus!T) {
      dbus_message_iter_append_basic(iter, typeCode!T, &arg);
    }
  }
}

T readIter(T)(DBusMessageIter* iter)
    if (is(T == enum) && !is(Unqual!T == InterfaceName) && !is(Unqual!T == BusName) && !is(Unqual!T == FileDescriptor)) {
  import std.algorithm.searching : canFind;

  alias B = Unqual!(OriginalType!T);

  B value = readIter!B(iter);
  enforce(only(EnumMembers!T).canFind(value), new InvalidValueException(value, T.stringof));
  return cast(T) value;
}

T readIter(T)(DBusMessageIter* iter)
    if (isInstanceOf!(BitFlags, T)) {
  import std.algorithm.iteration : fold;

  alias TemplateArgsOf!T[0] E;
  alias OriginalType!E B;

  B mask = only(EnumMembers!E).fold!((a, b) => cast(B)(a | b));

  B value = readIter!B(iter);
  enforce(!(value & ~mask), new InvalidValueException(value, T.stringof));

  return T(cast(E) value);
}

U readIter(U)(DBusMessageIter* iter)
    if (!(is(U == enum) && !is(Unqual!U == InterfaceName) && !is(Unqual!U == BusName) && !is(U == FileDescriptor)) 
    && !isInstanceOf!(BitFlags, U) && canDBus!U) {
  alias T = Unqual!U;

  auto argType = dbus_message_iter_get_arg_type(iter);
  T ret;

  static if (!isInstanceOf!(Variant, T) || is(T == Variant!DBusAny)) {
    if (argType == 'v') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      static if (is(T == Variant!DBusAny)) {
        ret = variant(readIter!DBusAny(&sub));
      } else {
        ret = readIter!T(&sub);
        static if (is(T == DBusAny))
          ret.explicitVariant = true;
      }
      dbus_message_iter_next(iter);
      return cast(U) ret;
    }
  }

  static if (!is(T == DBusAny) && !is(T == Variant!DBusAny) && !isInstanceOf!(VariantN, T)) {
    enforce(argType == typeCode!T(), new TypeMismatchException(typeCode!T(), argType));
  }

  static if (is(T == string) || is(T == InterfaceName) || is(T == BusName) || is(T == ObjectPath)) {
    const(char)* cStr;
    dbus_message_iter_get_basic(iter, &cStr);
    string str = cStr.fromStringz().idup; // copy string
    static if (is(T == string) || is(T : InterfaceName) || is(T : BusName)) {
      ret = cast(T)str;
    } else {
      ret = ObjectPath(str);
    }
  } else static if (is(T == bool)) {
    dbus_bool_t longerBool;
    dbus_message_iter_get_basic(iter, &longerBool);
    ret = cast(bool) longerBool;
  } else static if (isTuple!T) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    readIterTuple!T(&sub, ret);
  } else static if (is(T t : S[], S)) {
    assert(dbus_message_iter_get_element_type(iter) == typeCode!S);

    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);

    while (dbus_message_iter_get_arg_type(&sub) != 0) {
      static if (is(S == DictionaryEntry!(K, V), K, V)) {
        DBusMessageIter entry;
        dbus_message_iter_recurse(&sub, &entry);
        ret ~= S(readIter!K(&entry), readIter!V(&entry));
        dbus_message_iter_next(&sub);
      } else {
        ret ~= readIter!S(&sub);
      }
    }
  } else static if (isInstanceOf!(Variant, T)) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    ret.data = readIter!(VariantType!T)(&sub);
  } else static if (isInstanceOf!(VariantN, T)) {
    scope const(char)[] argSig = dbus_message_iter_get_signature(iter).fromStringz();
    scope (exit)
      dbus_free(cast(void*) argSig.ptr);

    foreach (AT; T.AllowedTypes) {
      // We have to compare the full signature here, not just the typecode.
      // Otherwise, in case of container types, we might select the wrong one.
      // We would then be calling an incorrect instance of readIter, which would
      // probably throw a TypeMismatchException.
      if (typeSig!AT == argSig) {
        ret = readIter!AT(iter);
        break;
      }
    }

    // If no value is in ret, apparently none of the types matched.
    enforce(ret.hasValue, new TypeMismatchException(typeCode!T, argType));
  } else static if (isAssociativeArray!T) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);

    while (dbus_message_iter_get_arg_type(&sub) != 0) {
      DBusMessageIter entry;
      dbus_message_iter_recurse(&sub, &entry);
      auto k = readIter!(KeyType!T)(&entry);
      auto v = readIter!(ValueType!T)(&entry);
      ret[k] = v;
      dbus_message_iter_next(&sub);
    }
  } else static if (is(T == DBusAny)) {
    ret.type = argType;
    ret.explicitVariant = false;

    if (ret.type == 's') {
      ret.str = readIter!string(iter);
      return cast(U) ret;
    } else if (ret.type == 'o') {
      ret.obj = readIter!ObjectPath(iter);
      return cast(U) ret;
    } else if (ret.type == 'b') {
      ret.boolean = readIter!bool(iter);
      return cast(U) ret;
    } else if (dbus_type_is_basic(ret.type)) {
      dbus_message_iter_get_basic(iter, &ret.int64);
    } else if (ret.type == 'a') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      auto sig = dbus_message_iter_get_signature(&sub);
      ret.signature = sig.fromStringz.dup;
      dbus_free(sig);
      if (ret.signature == ['y']) {
        while (dbus_message_iter_get_arg_type(&sub) != 0) {
          ubyte b;
          assert(dbus_message_iter_get_arg_type(&sub) == 'y');
          dbus_message_iter_get_basic(&sub, &b);
          dbus_message_iter_next(&sub);
          ret.binaryData ~= b;
        }
      } else {
        while (dbus_message_iter_get_arg_type(&sub) != 0) {
          ret.array ~= readIter!DBusAny(&sub);
        }
      }
    } else if (ret.type == 'r') {
      auto sig = dbus_message_iter_get_signature(iter);
      ret.signature = sig.fromStringz.dup;
      dbus_free(sig);

      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);

      while (dbus_message_iter_get_arg_type(&sub) != 0) {
        ret.tuple ~= readIter!DBusAny(&sub);
      }
    } else if (ret.type == 'e') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);

      ret.entry = new DictionaryEntry!(DBusAny, DBusAny);
      ret.entry.key = readIter!DBusAny(&sub);
      ret.entry.value = readIter!DBusAny(&sub);
    }
  } else static if (is(T == struct)) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    readIterStruct!T(&sub, ret);
  } else static if (basicDBus!T) {
    dbus_message_iter_get_basic(iter, &ret);
  }

  dbus_message_iter_next(iter);
  return cast(U) ret;
}

void readIterTuple(Tup)(DBusMessageIter* iter, ref Tup tuple)
    if (isTuple!Tup && allCanDBus!(Tup.Types)) {
  foreach (index, T; Tup.Types) {
    tuple[index] = readIter!T(iter);
  }
}

void readIterStruct(S)(DBusMessageIter* iter, ref S s)
    if (is(S == struct) && canDBus!S) {
  foreach (index, T; Fields!S) {
    static if (isAllowedField!(s.tupleof[index])) {
      s.tupleof[index] = readIter!T(iter);
    }
  }
}

unittest {
  import dunit.toolkit;
  import ddbus.thin;

  Variant!T var(T)(T data) {
    return Variant!T(data);
  }

  Message msg = Message(busName("org.example.wow"), ObjectPath("/wut"), interfaceName("org.test.iface"), "meth");
  bool[] emptyB;
  string[string] map;
  map["hello"] = "world";
  DBusAny anyVar = DBusAny(cast(ulong) 1561);
  anyVar.type.assertEqual('t');
  anyVar.uint64.assertEqual(1561);
  anyVar.explicitVariant.assertEqual(false);
  auto tupleMember = DBusAny(tuple(Variant!int(45), Variant!ushort(5), 32,
      [1, 2], tuple(variant(4), 5), map));
  Variant!DBusAny complexVar = variant(DBusAny([
        "hello world": variant(DBusAny(1337)),
        "array value": variant(DBusAny([42, 64])),
        "tuple value": variant(tupleMember),
        "optimized binary data": variant(DBusAny(cast(ubyte[])[1, 2, 3, 4, 5, 6]))
      ]));
  complexVar.data.type.assertEqual('a');
  complexVar.data.signature.assertEqual("{sv}".dup);
  tupleMember.signature.assertEqual("(vviai(vi)a{ss})");

  auto args = tuple(5, true, "wow", interfaceName("methodName"), var(5.9), [6, 5], tuple(6.2, 4, [["lol"]],
      emptyB, var([4, 2])), map, anyVar, complexVar);
  msg.build(args.expand);
  msg.signature().assertEqual("ibssvai(diaasabv)a{ss}tv");

  msg.read!string().assertThrow!TypeMismatchException();
  msg.readTuple!(Tuple!(int, bool, double)).assertThrow!TypeMismatchException();
  msg.readTuple!(Tuple!(int, bool, string, InterfaceName, double))
    .assertEqual(tuple(5, true, "wow", interfaceName("methodName"), 5.9));

  msg.readTuple!(typeof(args))().assertEqual(args);
  DBusMessageIter iter;
  dbus_message_iter_init(msg.msg, &iter);
  readIter!int(&iter).assertEqual(5);
  readIter!bool(&iter).assertEqual(true);
  readIter!string(&iter).assertEqual("wow");
  readIter!InterfaceName(&iter).assertEqual(interfaceName("methodName"));
  readIter!double(&iter).assertEqual(5.9);
  readIter!(int[])(&iter).assertEqual([6, 5]);
  readIter!(Tuple!(double, int, string[][], bool[], Variant!(int[])))(&iter).assertEqual(
      tuple(6.2, 4, [["lol"]], emptyB, var([4, 2])));

  // There are two ways to read a dictionary, so duplicate the iterator to test both.
  auto iter2 = iter;
  readIter!(string[string])(&iter).assertEqual(["hello": "world"]);
  auto dict = readIter!(DictionaryEntry!(string, string)[])(&iter2);
  dict.length.assertEqual(1);
  dict[0].key.assertEqual("hello");
  dict[0].value.assertEqual("world");

  readIter!DBusAny(&iter).assertEqual(anyVar);
  readIter!(Variant!DBusAny)(&iter).assertEqual(complexVar);
}

unittest {
  import dunit.toolkit;
  import ddbus.thin;

  import std.variant : Algebraic;

  enum E : int {
    a,
    b,
    c
  }

  enum F : uint {
    x = 1,
    y = 2,
    z = 4
  }

  alias V = Algebraic!(ubyte, short, int, long, string);

  Message msg = Message(busName("org.example.wow"), ObjectPath("/wut"), interfaceName("org.test.iface"), "meth2");
  V v1 = "hello from variant";
  V v2 = cast(short) 345;
  msg.build(E.c, 4, 5u, 8u, v1, v2);

  DBusMessageIter iter, iter2;
  dbus_message_iter_init(msg.msg, &iter);

  readIter!E(&iter).assertEqual(E.c);
  readIter!E(&iter).assertThrow!InvalidValueException();

  iter2 = iter;
  readIter!F(&iter).assertThrow!InvalidValueException();
  readIter!(BitFlags!F)(&iter2).assertEqual(BitFlags!F(F.x, F.z));

  readIter!F(&iter).assertThrow!InvalidValueException();
  readIter!(BitFlags!F)(&iter2).assertThrow!InvalidValueException();

  readIter!V(&iter).assertEqual(v1);
  readIter!short(&iter).assertEqual(v2.get!short);
}

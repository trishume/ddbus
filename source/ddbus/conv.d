module ddbus.conv;

import ddbus.c_lib;
import ddbus.util;
import std.string;
import std.typecons;
import std.range;
import std.traits;

void buildIter(TS...)(DBusMessageIter *iter, TS args) if(allCanDBus!TS) {
  foreach(index, arg; args) {
    alias TS[index] T;
    static if(is(T == string)) {
      immutable(char)* cStr = arg.toStringz();
      dbus_message_iter_append_basic(iter,typeCode!T,&cStr);
    } else static if(is(T==bool)) {
      dbus_bool_t longerBool = arg; // dbus bools are ints
      dbus_message_iter_append_basic(iter,typeCode!T,&longerBool);
    } else static if(isTuple!T) {
      DBusMessageIter sub;
      dbus_message_iter_open_container(iter, 'r', null, &sub);
      buildIter(&sub, arg.expand);
      dbus_message_iter_close_container(iter, &sub);
    } else static if(isInputRange!T) {
      DBusMessageIter sub;
      const(char)* subSig = (typeSig!(ElementType!T)()).toStringz();
      dbus_message_iter_open_container(iter, 'a', subSig, &sub);
      foreach(x; arg) {
        buildIter(&sub, x);
      }
      dbus_message_iter_close_container(iter, &sub);
    } else static if(isAssociativeArray!T) {
      buildIter(iter, arg.byDictionaryEntries);
    } else static if(isVariant!T) {
      DBusMessageIter sub;
      const(char)* subSig = typeSig!(VariantType!T).toStringz();
      dbus_message_iter_open_container(iter, 'v', subSig, &sub);
      buildIter(&sub, arg.data);
      dbus_message_iter_close_container(iter, &sub);
    } else static if(is(T == DictionaryEntry!(K, V), K, V)) {
      DBusMessageIter sub;
      dbus_message_iter_open_container(iter, 'e', null, &sub);
      buildIter(&sub, arg.key);
      buildIter(&sub, arg.value);
      dbus_message_iter_close_container(iter, &sub);
    } else static if(basicDBus!T) {
      dbus_message_iter_append_basic(iter,typeCode!T,&arg);
    }
  }
}

T readIter(T)(DBusMessageIter *iter) if (canDBus!T) {
  T ret;
  static if(!isVariant!T) {
    if(dbus_message_iter_get_arg_type(iter) == 'v') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      ret = readIter!T(&sub);
      dbus_message_iter_next(iter);
      return ret;
    }
  }
  static if(isTuple!T) {
    assert(dbus_message_iter_get_arg_type(iter) == 'r');
  } else static if(is(T == DictionaryEntry!(K1, V1), K1, V1)) {
    assert(dbus_message_iter_get_arg_type(iter) == 'e');
  } else {
    assert(dbus_message_iter_get_arg_type(iter) == typeCode!T());
  }
  static if(is(T==string)) {
    const(char)* cStr;
    dbus_message_iter_get_basic(iter, &cStr);
    ret = cStr.fromStringz().idup; // copy string
  } else static if(is(T==bool)) {
    dbus_bool_t longerBool;
    dbus_message_iter_get_basic(iter, &longerBool);
    ret = cast(bool)longerBool;
  } else static if(isTuple!T) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    readIterTuple!T(&sub, ret);
  } else static if(is(T == DictionaryEntry!(K, V), K, V)) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    ret.key = readIter!K(&sub);
    ret.value = readIter!V(&sub);
  } else static if(is(T t : U[], U)) {
    assert(dbus_message_iter_get_element_type(iter) == typeCode!U);
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    while(dbus_message_iter_get_arg_type(&sub) != 0) {
      ret ~= readIter!U(&sub);
    }
  } else static if(isVariant!T) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    ret.data = readIter!(VariantType!T)(&sub);
  } else static if(isAssociativeArray!T) {
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    while(dbus_message_iter_get_arg_type(&sub) != 0) {
      auto entry = readIter!(DictionaryEntry!(KeyType!T, ValueType!T))(&sub);
      ret[entry.key] = entry.value;
    }
  } else static if(basicDBus!T) {
    dbus_message_iter_get_basic(iter, &ret);
  }
  dbus_message_iter_next(iter);
  return ret;
}

void readIterTuple(Tup)(DBusMessageIter *iter, ref Tup tuple) if(isTuple!Tup && allCanDBus!(Tup.Types)) {
  foreach(index, T; Tup.Types) {
    tuple[index] = readIter!T(iter);
  }
}

unittest {
  import dunit.toolkit;
  import ddbus.thin;
  Variant!T var(T)(T data){ return Variant!T(data); }
  Message msg = Message("org.example.wow","/wut","org.test.iface","meth");
  bool[] emptyB;
  string[string] map;
  map["hello"] = "world";
  auto args = tuple(5,true,"wow",var(5.9),[6,5],tuple(6.2,4,[["lol"]],emptyB,var([4,2])),map);
  msg.build(args.expand);
  msg.signature().assertEqual("ibsvai(diaasabv)a{ss}");
  msg.readTuple!(typeof(args))().assertEqual(args);
  DBusMessageIter iter;
  dbus_message_iter_init(msg.msg, &iter);
  readIter!int(&iter).assertEqual(5);
  readIter!bool(&iter).assertEqual(true);
  readIter!string(&iter).assertEqual("wow");
  readIter!double(&iter).assertEqual(5.9);
  readIter!(int[])(&iter).assertEqual([6,5]);
  readIter!(Tuple!(double,int,string[][],bool[],Variant!(int[])))(&iter).assertEqual(tuple(6.2,4,[["lol"]],emptyB,var([4,2])));
  readIter!(string[string])(&iter).assertEqual(["hello": "world"]);
}

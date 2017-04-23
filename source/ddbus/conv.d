module ddbus.conv;

import ddbus.c_lib;
import ddbus.util;
import ddbus.thin;
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
    } else static if(is(T == DBusAny)) {
      DBusMessageIter subStore;
      DBusMessageIter* sub = &subStore;
      char[] sig = [cast(char) arg.type];
      if(arg.type == 'a')
        sig ~= arg.signature;
      else if(arg.type == 'r')
        sig = arg.signature;
      sig ~= '\0';
      if (!arg.explicitVariant)
        sub = iter;
      else
        dbus_message_iter_open_container(iter, 'v', sig.ptr, sub);
      if(arg.type == 's') {
        immutable(char)* cStr = arg.str.toStringz();
        dbus_message_iter_append_basic(sub,'s',&cStr);
      } else if(arg.type == 'b') {
        dbus_bool_t longerBool = arg.boolean; // dbus bools are ints
        dbus_message_iter_append_basic(sub,'b',&longerBool);
      } else if(dbus_type_is_basic(arg.type)) {
        dbus_message_iter_append_basic(sub,arg.type,&arg.int64);
      } else if(arg.type == 'a') {
        DBusMessageIter arr;
        dbus_message_iter_open_container(sub, 'a', sig[1 .. $].ptr, &arr);
        foreach(item; arg.array)
          buildIter(&arr, item);
        dbus_message_iter_close_container(sub, &arr);
      } else if(arg.type == 'r') {
        DBusMessageIter arr;
        dbus_message_iter_open_container(sub, 'r', null, &arr);
        foreach(item; arg.tuple)
          buildIter(&arr, item);
        dbus_message_iter_close_container(sub, &arr);
      } else if(arg.type == 'e') {
        DBusMessageIter entry;
        dbus_message_iter_open_container(sub, 'e', null, &entry);
        buildIter(&entry, arg.entry.key);
        buildIter(&entry, arg.entry.value);
        dbus_message_iter_close_container(sub, &entry);
      }
      if(arg.explicitVariant)
        dbus_message_iter_close_container(iter, sub);
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
      static if(is(T == DBusAny))
        ret.explicitVariant = true;
      dbus_message_iter_next(iter);
      return ret;
    }
  }
  static if(isTuple!T) {
    assert(dbus_message_iter_get_arg_type(iter) == 'r');
  } else static if(is(T == DictionaryEntry!(K1, V1), K1, V1)) {
    assert(dbus_message_iter_get_arg_type(iter) == 'e');
  } else static if(!is(T == DBusAny)) {
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
  } else static if(is(T == DBusAny)) {
    ret.type = dbus_message_iter_get_arg_type(iter);
    ret.explicitVariant = false;
    if(ret.type == 's') {
      const(char)* cStr;
      dbus_message_iter_get_basic(iter, &cStr);
      ret.str = cStr.fromStringz().idup; // copy string
    } else if(ret.type == 'b') {
      dbus_bool_t longerBool;
      dbus_message_iter_get_basic(iter, &longerBool);
      ret.boolean = cast(bool)longerBool;
    } else if(dbus_type_is_basic(ret.type)) {
      dbus_message_iter_get_basic(iter, &ret.int64);
    } else if(ret.type == 'a') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      auto sig = dbus_message_iter_get_signature(&sub);
      ret.signature = sig.fromStringz.dup;
      dbus_free(sig);
      while(dbus_message_iter_get_arg_type(&sub) != 0) {
        ret.array ~= readIter!DBusAny(&sub);
      }
    } else if(ret.type == 'r') {
      auto sig = dbus_message_iter_get_signature(iter);
      ret.signature = sig.fromStringz.dup;
      dbus_free(sig);
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      while(dbus_message_iter_get_arg_type(&sub) != 0) {
        ret.tuple ~= readIter!DBusAny(&sub);
      }
    } else if(ret.type == 'e') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      ret.entry = new DictionaryEntry!(DBusAny, DBusAny);
      ret.entry.key = readIter!DBusAny(&sub);
      ret.entry.value = readIter!DBusAny(&sub);
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
  DBusAny anyVar = DBusAny(cast(ulong) 1561);
  anyVar.type.assertEqual('t');
  anyVar.uint64.assertEqual(1561);
  anyVar.explicitVariant.assertEqual(false);
  auto tupleMember = DBusAny(tuple(Variant!int(45), Variant!ushort(5), 32, [1, 2], tuple(variant(4), 5), map));
  DBusAny complexVar = DBusAny(variant([
    "hello world": variant(DBusAny(1337)),
    "array value": variant(DBusAny([42, 64])),
    "tuple value": variant(tupleMember)
  ]));
  complexVar.type.assertEqual('a');
  complexVar.signature.assertEqual("{sv}".dup);
  tupleMember.signature.assertEqual("(vviai(vi)a{ss})");
  auto args = tuple(5,true,"wow",var(5.9),[6,5],tuple(6.2,4,[["lol"]],emptyB,var([4,2])),map,anyVar,complexVar);
  msg.build(args.expand);
  msg.signature().assertEqual("ibsvai(diaasabv)a{ss}tv");
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
  readIter!DBusAny(&iter).assertEqual(anyVar);
  readIter!DBusAny(&iter).assertEqual(complexVar);
}

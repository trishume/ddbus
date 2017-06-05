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
    } else static if(is(T == DBusAny) || is(T == Variant!DBusAny)) {
      static if(is(T == Variant!DBusAny)) {
        auto val = arg.data;
        val.explicitVariant = true;
      } else {
        auto val = arg;
      }
      DBusMessageIter subStore;
      DBusMessageIter* sub = &subStore;
      const(char)[] sig = [ cast(char) val.type ];
      if(val.type == 'a')
        sig ~= val.signature;
      else if(val.type == 'r')
        sig = val.signature;
      sig ~= '\0';
      if (!val.explicitVariant)
        sub = iter;
      else
        dbus_message_iter_open_container(iter, 'v', sig.ptr, sub);
      if(val.type == 's') {
        buildIter(sub, val.str);
      } else if(val.type == 'b') {
        buildIter(sub,val.boolean);
      } else if(dbus_type_is_basic(val.type)) {
        dbus_message_iter_append_basic(sub,val.type,&val.int64);
      } else if(val.type == 'a') {
        DBusMessageIter arr;
        dbus_message_iter_open_container(sub, 'a', sig[1 .. $].ptr, &arr);
        if (val.signature == ['y'])
          foreach (item; val.binaryData)
            dbus_message_iter_append_basic(&arr, 'y', &item);
        else
          foreach(item; val.array)
            buildIter(&arr, item);
        dbus_message_iter_close_container(sub, &arr);
      } else if(val.type == 'r') {
        DBusMessageIter arr;
        dbus_message_iter_open_container(sub, 'r', null, &arr);
        foreach(item; val.tuple)
          buildIter(&arr, item);
        dbus_message_iter_close_container(sub, &arr);
      } else if(val.type == 'e') {
        DBusMessageIter entry;
        dbus_message_iter_open_container(sub, 'e', null, &entry);
        buildIter(&entry, val.entry.key);
        buildIter(&entry, val.entry.value);
        dbus_message_iter_close_container(sub, &entry);
      }
      if(val.explicitVariant)
        dbus_message_iter_close_container(iter, sub);
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
  static if(!isVariant!T || is(T == Variant!DBusAny)) {
    if(dbus_message_iter_get_arg_type(iter) == 'v') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      static if(is(T == Variant!DBusAny)) {
        ret = variant(readIter!DBusAny(&sub));
      } else {
        ret = readIter!T(&sub);
        static if(is(T == DBusAny))
          ret.explicitVariant = true;
      }
      dbus_message_iter_next(iter);
      return ret;
    }
  }
  static if(isTuple!T) {
    assert(dbus_message_iter_get_arg_type(iter) == 'r');
  } else static if(is(T == DictionaryEntry!(K1, V1), K1, V1)) {
    assert(dbus_message_iter_get_arg_type(iter) == 'e');
  } else static if(!is(T == DBusAny) && !is(T == Variant!DBusAny)) {
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
      ret.str = readIter!string(iter);
      return ret;
    } else if(ret.type == 'b') {
      ret.boolean = readIter!bool(iter);
      return ret;
    } else if(dbus_type_is_basic(ret.type)) {
      dbus_message_iter_get_basic(iter, &ret.int64);
    } else if(ret.type == 'a') {
      DBusMessageIter sub;
      dbus_message_iter_recurse(iter, &sub);
      auto sig = dbus_message_iter_get_signature(&sub);
      ret.signature = sig.fromStringz.dup;
      dbus_free(sig);
      if (ret.signature == ['y'])
        while(dbus_message_iter_get_arg_type(&sub) != 0) {
          ubyte b;
          assert(dbus_message_iter_get_arg_type(&sub) == 'y');
          dbus_message_iter_get_basic(&sub, &b);
          dbus_message_iter_next(&sub);
          ret.binaryData ~= b;
        }
      else
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
  Variant!DBusAny complexVar = variant(DBusAny([
    "hello world": variant(DBusAny(1337)),
    "array value": variant(DBusAny([42, 64])),
    "tuple value": variant(tupleMember),
    "optimized binary data": variant(DBusAny(cast(ubyte[]) [1, 2, 3, 4, 5, 6]))
  ]));
  complexVar.data.type.assertEqual('a');
  complexVar.data.signature.assertEqual("{sv}".dup);
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
  readIter!(Variant!DBusAny)(&iter).assertEqual(complexVar);
}

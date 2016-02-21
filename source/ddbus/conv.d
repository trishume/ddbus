module ddbus.conv;

import ddbus.c_lib;
import ddbus.util;
import std.string;
import std.typecons;
import std.range;

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
      DBusMessageIter sub;
      const(char)* subSig = (typeSig!T())[1..$].toStringz(); // trim off "a" with slice syntax
      dbus_message_iter_open_container(iter, 'a', subSig, &sub);
      foreach(x; arg.byKeyValue()) {
        DBusMessageIter subsub;
        dbus_message_iter_open_container(sub, 'e', null, &subsub);
        buildIter(&subsub, x.key, x.value);
        dbus_message_iter_close_container(sub, &subsub);
      }
      dbus_message_iter_close_container(iter, &sub);
    } else static if(basicDBus!T) {
      dbus_message_iter_append_basic(iter,typeCode!T,&arg);
    }
  }
}

T readIter(T)(DBusMessageIter *iter) if (canDBus!T) {
  T ret;
  assert(dbus_message_iter_get_arg_type(iter) == typeCode!T());
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
  } else static if(is(T t : U[], U)) {
    assert(dbus_message_iter_get_element_type(iter) == typeCode!U);
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    while(dbus_message_iter_get_arg_type(&sub) != 0) {
      ret ~= readIter!U(&sub);
    }
  } else static if(isAssociativeArray!T) {
    assert(dbus_message_iter_get_element_type(iter) == 'e');
    DBusMessageIter sub;
    dbus_message_iter_recurse(iter, &sub);
    while(dbus_message_iter_get_arg_type(&sub) != 0) {
      DBusMessageIter subsub;
      dbus_message_iter_recurse(sub, &subsub);
      ret[readIter!(KeyType!T)(subsub)] = readIter!(ValueType!T)(subsub);
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
  Message msg = Message("org.example.wow","/wut","org.test.iface","meth");
  bool[] emptyB;
  auto args = tuple(5,true,"wow",[6,5],tuple(6.2,4,[["lol"]],emptyB));
  msg.build(args.expand);
  msg.signature().assertEqual("ibsai(diaasab)");
  msg.readTuple!(typeof(args))().assertEqual(args);
  DBusMessageIter iter;
  dbus_message_iter_init(msg.msg, &iter);
  readIter!int(&iter).assertEqual(5);
  readIter!bool(&iter).assertEqual(true);
  readIter!string(&iter).assertEqual("wow");
  readIter!(int[])(&iter).assertEqual([6,5]);
  readIter!(Tuple!(double,int,string[][],bool[]))(&iter).assertEqual(tuple(6.2,4,[["lol"]],emptyB));
}

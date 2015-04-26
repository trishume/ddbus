import std.stdio;
import ddbus.c_lib;

void main()
{
  DBusError err;
  dbus_error_init(&err);
  DBusMessage *msg = dbus_message_new_method_call("org.blah.lolbus","/root","org.blah.iface","testStuff");
  dbus_int32_t arg = 5;
  dbus_message_append_args(msg, 'i', &arg, '\0');
  dbus_int32_t arg_out;
  dbus_message_get_args(msg,&err,'i',&arg_out);
  dbus_message_unref(msg);
  assert(arg_out == arg);
	writeln("It worked!");
}

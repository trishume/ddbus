module ddbus.bus;

import ddbus.router;
import ddbus.thin;
import ddbus.c_lib;
import std.string;

enum BusService = "org.freedesktop.DBus";
enum BusPath = "/org/freedesktop/DBus";
enum BusInterface = "org.freedesktop.DBus";

enum NameFlags {
  AllowReplace = 1,
  ReplaceExisting = 2,
  NoQueue = 4
}

/// Requests a DBus well-known name.
/// returns if the name is owned after the call.
/// Involves blocking call on a DBus method, may throw an exception on failure.
bool requestName(Connection conn, string name,
    NameFlags flags = NameFlags.NoQueue | NameFlags.AllowReplace) {
  auto msg = Message(BusService, BusPath, BusInterface, "RequestName");
  msg.build(name, cast(uint)(flags));
  auto res = conn.sendWithReplyBlocking(msg).to!uint;
  return (res == 1) || (res == 4);
}

/// A simple main loop that isn't necessarily efficient
/// and isn't guaranteed to work with other tasks and threads.
/// Use only for apps that only do DBus triggered things.
void simpleMainLoop(Connection conn) {
  while (dbus_connection_read_write_dispatch(conn.conn, -1)) {
  } // empty loop body
}

/// Single tick in the DBus connection which can be used for
/// concurrent updates.
bool tick(Connection conn) {
  return cast(bool) dbus_connection_read_write_dispatch(conn.conn, 0);
}

unittest {
  import dunit.toolkit;

  Connection conn = connectToBus();
  conn.requestName("ca.thume.ddbus.testing").assertTrue();
}

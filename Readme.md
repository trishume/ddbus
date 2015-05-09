# ddbus

A [dbus](http://www.freedesktop.org/wiki/Software/dbus/) library for the [D programming language](http://dlang.org).

Provides fancy and convenient highly templated methods that automagically serialize and deserialize things into DBus types so that calling DBus methods is almost as easy as calling local ones.

It currently supports:

- Calling methods
- Creating wrapper objects for DBus interfaces
- Seamlessly converting too and from D types
- Handling method calls and signals (includes introspection support)

# Usage

## Call Interface

The simplest way to call methods over DBus is to create a connection and then a PathIface object
which wraps a destination, path and interface. You can then call methods on that object with any
parameters which ddbus knows how to serialize and it will return a reply message which you can convert
to the correct return type using `.to!T()`. You can also use the templated `call` method. Example:

```d
import ddbus;
Connection conn = connectToBus();
PathIface obj = new PathIface(conn, "org.freedesktop.DBus","/org/freedesktop/DBus",
"org.freedesktop.DBus");
// call any method with any parameters and then convert the result to the right type.
auto name = obj.GetNameOwner("org.freedesktop.DBus").to!string();
// alternative method
obj.call!string("GetNameOwner","org.freedesktop.DBus");
```

## Server Interface

You can register a delegate into a `MessageRouter` and a main loop in order to handle messages.
After that you can request a name so that other DBus clients can connect to your program.

```d
import ddbus;
MessageRouter router = new MessageRouter();
// create a pattern to register a handler at a path, interface and method
MessagePattern patt = MessagePattern("/root","ca.thume.test","test");
router.setHandler!(int,int)(patt,(int par) {
  writeln("Called with ", par);
  return par;
});
// handle a signal
patt = MessagePattern("/signaler","ca.thume.test","signal",true);
router.setHandler!(void,int)(patt,(int par) {
  writeln("Signalled with ", par);
});
// register all methods of an object
class Tester {
  int lol(int x, string s) {return 5;}
  void wat() {}
}
Tester o = new Tester;
registerMethods(router, "/","ca.thume.test",o);
// get a name and start the server
registerRouter(conn, router);
bool gotem = requestName(conn, "ca.thume.ddbus.test");
simpleMainLoop(conn);
```

Note that `ddbus` currently only supports a simple event loop that is really only suitable for apps that don't do
anything except respond to DBus messages. Other threads handling other things concurrently may or may not work with it. See the todo section for notes on potential `vibe.d` compatibility.

## Thin(ish) Wrapper

`ddbus` also includes a series of thin D struct wrappers over the DBus types.
- `Message`: wraps `DBusMessage` and provides D methods for common functionality.
- `Connection`: wraps `DBusConnection` and provides D methods for common functionality.
- `DBusException`: used for errors produced by DBus turned into D exceptions.

## Type Marshaling

`ddbus` includes fancy templated methods for marshaling D types in and out of DBus messages.
All DBus-compatible basic types work (except dbus path objects and file descriptors).
Any forward range can be marshalled in as DBus array of that type but arrays must be taken out as dynamic arrays.
Structures are mapped to `Tuple` from `std.typecons`.

Example using the lower level interface, the simple interfaces use these behind the scenes:
```d
Message msg = Message("org.example.wow","/wut","org.test.iface","meth");
bool[] emptyB;
auto args = tuple(5,true,"wow",[6,5],tuple(6.2,4,[["lol"]],emptyB));
msg.build(args.expand);
msg.signature().assertEqual("ibsai(diaasab)");
msg.readTuple!(typeof(args))().assertEqual(args);
```

## Modules

- `thin`: thin wrapper types
- `router`: message and signal routing based on `MessagePattern` structs.
- `bus`: bus functionality like requesting names and event loops.
- `simple`: simpler wrappers around other functionality.
- `conv`: low level type marshaling methods.
- `util`: templates for working with D type marshaling like `canDBus!T`.
- `c_lib`: a D translation of the DBus C headers.

Importing `ddbus` publicly imports the `thin`,`router`,`bus` and `simple` modules.
These provide most of the functionality you probably want,
you can import the others if you want lower level control.

Nothing is hidden so if `ddbus` doesn't provide something you can simply import `c_lib` and use the pointers
contained in the thin wrapper structs to do it yourself.

# Todo

`ddbus` should be complete for everyday use but is missing some fanciness that it easily could and should have:

- [vibe.d](http://vibed.org/) event loop compatibility so that calls don't block everything and more importantly, it is possible to write apps that have a DBus server and can do other things concurrently, like a GUI.
- Marshaling of DBus path and file descriptor objects
- Better efficiency in some places, particularly the object wrapping allocates tons of delegates for every method.

Pull requests are welcome, the codebase is pretty small and other than the template metaprogramming for type marshaling is fairly straightforward.

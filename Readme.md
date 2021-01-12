# ddbus

<a href="https://code.dlang.org/packages/ddbus" title="Go to ddbus"><img src="https://img.shields.io/dub/v/ddbus.svg" alt="Dub version"></a>
<a href="https://code.dlang.org/packages/ddbus" title="Go to ddbus"><img src="https://img.shields.io/dub/dt/ddbus.svg" alt="Dub downloads"></a>

A [dbus](http://www.freedesktop.org/wiki/Software/dbus/) library for the [D programming language](http://dlang.org).

Provides fancy and convenient highly templated methods that automagically serialize and deserialize things into DBus types so that calling DBus methods is almost as easy as calling local ones.

It currently supports:

- Calling methods
- Creating wrapper objects for DBus interfaces
- Seamlessly converting to and from D types
- Handling method calls and signals (includes introspection support)

# Installation

Before using, you will need to have the DBus C library installed on your computer to link with, and probably also a DBus session bus running so that you can actually do things.

`ddbus` is available on [DUB](http://code.dlang.org/packages/ddbus) so you can simply include it in your `dub.json`:
```json
"dependencies": {
  "ddbus": "~>2.3.0"
}
```

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

### Working with properties

```d
import ddbus;
Connection conn = connectToBus();
PathIface obj = new PathIface(conn, "org.freedesktop.secrets", "/org/freedesktop/secrets/collection/login", "org.freedesktop.DBus.Properties");

// read property
string loginLabel = obj.Get("org.freedesktop.Secret.Collection", "Label").to!string();
loginLabel = "Secret"~login;
// write it back (variant type requires variant() wrapper)
obj.Set("org.freedesktop.Secret.Collection", "Label", variant(loginLabel));
```
Setting read only properties results in a thrown `DBusException`.

## Server Interface

You can register a delegate into a `MessageRouter` and a main loop in order to handle messages.
After that you can request a name so that other DBus clients can connect to your program.

You can return a `Tuple!(args)` to return multiple values (multiple out values in XML) or
return a `Variant!DBusAny` to support returning any dynamic value.

```d
import ddbus;
MessageRouter router = new MessageRouter();
// create a pattern to register a handler at a path, interface and method
MessagePattern patt = MessagePattern("/root","ca.thume.test","test");
router.setHandler!(int,int,Variant!DBusAny)(patt,(int par, Variant!DBusAny anyArgument) {
  // anyArgument can contain any type now, it must be specified as argument using Variant!DBusAny.
  writeln("Called with ", par, ", ", anyArgument);
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

See the Concurrent Updates section for details how to implement this in a custom main loop.

## Thin(ish) Wrapper

`ddbus` also includes a series of thin D struct wrappers over the DBus types.
- `Message`: wraps `DBusMessage` and provides D methods for common functionality.
- `Connection`: wraps `DBusConnection` and provides D methods for common functionality.
- `DBusException`: used for errors produced by DBus turned into D exceptions.

## Type Marshaling

`ddbus` includes fancy templated methods for marshaling D types in and out of DBus messages.
All DBus-compatible basic types work (except file descriptors).
Any forward range can be marshaled in as DBus array of that type but arrays must be taken out as dynamic arrays.

As per version 2.3.0, D `struct` types are fully supported by `ddbus`. By default all public fields of a structure are marshaled. This behavior can be [changed by UDAs](#customizing-marshaling-of-struct-types). Mapping DBus structures to a matching instance of `std.typecons.Tuple`, like earlier versions of `ddbus` did, is also still supported.

Example using the lower level interface, the simple interfaces use these behind the scenes:
```d
Message msg = Message("org.example.wow","/wut","org.test.iface","meth");

struct S {
  double a;
  int b;
  string[][] c;
  bool[] d;
}

auto s = S(6.2, 4, [["lol"]], []);
auto args = tuple(5, true, "wow", [6, 5], s);
msg.build(args.expand);
msg.signature().assertEqual("ibsai(diaasab)");
msg.readTuple!(typeof(args))().assertEqual(args);
```
### Basic types
These are the basic types supported by `ddbus`:
`bool`, `ubyte`, `short`, `ushort`, `int`, `uint`, `long`, `ulong`, `double`, `string`, `ObjectPath`, `InterfaceName`, `BusName`

ObjectPath, InterfaceName and BusName are typesafe wrappers or aliases around strings which should be used to ensure type-safety. They do not allow implicit casts to each other but can be manually converted to strings either by casting to string.

### Overview of mappings of other types:

| D type                                       | DBus type                | Comments
| -------------------------------------------- | ------------------------ | ---
| any `enum`                                   | `enum` base type         | Only the exact values present in the definition of the `enum` type will be allowed.
| `std.typecons.BitFlags`                      | `enum` base type         | Allows usage of OR'ed values of a flags `enum`.
| dynamic array `T[]`                          | array                    |
| associative array `V[K]`                     | array of key-value pairs | DBus has a special type for key-value pairs, which can be used as the element type of an array only.
| `Tuple!(T...)`                               | structure                | The DBus structure will map all of the `Tuple`'s values in sequence.
| any `struct`                                 | structure                | The DBus structure will map all public fields of the `struct` type in order of definition, unless otherwise specified using UDAs.
| `ddbus` style variant `Variant!T`            | variant                  | `Variant!T` is in fact just a wrapper type to force representation as a variant in DBus, use `Variant!DBusAny` for actual dynamic typing.
| Phobos style variants `std.variant.VariantN` | variant                  | Only supported if set of allowed types is limited to types that can be marshaled by `ddbus`, so `std.variant.Variant` is not supported, but `std.variant.Algebraic` may be, depending on allowed types

### Customizing marshaling of `struct` types
Marshaling behavior can be changed for a `struct` type by adding the `@dbusMarshaling`
UDA with the appropriate flag. The following flags are supported:
- `includePrivateFields` enables marshaling of private fields
- `manualOnly` disables marshaling of all fields

Marshaling of individual fields can be enabled or disabled by setting the `DBusMarshal`
flag as an UDA. I.e. `@Yes.DBusMarshal` or `@No.DBusMarshal`.

Note: symbols `Yes` and `No` are defined in `std.typecons`.

After converting a DBus structure to a D `struct`, any fields that are not marshaled
will appear freshly initialized. This is true even when just converting a `struct` to
`DBusAny` and back.

```d
import ddbus.attributes;
import std.typecons;

@dbusMarshaling(MarshalingFlag.includePrivateFields)
struct WeirdThing {
  int a;                 // marshaled (default behavior not overridden)
  @No.DBusMarshal int b; // explicitly not marshaled
  private int c;         // marshaled, because of includePrivateFields
}
```

## Modules

- `attributes`: defines some UDAs (and related templates) that can be used to customize
struct marshaling.
- `bus`: bus functionality like requesting names and event loops.
- `conv`: low level type marshaling methods.
- `exception`: exception classes
- `router`: message and signal routing based on `MessagePattern` structs.
- `simple`: simpler wrappers around other functionality.
- `thin`: thin wrapper types
- `util`: templates for working with D type marshaling like `canDBus!T`.
- `c_lib`: a D translation of the DBus C headers
  (you generally should not need to use these directly).

Importing `ddbus` will publicly import the `thin`, `router`, `bus`, `simple` and
`attributes` modules. These provide most of the functionality you probably want,
you can import the others if you want lower level control.

Nothing is hidden so if `ddbus` doesn't provide something, you can always import
`c_lib` and use the pointers contained in the thin wrapper structs to do it yourself.

# Concurrent Updates

If you want to use the DBus connection concurrently with some other features
or library like a GUI or vibe.d you can do so by placing this code in the update/main loop:

```d
// initialize Connection conn; somewhere
// on update:
if (!conn.tick)
  return;
```

Or in vibe.d:

```d
runTask({
  import vibe.core.core : yield;

  while (conn.tick)
    yield(); // Or sleep(1.msecs);
});
```

It would be better to watch a file descriptor asynchronously in the event loop instead of checking on a timer, but that hasn't been implemented yet, see Todo.

# Todo

`ddbus` should be complete for everyday use but is missing some fanciness that it easily could and should have:

- Support for adding file descriptors to event loops like vibe.d so that it only wakes up when messages arrive and not on a timer.
- Marshaling of file descriptor objects
- Better efficiency in some places, particularly the object wrapping allocates tons of delegates for every method.

Pull requests are welcome, the codebase is pretty small and other than the template metaprogramming for type marshaling is fairly straightforward.

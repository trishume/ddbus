module ddbus.attributes;

import std.meta : allSatisfy;
import std.traits : getUDAs;
import std.typecons : BitFlags, Flag;

/++
  Flags for use with dbusMarshaling UDA

  Default is to include public fields only
+/
enum MarshalingFlag : ubyte {
  /++
    Automatically include private fields
  +/
  includePrivateFields = 1 << 0,

  /++
    Only include fields with explicit `@Yes.DBusMarshal`. This overrides any
    `include` flags.
  +/
  manualOnly = 1 << 7
}

/++
  UDA for specifying DBus marshaling options on structs
+/
auto dbusMarshaling(Args)(Args args...)
    if (allSatisfy!(isMarshalingFlag, Args)) {
  return BitFlags!MarshalingFlag(args);
}

package(ddbus) template isAllowedField(alias field) {
  private enum flags = marshalingFlags!(__traits(parent, field));
  private alias getUDAs!(field, Flag!"DBusMarshal") UDAs;

  static if (UDAs.length != 0) {
    static assert(UDAs.length == 1,
        "Only one UDA of type Flag!\"DBusMarshal\" allowed on struct field.");

    static assert(is(typeof(UDAs[0]) == Flag!"DBusMarshal"),
        "Did you intend to add UDA Yes.DBusMarshal or No.DBusMarshal?");

    enum isAllowedField = cast(bool) UDAs[0];
  } else static if (!(flags & MarshalingFlag.manualOnly)) {
    static if (__traits(getProtection, field) == "public") {
      enum isAllowedField = true;
    } else static if (cast(bool)(flags & MarshalingFlag.includePrivateFields)) {
      enum isAllowedField = true;
    } else {
      enum isAllowedField = false;
    }
  } else {
    enum isAllowedField = false;
  }
}

private template isMarshalingFlag(T) {
  enum isMarshalingFlag = is(T == MarshalingFlag);
}

private template marshalingFlags(S)
    if (is(S == struct)) {
  private alias getUDAs!(S, BitFlags!MarshalingFlag) UDAs;

  static if (UDAs.length == 0) {
    enum marshalingFlags = BitFlags!MarshalingFlag.init;
  } else {
    static assert(UDAs.length == 1, "Only one @dbusMarshaling UDA allowed on type.");
    static assert(is(typeof(UDAs[0]) == BitFlags!MarshalingFlag),
        "Huh? Did you intend to use @dbusMarshaling UDA?");
    enum marshalingFlags = UDAs[0];
  }
}

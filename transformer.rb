# Script used to transform dbus headers into sources/ddbus/c_lib.d
# Uses dstep and then fixes a bunch of things up
# This should only need to be done once but I'm including it in case things
# need to be re-done. Put dbus headers into the "dbus" folder and install dstep.

Dir["dbus/*.h"].each do |h|
  system "dstep #{h} -DDBUS_INSIDE_DBUS_H -I."
end

FILES_ORDER =
[
 "dbus/dbus-arch-deps.d",
 "dbus/dbus-types.d",
 "dbus/dbus-protocol.d",
 "dbus/dbus-errors.d",
 "dbus/dbus-macros.d",
 "dbus/dbus-memory.d",
 "dbus/dbus-shared.d",
 "dbus/dbus-address.d",
 "dbus/dbus-syntax.d",
 "dbus/dbus-signature.d",
 "dbus/dbus-misc.d",
 "dbus/dbus-threads.d",
 "dbus/dbus-message.d",
 "dbus/dbus-connection.d",
 "dbus/dbus-pending-call.d",
 "dbus/dbus-server.d",
 "dbus/dbus-bus.d",
 "dbus/dbus.d"
]

ANON_ALIAS = /^alias _Anonymous_(\d) (.*);$/
def fixup(cont)
  cont.gsub!("extern (C):",'')
  cont.gsub!(/^import .*$/,'')

  anons = cont.scan(ANON_ALIAS)
  cont.gsub!(ANON_ALIAS,'')
  anons.each do |num,name| 
    cont.gsub!("_Anonymous_#{num}",name)
  end

  # Special case for bug in translator
  cont.gsub!("alias  function", "alias DBusHandlerResult function")
  cont.gsub!(/^alias (\S*) (\S*);$/){ |s| ($1 == $2) ? '' : s }
  
  cont.strip
end

f = File.open("c_lib.d","w")
f.puts <<END
module ddbus.c_lib;
import core.stdc.config;
import core.stdc.stdarg;
extern (C):
END

FILES_ORDER.each do |h|
  f.puts "// START #{h}"
  File.open(h,'r') do |header|
    contents = header.read
    f.puts fixup(contents)
  end
  f.puts "// END #{h}"
end

# Manual Notes:
# - Put correct return result (DBusHandlerResult) for some typedefs (DBusHandleMessageFunction, DBusObjectPathMessageFunction)

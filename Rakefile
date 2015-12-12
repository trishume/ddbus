task :testCall do
  sh "dbus-send --type=method_call --print-reply --dest=ca.thume.ddbus.test /root ca.thume.test.test int32:5"
end

task :badCall do
  sh "dbus-send --type=method_call --print-reply --dest=ca.thume.ddbus.test /root ca.thume.test.test double:5.5"
end

task :testSignal do
  sh "dbus-send --dest=ca.thume.ddbus.test /signaler ca.thume.test.signal int32:9"
end

task :testDbus do
  sh "dbus-send --session --dest=org.freedesktop.DBus --type=method_call --print-reply /org/freedesktop/DBus org.freedesktop.DBus.ListNames"
end

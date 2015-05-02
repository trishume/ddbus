task :testCall do
  sh "dbus-send --type=method_call --print-reply --dest=ca.thume.ddbus.test /root ca.thume.test.test int32:5"
end

task :testSignal do
  sh "dbus-send --dest=ca.thume.ddbus.test /signaler ca.thume.test.signal int32:9"
end

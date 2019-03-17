import std.stdio;
import ddbus;

void testServe(Connection conn) {
  auto router = new MessageRouter();
  MessagePattern patt = MessagePattern(ObjectPath("/root"), interfaceName("ca.thume.test"), "test");
  router.setHandler!(int,int)(patt,(int par) {
      writeln("Called with ", par);
      return par;
    });
  patt = MessagePattern(ObjectPath("/signaler"), interfaceName("ca.thume.test"), "signal",true);
  router.setHandler!(void,int)(patt,(int par) {
      writeln("Signalled with ", par);
    });
  registerRouter(conn, router);
  writeln("Getting name...");
  bool gotem = requestName(conn, busName("ca.thume.ddbus.test"));
  writeln("Got name: ",gotem);
  simpleMainLoop(conn);
}

void main() {
  Connection conn = connectToBus();
  testServe(conn);
  writeln("It worked!");
}

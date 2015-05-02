import std.stdio;
import ddbus.c_lib;
import ddbus.thin;
import ddbus.router;
import ddbus.bus;

void testCall(Connection conn) {
  for(int i = 0; i < 50; i++) {
    Message msg =  Message("ca.thume.transience","/ca/thume/transience/screensurface",
                               "ca.thume.transience.screensurface","testDot");
    conn.sendBlocking(msg);
  }
  Message msg2 = Message("ca.thume.transience","/ca/thume/transience/screensurface",
                            "ca.thume.transience.screensurface","testPing");
  Message res = conn.sendWithReplyBlocking(msg2,3000);
  int result = res.read!int();
  writeln(result);
}

void testServe(Connection conn) {
  auto router = new MessageRouter();
  MessagePattern patt = MessagePattern("/root","ca.thume.test","test");
  router.setHandler!(int,int)(patt,(int par) {
      writeln("Called with ", par);
      return par;
    });
  registerRouter(conn, router);
  writeln("Getting name...");
  bool gotem = requestName(conn, "ca.thume.ddbus.test");
  writeln("Got name: ",gotem);
  simpleMainLoop(conn);
}

void main() {
  Connection conn = connectToBus();
  testServe(conn);
	writeln("It worked!");
}

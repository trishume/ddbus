import core.time;
import std.stdio;
import ddbus;

void testCall(Connection conn) {
  for(int i = 0; i < 50; i++) {
    Message msg =  Message(busName("ca.thume.transience"), ObjectPath("/ca/thume/transience/screensurface"),
                          interfaceName("ca.thume.transience.screensurface"), "testDot");
    conn.sendBlocking(msg);
  }
  Message msg2 = Message(busName("ca.thume.transience"), ObjectPath("/ca/thume/transience/screensurface"),
                        interfaceName("ca.thume.transience.screensurface"), "testPing");
  Message res = conn.sendWithReplyBlocking(msg2, 3.seconds);
  int result = res.read!int();
  writeln(result);
}

void main() {
  Connection conn = connectToBus();
  testCall(conn);
  writeln("It worked!");
}

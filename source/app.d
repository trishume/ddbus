import std.stdio;
import ddbus.c_lib;
import ddbus.thin;

void main()
{
  Connection conn = connectToBus();
  for(int i = 0; i < 50; i++) {
    Message msg =  new Message("ca.thume.transience","/ca/thume/transience/screensurface",
                               "ca.thume.transience.screensurface","testDot");
    conn.sendBlocking(msg);
  }
  Message msg2 = new Message("ca.thume.transience","/ca/thume/transience/screensurface",
                            "ca.thume.transience.screensurface","testPing");
  Message res = conn.sendWithReplyBlocking(msg2,3000);
  int result = res.read!int();
  writeln(result);
	writeln("It worked!");
}

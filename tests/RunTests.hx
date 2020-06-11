package ;

import tink.unit.*;
import tink.testrunner.*;

class RunTests {
  static function main() {
    Runner.run(TestBatch.make([
      new Annexes(),
      new Callbacks(),
      new Errors(),
      new Futures(),
      new Lazies(),
      new Options(),
      new Outcomes(),
      new Pairs(),
      new Promises(),
      new Refs(),
      new Signals(),
      new Progresses(),
    ])).handle(Runner.exit);
  }
}
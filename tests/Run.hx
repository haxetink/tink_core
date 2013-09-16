package ;

import haxe.unit.*;
import tink.core.Pair;
class Run {
	static var tests:Array<TestCase> = [
		new Chains(),
		new Base.TestBase(),
		new Callbacks(),
		new Futures(),
		new Outcomes(),
		new Signals(),
		new Refs(),
		new TestCons()
	];
	static function main() {
		var r = new TestRunner();
		for (c in tests)
			r.add(c);
		r.run();
	}
}
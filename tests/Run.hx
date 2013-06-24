package ;

import haxe.unit.TestCase;
import haxe.unit.TestRunner;
import neko.Lib;
import tink.core.Ref;

class Run {
	static var tests:Array<TestCase> = [
		new Base.TestBase(),
		new Callbacks(),
		new Futures(),
		new Outcomes(),
	];
	static function main() {
		var runner = new TestRunner();
		for (test in tests)
			runner.add(test);
		runner.run();
		trace(Ref.to(5));
	}
}
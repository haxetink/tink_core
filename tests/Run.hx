package ;

import haxe.unit.*;

class Run {
	static var tests:Array<TestCase> = [
		new Base.TestBase(),
		new Callbacks(),
		new Futures(),
		new Outcomes(),
		new Signals(),
		new Refs(),
		new Pairs()
	];
	static function main() {		
		var r = new TestRunner();
		for (c in tests)
			r.add(c);
		r.run();
	}
}
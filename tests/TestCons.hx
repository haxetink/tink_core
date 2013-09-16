package ;

import tink.core.Pair;
import tink.core.Future;
import haxe.ds.Option;

class TestCons extends Base {
	function test() {
		var c = new Pair(new Pair(1, 2), new Pair(3, 4));
		assertEquals(1, c.a.a);
		assertEquals(2, c.a.b);
		assertEquals(3, c.b.a);
		assertEquals(4, c.b.b);
		
	}
}
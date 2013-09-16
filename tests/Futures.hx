package ;

using tink.core.Future;

class Futures extends Base {
	
	function testOfConstant() {
		var f = Future.ofConstant(4);
		var x = -4;
		f.handle(function (v) x = v);
		assertEquals(4, x);
	}
	
	function testOfAsyncCall() {
		var callbacks:Array<Int->Void> = [];
		function fake(callback:Int->Void) {
			callbacks.push(callback);
		}
		function trigger() 
			for (c in callbacks) c(4);
		
		var f = Future.ofAsyncCall(fake);
		
		var calls = 0;
		
		var link1 = f.handle(function () calls++),
			link2 = f.handle(function () calls++);
			
		f.handle(function (v) {
			assertEquals(4, v);
			calls++;
		});
		
		assertEquals(1, callbacks.length);
		link1.dissolve();
		
		trigger();
		
		assertEquals(2, calls);
	}
	
	function testTrigger() {
		var t = Future.create();
		assertTrue(t.invoke(4));
		assertFalse(t.invoke(4));
		
		t = Future.create();
		
		var f:Future<Int> = t;
		
		var calls = 0;
		
		f.handle(function (v) {
			assertEquals(4, v);
			calls++;
		});
		
		t.invoke(4);
		
		assertEquals(1, calls);
		
	}
	
	function testFlatten() {
		var f = Future.ofConstant(Future.ofConstant(4));
		var flat = Future.flatten(f),
			calls = 0;
			
		flat.handle(function (v) {
			assertEquals(4, v);
			calls++;
		});
		
		assertEquals(1, calls);
	}
}
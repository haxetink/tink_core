package ;

using tink.CoreApi;

class Futures extends Base {
	
	function testsync() {
		var f = Future.sync(4);
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
		
		var f = Future.async(fake);
		
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
		var t = Future.trigger();
		assertTrue(t.trigger(4));
		assertFalse(t.trigger(4));
		
		t = Future.trigger();
		
		var f:Future<Int> = t;
		
		var calls = 0;
		
		f.handle(function (v) {
			assertEquals(4, v);
			calls++;
		});
		
		t.trigger(4);
		
		assertEquals(1, calls);
		
	}
	
	function testFlatten() {
		var f = Future.sync(Future.sync(4));
		var flat = Future.flatten(f),
			calls = 0;
			
		flat.handle(function (v) {
			assertEquals(4, v);
			calls++;
		});
		
		assertEquals(1, calls);
	}
	
	function testOps() {
		var t1 = Future.trigger(),
			t2 = Future.trigger();
		var f1:Future<Int> = t1,
			f2:Future<Int> = t2;
			
		var f = f1 || f2;
		t1.trigger(1);
		t2.trigger(2);
		f.handle(assertEquals.bind(1));
		var f = f1 && f2;
		f.handle(function (p) {
			assertEquals(p.a, 1);	
			assertEquals(p.b, 2);	
		});
	}
}








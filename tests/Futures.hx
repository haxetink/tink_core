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
	
	function testMany() {
		var triggers = [for (i in 0...10) Future.trigger()];
		var futures = [for (t in triggers) t.asFuture()];
		
		var read1 = false,
			read2 = false;
		
		var lazy1 = Future.lazy(function () {
			read1 = true;
			return 10;
		});
		
		var lazy2 = Future.lazy(function () {
			read2 = true;
			return 10;
		});
		
		futures.unshift(lazy1);
		futures.push(lazy2);
		
		function sum(a:Array<Int>, ?index = 0)
			return 
				if (index < a.length) a[index] + sum(a, index + 1);
				else 0;
		
		var f = Future.ofMany(futures).map(sum.bind(_, 0)),
			f2 = Future.ofMany(futures, false).map(sum.bind(_, 0));
			
		assertFalse(read1);
		assertFalse(read2);
		
		f.handle(assertEquals.bind(65));
		f2.handle(assertEquals.bind(65));
		
		var handled = false;
		f.handle(function () handled = true);
		
		assertFalse(handled);
		assertTrue(read1);
		assertFalse(read2);
		
		for (i in 0...triggers.length)
			triggers[i].trigger(i);
			
		assertTrue(handled);
	}
}
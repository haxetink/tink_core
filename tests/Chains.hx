package ;

import tink.core.*;
import haxe.ds.Option;

class Chains extends Base {
	
	function nat(?f:Int->Void) {
		var count = 0;
		return Chain.lazy(function () {
			if (f != null) f(count);
			return count++;
		});
	}
	
	function testStep() {
		var c = nat();
		for (i in 0...100)
			c = c.step(assertEquals.bind(i));
	}
	
	function testLimit() 
		for (length in 0...10) {
			var c = nat().limit(length),
				done = 0;
				
			function end() done++;
			function step() c = c.step(end);
			
			for (i in 0...length)
				step();
				
			for (i in 0...10) {
				assertEquals(i, done);
				step();
			}
		}	
	
	function testSkip() {
		var c = nat();
		for (i in 0...100)
			c.skip(i).step(assertEquals.bind(i));
	}
	
	function testFold() 
		for (i in 0...100)
			nat().limit(i).fold(0, function (sum, _) return sum + 1).handle(assertEquals.bind(i));		
	
	function testSlice() 
		for (length in 0...20)
			nat().slice(length).map(function (a) return a.join(',')).handle(
				assertEquals.bind([for (i in 0...length) i].join(','))
			);
	
	function testZip() 
		nat()
			.zip(nat(), function (a, b) return [a, b])
			.limit(100)
			.forEach(function (x) assertEquals(x[0], x[1]));
	
	function testMap() {
		var c = nat().limit(100);
		var calls = 0;
		function sq(x) {
			calls++;
			return x * x;
		}
		var m = c.map(sq, true);
		assertEquals(0, calls);
		c.zip(m, function (x, s) return x * x - s).forEach(assertEquals.bind(0));
		assertEquals(100, calls);
		c.zip(m, function (x, s) return x * x - s).forEach(assertEquals.bind(0));
		assertEquals(100, calls);
		
		m = c.map(sq, false);
		calls = 0;
		assertEquals(0, calls);
		c.zip(m, function (x, s) return x * x - s).forEach(assertEquals.bind(0));
		assertEquals(100, calls);
		c.zip(m, function (x, s) return x * x - s).forEach(assertEquals.bind(0));
		assertEquals(200, calls);
	}
	
	function testConcat() {
		var c = nat().limit(100).concat(nat().limit(100));
		var a = [for (i in 0...100) i];
		a = a.concat(a);
		c.forEach(function (x) assertEquals(a.shift(), x));
		
		var c = nat().limit(100);
		var a = [for (i in 0...100) i];
		a = a.concat(a);
		c = c.concat(c);
		c.forEach(function (x) assertEquals(a.shift(), x));
	}
	
	function testFilter() {
		var c = nat().limit(100);
		var calls = 0;
		function even(x) {
			calls++;
			return x & 1 == 0;
		}
		var m = c.filter(even, true);
		assertEquals(0, calls);
		
		c.zip(m, function (x, s) return 2 * x - s).forEach(assertEquals.bind(0));
		assertEquals(100, calls);
		c.zip(m, function (x, s) return 2 * x - s).forEach(assertEquals.bind(0));
		assertEquals(100, calls);
		
		m = c.filter(even, false);
		calls = 0;
		assertEquals(0, calls);
		c.zip(m, function (x, s) return 2 * x - s).forEach(assertEquals.bind(0));
		assertEquals(100, calls);
		c.zip(m, function (x, s) return 2 * x - s).forEach(assertEquals.bind(0));
		assertEquals(200, calls);		
	}
	
	function testLazy() {
		var last = -1;
		var c = nat(function (x) last = x);
		var f1 = c.filter(function (x) return x % 3 == 0, true),
			f2 = c.filter(function (x) return x % 3 == 0, false),
			
			m1 = c.map(function (x) return 2 * x, true),
			m2 = c.map(function (x) return 2 * x, false),
			
			l1 = c.limit(4, true),
			l2 = c.limit(4, false),
			
			s1 = c.skip(4, true),
			s2 = c.skip(4, false);
		
		assertEquals(last, -1);
		
		l1.fold(0, function (x, y) return x + y).handle(assertEquals.bind(6));
		
		assertEquals(3, last);
	}
}
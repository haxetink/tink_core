package ;

using tink.core.Signal;
using tink.core.Future;
using tink.core.Callback;

class Signals extends Base {
	var signal1:Signal<String>;
	var handlers1:CallbackList<String>;
	var signal2:Signal<String>;
	var handlers2:CallbackList<String>;
	override function setup() {
		signal1 = handlers1 = new CallbackList();
		signal2 = handlers2 = new CallbackList();
	}
	function testNext() {
		var next = signal1.next();
		var value = null;
		next.when(function (v) value = v);
		handlers1.invoke('foo');
		assertEquals('foo', value);
		handlers1.invoke('bar');
		assertEquals('foo', value);
	}
	
	function testJoinNoGather() {
		var s = signal1.join(signal2, false);
		assertEquals(0, handlers1.length);
		assertEquals(0, handlers2.length);
		
		var calls = 0;
		
		var link1 = s.when(function () calls++),
			link2 = s.when(function () calls++);
		
		assertEquals(2, handlers1.length);
		assertEquals(2, handlers2.length);		
		
		handlers1.invoke('foo');
		
		assertEquals(2, calls);
		
		handlers2.invoke('foo');
		
		assertEquals(4, calls);
		
		link2.dissolve();
		
		assertEquals(1, handlers1.length);
		assertEquals(1, handlers2.length);		
		
		link1.dissolve();
		
		assertEquals(0, handlers1.length);
		assertEquals(0, handlers2.length);		
	}
	
	function testJoinGather() {
		var s = signal1.join(signal2);
		
		assertEquals(1, handlers1.length);
		assertEquals(1, handlers2.length);
		
		var calls = 0;
		
		var link1 = s.when(function () calls++),
			link2 = s.when(function () calls++);
		
		assertEquals(1, handlers1.length);
		assertEquals(1, handlers2.length);		
		
		handlers1.invoke('foo');
		
		assertEquals(2, calls);
		
		handlers2.invoke('foo');
		
		assertEquals(4, calls);
		
		link2.dissolve();
		
		assertEquals(1, handlers1.length);
		assertEquals(1, handlers2.length);		
		
		link1.dissolve();
		
		assertEquals(1, handlers1.length);
		assertEquals(1, handlers2.length);		
	}
	
	function testMap() {
		var mapCalls = 0,
			last = null;
		var s = signal1.map(function (v) { mapCalls++; return last = v + v; } );
		
		assertEquals(1, handlers1.length);
		
		var calls = 0;
		
		var link1 = s.when(function () calls++),
			link2 = s.when(function () calls++);
		
		assertEquals(1, handlers1.length);
		
		handlers1.invoke('foo');
		
		assertEquals(2, calls);
		assertEquals(1, mapCalls);
		assertEquals('foofoo', last);
		
		link2.dissolve();
		
		assertEquals(1, handlers1.length);
		
		link1.dissolve();
		
		assertEquals(1, handlers1.length);
	}
	
	function testMapNoGather() {
		var mapCalls = 0,
			last = null;
		var s = signal1.map(function (v) { mapCalls++; return last = v + v; }, false);
		
		assertEquals(0, handlers1.length);
		
		var calls = 0;
		
		var link1 = s.when(function () calls++),
			link2 = s.when(function () calls++);
		
		assertEquals(2, handlers1.length);
		
		handlers1.invoke('foo');
		
		assertEquals(2, calls);
		assertEquals(2, mapCalls);
		assertEquals('foofoo', last);
		
		link2.dissolve();
		
		assertEquals(1, handlers1.length);
		
		link1.dissolve();
		
		assertEquals(0, handlers1.length);
	}
	
	function testFlatMap() {
		var mapCalls = 0,
			out = '',
			inQueueData = [for (i in 1...1000) Std.string(i)],
			inQueue = [];
		
		function make() {
			var f = Future.create();
			var data = inQueueData.shift();
			inQueue.push(function () f.invoke(data));
			return f.asFuture();
		}
		function step() 
			inQueue.shift()();
		
		var s = signal1.flatMap(function (v1) { mapCalls++; return make().map(function (v2) return v1 + v2); });
		
		assertEquals(1, handlers1.length);
		
		var calls = 0;
		
		var link1 = s.when(function () calls++),
			link2 = s.when(function () calls++),
			link3 = s.when(function (v) out += v);
		
		assertEquals(1, handlers1.length);

		assertEquals(0, calls);
		assertEquals(0, mapCalls);
		
		handlers1.invoke('1');
		
		assertEquals(0, calls);
		assertEquals(1, mapCalls);
		
		handlers1.invoke('2');
		
		assertEquals(0, calls);
		assertEquals(2, mapCalls);
		
		assertEquals('', out);
		
		step();
		
		assertEquals(2, calls);
		assertEquals(2, mapCalls);
		
		assertEquals('11', out);
		
		handlers1.invoke('3');
		
		assertEquals(2, calls);
		assertEquals(3, mapCalls);
		
		step();
		step();
		
		assertEquals(6, calls);
		assertEquals(3, mapCalls);
		assertEquals('112233', out);
	}
	
	function testFlatMapNoGather() {
		var mapCalls = 0,
			out = '',
			inQueueData = [for (i in 1...1000) Std.string(i)],
			inQueue = [];
		
		function make() {
			var f = Future.create();
			var data = inQueueData.shift();
			inQueue.push(function () f.invoke(data));
			return f.asFuture();
		}
		function step() 
			inQueue.shift()();
		
		var s = signal1.flatMap(function (v1) { mapCalls++; return make().map(function (v2) return v1 + v2); }, false);
		
		assertEquals(0, handlers1.length);
		
		var calls = 0;
		
		var link1 = s.when(function () calls++),
			link2 = s.when(function () calls++),
			link3 = s.when(function (v) out += v);
		
		assertEquals(3, handlers1.length);

		assertEquals(0, calls);
		assertEquals(0, mapCalls);
		
		handlers1.invoke('1');
		
		assertEquals(0, calls);
		assertEquals(3, mapCalls);
		
		handlers1.invoke('2');
		
		assertEquals(0, calls);
		assertEquals(6, mapCalls);
		
		assertEquals('', out);
		
		step();
		
		assertEquals(1, calls);
		assertEquals(6, mapCalls);
		assertEquals('', out);
		
		step();
		
		assertEquals(2, calls);
		assertEquals(6, mapCalls);
		assertEquals('', out);
		
		step();
		
		assertEquals(2, calls);
		assertEquals(6, mapCalls);
		assertEquals('13', out);
	}	
}
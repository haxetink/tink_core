package ;

using tink.core.Signal;
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
}
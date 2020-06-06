package ;

using tink.CoreApi;

@:asserts
class Signals extends Base {
  var signal1:Signal<String>;
  var handlers1:SignalTrigger<String>;
  var signal2:Signal<String>;
  var handlers2:SignalTrigger<String>;

  @:before
  public function setup() {
    signal1 = handlers1 = Signal.trigger();
    signal2 = handlers2 = Signal.trigger();
    return Noise;
  }

  public function testNext() {
    var next = signal1.nextTime();
    var value = null;
    next.handle(function (v) value = v);
    handlers1.trigger('foo');
    asserts.assert('foo' == value);
    handlers1.trigger('bar');
    asserts.assert('foo' == value);
    return asserts.done();
  }

  public function testSuspendable() {

    var active = false;
    var s = Signal.create(
      function (_) {
        active = true;
        return function () active = false;
      }
    );

    asserts.assert(!active);

    var link = s.handle(function () {});
    asserts.assert(active);

    link.cancel();
    asserts.assert(!active);

    link = s.handle(function () {});
    asserts.assert(active);

    var link2 = s.handle(function () {});
    asserts.assert(active);

    link.cancel();
    asserts.assert(active);

    link2.cancel();
    asserts.assert(!active);
    return asserts.done();
  }

  public function testJoinGather() {
    var s = signal1.join(signal2);

    asserts.assert(0 == handlers1.getLength());
    asserts.assert(0 == handlers2.getLength());

    var calls = 0;

    var link1 = s.handle(function () calls++),
        link2 = s.handle(function () calls++);

    asserts.assert(1 == handlers1.getLength());
    asserts.assert(1 == handlers2.getLength());

    handlers1.trigger('foo');

    asserts.assert(2 == calls);

    handlers2.trigger('foo');

    asserts.assert(4 == calls);

    link2.cancel();

    asserts.assert(1 == handlers1.getLength());
    asserts.assert(1 == handlers2.getLength());

    link1.cancel();

    asserts.assert(0 == handlers1.getLength());
    asserts.assert(0 == handlers2.getLength());
    return asserts.done();
  }

  public function testMap() {
    var mapCalls = 0,
        last = null;
    var s = signal1.map(function (v) { mapCalls++; return last = v + v; } );

    asserts.assert(1 == handlers1.getLength());

    var calls = 0;

    var link1 = s.handle(function () calls++),
      link2 = s.handle(function () calls++);

    asserts.assert(1 == handlers1.getLength());

    handlers1.trigger('foo');

    asserts.assert(2 == calls);
    asserts.assert(1 == mapCalls);
    asserts.assert('foofoo' == last);

    link2.cancel();

    asserts.assert(1 == handlers1.getLength());

    link1.cancel();

    asserts.assert(1 == handlers1.getLength());
    return asserts.done();
  }

  public function testMapNoGather() {
    var mapCalls = 0,
        last = null;
    var s = signal1.map(function (v) { mapCalls++; return last = v + v; }, false);

    asserts.assert(0 == handlers1.getLength());

    var calls = 0;

    var link1 = s.handle(function () calls++),
      link2 = s.handle(function () calls++);

    asserts.assert(2 == handlers1.getLength());

    handlers1.trigger('foo');

    asserts.assert(2 == calls);
    asserts.assert(2 == mapCalls);
    asserts.assert('foofoo' == last);

    link2.cancel();

    asserts.assert(1 == handlers1.getLength());

    link1.cancel();

    asserts.assert(0 == handlers1.getLength());
    return asserts.done();
  }

  public function testFlatMap() {
    var mapCalls = 0,
      out = '',
      inQueueData = [for (i in 1...1000) Std.string(i)],
      inQueue = [];

    function make() {
      var f = Future.trigger();
      var data = inQueueData.shift();
      inQueue.push(function () f.trigger(data));
      return f.asFuture();
    }
    function step()
      inQueue.shift()();

    var s = signal1.flatMap(function (v1) { mapCalls++; return make().map(function (v2) return v1 + v2); });

    asserts.assert(1 == handlers1.getLength());

    var calls = 0;

    var link1 = s.handle(function () calls++),
      link2 = s.handle(function () calls++),
      link3 = s.handle(function (v) out += v);

    asserts.assert(1 == handlers1.getLength());

    asserts.assert(0 == calls);
    asserts.assert(0 == mapCalls);

    handlers1.trigger('1');

    asserts.assert(0 == calls);
    asserts.assert(1 == mapCalls);

    handlers1.trigger('2');

    asserts.assert(0 == calls);
    asserts.assert(2 == mapCalls);

    asserts.assert('' == out);

    step();

    asserts.assert(2 == calls);
    asserts.assert(2 == mapCalls);

    asserts.assert('11' == out);

    handlers1.trigger('3');

    asserts.assert(2 == calls);
    asserts.assert(3 == mapCalls);

    step();
    step();

    asserts.assert(6 == calls);
    asserts.assert(3 == mapCalls);
    asserts.assert('112233' == out);
    return asserts.done();
  }

  public function testFlatMapNoGather() {
    var mapCalls = 0,
      out = '',
      inQueueData = [for (i in 1...1000) Std.string(i)],
      inQueue = [];

    function make() {
      var f = Future.trigger();
      var data = inQueueData.shift();
      inQueue.push(function () f.trigger(data));
      return f.asFuture();
    }
    function step()
      inQueue.shift()();

    var s = signal1.flatMap(function (v1) { mapCalls++; return make().map(function (v2) return v1 + v2); }, false);

    asserts.assert(0 == handlers1.getLength());

    var calls = 0;

    var link1 = s.handle(function () calls++),
      link2 = s.handle(function () calls++),
      link3 = s.handle(function (v) out += v);

    asserts.assert(3 == handlers1.getLength());

    asserts.assert(0 == calls);
    asserts.assert(0 == mapCalls);

    handlers1.trigger('1');

    asserts.assert(0 == calls);
    asserts.assert(3 == mapCalls);

    handlers1.trigger('2');

    asserts.assert(0 == calls);
    asserts.assert(6 == mapCalls);

    asserts.assert('' == out);

    step();

    asserts.assert(1 == calls);
    asserts.assert(6 == mapCalls);
    asserts.assert('' == out);

    step();

    asserts.assert(2 == calls);
    asserts.assert(6 == mapCalls);
    asserts.assert('' == out);

    step();

    asserts.assert(2 == calls);
    asserts.assert(6 == mapCalls);
    asserts.assert('13' == out);
    return asserts.done();
  }
}
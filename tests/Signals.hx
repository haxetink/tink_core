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
    final next = signal1.nextTime();
    var value = null;
    next.handle(v -> { value = v; });
    handlers1.trigger('foo');
    asserts.assert('foo' == value);
    handlers1.trigger('bar');
    asserts.assert('foo' == value);
    return asserts.done();
  }

  public function testSuspendable() {

    var active = false;
    var d = null;
    var counter = 0;
    var initialized = 0;
    var received = -1;

    final s = new Signal(
      fire -> {
        fire(counter++);
        active = true;
        return () -> active = false;
      },
      v -> {
        initialized++;
        d = v;
      }
    );

    function handler(v)
      received = v;

    asserts.assert(!active);
    asserts.assert(d == null, 'not initialized');
    asserts.assert(initialized == 0);

    var link = s.handle(handler);

    asserts.assert(received == 0);
    asserts.assert(active);
    asserts.assert(d != null, 'initialized');
    asserts.assert(initialized == 1);

    link.cancel();
    asserts.assert(!active);

    link = s.handle(handler);
    asserts.assert(received == 1);
    asserts.assert(active);
    asserts.assert(initialized == 1);

    var link2 = s.handle(handler);
    asserts.assert(active);

    link.cancel();
    asserts.assert(active);

    link2.cancel();
    asserts.assert(!active);

    link2 = s.handle(handler);
    asserts.assert(received == 2);
    d.dispose();

    asserts.assert(!active);
    link2 = s.handle(handler);
    asserts.assert(!active);

    return asserts.done();
  }

  public function testJoin() {
    final s = signal1.join(signal2);

    asserts.assert(0 == handlers1.getLength());
    asserts.assert(0 == handlers2.getLength());

    var calls = 0;

    final link1 = s.handle(() -> calls++);
    final link2 = s.handle(() -> calls++);

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
    var mapCalls = 0;
    var last = null;
    final s = signal1.map(v -> { mapCalls++; return last = v + v; });

    asserts.assert(0 == handlers1.getLength());

    var calls = 0;

    final link1 = s.handle(() -> calls++);
    final link2 = s.handle(() -> calls++);

    asserts.assert(1 == handlers1.getLength());

    handlers1.trigger('foo');

    asserts.assert(2 == calls);
    asserts.assert(1 == mapCalls);
    asserts.assert('foofoo' == last);

    link2.cancel();

    asserts.assert(1 == handlers1.getLength());

    link1.cancel();

    asserts.assert(0 == handlers1.getLength());
    return asserts.done();
  }

  public function testFlatMap() {
    var mapCalls = 0;
    var out = '';
    final inQueueData = [for (i in 1...1000) Std.string(i)];
    final inQueue = [];

    function make() {
      final f = Future.trigger();
      final data = inQueueData.shift();
      inQueue.push(() -> f.trigger(data));
      return f.asFuture();
    }
    function step()
      inQueue.shift()();

    final s = signal1.flatMap(v1 -> { mapCalls++; return make().map(v2 -> v1 + v2); });

    asserts.assert(0 == handlers1.getLength());

    var calls = 0;

    final link1 = s.handle(() -> calls++);
    final link2 = s.handle(() -> calls++);
    final link3 = s.handle(v -> out += v);

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

  public function testGenerate() {
    final s = Signal.generate(fire -> {
      fire('42');
      handlers1.listen(fire);
    });
    final a = [];
    s.handle(a.push);
    s.handle(a.push);
    asserts.assert('42' == a.join(','));
    handlers1.trigger('0');
    handlers1.trigger('1');
    asserts.assert('42,0,0,1,1' == a.join(','));

    return asserts.done();
  }

  #if nodejs // derived signals are only held weakly on js
  public function testDerivedReleasedWhileSourceLives() {
    final gc:()->Void =
      try {
        js.Lib.require('v8').setFlagsFromString('--expose-gc');
        js.Lib.require('vm').runInNewContext('gc');
      }
      catch (e:Dynamic) null;
    if (gc == null) {
      asserts.assert(true, 'no way to force a collection');
      return asserts.done();
    }

    // count collections with a FinalizationRegistry: a WeakRef would keep its target alive while it is being checked
    var collected = 0;
    final registry:Dynamic = js.Syntax.code('new FinalizationRegistry({0})', (_:Dynamic) -> collected++);

    var attempts = 0;
    function check() {
      gc();
      haxe.Timer.delay(() ->
        if (collected < 39 && ++attempts < 20) check();
        else {
          // Haxe's generated '$_' temp keeps the last object it bound a method of, so one may survive
          asserts.assert(collected >= 39);
          asserts.done();
        }, 10);
    }

    // in a later task: node keeps the targets of WeakRefs created while the main script runs
    haxe.Timer.delay(() -> {
      for (i in 0...20) {
        final mapped = signal1.map(v -> v + i);
        final joined = mapped.join(signal2.filter(v -> v.length > i));
        joined.handle(_ -> {}).cancel();
        registry.register(mapped, i);
        registry.register(joined, i);
      }
      check();
    }, 0);

    return asserts;
  }
  #end
}

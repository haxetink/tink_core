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

  // Activating a derived signal costs one level of guard depth per link, and the
  // trigger that follows costs one more. Close enough to `MAX_DEPTH`, the delivery
  // is therefore parked, and an observer reading the value synchronously after
  // `trigger` - as `Progresses::testPromiseProgress` does - sees nothing. See #180.
  @:include
  public function testActivationIsSynchronous() {
    // runs `f` with `Callback.depth` at `target`, however deep we already are
    function atDepth(target:Int, f:()->Void) {
      function rec()
        if (@:privateAccess Callback.depth >= target) f();
        else Callback.guardStackoverflow(rec);
      rec();
    }

    final ceiling = @:privateAccess Callback.MAX_DEPTH;
    final derived = signal1.map(v -> v);

    var seen = null,
        ran = false;

    atDepth(ceiling - 1, () -> {
      ran = true;
      derived.handle(v -> seen = v);
      handlers1.trigger('foo');
    });

    asserts.assert(ran, 'never reached depth ${ceiling - 1}');
    asserts.assert(seen == 'foo', 'saw $seen');

    return asserts.done();
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

  // Registering a handler on a chain of derived signals activates every link in
  // it, and each activation happens inside the previous one, so the recursion is
  // as deep as the chain is long. Nothing bounds it by `MAX_DEPTH` the way
  // guarded calls are, so a long enough chain overflows the stack before
  // `handle` returns. See #180.
  public function testDeepChainActivation() {
    final limit = @:privateAccess Callback.MAX_DEPTH;
    final length = limit * 2;
    var nested = 0,
        deepest = 0;

    function derive(inner:Signal<Int>):Signal<Int>
      return new Signal<Int>(fire -> {
        if (++nested > deepest) deepest = nested;
        final link = inner.handle(fire);
        nested--;
        return link;
      });

    final source:SignalTrigger<Int> = Signal.trigger();
    var last:Signal<Int> = source;
    for (i in 0...length) last = derive(last);

    var received = -1;
    last.handle(v -> received = v);

    asserts.assert(deepest <= limit, 'activating a chain of $length links nested $deepest deep');

    source.trigger(42);

    // firing the chain does outgrow the guard, so the tail of the delivery is
    // parked until the queue is drained, which happens after this method returns
    Callback.defer(() -> {
      asserts.assert(received == 42, 'received $received');
      asserts.done();
    });

    return asserts;
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

  function watched() {
    final state = { active: false, fire: (null:Int->Void) };
    final signal = new Signal<Int>(fire -> {
      state.active = true;
      state.fire = fire;
      () -> state.active = false;
    });
    return { signal: signal, state: state };
  }

  public function testNextTimeBeforeHandle() {
    final next = signal1.nextTime();
    handlers1.trigger('foo');
    var value = null;
    next.handle(v -> value = v);
    asserts.assert('foo' == value);
    return asserts.done();
  }

  public function testNextTimeStopsListening() {
    final w = watched();
    final next = w.signal.nextTime(v -> v > 1);
    asserts.assert(w.state.active);

    next.handle(_ -> {}).cancel();
    asserts.assert(!w.state.active);

    var value = 0;
    next.handle(v -> value = v);
    asserts.assert(w.state.active);
    w.state.fire(1);
    w.state.fire(2);
    asserts.assert(2 == value);
    asserts.assert(!w.state.active);
    return asserts.done();
  }

  public function testNextTimeRaceLoser() {
    final loser = watched();
    var value = null;
    (signal1.nextTime() || loser.signal.nextTime().map(Std.string)).handle(v -> value = v);
    handlers1.trigger('foo');
    asserts.assert('foo' == value);
    // queued behind whatever Callback's stack overflow guard parked (interp/eval/python guard at depth 100)
    Callback.guardStackoverflow(() -> {
      asserts.assert(!loser.state.active);
      asserts.done();
    });
    return asserts;
  }

  function linked(trigger:SignalTrigger<String>)
    return @:privateAccess trigger.handlers.activeDisposeHandlers;

  public function testUnusedDerivedSignalsAreReleased() {
    for (i in 0...100) {
      signal1.select(v -> if (v == 'foo') Some(v) else None);
      signal1.map(v -> v.length).filter(v -> v > 1);
      signal1.join(signal2).handle(_ -> {}).cancel();
    }
    asserts.assert(linked(handlers1) == 0);
    asserts.assert(linked(handlers2) == 0);
    asserts.assert(@:privateAccess handlers1.handlers.disposeHandlers.length == 0);
    asserts.assert(@:privateAccess handlers2.handlers.disposeHandlers.length == 0);
    return asserts.done();
  }

  public function testDerivedSignalsAreDisposedWithSource() {
    final log = [];
    final idle = signal1.map(v -> v.length);
    final active = signal1.map(v -> v.length);
    final watched = signal1.map(v -> v.length);
    final chained = signal1.map(v -> v.length).filter(v -> v > 1);

    final link = active.handle(v -> log.push('active:$v'));
    chained.handle(v -> log.push('chained:$v'));
    final watch = watched.ondispose(() -> log.push('watched disposed'));
    asserts.assert(linked(handlers1) == 3);

    handlers1.trigger('a');
    handlers1.trigger('ab');
    asserts.assert(log.join(',') == 'active:1,active:2,chained:2');

    link.cancel();
    asserts.assert(linked(handlers1) == 2);
    watch.cancel();
    asserts.assert(linked(handlers1) == 1);
    watched.ondispose(() -> log.push('watched disposed'));
    asserts.assert(linked(handlers1) == 2);

    handlers1.dispose();
    asserts.assert(log.join(',') == 'active:1,active:2,chained:2,watched disposed');
    asserts.assert(idle.disposed && active.disposed && watched.disposed && chained.disposed);

    var late = false;
    idle.ondispose(() -> late = true);
    asserts.assert(late);
    return asserts.done();
  }

  public function testJoinDisposal() {
    final joined = signal1.join(signal2);
    var disposed = false;
    joined.ondispose(() -> disposed = true);
    handlers1.dispose();
    asserts.assert(!disposed && !joined.disposed);
    handlers2.dispose();
    asserts.assert(disposed && joined.disposed);
    return asserts.done();
  }
}

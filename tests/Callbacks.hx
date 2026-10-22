package ;

import tink.unit.Assert.*;

using tink.CoreApi;

@:asserts
class Callbacks extends Base {
  public function testInvoke() {
    var calls = 0;
    final cbs:Array<Callback<Int>> = [
      () -> calls++,
      _ -> calls++
    ];
    cbs.push(cbs.copy());

    for (c in cbs)
      c.invoke(17);

    asserts.assert(calls == 4);
    return asserts.done();
  }

  public function testGuarding()
    return Future.irreversible(done -> {
      var i = 100000;
      final finished = true;
      function rec()
        if (--i == 0) {
          asserts.assert(finished);
          done(asserts.done());
        }
        else
          Callback.guardStackoverflow(rec);
        rec();
    });

  // Runs `f` at the point where the guarded call stack is exhausted, i.e. with a
  // non-empty overflow queue, so that every guarded call made by `f` is parked.
  // Recurses under the guard until one of its own guarded calls fails to run.
  function atStackLimit(f:()->Void) {
    var reached = false;
    function recurse():Bool {
      if (reached) return false;
      var ran = false;
      Callback.guardStackoverflow(() -> {
        ran = true;
        if (recurse()) {
          reached = true;
          f();
        }
      });
      return !ran;
    }
    recurse();
  }

  public function testOverflowOrder() {
    final order = [];

    atStackLimit(() -> {
      Callback.guardStackoverflow(() -> {
        order.push('a');
        atStackLimit(() -> {
          Callback.guardStackoverflow(() -> order.push('a1'));
          Callback.guardStackoverflow(() -> order.push('a2'));
        });
      });
      Callback.guardStackoverflow(() -> order.push('b'));
      Callback.guardStackoverflow(() -> order.push('c'));
    });

    // the queue is drained once the guarded stack unwinds, which happens after
    // this test method returns, hence the deferred assertion
    Callback.defer(() -> {
      // parked continuations run in the order they were parked, and those parked
      // while a parked continuation runs go before the rest of the queue
      asserts.assert(order.join(',') == 'a,a1,a2,b,c', 'order: ' + order.join(','));
      asserts.done();
    });

    return asserts;
  }

  public function testOverflowVolume() {
    final total = 10000;
    var count = 0;

    atStackLimit(() -> for (i in 0...total) Callback.guardStackoverflow(() -> count++));

    Callback.defer(() -> {
      asserts.assert(count == total, '$count of $total parked callbacks ran');
      asserts.done();
    });

    return asserts;
  }

  public function testDefer() {

    var counter = 0;
    function count()
      counter++;

    Callback.defer(count);
    Callback.defer(count);
    Callback.defer(() -> {
      asserts.assert(counter == 2);
      asserts.done();
    });

    asserts.assert(counter == 0);
    return asserts;
  }

  public function testSimpleLink() {
    var calls = 0;
    final link:CallbackLink = () -> calls++;
    link.cancel();
    link.cancel();
    asserts.assert(calls == 1);
    return asserts.done();
  }

  public function testLinkPair() {
    var calls = 0;
    var calls1 = 0;
    var calls2 = 0;

    final link1:CallbackLink = () -> { calls++; calls1++; }
    final link2:CallbackLink = () -> { calls++; calls2++; }
    final link = link1 & link2;

    link.cancel();
    asserts.assert(calls == 2);
    asserts.assert(calls1 == 1);
    asserts.assert(calls2 == 1);

    link.cancel();
    asserts.assert(calls == 2);

    link1.cancel();
    asserts.assert(calls1 == 1);

    link2.cancel();
    asserts.assert(calls2 == 1);
    return asserts.done();
  }

  public function testList() {
    final cb = new CallbackList();

    asserts.assert(cb.length == 0);

    var calls = 0;
    var calls1 = 0;
    var calls2 = 0;

    final link1 = cb.add(() -> { calls++; calls1++; });
    final link2 = cb.add(_ -> { calls++; calls2++; });

    asserts.assert(cb.length == 2);

    cb.invoke(true);

    asserts.assert(calls == 2);
    asserts.assert(calls1 == 1);
    asserts.assert(calls2 == 1);

    link1.cancel();

    asserts.assert(cb.length == 1);

    link1.cancel();

    asserts.assert(cb.length == 1);

    cb.invoke(true);

    asserts.assert(calls == 3);
    asserts.assert(calls1 == 1);
    asserts.assert(calls2 == 2);

    return asserts.done();
  }

  @:describe("null CallbackLink should be noop and not crash")
  public function testNullCallbackLink() {
    final link:CallbackLink = null;
    link.cancel();

    final fn:()->Void = link;
    fn();

    final cb:Callback<Noise> = link;
    cb.invoke(Noise);

    final pair = link & link;
    pair.cancel();

    final many:CallbackLink = [link, link];
    many.cancel();

    return asserts.done();
  }

  /*public function testListCompaction() {
    var on = 0,
        off = 0,
        last = 0;

    var list = new CallbackList(count -> {
      switch [count, last] {
        case [0, 1]: on++;
        case [1, 0]: off++;
        default:
      }
      last = count;
    });

    for (i in 0...100)
      for (link in [for (i in 0...1 + Std.random(20)) list.add(() -> {})])
        link.cancel();

    asserts.assert(list.length == 0);
    asserts.assert(on == 100);
    asserts.assert(off == 100);
    return asserts.done();
  }*/
}

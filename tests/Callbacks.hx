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

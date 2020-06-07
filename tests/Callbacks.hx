package ;

import tink.unit.Assert.*;

using tink.CoreApi;

@:asserts
class Callbacks extends Base {
  public function testInvoke() {
    var calls = 0;
    var cbs:Array<Callback<Int>> = [
      function () calls++,
      function (_) calls++
    ];
    cbs.push(cbs.copy());

    for (c in cbs)
      c.invoke(17);

    asserts.assert(calls == 4);
    return asserts.done();
  }

  public function testGuarding()
    return Future.async(done -> {
      var i = 100000,
          finished = true;
      function rec()
        if (--i == 0) {
          asserts.assert(finished);
          done(asserts.done());
        }
        else
          @:privateAccess Callback.guarded(rec);
      rec();
    });

  #if (js || flash || haxe_ver >= 3.3)
  #if java @:exclude #end
  public function testDefer() {

    var counter = 0;
    function count()
      counter++;

    Callback.defer(count);
    Callback.defer(count);
    Callback.defer(function () {
      asserts.assert(counter == 2);
    });

    asserts.assert(counter == 0);
    return asserts.done();
  }
  #end

  public function testSimpleLink() {
    var calls = 0;
    var link:CallbackLink = function () calls++;
    link.cancel();
    link.cancel();
    asserts.assert(calls == 1);
    return asserts.done();
  }

  public function testLinkPair() {
    var calls = 0,
      calls1 = 0,
      calls2 = 0;

    var link1:CallbackLink = function () { calls++; calls1++; }
    var link2:CallbackLink = function () { calls++; calls2++; }
    var link = link1 & link2;

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
    var cb = new CallbackList();

    asserts.assert(cb.length == 0);

    var calls = 0,
        calls1 = 0,
        calls2 = 0;

    var link1 = cb.add(function () { calls++; calls1++; } ),
        link2 = cb.add(function (_) { calls++; calls2++; });

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
      for (link in [for (i in 0...1 + Std.random(20)) list.add(function () {})])
        link.cancel();

    asserts.assert(list.length == 0);
    asserts.assert(on == 100);
    asserts.assert(off == 100);
    return asserts.done();
  }*/
}
package ;

using tink.CoreApi;

@:asserts
class Futures extends Base {
  public function testSync() {
    var f = Future.sync(4);
    var x = -4;
    f.handle(function (v) x = v);
    asserts.assert(4 == x);
    f = 12;
    f.map(function (v) return v * 2).handle(function (v) x = v);
    asserts.assert(24 == x);
    return asserts.done();
  }

  public function testOfAsyncCall() {
    var callbacks:Array<Int->Void> = [];
    function fake(callback:Int->Void) {
      callbacks.push(callback);
    }
    function trigger()
      for (c in callbacks) c(4);

    var f = Future.irreversible(fake).eager();

    var calls = 0;

    var link1 = f.handle(function () calls++),
        link2 = f.handle(function () calls++);

    f.handle(function (v) {
      asserts.assert(4 == v);
      calls++;
    });

    asserts.assert(1 == callbacks.length);
    link1.cancel();

    trigger();

    asserts.assert(2 == calls);
    return asserts.done();
  }

  public function testTrigger() {
    var t = Future.trigger();
    asserts.assert(t.trigger(4));
    asserts.assert(!t.trigger(4));

    t = Future.trigger();

    var f:Future<Int> = t;

    var calls = 0;

    f.handle(function (v) {
      asserts.assert(4 == v);
      calls++;
    });

    t.trigger(4);

    asserts.assert(1 == calls);
    return asserts.done();
  }

  public function testFlatten() {
    var f = Future.sync(Future.sync(4));
    var flat = Future.flatten(f),
      calls = 0;

    flat.handle(function (v) {
      asserts.assert(4 == v);
      calls++;
    });

    asserts.assert(1 == calls);
    return asserts.done();
  }

  public function issue131() {
    var future = new Future(yield -> null);
    asserts.assert(future.status.match(Suspended));
    var link = future.handle(_ -> {});
    asserts.assert(!future.status.match(Suspended));
    link.cancel();
    asserts.assert(future.status.match(Suspended));
    return asserts.done();
  }

  public function issue142() {
    var t1 = Future.trigger(),
        t2 = Future.trigger(),
        t3 = Future.trigger();

    t2.trigger(42);
    t3.trigger(Failure(new Error('haha!')));

    var a = [
      Promise.lift(t1),
      Promise.lift(t2),
      Promise.lift(t3),
    ];

    t1.trigger(Success(123));
    return asserts.done();
  }

  public function issue143() {
    asserts.assert(Future.never() == Promise.never());
    for (shouldHalt in [true, false]) {
      function tryGetData():Promise<{ foo: Int }> return shouldHalt ? Promise.never() : { foo: 123 };
      if (shouldHalt)
        asserts.assert(tryGetData().status.match(NeverEver));
      else
        asserts.assert(tryGetData().status.match(Ready(_)));
    }

    for (shouldHalt in [true, false]) {
      function tryGetData()
        return Promise.resolve(123).next(
          v -> Promise.lift(!shouldHalt ? { foo: 123 } : Promise.never())
        ).eager();
      asserts.assert(tryGetData().status.match(Ready(_)) != shouldHalt);
    }

    return asserts.done();
  }

  public function issue153() {
    asserts.assert((Future.never():Future<Noise>) == (Future.never():Future<Noise>));
    asserts.assert((Promise.never():Promise<Noise>) == (Promise.never():Promise<Noise>));

    return asserts.done();
  }

  public function testOps() {
    var t1 = Future.trigger(),
        t2 = Future.trigger();
    var f1:Future<Int> = t1,
        f2:Future<Int> = t2;

    var f = (f1 || f2).eager();
    t1.trigger(1);
    t2.trigger(2);

    asserts.assert(f.status.match(Ready(_.get() => 1)));
    var f = (f1 && f2).eager();

    asserts.assert(f.status.match(Ready(_.get() => {a : 1, b: 2 })));

    var t1 = Future.trigger(),
        t2 = Future.trigger();
    var f1:Future<Int> = t1,
        f2:Future<Noise> = t2;

    t1.trigger(1);
    t2.trigger(Noise);

    var f = f1 || f2;

    // asserts.assert(f.status.match(Ready(_.get() => Left(1))));

    return asserts.done();
  }

  public function testMany() {
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

    var f = Future.inSequence(futures).map(sum.bind(_, 0)),
        f2 = Future.inSequence(futures).map(sum.bind(_, 0));

    asserts.assert(!read1);
    asserts.assert(!read2);

    f.handle(function(v) asserts.assert(v == 65));
    f2.handle(function(v) asserts.assert(v == 65));

    var handled = false;
    f.handle(function () handled = true);

    asserts.assert(!handled);
    asserts.assert(read1);
    asserts.assert(!read2);

    for (i in 0...triggers.length)
      triggers[i].trigger(i);

    asserts.assert(handled);
    return asserts.done();
  }

  public function testNever() {
    var f:Future<Int> = Future.never();
    f.handle(function () {}).cancel();
    function foo<A>() {
      var f:Future<A> = Future.never();
      f.handle(function () {}).cancel();
    }
    foo();
    return asserts.done();
  }

  public function testDelay() {
    var now = haxe.Timer.stamp();
    var resolved = false;
    Future.delay(500, Noise).handle(function(_) {
      resolved = true;
      var dt = haxe.Timer.stamp() - now;
      asserts.assert(dt > .4); // it may not be very exact
      asserts.assert(dt < .6); // it may not be very exact
      asserts.done();
    });
    asserts.assert(!resolved);

    return asserts;

  }

  public function testFirst() {
    var triggered1 = false;
    var triggered2 = false;
    var cancelled1 = false;
    var cancelled2 = false;

    var f1 = new Future(cb -> {
      var timer = haxe.Timer.delay(function() {
        triggered1 = true;
        cb(1);
      }, 50);
      function() {
        cancelled1 = true;
        timer.stop();
      }
    });
    var f2 = new Future(cb -> {
      var timer = haxe.Timer.delay(function() {
        triggered2 = true;
        cb(2);
      }, 100);
      function() {
        cancelled2 = true;
        timer.stop();
      }
    });

    f1.first(f2).handle(function(o) {
      asserts.assert(o == 1);
      Callback.defer(function() {
        asserts.assert(triggered1);
        asserts.assert(cancelled1);
        asserts.assert(!triggered2);
        asserts.assert(cancelled2);
        asserts.done();
      });
    });

    return asserts;

  }

  public function testNoise() {
    var f = Future.sync(42);
    f.noise().handle(v -> asserts.assert(v == Noise));
    (f : Future<Noise>).handle(v -> asserts.assert(v == Noise));
    return asserts.done();
  }

  #if (js && js.compat)
  public function issue161() {
    var f = Future.sync(42);
    var p:js.lib.Promise<Int> = cast f;
    return Promise.lift(p).next(v -> {
      asserts.assert(v == 42);
      asserts.done();
    });
  }
  #end
}

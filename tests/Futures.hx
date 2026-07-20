package ;

using tink.CoreApi;

@:asserts
class Futures extends Base {
  public function testSync() {
    var f = Future.sync(4);
    var x = -4;
    f.handle(v -> { x = v; });
    asserts.assert(4 == x);
    f = 12;
    f.map(v -> v * 2).handle(v -> { x = v; });
    asserts.assert(24 == x);
    return asserts.done();
  }

  public function testOfAsyncCall() {
    final callbacks:Array<Int->Void> = [];
    function fake(callback:Int->Void) {
      callbacks.push(callback);
    }
    function trigger()
      for (c in callbacks) c(4);

    final f = Future.irreversible(fake).eager();

    var calls = 0;

    final link1 = f.handle(() -> calls++);
    final link2 = f.handle(() -> calls++);

    f.handle(v -> {
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

    final f:Future<Int> = t;

    var calls = 0;

    f.handle(v -> {
      asserts.assert(4 == v);
      calls++;
    });

    t.trigger(4);

    asserts.assert(1 == calls);
    return asserts.done();
  }

  public function testFlatten() {
    final f = Future.sync(Future.sync(4));
    final flat = Future.flatten(f);
    var calls = 0;

    flat.handle(v -> {
      asserts.assert(4 == v);
      calls++;
    });

    asserts.assert(1 == calls);
    return asserts.done();
  }

  public function issue131() {
    final future = new Future(yield -> null);
    asserts.assert(future.status.match(Suspended));
    final link = future.handle(_ -> {});
    asserts.assert(!future.status.match(Suspended));
    link.cancel();
    asserts.assert(future.status.match(Suspended));
    return asserts.done();
  }

  public function issue142() {
    final t1 = Future.trigger();
    final t2 = Future.trigger();
    final t3 = Future.trigger();

    t2.trigger(42);
    t3.trigger(Failure(new Error('haha!')));

    final a = [
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
          v -> shouldHalt ? Promise.never() :  { foo: 123 }
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
    final t1 = Future.trigger();
    final t2 = Future.trigger();
    final f1:Future<Int> = t1;
    final f2:Future<Int> = t2;

    final fOr = (f1 || f2).eager();
    t1.trigger(1);
    t2.trigger(2);

    asserts.assert(fOr.status.match(Ready(_.get() => 1)));
    final fAnd = (f1 && f2).eager();

    asserts.assert(fAnd.status.match(Ready(_.get() => {a : 1, b: 2 })));

    final t1b = Future.trigger();
    final t2b = Future.trigger();
    final f1b:Future<Int> = t1b;
    final f2b:Future<Noise> = t2b;

    t1b.trigger(1);
    t2b.trigger(Noise);

    final fb = f1b || f2b;

    // asserts.assert(fb.status.match(Ready(_.get() => Left(1))));

    return asserts.done();
  }

  public function testMany() {
    final triggers = [for (i in 0...10) Future.trigger()];
    final futures = [for (t in triggers) t.asFuture()];

    var read1 = false;
    var read2 = false;

    final lazy1 = Future.lazy(() -> {
      read1 = true;
      return 10;
    });

    final lazy2 = Future.lazy(() -> {
      read2 = true;
      return 10;
    });

    futures.unshift(lazy1);
    futures.push(lazy2);

    function sum(a:Array<Int>, ?index = 0)
      return
        if (index < a.length) a[index] + sum(a, index + 1);
        else 0;

    final f = Future.inSequence(futures).map(sum.bind(_, 0));
    final f2 = Future.inSequence(futures).map(sum.bind(_, 0));

    asserts.assert(!read1);
    asserts.assert(!read2);

    f.handle(v -> asserts.assert(v == 65));
    f2.handle(v -> asserts.assert(v == 65));

    var handled = false;
    f.handle(() -> handled = true);

    asserts.assert(!handled);
    asserts.assert(read1);
    asserts.assert(!read2);

    for (i in 0...triggers.length)
      triggers[i].trigger(i);

    asserts.assert(handled);
    return asserts.done();
  }

  public function testNever() {
    final f:Future<Int> = Future.never();
    f.handle(() -> {}).cancel();
    function foo<A>() {
      final f:Future<A> = Future.never();
      f.handle(() -> {}).cancel();
    }
    foo();
    return asserts.done();
  }

  public function testDelay() {
    final now = haxe.Timer.stamp();
    var resolved = false;
    Future.delay(500, Noise).handle(_ -> {
      resolved = true;
      final dt = haxe.Timer.stamp() - now;
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

    final f1 = new Future(cb -> {
      final timer = haxe.Timer.delay(() -> {
        triggered1 = true;
        cb(1);
      }, 50);
      () -> {
        cancelled1 = true;
        timer.stop();
      }
    });
    final f2 = new Future(cb -> {
      final timer = haxe.Timer.delay(() -> {
        triggered2 = true;
        cb(2);
      }, 100);
      () -> {
        cancelled2 = true;
        timer.stop();
      }
    });

    f1.first(f2).handle(o -> {
      asserts.assert(o == 1);
      Callback.defer(() -> {
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
    final f = Future.sync(42);
    f.noise().handle(v -> asserts.assert(v == Noise));
    (f : Future<Noise>).handle(v -> asserts.assert(v == Noise));
    return asserts.done();
  }

  #if (js && js.compat)
  public function issue161() {
    final f = Future.sync(42);
    final p:js.lib.Promise<Int> = cast f;
    return Promise.lift(p).next(v -> {
      asserts.assert(v == 42);
      asserts.done();
    });
  }
  #end
  
  
  public function andCall() {
    return Future.sync(42).and(Future.sync('foo'))
      .next(v -> {
        asserts.assert(v.a == 42);
        asserts.assert(v.b == 'foo');
        return asserts.done();
      });
  }
  
  public function andOp() {
    return (Future.sync(42) && Future.sync('foo'))
      .next(v -> {
        asserts.assert(v.a == 42);
        asserts.assert(v.b == 'foo');
        return asserts.done();
      });
  }
}

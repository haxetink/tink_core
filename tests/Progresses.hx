import tink.core.Progress;

using tink.CoreApi;

@:asserts
class Progresses {
  public function new() {}

  public function testProgress() {
    var trigger = Progress.trigger();
    var progress = trigger.asProgress();

    var p;
    progress.listen(function(v) p = v);
    trigger.progress(0.5, None);
    asserts.assert(p.value == 0.5);
    asserts.assert(p.total.match(None));
    trigger.finish('Done');
    progress.handle(function(v) {
      asserts.assert(v == 'Done');
      asserts.done();
    });

    return asserts;
  }

  public function testFutureProgress() {
    var trigger = Progress.trigger();
    var progress:Progress<String> = Future.sync(trigger.asProgress());

    var p;
    progress.listen(function(v) p = v);
    trigger.progress(0.5, None);
    asserts.assert(p.value == 0.5);
    asserts.assert(p.total.match(None));
    trigger.finish('Done');
    progress.handle(function(v) {
      asserts.assert(v == 'Done');
      asserts.done();
    });

    return asserts;
  }

  public function testPromiseProgress() {
    var trigger = Progress.trigger();
    var progress:Progress<Outcome<String, Error>> = Promise.resolve(trigger.asProgress());

    var p;
    progress.listen(function(v) p = v);
    trigger.progress(0.5, None);
    asserts.assert(p.value == 0.5);
    asserts.assert(p.total.match(None));
    trigger.finish('Done');
    progress.next(function(o) {
      asserts.assert(o.sure() == 'Done');
      return Noise;
    }).eager();
    progress.asPromise().next(function(o) {
      asserts.assert(o == 'Done');
      return Noise;
    }).eager();
    progress.handle(function(v) {
      asserts.assert(v.match(Success('Done')));
      asserts.done();
    });

    return asserts;
  }

  public function testMake() {
    var t = new SignalTrigger<ProgressStatus<String>>(),
        hot = false;

    var p = Progress.make((progress, finish) -> {
      hot = true;
      t.asSignal().handle(status -> switch status {
        case InProgress(v): progress(v.value, v.total);
        case Finished(v): finish(v);
      }) & function () hot = false;
    });

    function progress(to)
      t.trigger(InProgress(new ProgressValue(to, None)));

    asserts.assert(p.status.match(InProgress({ value: 0 })));

    progress(.25);

    asserts.assert(p.status.match(InProgress({ value: 0 })));

    var link = p.handle(function () {});
    asserts.assert(hot);

    asserts.assert(p.status.match(InProgress({ value: 0 })));

    progress(.25);

    asserts.assert(p.status.match(InProgress({ value: .25 })));

    link.cancel();

    progress(.5);

    asserts.assert(p.status.match(InProgress({ value: .25 })));

    link = p.listen(function () {});

    asserts.assert(p.status.match(InProgress({ value: .25 })));

    progress(.5);

    asserts.assert(p.status.match(InProgress({ value: .5 })));

    link.cancel();

    progress(.75);

    asserts.assert(p.status.match(InProgress({ value: .5 })));

    var upper = p.map(s -> s.toUpperCase());

    asserts.assert(p.status.match(InProgress({ value: .5 })));

    var result = null;
    upper.result.handle(r -> result = r);

    asserts.assert(p.status.match(InProgress({ value: .5 })));
    asserts.assert(upper.status.match(InProgress({ value: .5 })));

    progress(.75);

    asserts.assert(p.status.match(InProgress({ value: .75 })));
    asserts.assert(upper.status.match(InProgress({ value: .75 })));

    t.trigger(Finished('haha'));

    asserts.assert(p.status.match(Finished('haha')));
    asserts.assert(upper.status.match(Finished('HAHA')));

    return asserts.done();
  }
}
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
}
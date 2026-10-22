package ;

import tink.core.Disposable;

using tink.CoreApi;

@:asserts
class Disposables extends Base {
  public function testCancelOndispose() {
    final log = [];
    final d = new SimpleDisposable(() -> log.push('teardown'));
    final links = [for (i in 0...5) d.ondispose(() -> log.push('$i'))];
    links[1].cancel();
    links[3].cancel();
    links[3].cancel();
    d.dispose();
    asserts.assert(log.join(',') == 'teardown,0,2,4');
    links[0].cancel();
    d.dispose();
    asserts.assert(log.join(',') == 'teardown,0,2,4');
    return asserts.done();
  }

  public function testCancelDuringDispose() {
    final log = [];
    final d = new SimpleDisposable(() -> {});
    var second:CallbackLink = null;
    d.ondispose(() -> {
      log.push('first');
      second.cancel();
    });
    second = d.ondispose(() -> log.push('second'));
    d.ondispose(() -> log.push('third'));
    d.dispose();
    asserts.assert(log.join(',') == 'first,third');
    return asserts.done();
  }

  public function testCancelledHandlersAreReleased() {
    final d = new SimpleDisposable(() -> {});
    var calls = 0;
    d.ondispose(() -> calls++);
    for (i in 0...1000)
      d.ondispose(() -> calls += 1000).cancel();
    asserts.assert(@:privateAccess d.disposeHandlers.length == 1);
    d.dispose();
    asserts.assert(calls == 1);
    return asserts.done();
  }

  public function testOndisposeWhenDisposed() {
    var calls = 0;
    final d = new SimpleDisposable(() -> {});
    d.dispose();
    final link = d.ondispose(() -> calls++);
    asserts.assert(calls == 1);
    link.cancel();
    AlreadyDisposed.INST.ondispose(() -> calls++).cancel();
    asserts.assert(calls == 2);
    return asserts.done();
  }
}

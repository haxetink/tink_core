package ;

using tink.CoreApi;

#if js
import js.lib.Error as JsError;
#end

@:asserts
class Errors extends Base {
  #if js
  public function ofJs() {
    final message = 'whatever';
    final jsError = new JsError(message);
    final err = Error.ofJsError(jsError);
    asserts.assert(err.code == 500);
    asserts.assert(err.message == message);
    asserts.assert(err.data == jsError);
    return asserts.done();
  }
  
  public function toJs() {
    final message = 'whatever';
    final err = new Error(message);
    final jsError = err.toJsError();
    asserts.assert(jsError.message == message);
    asserts.assert((untyped jsError.data) == err);
    return asserts.done();
  }
  
  public function reuseNative() {
    final message = 'whatever';
    final js1 = new JsError(message);
    final err = Error.ofJsError(js1);
    final js2 = err.toJsError();
    asserts.assert(js1 == js2);
    return asserts.done();
  }
  #end
  
  public function catchExceptions() {
    return switch Error.catchExceptions(() -> throw 'foo') {
      case Success(_):
        asserts.fail('Expected failure');
      case Failure(e):
        asserts.assert(e.data == 'foo');
        asserts.done();
    }
  }
  
  public function toPromise() {
    final e:TypedError<Int> = TypedError.typed(500, '', 42);
    final p:Promise<Noise> = e.toPromise();
    return p.map(o -> switch o {
      case Success(_):
        asserts.fail('expected failure');
      case Failure(e):
        asserts.assert(e.data == 42);
        asserts.done();
    });
  }
}

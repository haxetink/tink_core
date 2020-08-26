package ;

using tink.CoreApi;

#if js
import js.lib.Error as JsError;
#end

@:asserts
class Errors extends Base {
  #if js
  public function ofJs() {
    var message = 'whatever';
    var jsError = new JsError(message);
    var err = Error.ofJsError(jsError);
    asserts.assert(err.code == 500);
    asserts.assert(err.message == message);
    asserts.assert(err.data == jsError);
    return asserts.done();
  }
  
  public function toJs() {
    var message = 'whatever';
    var err = new Error(message);
    var jsError = err.toJsError();
    asserts.assert(jsError.message == message);
    asserts.assert((untyped jsError.data) == err);
    return asserts.done();
  }
  
  public function reuseNative() {
    var message = 'whatever';
    var js1 = new JsError(message);
    var err = Error.ofJsError(js1);
    var js2 = err.toJsError();
    asserts.assert(js1 == js2);
    return asserts.done();
  }
  #end
}

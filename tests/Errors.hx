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
    asserts.assert(500 == err.code);
    asserts.assert(message == err.message);
    asserts.assert(jsError == err.data);
    return asserts.done();
  }
  
  public function toJs() {
    var message = 'whatever';
    var js1 = new JsError(message);
    var err = Error.ofJsError(js1);
    var js2 = err.toJsError();
    asserts.assert(js1 == js2);
    return asserts.done();
  }
  #end
}

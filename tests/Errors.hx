package ;

using tink.CoreApi;

#if js
import #if haxe4 js.lib.Error #else js.Error #end as JsError;
#end

@:asserts
class Errors extends Base {
  #if js
  public function testOfJsError() {
    var message = 'whatever';
    var jsError = new JsError(message);
    var err = Error.ofJsError(jsError);
    asserts.assert(500 == err.code);
    asserts.assert(message == err.message);
    asserts.assert(jsError == err.data);
    return asserts.done();
  }
  #end
}

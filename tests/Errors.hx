package ;

using tink.CoreApi;

@:asserts
class Errors extends Base {
  #if js
  public function testOfJsError() {
    var message = 'whatever';
    var jsError = new js.Error(message);
    var err = Error.ofJsError(jsError);
    asserts.assert(500 == err.code);
    asserts.assert(message == err.message);
    asserts.assert(jsError == err.data);
    return asserts.done();
  }
  #end
}

package ;

using tink.CoreApi;

class Errors extends Base {
  
  function testOfJsError() {
    var message = 'whatever';
    var jsError = new js.Error(message);
    var err = Error.ofJsError(jsError);
    assertEquals(500, err.code);
    assertEquals(message, err.message);
    assertEquals(jsError, err.data);
  }
}
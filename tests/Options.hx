package ;

using tink.CoreApi;

@:asserts
class Options extends Base {
  public function testSure() {
    asserts.assert(4 == Some(4).force());
    
    throws(
      asserts,
      function () None.force(),
      Error,
      function (e) return e.message == 'Some value expected but none found'
    );
    
    return asserts.done();
  }
  
  public function testEquals() {
    asserts.assert(Some(4).equals(4));
    asserts.assert(!Some(-4).equals(4));
    asserts.assert(!None.equals(4));
    return asserts.done();
  }
  
}
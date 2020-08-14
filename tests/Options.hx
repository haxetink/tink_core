package ;

using tink.CoreApi;

@:asserts
class Options extends Base {
  public function testSure() {
    asserts.assert(4 == Some(4).sure());
    
    throws(
      asserts,
      function () None.sure(),
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
  
  public function or() {
    var some = Some(1);
    var none = None;
        
    asserts.assert(some.orNull() == 1);
    asserts.assert(none.orNull() == null);
        
    asserts.assert(some.or(5) == 1);
    asserts.assert(none.or(5) == 5);
        
    asserts.assert(some.orTry(Some(2)).match(Some(1)));
    asserts.assert(none.orTry(Some(2)).match(Some(2)));
    asserts.assert(none.orTry(None).match(None));
    
    return asserts.done();
  }
  
}
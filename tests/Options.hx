package ;

using tink.CoreApi;

class Options extends Base {
  
  function testSure() {
    assertEquals(4, Some(4).force());
    
    throws(
      function () None.force(),
      Error,
      function (e) return e.message == 'Some value expected but none found'
    );
  }
  
  function testEquals() {
    assertTrue(Some(4).equals(4));
    assertFalse(Some(-4).equals(4));
    assertFalse(None.equals(4));
  }
  
  function eq<A:EnumValue>(exp:A, found:A) 
    assertTrue(Type.enumEq(exp, found));
  
}
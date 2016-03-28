package ;

using tink.CoreApi;

class Refs extends Base {
  function testImplicit() {
    var r:Ref<Int> = 5;
    assertEquals(5, r);
  }
}
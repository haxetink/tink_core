package ;

using tink.CoreApi;

@:asserts
class Refs extends Base {
  public function testImplicit() {
    final r:Ref<Int> = 5;
    asserts.assert(r == 5);
    return asserts.done();
  }
}

package ;

using tink.CoreApi;

@:asserts
class Pairs extends Base {
  public function test() {
    var c = new Pair(new Pair(1, 2), new Pair(3, 4));
    
    asserts.assert(1 == c.a.a);
    asserts.assert(2 == c.a.b);
    asserts.assert(3 == c.b.a);
    asserts.assert(4 == c.b.b);
    
    return asserts.done();
  }
}
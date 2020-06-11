package;

using tink.CoreApi;

@:asserts
class Lazies extends Base {
  @:include public function ridiculousDepth() {
    var l:Lazy<Int> = 0;
    for (i in 0...1000000)
      l = l.map(x -> x + 1);
    asserts.assert(l.get() == 1000000);
    return asserts.done();
  }
  public function testLaziness() {
    var counter = 0;

    function double(x):Int {
      ++counter;
      return x * 2;
    }

    function lazyDouble(x):Lazy<Int> {
      ++counter;
      return x * 2;
    }

    function test(i:Lazy<Int>, expected:Int) {
      counter = 0;
      var j = i.map(double);
      asserts.assert(0 == counter);
      asserts.assert(j.get() == expected);
      j.get();
      asserts.assert(1 == counter);

      counter = 0;
      var k = i.flatMap(lazyDouble);
      asserts.assert(0 == counter);
      asserts.assert(k.get() == expected);
      k.get();
      asserts.assert(1 == counter);
    }

    test(7, 14);
    test(function () return 11, 22);

    return asserts.done();
  }
}

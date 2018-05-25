package;

using tink.CoreApi;

class Lazies extends Base {
  function testLaziness() {
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
      assertEquals(0, counter);
      assertEquals(j.get(), expected);
      j.get();
      assertEquals(1, counter);

      counter = 0;
      var k = i.flatMap(lazyDouble);
      assertEquals(0, counter);
      assertEquals(k.get(), expected);
      k.get();
      assertEquals(1, counter);
    }

    test(7, 14);
    test(function () return 11, 22);
  }
}

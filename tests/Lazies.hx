package;

using tink.CoreApi;

class Lazies extends Base {
  function testConst() {
    var counter = 0;

    function double(x):Int {
      ++counter;
      return x * 2;
    }

    function lazyDouble(x):Lazy<Int> {
      ++counter;
      return x * 2;
    }

    var i:Lazy<Int> = 7;

    var j = i.map(double);
    assertEquals(0, counter);
    assertEquals(j.get(), 14);
    j.get();
    assertEquals(1, counter);

    counter = 0;

    var k = i.flatMap(lazyDouble);
    assertEquals(0, counter);
    assertEquals(k.get(), 14);
    k.get();
    assertEquals(1, counter);
  }
}


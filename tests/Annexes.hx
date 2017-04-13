package ;

using tink.CoreApi;

class Annexes extends Base {
  function testAll() {
    var car = new Car();
    assertEquals(car.parts.get(Engine), car.parts.get(Engine));
  }
}

private class Car {
  
  public var parts(default, null):Annex<Car>;

  public function new() {
    this.parts = new Annex(this);
  }
}

private class Engine {
  public function new(c:Car) {

  }
}
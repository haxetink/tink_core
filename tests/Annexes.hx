package ;

import tink.unit.Assert.*;

using tink.CoreApi;

@:asserts
class Annexes extends Base {
  public function testAll() {
    var car = new Car();
    return assert(car.parts.get(Engine) == car.parts.get(Engine));
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
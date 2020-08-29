package tink.core;

enum abstract Noise(Null<Dynamic>) {
  var Noise = null;
  @:from static function ofAny<T>(t:Null<T>):Noise
    return Noise;
}

abstract Never(Noise) to Dynamic {
}
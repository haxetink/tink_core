package tink.core;

enum abstract Noise(Null<Dynamic>) {
  var Noise = null;
  @:from static function ofAny<T>(t:Null<T>):Noise
    return Noise;
}

#if (haxe_ver < 4.2)
typedef Never = Dynamic;
#else
abstract Never(Dynamic) to Dynamic from Dynamic {
}
#end
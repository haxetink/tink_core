package tink.core;

enum abstract Noise(Null<Dynamic>) {
	var Noise = null;
	@:from static inline function ofAny<T>(t:Null<T>):Noise
		return Noise;
}
package tink.core;

#if (haxe_ver >= 3.4)
typedef Any = std.Any;
#else
abstract Any(Dynamic) from Dynamic {
  @:noCompletion @:to inline function __promote<A>():A return this;
}
#end
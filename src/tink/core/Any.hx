package tink.core;

abstract Any(Dynamic) from Dynamic {
  @:noCompletion @:to inline function __promote<A>():A return this;
}
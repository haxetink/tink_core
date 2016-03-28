package tink.core;

abstract Ref<T>(haxe.ds.Vector<T>) {
  public var value(get, set):T;
  
  inline function new() this = new haxe.ds.Vector(1);
  
  @:to inline function get_value():T return this[0];
  inline function set_value(param:T) return this[0] = param;
  
  public function toString():String return '@[' + Std.string(value)+']';
  
  @:noUsing @:from static inline public function to<A>(v:A):Ref<A> {
    var ret = new Ref();
    ret.value = v;
    return ret;
  }
}
package tink.core;

abstract Ref<T>({ v: T }) {
	//TODO: optimize. On many platforms instances or native one-element arrays is be better
	public var value(get, set):T;
	
	inline function new(v:T) this = { v: v };
	
	@:to inline function get_value():T return this.v;
	inline function set_value(param:T) return this.v = param;
	
	public function toString():String return '@[' + Std.string(value)+']';
	@:from static inline public function to<A>(v:A) return new Ref(v);
}
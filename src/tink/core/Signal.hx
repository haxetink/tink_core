package tink.core;

import tink.core.Callback;
import tink.core.Noise;

abstract Signal<T>(Callback<T>->CallbackLink) {
	
	public inline function new(f:Callback<T>->CallbackLink) this = f;	
	
	public function when(handler:Callback<T>):CallbackLink 
		return (this)(handler);
	
	public function map<A>(f:T->A, ?dike = true):Signal<A> {
		var ret = new Signal(function (cb) return (this)(function (result) cb.invoke(f(result))));
		if (dike) ret = ret.dike();
		return ret;
	}
		
	public function next():Future<T> {
		var ret = Future.create();
		when(ret.invoke);
		return ret.asFuture();
	}
	
	public function noise():Signal<Noise>
		return map(function (_) return Noise);
	
	public function dike():Signal<T> {
		var ret = new CallbackList<T>();
		when(ret.invoke);
		return ret;
	}
}
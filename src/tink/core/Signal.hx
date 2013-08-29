package tink.core;

import tink.core.Callback;
import tink.core.Noise;

abstract Signal<T>(Callback<T>->CallbackLink) {
	
	public inline function new(f:Callback<T>->CallbackLink) this = f;	
	
	public function when(handler:Callback<T>):CallbackLink 
		return (this)(handler);
	
	public function map<A>(f:T->A, ?gather = true):Signal<A> {
		var ret = new Signal(function (cb) return when(this, function (result) cb.invoke(f(result))));
		if (gather) ret = ret.gather();
		return ret;
	}
	
	public function filter(f:T->Bool, ?gather = true):Signal<T> {
		var ret = new Signal(function (cb) return when(this, function (result) if (f(result)) cb.invoke(result)));
		if (gather) ret = ret.gather();
		return ret;
	}
	
	public function join(other:Signal<T>, ?gather = true):Signal<T> {
		var ret = new Signal(
			function (cb:Callback<T>):CallbackLink 
				return [
					when(this, cb),
					other.when(cb)
				]
		);
		if (gather) ret = ret.gather();
		return ret;
	}
	
	public function next():Future<T> {
		var ret = Future.create();
		when(ret.invoke);
		return ret.asFuture();
	}
	
	public function noise():Signal<Noise>
		return map(function (_) return Noise);
	
	public function gather():Signal<T> {
		var ret = new CallbackList<T>();
		when(ret.invoke);
		return ret;
	}
}
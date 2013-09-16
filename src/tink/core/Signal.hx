package tink.core;

import tink.core.Callback;
import tink.core.Noise;

abstract Signal<T>(Callback<T>->CallbackLink) {
	
	public inline function new(f:Callback<T>->CallbackLink) this = f;	
	
	public function handle(handler:Callback<T>):CallbackLink 
		return (this)(handler);
	
	public function map<A>(f:T->A, ?gather = true):Signal<A> {
		var ret = new Signal(function (cb) return handle(this, function (result) cb.invoke(f(result))));
		return
			if (gather) ret.gather();
			else ret;
	}
	
	public function flatMap<A>(f:T->Future<A>, ?gather = true):Signal<A> {
		var ret = new Signal(function (cb) return handle(this, function (result) f(result).handle(cb)));
		return 
			if (gather) ret.gather() 
			else ret;
	}
	
	public function filter(f:T->Bool, ?gather = true):Signal<T> {
		var ret = new Signal(function (cb) return handle(this, function (result) if (f(result)) cb.invoke(result)));
		return
			if (gather) ret.gather();
			else ret;
	}
	
	public function join(other:Signal<T>, ?gather = true):Signal<T> {
		var ret = new Signal(
			function (cb:Callback<T>):CallbackLink 
				return [
					handle(this, cb),
					other.handle(cb)
				]
		);
		return
			if (gather) ret.gather();
			else ret;
	}
	
	public function next():Future<T> {
		var ret = Future.create();
		handle(ret.invoke);
		return ret.asFuture();
	}
	
	public function noise():Signal<Noise>
		return map(function (_) return Noise);
	
	public function gather():Signal<T> {
		var ret = new CallbackList<T>();
		handle(ret.invoke);
		return ret;
	}
}
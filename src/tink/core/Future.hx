package tink.core;

import tink.core.Callback;
import tink.core.Outcome;
import haxe.ds.Option;

abstract Future<T>(Callback<T>->CallbackLink) {

	public inline function new(f:Callback<T>->CallbackLink) this = f;	
		
	public inline function handle(callback:Callback<T>):CallbackLink //TODO: consider null-case
		return (this)(callback);
	
	public function gather():Future<T> {
		var op = Future.create(),
			active = true;
		return new Future(function (cb:Callback<T>) {
			if (active) {
				active = false;
				handle(this, op.invoke);
			}
			return op.asFuture().handle(cb);
		});
	}
	
	public function map<A>(f:T->A, ?gather = true):Future<A> {
		var ret = new Future(function (callback) return (this)(function (result) callback.invoke(f(result))));
		return
			if (gather) ret.gather();
			else ret;
	}
	
	public function flatMap<A>(next:T->Future<A>, ?gather = true):Future<A> {
		var ret = flatten(map(next, false));
		return
			if (gather) ret.gather();
			else ret;		
	}
		
	
	static public function flatten<A>(f:Future<Future<A>>):Future<A> 
		return new Future(function (callback) {
			var ret = null;
			ret = f.handle(function (next:Future<A>) {
				ret = next.handle(function (result) callback.invoke(result));
			});
			return ret;
		});
	
	@:from static inline function fromTrigger<A>(trigger:FutureTrigger<A>):Future<A> 
		return trigger.asFuture();
	
	@:from static function fromMany<A>(futures:Array<Future<A>>):Future<Array<A>> {
		var ret = ofConstant([]);
		for (f in futures)
			ret = ret.flatMap(
				function (results:Array<A>) 
					return f.map(
						function (result) 
							return results.concat([result])
					)
			);
		return ret;
	}
	
	@:noUsing static public function lazy<A>(calc:Void->A):Future<A> {
		var done = false,
			value = null;
		return
			new Future(function (cb:Callback<A>) {
				if (!done) {
					done = true;
					value = calc();
				}
				cb.invoke(value);
				return null;
			});
	}
	
	//It's very tempting to make this a @:from
	@:noUsing static public function ofConstant<A>(v:A):Future<A> 
		return new Future(function (callback) { callback.invoke(v); return null; } );
		
	@:noUsing static public function ofAsyncCall<A>(f:(A->Void)->Void):Future<A> {
		var op = create();
		f(op.invoke);
		return op;
	}
	
	@:noUsing static public inline function create<A>():FutureTrigger<A> 
		return new FutureTrigger();
	
	@:to public function toSurprise<F>():Surprise<T, F> 
		return map(Success);
	
}

class FutureTrigger<T> {
	var state:State<T>;
	var future:Future<T>;
	public function new() {
		state = Left(new CallbackList());
		future = new Future(
			function (callback)
				return 
					switch (state) {
						case Left(callbacks):
							callbacks.add(callback);
						case Right(result): 
							callback.invoke(result);
							null;
					}
		);
	}
	public inline function asFuture() return future;
	
	public function invoke(result:T):Bool {
		return
			switch (state) {
				case Left(callbacks):
					state = Right(result);
					callbacks.invoke(result);
					callbacks.clear();
					true;
				case Right(_):
					false;
			}
	}
}

private typedef State<T> = Either<CallbackList<T>, T>;

typedef Surprise<D, F> = Future<Outcome<D, F>>;
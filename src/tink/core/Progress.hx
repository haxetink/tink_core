package tink.core;

import tink.core.Callback;
import tink.core.Future;
import tink.core.Signal;

using tink.core.Progress.TotalTools;
using tink.CoreApi;

@:forward
abstract Progress<T>(ProgressObject<T>) from ProgressObject<T> {
	public static var INIT(default, null):ProgressValue = new Pair(0.0, None);

	public inline static function trigger<T>():ProgressTrigger<T> {
		return new ProgressTrigger();
	}
	
	public static function make<T>(f:(Float->Option<Float>->Void)->(T->Void)->Void) {
		var value = InProgress(INIT);
		var signal = Signal.trigger();
		var future = Future.async(function(cb) {
			function progress(v:Float, total:Option<Float>) {
				switch value {
					case Finished(_):
						// do nothing
					case InProgress(current):
						if (current.value != v || !current.total.eq(total)) {
							var pv = new Pair(v, total);
							value = InProgress(pv);
							signal.trigger(pv);
						}
				}
			}
			
			function finish(v:T) {
				switch value {
					case Finished(_):
						// do nothing
					case _:
						// TODO: clear signal handlers
						value = Finished(v);
						cb(v);
				}
			}
			
			f(progress, finish);
		});

		return new CompositeProgress(future, signal);
	}

	@:to
	public inline function asFuture():Future<T> {
		return this;
	}

	@:impl
	public static inline function asPromise<T>(p:ProgressObject<Outcome<T, Error>>):Promise<T>
		return ((p:Progress<Outcome<T, Error>>):Future<Outcome<T, Error>>);

	@:from
	static inline function promise<T>(v:Promise<Progress<T>>):Progress<Outcome<T, Error>> {
		return new PromiseProgress(v);
	}

	@:from
	static inline function future<T>(v:Future<Progress<T>>):Progress<T> {
		return new FutureProgress(v);
	}

	public inline function next(f) {
		return asFuture().next(f);
	}
}


class CompositeProgress<T> implements ProgressObject<T> {
	var future:Future<T>;
	var signal:Signal<ProgressValue>;
	
	public function new(future, signal) {
		this.future = future;
		this.signal = signal;
	}
	public inline function map<R>(f:T->R):Future<R> {
		return future.map(f);
	}
	public inline function flatMap<R>(f:T->Future<R>):Future<R> {
		return future.flatMap(f);
	}
	public inline function handle(callback:Callback<T>):CallbackLink {
		return future.handle(callback);
	}
	public inline function listen(callback:Callback<ProgressValue>):CallbackLink {
		return signal.handle(callback);
	}
	public inline function gather():Future<T> {
		return future.gather();
	}
	public inline function eager():Future<T> {
		return future.eager();
	}
}

interface ProgressObject<T> extends FutureObject<T> extends SignalObject<ProgressValue> {}

class ProgressTrigger<T> extends CompositeProgress<T> {
	
	var futureTrigger:FutureTrigger<T>;
	var signalTrigger:SignalTrigger<ProgressValue>;
	
	var value = InProgress(Progress.INIT);
	
	public function new() {
		super(futureTrigger = Future.trigger(), signalTrigger = Signal.trigger());
	}
	
	public function progress(v:Float, total:Option<Float>) {
		switch value {
			case Finished(_):
				// do nothing
			case InProgress(current):
				if (current.value != v || !current.total.eq(total)) {
					var pv = new Pair(v, total);
					value = InProgress(pv);
					signalTrigger.trigger(pv);
				}
		}
	}
	
	public function finish(v:T) {
		switch value {
			case Finished(_):
				// do nothing
			case _:
				// TODO: clear signal handlers
				value = Finished(v);
				futureTrigger.trigger(v);
		}
	}
	
	public inline function asProgress():Progress<T>
		return this;
}

class FutureProgress<T> extends CompositeProgress<T> {
	public function new(future:Future<Progress<T>>) {
		super(
			future.flatMap(function(progress) return progress),
			Signal.generate(function(cb) future.handle(function(progress) progress.listen(cb)))
		);
	}
}

class PromiseProgress<T> extends CompositeProgress<Outcome<T, Error>> {
	public function new(promise:Promise<Progress<T>>) {
		super(
			promise.flatMap(function(o) return switch o {
				case Success(progress): progress.map(Success);
				case Failure(e): Future.sync(Failure(e));
			}),
			Signal.generate(function(cb) promise.handle(function(o) switch o {
				case Success(progress): progress.listen(cb);
				case Failure(e): // do nothing
			}))
		);
	}
}

@:pure
abstract ProgressValue(Pair<Float, Option<Float>>) from Pair<Float, Option<Float>> {
	public var value(get, never):Float;
	public var total(get, never):Option<Float>;

	public inline function new(value, total)
		this = new Pair(value, total);

	/**
	 * Normalize to 0-1 range
	 */
	public inline function normalize():Option<UnitInterval>
		return total.map(function(v) return value / v);

	inline function get_value()
		return this.a;

	inline function get_total()
		return this.b;
}

abstract UnitInterval(Float) from Float to Float {
	public function toPercentageString(dp:Int) {
		var m = Math.pow(10, dp);
		var v = Math.round(this * m * 100) / m;
		var s = Std.string(v);
		return switch s.indexOf('.') {
			case -1: s + '.' + StringTools.lpad('', '0', dp) + '%';
			case i if (s.length - i > dp): s.substr(0, dp + i + 1) + '%';
			case i: StringTools.rpad(s, '0', i + dp + 1) + '%';
		}
	}
}

enum ProgressType<T> {
	InProgress(v:ProgressValue);
	Finished(v:T);
}

class TotalTools {
	public static function eq(a:Option<Float>, b:Option<Float>) {
		return switch [a, b] {
			case [Some(t1), Some(t2)]: t1 == t2;
			case [None, None]: true;
			case _: false;
		}
	}
}

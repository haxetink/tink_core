package tink.core;

abstract Lazy<T>(Void->T) {
	
	inline function new(r) this = r;
	
	@:to public inline function get():T
		return (this)();
			
	@:from static public function ofFunc<T>(f:Void->T) {
		var result = null;
		#if debug var busy = false; #end
		return new Lazy(function () {
			#if debug if (busy) throw new Error('circular lazyness');#end
			if (f != null) {
				#if debug busy = true;#end
				result = f();
				f = null;
				#if debug busy = false;#end
			}
			return result;
		});
	}
	
	public inline function map<A>(f:T->A):Lazy<A> 
		return Lazy.ofFunc(function () return f(get()));
		
	public inline function flatMap<A>(f:T->Lazy<A>):Lazy<A> 
		return Lazy.ofFunc(function () return f(get()).get());
	
	@:from @:noUsing static inline function ofConst<T>(c:T) 
		return new Lazy(function () return c);
}	
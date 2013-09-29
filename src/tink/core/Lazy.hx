package tink.core;

abstract Lazy<T>(Void->T) {
	
	inline function new(r) this = r;
	
	@:to public inline function get():T
		return (this)();
			
	@:from static public function ofFunc<T>(f:Void->T) {
		var result = null;
		return new Lazy(function () {
			if (f != null) {
				var f2 = f;
				f = null;
				result = f2();
			}
			return result;
		});
	}
	
	@:from static inline function ofConst<T>(c:T) 
		return new Lazy(function () return c);
}	
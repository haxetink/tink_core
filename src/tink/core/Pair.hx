package tink.core;

abstract Pair<A, B>(MPair<A, B>) {
	
	public var a(get, never):A;
	public var b(get, never):B;
	
	public inline function new(a:A, b:B) this = new MPair(a, b);
	
	inline function get_a():A return this.a;
	inline function get_b():B return this.b;
	
	@:to inline function toBool() 
		return this != null;
		
	@:op(!a) public function isNil() 
		return this == null;
	
	static public function nil<A, B>():Pair<A, B> 
		return null;
}

#if neko
	private typedef Data<A, B> = neko.NativeArray<Dynamic>;
#elseif (js || java)
	private typedef Data<A, B> = { a: A, b: B } 
		//this is possibly also the best choice for PHP
		//also for reasons yet unknown to me Java will be unable to deal with a class here
#else
	private class Data<A, B> {
		public var a:A;
		public var b:B;
		public function new(a, b) {
			this.a = a;
			this.b = b;
		}
	}
#end

abstract MPair<A, B>(Data<A, B>) {
	public var a(get, set):A;
	public var b(get, set):B;
	
	public inline function new(a:A, b:B) this =
		#if neko
			untyped $array(a, b);
		#elseif (js || java)
			{ a: a, b: b };
		#else
			new Data(a, b);
		#end
	
	inline function get_a():A 
		return #if neko this[0] #else this.a #end;
		
	inline function get_b():B 
		return #if neko this[1] #else this.b #end;
		
	inline function set_a(v:A):A
		return #if neko this[0] #else this.a #end = v;
		
	inline function set_b(v:B):B
		return #if neko this[1] #else this.b #end = v;
}	
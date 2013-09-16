package tink.core;

#if neko
	private typedef Data<A, B> = neko.NativeArray<Dynamic>;
#elseif js
	private typedef Data<A, B> = { a: A, b: B } //this is possibly also the best choice for PHP
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

abstract Pair<A, B>(Data<A, B>) from Data<A, B> {
	
	public var a(get, never):A;
	public var b(get, never):B;
	
	public inline function new(a:A, b:B) this =
		#if neko
			untyped $array(a, b);
		#elseif js
			{ a: a, b: b };
		#else
			new Data(a, b);
		#end
	
	inline function get_a():A 
		return #if neko this[0] #else this.a #end;
	inline function get_b():B 
		return #if neko this[1] #else this.b #end;
	
	@:to inline function toBool() 
		return this != null;
		
	@:op(!a) public function isNil() return this == null;
	
	static public function nil<A, B>():Pair<A, B> return null;
}
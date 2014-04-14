package tink.core;

//TODO: To work around #2881 the abstracts are declared over Null. Remove this when no longer necessary.

abstract Callback<T>(Null<T->Void>) from (T->Void) {
	
	inline function new(f) 
		this = f;
		
	public function invoke(data:T):Void //TODO: consider swallowing null here
		(this)(data);
		
	@:from static inline function fromNiladic<A>(f:Void->Void):Callback<A> 
		return new Callback(function (r) f());
	
	@:from static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> 
		return
			function (v:A) 
				for (callback in callbacks)
					callback.invoke(v);
}

abstract CallbackLink(Null<Void->Void>) {
	
	inline function new(link:Void->Void) 
		this = link;
		
	public inline function dissolve():Void 
		if (this != null) (this)();
		
	@:to function toCallback<A>():Callback<A> 
		return this;
		
	@:from static inline function fromFunction(f:Void->Void) 
		return new CallbackLink(f);
		
	@:from static function fromMany(callbacks:Array<CallbackLink>)
		return fromFunction(function () for (cb in callbacks) cb.dissolve());
}

private class Cell<T> {
	//TODO: the cell (or some super class of it) could just as easily act as callback link
	public var cb:Callback<T>;
	
	function new() {}
	
	public inline function free():Void {
		this.cb = null;
		pool.push(this);
	}
	
	static var pool:Array<Cell<Dynamic>> = [];
	
	static public inline function get<A>():Cell<A> 
		return
			if (pool.length > 0) cast pool.pop();
			else new Cell();
}

abstract CallbackList<T>(Array<Cell<T>>) {
	
	public var length(get, never):Int;
	
	inline public function new():Void
		this = [];
	
	inline function get_length():Int 
		return this.length;	
	
	public function add(cb:Callback<T>):CallbackLink {
		var cell = Cell.get();
		cell.cb = cb;
		this.push(cell);
		return function () {
			if (this.remove(cell))
				cell.free();
			cell = null;
		}
	}
		
	public function invoke(data:T) 
		for (cell in this.copy()) 
			if (cell.cb != null) //This occurs when an earlier cell in this run dissolves the link for a later cell - usually a sign of convoluted code, but who am I to judge
				cell.cb.invoke(data);
			
	public function clear():Void 
		for (cell in this.splice(0, this.length)) 
			cell.free();
}
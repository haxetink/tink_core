package tink.core;

typedef Pos = 
	#if macro
		haxe.macro.Expr.Position;
	#else
		haxe.PosInfos;
	#end

//TODO: there's huge overlap with haxe.macro.Error
class Error {
	public var message(default, null):String;//It might make sense for the message to be lazy
	public var data(default, null):Dynamic;
	public var pos(default, null):Null<Pos>;
	
	public function new(message, ?pos) {
		this.message = message;
		this.pos = pos;
	}
	function printPos()
		return
			#if macro
				Std.string(pos);
			#else
				pos.className+'.'+pos.methodName+':'+pos.lineNumber;
			#end
			
	@:keep public function toString() {
		var ret = 'Error: $message';
		if (pos != null)
			ret += printPos();
		return ret;
	}
	
	@:keep public function throwSelf():Dynamic
		return
			#if macro
				haxe.macro.Context.error(message, if (pos == null) haxe.macro.Context.currentPos() else pos);
			#else
				throw this;
			#end
		
	static public function withData(message, data, ?pos) {
		var ret = new Error(message, pos);
		ret.data = data;
		return ret;
	}
}
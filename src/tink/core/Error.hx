package tink.core;

typedef Pos = 
	#if macro
		haxe.macro.Expr.Position;
	#else
		haxe.PosInfos;
	#end

//TODO: there's huge overlap with haxe.macro.Error
typedef Error = TypedError<Dynamic>;

@:enum abstract ErrorCode(Int) from Int to Int {
	var BadRequest = 400;
	var Unauthorized = 401;
	var PaymentRequired = 402;
	var Forbidden = 403;
	var NotFound = 404;
	var MethodNotAllowed = 405;
	var Gone = 410;
	var NotAcceptable = 406;
	var Timeout = 408;
	var Conflict = 409;
	var OutOfRange = 416;
	var ExpectationFailed = 417;
	var I_am_a_Teapot = 418;
	var AuthenticationTimeout = 419;

	var InternalError = 500;
	var NotImplemented = 501;
	var ServiceUnavailable = 503;
	var InsufficientStorage = 507;
	var BandwidthLimitExceeded = 509;

}

class TypedError<T> {
	public var message(default, null):String;//It might make sense for the message to be lazy
	public var code(default, null):Int;
	public var data(default, null):T;
	public var pos(default, null):Null<Pos>;
	
	public function new(?code:ErrorCode = InternalError, message, ?pos) {
		this.code = code;
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
			ret += " "+printPos();
		return ret;
	}
	
	@:keep public function throwSelf():Dynamic
		return
			#if macro
				#if tink_macro
					tink.macro.Positions.error(pos, message);
				#else
					haxe.macro.Context.error(message, if (pos == null) haxe.macro.Context.currentPos() else pos);
				#end
			#else
				throw this;
			#end
		
	static public function withData(?code:Int = 500, message:String, data:Dynamic, ?pos:Pos) {
		var ret = new Error(code, message, pos);
		ret.data = data;
		return ret;
	}
}

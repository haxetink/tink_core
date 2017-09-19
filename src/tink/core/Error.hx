package tink.core;

import tink.core.Outcome;
import haxe.CallStack;

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
  var UnsupportedMediaType = 415;
  var OutOfRange = 416;
  var ExpectationFailed = 417;
  var I_am_a_Teapot = 418;
  var AuthenticationTimeout = 419;
  var UnprocessableEntity = 422;

  var InternalError = 500;
  var NotImplemented = 501;
  var ServiceUnavailable = 503;
  var InsufficientStorage = 507;
  var BandwidthLimitExceeded = 509;

}

class TypedError<T> {
  public var message(default, null):String;//It might make sense for the message to be lazy
  public var code(default, null):ErrorCode;
  public var data(default, null):T;
  public var pos(default, null):Null<Pos>;
  public var callStack(default, null):Stack;
  public var exceptionStack(default, null):Stack;
  var isTinkError = true;
  
  public function new(?code:ErrorCode = InternalError, message, ?pos) {
    this.code = code;
    this.message = message;
    this.pos = pos;
    this.exceptionStack = #if error_stack try CallStack.exceptionStack() catch(e:Dynamic) #end [];
    this.callStack = #if error_stack try CallStack.callStack() catch(e:Dynamic) #end [];
  }
  function printPos()
    return
      #if macro
        Std.string(pos);
      #else
        pos.className+'.'+pos.methodName+':'+pos.lineNumber;
      #end
      
  @:keep public function toString() {
    var ret = 'Error#$code: $message';
    if (pos != null)
      ret += " @ "+printPos();
    
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
        rethrow(this);
      #end
    
  static public function withData(?code:ErrorCode, message:String, data:Dynamic, ?pos:Pos):Error {
    return typed(code, message, data, pos);
  }
  
  static public function typed<A>(?code:ErrorCode, message:String, data:A, ?pos:Pos):TypedError<A> {
    var ret = new TypedError(code, message, pos);
    ret.data = data;
    return ret;
  }
  
  #if js
  static public inline function ofJsError(e:js.Error, ?pos:Pos):Error 
    return Error.withData(500, e.message, e, pos);
  #end
  
  static public function catchExceptions<A>(f:Void->A, ?report:Dynamic->Error, ?pos:Pos)
    return
      try 
        Success(f())
      catch (e:Dynamic)
        Failure(
          if (e.isTinkError)
            (e:Error)
          else if (report == null)
            Error.withData('Unexpected Error', e, pos)
          else
            report(e)
        );
  
  static public function reporter(?code:ErrorCode, message:String, ?pos:Pos):Dynamic->Error 
    return 
      function (e:Dynamic) return Error.withData(code, message, e, pos);
      
  static public inline function rethrow(any:Dynamic):Dynamic {
    #if neko
      neko.Lib.rethrow(any);
    #elseif php
      php.Lib.rethrow(any);
    #elseif cpp
      cpp.Lib.rethrow(any);
    #else
      throw any;
    #end
    return any;
  }
}

@:forward
abstract Stack(Array<StackItem>) from Array<StackItem> to Array<StackItem> {
  @:to
  public inline function toString():String
    return CallStack.toString(this);
}
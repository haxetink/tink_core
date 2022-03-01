package tink.core;

import tink.core.Outcome;
import haxe.CallStack;

#if js
import js.lib.Error as JsError;
#end

typedef Pos =
  #if macro
    haxe.macro.Expr.Position;
  #elseif tink_core_no_error_pos
    {};
  #else
    haxe.PosInfos;
  #end

//TODO: there's huge overlap with haxe.macro.Error
typedef Error = TypedError<Any>;

@:transitive
enum abstract ErrorCode(Int) from Int to Int {
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
      #elseif tink_core_no_error_pos
        ;
      #else
        pos.className+'.'+pos.methodName+':'+pos.lineNumber;
      #end

  public function toString() {
    var ret = 'Error#$code: $message';
    #if !tink_core_no_error_pos
    if (pos != null)
      ret += " @ "+printPos();
    #end
    return ret;
  }

  public inline function toPromise<X>():Promise<X>
    return Promise.reject(cast this);

  public function throwSelf():Dynamic
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
  static public inline function ofJsError(e:JsError, ?pos:Pos):Error
    return Error.withData(500, e.message, e, pos);

  public function toJsError():JsError
    return
      if (js.Syntax.instanceof(data, JsError)) cast data;
      else new TinkError(this);
  #end

  @:noUsing static public function asError(v:Dynamic):Null<Error> {
    return
      #if js
        if (v != null && (cast v:Error).isTinkError) cast v;
        else null;
      #else
        Std.downcast(v, Error);
      #end
  }
  static public function catchExceptions<A>(f:()->A, ?report:Dynamic->Error, ?pos:Pos)
    return
      try
        Success(f())
      catch (ex:Dynamic) {
        var e = asError(ex); // this tempvar sidesteps https://github.com/HaxeFoundation/haxe/issues/9617
        Failure(
          switch e {
            case null:
              if (report == null)
                Error.withData('Unexpected Error', ex, pos)
              else
                report(ex);
            case e: e;
          }
        );
      }

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

  static public function tryFinally<T>(f:()->T, cleanup:()->Void):T {
    #if js
      #if haxe4
      js.Syntax.code('try { return f(); } finally { cleanup(); }');
      #else
      untyped __js__('try { return f(); } finally { cleanup(); }');
      #end
      return null;
    #else
    try {
      var ret = f();
      cleanup();
      return ret;
    }
    catch (e:Dynamic) {
      cleanup();
      return rethrow(e);
    }
    #end
  }
}

@:forward
abstract Stack(Array<StackItem>) from Array<StackItem> to Array<StackItem> {
  @:to
  public inline function toString():String
    return
      #if error_stack
        CallStack.toString(this);
      #else
        'Error stack not available. Compile with -D error_stack.';
      #end
}

#if js
private class TinkError<T> extends JsError {
  public final data:TypedError<T>;
  public function new(e:TypedError<T>) {
    super();
    this.message = e.message;
    this.data = e;
  }
}
#end
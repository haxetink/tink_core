# Error

The `Error` class is meant as a standard class for errors. It is defined like so:

```haxe
typedef Error = TypedError<Dynamic>;

class TypedError<T> {
  
  var message(default, null):String;
  var code(default, null):ErrorCode;
  var data(default, null):T;
  var pos(default, null):Null<Pos>;
  
  var callStack(default, null):Stack;
  var exceptionStack(default, null):Stack;
  
  function new(?code:ErrorCode, message, ?pos:Pos):Void;
  
  static function withData(?code:ErrorCode, message:String, data:Dynamic, ?pos:Pos):Error;
  static function typed<A>(?code:ErrorCode, message:String, data:A, ?pos:Pos):TypedError<A>;
  static function catchExceptions<A>(f:Void->A, ?report:Dynamic->Error, ?pos:Pos):Outcome<A, Error>;
}
```

Most of the time you will just be dealing with `Error`, where `data` is simply `Dynamic`. In a very select cases you may wish to created typed errors where the type of the error's data is well defined.

The `Pos` type is just a typedef that will be `haxe.macro.Expr.Position` in the macro context and `haxe.PosInfos` otherwise.

There are a couple of interesting things to point out:

- The `throwSelf` method will be called if you do `sure` on a `Failure` that is an `Error`. This is useful to not just have willy-nilly stack traces but instead have a chance to die gracefully.
- In macro context, the `throwSelf` method will cause a compiler error at `pos` (defaults to `haxe.macro.Context.currentPos()` at the time of creation).
- Outside macro context, `Pos` is `PosInfos` which happens to be a magical type, that when left to default, will contain the call site position. So when you pass around an `Outcome` and at some point call `sure` and it happens to be a `Failure(someError)`, the stack trace will contain information on where the `Error` was actually constructed. Future versions may also capture the stack at the point of the error's creation.
- If you compile with `-D error_stack` then the two stack fields are populated with contextual information (otherwise they are just empty arrays).
- By default errors are constructed without data. Use `withData` or `typed` to construct them with `Dynamic` or specific data.
- the `catchExceptions` function is a nice way to call functions that might throw like so: `sys.io.File.getContent.bind('path/to/file').catchExceptions()`

## ErrorCode

The `ErrorCode` type is mentioned a lot in the `TypedError` class above. Here is how it is actually defined:

```haxe
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
```

You may notice that these numerical codes are a subset of HTTP status codes. There was no real point in inventing yet another set of error codes so instead I turned to one of the most ubiquitous standards out there. It actually covers quite a few cases, e.g. `Unauthorized` (you need to log in) vs. `Forbidden` (you are logged in but simply not allowed to do what you're trying). Of course `I_am_a_Teapot` absolutely had to be included.

If you wish to propose any more error codes, please do so.

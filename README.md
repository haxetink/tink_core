# Tinkerbell Core Library

[![Build Status](https://travis-ci.org/haxetink/tink_core.svg)](https://travis-ci.org/haxetink/tink_core)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg?maxAge=2592000)](https://gitter.im/haxetink/public)

The `tink_core` lib contains a set of lightweight tools for robust programming.

All modules are situated in `tink.core.*`. Some contain more than a single type. Generally, it is advisable to import the modules of this package through `using` rather than `import`. 

In addition, you can import all modules at once with `using tink.CoreApi;`.

### Overview

<!-- START INDEX -->
- [Named](#named)
- [Any](#any)
- [Pair](#pair)
	- [Nullness](#nullness)
	- [MPair](#mpair)
- [Lazy](#lazy)
- [Outcome](#outcome)
- [Error](#error)
	- [ErrorCode](#errorcode)
- [Noise](#noise)
- [Either](#either)
- [Ref](#ref)
- [Callback](#callback)
	- [CallbackLink](#callbacklink)
	- [CallbackList](#callbacklist)
	- [Registering callbacks](#registering-callbacks)
- [Future](#future)
	- [Why use futures?](#why-use-futures)
	- [Transformation](#transformation)
	- [Composition](#composition)
	- [Gathering](#gathering)
	- [Rolling your own](#rolling-your-own)
	- [Operators](#operators)
	- [Surprise](#surprise)
	- [FutureTrigger](#futuretrigger)
- [Promise](#promise)
	- [Recover](#recover)
	- [Next](#next)
	- [Promise vs Surprise](#promise-vs-surprise)
- [Signal](#signal)
	- [Why use signals?](#why-use-signals)
	- [Wrapping 3rd party APIs](#wrapping-3rd-party-apis)
	- [Rolling your own](#rolling-your-own)
	- [No way to dispatch from outside](#no-way-to-dispatch-from-outside)
	- [Composing](#composing)
	- [Gathering](#gathering)
	- [SignalTrigger](#signaltrigger)
- [Annex](#annex)

<!-- END INDEX -->

Despite the rather long documentation here, `tink_core` does not exceed 1KLOC. And while was primarily drafted as the basis for the rest of tink, it can be used in isolation or for other libs to build on.

# Named

This is a very basic helper type, defined over its generalization:

```haxe
typedef Named<V> = NamedWith<String, V>;

class NamedWith<N, V> {
  
  public var name(default, null):N;
  public var value(default, null):V;
  
  public function new(name, value) {
    this.name = name;
    this.value = value;
  }
  
}
```

This just formalizes a notion of something being named.

# Any

The `Any` type (which has been included in the standard library in Haxe 3.4) is an alternative to Haxe's `Dynamic` defined like so:

```haxe
abstract Any from Dynamic {
  @:to private inline function __promote<A>():A;
}
```

It is a type that is compatible with any other, in both ways. Yet you can do almost nothing with it, except promote it to other types. This is useful, because `Dynamic` itself behaves in unintuitive ways, because of the overloaded role it plays in the Haxe type system.

Behaviors of `Dynamic` that `Any` does not exhibit:

1. `Dynamic` gives you the raw native runtime behavior - example with haxe/js:

  ```haxe
  var s = '';
  var d:Dynamic = s;
  
  trace(Std.string(s.charCodeAt(1)));//null
  trace(Std.string(d.charCodeAt(1)));//NaN - native runtime behavior is different!
  ```

2. `Dynamic` is erased during inference. Example:

  ```haxe
  var x = Reflect.field({ foo: [4] }, 'foo');//x is Unknown<?>
  if (x.length == 1)//x is now {+ length : Int }
    trace(x[0]);//Compiler error: Array access is not allowed on {+ length : Int }
  ```
  
  That error message is a bit confusing to say the least.
  
3. `Dynamic` is weirdly related to `Dynamic<T>`. I won't go into details, because truth be told I myself am sometimes startled by certain nuances.

Compared to `Dynamic`, the `Any` type has a very specific meaning: it means the value could be of any type - that's it. The idea proposed here is to use `Dynamic` only to express the notion that a value is going to be accessed with native semantics (which is no doubt useful at times). If you want to access values in an untyped manner (which most of the time you should try to avoid), use the `untyped` keyword.

Notice how in the first example, the compiler will force you to choose a type.

```haxe
var s = '';
var a:Any = s;

trace(Std.string(s.charCodeAt(1)));//null
trace(Std.string(a.charCodeAt(1)));//does not compile because "Any has no field charCodeAt"
trace(Std.string((a:String).charCodeAt(1)));//null - of course
```

Also, if `Reflect.field` were to return `Any`, then you'd just have to type `x` to `Array<Dynamic>` to do anything with it.

As for an alternative to `Dynamic<T>`, `Any` does not offer one. But `haxe.DynamicAccess<T>` does!

So to be clear:

- `Any` for values of a type not know at compile time`
- `haxe.DynamicAccess` to access an object as a map
- `untyped` to write untyped code
- `Dynamic` to access the native runtime behavior

This should go toward clarifying what exactly is going on in a specific piece of code.

# Pair

The `Pair` represents an [ordered pair](http://en.wikipedia.org/wiki/Ordered_pair):

```haxe
abstract Pair<A, B> {
  function new(a:A, b:B);
  var a(get, never):A;
  var b(get, never):B;
}
```

The representation is immutable and optimized for runtime performance. It can be used as a basic means of composition, although you should beware not to abuse it.

- Good `function getCredentials():Pair<User, Password>`
- Bad `function getAddress():Pair<Pair<String, Int>, String>`

In the latter example, there are two ways to actually convey meaning:

- with pairs: `function getAddress():Pair<Pair<Host, Port>, Path>`
- vanilla haxe: `function getAddress():{ host:String, port:Int, path:String }`

Advantages of the pair approach:

1. Performance is good on all platforms.
2. The returned value is immutable without having to declare all fields as readonly - this assumes you *want* immutability

### Nullness

As any complex data, pairs are nullable. For `Pair` we consider `null` an "empty pair", which is not sensible from a mathematical point of view, but Lisp managed to build a whole ecosystem on this convention, so it seems a fair bet.

## MPair

The `MPair` is the mutable counterpart to `Pair`. Formerly optimized for speed, it has been demoted to a plain class, which should be fast enough 99% of the time.

# Lazy

The `Lazy` type is a primitive for [lazy evaluation](http://en.wikipedia.org/wiki/Lazy_evaluation):

```haxe
abstract Lazy<T> {  
  @:to function get():T;  
  function map<R>(f:T->R):Lazy<R>;
  function flatMap<R>(f:T->Lazy<R>):Lazy<R>;
  @:from static function ofFunc<T>(f:Void->T):Lazy<T>;
  @:from static private function ofConst<T>(c:T):Lazy<T>;
}
```

Notice it defines `map` and `flatMap` functions that allows you to transform one lazy value to another. It is important to understand that the final value is not computed until you call `get` as shown in [this example](http://try.haxe.org/#67EA8):

```haxe
using tink.CoreApi;

class Test {
  static function generate():Int {
    trace("generating");
    return Std.random(500);
  }
    
  static function lazyInt():Lazy<Int>
    return generate;//Void->Int is automatically converted to Lazy<Int>
    
  static function lazyToString(o:Dynamic):Lazy<String> {
    trace("calling lazyToString");
    return Std.string.bind(o);//And Void->String becomes Lazy<String>
  }
    
  static function main() {
    var l1 = lazyInt(),
        l2 = lazyInt();
      
    trace("before any access");
    trace(l1.get());//traces "generating" and the random value
    trace(l1.get());//traces the same value
      
    var l3 = l2.flatMap(lazyToString);
    trace("before printing l3");
    trace(l3.get());
    /**
     * The above traces:
     * 1. "generating" - because `l2` actually gets generated
     * 2. "calling lazyTotring" - because it was not needed before
     * 3. the resulting string representation of the second random int
     */
  }
}
```

# Outcome

The `Outcome` type is quite similar to [`haxe.ds.Option`](http://haxe.org/api/haxe/ds/option), but is different in that it is tailored specifically to represent the result of an operation that either fails or succeeds.

```haxe
enum Outcome<Data, Failure> {
  Success(data:Data);
  Failure(failure:Failure);
}
```

This is a way of doing error reporting without resorting to exceptions or [sentinel values](http://en.wikipedia.org/wiki/Sentinel_value). 

Because switching on `Outcome` all the time can become tedious, the module where `Outcome` resides also defines `OutcomeTools`, a set of helper functions best leveraged by simply [`using tink.core.Outcome`](http://haxe.org/manual/using).

This will give you a number of helper methods:

* `function sure<D,F>(outcome:Outcome<D,F>):D`  
Will return the result in case of success or throw an exception otherwise. Therefore the exception is raised not when an operation fails, but when other code doesn't handle failure at all.

* `function toOption<D,F>(outcome:Outcome<D,F>):Option<D>`  
Will transform an `Outcome` into an `Option`. Information on failure is thereby lost.
* `function toOutcome<D>(option:Option<D>, ?pos:haxe.PosInfos):Outcome<D, String>`  
Converts an `Option` into an `Outcome`, where `Some(value)` is considered success and `None` is considered failure, with an error message.
* `function orUse<D,F>(outcome:Outcome<D,F>, fallback:D):D`  
Attempts to get data from a successful `Outcome` or returns a `fallback` otherwise.
* `function orTry<D,F>(outcome:Outcome<D,F>, fallback:Outcome<D,F>):Outcome<D,F>`  
If the `outcome` failed, uses `fallback` instead. Note that this can still be a failure.
* `function equals<D,F>(outcome:Outcome<D,F>, to:D):Bool`  
Tells whether an `Outcome` is successful and the value is equal to `to`.
* `function map<A,B,F>(outcome:Outcome<A,F>, transform:A->B):Outcome<B, F>`  
Returns a new `Outcome`, where the success (if any) is transformed with the given transformer.
* `function isSuccess<D,F>(outcome:Outcome<D,F>):Bool`  
Tells whether an outcome was successful.

Here is some example code of what neko file access might look like:

```haxe
enum FileAccessError {
  NoSuchFile(path:String);
  CannotOpen(path:String, reason:Dynamic);
}

class MyFS {
  static public function getContent(path:String) 
    return
      if (sys.FileSystem.exists(path)) 
        try {
          Success(sys.io.File.getContent(path));
        }
        catch (e:Dynamic) {
          Failure(CannotOpen(path, e));
        }
      else
        Failure(NoSuchFile(path));
}

class Main {
  static function main() {

    //First, let's process outcomes by hand it by hand:

      switch MyFS.getContent('path/to/file') {
        case Success(s): 
          trace('file content: ' + s);
        case Failure(f):
          switch f {
            case NoSuchFile(path): 
              trace('file not found: $path');
            case CannotOpen(path, reason): 
              trace('failed to open file $path because $reason');
          }
      }
    
    //Now, using OutcomeTools:

      trace('other file content: ' + MyFile.getContent('path/to/other_file').sure());
      //will throw an exception if the file content can not be read
    
      var equal = MyFile.getContent('path/to/file').map(haxe.Md5.encode).equals(otherMd5Sig);
      //will be true, if the file could be openend and its content's Md5 signature is equal to `otherMd5Sig`
  }
}  
```

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

# Noise

Because in Haxe 3 `Void` can no longer have values, i.e. values of a type that always holds nothing, `tink_core` introduces `Noise`.

```haxe
enum Noise { Noise; }
```

Technically, `null` is also a valid value for `Noise`. In any case, there is no good reason to inspect values of type noise, only to create them and ignore them.

An example where using `Noise` makes sense is when you have an operation that succeeds without any result to speak of:

```haxe
function writeToFile(content:String):Outcome<Noise, IoError>;
```

# Either

Represents a value that can have either of two types:

```haxe
enum Either<A,B> {
  Left(a:A);
  Right(b:B);
}
```

For example the following can represent a physical type in Haxe: 

```haxe
typedef PhysicalType<T> = Either<Class<T>, Enum<T>>`

function name(t:PhysicalType<Dynamic>) 
  return switch t {
    case Left(c): Type.getClassName(c);
    case Right(e): Type.getEnumName(e);
  }
```

Historically it existed as such in `tink_core` but only remains as a typedef [to the standard library's version of it](http://api.haxe.org/haxe/ds/Either.html).

# Ref

At times you wish to share the same reference (and therefore changes to it) among different places. Since Haxe doesn't support old fashioned pointer arithmetics, we need to find other ways.

The `Ref` type does just that, but in an abstract:

```haxe
abstract Ref<T> {
  var value(get, set):T;
  function toString():String;
  @:from static function to(value:T):Ref<T>;
  @:to function toPlain():T;
}
```

It is worth noting that `Ref` defines implicit conversion in both ways. The following code will thus compile:

```haxe
var r:Ref<Int> = 4;//here `4` gets automatically wrapped into a reference
var i:Int = r;//here `r` gets automatically unwrapped
```

The current implementation is built over `haxe.ds.Vector` and should thus perform quite decently across most platforms.

Note that assigning a value to a reference will update the reference in place but rather wrap the value in a new reference.

```haxe
var a:Ref<Int> = 4;
var b = a;
b.value = 3;
trace(a.value);//3
b = 2;
trace(a.value);//still 3, because b is now a different reference
```

# Callback

To denote callbacks, `tink_core` introduces a special type:

```haxe
abstract Callback<T> from T->Void {
  function invoke(data:T):Void;
  @:from static function fromNiladic<A>(f:Void->Void):Callback<A> 
  @:from static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> 
}
```

The obvious question to ask here is why to complicate a simple concept as callbacks when we already have first class functions.

* It brings more clarity to code. Function types use structural subtyping, i.e. the signature alone defines the type. Type matches can thus be unintentional. Also calling something a callback when that's what it really is, carries more meaning.
* The use of abstracts allows for implicit conversions. If you want to subscribe to an event but don't really care for the data, you don't have to define an argument you're not using. You can simply do either of both:
 * `myButton.onClick(function () trace('clicked'));`
 * `myButton.onClick(function (e) trace('clicked at (${e.x}, ${e.y})'));`
* Instead of specifically relying on a function type, we have a separate abstraction, which at some point can be used to leverage platform knowledge to provide for faster code that doesn't have suffer from the performance penalties anonymous function have on most platforms

Beyond that, one might ask what to do if you don't have any data to pass to the callback, or more than a single value. In that case, you could use these respectively:

```haxe
Callback<Noise>
Callback<Pair<A, B>>
Callback<{ a: A, b: B, c: C }>
```

This approach has two advantages:

* For one, it greatly simplifies things. Implementations of signals only ever consume one type of callbacks, so you don't need signals for 0, 1, 2 and possibly 3 arguments.
* Types written against this single callback type are easier to work with in a consistent matter.
* In the last case you can add additional information in a new field without breaking code

## CallbackLink

When you register a callback to a caller, you often want to be able to undo this registration. Classically, the caller provides for this functionality by exposing two methods, one for registering and one for unregistering.

As opposed to that, tink adheres to a different approach, where the registration returns a "callback link", i.e. a value representing the link between the caller and the callback. It looks as follows:

```haxe
abstract CallbackLink {
  function dissolve():Void;
  @:to function toCallback<A>():Callback<A>;
  @:from static function fromFunction(f:Void->Void):CallbackLink;
}
```

Calling `dissolve` will dissolve the link, as suggested by the name. Ain't no rocket science ;)

The link itself can be promoted to become a callback, so that you can in fact register it as a handler elsewhere:

```haxe
button.onPress(function () {
  var stop = button.onMouseMove(function () trace('move!'));
  button.onRelease(stop);
});
```

## CallbackList

While the `Callback` and `CallbackLink` are pretty nice in theory, on their own, they have no application. For that reasons `tink_core` defines a basic infrastructure to provide callback registration and link dissolving:

```haxe
abstract CallbackList<T> {
  var length(get, never):Int;
  function new():Void;
  function add(cb:Callback<T>):CallbackLink;
  function invoke(data:T):Void; 
  function clear():Void;
}
```

By calling `add` you can thus register a callback and will obtain a link that allows undoig the registration. You can `invoke` all callbacks in the list with some data, or `clear` the list if you wish to. 

### Registering callbacks

Unlike with similar mechanisms, you can `add` the same callback multiple times and one `invoke` will then cause the callback to be called multiple times. You will however get distinct callback links that allow you to separately undo the registrations.
While this behavior might strike you as unfamiliar, it does have advantages:

- Adding callbacks becomes very cheap (since you don't have to check whether they are already existent)
- Avoid trouble with all sorts of inconsistencies regarding function equality on different Haxe targets
- Have a clear and simple behavior, that is thus highly predictable - i.e. callbacks are simply executed in the order they are registered in. If you register a new callback, you can expect *all* previously registered callbacks to execute *before* it. The same cannot be said in case of the more common approach, if the callback was registered already once, so execution order tends to be undefined.

In essence the `CallbackList` can be seen as a basic building block for notification mechanisms.

# Future

As the name would suggest, futures express the idea that something is going to happen in the future. Or much rather: a future represents the result of a potentially asynchronous operation, that will become available at some point in time. It allows you to register a `Callback` to `handle` the operation's result once it is available.

```haxe
abstract Future<T> {
  function handle(callback:Callback<T>):CallbackLink;
  
  function map<A>(f:T->A, ?gather = true):Future<A>;
  function flatMap<A>(f:T->Future<A>, ?gather = true):Future<A>; 
  static function flatten<A>(f:Future<Future<A>>):Future<A>;
  
  function first(other:Future<T>):Future<T>;
  function merge<A, R>(other:Future<A>, how:T->A->R):Future<R>;
  @:from static function fromMany<A>(a:Array<Future<A>>):Future<Array<A>>;
  
  static function sync<A>(v:A):Future<A>;
  static function lazy<A>(f:Void->A):Future<A>;
  static function async<A>(f:(A->Void)->Void, ?lazy = false):Future<A>;  
  static function trigger<A>():FutureTrigger<A>;//FutureTrigger is documented below
  static function ofMany<A>(futures:Array<Future<A>>, ?gather = true):Future<Array<A>>;
  function new(f:Callback<T>->CallbackLink):Void;  
}
```

It is important to note that a future - despite its name - need not necessarily represent an operation whose result still lies in the future. Once the underlying operation has completed, the future will retain the result and if you register a callback, it will be called back *immediately*. There are claims that such behavior can cause problems. The problem is however caused by making assumptions about *when* the callback will be invoked. Do not make any such assumptions and you will be on the safe side. You can see the `Future` as a micro-framework, that inverts control.

### Why use futures?

We can already deal with asynchrony by means of plain old callbacks. Introducing futures has two advantages:

- Futures are values and that allows for composition
- Futures are very generic. They need not represent an asynchronous operation, they might just as well represent a lazy one or they may even hold a value that has been available from the very start. Writing a piece of code against futures allows you to work with and even intermix these three types of evaluation strategies.

Say you have these functions, that are built on one another:

```haxe
function loadFromURL(url:String, callback:String->Void):Void { 
  /* load data somehow */ 
}

function loadFromParameters(params: { host: String, port: Int, url:String, params:Map<String> }, callback:String->Void):Void {
  var url = buildURL(params);//wherever this comes from
  loadFromURL(url, callback);
}

function loadAll(params:Array<{ host:String, port:Int, url:String, params:Map<String> }, callback:Array<String>->Void):Void {
  var results = [],
    count = 0;
  for (i in 0...params.length) {
    count++;
    loadFromParameters(params[i], function (data) {
      results[i] = data;
      if (--count == 0) callback(results);
    });
  }
}
```

Now let's see that code with futures:

```haxe
function loadFromURL(url:String):Future<String> { 
  /* load the data somehow */ 
}

function loadFromParameters(params: { host: String, port: Int, url:String, params:Map<String> }):Future<String> {
  var url = buildURL(params);//wherever this comes from
  return loadFromURL(url);
}

function loadAll(params:Array<{ host:String, port:Int, url:String, params:Map<String> }):Future<Array<String>> {
  return [for (p in params)
    loadFromParameters(params)
  ];
}
```

A couple of observations:

- Rather than passing callbacks from function to function, we return futures. We do not know, that somebody is going to want to be called back and we don't really care. We simply return a future and client code can decide whether or not it wants to handle the result of an operation.
- Futures can be composed, because they are values. If you compare the implementations of `loadAll` the advantage of that should become evident. In the future based implementation, we use an [array comprehension](http://haxe.org/manual/comprehension) to simply comprise the individual futures resulting from `loadFromParameters` to an array.  
Note that the value that we constructed is `Array<Future<String>>` whereas what we are returning is a single `Future<Array<String>>`. They are not at all the same but converting the former to the latter is indeed possible and happens automagically here, because `Future` defines an implicit conversion rule (see `fromMany`) to do just that.

So rather than passing callbacks along with all calls, we simply return futures and the resulting code is much closer to how we would do this with synchronous APIs.

### Transformation

In the example above we can see some composition of futures at work. What's equally interesting is transformation. The basic tool is `map` which works very much like it does for `Array`. For a `Array`, it constructs a new `Array` by applying a function to all elements. For a `Future` it does pretty much the same thing: it constructs a new `Future` by applying a function to the result.

Say we want to load JSON instead of raw data in the example above. To expand on the example above, this is how we would accomplish it:

```haxe
function loadJson(url:String):Future<Dynamic> 
  return loadFromUrl(url).map(haxe.Json.parse);
```

Now let's say that we know for a fact, that all these JSONs contain arrays of strings and we actually just want the first entry, then we would do this:

```haxe
function loadJson(url:String):Future<String>
  return loadFromUrl(url).map(haxe.Json.parse).map(function (a) return a[0]);
```

Or let's try something else. Loading information from wikipedia.

```haxe
function loadWikiDescription(article:String):Future<Null<String>> 
  return 
    loadFromUrl('http://en.wikipedia.org/wiki/$article').map(function (html:String) 
      return
        if (html.indexOf('Wikipedia does not have an article with this exact name') != -1) null;
        else html.split('<p>').pop().split('</p>').shift();
    );
```

So the above will create a future that returns null if there's no article, or the contents of the first paragraph (please do not parse HTML like that in production code).

Now let's assume that we want to load an article that is specified in a config, then we would try this:

```haxe
loadJson('config.json').map(
  function (config: { article:String }):Future<Null<String>>
    return loadWikiDescription(config.article)
);
```

There is only one problem. The transformation function does not return a plain value, but rather a future. Since map with a function of type `T->A` transforms a `Future<T>` to a `Future<A>`, map with a function of type `String->Future<Null<String>>`.
so the resulting future will in fact be of type `Future<Future<Null<String>>>` whereas we would really rather want `Future<Null<String>>`. One could call this a "nested" future and we want to `flatten` it:

```haxe
Future.flatten(loadJson('config.json').map(
  function (config: { article:String }) 
    return loadWikiDescription(config.article)
));
```

Now because this is a lot to write for a rather common situation, we have `flatMap` which basically just does a `map` and `flatten`:

```haxe
loadJson('config.json').flatMap(
  function (config: { article:String }) 
    return loadWikiDescription(config.article)
);
```

And the result is a plain future.

### Composition

To compose futures, you have three basic options:

1. `first` - take two futures of the same type and construct one that yields the result of whichever future finishes first. Example: `loadFrom(source1).first(loadFrom(source2))`
2. `fromMany` - take an array of futures and transform it to a single future of an array of the results. In fact you've seen this in action in "Why use futures?"
3. `merge` - take two futures and merge them together by means of a function. Example: `loadFrom(source1).merge(loadFrom(source2), function (r1, r2) return r1 + r2)`

Now you may want to use `first` on futures of different types. Here's how that would work:

```haxe
var x:Future<X> = ...; 
var y:Future<Y> = ...; 

$type(x.map(Either.Left).first(y.map(Either.Right)));//Future<Either<X, Y>>
``` 

### Gathering

The keen observer may have noticed the optional `gather` argument for `map` and `flatMap`. This a compromise that leaks an implementation detail to give you the possibility to reduce overhead. When in doubt, leave it untouched.

Let's examine a naive implementation of `map`:

```haxe
function map<In, Out>(future:Future<In>, transform:In->Out):Future<Out>
  return new Future(
    function (callback:Callback<Out>):CallbackLink
      return f.handle(
        function (data:In) callback.invoke(transform(data))
      )
  )
```

What this does is to create a future that deals with a `callback` by registering a new handle to the original `future` that will first `transform` the `data` and then `invoke` the original `callback`. This pretty much does what we want, with one problem: The transformation is executed for *every* `callback`. 

Example:

```haxe
var f = Future.sync('foo'),
  array = [];

var mapped = map(f, array.push);
mapped.handle(function (x) trace(x));//1
trace(array);//[foo]
mapped.handle(function (x) trace(x));//2
trace(array);//[foo, foo]
```

Ideally the transformation should be a [pure function](http://en.wikipedia.org/wiki/Pure_function), so you will not actually have any direct side effects. But even then it would be executed multiple times which may cause performance issues if the transformation is costly.

To avoid this, we would need a mechanism that internally stores the transformed result once it becomes available and dispatches that onto all callbacks. That's what "gathering" does. 

Gathering is used by default, because by default it's the sensible thing to do. However, you may build chains such as `f.map(t1).map(t2).flatMap(t3).map(t4)`. The intermediary futures will only ever have one handler. In that case the overhead introduced by gathering is not needed.

If the transformations are pretty straight forward but frequent and you're dealing with synchronous code, then turning off gathering can lead to noticable performance differences.

### Rolling your own

While you can create Futures with the constructor, the suggested method is to use one of the static constructors.

In the example above, we've seen a `loadFromUrl` function. Here's a way to implement it on top of `haxe.Http` on async platforms with `Future.async`:

```haxe
//First, let's have a plain old callback based function
function loadAsync(url:String, callback:String->Void) {
  var h = new haxe.Http(url);
  h.onDone = callback;
  h.send();
}
//and now, pixie dust!!!!
function loadFromUrl(url:String) 
  return Future.async(loadAsync.bind(url));

```

Or if we wanted to achieve the same in one step:

```haxe
function loadFromUrl(url:String)
  return Future.async(function (handler:String->Void) {
    var h = new haxe.Http(url);
    h.onDone = handler;
    h.send();
  });
```

A fair question to ask would be, how to deal with errors. Quite simply, we will use our old friend the `Outcome`:

```haxe
function loadFromUrl(url:String):Future<Outcome<String, String>>
  return Future.async(function (handler:Outcome<String, String>->Void) {
    var h = new haxe.Http(url);
    h.onDone = function (data:String) handler(Success(data));
    h.onError = function (error:String) handler(Failure(error));
    h.send();
  });
```

Now suppose we wanted the code to run on PHP that's synchronous. For one, the implementation above would already happen to work. But typically most APIs that you would want to deal with are purely synchronous and you'd have to deal with that. This is how:

```haxe
function loadFromUrl(url:String)
  return Future.sync(haxe.Http.requestUrl(url));
  
function loadFromUrl(url:String)
  return Future.lazy(haxe.Http.requestUrl.bind(url));
```

The first version just gets the data synchronously and then "lifts" it to become a `Future`. The second version constructs a lazy future, i.e. the operation is executed when you register the first callback. Example:

```haxe
var load = loadFromUrl('http://example.com/');//no requests have been made yet
load.handle(function (data) {});//now the request is made
load.handle(function (data) {});//the data is already available, so no request is made
```

Lazyness of course is something that you may want in async scenarios. For that reason `Future.async` has a `lazy` parameter that you can set to `true`.

Please note that lazyness is not always preferable. In the context of HTTP for example, it might make sense to have `GET` requests be lazy, because there's no point in loading the data if you're not going to `handle` it. As opposed to that, `POST` requests should not be lazy. You want the request to be sent of to the server, whether or not you're going to `handle` the response.

For any more complex scenarios, you can use [`FutureTrigger`](#futuretrigger) to complete the future by hand.

### Operators

Because `Future` is an abstract, we can do some neat tricks with operator overloading. Before looking at those, you might want to peek at the next section to see what a `Surprise` is.

1. `||`
 1. If futures are of the same type, will use `first`
 2. If futures are of different type, will collapse the type by means of `Either` and then use `first` (as shown at the end of the "Composition" section)
2. `&&` - will combine a `Future<A>` and `Future<B>` to a `Future<Pair<A, B>>`.
3. `>>`
 1. Will `flatMap` a `Surprise<A, F>` to a `Surprise<B, F>` with a `A->Surprise<B, F>`
 2. Will `flatMap` a `Surprise<A, F>` to a `Surprise<B, F>` with a `A->Future<B>`
 3. Will `map` a `Surprise<A, F>` to a `Surprise<B, F>` with a `A->Outcome<B, F>`
 4. Will `map` a `Surprise<A, F>` to a `Surprise<B, F>` with a `A->B`
 5. Will `flatMap` a `Future<A>` to a `Future<B>` with a `A->Future<B>`
 6. Will `map` a `Future<A>` to a `Future<B>` with a `A->B`

Evidently, `>>` is quite supercharged. Let's examine an example from above once more to see why:

```haxe
loadJson('config.json').flatMap(
  function (config: { article:String }) 
    return loadWikiDescription(config.article)
);
```

We can now write it as this:

```haxe
loadJson('config.json') >> 
  function (config: { article:String }) 
    return loadWikiDescription(config.article);
```

Apart from shaving off a few characters, we achieved something else entirely. This piece of code is *significantly* more flexible. If `loadJson` starts returning a `Surprise` because the maintainer added error handling, our code remains unaffected. The overloaded `>>` operator will lift the transformation to the right context. The same applies for `loadWikiDescription`. With this syntax it no longer matters whether it returns a `Surprise` or just a `Future` or even just a plain value. 

Handle the future like a boss ;)

## Surprise

For all those who love surprises and for all those who hate them, `tink_core` provides a neat way of expressing them. Simply put, a surprise is nothing but a future outcome. Literally:

```haxe
typedef Surprise<D, F> = Future<Outcome<D, F>>;
```

This type thus represents an operation that will finish at some point in time and can end in failure. Perfect for representing asynchronous I/O and such. We've seen it in the examples above, we just didn't call it that way.

## FutureTrigger

In an above section we've seen ways to construct futures on top of other APIs. However, you may need to build your own future yourself from scratch. The simplest way to do this is by using a helper class:

```haxe
class FutureTrigger<T> {
  function new();
  function asFuture():Future<T>;
  function trigger(result:T):Bool;
}
```

Typically you would construct a trigger with `Future.trigger()` instead of `new FutureTrigger()`. One advantage is that the former works with `import tink.core.*;` and the other one requires you to `import tink.core.Future;` explicitly.

Here is how you would use such a trigger (as an alternative to the example above):

```haxe
class Http {
  static public function requestURL(url:String):Surprise<String, String> {
    var req = new haxe.Http(url),
      f = Future.trigger();
    req.onData = function (data) f.trigger(Success(data));
    req.onError = function (error) f.trigger(Failure(error));
    req.request();
    return f.asFuture();
  }
}
```

Looks pretty neat already. And it forces client code to consider failure.

# Promise

Promises are a relatively late addition to `tink_core` and are the result of the realization that most of the time one will just use `Error` as the error type of a `Surprise`. Indeed `typedef Promise<T> = Surprise<T, Error>` is relatively close to what promises are, but there's a few more comfort features added to the mix:

```haxe
abstract Promise<T> from Surprise<T, Error> to Surprise<T, Error> {
  
  function map<R>(f:Outcome<T, Error>->R):Future<R>;
  function flatMap<R>(f:Outcome<T, Error>->Future<R>):Future<R>;
  function handle(cb:Callback<Outcome<T, Error>>):CallbackLink;

  function next<R>(f:Next<T, R>):Promise<R>; 
  function recover(f:Recover<T>):Future<T>;
  
  @:to function noise():Promise<Noise>;

  @:from static private function ofSpecific<T, E>(s:Surprise<T, TypedError<E>>):Promise<T>;    
  @:from static private function ofFuture<T>(f:Future<T>):Promise<T>;    
  @:from static private function ofOutcome<T>(o:Outcome<T, Error>):Promise<T>;    
  @:from static private function ofError<T>(e:Error):Promise<T>;
  @:from static private function ofData<T>(d:T):Promise<T>;
    
  @:noUsing static function lift<T>(p:Promise<T>)
}
```

So you see that `map`, `flatMap` and `handle` allow you to deal with the promise as though it were an ordinary `Surprise`.

What's added is for one the ability to promote any `Future`, `Outcome`, `Surprise`, `Error` or plain value to a `Promise`. On top, we have a way to transform `Promise<T>` to `Promise<R>` with a `Next<T, R>` and to recover a `Promise<T>` to a `Future<T>` with a `Recover<T>` - let's have a look at both types:

## Recover

As some point you may wish to recover from the error case of a promise and continue with a plain future. That is what `Recover<T>` is for:

```haxe
@:callable
abstract Recover<T>(Error->Future<T>) from Error->Future<T> {
  @:from static function ofSync<T>(f:Error->T):Recover<T>
    return function (e) return Future.sync(f(e));
}
```

You must provide a function that either synchronously or asynchronously turns an error into data of the expected type.

## Next

The `Next<In, Out>` type describes an asynchronous transformation from `In` to `Out`. In essence it is just `In->Promise<Out>` with a bit of abstract magic sprinkled on top.

```haxe
@:callable
abstract Next<In, Out>(In->Promise<Out>) from In->Promise<Out> {
      
  @:from static private function ofSafe<In, Out>(f:In->Outcome<Out, Error>):Next<In, Out>;
  @:from static private function ofSync<In, Out>(f:In->Future<Out>):Next<In, Out>;
  @:from static private function ofSafeSync<In, Out>(f:In->Out):Next<In, Out>;
    
  @:op(a * b) static private function _chain<A, B, C>(a:Next<A, B>, b:Next<B, C>):Next<A, C>;
}
```

What this achieves is that we may chain operations on promises in a similarly flexible way as `>>`.

```haxe
function requestUrl(url:String):Promise<String> { ... };

requestUrl('http://host.tld/some.xml')
  .next(function (s:String) 
    try return Xml.parse(s)
    catch (e:Dynamic) return new Error('Invalid XML: $s')
  )
  .next(function (x:Xml) return
    x.firstElement().getAttribute('url')
  )
  .next(requestUrl)
  .next(function (data:String) return Future.async(function (cb) {
    var div = document.createDivElement();
    var span = document.createSpanElement();
    span.innerHTML = 'Proceed?';
    var accept = document.createButtonElement();
    accept.innerHTML = 'Yes';
    accept.onclick = cb.bind(data);
  }));
```

As we see, some transformations return synchronously, others return promises, others return plain futures. The first one is particularly interesting in that in one case it returns an `Xml` and in the other case it returns an `Error`. That is because the return type of the function is actually known to be `Promise<T>` and both errors and data can be promoted to that.

## Promise vs Surprise

Promises and futures neatly complement each other in that one means an asynchronous operation that can fail, and the other an operation that can't fail. However promises and surprises compete over the same semantics. Obviously you will want to use surprises if the error type is anything other than `Error`. For everything else, you will probably find `Promise` to be easier to deal with. It works better with type inference that `>>` and also leads to saner error reporting. If you get type errors with `>>` then it tends to results in cascades of `Future<SomeInsanelyComplexTypeParameterHereThatSpansMultipleLines> should be Int`.

# Signal

Despite an overabundance of signal implementations, `tink_core` does provide its own flavour of signals. One that aims at utmost simplicity and full integration with the rest of tink. Here it is:

```haxe
abstract Signal<T> {
  function new(f:Callback<T>->CallbackLink):Void;

  function handle(calback:Callback<T>):CallbackLink;
  
  function map<A>(f:T->A, ?gather:Bool = true):Signal<A>;
  function join(other:Signal<T>, ?gather:Bool = true):Signal<T>;
  function noise():Signal<Noise>;
  
  function gather():Signal<T>;
  
  function next():Future<T>;  
  
  static function trigger<A>():SignalTrigger<A>;
  static function ofClassical<A>(add:(A->Void)->Void, remove:(A->Void)->Void, ?gather = true):Signal<A>;
}
```

A `Signal` quite simply invokes `Callback`s that are registered using `handle` whenever an event occurs.

There is significant similarity between `Signal` and `Future`. It's best to read up on futures if you haven't done so yet. You may also notice `next`, which at any time will create a future corresponding to the *next* occurence of the signal. So if you only want to do something on the next occurence, you would do `someSignal.next().handle(function (data) {})`.

### Why use signals?

When compared to mechanisms like flash's `EventDispatcher` or the DOM's `EventTarget` or nodejs's `EventEmitter`, the critical advantage is type safety.

Say you have the following class:

```haxe
class Button {
  public var pressed(default, null):Signal<MouseEvent>;
  public var clicked(default, null):Signal<MouseEvent>;
  public var released(default, null):Signal<MouseEvent>;
}
```

You know exactly which events to expect and what type they will have. Also, an interface can define signals that an implementor must thus provide. And lastly, the fact that a signal itself is a value, you can pass it around rather then the whole object owning it. Similarly to futures, this allows for composition.

### Wrapping 3rd party APIs

It is quite easy to take an arbitrary API and wrap it in signals. Let's take the beloved `IEventDispatcher`.

```haxe
function makeSignal<A:Event>(dispatcher:IEventDispatcher, type:String):Signal<A> 
  return Signal.ofClassical(
    dispatcher.addEventListener.bind(type),
    dispatcher.removeEventListener.bind(type)
  );

var keydown:Signal<KeyboardEvent> = makeSignal(stage, 'keydown');//yay!!!
```

As far as just `tink.core.Signal` and interoperability with other APIs is concerned, the primary goal is to make it extremely simple to represent any kind of API with signals. And as shown above, there's really not much to it.

### Rolling your own

As the constructor indicates, a signal can be constructed from any function that consumes a callback and returns a link. Therefore `CallbackList` is pretty much a perfect fit. However, for the sake of consistency with `Future`, the intended usage is to create a `SignalTrigger` that you use internally to - well - trigger the `Signal`.

### No way to dispatch from outside

Unlike many other signal flavors, tink's signals do not allow client code to invoke the signal. When exposing a signal that you trigger yourself, typically you will expose only a `Signal` while internally knowing the `SignalTrigger`.
Here's an example of just that:

```haxe
class Clock {
  public var tick(default, null):Signal<Noise>;
  public function new() {
    var s = Signal.trigger();//<-- this trigger is never passed outside the constructor
    var t = new Timer(1000);
    t.run = function () s.trigger(Noise);
    this.tick = s;
  }
}
```

That being said, if you wish to provide means to dispatch a signal from outside, you can of course do so by exposing this functionality in whatever way you see fit.

### Composing

Now let's have a look at the `map` and `join` and `noise` methods. The `gather` parameter has a very similar role to the counterpart for `Future`. We'll examine that later.

First of all, `map` comes from the functional term of mapping. The idea is to use a function that maps values of one type onto other values (possibly of another type) and give that to a more complex data structure that also deals with values of that type, creating a similar data structure, where the function has been applied to every value. In Haxe `Lambda.map` does this for all iterable data structures. Also `Array` and `List` have built in support for this. So if you want to understand this concept, that's probably the best place to look for an easy example.

Secondly, we have `join` that allows us to join two signals of the same type into one. Here's an example of what that might look like, where we assume that we have a `plusButton` and a `minusButton` on our GUI and they each have a signal called `clicked`:

```haxe
var delta = 
  plusButton.clicked
    .map(function (_) return 1)
    .join(minusButton.clicked.map(function (_) return -1));

$type(delta);//tink.core.Signal<Int>
```

From that we have constructed a new `Signal` that fires `1` when the `plusButton` is clicked and `-1`, when the `minusButton` is clicked. 

This way we can map many input events into a single application event without extraneous noise.

The `noise` method mentioned earlier is merely a shortcut to `map` any `Signal` to a `Signal<Noise>`, thus discarding any information it carries. This is useful when you want to propagate an event but not expose the original data and also have no meaningful substitute.

### Gathering

Similar to `Future`, we have "gathering" for `Signal` as well - for pretty much the same reasons. But it also has another role - normalizing behavior:

As we've seen **any** function that accepts a `Callback` and returns a `CallbackLink` is suitable to act as a `Signal`. But such a `Signal` needn't behave consistently with those built on `CallbackList`, i.e. invokation order might be different or duplicate registration might not be allowed or whatever. Or in some instances, the implementation might be slower or weird in some other way (e.g. [ACE's EventEmitter](https://github.com/ajaxorg/ace/blob/master/lib/ace/lib/event_emitter.js#L39) implementation that has all sorts of unexpected behavior if you add/remove handlers for an event type, while an event of the type is dispatched).

What gathering does for signals is quite easily explained. It creates a new `SignalTrigger` and registers that with the original signal. Then the signal derived from the trigger is returned. Therefore behavioral oddities of the original implementation are hidden.

If we look at `Signal.ofClassical` as used in the example with `IEventDispatcher`, we've used gathering (by default). We could choose not to use it. In that case, the callbacks registration would be delegated to the dispatcher in a relatively direct fashion - with all the advantages and problems this may lead to (usually the problems outweigh any advantages).

## SignalTrigger

A `SignalTrigger` is what permits you to build a signal that you can trigger yourself:

```haxe
abstract SignalTrigger<T> {
  function new();
  function trigger(result:T):Void;
  function clear():Void
  @:to function asSignal():Signal<T>;
}
```

The "clock" example above demonstrates how to do that.

# Annex

The `Annex` type allows "attaching" objects to a specific target.

```haxe
class Annex<Target> { 
  function new(target:Target);
  function get<A:Constructible<Target->Void>>(c:Class<A>):A;
}
```

Consider the following:

```haxe
class Person {
  
  public var name(default, null):String;
  public var about(default, null):Annex<Person>;

  public function new(name) {
    this.name = name;
    this.about = new Annex(this);
  }

}

class ObservationProtocol {
  public function new(person:Person) {}
}

var johnDoe = new Person("John Doe");
johnDoe.about.get(ObservationProtocol);//gives us the same ...
johnDoe.about.get(ObservationProtocol);//... protocol every time
```

John does not need to know he is being observed in order for him to be observed. It would of course be possible to just create the observation protocol for him without an `Annex` but the protocol obtained through the annex is unique and tied to him. There's no need for maintaining a registry elsewhere, which risks retaining John in memory when he's no longer needed. When John is GCd, so is his annex.

The presents a nice way to implement the open closed principle. Any object that has an annex can have functionality added at runtime, much like in dynamic languages, but without any risk of conflict and with the possibility for hiding the data as well. Consider this:

```haxe
package mi6;

class Agent {}
private class Report {
  public function new(person:Person) {}
}

package kgb;

class Agent {}
private class Report {
  public function new(person:Person) {}
}
```

This way, mi6 agents cannot access kgb reports and vice versa. Not only that: if the reports were not private, they could still coexist without any conflict.

What's nice is that you can use that state with static extensions:

```haxe
class Dispatcher extends openfl.events.EventDispatcher {
  public function new<A>(target:A) super();
}

class PersonEvents {

  static public function on(target:Person, event:String, handler:Dynamic)
    target.about.get(Dispatcher).addEventListener(event, handler);

  static public function fire(target:Person, event:openfl.events.Event)
    target.about.get(Dispatcher).dispatchEvent(event);
}

using PersonEvents;

johnDoe.on("died", function (_) trace("oh no!"));
johnDoe.fire(new openfl.events.Event("died"));//traces "oh no!"
```

Without any modification to `Person`, we can use it as an `EventDispatcher`.

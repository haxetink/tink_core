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


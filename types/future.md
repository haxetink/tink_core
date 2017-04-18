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


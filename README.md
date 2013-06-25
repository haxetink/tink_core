The `tink_core` package is [separately available on haxelib](http://lib.haxe.org/p/tink_core) and contains a set of lightweight tools for robust programming. 

All modules are situated in `tink.core.*`. Some contain more than a single type. Generally, it is advisable to import the modules of this package through `using` rather than `import`.

Here is an overview:

- [Outcome](#outcome)
- Noise
- Callback
 - CallbackLink
 - CallbackList
- Signal
- Future
 - Surprise
 - FutureTrigger
- Either
- Ref

# Outcome

The outcome type is quite similar to [`haxe.ds.Option`](http://haxe.org/api/haxe/ds/option), but is different in that it is tailored specifically to represent the result of an operation that either fails or succeeds.

```haxe
enum Outcome<Data, Failure> {
	Success(data:Data);
	Failure(?failure:Failure);
}
```

This is a way of doing error reporting without resorting to exceptions or [sentinel values](http://en.wikipedia.org/wiki/Sentinel_value). 

Because switching on `Outcome` all the time can become tedious, the module where `Outcome` resides also defines `OutcomeTools`, a set of helper functions best leveraged by simply [`using tink.core.Outcome`](http://haxe.org/manual/using).

This will give you a number of helper methods:

* `function sure<D,F> ( outcome:Outcome<D,F> ):D`  
Will return the result in case of success or throw an exception otherwise. Therefore the exception is raised not when an operation fails, but when other code doesn't handle failure at all.

* `function toOption<D,F> ( outcome:Outcome<D,F> ):Option<D>`  
Will transform an `Outcome` into an `Option`. Information on failure is thereby lost.
* `function toOutcome<D> ( option:Option<D>, ?pos:haxe.PosInfos ):Outcome<D, String>`  
Converts an `Option` into an `Outcome`, where `Some(value)` is considered success and `None` is considered failure, with an error message.
* `function orUse<D,F> ( outcome:Outcome<D,F>, fallback:D ):D`  
Attempts to get data from a successful `Outcome` or returns a `fallback` otherwise.
* `function orTry<D,F> ( outcome:Outcome<D,F>, fallback:Outcome<D,F> ):Outcome<D,F>`  
If the `outcome` failed, uses `fallback` instead. Note that this can still be a failure.
* `function equals<D,F> ( outcome:Outcome<D,F>, to:D ):Bool`  
Tells whether an `Outcome` is successful and the value is equal to `to`.
* `function map<A,B,F> ( outcome:Outcome<A,F>, transform:A->B ):Outcome<B, F>`  
Returns a new `Outcome`, where the success (if any) is transformed with the given transformer.
* `function asSuccess<D,F> ( data:D ):Outcome<D,F>`  
Converts an arbitrary value to a successful `Outcome`.
* `function asFailure<D,F> ( reason:F ):Outcome<D,F>`  
Converts an arbitrary value to a failed `Outcome`.
* `function isSuccess<D,F> ( outcome:Outcome<D,F> ):Bool`  
Tells whether an outcome was successful.

Here is some example code of what neko file access might look like:

```haxe
using tink.core.Outcome;
enum FileAccessError {
	NoSuchFile(path:String);
	CannotOpen(path:String, reason:Dynamic);
}
class MyFS {
	static public function getContent(path:String) {
		return
			if (sys.FileSystem.exists(path)) 
				try {
					sys.io.File.getContent(path).asSuccess();
				}
				catch (e:Dynamic) {
					CannotOpen(path, e).asFailure();
				}
			else
				NoSuchFile(path).asFailure();
	}
}
class Main {
	static function main() {
		switch (MyFS.getContent('path/to/file')) {
			case Success(s): trace('file content: ' + s);
			case Failure(f):
				switch (f) {
					case NoSuchFile(path): 
						trace('file not found: $path');
					case CannotOpen(path, reason): 
						trace('failed to open file $path because $reason');
				}
		}
		
		trace('other file content: ' + MyFile.getContent('path/to/other_file').sure());
		//will throw an exception if the file content can not be read
		
		var equal = MyFile.getContent('path/to/file').map(haxe.Md5.encode).equals(otherMd5Sig);
		//will be true, if the file could be openend and its content's Md5 signature is equal to `otherMd5Sig`
	}
}
	
```

# Noise

Because in Haxe 3 `Void` can no longer have values, i.e. values of a type that always holds nothing, `tink_core` introduces `Noise`.

```haxe
enum Noise { Noise; }
```

Technically, `null` is also a valid value for `Noise`. In any case, there is no good reason to inspect values of type noise, only to create them.

An example where using `Noise` makes sense is when you have an operation that succeeds with out any data to speak of:

```haxe
function writeToFile(content:String):Outcome<Noise, IoError>;
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

The most important question to ask here is why to complicate a simple concept as callbacks when we already have first class functions.

* It brings more clarity to code. Function types use structural subtyping, i.e. the signature alone defines the type. Type matches can thus be unintentional. Also calling something a callback when that's what it really is, carries more meaning.
* The use of abstracts allows for implicit conversions. If you want to subscribe to an event but don't really care for the data, you don't have to define an argument you're not using. You can simply do either of both:
```
myButton.onClick(function () trace('clicked'));
myButton.onClick(function (e) trace('clicked at (${e.x}, ${e.y})'));
```
* Instead of specifically relying on a function type, we have a separate abstraction, which at some point can be used to leverage platform knowledge to provide for faster code that doesn't have suffer from the performance penalties anonymous function have on most platforms

Beyond that, one might ask what to do if you don't have any data to pass to the callback, or more than a single value. In that case, you could use these two respectively:

```haxe
Callback<Noise>
Callback<{a:A, b:B}>
```

This approach has two advantages:

* For one, it greatly simplifies things. Implementations of signals only ever consume one type of callbacks, so you don't need signals for 0, 1, 2 and possibly 3 arguments.
* Types written against this single callback type are easier to work with in a consistent matter.

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
	var stop = button.onMouseMove(function () trace('move!');
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
	@:to function toSignal():Signal<T>;		
}
```

By calling `add` you can thus register a callback and will obtain a link that allows undoig the registration. You can `invoke` all callbacks in the list with some data, or `clear` the list if you wish to. 

Unlike with similar mechanisms, you can `add` the same callback multiple times and one `invoke` will then cause the callback to be called multiple times. You will however get distinct callback links that allow you to separately undo the registrations.
While this behavior might strike you as unfamiliar, it does have advantages:

- Adding callbacks becomes very cheap (since you don't have to check whether they are already existent)
- Avoid trouble with all sorts of inconsistencies regarding function equality on different Haxe targets
- Have a clear and simple behavior, that is thus highly predictable - i.e. callbacks are simply executed in the order they are registered in. If you register a new callback, you can expect *all* previously registered callbacks to execute *before* it. The same cannot be said in case of the more common approach, if the callback was registered already once. Usually execution order is therefore undefined.

Finally, it is worth nothing that as the last function indicates, the list can also act as a signal. Let's have a look at those now.

# Signal

Despite an overabundance of signal implementations, `tink_core` does provide its own flavour of signals. One that aims at utmost simplicity and full integration with the rest of tink. Here it is:

```haxe
abstract Signal<T> {
	function new(f:Callback<T>->CallbackLink):Void;

	function when(calback:Callback<T>):CallbackLink;
	
	function map<A>(f:T->A, ?gather:Bool = true):Signal<A>;
	function join(other:Signal<T>, ?gather:Bool = true):Signal<T>;
	function noise():Signal<Noise>;
	
	function gather():Signal<T>;
	
	function next():Future<T>;	
}
```

### Rolling your own

As the constructor indicates, a signal can be constructed from any function that consumes a callback and returns a link. It should become obvious, how a `CallbackList` becomes a `Signal`.

### Registering callbacks

Registering callbacks is pretty straight forward. You provide the callback to `when` and get a link in return.

Normally, `Signal` is implemented with a `CallbackList` and thus the same rules apply for callback registration.

### No way to dispatch from outside

Unlike many other signal flavors, tink's signals do not allow client code to invoke the signal. Typically, you will expose only a `Signal` while internally knowing the `CallbackList` that implements it, so that only you can invoke it.

Here's an example of just that:

```haxe
class Clock {
	public var tick(default, null):Signal<Noise>;
	var tickHandlers:CallbackList<Noise>;
	public function new() {
		this.tick = this.tickHandlers = new CallbackList();
		var t = new Timer(1000);
		t.run = function () this.tickHandlers.invoke(Noise);
	}
}
```

That being said, if you wish to provide means to dispatch a signal from outside, you can of course do so by exposing this functionality in whatever way you see fit.

### Wrapping 3rd party APIs

It is also quite easy to take an arbitrary API and wrap it in signals. Let's take the beloved `IEventDispatcher`.

```haxe
function makeSignal<A:Event>(dispatcher:IEventDispatcher, type:String):Signal<A> 
    return new Signal(
        function (cb:Callback<A>):CallbackLink {
        	var f = function (e:A) cb.invoke(e);
            dispatcher.addEventListener(type, f); 
            return dispatcher.removeEventListener.bind(type, f);
        }
    )


var keydown:Signal<KeyboardEvent> = makeSignal(stage, 'keydown');//yay!!!
```

As far as just `tink.core.Signal` and interoperability with other APIs is concerned, the primary goal is to make it extremely simple to represent any kind of API with signals. And as seen above, there's really not much to it.

### Composing

Now let's have a look at the `map` and `join` and `noise` methods. Please do not yet concern yourself with the `gather` parameter some of them define as it will be covered later and is not essential to their intention.

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

The concept of *gathering* is brought into existence by the unfortunate fact that building a non-leaky abstraction that can live on top of any kind of API and allows for easy composition requires sacrifying some simplicity.

Still, it is very easily explained: all that *gathering* does, is to create a new `Signal` on top of a `CallbackList` and register it's `invoke` method to the original signal.

But why bother, you say?

Well, as we've seen **any** function that accepts a `Callback` and returns a `CallbackLink` is suitable to act as a `Signal`. But such a `Signal` needn't behave consistently with those built on `CallbackList`, i.e. invokation order might be different or duplicate registration might not be allowed or whatever. Or in some instances, the implementation might be slower or weird in some other way (e.g. [ACE's EventEmitter](https://github.com/ajaxorg/ace/blob/master/lib/ace/lib/event_emitter.js#L39) implementation that has all sorts of unexpected behavior if you add/remove handlers for an event type, while an event of the type is dispatched).

As seen in the example with `IEventDispatcher`, a signal is quite easy to build. However, in the above implementation, the `Signal` will always call down to the underlying dispatcher to deal with registration. 

You may have noticed that both `map` and `join` have a paremeter for diking, that is true by default. If we do not use diking, what these functions do is to return Signals that implement registration by calling down to the original signals they were constructed from.
Thus `map` will cause the mapping function to be called **for every registered callback**, which can be very expensive. Also `join` will cause the resulting `Signal` to propagate any callback registration to both underlying signals, which can become quite expensive if you join a lot of signals together and perform many registration and deregistrations on them. However, if you create some signals only as intermediary results to be composed into a larger signal, then you should not use `gather` as this introduces unnecessary intermediary objects.

The implications of using gathering or not are rather subtle. But when in doubt, do use it. Or send me an email ;)

# Future

As the name would suggest, futures express the idea that something is going to happen in the future. Or much rather: a future represents the result of an asynchronous operation, that will become available at some point in time. It allows you to register a `Callback` for `when` the operation is finished.

```haxe
abstract Future<T> {
	function new(f:Callback<T>->CallbackLink):Void;	
	function when(callback:Callback<T>):CallbackLink;
	function map<A>(f:T->A):Future<A> 
	function flatMap<A>(next:T->Future<A>):Future<A>; 
	@:from static function fromMany<A>(a:Array<Future<A>>):Future<Array<A>>;
	static function ofConstant<A>(v:A):Future<A>;
	static function ofAsyncCall<A>(f:(A->Void)->Void):Future<A>;
}
```

## Surprise

For all those who love surprises and for all those who hate them, `tink_core` provides a neat way of expressing them. Simply put, a surprise is nothing but a future outcome. Literally:

```haxe
typedef Surprise<D, F> = Future<Outcome<D, F>>;
```

This type thus represents an operation that will finish at some point in time and can end in failure. Perfect for representing asynchronous I/O and such.

## FutureTrigger

You often want to roll your own future. The simplest way to do this is by using a helper class:

```haxe
class FutureTrigger<T> {
	function new():Void;
	function asFuture():Future<T>;
	function invoke(result:T):Bool;
}
```

Here is how you would use such a trigger:

```haxe
class Http {
	static public function requestURL(url:String):Surprise<String, String> {
	   var req = new haxe.Http(url),
		   trigger = new FutureTrigger();
	   req.onData = function (data) trigger.invoke(Success(data));
	   req.onError = function (error) trigger.invoke(Failure(error));
	   return trigger.asFuture();
	}
}
```

And then client code can simply do this:

```haxe
Http.requestURL('http://example.com').when(function (result) switch result {
	case Success(data): //...
	case Failure(data): //...
});
```

Looks pretty neat already. And it forces client code to consider failure.

Also, in `tink_lang` we have sugars to write the same piece of code as:

```haxe
@when(Http.requestURL('http://example.com'))
	@do switch _ {
		case Success(data): //...
		case Failure(data): //...
	}
```

# Either

Represents a value that can have either of two types:

```haxe
enum Either<A,B> {
	Left(a:A);
	Right(b:B);
}
```

# Ref

At times you wish to share the same reference (and therefore changes to it) among different places. Since Haxe doesn't support pointer arithmetics, you need to box the reference in an object, on which you can then operate.

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
var r:Ref<Int> = 4;
var i:Int = r;
```

The current implementation is very naive, not leveraging any platform specifics to provide optimal performance, but there are plans to change this in the future.

The `tink_core` package is [separately available on haxelib](http://lib.haxe.org/p/tink_core) and contains a set of lightweight tools for robust programming. 

Generally, it is advised to import the modules of this package through `using` rather than `import`.

# Ref

At times you wish to share the same reference (and therefore changes to it) among different places. Since Haxe doesn't support pointer arithmetics, you need to box the reference in an object, on which you can then operate.

The `Ref` type does just that, but in an abstract:

```haxe
abstract Ref<T> {
	public var value(get, set):T;
	public function toString():String;
	@:from static public function to(value:T):Ref<T>;
	@:to function toPlain():T;
}
```

It is worth noting that `Ref` defines implicit conversion in both ways. The following code will thus compile:

```haxe
var r:Ref<Int> = 4;
var i:Int = r;
```

The current implementation is very naive, not leveraging any platform specifics to provide optimal performance, but there are plans to change this in the future.

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

# Either

Represents a value that can have either of two types:

```haxe
enum Either<A,B> {
	Left(a:A);
	Right(b:B);
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

tbd

## CallbackLink

tbd

## CallbackList

tbd

# Future

tbd

## FutureTrigger

tbd

# Signal

tbd

## Surprise

tbd
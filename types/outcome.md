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

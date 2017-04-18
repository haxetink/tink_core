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
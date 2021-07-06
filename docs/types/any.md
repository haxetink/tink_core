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
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


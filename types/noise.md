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

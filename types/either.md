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


# Pair

The `Pair` represents an [ordered pair](http://en.wikipedia.org/wiki/Ordered_pair):

```haxe
abstract Pair<A, B> {
  function new(a:A, b:B);
  var a(get, never):A;
  var b(get, never):B;
}
```

The representation is immutable and optimized for runtime performance. It can be used as a basic means of composition, although you should beware not to abuse it.

- Good `function getCredentials():Pair<User, Password>`
- Bad `function getAddress():Pair<Pair<String, Int>, String>`

In the latter example, there are two ways to actually convey meaning:

- with pairs: `function getAddress():Pair<Pair<Host, Port>, Path>`
- vanilla haxe: `function getAddress():{ host:String, port:Int, path:String }`

Advantages of the pair approach:

1. Performance is good on all platforms.
2. The returned value is immutable without having to declare all fields as readonly - this assumes you *want* immutability

### Nullness

As any complex data, pairs are nullable. For `Pair` we consider `null` an "empty pair", which is not sensible from a mathematical point of view, but Lisp managed to build a whole ecosystem on this convention, so it seems a fair bet.

## MPair

The `MPair` is the mutable counterpart to `Pair`. Formerly optimized for speed, it has been demoted to a plain class, which should be fast enough 99% of the time.
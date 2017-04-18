# Named

This is a very basic helper type, defined over its generalization:

```haxe
typedef Named<V> = NamedWith<String, V>;

class NamedWith<N, V> {
  
  public var name(default, null):N;
  public var value(default, null):V;
  
  public function new(name, value) {
    this.name = name;
    this.value = value;
  }
  
}
```

This just formalizes a notion of something being named.
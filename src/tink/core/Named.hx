package tink.core;

typedef Named<V> = NamedWith<String, V>;

class NamedWith<N, V> {
  
  public var name(default, null):N;
  public var value(default, null):V;
  
  public function new(name, value) {
    this.name = name;
    this.value = value;
  }
  
}
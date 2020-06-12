package tink.core;

typedef Named<V> = NamedWith<String, V>;

@:pure
class NamedWith<N, V> {

  public final name:N;
  public final value:V;

  public inline function new(name, value) {
    this.name = name;
    this.value = value;
  }

}
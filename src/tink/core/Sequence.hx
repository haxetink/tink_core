package tink.core;

@:forward
abstract Sequence<T>(Array<T>) from Array<T> to Array<T> {
  @:from
  public static inline function ofSingle<T>(v:T):Sequence<T>
    return [v];
}
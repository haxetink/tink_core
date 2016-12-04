package tink.core;

@:forward(concat, copy, filter, indexOf, iterator, join, lastIndexOf, map, slice, toString)
abstract Sequence<T>(Array<T>) from Array<T> to Array<T> {
  @:from
  public static inline function ofSingle<T>(v:T):Sequence<T>
    return [v];
  
  @:arrayAccess
  public inline function get(i:Int)
    return this[i];
}
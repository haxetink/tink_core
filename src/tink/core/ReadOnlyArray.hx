package tink.core;

@:forward(length, concat, copy, filter, indexOf, iterator, join, lastIndexOf, map, slice, toString)
abstract ReadOnlyArray<T>(Array<T>) from Array<T> {
	@:arrayAccess public inline function get(i:Int) return this[i];
	@:arrayAccess public inline function set(i:Int, v:T) return this[i] = v;
}
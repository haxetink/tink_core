package tink.core;

abstract Sequence<T>(Array<T>) from Array<T> to Array<T> {
  @:from
  public static inline function ofSingle<T>(v:T):Sequence<T>
    return [v];
  
  @:arrayAccess
  public inline function get(i:Int)
    return if(this == null) null else this[i];
    
  public inline function concat(other:Sequence<T>):Sequence<T>
    return if(this == null) other.copy() else this.concat(other);
    
  public inline function copy():Sequence<T>
    return if(this == null) null else this.copy();
    
  public inline function filter(f:T->Bool):Sequence<T>
    return if(this == null) null else this.filter(f);
    
  public inline function indexOf(v:T)
    return if(this == null) -1 else this.indexOf(v);
    
  public inline function join(v:String)
    return if(this == null) '' else this.join(v);
    
  public inline function lastIndexOf(v:T)
    return if(this == null) -1 else this.lastIndexOf(v);
    
  public inline function map<A>(f:T->A):Sequence<A>
    return if(this == null) null else this.map(f);
    
  public inline function slice(pos:Int, ?end:Int):Sequence<T>
    return if(this == null) null else this.slice(pos, end);
    
  public inline function toString()
    return if(this == null) '[]' else this.toString();
    
  public inline function iterator()
    return if(this == null) EmptyIterator.instance else this.iterator();
}

class EmptyIterator {
  public static var instance = new EmptyIterator();
  inline function new() {}
  public inline function hasNext() return false;
  public inline function next() return null;
}
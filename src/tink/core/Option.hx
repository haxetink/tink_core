package tink.core;

typedef Option<T> = haxe.ds.Option<T>;

class OptionTools {
  
  /**
   *  Extracts the value if the option is `Some`, throws an `Error` otherwise
   */
  static public inline function force<T>(o:Option<T>, ?pos:tink.core.Error.Pos)
    return switch o {
      case Some(v): 
        v;
      default: 
        throw new Error(NotFound, 'Some value expected but none found', pos);
    }
  
  /**
   *  Extracts the value if the option is `Some`, uses the fallback value otherwise
   */
  static public inline function or<T>(o:Option<T>, l:Lazy<T>):T
    return switch o {
      case Some(v): v;
      default: l.get();
    }

  /**
   *  Extracts the value if the option is `Some`, otherwise `null`
   */
  static public inline function orNull<T>(o:Option<T>):Null<T>
    return switch o {
      case Some(v): v;
      default: null;
    }
    
  /**
   *  Returns `Some(value)` if the option is `Some` and the filter function evaluates to `true`, otherwise `None`
   */
  static public inline function filter<T>(o:Option<T>, f:T->Bool):Option<T>
    return switch o {
      case Some(f(_) => false): None;
      default: o;
    }
    
  /**
   *  Returns `true` if the option is `Some` and the filter function evaluates to `true`, otherwise `false`
   */
  static public inline function satisfies<T>(o:Option<T>, f:T->Bool):Bool
    return switch o {
      case Some(v): f(v);
      default: false;
    }
    
  /**
   *  Returns `true` if the option is `Some` and the value is equal to `v`, otherwise `false`
   */
  static public inline function equals<T>(o:Option<T>, v:T):Bool
    return satisfies(o, function (found) return found == v);
    
  /**
   *  Transforms the option value with a transform function
   *  Different from `flatMap`, the transform function of `map` returns a plain value
   */
  static public inline function map<In, Out>(o:Option<In>, f:In->Out):Option<Out>
    return switch o {
      case Some(v): Some(f(v));
      default: None;
    }
    
  /**
   *  Transforms the option value with a transform function
   *  Different from `map`, the transform function of `flatMap` returns an `Option`
   */
  static public inline function flatMap<In, Out>(o:Option<In>, f:In->Option<Out>)
    return switch o {
      case Some(v): f(v);
      default: None;
    }
    
  /**
   *  Creates an iterator from the option.
   *  The iterator has one item if the option is `Some`, and no items if it is `None`
   */
  static public inline function iterator<T>(o:Option<T>) 
    return new OptionIter(o);
  
  /**
   *  Creates an array from the option.
   *  The array has one item if the option is `Some`, and no items if it is `None`
   */
  static public inline function toArray<T>(o:Option<T>) 
    return switch o {
      case Some(v): [v];
      default: [];
    }
    
}

class OptionIter<T> {
  var value:T;
  var alive = true;
  
  public inline function new(o:Option<T>) 
    switch o {
      case Some(v): value = v;
      default: alive = false;
    }
    
  public inline function hasNext()
    return alive;
  
  public inline function next() {
    alive = false;
    //TODO: we might want to null the value after usage, but iterators are usually short lived
    return value;
  }
}
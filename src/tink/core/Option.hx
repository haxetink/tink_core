package tink.core;

typedef Option<T> = haxe.ds.Option<T>;

class OptionTools {
  
  static public inline function force<T>(o:Option<T>, ?pos:tink.core.Error.Pos)
    return switch o {
      case Some(v): 
        v;
      default: 
        throw new Error(NotFound, 'Some value expected but none found', pos);
    }
  
  static public inline function or<T>(o:Option<T>, l:Lazy<T>):T
    return switch o {
      case Some(v): v;
      default: l.get();
    }

  static public inline function orNull<T>(o:Option<T>):Null<T>
    return switch o {
      case Some(v): v;
      default: null;
    }
    
  static public inline function filter<T>(o:Option<T>, f:T->Bool):Option<T>
    return switch o {
      case Some(f(_) => false): None;
      default: o;
    }
    
  static public inline function satisfies<T>(o:Option<T>, f:T->Bool):Bool
    return switch o {
      case Some(v): f(v);
      default: false;
    }
    
  static public inline function equals<T>(o:Option<T>, v:T):Bool
    return satisfies(o, function (found) return found == v);
    
  static public inline function map<In, Out>(o:Option<In>, f:In->Out):Option<Out>
    return switch o {
      case Some(v): Some(f(v));
      default: None;
    }
    
  static public inline function flatMap<In, Out>(o:Option<In>, f:In->Option<Out>)
    return switch o {
      case Some(v): f(v);
      default: None;
    }
    
  static public inline function iterator<T>(o:Option<T>) 
    return new OptionIter(o);
    
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
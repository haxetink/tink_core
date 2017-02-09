package tink.core;

using tink.CoreApi;

typedef Promise<T> = Surprise<T, Error>;

abstract Next<In, Out>(Ref<In->Promise<Out>>) {
      
  inline function new(f:In->Promise<Out>) 
    this = Ref.to(f);

  public inline function apply(v:In):Promise<Out> 
    return this.value(v);

  public inline function unwrap():In->Promise<Out>
    return this.value;

  @:from static function ofSafe<In, Out>(f:In->Outcome<Out, Error>):Next<In, Out> 
    return function (x):Promise<Out> return f(x);
    
  @:from static function ofSync<In, Out>(f:In->Future<Out>):Next<In, Out> 
    return function (x):Promise<Out> return f(x);
    
  @:from static function ofSafeSync<In, Out>(f:In->Out):Next<In, Out> 
    return function (x):Promise<Out> return f(x);
  
  @:from static function ofPlain<In, Out>(f:In->Promise<Out>):Next<In, Out>
    return new Next(f);
    
  @:op(a * b) static function _chain<A, B, C>(a:Next<A, B>, b:Next<B, C>):Next<A, C>
    return function (v) return a.apply(v).next(b);
  
}
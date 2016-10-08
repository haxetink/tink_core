package tink.core;

using tink.CoreApi;

abstract Promise<T>(Surprise<T, Error>) from Surprise<T, Error> to Surprise<T, Error> {
  
  function pseudoResult():T
    return cast null;
  
  public inline function recover(f:Error->Future<T>):Future<T>
    return this.flatMap(function (o) return switch o {
      case Success(d): Future.sync(d);
      case Failure(e): f(e);
    });
    
  public inline function handle(cb)
    return this.handle(cb);
    
  public inline function next<R>(f:Next<T, R>):Promise<R> 
    return this >> function (result:T) return (f(result) : Surprise<R, Error>);
  
  @:from static function ofFuture<T>(f:Future<T>):Promise<T>
    return f.map(Success);
    
  @:from static function ofOutcome<T>(o:Outcome<T, Error>):Promise<T>
    return Future.sync(o);
    
  @:from static function ofError<T>(e:Error):Promise<T>
    return ofOutcome(Failure(e));

  @:from static function ofData<T>(d:T):Promise<T>
    return ofOutcome(Success(d));
    
  @:noCompletion @:noUsing 
  static public function lift<T>(p:Promise<T>)
    return p;
}

@:callable
private abstract Next<In, Out>(In->Promise<Out>) from In->Promise<Out> {
      
  @:from static function ofSafe<In, Out>(f:In->Outcome<Out, Error>):Next<In, Out> 
    return function (x) return f(x);
    
  @:from static function ofSync<In, Out>(f:In->Future<Out>):Next<In, Out> 
    return function (x) return f(x);
    
  @:from static function ofSafeSync<In, Out>(f:In->Out):Next<In, Out> 
    return function (x) return f(x);
    
}
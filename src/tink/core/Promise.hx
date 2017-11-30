package tink.core;

using tink.CoreApi;

abstract Promise<T>(Surprise<T, Error>) from Surprise<T, Error> to Surprise<T, Error> {
  
  public static var NULL:Promise<Dynamic> = Future.sync(Success(null));
  public static var NOISE:Promise<Noise> = Future.sync(Success(Noise));
  public static var NEVER:Promise<Dynamic> = Future.NEVER;
  
  public inline function eager():Promise<T>
    return this.eager();

  public inline function map<R>(f:Outcome<T, Error>->R):Future<R>
    return this.map(f);

  public inline function flatMap<R>(f:Outcome<T, Error>->Future<R>):Future<R>
    return this.flatMap(f);

  public inline function tryRecover(f:Next<Error, T>):Promise<T>
    return this.flatMap(function (o) return switch o {
      case Success(d): Future.sync(o);
      case Failure(e): f(e);
    });

  public inline function recover(f:Recover<T>):Future<T>
    return this.flatMap(function (o) return switch o {
      case Success(d): Future.sync(d);
      case Failure(e): f(e);
    });
  
  public function mapError(f:Error->Error):Promise<T>
    return this.map(function(o) return switch o {
      case Success(_): o;
      case Failure(e): Failure(f(e));
    });
        
  public inline function handle(cb:Callback<Outcome<T, Error>>):CallbackLink
    return this.handle(cb);
    
  @:to public function noise():Promise<Noise>
    return (this:Promise<T>).next(function (v) return Noise);
    
  @:to public function isSuccess():Future<Bool>
    return this.map(function (o) return o.isSuccess());
    
  public function next<R>(f:Next<T, R>, ?gather = true):Promise<R> 
    return this.flatMap(function (o) return switch o {
        case Success(d): f(d);
        case Failure(f): Future.sync(Failure(f));
      }, gather);
  
  public inline function swap<R>(v:R):Promise<R> 
    return this >> function(_) return v;
  
  public inline function swapError(e:Error):Promise<T> 
    return mapError(function(_) return e);
    
  public function merge<A, R>(other:Promise<A>, merger:Combiner<T, A, R>, ?gather = true):Promise<R> 
    return next(function (t) return other.next(function (a) return merger(t, a), false), gather);
    
  @:noCompletion @:op(a && b) static public function and<A, B>(a:Promise<A>, b:Promise<B>):Promise<Pair<A, B>>
    return a.merge(b, function (a, b) return new Pair(a, b)); // TODO: a.merge(b, Pair.new); => File "src/typing/type.ml", line 555, characters 9-15: Assertion failed
  
  #if js
  @:from static public inline function ofJsPromise<A>(promise:js.Promise<A>):Promise<A>
    return Future.ofJsPromise(promise);
  #end
  
  @:from static function ofSpecific<T, E>(s:Surprise<T, TypedError<E>>):Promise<T>
    return (s : Surprise<T, Error>);
    
  @:from static inline function ofFuture<T>(f:Future<T>):Promise<T>
    return f.map(Success);
    
  @:from static inline function ofOutcome<T>(o:Outcome<T, Error>):Promise<T>
    return Future.sync(o);
    
  @:from static inline function ofError<T>(e:Error):Promise<T>
    return ofOutcome(Failure(e));

  @:from static inline function ofData<T>(d:T):Promise<T>
    return ofOutcome(Success(d));
    
  public static inline function lazy<T>(p:Lazy<Promise<T>>):Promise<T>
    return Future.async(function(cb) p.get().handle(cb), true);

  static public function inParallel<T>(a:Array<Promise<T>>, ?lazy:Bool):Promise<Array<T>> 
    return 
      if(a.length == 0) Future.sync(Success([]))
      else Future.async(function (cb) {
        var result = [], 
            pending = a.length,
            links:CallbackLink = null,
            sync = false;

        function done(o) {
          if (links == null) sync = true;
          else links.dissolve();
          cb(o);
        }

        function fail(e:Error) {
          done(Failure(e));
        }
        function set(index, value) {
          result[index] = value;
          if (--pending == 0) 
            done(Success(result));
        }
        
        var linkArray = [];
        
        for (i in 0...a.length) {
          if (sync) break;
          linkArray.push(a[i].handle(function (o) switch o {
            case Success(v): set(i, v);
            case Failure(e): fail(e);
          }));
        };

        links = linkArray;

        if (sync) 
          links.dissolve();
      }, lazy);
  
  static public function inSequence<T>(a:Array<Promise<T>>):Promise<Array<T>> {
    
    function loop(index:Int):Promise<Array<T>>
      return 
        if (index == a.length) [];
        else
          a[index].next(
            function (head) return loop(index+1).next(
              function (tail) return [head].concat(tail)
            )
          );

    return loop(0);
  }

  @:noUsing 
  static public inline function lift<T>(p:Promise<T>)
    return p;
}

@:callable
abstract Next<In, Out>(In->Promise<Out>) from In->Promise<Out> {
      
  @:from static function ofSafe<In, Out>(f:In->Outcome<Out, Error>):Next<In, Out> 
    return function (x) return f(x);
    
  @:from static function ofSync<In, Out>(f:In->Future<Out>):Next<In, Out> 
    return function (x) return f(x);
    
  @:from static function ofSafeSync<In, Out>(f:In->Out):Next<In, Out> 
    return function (x) return f(x);
    
  @:op(a * b) static function _chain<A, B, C>(a:Next<A, B>, b:Next<B, C>):Next<A, C>
    return function (v) return a(v).next(b);
  
}

@:callable
abstract Recover<T>(Error->Futuristic<T>) from Error->Futuristic<T> {
  @:from static function ofSync<T>(f:Error->T):Recover<T>
    return function (e) return Future.sync(f(e));
}

@:callable
abstract Combiner<In1, In2, Out>(In1->In2->Promise<Out>) from In1->In2->Promise<Out> {
      
  @:from static function ofSafe<In1, In2, Out>(f:In1->In2->Outcome<Out, Error>):Combiner<In1, In2, Out> 
    return function (x1, x2) return f(x1, x2);
    
  @:from static function ofSync<In1, In2, Out>(f:In1->In2->Future<Out>):Combiner<In1, In2, Out> 
    return function (x1, x2) return f(x1, x2);
    
  @:from static function ofSafeSync<In1, In2, Out>(f:In1->In2->Out):Combiner<In1, In2, Out> 
    return function (x1, x2) return f(x1, x2);
	
}
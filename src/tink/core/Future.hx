package tink.core;

using tink.CoreApi;

abstract Future<T>(FutureObject<T>) from FutureObject<T> to FutureObject<T> {

  public inline function new(f:Callback<T>->CallbackLink) 
    this = new SimpleFuture(f);  
    
  public inline function handle(callback:Callback<T>):CallbackLink //TODO: consider null-case
    return this.handle(callback);
  
  public function gather():Future<T> {
    var op = Future.trigger(),
        self = this;
    return new Future(function (cb:Callback<T>) {
      if (self != null) {
        handle(op.trigger);
        self = null;        
      }
      return op.asFuture().handle(cb);
    });
  }
  
  public function first(other:Future<T>):Future<T> { // <-- consider making it lazy by default
    var ret = Future.trigger();
    var l1 = handle(ret.trigger);
    var l2 = other.handle(ret.trigger);
    var ret = ret.asFuture();
    if (l1 != null)
      ret.handle(l1);
    if (l2 != null)
      ret.handle(l2);
    return ret;
  }
  
  public function map<A>(f:T->A, ?gather = true):Future<A> {
    var ret = new Future(function (callback) return this.handle(function (result) callback.invoke(f(result))));
    return
      if (gather) ret.gather();
      else ret;
  }
  
  public function flatMap<A>(next:T->Future<A>, ?gather = true):Future<A> {
    var ret = flatten(map(next, gather));
    return
      if (gather) ret.gather();
      else ret;    
  }  
  
  public function merge<A, R>(other:Future<A>, merger:T->A->R, ?gather = true):Future<R> 
    return flatMap(function (t:T) {
      return other.map(function (a:A) return merger(t, a), false);
    }, gather);
  
  static public function flatten<A>(f:Future<Future<A>>):Future<A> 
    return new Future(function (callback) {
      var ret = null;
      ret = f.handle(function (next:Future<A>) {
        ret = next.handle(function (result) callback.invoke(result));
      });
      return ret;
    });
  
  @:from inline static function fromTrigger<A>(trigger:FutureTrigger<A>):Future<A> 
    return trigger.asFuture();
  
  #if js
  static public function ofJsPromise<A>(promise:js.Promise<A>):Surprise<A, Error>
    return Future.async(function(cb) promise.then(function(a) cb(Success(a))).catchError(function(e:js.Error) cb(Failure(Error.withData(e.message, e)))));
  #end
    
  static inline public function asPromise<T>(s:Surprise<T, Error>):Promise<T>
    return s;
  
  static public function ofMany<A>(futures:Array<Future<A>>, ?gather:Bool = true) {
    var ret = sync([]);
    for (f in futures)
      ret = ret.flatMap(
        function (results:Array<A>) 
          return f.map(
            function (result) 
              return results.concat([result]),
            false
          ),
        false
      );
    return 
      if (gather) ret.gather();
      else ret;
  }
  
  @:from static function fromMany<A>(futures:Array<Future<A>>):Future<Array<A>> 
    return ofMany(futures);
  
  //TODO: use this as `sync` when Haxe stops upcasting ints
  @:noUsing static public function lazy<A>(l:Lazy<A>):Future<A>
    return new Future(function (cb:Callback<A>) { cb.invoke(l); return null; });    
  
  @:noUsing static public function sync<A>(v:A):Future<A> 
    return new Future(function (callback) { callback.invoke(v); return null; } );
    
  @:noUsing static public function async<A>(f:(A->Void)->Void, ?lazy = false):Future<A> 
    if (lazy) 
      return flatten(Future.lazy(async.bind(f, false)));
    else {
      var op = trigger();
      f(op.trigger);
      return op;      
    }    
    
  @:noCompletion @:op(a || b) static public function or<A>(a:Future<A>, b:Future<A>):Future<A>
    return a.first(b);
    
  @:noCompletion @:op(a || b) static public function either<A, B>(a:Future<A>, b:Future<B>):Future<Either<A, B>>
    return a.map(Either.Left, false).first(b.map(Either.Right, false));
      
  @:noCompletion @:op(a && b) static public function and<A, B>(a:Future<A>, b:Future<B>):Future<Pair<A, B>>
    return a.merge(b, function (a, b) return new Pair(a, b));
  
  @:noCompletion @:op(a >> b) static public function _tryFailingFlatMap<D, F, R>(f:Surprise<D, F>, map:D->Surprise<R, F>)
    return f.flatMap(function (o) return switch o {
      case Success(d): map(d);
      case Failure(f): Future.sync(Failure(f));
    });

  @:noCompletion @:op(a >> b) static public function _tryFlatMap<D, F, R>(f:Surprise<D, F>, map:D->Future<R>):Surprise<R, F> 
    return f.flatMap(function (o) return switch o {
      case Success(d): map(d).map(Success);
      case Failure(f): Future.sync(Failure(f));
    });
    
  @:noCompletion @:op(a >> b) static public function _tryFailingMap<D, F, R>(f:Surprise<D, F>, map:D->Outcome<R, F>)
    return f.map(function (o) return o.flatMap(map));

  @:noCompletion @:op(a >> b) static public function _tryMap<D, F, R>(f:Surprise<D, F>, map:D->R)
    return f.map(function (o) return o.map(map));    
  
  @:noCompletion @:op(a >> b) static public function _flatMap<T, R>(f:Future<T>, map:T->Future<R>)
    return f.flatMap(map);

  @:noCompletion @:op(a >> b) static public function _map<T, R>(f:Future<T>, map:T->R)
    return f.map(map);

  @:noUsing static public inline function trigger<A>():FutureTrigger<A> 
    return new FutureTrigger();  

  @:impl @:to static public function noise<T>(p:FutureObject<Outcome<T, Error>>):Promise<Noise>
    return lift(p).next(function (v) return Noise);

  @:impl public inline function recover<T>(p:FutureObject<Outcome<T, Error>>, f:Recover<T>):Future<T>
    return lift(p).flatMap(function (o) return switch o {
      case Success(d): Future.sync(d);
      case Failure(e): f(e);
    });    

  @:impl static public function next<T, R>(o:FutureObject<Outcome<T, Error>>, f:Next<T, R>):Promise<R> 
    return _tryFailingFlatMap(o, f.unwrap());

  @:from static function ofSpecific<T, E>(s:Surprise<T, TypedError<E>>):Promise<T>
    return (cast s : Surprise<T, Error>);
    
  @:from static inline function ofFuture<T>(f:Future<T>):Promise<T>
    return f.map(Success);
    
  @:from static inline function ofOutcome<T>(o:Outcome<T, Error>):Promise<T>
    return Future.sync(o);
    
  @:from static inline function ofError<T>(e:Error):Promise<T>
    return ofOutcome(Failure(e));

  @:from static inline function ofData<T>(d:T):Promise<T>
    return ofOutcome(Success(d));
    
  @:noCompletion @:noUsing 
  static public inline function lift<T>(p:Promise<T>)
    return p;    
}

interface FutureObject<T> {
  function handle(callback:Callback<T>):CallbackLink;
}

class SyncFuture<T> implements FutureObject<T> {
  
  var value:Lazy<T>;

  public inline function new(value)
    this.value = value;

  public inline function map<R>(f:T->R):Future<R>
    return new SyncFuture(value.map(f));

  public function handle(cb:Callback<T>):CallbackLink {
    cb.invoke(value);
    return null;
  }
}

class SimpleFuture<T> implements FutureObject<T> {
  var f:Callback<T>->CallbackLink;
  public inline function new(f) this.f = f;
  public inline function handle(callback:Callback<T>):CallbackLink
    return f(callback);
}

class FutureTrigger<T> implements FutureObject<T> {
  var result:T;
  var list:CallbackList<T>;

  public function new() 
    this.list = new CallbackList();
  
  public function handle(callback:Callback<T>):CallbackLink
    return switch list {
      case null: 
        callback.invoke(result);
        null;
      case v:
        v.add(callback);
    }

  public inline function asFuture():Future<T>
    return this;
  
  static var depth = 0;
  public function trigger(result:T):Bool
    return
      if (list == null) false;
      else {
        var list = this.list;
        this.list = null;
        this.result = result;
        inline function dispatch() {
          depth++;
          list.invoke(result);
          list.clear();//free callback links          
          depth--;
        }
        if (depth >= 1000)
          Callback.defer(function () dispatch());
        else
          dispatch();
        true;
      }
}

typedef Surprise<D, F> = Future<Outcome<D, F>>;

@:callable
private abstract Recover<T>(Error->Future<T>) from Error->Future<T> {
  @:from static function ofSync<T>(f:Error->T):Recover<T>
    return function (e) return Future.sync(f(e));
}

#if js
class JsPromiseTools {
  static inline public function toSurprise<A>(promise:js.Promise<A>):Surprise<A, Error>
    return Future.ofJsPromise(promise);
  static inline public function toPromise<A>(promise:js.Promise<A>):Promise<A>
    return Future.ofJsPromise(promise);
}
#end

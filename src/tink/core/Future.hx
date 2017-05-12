package tink.core;

using tink.CoreApi;

abstract Future<T>(FutureObject<T>) from FutureObject<T> to FutureObject<T> {
  
  public static var NOISE:Future<Noise> = Future.sync(Noise);
  public static var NEVER:Future<Dynamic> = Future.async(function(_){});

  public inline function new(f:Callback<T>->CallbackLink) 
    this = new SimpleFuture(f);  
    
  public inline function handle(callback:Callback<T>):CallbackLink //TODO: consider null-case
    return this.handle(callback);
  
  public inline function eager():Future<T>
    return this.eager();

  public inline function gather():Future<T> 
    return this.gather();
  
  public function first(other:Future<T>):Future<T> { // <-- consider making it lazy by default ... also pull down into FutureObject
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
  
  public inline function map<A>(f:T->A, ?gather = true):Future<A> {
    var ret = this.map(f);
    return
      if (gather) ret.gather();
      else ret;
  }
  
  public inline function flatMap<A>(next:T->Future<A>, ?gather = true):Future<A> {
    var ret = this.flatMap(next);
    return
      if (gather) ret.gather();
      else ret;    
  }  

  public function next<R>(n:Next<T, R>):Promise<R>
    return this.flatMap(function (v) return n(v));
  
  public function merge<A, R>(other:Future<A>, merger:T->A->R, ?gather = true):Future<R> 
    return flatMap(function (t:T) {
      return other.map(function (a:A) return merger(t, a), false);
    }, gather);
  
  static public function flatten<A>(f:Future<Future<A>>):Future<A> 
    return new NestedFuture(f);
  
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
  
  //TODO: use this as `sync` for 2.0
  @:noUsing static inline public function lazy<A>(l:Lazy<A>):Future<A>
    return new SyncFuture(l);    
  
  @:noUsing static inline public function sync<A>(v:A):Future<A> 
    return new SyncFuture(v); 
    
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

}

abstract Futuristic<T>(Future<T>) from Future<T> to Future<T> {
  @:from static function ofAny<T>(v:T):Futuristic<T>
    return Future.sync(v);
}

private interface FutureObject<T> {
  function map<R>(f:T->R):Future<R>;
  function flatMap<R>(f:T->Future<R>):Future<R>;
  function handle(callback:Callback<T>):CallbackLink;
  function gather():Future<T>;
  function eager():Future<T>;
}

private class SyncFuture<T> implements FutureObject<T> {
  
  var value:Lazy<T>;

  public inline function new(value)
    this.value = value;

  public inline function map<R>(f:T->R):Future<R>
    return new SyncFuture(value.map(f));

  public inline function flatMap<R>(f:T->Future<R>):Future<R>
    return new SimpleFuture({
      var l = value.map(f);
      function (cb) return l.get().handle(cb);
    });

  public function handle(cb:Callback<T>):CallbackLink {
    cb.invoke(value);
    return null;
  }

  public function eager()
    return this;

  public function gather()
    return this;
}

private class SimpleFuture<T> implements FutureObject<T> {
  
  var f:Callback<T>->CallbackLink;
  var gathered:Future<T>;

  public inline function new(f) 
    this.f = f;

  public inline function handle(callback:Callback<T>):CallbackLink
    return f(callback);

  public inline function map<R>(f:T->R):Future<R>
    return new SimpleFuture(function (cb) {
      return handle(function (v) cb.invoke(f(v)));
    });

  public inline function flatMap<R>(f:T->Future<R>):Future<R>
    return Future.flatten(map(f));

  public inline function gather():Future<T> 
    return FutureTrigger.gatherFuture(this);

  public inline function eager():Future<T> {
    var ret = gather();
    ret.handle(function () {});
    return ret;
  }
}

private class NestedFuture<T> implements FutureObject<T> {
  var outer:Future<Future<T>>;

  public inline function new(outer)
    this.outer = outer;

  public inline function map<R>(f:T->R):Future<R>
    return outer.flatMap(function (inner) return inner.map(f));

  public inline function flatMap<R>(f:T->Future<R>):Future<R>
    return outer.flatMap(function (inner) return inner.flatMap(f));
  
  public inline function gather():Future<T> 
    return FutureTrigger.gatherFuture(this);

  public inline function eager():Future<T> {
    var ret = gather();
    ret.handle(function () {});
    return ret;
  }
  
  public function handle(cb:Callback<T>) {
    var ret = null;
    ret = outer.handle(function (inner:Future<T>) {
      ret = inner.handle(function (result) cb.invoke(result));
    });
    return ret;
  }
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

  public function map<R>(f:T->R):Future<R>
    return switch list {
      case null: Future.sync(f(result));
      case v:
        var ret = new FutureTrigger();
        list.add(function (v) ret.trigger(f(v)));
        ret;
    }

  public function flatMap<R>(f:T->Future<R>):Future<R>
    return switch list {
      case null: f(result);
      case v:
        var ret = new FutureTrigger();
        list.add(function (v) f(v).handle(ret.trigger));
        ret;
    }

  public inline function gather()
    return this;

  public inline function eager()
    return this;

  public inline function asFuture():Future<T>
    return this;

  static public function gatherFuture<T>(f:Future<T>):Future<T> {
    var op = null;
    return new Future<T>(function (cb:Callback<T>) {
      if (op == null) {
        op = new FutureTrigger();
        f.handle(op.trigger);
        f = null;        
      }
      return op.handle(cb);
    });  
  }

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

#if js
class JsPromiseTools {
  static inline public function toSurprise<A>(promise:js.Promise<A>):Surprise<A, Error>
    return Future.ofJsPromise(promise);
  static inline public function toPromise<A>(promise:js.Promise<A>):Promise<A>
    return Future.ofJsPromise(promise);
}
#end

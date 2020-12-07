package tink.core;

import tink.core.Callback;
import tink.core.Error;
import tink.core.Future;
import tink.core.Noise;
import tink.core.Outcome;
import tink.core.Signal.Gather;

#if js
import js.lib.Error as JsError;
import js.lib.Promise as JsPromise;
#end

/**
  Representation of the outcome of a potentially asynchronous operation that can fail.

  This type is a compile-time wrapper over `Future<Outcome<T, tink.core.Error>>` that provides
  convenience API for dealing with failure outcomes.
**/
@:forward(status) @:transitive
abstract Promise<T>(Surprise<T, Error>) from Surprise<T, Error> to Surprise<T, Error> {

  static public final NOISE:Promise<Noise> = Future.sync(Success(Noise));
  @:deprecated('use Promise.NOISE instead') static public final NULL:Promise<Noise> = NOISE;
  static public final NEVER:Promise<Never> = Future.NEVER;

  public inline function new(f:(T->Void)->(Error->Void)->CallbackLink)
    this = new Future(cb -> f(v -> cb(Success(v)), e -> cb(Failure(e))));

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

  public function isSuccess():Future<Bool>
    return this.map(function (o) return o.isSuccess());

  public function next<R>(f:Next<T, R>, ?gather:Gather):Promise<R>
    return this.flatMap(function (o) return switch o {
      case Success(d): f(d);
      case Failure(f): Future.sync(Failure(f));
    });

  public inline function swap<R>(v:R):Promise<R>
    return next(_ -> v);

  public inline function swapError(e:Error):Promise<T>
    return mapError(_ -> e);

  public function merge<A, R>(other:Promise<A>, merger:Combiner<T, A, R>, ?gather:Gather):Promise<R>
    return this.merge(other, (a, b) -> switch [a, b] {
      case [Success(a), Success(b)]: merger(a, b);
      case [Failure(e), _] | [_, Failure(e)]: Promise.lift(e);
    }).flatMap(o -> o);

  @:noCompletion @:op(a && b) static function and<A, B>(a:Promise<A>, b:Promise<B>):Promise<Pair<A, B>>
    // return a.merge(b, Pair.new); // see https://github.com/HaxeFoundation/haxe/issues/9764
    return a.merge(b, (a, b) -> new Pair(a, b));

  /**
   * Given an Iterable (e.g. Array) of Promises, handle them one by one with the `yield` function until one of them yields `Some` value
   * and the returned promise will resolve that value. If all of them yields `None`, the returned promise will resolve to the `fallback` promise.
   * In a nutshell, it is the async version of the following code:
   * ```haxe
   * for(promise in promises) {
   *   switch yield(promise) {
   *     case Some(v): return v;
   *     case None:
   *   }
   * }
   * return fallback;
   * ```
   * @param promises An Iterable (e.g. Array) of Promises
   * @param yield A function used to handle the promises and should return an Option
   * @param fallback A value to be used when all yields `None`
   * @return Promise<T>
   */
  @:noUsing
  static public function iterate<A, R>(promises:Iterable<Promise<A>>, yield:Next<A, Option<R>>, fallback:Promise<R>):Promise<R> {
    return Future.irreversible(function(cb) {
      var iter = promises.iterator();
      function next() {
        if(iter.hasNext())
          iter.next().handle(function(o) switch o {
            case Success(v):
              yield(v).handle(function(o) switch o {
                case Success(Some(ret)): cb(Success(ret));
                case Success(None): next();
                case Failure(e): cb(Failure(e));
              });
            case Failure(e):
              cb(Failure(e));
          })
        else
          fallback.handle(cb);
      }
      next();
    });
  }

  /**
   * Retry a promise generator repeatedly
   *
   * @param gen A function that returns a `Promise`, this function will be called multiple times during the retry process
   * @param next A callback to be called when an attempt failed. An object will be received containing the info of the last attempt:
   *   `attempt` is the number of attempts tried, starting from `1`
   *   `error` is the error produced from the last attempt
   *   `elasped` is the amount of time (in ms) elapsed since the beginning of the `retry` call
   *
   *   If this function's returned promised resolves to an `Error`, this retry will abort with such error. Otherwise if it resolves to a `Success(Noise)`, the retry will continue.
   *
   *   Some usage examples:
   *     - wait longer for later attempts and stop after a limit:
   *     ```haxe
   *     function (info) return switch info.attempt {
   *         case 10: info.error;
   *         case v: Future.delay(v * 1000, Noise);
   *     }
   *     ```
   *
   *     - bail out on error codes that are fatal:
   *     ```haxe
   *     function (info) return switch info.error.code {
   *       case Forbidden : info.error; // in this case new attempts probably make no sense
   *       default: Future.delay(1000, Noise);
   *     }
   *     ```
   *
   *     - and also actually timeout:
   *     ```haxe
   *     // with using DateTools
   *     function (info) return
   *       if (info.elapsed > 2.minutes()) info.error
   *       else Future.delay(1000, Noise);
   *     ```
   *
   * @return Promise<T>
   */
  @:noUsing
  static public function retry<T>(gen:()->Promise<T>, next:Next<{ attempt: Int, error:Error, elapsed:Float }, Noise>):Promise<T> {
    function stamp() return haxe.Timer.stamp() * 1000;
    var start = stamp();
    return (function attempt(count:Int) {
      return gen().tryRecover(
        function (error) {
          return next({ attempt: count, error: error, elapsed: stamp() - start })
            .next(function (_) return attempt(count + 1));
        }
      );
    })(1);
  }

  #if js
  @:noUsing
  @:from static public inline function ofJsPromise<A>(promise:JsPromise<A>):Promise<A>
    return Future.ofJsPromise(promise);

  @:to public inline function toJsPromise():JsPromise<T>
    return new JsPromise(function(resolve, reject) this.handle(function(o) switch o {
      case Success(v): resolve(v);
      case Failure(e): reject(e.toJsError());
    }));
  #end

  // TODO: investigate why inlining this will cause all kinds of type error all over the place (downstream libraries)
  @:from static function ofSpecific<T, E>(s:Surprise<T, TypedError<E>>):Promise<T>
    return (cast s : Surprise<T, Error>);

  @:from static function fromNever<T>(l:Promise<Never>):Promise<T>
    return cast l;

  @:from static inline function ofTrigger<T>(f:FutureTrigger<Outcome<T, Error>>):Promise<T>
    return f.asFuture();

  @:from static inline function ofHappyTrigger<T>(f:FutureTrigger<T>):Promise<T>
    return ofFuture(f.asFuture());

  @:from static inline function ofFuture<T>(f:Future<T>):Promise<T>
    return f.map(Success);

  @:from static inline function ofOutcome<T>(o:Outcome<T, Error>):Promise<T>
    return Future.sync(o);

  @:from static inline function ofError<T>(e:Error):Promise<T>
    return ofOutcome(Failure(e));

  @:from static inline function ofData<T>(d:T):Promise<T>
    return ofOutcome(Success(d));

  @:noUsing
  static public inline function lazy<T>(p:Lazy<Promise<T>>):Promise<T>
    return new Future(cb -> p.get().handle(cb));

  @:noUsing
  static public function inParallel<T>(a:Array<Promise<T>>, ?concurrency:Int):Promise<Array<T>>
    return many(a, concurrency);

  static function many<T>(a:Array<Promise<T>>, ?concurrency:Int):Promise<Array<T>>
    return @:privateAccess Future.processMany((cast a:Array<Surprise<T, Error>>), concurrency, o -> o, o -> o);//TODO: raise issue for the cast

  @:noUsing
  static public function inSequence<T>(a:Array<Promise<T>>):Promise<Array<T>>
    return many(a, 1);

  #if (!java || jvm)
  @:noUsing
  static public function cache<T>(gen:()->Promise<Pair<T, Future<Noise>>>):()->Promise<T> {
    var p = null;
    return function() {
      var ret = p;
      if(ret == null) {
        var sync = false;
        ret = gen().next(function(o) {
          o.b.handle(function(_) {
            sync = true;
            p = null;
          });
          return o.a;
        });
        if(!sync) p = ret;
      }
      return ret.map(function(o) {
        if(!o.isSuccess()) p = null;
        return o;
      });
    }
  }
  #end

  @:noUsing
  static public inline function lift<T>(p:Promise<T>)
    return p;

  /**
   *  Creates a new `PromiseTrigger`
   */
  @:noUsing
  static public inline function trigger<A>():PromiseTrigger<A>
    return new PromiseTrigger();

  @:noUsing
  static public inline function resolve<A>(v:A):Promise<A>
    return Future.sync(Success(v));

  @:noUsing
  static public inline function reject<A>(e:Error):Promise<A>
    return Future.sync(Failure(e));
}

@:callable
abstract Next<In, Out>(In->Promise<Out>) from In->Promise<Out> to In->Promise<Out> {

  @:from extern inline static function ofDynamic<In>(f:In->Nonsense):Next<In, Dynamic> // Nonsense being non-existent, no function should ever unify with this, unless it returns Dynamic
    return function (x):Promise<Dynamic> {
      var d:Dynamic = f(x);
      return Future.sync(Success(d));
    }

  @:from static function ofSafe<In, Out>(f:In->Outcome<Out, Error>):Next<In, Out>
    return x -> f(x);

  @:from static function ofSync<In, Out>(f:In->Future<Out>):Next<In, Out>
    return x -> f(x);

  @:from static function ofSafeSync<In, Out>(f:In->Out):Next<In, Out>
    return x -> f(x);

  @:op(a * b) static function _chain<A, B, C>(a:Next<A, B>, b:Next<B, C>):Next<A, C>
    return v -> a(v).next(b);

}

private abstract Nonsense(Dynamic) {}

@:callable
abstract Recover<T>(Error->Future<T>) from Error->Future<T> {
  @:from static function ofSync<T>(f:Error->T):Recover<T>
    return e -> Future.sync(f(e));
}

@:callable
abstract Combiner<In1, In2, Out>(In1->In2->Promise<Out>) from In1->In2->Promise<Out> {

  @:from static function ofSync<In1, In2, Out>(f:In1->In2->Outcome<Out, Error>):Combiner<In1, In2, Out>
    return (x1, x2) -> f(x1, x2);

  @:from static function ofSafe<In1, In2, Out>(f:In1->In2->Future<Out>):Combiner<In1, In2, Out>
    return (x1, x2) -> f(x1, x2);

  @:from static function ofSafeSync<In1, In2, Out>(f:In1->In2->Out):Combiner<In1, In2, Out>
    return (x1, x2) -> f(x1, x2);

}

@:forward
abstract PromiseTrigger<T>(FutureTrigger<Outcome<T, Error>>) from FutureTrigger<Outcome<T, Error>> to FutureTrigger<Outcome<T, Error>> {

  public inline function new()
    this = Future.trigger();

  public inline function resolve(v:T)
    return this.trigger(Success(v));

  public inline function reject(e:Error)
    return this.trigger(Failure(e));

  @:to public inline function asPromise():Promise<T> return this.asFuture();
}

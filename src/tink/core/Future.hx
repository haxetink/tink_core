package tink.core;

import tink.core.Signal;
import tink.core.Callback;

using tink.CoreApi;

#if js
import #if haxe4 js.lib.Error #else js.Error #end as JsError;
import #if haxe4 js.lib.Promise #else js.Promise #end as JsPromise;
#end

@:forward(handle, eager)
abstract Future<T>(FutureObject<T>) from FutureObject<T> to FutureObject<T> {

  static public final NULL:Future<Dynamic> = Future.sync(null);
  static public final NOISE:Future<Noise> = Future.sync(Noise);
  static public final NEVER:Future<Dynamic> = (NeverFuture.inst:FutureObject<Dynamic>);

  public var status(get, never):FutureStatus<T>;
    inline function get_status()
      return this.getStatus();

  public inline function new(f:(T->Void)->CallbackLink)
    this = new SuspendableFuture(f);

  /**
   *  Creates a future that contains the first result from `this` or `that`
   */
  public function first(that:Future<T>):Future<T>
    return switch [(this:Future<T>), that] {
      case [{ status: NeverEver }, v]
         | [v, { status: NeverEver }]
         | [v = { status: Ready(_) }, _]
         | [_, v = { status: Ready(_) }]:
         v;
      default:
        new SuspendableFuture<T>(fire -> this.handle(fire) & that.handle(fire));
    }

  /**
   *  Creates a new future by applying a transform function to the result.
   *  Different from `flatMap`, the transform function of `map` returns a sync value
   */
  public function map<A>(f:T->A, ?gather:Gather):Future<A>
    return switch status {
      case NeverEver: cast NEVER;
      case Ready(l): new SyncFuture<A>(l.map(f));
      default: new SuspendableFuture<A>(fire -> this.handle(v -> fire(f(v))));
    }

  /**
   *  Creates a new future by applying a transform function to the result.
   *  Different from `map`, the transform function of `flatMap` returns a `Future`
   */
  public function flatMap<A>(next:T->Future<A>, ?gather:Gather):Future<A>
    return switch status {
      case NeverEver: cast NEVER;
      case Ready(l):
        new SuspendableFuture<A>(fire -> next(l.get()).handle(v -> fire(v)));
      default:
        new SuspendableFuture<A>(function (yield) {
          final inner = new CallbackLinkRef();
          final outer = this.handle(v -> inner.link = next(v).handle(yield));
          return outer.join(inner);
        });
    }

  /**
   *  Like `map` and `flatMap` but with a polymorphic transformer and return a `Promise`
   *  @see `Next`
   */
  public inline function next<R>(n:Next<T, R>):Promise<R>
    return flatMap(n);

  @:deprecated('Gathering no longer has any effect')
  public inline function gather():Future<T>
    return this;

  /**
   *  Merges two futures into one by applying `combine` on the two future values
   */
  public function merge<A, R>(that:Future<A>, combine:T->A->R):Future<R>
    return switch [status, that.status] {
      case [NeverEver, _] | [_, NeverEver]: cast NEVER;
      default:
        new SuspendableFuture<R>(yield -> {
          function check(?v:Dynamic)
            return switch [status, that.status] {
              case [Ready(a), Ready(b)]:
                yield(combine(a, b));
              default:
            }

          this.handle(check) & that.handle(check);
        });
    }


  /**
   *  Flattens `Future<Future<A>>` into `Future<A>`
   */
  static public function flatten<A>(f:Future<Future<A>>):Future<A>
    return f.flatMap(v -> v);

  #if js
  /**
   *  Casts a js Promise into a Surprise
   */
  @:from static public function ofJsPromise<A>(promise:JsPromise<A>):Surprise<A, Error>
    return Future.async(function(cb) promise.then(function(a) cb(Success(a))).catchError(function(e:JsError) cb(Failure(Error.withData(e.message, e)))));
  #end

  @:from static inline function ofAny<T>(v:T):Future<T>
    return Future.sync(v);

  /**
   *  Casts a Surprise into a Promise
   */
  static inline public function asPromise<T>(s:Surprise<T, Error>):Promise<T>
    return s;

  @:deprecated('use inSequence instead')
  static public function ofMany<A>(futures:Array<Future<A>>, ?gather:Gather)
    return inSequence(futures);


  /**
   * Merges multiple futures into a `Future<Array<A>>`
   * The futures are processed simultaneously. Set concurrency to limit how many are processed at a time.
   */
   static public function inParallel<T>(futures:Array<Future<T>>, ?concurrency:Int):Future<Array<T>>
    return many(futures, concurrency);//the `orNull` just pleases the typer

  /**
   * Merges multiple futures into a `Future<Array<A>>`
   * The futures are processed one at a time.
   */
  static public function inSequence<T>(futures:Array<Future<T>>):Future<Array<T>>
    return many(futures, 1);

  static function many<X>(a:Array<Future<X>>, ?concurrency:Int)
    return processMany(a, concurrency, Success, o -> o.orNull());//the `orNull` just pleases the typer

  static function processMany<In, X, Abort, Out>(a:Array<Future<In>>, ?concurrency:Int, fn:In->Outcome<X, Abort>, lift:Outcome<Array<X>, Abort>->Out):Future<Out>
    return switch a {
      case []: Future.sync(lift(Success([])));
      default: new Future(yield -> {
        var links = new Array<CallbackLink>(),
            ret = [for (x in a) (null:X)],
            index = 0,
            pending = 0,
            done = false,
            concurrency = switch concurrency {
              case null: a.length;
              case v:
                if (v < 1) 1;
                else if (v > a.length) a.length;
                else v;
            };

        inline function fire(v) {
          done = true;
          yield(v);
        }

        function fireWhenReady()
          return
            if (index == ret.length)
              if (pending == 0) {
                fire(lift(Success(ret)));
                true;
              }
              else false;
            else false;

        function step()
          if (!done && !fireWhenReady())
            while (index < ret.length) {

              var index = index++;
              var p = a[index];

              function check(o:In)
                switch fn(o) {
                  case Success(v):
                    ret[index] = v;
                    fireWhenReady();
                  case Failure(e):
                    for (l in links)
                      l.cancel();
                    fire(lift(Failure(e)));
                }

              switch p.status {
                case Ready(_.get() => v):
                  check(v);
                  if (!done) continue;
                default:
                  pending++;
                  links.push(
                    p.handle(function (o) {
                      pending--;
                      check(o);
                      if (!done) step();
                    })
                  );
              }
              break;
            }

        for (i in 0...concurrency)
          step();

        return links;
      });

    }

  //TODO: use this as `sync` for 2.0
  @:noUsing static inline public function lazy<A>(l:Lazy<A>):Future<A>
    return new SyncFuture(l);

  /**
   *  Creates a sync future.
   *  Example: `var i = Future.sync(1); // Future<Int>`
   */
  @:noUsing static inline public function sync<A>(v:A):Future<A>
    return lazy(v);

  @:noUsing static inline public function isFuture(maybeFuture: Dynamic)
    return Std.is(maybeFuture, FutureObject);

  /**
   *  Creates an async future
   *  Example: `var i = Future.async(function(cb) cb(1)); // Future<Int>`
   */
  #if python @:native('make') #end
  @:noUsing static public function async<A>(f:(A->Void)->Void, ?lazy = false):Future<A> {

    var ret = new SuspendableFuture(function (yield) {
      f(yield);
      return null;
    });

    return if (lazy) ret else ret.eager();
  }

  /**
   *  Same as `first`
   */
  @:noCompletion @:op(a || b) static public function or<A>(a:Future<A>, b:Future<A>):Future<A>
    return a.first(b);

  /**
   *  Same as `first`, but use `Either` to handle the two different types
   */
  @:noCompletion @:op(a || b) static public function either<A, B>(a:Future<A>, b:Future<B>):Future<Either<A, B>>
    return a.map(Either.Left).first(b.map(Either.Right));

  /**
   *  Uses `Pair` to merge two futures
   */
  @:noCompletion @:op(a && b) static public function and<A, B>(a:Future<A>, b:Future<B>):Future<Pair<A, B>>
    return a.merge(b, function (a, b) return new Pair(a, b));

  @:deprecated('>> for futures is deprecated') @:noCompletion @:op(a >> b) static public function _tryFailingFlatMap<D, F, R>(f:Surprise<D, F>, map:D->Surprise<R, F>)
    return f.flatMap(function (o) return switch o {
      case Success(d): map(d);
      case Failure(f): Future.sync(Failure(f));
    });

  @:deprecated('>> for futures is deprecated') @:noCompletion @:op(a >> b) static public function _tryFlatMap<D, F, R>(f:Surprise<D, F>, map:D->Future<R>):Surprise<R, F>
    return f.flatMap(function (o) return switch o {
      case Success(d): map(d).map(Success);
      case Failure(f): Future.sync(Failure(f));
    });

  @:deprecated('>> for futures is deprecated') @:noCompletion @:op(a >> b) static public function _tryFailingMap<D, F, R>(f:Surprise<D, F>, map:D->Outcome<R, F>)
    return f.map(function (o) return o.flatMap(map));

  @:deprecated('>> for futures is deprecated') @:noCompletion @:op(a >> b) static public function _tryMap<D, F, R>(f:Surprise<D, F>, map:D->R)
    return f.map(function (o) return o.map(map));

  @:deprecated('>> for futures is deprecated') @:noCompletion @:op(a >> b) static public function _flatMap<T, R>(f:Future<T>, map:T->Future<R>)
    return f.flatMap(map);

  @:deprecated('>> for futures is deprecated') @:noCompletion @:op(a >> b) static public function _map<T, R>(f:Future<T>, map:T->R)
    return f.map(map);

  /**
   *  Creates a new `FutureTrigger`
   */
  @:noUsing static public inline function trigger<A>():FutureTrigger<A>
    return new FutureTrigger();

  @:noUsing static public function delay<T>(ms:Int, value:Lazy<T>):Future<T>
    return Future.async(function(cb) haxe.Timer.delay(function() cb(value.get()), ms));

}

enum FutureStatus<T> {
  Suspended;
  Awaited;
  EagerlyAwaited;
  Ready(result:Lazy<T>);
  NeverEver;
}

private interface FutureObject<T> {

  function getStatus():FutureStatus<T>;
  /**
   *  Registers a callback to handle the future result.
   *  If the result is already available, the callback will be invoked immediately.
   *  @return A `CallbackLink` instance that can be used to cancel the callback, no effect if the callback is already invoked
   */
  function handle(callback:Callback<T>):CallbackLink;
  /**
   *  Makes this future eager.
   *  Futures are lazy by default, i.e. it does not try to fetch the result until someone `handle` it
   */
  function eager():Future<T>;
}

private class NeverFuture<T> implements FutureObject<T> {
  public static var inst(default, null):NeverFuture<Dynamic> = new NeverFuture();
  function new() {}
  public function getStatus():FutureStatus<T>
    return NeverEver;
  public function handle(callback:Callback<T>):CallbackLink return null;
  public function eager():Future<T> return cast inst;
}

private class SyncFuture<T> implements FutureObject<T> {//TODO: there should be a way to get rid of this

  var value:Lazy<T>;

  public function getStatus()
    return Ready(value);

  public inline function new(value)
    this.value = value;

  public function handle(cb:Callback<T>):CallbackLink {
    cb.invoke(value);
    return null;
  }

  public function eager() {
    if (!value.computed)
      value.get();
    return this;
  }
}

class FutureTrigger<T> implements FutureObject<T> {
  var status:FutureStatus<T> = Awaited;
  final list:CallbackList<T>;

  public function new()
    this.list = new CallbackList(true);

  public function getStatus()
    return status;

  public function handle(callback:Callback<T>):CallbackLink
    return switch status {
      case Ready(result):
        callback.invoke(result);
        null;
      case v:
        list.add(callback);
    }

  public function eager()
    return this;

  public inline function asFuture():Future<T>
    return this;

  /**
   *  Triggers a value for this future
   */
  public function trigger(result:T):Bool
    return switch status {
      case Ready(_): false;
      default:
        status = Ready(result);
        list.invoke(result);
        true;
    }
}

typedef Surprise<D, F> = Future<Outcome<D, F>>;

#if js
class JsPromiseTools {
  static inline public function toSurprise<A>(promise:JsPromise<A>):Surprise<A, Error>
    return Future.ofJsPromise(promise);
  static inline public function toPromise<A>(promise:JsPromise<A>):Promise<A>
    return Future.ofJsPromise(promise);
}
#end

private class SuspendableFuture<T> implements FutureObject<T> {//TODO: this has quite a bit of duplication with FutureTrigger
  final callbacks:CallbackList<T>;
  var status:FutureStatus<T> = Suspended;
  var link:CallbackLink;
  var wakeup:(T->Void)->CallbackLink;

  public function getStatus()
    return this.status;

  public function new(wakeup) {
    this.wakeup = wakeup;
    this.callbacks = new CallbackList(true);

    callbacks.ondrain = function () if (status.match(Awaited)) {
      status = Suspended;
      link.cancel();
      link = null;
    }
  }

  function trigger(value:T)
    switch status {
      case Ready(_):
      default:
        status = Ready(value);
        link = null;
        wakeup = null;
        callbacks.invoke(value);
    }

  public function handle(callback:Callback<T>):CallbackLink
    return switch status {
      case Ready(result):
        callback.invoke(result);
        null;
      case Suspended:
        var ret = callbacks.add(callback);
        status = Awaited;
        arm();
        ret;
      default:
        callbacks.add(callback);
    }

  function arm()
    link = wakeup(trigger);

  public inline function eager():Future<T> {
    switch status {
      case Suspended:
        status = EagerlyAwaited;
        arm();
      case Awaited:
        status = EagerlyAwaited;
      default:
    }
    return this;
  }

}
package tink.core;

import tink.core.Disposable;
import tink.core.Callback;
import tink.core.Noise;

@:noCompletion
abstract Gather(Bool) {
  inline function new(v) this = v;
  @:deprecated('Gathering no longer has any effect')
  @:from static function ofBool(b:Bool)
    return new Gather(b);
}

@:forward
abstract Signal<T>(SignalObject<T>) from SignalObject<T> {

  public inline function new(f:(T->Void)->CallbackLink, ?init:OwnedDisposable->Void)
    this = new Suspendable<T>(fire -> f(fire), init);

  public inline function handle(handler:Callback<T>):CallbackLink
    return this.listen(handler);

  /**
   *  Creates a new signal by applying a transform function to the result.
   *  Different from `flatMap`, the transform function of `map` returns a sync value
   */
  public function map<A>(f:T->A, ?gather:Gather):Signal<A>
    return Suspendable.over(this, fire -> handle(v -> fire(f(v))));

  /**
   *  Creates a new signal by applying a transform function to the result.
   *  Different from `map`, the transform function of `flatMap` returns a `Future`
   */
  @:deprecated public function flatMap<A>(f:T->Future<A>, ?gather:Gather):Signal<A>
    return Suspendable.over(this, fire -> handle(v -> f(v).handle(fire)));

  /**
   *  Creates a new signal whose values will only be emitted when the filter function evalutes to `true`
   */
  public function filter(f:T->Bool, ?gather:Gather):Signal<T>
    return Suspendable.over(this, fire -> handle(v -> if (f(v)) fire(v)));

  public function select<R>(selector:T->Option<R>, ?gather:Gather):Signal<R>
    return Suspendable.over(this, fire -> handle(v -> switch selector(v) {
      case Some(v): fire(v);
      default:
    }));

  /**
   *  Creates a new signal by joining `this` and `that`,
   *  the new signal will be triggered whenever either of the two triggers
   */
  public function join(that:Signal<T>, ?gather:Gather):Signal<T>
    return
      if (this.disposed) that;
      else if (that.disposed) this;
      else new Suspendable<T>(
        fire -> {
          var cb:Callback<T> = fire;
          handle(cb) & that.handle(cb);
        },
        self -> {
          function release()
            if (this.disposed && that.disposed) self.dispose();
          this.ondispose(release);
          that.ondispose(release);
        }
      );

  /**
   *  Gets the next emitted value as a Future
   */
  public function nextTime(?condition:T->Bool):Future<T>
    return pickNext(v -> if (condition == null || condition(v)) Some(v) else None);

  /**
   * Creates a future that yields the next value matched by the provided selector.
   */
   public function pickNext<R>(selector:T->Option<R>):Future<R> {
    var ret = Future.trigger(),
        link:CallbackLink = null;

    link = this.listen(v -> switch selector(v) {
      case None:
      case Some(v):
        ret.trigger(v);
    });

    ret.handle(link);

    return ret.asFuture();
  }

  public function until<X>(end:Future<X>):Signal<T>
    return new Suspendable(
      yield -> this.listen(yield),
      self -> end.handle(self.dispose)
    );

  @:deprecated("use nextTime instead")
  public inline function next(?condition:T->Bool):Future<T>
    return nextTime(condition);

  /**
   *  Transforms this signal and makes it emit `Noise`
   */
  public function noise():Signal<Noise>
    return map(function (_) return Noise);

  /**
   *  Creates a new signal which stores the result internally.
   *  Useful for tranformed signals, such as product of `map` and `flatMap`,
   *  so that the transformation function will not be invoked for every callback
   */
  @:deprecated('Gathering no longer has any effect')
  public function gather():Signal<T>
    return this;

  static public function generate<T>(generator:(T->Void)->Void):Signal<T> {
    var ret = trigger();//TODO: consider implementing this over `create`
    generator(ret.trigger);
    return ret;
  }

  /**
   *  Creates a new `SignalTrigger`
   */
  static public function trigger<T>():SignalTrigger<T>
    return new SignalTrigger();

  // @:deprecate('use new Signal() instead')
  // static public inline function create<T>(create:(T->Void)->(Void->Void), ?init):Signal<T>
  //   return new Suspendable<T>(fire -> create(fire), init);

  /**
   *  Creates a `Signal` from classic signals that has the semantics of `addListener` and `removeListener`
   *  Example: `var signal = Signal.ofClassical(emitter.addListener.bind(eventType), emitter.removeListener.bind(eventType));`
   */
  static public function ofClassical<A>(add:(A->Void)->Void, remove:(A->Void)->Void, ?gather:Gather)
    return new Suspendable<A>(function (fire) {
      add(fire);
      return remove.bind(fire);
    });
}

private class Disposed implements SignalObject<Dynamic> {

  public var disposed(get, never):Bool;
    inline function get_disposed()
      return true;

  function new() {}

  static public var INST(default, null):Signal<Dynamic> = new Disposed();

  public function dispose() {}
  public function ondispose(handler)
    handler();//TODO: consider using Callback.defer

  public inline function listen(cb:Callback<Dynamic>):CallbackLink
    return null;
}

private class Check<T> implements LinkObject {
  final target:Suspendable<T>;

  public function new(target)
    this.target = target;

  public function cancel()
    @:privateAccess if (target.trigger.getLength() == 0) {
      target.subscription.cancel();
    }
}

private class Suspendable<T> implements SignalObject<T> implements OwnedDisposable {

  final trigger = new SignalTrigger<T>();
  final activate:(fire:T->Void)->CallbackLink;
  final check:CallbackLink;

  var init:Null<OwnedDisposable->Void>;
  var subscription:CallbackLink;

  @:deprecated
  public var killed(get, never):Bool;
    inline function get_killed() return disposed;

  public var disposed(get, never):Bool;
    inline function get_disposed() return trigger.disposed;

  public function dispose() {
    trigger.dispose();
    subscription.cancel();
  }

  @:deprecated('use dispose() instead')
  public inline function kill()
    dispose();

  public inline function ondispose(handler)
    trigger.ondispose(handler);

  public function new(activate, ?init) {
    this.activate = activate;
    this.init = init;
    this.check = new Check(this);
  }

	public function listen(cb) {
    if (disposed) return null;

    var ret = trigger.listen(cb) & check;

    if (trigger.getLength() == 1) {
      switch init {
        case null:
        case f: init = null; f(this);
      }
      this.subscription = activate(trigger.trigger);
    }

    return ret;
  }

  static public function over<In, Out>(s:Signal<In>, activate):Signal<Out>
    return
      if (s.disposed) return cast Disposed.INST;
      else {
        var ret = new Suspendable<Out>(activate);
        s.ondispose(ret.dispose);
        return ret;
      }
}

final class SignalTrigger<T> implements SignalObject<T> implements OwnedDisposable {
  public var disposed(get, never):Bool;
    inline function get_disposed()
      return handlers.disposed;

  var handlers = new CallbackList<T>();

  public inline function new() {}

  public function dispose()
    handlers.dispose();

  public function ondispose(d)
    handlers.ondispose(d);

  /**
   *  Emits a value for this signal
   */
  public inline function trigger(event:T)
    handlers.invoke(event);

  /**
   *  Gets the number of handlers registered
   */
  public inline function getLength()
    return handlers.length;

	public inline function listen(cb)
    return handlers.add(cb);

  /**
   *  Clear all handlers
   */
  public inline function clear()
    handlers.clear();

  @:to public inline function asSignal():Signal<T>
    return this;
}

private interface SignalObject<T> extends Disposable {
  /**
   *  Registers a callback to be invoked every time the signal is triggered
   *  @return A `CallbackLink` instance that can be used to unregister the callback
   */
  function listen(handler:Callback<T>):CallbackLink;
}
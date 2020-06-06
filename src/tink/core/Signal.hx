package tink.core;

import tink.core.Disposable;
import tink.core.Callback;
import tink.core.Noise;

@:forward(disposed, ondispose)
abstract Signal<T>(SignalObject<T>) from SignalObject<T> {

  @:deprecated public inline function new(f:Callback<T>->CallbackLink) this = new SimpleSignal(f);

  public inline function handle(handler:Callback<T>):CallbackLink
    return this.listen(handler);

  /**
   *  Creates a new signal by applying a transform function to the result.
   *  Different from `flatMap`, the transform function of `map` returns a sync value
   */
  public function map<A>(f:T->A, ?gather = true):Signal<A>
    return Suspendable.over(this, function (fire, _, _) return handle(function (v) fire(f(v))));

  /**
   *  Creates a new signal by applying a transform function to the result.
   *  Different from `map`, the transform function of `flatMap` returns a `Future`
   */
  @:deprecated public function flatMap<A>(f:T->Future<A>, ?gather = true):Signal<A>
    return Suspendable.over(this, function (fire, _, _) return handle(function (v) f(v).handle(fire)));

  /**
   *  Creates a new signal whose values will only be emitted when the filter function evalutes to `true`
   */
  public function filter(f:T->Bool, ?gather = true):Signal<T>
    return Suspendable.over(this, function (fire, _, _) return handle(function (v) if (f(v)) fire(v)));

  public function select<R>(selector:T->Option<R>, ?gather = true):Signal<R>
    return Suspendable.over(this, function (fire, _, _) return handle(function (v) switch selector(v) {
      case Some(v): fire(v);
      default:
    }));

  /**
   *  Creates a new signal by joining `this` and `that`,
   *  the new signal will be triggered whenever either of the two triggers
   */
  public function join(that:Signal<T>, ?gather = true):Signal<T>
    return
      if (this.disposed) that;
      else if (that.disposed) this;
      else new Suspendable<T>(function (fire, first, self) {
        var cb:Callback<T> = fire;
        if (first) {
          function release()
            if (this.disposed && that.disposed) self.dispose();
          this.ondispose(release);
          that.ondispose(release);
        }
        return handle(cb) & that.handle(cb);
      });

  /**
   *  Gets the next emitted value as a Future
   */
  public function nextTime(?condition:T->Bool):Future<T> {
    var ret = Future.trigger();
    var link:CallbackLink = null;

    link = this.listen(function (v) if (condition == null || condition(v)) {
      ret.trigger(v);
      link.cancel();
    });

    return ret.asFuture();
  }

  public function until<X>(end:Future<X>):Signal<T>
    return new Suspendable(
      function (yield, first, self) {
        if (first)
          end.handle(self.dispose);
        return this.listen(yield);
      }
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
  @:deprecated public function gather():Signal<T> {
    var ret = trigger();
    this.listen(function (x) ret.trigger(x));
    return ret.asSignal();
  }

  static public function generate<T>(generator:(T->Void)->Void):Signal<T> {
    var ret = trigger();
    generator(ret.trigger);
    return ret;
  }

  /**
   *  Creates a new `SignalTrigger`
   */
  static public function trigger<T>():SignalTrigger<T>
    return new SignalTrigger();

  static public inline function create<T>(create:(T->Void)->(Void->Void)):Signal<T>
    return new Suspendable<T>(function (fire, first, self) return create(fire));

  /**
   *  Creates a `Signal` from classic signals that has the semantics of `addListener` and `removeListener`
   *  Example: `var signal = Signal.ofClassical(emitter.addListener.bind(eventType), emitter.removeListener.bind(eventType));`
   */
  static public function ofClassical<A>(add:(A->Void)->Void, remove:(A->Void)->Void, ?gather = true) {
    var ret = new Signal(function (cb:Callback<A>) {
      var f = function (a) cb.invoke(a);
      add(f);
      return remove.bind(f);
    });

    return
      if (gather) ret.gather();
      else ret;
  }
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

private class SimpleSignal<T> implements SignalObject<T> {
  var f:Callback<T>->CallbackLink;
  public var disposed(get, never):Bool;
    inline function get_disposed() return false;

  public function dispose() {}
  public function ondispose(handler) {}
  public inline function new(f) this.f = f;
  public inline function listen(cb) return this.f(cb);
}

private class Suspendable<T> implements SignalObject<T> {
  var trigger:SignalTrigger<T> = new SignalTrigger();
  var activate:(T->Void)->Bool->Suspendable<T>->(Void->Void);
  var suspend:Void->Void;
  var first = true;

  @:deprecated
  public var killed(get, never):Bool;
    inline function get_killed() return disposed;

  public var disposed(get, never):Bool;
    inline function get_disposed() return trigger.disposed;

  public function dispose() {
    trigger.dispose();
    switch suspend {
      case null:
      case fn:
        suspend = null;
        fn();
    }
  }

  @:deprecated
  public inline function kill()
    dispose();

  public inline function ondispose(handler)
    trigger.ondispose(handler);

  public function new(activate)
    this.activate = activate;

	public function listen(cb) {
    if (disposed) return null;

    if (trigger.getLength() == 0)
      this.suspend = activate(trigger.trigger, first && !(first = false), this);

    if (disposed) return null;

    return
      trigger.listen(cb)
      & function ()
          if (trigger.getLength() == 0) {
            suspend();
            suspend = null;
          }
  }

  static public function over<In, Out>(s:Signal<In>, activate:(Out->Void)->Bool->Suspendable<Out>->(Void->Void)):Signal<Out>
    return
      if (s.disposed) return cast Disposed.INST;
      else {
        var ret = new Suspendable<Out>(activate);
        s.ondispose(ret.dispose);
        return ret;
      }
}

class SignalTrigger<T> implements SignalObject<T> implements OwnedDisposable {
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

interface SignalObject<T> extends Disposable {
  /**
   *  Registers a callback to be invoked every time the signal is triggered
   *  @return A `CallbackLink` instance that can be used to unregister the callback
   */
  function listen(handler:Callback<T>):CallbackLink;
}
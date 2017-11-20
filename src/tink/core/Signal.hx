package tink.core;

import tink.core.Callback;
import tink.core.Noise;

@:forward
abstract Signal<T>(SignalObject<T>) from SignalObject<T> to SignalObject<T> {
  
  public inline function new(f:Callback<T>->CallbackLink) this = new SimpleSignal(f);
  
  /**
   *  Creates a new signal by applying a transform function to the result.
   *  Different from `flatMap`, the transform function of `map` returns a sync value
   */
  public function map<A>(f:T->A, ?gather = true):Signal<A> {
    var ret = new Signal(function (cb) return this.handle(function (result) cb.invoke(f(result))));
    return
      if (gather) ret.gather();
      else ret;
  }
  
  /**
   *  Creates a new signal by applying a transform function to the result.
   *  Different from `map`, the transform function of `flatMap` returns a `Future`
   */
  public function flatMap<A>(f:T->Future<A>, ?gather = true):Signal<A> {
    var ret = new Signal(function (cb) return this.handle(function (result) f(result).handle(cb)));
    return 
      if (gather) ret.gather() 
      else ret;
  }
  
  /**
   *  Creates a new signal whose values will only be emitted when the filter function evalutes to `true`
   */
  public function filter(f:T->Bool, ?gather = true):Signal<T> {
    var ret = new Signal(function (cb) return this.handle(function (result) if (f(result)) cb.invoke(result)));
    return
      if (gather) ret.gather();
      else ret;
  }
  
  /**
   *  Creates a new signal by joining `this` and `other`,
   *  the new signal will be triggered whenever either of the two triggers
   */
  public function join(other:Signal<T>, ?gather = true):Signal<T> {
    var ret = new Signal(
      function (cb:Callback<T>):CallbackLink 
        return this.handle(cb) & other.handle(cb)
    );
    return
      if (gather) ret.gather();
      else ret;
  }
  
  /**
   *  Gets the next emitted value as a Future
   */
  public function next(?condition:T->Bool):Future<T> {
    var ret = Future.trigger();
    var link:CallbackLink = null,
        immediate = false;
        
    link = this.handle(function (v) if (condition == null || condition(v)) {
      ret.trigger(v);
      if (link == null) immediate = true;
      else link.dissolve();
    });
    
    if (immediate) 
      link.dissolve();
    
    return ret.asFuture();
  }
  
  /**
   *  Transfroms this signal and makes it emit `Noise`
   */
  public function noise():Signal<Noise>
    return map(function (_) return Noise);
  
  /**
   *  Creates a new signal which stores the result internally.
   *  Useful for tranformed futures, such as product of `map` and `flatMap`,
   *  so that the transformation function will not be invoked for every callback
   */
  public function gather():Signal<T> {
    var ret = trigger();
    this.handle(function (x) ret.trigger(x));
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

private class SimpleSignal<T> implements SignalObject<T> {
  var f:Callback<T>->CallbackLink;
  public inline function new(f) this.f = f;
  public inline function handle(cb) return this.f(cb);
}

class SignalTrigger<T> implements SignalObject<T> {
  var handlers = new CallbackList<T>();
  public inline function new() {} 
    
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

  public inline function handle(cb) 
    return handlers.add(cb);

  /**
   *  Clear all handlers
   */
  public inline function clear()
    handlers.clear();
    
  @:to public inline function asSignal():Signal<T> 
    return this;
}

interface SignalObject<T> {
  /**
   *  Registers a callback to be invoked every time the signal is triggered
   *  @return A `CallbackLink` instance that can be used to unregister the callback
   */
  function handle(handler:Callback<T>):CallbackLink;
}

package tink.core;

import tink.core.Callback;
import tink.core.Noise;

abstract Signal<T>(SignalObject<T>) from SignalObject<T> to SignalObject<T> {
  
  public inline function new(f:Callback<T>->CallbackLink) this = new SimpleSignal(f);
  
  public inline function handle(handler:Callback<T>):CallbackLink 
    return this.handle(handler);
  
  public function map<A>(f:T->A, ?gather = true):Signal<A> {
    var ret = new Signal(function (cb) return handle(function (result) cb.invoke(f(result))));
    return
      if (gather) ret.gather();
      else ret;
  }
  
  public function flatMap<A>(f:T->Future<A>, ?gather = true):Signal<A> {
    var ret = new Signal(function (cb) return handle(function (result) f(result).handle(cb)));
    return 
      if (gather) ret.gather() 
      else ret;
  }
  
  public function filter(f:T->Bool, ?gather = true):Signal<T> {
    var ret = new Signal(function (cb) return handle(function (result) if (f(result)) cb.invoke(result)));
    return
      if (gather) ret.gather();
      else ret;
  }
  
  public function join(other:Signal<T>, ?gather = true):Signal<T> {
    var ret = new Signal(
      function (cb:Callback<T>):CallbackLink 
        return handle(cb) & other.handle(cb)
    );
    return
      if (gather) ret.gather();
      else ret;
  }
  
  public function next():Future<T> {
    var ret = Future.trigger();
    var link:CallbackLink = null,
        immediate = false;
        
    link = handle(function (v) {
      ret.trigger(v);
      if (link == null) immediate = true;
      else link.dissolve();
    });
    
    if (immediate) 
      link.dissolve();
    
    return ret.asFuture();
  }
  
  public function noise():Signal<Noise>
    return map(function (_) return Noise);
  
  public function gather():Signal<T> {
    var ret = trigger();
    handle(function (x) ret.trigger(x));
    return ret.asSignal();
  }
  
  static public function trigger<T>():SignalTrigger<T>
    return new SignalTrigger();
    
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
    
  public inline function trigger(event:T)
    handlers.invoke(event);
    
  public inline function getLength()
    return handlers.length;

  public inline function handle(cb) 
    return handlers.add(cb);

  public inline function clear()
    handlers.clear();
    
  @:to public inline function asSignal():Signal<T> 
    return this;
}

interface SignalObject<T> {
  function handle(handler:Callback<T>):CallbackLink;
}
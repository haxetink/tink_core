package tink.core;

import tink.core.Disposable;

abstract Callback<T>(T->Void) from (T->Void) {

  inline function new(f)
    this = f;

  @:to inline function toFunction()
    return this;

  static var depth = 0;
  static inline final MAX_DEPTH = #if (eval || python || interp) 100 #else 500 #end;

  // When the guarded call stack is exhausted, continuations are parked here and
  // run once it unwinds. See `Callbacks::testOverflowOrder` for the ordering guarantees.
  static var overflow:Array<()->Void> = [];
  static var draining = false;

  static function drainOverflow()
    if (!draining) {
      draining = true;
      while (overflow.length > 0) {
        final batch = overflow;
        overflow = [];
        for (fn in batch)
          guardStackoverflow(fn);
      }
      draining = false;
    }

  // Note: behavior is unspecified if `fn` throws,
  // pending https://github.com/haxetink/tink_core/issues/165
  extern static public inline function guardStackoverflow(fn:()->Void):Void
    if (overflow.length == 0 && depth < MAX_DEPTH) {
      depth++;
      fn();
      depth--;
      if (depth == 0)
        drainOverflow();
    }
    else overflow.push(fn);

  public function invoke(data:T):Void
    guardStackoverflow(() -> this(data));

  @:from static inline function fromNiladic<A>(f:()->Void):Callback<A>
    return #if js cast f #else _ -> f() #end;

  @:from static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A>
    return
      (v:A) -> {
        for (callback in callbacks)
          callback.invoke(v);
      };

  @:from static inline function fromSignalTrigger<A>(trigger:tink.core.Signal.SignalTrigger<A>):Callback<A>
    return v -> trigger.trigger(v);

  @:from static inline function fromFutureTrigger<A>(trigger:tink.core.Future.FutureTrigger<A>):Callback<A>
    return v -> trigger.trigger(v);

  @:noUsing static public function defer(f:()->Void) {
    #if macro
      f();
    #elseif tink_runloop
      tink.RunLoop.current.work(f);
    #elseif hxnodejs
      js.Node.setImmediate(f);
    #elseif luxe
      Luxe.timer.schedule(0, f);
    #elseif snow
      snow.api.Timer.delay(0, f);
    #elseif java
      haxe.Timer.delay(f, 1);//TODO: find something that leverages the platform better
    #else
      haxe.Timer.delay(f, 0);
    #end
  }
}

interface LinkObject {
  function cancel():Void;
}

class CallbackLinkRef implements LinkObject {
  public var link(default, set):CallbackLink;
    inline function set_link(param) {
      link.cancel();
      return link = param;
    }
  public function new() {}
  public function cancel()
    link.cancel();
}

abstract CallbackLink(LinkObject) from LinkObject {

  inline function new(link:()->Void)
    this = new SimpleLink(link);

  public inline function cancel():Void
    if (this != null) this.cancel();

  @:deprecated('Use cancel() instead')
  public inline function dissolve():Void
    cancel();

  static function noop() {}

  @:to inline function toFunction():()->Void
    return if (this == null) noop else this.cancel;

  @:to inline function toCallback<A>():Callback<A>
    return if (this == null) noop else this.cancel;

  @:from static inline function fromFunction(f:()->Void)
    return new CallbackLink(f);

  @:op(a & b) public inline function join(b:CallbackLink):CallbackLink
    return new LinkPair(this, b);

  @:from static public function fromMany(callbacks:Array<CallbackLink>)
    return fromFunction(() -> {
      if (callbacks != null)
        for (cb in callbacks) cb.cancel();
      else
        callbacks = null;
    });
}

class SimpleLink implements LinkObject {
  var f:()->Void;

  public inline function new(f)
    this.f = f;

  public inline function cancel()
    if (f != null) {
      f();
      f = null;
    }
}

private class LinkPair implements LinkObject {

  var a:CallbackLink;
  var b:CallbackLink;
  var dissolved:Bool = false;
  public function new(a, b) {
    this.a = a;
    this.b = b;
  }

  public function cancel()
    if (!dissolved) {
      dissolved = true;
      a.cancel();
      b.cancel();
      a = null;
      b = null;
    }
}

private class ListCell<T> implements LinkObject {

  public var cb:T->Void;
  public var list:CallbackList<T>;
  public function new(cb, list) {
    if (cb == null) throw 'callback expected but null received';
    this.cb = cb;
    this.list = list;
  }

  public inline function invoke(data)
    if (list != null) cb(data);

  public inline function clear() {
    cb = null;
    list = null;
  }

  public inline function cancel()
    if (list != null) {
      final list = this.list;
      clear();
      @:privateAccess list.release();
    }
}

class CallbackList<T> extends SimpleDisposable {

  final destructive:Bool;
  var cells:Array<ListCell<T>>;

  public var length(get, never):Int;
    inline function get_length():Int
      return used;

  var used:Int = 0;
  var queue = [];

  public var busy(default, null):Bool = false;

  public function new(destructive = false) {
    super(() -> if (!busy) destroy());
    this.destructive = destructive;
    this.cells = [];
  }

  public var ondrain:()->Void = () -> {}
  public var onfill:()->Void = () -> {}

  inline function release()
    if (--used <= cells.length >> 1)
      compact();

  function destroy() {
    for (c in cells)
      c.clear();

    final queue = this.queue;
    this.queue = null;
    cells = null;

    if (used > 0) {
      used = 0;
      drain();
    }

    // queued invocations no longer deliver anything, but their `after` must still run
    for (f in queue)
      f();
  }

  inline function drain()
    Callback.guardStackoverflow(ondrain);

  public inline function add(cb:Callback<T>):CallbackLink {
    if (disposed) return null;
    final node = new ListCell(cb, this);//perhaps adding during and after destructive invokations should be disallowed altogether
    cells.push(node);
    if (used++ == 0) Callback.guardStackoverflow(onfill);
    return node;
  }

  /**
   * Invokes all callbacks with `data`. Delivery is not guaranteed to be synchronous, because
   * it is deferred when the call stack gets too deep, or when invoked while already invoking.
   * The optional `after` is called once all callbacks have been invoked, including whatever
   * they in turn deferred.
   */
  public function invoke(data:T, ?after:()->Void)
    Callback.guardStackoverflow(() -> {
      if (disposed) {}
      else if (busy) {
        if (destructive != true) {
          queue.push(invoke.bind(data, after));
          return;
        }
      }
      else {
        busy = true;

        if (destructive)
          dispose();

        final length = cells.length;
        for (i in 0...length)
          cells[i].invoke(data);

        busy = false;

        if (disposed)
          destroy();
        else {
          if (used < cells.length)
            compact();

          if (queue.length > 0)
            queue.shift()();
        }
      }
      if (after != null)
        Callback.guardStackoverflow(after);
    });

  function compact()
    if (busy) return;
    else if (used == 0) {
      resize(0);
      drain();
    }
    else {
      var compacted = 0;

      for (i in 0...cells.length)
        switch cells[i] {
          case { cb: null }:
          case v:
            if (compacted != i)
              cells[compacted] = v;
            if (++compacted == used) break;
        }

      resize(used);
    }

  function resize(length)
    cells.resize(length);

  //TODO: probably want to make this private
  public function clear():Void {
    if (disposed) return;
    if (busy)
      queue.push(clear);
    for (cell in cells)
      cell.clear();
    resize(0);
  }

}

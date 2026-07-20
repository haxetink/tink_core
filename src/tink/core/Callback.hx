package tink.core;

import tink.core.Disposable;

abstract Callback<T>(T->Void) from (T->Void) {

  inline function new(f)
    this = f;

  @:to inline function toFunction()
    return this;

  static var depth = 0;
  static inline final MAX_DEPTH = #if (eval || python || interp) 100 #else 500 #end;

  // When the guarded call stack is exhausted, continuations are parked here
  // and executed when the stack unwinds, so that synchronous delivery chains
  // are never split across macro-tasks (splitting them loses signal events
  // fired in between, see SignalStream). Two invariants keep delivery order
  // identical to fully synchronous execution:
  //   1. once anything is parked, all subsequent guarded calls park behind it
  //      (nothing may overtake a parked continuation), and
  //   2. continuations parked while a drained item runs are processed before
  //      the remainder of the queue (depth-first order).
  static var overflow:Array<()->Void> = [];
  static var draining = false;

  static function drainOverflow()
    if (!draining) {
      draining = true;
      while (overflow.length > 0) {
        final fn = overflow.shift();
        final rest = overflow;
        // give the item a clean queue so its own nested guarded
        // calls run synchronously until it hits the wall itself
        overflow = [];
        guardStackoverflow(fn);
        overflow = overflow.concat(rest);
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
    if (list != null)
      cb(data);

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

    queue = null;
    cells = null;

    if (used > 0) {
      used = 0;
      drain();
    }
  }

  // onfill/ondrain are state synchronization hooks and must run synchronously:
  // deferring them under guardStackoverflow leaves observers with stale state
  // (e.g. a Suspendable signal that is not activated when `handle` returns).
  // Recursion-prone implementations (see SuspendableFuture) guard themselves.
  inline function drain()
    ondrain();

  public inline function add(cb:Callback<T>):CallbackLink {
    if (disposed) return null;
    final node = new ListCell(cb, this);//perhaps adding during and after destructive invokations should be disallowed altogether
    cells.push(node);
    if (used++ == 0) onfill();
    return node;
  }

  public function invoke(data:T)
    Callback.guardStackoverflow(() -> {
      if (disposed) {}
      else if (busy) {
        if (destructive != true)
          queue.push(invoke.bind(data));
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
          destroy();//TODO: perhaps something should be done with non empty queue
        else {
          if (used < cells.length)
            compact();

          if (queue.length > 0)
            queue.shift()();
        }
      }
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
    if (busy)
      queue.push(clear);
    for (cell in cells)
      cell.clear();
    resize(0);
  }

}

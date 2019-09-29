package tink.core;

abstract Callback<T>(T->Void) from (T->Void) {
  
  inline function new(f) 
    this = f;
  
  @:to inline function toFunction()
    return this;
    
  static var depth = 0;
  static inline var MAX_DEPTH = #if (python || eval) 200 #elseif interp 100 #else 500 #end;
  public function invoke(data:T):Void
    if (depth < MAX_DEPTH) {
      depth++;
      (this)(data); //TODO: consider handling exceptions here (per opt-in?) to avoid a failing callback from taking down the whole app
      depth--;
    }
    else Callback.defer(invoke.bind(data));
  
  // This seems useful, but most likely is not. 
  @:deprecated('Implicit cast from Callback<Noise> is deprecated. Please create an issue if you find it useful, and don\'t want this cast removed.')
  @:to static function ignore<T>(cb:Callback<Noise>):Callback<T>
    return function (_) cb.invoke(Noise);
    
  @:from static function fromNiladic<A>(f:Void->Void):Callback<A> //inlining this seems to cause recursive implicit casts
    return #if js cast f #else function (_) f() #end;
  
  @:from static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> 
    return
      function (v:A) 
        for (callback in callbacks)
          callback.invoke(v);
          
  @:noUsing static public function defer(f:Void->Void) {
    #if macro
      f();
    #elseif tink_runloop
      tink.RunLoop.current.work(f);
    #elseif hxnodejs
      js.Node.process.nextTick(f);
    #elseif luxe
      Luxe.timer.schedule(0, f);
    #elseif snow
      snow.api.Timer.delay(0, f);
    #elseif java
      haxe.Timer.delay(f, 1);//TODO: find something that leverages the platform better
    #elseif ((haxe_ver >= 3.3) || js || flash || openfl)
      haxe.Timer.delay(f, 0);
    #else
      f();
    #end
  }
}
interface LinkObject {
  function cancel():Void;
}

abstract CallbackLink(LinkObject) from LinkObject {

  inline function new(link:Void->Void) 
    this = new SimpleLink(link);

  public inline function cancel():Void 
    if (this != null) this.cancel();
  
  //@:deprecated('Use cancel() instead')
  public inline function dissolve():Void 
    cancel();

  static function noop() {}
  
  @:to inline function toFunction():Void->Void
    return if (this == null) noop else this.cancel;
    
  @:to inline function toCallback<A>():Callback<A> 
    return function (_) this.cancel();
    
  @:from static inline function fromFunction(f:Void->Void) 
    return new CallbackLink(f);

  @:op(a & b) static public inline function join(a:CallbackLink, b:CallbackLink):CallbackLink
    return new LinkPair(a, b);
    
  @:from static public function fromMany(callbacks:Array<CallbackLink>)
    return fromFunction(function () { 
      if (callbacks != null) 
        for (cb in callbacks) cb.cancel(); 
      else
        callbacks = null; 
    });
}

class SimpleLink implements LinkObject {
  var f:Void->Void;

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
  
  public var cb:Callback<T>;
  public var list:CallbackList<T>;
  public function new(cb, list) {
    if (cb == null) throw 'callback expected but null received';
    this.cb = cb;
    this.list = list;
  }

  public inline function invoke(data)
    if (list != null) 
      cb.invoke(data);

  public inline function clear() {
    cb = null;
    list = null;
  }

  public inline function cancel() 
    if (list != null) {
      var list = this.list;
      clear();
      @:privateAccess list.release();
    }
}

class CallbackList<T> {
  
  var cells:Array<ListCell<T>>;

  public var length(get, never):Int;
  
  var used:Int = 0;
  var queue = [];

  public var busy(default, null):Bool = false;
  public function new() {
    this.cells = [];
  }
  
  dynamic public function ondrain() {}

  inline function get_length():Int 
    return used;

  inline function release() 
    if (--used < length >> 1)
      compact();  
  
  public inline function add(cb:Callback<T>):CallbackLink {
    var node = new ListCell(cb, this);//perhaps adding during and after destructive invokations should be disallowed altogether
    cells.push(node);
    used++;
    return node;
  }
    
  public function invoke(data:T, ?destructive:Bool) 
    if (busy) 
      queue.push(invoke.bind(data, destructive));//TODO: the wisdom of just queueing destructive invokations is questionable
    else {
      busy = true;
      
      var length = cells.length;
      for (i in 0...length) 
        cells[i].invoke(data);
      
      busy = false;

      if (destructive) {
        var added = cells.length - length;
        for (i in 0...length) 
          cells[i].clear();
        for (i in 0...added)
          cells[i] = cells[length + i];
        resize(added);
      }
      else if (used < cells.length) 
        compact();
      if (queue.length > 0)
        queue.shift()();
    }

  function compact() 
    if (busy) return;
    else if (used == 0) {
      resize(0);
      ondrain();
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
    #if haxe4
      cells.resize(length);
    #else
      cells.splice(0, length);
    #end
      
  //TODO: probably want to make this private      
  public function clear():Void {
    if (busy)
      queue.push(clear);
    for (cell in cells) 
      cell.clear();
    resize(0);
  }

}

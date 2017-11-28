package tink.core;

abstract Callback<T>(T->Void) from (T->Void) {
  
  inline function new(f) 
    this = f;
  
  @:to inline function toFunction()
    return this;
    
  static var depth = 0;
  static inline var MAX_DEPTH = 1000;
  public function invoke(data:T):Void
    if (depth < MAX_DEPTH) {
      depth++;
      (this)(data); //TODO: consider handling exceptions here (per opt-in?) to avoid a failing callback from taking down the whole app
      depth--;
    }
    else Callback.defer(invoke.bind(data));
    
  @:to static function ignore<T>(cb:Callback<Noise>):Callback<T>
    return function () cb.invoke(Noise);
    
  @:from static function fromNiladic<A>(f:Void->Void):Callback<A> //inlining this seems to cause recursive implicit casts
    return new Callback(function (r) f());
  
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
private interface LinkObject {
  function dissolve():Void;
}

abstract CallbackLink(LinkObject) from LinkObject {

  inline function new(link:Void->Void) 
    this = new SimpleLink(link);
    
  public inline function dissolve():Void 
    if (this != null) this.dissolve();
    
  @:to inline function toCallback<A>():Callback<A> 
    return function (_) this.dissolve();
    
  @:from static inline function fromFunction(f:Void->Void) 
    return new CallbackLink(f);

  @:op(a & b) static inline function join(a:CallbackLink, b:CallbackLink):CallbackLink
    return new LinkPair(a, b);
    
  @:from static function fromMany(callbacks:Array<CallbackLink>)
    return fromFunction(function () for (cb in callbacks) cb.dissolve());
}

private class SimpleLink implements LinkObject {
  var f:Void->Void;

  public inline function new(f) 
    this.f = f;

  public inline function dissolve()
    if (f != null) f();
}

private class LinkPair implements LinkObject {
  
  var a:CallbackLink;
  var b:CallbackLink;
  var dissolved:Bool = false;
  public function new(a, b) {
    this.a = a;
    this.b = b;
  }

  public function dissolve() 
    if (!dissolved) {
      dissolved = true;
      a.dissolve();
      b.dissolve();
    }
}

private class ListCell<T> implements LinkObject {
  
  var list:Array<ListCell<T>>;
  var cb:Callback<T>;

  public function new(cb, list) {
    if (cb == null) throw 'callback expected but null received';
    this.cb = cb;
    this.list = list;
  }

  public inline function invoke(data)
    if (cb != null) 
      cb.invoke(data);

  public function clear() {
    list = null;
    cb = null;
  }

  public function dissolve() 
    switch list {
      case null:
      case v: clear(); v.remove(this);
    }
}

abstract CallbackList<T>(Array<ListCell<T>>) {
  
  public var length(get, never):Int;
  
  inline public function new():Void
    this = [];
  
  inline function get_length():Int 
    return this.length;  
  
  public function add(cb:Callback<T>):CallbackLink {
    var node = new ListCell(cb, this);
    this.push(node);
    return node;
  }
    
  public function invoke(data:T) 
    for (cell in this.copy()) 
      cell.invoke(data);
      
  public function clear():Void 
    for (cell in this.splice(0, this.length)) 
      cell.clear();
}

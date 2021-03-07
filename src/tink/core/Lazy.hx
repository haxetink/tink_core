package tink.core;

abstract Lazy<T>(LazyObject<T>) from LazyObject<T> {

  static public final NOISE:Lazy<Noise> = ofConst(null);
  @:deprecated('use Lazy.NOISE instead') static public final NULL = NOISE;

  public var computed(get, never):Bool;
    inline function get_computed()
      return this.isComputed();

  @:to public function get():T {
    this.compute();
    return this.get();
  }

  @:from static inline function fromNoise<T>(l:Lazy<Noise>):Lazy<Null<T>>
    return cast l;

  @:from static public inline function ofFunc<T>(f:()->T):Lazy<T>
    return new LazyFunc(f);

  public inline function map<A>(f:T->A):Lazy<A>
    return new LazyFunc<A>(() -> f(this.get()), this);

  public inline function flatMap<A>(f:T->Lazy<A>):Lazy<A>
    return new LazyFunc<A>(() -> f(this.get()).get(), this);


  @:from @:noUsing static inline function ofConst<T>(c:T):Lazy<T>
    return new LazyConst(c);
}

private interface LazyObject<T> extends Computable {
  function get():T;
}

private interface Computable {
  function isComputed():Bool;
  function compute():Void;
  function underlying():Null<Computable>;
}

private class LazyConst<T> implements LazyObject<T> {

  var value:T;

  public function isComputed():Bool
    return true;

  public inline function new(value)
    this.value = value;

  public inline function get()
    return value;

  public inline function compute() {}

  public function underlying():Computable
    return null;

}

private class LazyFunc<T> implements LazyObject<T> {
  var f:Null<()->T>;
  var from:Computable;
  var result:Null<T>;
  #if debug var busy = false; #end

  public function new(f:()->T, ?from) {
    this.f = f;
    this.from = from;
  }

  public function underlying()
    return from;

  public function isComputed()
    return this.f == null;

  public function get():T
    return result;

  public function compute() {
    #if debug if (busy) throw new Error('circular lazyness');#end
    switch f {
      case null:
      case v:
        #if debug busy = true;#end
        f = null;
        switch this.from {
          case null:
          case cur:
            from = null;
            var stack = [];
            while (cur != null && !cur.isComputed()) {
              stack.push(cur);
              cur = cur.underlying();
            }
            stack.reverse();
            for (c in stack)
              c.compute();

        }

        result = v();
        #if debug busy = false;#end
    }
  }
}
package tink.core;

abstract Lazy<T>(LazyObject<T>) from LazyObject<T> {

  @:to public inline function get():T
    return this.get();

  @:from static public inline function ofFunc<T>(f:Void->T):Lazy<T>
    return new LazyFunc(f);

  public inline function map<A>(f:T->A):Lazy<A>
    return this.map(f);

  public inline function flatMap<A>(f:T->Lazy<A>):Lazy<A>
    return this.flatMap(f);

  @:from @:noUsing static inline function ofConst<T>(c:T):Lazy<T>
    return new LazyConst(c);
}

private interface LazyObject<T> {
  function get():T;
  function map<R>(f:T->R):Lazy<R>;
  function flatMap<R>(f:T->Lazy<R>):Lazy<R>;
}

private class LazyConst<T> implements LazyObject<T> {

  var value:T;

  public inline function new(value)
    this.value = value;

  public inline function get()
    return value;

  public inline function map<R>(f:T->R):Lazy<R>
    return new LazyFunc(function () return f(value));

  public inline function flatMap<R>(f:T->Lazy<R>):Lazy<R>
    return new LazyFunc(function () return f(value).get());
}

private class LazyFunc<T> implements LazyObject<T> {
  var f:Void->T;
  var result:T;
  #if debug var busy = false; #end

  public function new(f) this.f = f;

  public function get() {
    #if debug if (busy) throw new Error('circular lazyness');#end
    if (f != null) {
      #if debug busy = true;#end
      result = f();
      f = null;
      #if debug busy = false;#end
    }
    return result;
  }

  public inline function map<R>(f:T->R):Lazy<R>
    return new LazyFunc(function () return f(get()));

  public inline function flatMap<R>(f:T->Lazy<R>):Lazy<R>
    return new LazyFunc(function () return f(get()).get());
}

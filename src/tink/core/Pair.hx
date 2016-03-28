package tink.core;

abstract Pair<A, B>(MPair<A, B>) {
  
  public var a(get, never):A;
  public var b(get, never):B;
  
  public inline function new(a:A, b:B) this = new MPair(a, b);
  
  inline function get_a():A return this.a;
  inline function get_b():B return this.b;
  
  @:to inline function toBool() 
    return this != null;
    
  @:op(!a) public function isNil() 
    return this == null;
  
  static public function nil<A, B>():Pair<A, B> 
    return null;
}

class MPair<A, B> {
  public var a:A;
  public var b:B;
  public function new(a, b) {
    this.a = a;
    this.b = b;
  }
}
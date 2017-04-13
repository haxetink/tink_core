package tink.core;

import haxe.Constraints;

class Annex<Target> {
  
  var target:Target;
  var registry:Map<Dynamic, Dynamic>;
  
  public function new(target:Target) {
  	this.target = target;
    this.registry = cast new haxe.ds.ObjectMap();
  }
  #if java @:extern #end
  @:generic public inline function get<A:Constructible<Target->Void>>(c:Class<A>):A 
    return switch registry[c] {
      case null: registry[c] = new A(target);
   	  case v: v;
  	}
}
package tink.core;

private typedef AnnexableTo<T> = 
  #if (haxe_ver >= 3.4)
    haxe.Constraints.Constructible<T->Void>
  #else
    { function new(targeT:T):Void; }
  #end

class Annex<Target> {
  
  var target:Target;
  var registry:Map<Dynamic, Dynamic>;
  
  public function new(target:Target) {
  	this.target = target;
    this.registry = cast new haxe.ds.ObjectMap();
  }
  #if (java || cs) @:extern #end
  @:generic public inline function get<A:AnnexableTo<Target>>(c:Class<A>):A 
    return switch registry[c] {
      case null: registry[c] = new A(target);
   	  case v: v;
  	}
}
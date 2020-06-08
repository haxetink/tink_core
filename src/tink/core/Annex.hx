package tink.core;

private typedef AnnexableTo<T> = haxe.Constraints.Constructible<T->Void>

#if (java || cs) @:dce #end // this make sure the generic method is not genrated
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
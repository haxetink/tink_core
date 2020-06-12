package tink.core;

private typedef AnnexableTo<T> = haxe.Constraints.Constructible<T->Void>

#if (java || cs) @:dce #end // this make sure the generic method is not genrated
class Annex<Target> {

  var target:Target;
  var registry:Map<{}, Dynamic>;

  public function new(target:Target) {
  	this.target = target;
    this.registry = cast new haxe.ds.ObjectMap();
  }

  @:generic
  #if (java || cs) extern #end
  public inline function get<A:AnnexableTo<Target>>(c:Class<A>):A {
    var c:{} = cast c;
    return switch registry[c] {
      case null: registry[c] = new A(target);
   	  case v: v;
    }
  }
}
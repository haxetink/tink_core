# Annex

The `Annex` type allows "attaching" objects to a specific target.

```haxe
class Annex<Target> { 
  function new(target:Target);
  function get<A:Constructible<Target->Void>>(c:Class<A>):A;
}
```

Consider the following:

```haxe
class Person {
  
  public var name(default, null):String;
  public var about(default, null):Annex<Person>;

  public function new(name) {
    this.name = name;
    this.about = new Annex(this);
  }

}

class ObservationProtocol {
  public function new(person:Person) {}
}

var johnDoe = new Person("John Doe");
johnDoe.about.get(ObservationProtocol);//gives us the same ...
johnDoe.about.get(ObservationProtocol);//... protocol every time
```

John does not need to know he is being observed in order for him to be observed. It would of course be possible to just create the observation protocol for him without an `Annex` but the protocol obtained through the annex is unique and tied to him. There's no need for maintaining a registry elsewhere, which risks retaining John in memory when he's no longer needed. When John is GCd, so is his annex.

The presents a nice way to implement the open closed principle. Any object that has an annex can have functionality added at runtime, much like in dynamic languages, but without any risk of conflict and with the possibility for hiding the data as well. Consider this:

```haxe
package mi6;

class Agent {}
private class Report {
  public function new(person:Person) {}
}

package kgb;

class Agent {}
private class Report {
  public function new(person:Person) {}
}
```

This way, mi6 agents cannot access kgb reports and vice versa. Not only that: if the reports were not private, they could still coexist without any conflict.

What's nice is that you can use that state with static extensions:

```haxe
class Dispatcher extends openfl.events.EventDispatcher {
  public function new<A>(target:A) super();
}

class PersonEvents {

  static public function on(target:Person, event:String, handler:Dynamic)
    target.about.get(Dispatcher).addEventListener(event, handler);

  static public function fire(target:Person, event:openfl.events.Event)
    target.about.get(Dispatcher).dispatchEvent(event);
}

using PersonEvents;

johnDoe.on("died", function (_) trace("oh no!"));
johnDoe.fire(new openfl.events.Event("died"));//traces "oh no!"
```

Without any modification to `Person`, we can use it as an `EventDispatcher`.
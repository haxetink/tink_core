# Signal

### Quick Example

```haxe
class Player {
  // Expose a signal object to outside 
  public var damaged(default, null):Signal<Int>;
  
  // Keep the trigger private so that only the player itself can trigger it
  var damagedTrigger:SignalTrigger<Int>;
  
  public function new() {
    // Create a trigger which can be later used to invoke the signal
    damagedTrigger = Signal.trigger();
    
    // Create a Signal instance which can be exposed to outside
    damaged = damagedTrigger.asSignal();
  }
  
  public function damage(value:Int) {
    // Invoke a value on the signal
    damagedTrigger.trigger(value);
  }
}

class Main {
  static function main() {
    var player = new Player();
    
    // Register a handler on the signal
    player.damanged.handle(v -> trace('Damaged ${v}HP!');
    
    // ... later at somewhere else ...
    player.damage(100);
  }
}
```


### Interface

Despite an overabundance of signal implementations, `tink_core` does provide its own flavour of signals. One that aims at utmost simplicity and full integration with the rest of tink. Here it is:

```haxe
abstract Signal<T> {
  function new(f:Callback<T>->CallbackLink):Void;

  function handle(calback:Callback<T>):CallbackLink;
  
  function map<A>(f:T->A, ?gather:Bool = true):Signal<A>;
  function join(other:Signal<T>, ?gather:Bool = true):Signal<T>;
  function noise():Signal<Noise>;
  
  function gather():Signal<T>;
  
  function next():Future<T>;  
  
  static function trigger<A>():SignalTrigger<A>;
  static function ofClassical<A>(add:(A->Void)->Void, remove:(A->Void)->Void, ?gather = true):Signal<A>;
}
```

A `Signal` quite simply invokes `Callback`s that are registered using `handle` whenever an event occurs.

There is significant similarity between `Signal` and `Future`. It's best to read up on futures if you haven't done so yet. You may also notice `next`, which at any time will create a future corresponding to the *next* occurence of the signal. So if you only want to do something on the next occurence, you would do `someSignal.next().handle(function (data) {})`.

### Why use signals?

When compared to mechanisms like flash's `EventDispatcher` or the DOM's `EventTarget` or nodejs's `EventEmitter`, the critical advantage is type safety.

Say you have the following class:

```haxe
class Button {
  public var pressed(default, null):Signal<MouseEvent>;
  public var clicked(default, null):Signal<MouseEvent>;
  public var released(default, null):Signal<MouseEvent>;
}
```

You know exactly which events to expect and what type they will have. Also, an interface can define signals that an implementor must thus provide. And lastly, the fact that a signal itself is a value, you can pass it around rather then the whole object owning it. Similarly to futures, this allows for composition.

### Wrapping 3rd party APIs

It is quite easy to take an arbitrary API and wrap it in signals. Let's take the beloved `IEventDispatcher`.

```haxe
function makeSignal<A:Event>(dispatcher:IEventDispatcher, type:String):Signal<A> 
  return Signal.ofClassical(
    dispatcher.addEventListener.bind(type),
    dispatcher.removeEventListener.bind(type)
  );

var keydown:Signal<KeyboardEvent> = makeSignal(stage, 'keydown');//yay!!!
```

As far as just `tink.core.Signal` and interoperability with other APIs is concerned, the primary goal is to make it extremely simple to represent any kind of API with signals. And as shown above, there's really not much to it.

### Rolling your own

As the constructor indicates, a signal can be constructed from any function that consumes a callback and returns a link. Therefore `CallbackList` is pretty much a perfect fit. However, for the sake of consistency with `Future`, the intended usage is to create a `SignalTrigger` that you use internally to - well - trigger the `Signal`.

### No way to dispatch from outside

Unlike many other signal flavors, tink's signals do not allow client code to invoke the signal. When exposing a signal that you trigger yourself, typically you will expose only a `Signal` while internally knowing the `SignalTrigger`.
Here's an example of just that:

```haxe
class Clock {
  public var tick(default, null):Signal<Noise>;
  public function new() {
    var s = Signal.trigger();//<-- this trigger is never passed outside the constructor
    var t = new Timer(1000);
    t.run = function () s.trigger(Noise);
    this.tick = s;
  }
}
```

That being said, if you wish to provide means to dispatch a signal from outside, you can of course do so by exposing this functionality in whatever way you see fit.

### Composing

Now let's have a look at the `map` and `join` and `noise` methods. The `gather` parameter has a very similar role to the counterpart for `Future`. We'll examine that later.

First of all, `map` comes from the functional term of mapping. The idea is to use a function that maps values of one type onto other values (possibly of another type) and give that to a more complex data structure that also deals with values of that type, creating a similar data structure, where the function has been applied to every value. In Haxe `Lambda.map` does this for all iterable data structures. Also `Array` and `List` have built in support for this. So if you want to understand this concept, that's probably the best place to look for an easy example.

Secondly, we have `join` that allows us to join two signals of the same type into one. Here's an example of what that might look like, where we assume that we have a `plusButton` and a `minusButton` on our GUI and they each have a signal called `clicked`:

```haxe
var delta = 
  plusButton.clicked
    .map(function (_) return 1)
    .join(minusButton.clicked.map(function (_) return -1));

$type(delta);//tink.core.Signal<Int>
```

From that we have constructed a new `Signal` that fires `1` when the `plusButton` is clicked and `-1`, when the `minusButton` is clicked. 

This way we can map many input events into a single application event without extraneous noise.

The `noise` method mentioned earlier is merely a shortcut to `map` any `Signal` to a `Signal<Noise>`, thus discarding any information it carries. This is useful when you want to propagate an event but not expose the original data and also have no meaningful substitute.

### Gathering

Similar to `Future`, we have "gathering" for `Signal` as well - for pretty much the same reasons. But it also has another role - normalizing behavior:

As we've seen **any** function that accepts a `Callback` and returns a `CallbackLink` is suitable to act as a `Signal`. But such a `Signal` needn't behave consistently with those built on `CallbackList`, i.e. invokation order might be different or duplicate registration might not be allowed or whatever. Or in some instances, the implementation might be slower or weird in some other way (e.g. [ACE's EventEmitter](https://github.com/ajaxorg/ace/blob/master/lib/ace/lib/event_emitter.js#L39) implementation that has all sorts of unexpected behavior if you add/remove handlers for an event type, while an event of the type is dispatched).

What gathering does for signals is quite easily explained. It creates a new `SignalTrigger` and registers that with the original signal. Then the signal derived from the trigger is returned. Therefore behavioral oddities of the original implementation are hidden.

If we look at `Signal.ofClassical` as used in the example with `IEventDispatcher`, we've used gathering (by default). We could choose not to use it. In that case, the callbacks registration would be delegated to the dispatcher in a relatively direct fashion - with all the advantages and problems this may lead to (usually the problems outweigh any advantages).

## SignalTrigger

A `SignalTrigger` is what permits you to build a signal that you can trigger yourself:

```haxe
abstract SignalTrigger<T> {
  function new();
  function trigger(result:T):Void;
  function clear():Void
  @:to function asSignal():Signal<T>;
}
```

The "clock" example above demonstrates how to do that.


# Callback

To denote callbacks, `tink_core` introduces a special type:

```haxe
abstract Callback<T> from T->Void {
  function invoke(data:T):Void;
  @:from static function fromNiladic<A>(f:Void->Void):Callback<A> 
  @:from static function fromMany<A>(callbacks:Array<Callback<A>>):Callback<A> 
}
```

The obvious question to ask here is why to complicate a simple concept as callbacks when we already have first class functions.

* It brings more clarity to code. Function types use structural subtyping, i.e. the signature alone defines the type. Type matches can thus be unintentional. Also calling something a callback when that's what it really is, carries more meaning.
* The use of abstracts allows for implicit conversions. If you want to subscribe to an event but don't really care for the data, you don't have to define an argument you're not using. You can simply do either of both:
 * `myButton.onClick(function () trace('clicked'));`
 * `myButton.onClick(function (e) trace('clicked at (${e.x}, ${e.y})'));`
* Instead of specifically relying on a function type, we have a separate abstraction, which at some point can be used to leverage platform knowledge to provide for faster code that doesn't have suffer from the performance penalties anonymous function have on most platforms

Beyond that, one might ask what to do if you don't have any data to pass to the callback, or more than a single value. In that case, you could use these respectively:

```haxe
Callback<Noise>
Callback<Pair<A, B>>
Callback<{ a: A, b: B, c: C }>
```

This approach has two advantages:

* For one, it greatly simplifies things. Implementations of signals only ever consume one type of callbacks, so you don't need signals for 0, 1, 2 and possibly 3 arguments.
* Types written against this single callback type are easier to work with in a consistent matter.
* In the last case you can add additional information in a new field without breaking code

## CallbackLink

When you register a callback to a caller, you often want to be able to undo this registration. Classically, the caller provides for this functionality by exposing two methods, one for registering and one for unregistering.

As opposed to that, tink adheres to a different approach, where the registration returns a "callback link", i.e. a value representing the link between the caller and the callback. It looks as follows:

```haxe
abstract CallbackLink {
  function dissolve():Void;
  @:to function toCallback<A>():Callback<A>;
  @:from static function fromFunction(f:Void->Void):CallbackLink;
}
```

Calling `dissolve` will dissolve the link, as suggested by the name. Ain't no rocket science ;)

The link itself can be promoted to become a callback, so that you can in fact register it as a handler elsewhere:

```haxe
button.onPress(function () {
  var stop = button.onMouseMove(function () trace('move!'));
  button.onRelease(stop);
});
```

## CallbackList

While the `Callback` and `CallbackLink` are pretty nice in theory, on their own, they have no application. For that reasons `tink_core` defines a basic infrastructure to provide callback registration and link dissolving:

```haxe
abstract CallbackList<T> {
  var length(get, never):Int;
  function new():Void;
  function add(cb:Callback<T>):CallbackLink;
  function invoke(data:T):Void; 
  function clear():Void;
}
```

By calling `add` you can thus register a callback and will obtain a link that allows undoig the registration. You can `invoke` all callbacks in the list with some data, or `clear` the list if you wish to. 

### Registering callbacks

Unlike with similar mechanisms, you can `add` the same callback multiple times and one `invoke` will then cause the callback to be called multiple times. You will however get distinct callback links that allow you to separately undo the registrations.
While this behavior might strike you as unfamiliar, it does have advantages:

- Adding callbacks becomes very cheap (since you don't have to check whether they are already existent)
- Avoid trouble with all sorts of inconsistencies regarding function equality on different Haxe targets
- Have a clear and simple behavior, that is thus highly predictable - i.e. callbacks are simply executed in the order they are registered in. If you register a new callback, you can expect *all* previously registered callbacks to execute *before* it. The same cannot be said in case of the more common approach, if the callback was registered already once, so execution order tends to be undefined.

In essence the `CallbackList` can be seen as a basic building block for notification mechanisms.


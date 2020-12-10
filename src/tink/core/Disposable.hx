package tink.core;

/**
 *
 * An object that will be disposed at the end of life cycle.
 *
 * This interface only gives access to observing the disposed status,
 * but not allow disposing the object. For that @see OwnedDisposable
 *
 * Diposable objects should be satisfy the following conditions:
 *
 * - disposal should be implemented in such a way that the `disposed` property becomes `true`,
 *   then all handlers supplied to `ondispose` are invoked and then the actual teardown is performed
 *
 * - calling out from a disposable (e.g. by means of callbacks) to other objects mid-method may lead to disposal
 *   and therefore methods should be implemented in one of two ways:
 *
 *   - control should only be transferred outside at the end of a method
 *   - methods should be implemented in an abortable fashion, check for disposal when control is transferred back
 *   - and skip the remaining method (and possibly rollback already performed actions)
 *
 * - a diposable that is disposed should gracefully noop out any method calls performed on it:
 *
 *   - methods should return null objects
 *   - if the disposable has an error signaling mechanism, it can be used to communicate the occurence of such calls
 *   - methods returning promises should return failing promises
 *   - methods returning futures should preferably return futures yielding null objects, or alternatively
 */
interface Disposable {
  var disposed(get, never):Bool;
  function ondispose(d:()->Void):Void;
}

/**
 * A disposable object that also exposes the means to dispose it.
 */
interface OwnedDisposable extends Disposable {
  function dispose():Void;
}

/**
 * A simple implementation of the OwnedDisposable,
 * where actual disposal is passed in via the constructor.
 */
class SimpleDisposable implements OwnedDisposable {
  var f:()->Void;
  var disposeHandlers:Null<Array<()->Void>> = [];

  public var disposed(get, never):Bool;
    inline function get_disposed()
      return disposeHandlers == null;

  public function ondispose(d:()->Void)
    switch disposeHandlers {
      case null: d();
      case v: v.push(d);
    }

  public function new(dispose)
    this.f = dispose;

  public function dispose()
    switch disposeHandlers {
      case null:
      case v:
        disposeHandlers = null;
        var f = f;
        this.f = noop;//TODO: stack overflow guard
        f();
        for (h in v)
          h();
    }

  static function noop() {}
}

class AlreadyDisposed implements OwnedDisposable {

  public var disposed(get, never):Bool;
    function get_disposed() return true;

  public function ondispose(d:()->Void) d();//TODO: consider using Callback.defer
  public function dispose() {}

  function new() {}

  static public final INST:OwnedDisposable = new AlreadyDisposed();

}
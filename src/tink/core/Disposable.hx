package tink.core;

/**
 * An object that will be disposed at the end of life cycle.
 *
 * This interface only gives access to observing the disposed status,
 * but not allow disposing the object. For that @see OwnedDisposable
 */
interface Disposable {
  var disposed(get, never):Bool;
  function ondispose(d:Void->Void):Void;
}

/**
 * A disposable object that also exposes the means to dispose it.
 */
interface OwnedDisposable extends Disposable {
  function dispose():Void;
}
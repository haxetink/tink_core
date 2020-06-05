package tink.core;

interface Disposable {
  var disposed(get, never):Bool;
  function dispose():Void;
  function attachDisposable(d:Disposable):Void;//TODO: this should probably live in an extra interface
}
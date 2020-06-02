package tink.core;

interface Disposable {
  var disposed(get, never):Bool;
  function dispose():Void;
  function attach(d:Disposable):Void;
}
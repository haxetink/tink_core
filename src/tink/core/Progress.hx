package tink.core;

import tink.core.Callback;
import tink.core.Future;
import tink.core.Signal;

using tink.core.Progress.TotalTools;
using tink.core.Option;

@:forward(result)
abstract Progress<T>(ProgressObject<T>) from ProgressObject<T> {
  static public final INIT = ProgressValue.ZERO;

  public inline function listen(cb:Callback<ProgressValue>):CallbackLink
    return this.valueChanged.handle(cb);

  public inline function handle(cb:Callback<T>):CallbackLink
    return this.result.handle(cb);

  public inline static function trigger<T>():ProgressTrigger<T> {
    return new ProgressTrigger<T>();
  }

  public static function make<T>(f:(progress:(value:Float, total:Option<Float>)->Void, finish:(result:T)->Void)->CallbackLink):Progress<T>
    return Future.irreversible(yield -> {
      var ret = trigger();
      f(ret.progress, ret.finish);
      yield(ret.asProgress());
    });

  @:to
  public inline function asFuture():Future<T>
    return this.result;

  @:impl
  public static inline function asPromise<T>(p:ProgressObject<Outcome<T, Error>>):Promise<T>
    return (p:Progress<Outcome<T, Error>>).result;

  @:from
  static inline function promise<T>(v:Promise<Progress<T>>):Progress<Outcome<T, Error>>
    return new ProgressObject<Outcome<T, Error>>(
      v.next(p -> p.result),
      Signal.create(fire -> {
        var inner = new CallbackLinkRef();
        return v.handle(o -> switch o {
          case Success(p):
            inner.link = p.listen(fire);
          case Failure(e):
        }) & inner;
      })
    );

  @:from
  static inline function future<T>(v:Future<Progress<T>>):Progress<T>
    return new ProgressObject<T>(
      v.flatMap(p -> p.result),
      Signal.create(fire -> {
        var inner = new CallbackLinkRef();
        return v.handle(p -> inner.link = p.listen(fire)) & inner;
      })
    );

  public inline function next(f) {
    return asFuture().next(f);
  }
}

private class ProgressObject<T> {
  public var status(default, null):ProgressStatus<T> = InProgress(ProgressValue.ZERO);

  public final result:Future<T>;
  public final valueChanged:Signal<ProgressValue>;

  public function new(result, valueChanged, ?status) {
    this.result = result;
    this.valueChanged = valueChanged;
    switch status {
      case null:
      case v: this.status = v;
    }
  }
}

class ProgressTrigger<T> extends ProgressObject<T> {

  var _result = new FutureTrigger();
  var _valueChanged = new SignalTrigger();

  public function new(?status) {
    super(_result, _valueChanged, status);
  }

  public inline function asProgress():Progress<T>
    return this;

  public function progress(v:Float, total:Option<Float>) {
    switch status {
      case Finished(_):
        // do nothing
      case InProgress(current):
        if (current.value != v || !current.total.eq(total)) {
          var pv = new Pair(v, total);
          status = InProgress(pv);
          _valueChanged.trigger(pv);
        }
    }
  }

  public function finish(v:T) {
    switch status {
      case Finished(_):
        // do nothing
      case _:
        // TODO: clear signal handlers
        status = Finished(v);
        _result.trigger(v);
    }
  }
}

@:pure
abstract ProgressValue(Pair<Float, Option<Float>>) from Pair<Float, Option<Float>> {
  static public final ZERO = new ProgressValue(0, None);

  public var value(get, never):Float;
  public var total(get, never):Option<Float>;

  public inline function new(value, total)
    this = new Pair(value, total);

  /**
   * Normalize to 0-1 range
   */
  public inline function normalize():Option<UnitInterval>
    return total.map(function(v) return value / v);

  inline function get_value()
    return this.a;

  inline function get_total()
    return this.b;
}

abstract UnitInterval(Float) from Float to Float {
  public function toPercentageString(dp:Int) {
    var m = Math.pow(10, dp);
    var v = Math.round(this * m * 100) / m;
    var s = Std.string(v);
    return switch s.indexOf('.') {
      case -1: s + '.' + StringTools.lpad('', '0', dp) + '%';
      case i if (s.length - i > dp): s.substr(0, dp + i + 1) + '%';
      case i: StringTools.rpad(s, '0', i + dp + 1) + '%';
    }
  }
}

@:deprecated typedef ProgressType<T> = ProgressStatus<T>;

enum ProgressStatus<T> {
  InProgress(v:ProgressValue);
  Finished(v:T);
}

class TotalTools {
  public static function eq(a:Option<Float>, b:Option<Float>) {
    return switch [a, b] {
      case [Some(t1), Some(t2)]: t1 == t2;//TODO: deal with precision
      case [None, None]: true;
      case _: false;
    }
  }
}

package tink.core;

import tink.core.Disposable;
import tink.core.Callback;
import tink.core.Future;
import tink.core.Signal;
import tink.core.Outcome;

using tink.core.Progress.TotalTools;
using tink.core.Option;

@:using(tink.core.Progress.ProgressTools)
@:forward(result, status, progressed, changed)
abstract Progress<T>(ProgressObject<T>) from ProgressObject<T> {
  static public final INIT = ProgressValue.ZERO;

  public inline function listen(cb:Callback<ProgressValue>):CallbackLink
    return this.progressed.handle(cb);

  public inline function handle(cb:Callback<T>):CallbackLink
    return this.result.handle(cb);

  public inline static function trigger<T>():ProgressTrigger<T> {
    return new ProgressTrigger<T>();
  }

  public static function make<T>(f:(progress:(value:Float, total:Option<Float>)->Void, finish:(result:T)->Void)->CallbackLink):Progress<T>
    return new SuspendableProgress(fire -> f(
      (value, total) -> fire(InProgress(new ProgressValue(value, total))),
      result -> fire(Finished(result))
    ));

  public function map<R>(f:T->R):Progress<R>
    return new ProgressObject(this.changed.map(s -> s.map(f)), () -> this.status.map(f));

  // @:to // enabling this will block the following flattening casts
  public inline function asFuture():Future<T>
    return this.result;

  @:from
  static function promise<T>(v:Promise<Progress<T>>):Progress<Outcome<T, Error>>
    return new SuspendableProgress(fire -> {
      final inner = new CallbackLinkRef();
      v.handle(o -> switch o {
        case Success(p):
          inner.link = p.changed.handle(s -> fire(s.map(Success)));
        case Failure(e):
          fire(Finished(Failure(e)));
      }) & inner;
    });

  @:from
  static inline function flatten<T>(v:Promise<Progress<Outcome<T, Error>>>):Progress<Outcome<T, Error>>
    return promise(v).map(o -> switch o {
      case Success(Success(v)): Success(v);
      case Failure(e) | Success(Failure(e)): Failure(e);
    });

  @:from
  static function future<T>(v:Future<Progress<T>>):Progress<T>
    return new SuspendableProgress(fire -> {
      final inner = new CallbackLinkRef();
      v.handle(p -> inner.link = p.changed.handle(fire)) & inner;
    });

  public inline function next(f) {
    return asFuture().next(f);
  }
}

private class SuspendableProgress<T> extends ProgressObject<T> {

  function noop(_, _) return null;
  public function new(wakeup:(fire:ProgressStatus<T>->Void)->CallbackLink, ?status) {
    if (status == null)
      status = InProgress(ProgressValue.ZERO);
    var disposable = AlreadyDisposed.INST;
    var changed = switch status {
      case Finished(_):
        Signal.dead();
      case InProgress(_):
        new Signal(
          fire -> wakeup(s -> fire(status = s)),
          d -> disposable = d
        );
    }
    super(
      changed,
      () -> status
    );
  }
}

private class ProgressObject<T> {

  public var status(get, never):ProgressStatus<T>;
    inline function get_status() return getStatus();

  var getStatus:Void->ProgressStatus<T>;

  public final changed:Signal<ProgressStatus<T>>;
  public final progressed:Signal<ProgressValue>;
  public final result:Future<T>;

  public function new(changed, getStatus) {
    this.changed = changed;
    this.progressed = new Signal(fire -> changed.handle(s -> switch s {
      case InProgress(v): fire(v);
      default:
    }));
    this.getStatus = getStatus;
    this.result = new Future(fire -> switch getStatus() {
      case Finished(v): fire(v); null;
      default:
        changed.handle(s -> switch s {
          default:
          case Finished(v): fire(v);
        });
    });
  }
}

final class ProgressTrigger<T> extends ProgressObject<T> {

  var _status:ProgressStatus<T>;
  var _changed = null;

  public function new(?status) {
    if (status == null)
      _status = status = InProgress(ProgressValue.ZERO);
    super(if (status.match(Finished(_))) Signal.dead() else _changed = Signal.trigger(), () -> _status);
  }

  public inline function asProgress():Progress<T>
    return this;

  public function progress(v:Float, total:Option<Float>)
    if (!_status.match(Finished(_)))
      _changed.trigger(_status = InProgress(new ProgressValue(v, total)));

  public function finish(v:T)
    if (!_status.match(Finished(_)))
      _changed.trigger(_status = Finished(v));

}

@:pure
abstract ProgressValue(Pair<Float, Option<Float>>) from Pair<Float, Option<Float>> to Pair<Float, Option<Float>> {
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
  
  @:op(A+B) public static function add(a:UnitInterval, b:Float):Float;
  @:op(A-B) public static function sub(a:UnitInterval, b:Float):Float;
  @:op(A*B) public static function mul(a:UnitInterval, b:Float):Float;
  @:op(A/B) public static function div(a:UnitInterval, b:Float):Float;
}

@:deprecated typedef ProgressType<T> = ProgressStatus<T>;

@:using(tink.core.Progress.ProgressStatusTools)
enum ProgressStatus<T> {
  InProgress(v:ProgressValue);
  Finished(v:T);
}

@:noCompletion
class ProgressStatusTools {
  static public function map<T, R>(p:ProgressStatus<T>, f:T->R)
    return switch p {
      case InProgress(v): InProgress(v);
      case Finished(v): Finished(f(v));
    }
}

@:noCompletion
class TotalTools {
  public static function eq(a:Option<Float>, b:Option<Float>) {
    return switch [a, b] {
      case [Some(t1), Some(t2)]: t1 == t2;//TODO: deal with precision
      case [None, None]: true;
      case _: false;
    }
  }
}

class ProgressTools {
  public static inline function asPromise<T>(p:Progress<Outcome<T, Error>>):Promise<T>
    return p.result;
}
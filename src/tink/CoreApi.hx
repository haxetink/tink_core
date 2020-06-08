package tink;

@:noCompletion typedef Annex<Target> = tink.core.Annex<Target>;

@:noCompletion typedef Next<In, Out> = tink.core.Promise.Next<In, Out>;
@:noCompletion typedef Combiner<In1, In2, Out> = tink.core.Promise.Combiner<In1, In2, Out>;
@:noCompletion typedef Promise<T> = tink.core.Promise<T>;
@:noCompletion typedef Future<T> = tink.core.Future<T>;

@:noCompletion typedef Surprise<D, F> = tink.core.Future.Surprise<D, F>;
#if js @:noCompletion typedef JsPromiseTools = tink.core.Future.JsPromiseTools; #end
@:noCompletion typedef FutureTrigger<T> = tink.core.Future.FutureTrigger<T>;
@:noCompletion typedef PromiseTrigger<T> = tink.core.Promise.PromiseTrigger<T>;

@:noCompletion typedef Outcome<D, F> = tink.core.Outcome<D, F>;
@:noCompletion typedef OutcomeTools = tink.core.Outcome.OutcomeTools;

@:noCompletion typedef Either<L, R> = tink.core.Either<L, R>;
@:noCompletion typedef Option<T> = tink.core.Option<T>;
@:noCompletion typedef OptionTools<T> = tink.core.Option.OptionTools;

@:noCompletion typedef Pair<A, B> = tink.core.Pair<A, B>;
@:noCompletion typedef MPair<A, B> = tink.core.Pair.MPair<A, B>;

@:noCompletion typedef Signal<T> = tink.core.Signal<T>;
@:noCompletion typedef SignalTrigger<T> = tink.core.Signal.SignalTrigger<T>;

@:noCompletion typedef Noise = tink.core.Noise;

@:noCompletion typedef Error = tink.core.Error;
@:noCompletion typedef TypedError<T> = tink.core.Error.TypedError<T>;

@:noCompletion typedef Callback<T> = tink.core.Callback<T>;
@:noCompletion typedef CallbackLink = tink.core.Callback.CallbackLink;
@:noCompletion typedef CallbackList<T> = tink.core.Callback.CallbackList<T>;

@:noCompletion typedef Ref<T> = tink.core.Ref<T>;
@:noCompletion typedef Lazy<T> = tink.core.Lazy<T>;
@:noCompletion typedef Any = tink.core.Any;

@:noCompletion typedef Named<V> = tink.core.Named<V>;
@:noCompletion typedef NamedWith<N, V> = tink.core.Named.NamedWith<N, V>;

@:noCompletion typedef Progress<T> = tink.core.Progress<T>;

package tink;

typedef Annex<Target> = tink.core.Annex<Target>;

typedef Next<In, Out> = tink.core.Promise.Next<In, Out>;
typedef Combiner<In1, In2, Out> = tink.core.Promise.Combiner<In1, In2, Out>;
typedef Promise<T> = tink.core.Promise<T>;
typedef Future<T> = tink.core.Future<T>;

typedef Surprise<D, F> = tink.core.Future.Surprise<D, F>;
#if js typedef JsPromiseTools = tink.core.Future.JsPromiseTools; #end
typedef FutureTrigger<T> = tink.core.Future.FutureTrigger<T>;
typedef PromiseTrigger<T> = tink.core.Promise.PromiseTrigger<T>;

typedef Outcome<D, F> = tink.core.Outcome<D, F>;
typedef OutcomeTools = tink.core.Outcome.OutcomeTools;

typedef Either<L, R> = tink.core.Either<L, R>;
typedef Option<T> = tink.core.Option<T>;
typedef OptionTools<T> = tink.core.Option.OptionTools;

typedef Pair<A, B> = tink.core.Pair<A, B>;
typedef MPair<A, B> = tink.core.Pair.MPair<A, B>;

typedef Signal<T> = tink.core.Signal<T>;
typedef SignalTrigger<T> = tink.core.Signal.SignalTrigger<T>;

typedef Noise = tink.core.Noise;

typedef Error = tink.core.Error;
typedef TypedError<T> = tink.core.Error.TypedError<T>;

typedef Callback<T> = tink.core.Callback<T>;
typedef CallbackLink = tink.core.Callback.CallbackLink;
typedef CallbackList<T> = tink.core.Callback.CallbackList<T>;

typedef Ref<T> = tink.core.Ref<T>;
typedef Lazy<T> = tink.core.Lazy<T>;
typedef Any = tink.core.Any;

typedef Named<V> = tink.core.Named<V>;
typedef NamedWith<N, V> = tink.core.Named.NamedWith<N, V>;

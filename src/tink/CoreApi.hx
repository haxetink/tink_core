package tink;

typedef Future<T> = tink.core.Future<T>;
typedef Surprise<D, F> = tink.core.Future.Surprise<D, F>;
typedef FutureTrigger<T> = tink.core.Future.FutureTrigger<T>;

typedef Outcome<D, F> = tink.core.Outcome<D, F>;
typedef OutcomeTools = tink.core.Outcome.OutcomeTools;

typedef Either<L, R> = tink.core.Either<L, R>;

typedef Pair<A, B> = tink.core.Pair<A, B>;
typedef MPair<A, B> = tink.core.Pair.MPair<A, B>;

typedef Signal<T> = tink.core.Signal<T>;
typedef SignalTrigger<T> = tink.core.Signal.SignalTrigger<T>;

typedef Noise = tink.core.Noise;

typedef Error = tink.core.Error;

typedef Callback<T> = tink.core.Callback<T>;
typedef CallbackLink = tink.core.Callback.CallbackLink;
typedef CallbackList<T> = tink.core.Callback.CallbackList<T>;

typedef Ref<T> = tink.core.Ref<T>;
typedef Lazy<T> = tink.core.Lazy<T>;
typedef Any = tink.core.Any;
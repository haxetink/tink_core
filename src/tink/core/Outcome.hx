package tink.core;

import haxe.ds.Option;
import tink.core.Either;

enum Outcome<Data, Failure> {//TODO: turn into abstract when this commit is released: https://github.com/HaxeFoundation/haxe/commit/e8715189fc055220f2f33a06c5e1331c96310a88
  Success(data:Data);
  Failure(failure:Failure);
}

class OutcomeTools {
  
  /**
   *  Extracts the value if the outcome is `Success`, throws the `Failure` contents otherwise
   */
  static public function sure<D, F>(outcome:Outcome<D, F>):D 
    return
      switch (outcome) {
        case Success(data): 
          data;
        case Failure(failure): 
          switch Error.asError(failure) {
            case null: throw failure;
            case e: e.throwSelf();
          }
      }
  
  /**
   *  Creates an `Option` from this `Outcome`, discarding the `Failure` information
   */
  static public function toOption<D, F>(outcome:Outcome<D, F>):Option<D>
    return 
      switch (outcome) {
        case Success(data): Option.Some(data);
        case Failure(_): Option.None;
      }
  
  /**
   *  Creates an `Outcome` from an `Option`, with made-up `Failure` information
   */
  static public function toOutcome<D>(option:Option<D>, ?pos:haxe.PosInfos):Outcome<D, Error>//TODO: this should go into OptionTools in the next major release
    return
      switch (option) {
        case Some(value): 
          Success(value);
        case None: 
          Failure(new Error(NotFound, 'Some value expected but none found in ' + pos.fileName + '@line ' + pos.lineNumber));
      }
  
  /**
   *  Extracts the value if the option is `Success`, otherwise `null`
   */
  static public function orNull<D, F>(outcome: Outcome<D, F>):Null<D> 
    return
      switch (outcome) {
        case Success(data): data;
        case Failure(_): null;
      }    

  /**
   *  Extracts the value if the option is `Success`, uses the fallback value otherwise
   */
  static public function orUse<D, F>(outcome: Outcome<D, F>, fallback: Lazy<D>):D 
    return
      switch (outcome) {
        case Success(data): data;
        case Failure(_): fallback.get();
      }    
  
  /**
   *  Extracts the value if the option is `Success`, uses the fallback `Outcome` otherwise
   */
  static public function orTry<D, F>(outcome: Outcome<D, F>, fallback: Lazy<Outcome<D, F>>):Outcome<D, F> 
    return
      switch (outcome) {
        case Success(_): outcome;
        case Failure(_): fallback.get();
      }
  /**
   *   Returns `true` if the outcome is `Some` and the value is equal to `v`, otherwise `false`
   */
  static public function equals<D, F>(outcome:Outcome<D, F>, to: D):Bool 
    return 
      switch (outcome) {
        case Success(data): data == to;
        case Failure(_): false;
      }
  /**
   *  Transforms the outcome with a transform function
   *  Different from `flatMap`, the transform function of `map` returns a plain value
   */
  static public function map<A, B, F>(outcome:Outcome<A, F>, transform: A->B) 
    return 
      switch (outcome) {
        case Success(a): 
          Success(transform(a));
        case Failure(f): 
          Failure(f);
      }
  
  /**
   *  Returns `true` if the outcome is `Success`
   */
  static public function isSuccess<D, F>(outcome:Outcome<D, F>):Bool 
    return 
      switch outcome {
        case Success(_): true;
        default: false;
      }
  
  
  /**
   *  Transforms the outcome with a transform function
   *  Different from `map`, the transform function of `flatMap` returns an `Outcome`
   */
  static public function flatMap<DIn, FIn, DOut, FOut>(o:Outcome<DIn, FIn>, mapper:OutcomeMapper<DIn, FIn, DOut, FOut>):Outcome<DOut, FOut> {
    return mapper.apply(o);
  }
  
  /**
   *  Like `map` but with a plain value instead of a transform function, thus discarding the orginal result
   */
  static public function swap<A, B, F>(outcome:Outcome<A, F>, v:B)
    return 
      switch (outcome) {
        case Success(a): 
          Success(v);
        case Failure(f): 
          Failure(f);
      }
  
  /**
   *  Try to run `f` and wraps the result in `Success`,
   *  thrown exceptions are transformed by `report` then wrapped into a `Failure`
   */
  static public function attempt<D, F>(f:Void->D, report:Dynamic->F) 
    return
      try Success(f())
      catch (e:Dynamic) 
        Failure(report(e));
        
  static public function flatten<D, F>(o:Outcome<Outcome<D, F>, F>):Outcome<D, F>
    return switch o {
      case Success(Success(d)): Success(d);
      case Success(Failure(f)) | Failure(f): Failure(f);
    }
}

private abstract OutcomeMapper<DIn, FIn, DOut, FOut>({ f: Outcome<DIn, FIn>->Outcome<DOut, FOut> }) {
  function new(f:Outcome<DIn, FIn>->Outcome<DOut, FOut>) this = { f: f };
  public function apply(o) 
    return this.f(o);
    
  @:from static function withSameError<In, Out, Error>(f:In->Outcome<Out, Error>):OutcomeMapper<In, Error, Out, Error> {
    return new OutcomeMapper(function (o)
      return switch o {
        case Success(d): f(d);
        case Failure(f): Failure(f);
      }
    );
  }
  
  @:from static function withEitherError<DIn, FIn, DOut, FOut>(f:DIn->Outcome<DOut, FOut>):OutcomeMapper<DIn, FIn, DOut, Either<FIn, FOut>> {
    return new OutcomeMapper(function (o)
      return switch o {
        case Success(d): 
          switch f(d) {
            case Success(d): Success(d);
            case Failure(f): Failure(Right(f));
          }
        case Failure(f): Failure(Left(f));
      }
    );    
  }
}
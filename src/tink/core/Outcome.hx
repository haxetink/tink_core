package tink.core;

import haxe.ds.Option;
import tink.core.Either;

enum Outcome<Data, Failure> {//TODO: turn into abstract when this commit is released: https://github.com/HaxeFoundation/haxe/commit/e8715189fc055220f2f33a06c5e1331c96310a88
	Success(data:Data);
	Failure(failure:Failure);
}

class OutcomeTools {
	static public function sure<D, F>(outcome:Outcome<D, F>):D 
		return
			switch (outcome) {
				case Success(data): 
					data;
				case Failure(failure): 
					if (Std.is(failure, Error)) 
						untyped failure.throwSelf();
					else
						throw failure;
			}
	
	static public function toOption<D, F>(outcome:Outcome<D, F>):Option<D>
		return 
			switch (outcome) {
				case Success(data): Option.Some(data);
				case Failure(_): Option.None;
			}
	
	static public function toOutcome<D>(option:Option<D>, ?pos:haxe.PosInfos):Outcome<D, String>
		return
			switch (option) {
				case Some(value): 
					Success(value);
				case None: 
					Failure('Some value expected but none found in ' + pos.fileName + '@line ' + pos.lineNumber);
			}
	
	//TODO: orTry and orUse should probably become Lazy to allow for short-circuit evaluation
	static public inline function orUse<D, F>(outcome: Outcome<D, F>, fallback: D) 
		return
			switch (outcome) {
				case Success(data): data;
				case Failure(_): fallback;
			}		
			
	static public inline function orTry<D, F>(outcome: Outcome<D, F>, fallback: Outcome<D, F>) 
		return
			switch (outcome) {
				case Success(_): outcome;
				case Failure(_): fallback;
			}
	
	static public inline function equals<D, F>(outcome:Outcome<D, F>, to: D):Bool 
		return 
			switch (outcome) {
				case Success(data): data == to;
				case Failure(_): false;
			}
	
	static public inline function map<A, B, F>(outcome:Outcome<A, F>, transform: A->B) 
		return 
			switch (outcome) {
				case Success(a): 
					Success(transform(a));
				case Failure(f): 
					Failure(f);
			}
	
	static public inline function isSuccess<D, F>(outcome:Outcome<D, F>):Bool 
		return 
			switch outcome {
				case Success(_): true;
				default: false;
			}
	
	static public function flatMap<DIn, FIn, DOut, FOut>(o:Outcome<DIn, FIn>, mapper:OutcomeMap<DIn, FIn, DOut, FOut>):Outcome<DOut, FOut> {
		return mapper.apply(o);
	}
}

private abstract OutcomeMap<DIn, FIn, DOut, FOut>({ f: Outcome<DIn, FIn>->Outcome<DOut, FOut> }) {
	function new(f) this = { f: f };
	public function apply(o) 
		return this.f(o);
		
	@:from #if as3 public #end static function withSameError<In, Out, Error>(f:In->Outcome<Out, Error>):OutcomeMap<In, Error, Out, Error> {
		return new OutcomeMap(function (o)
			return switch o {
				case Success(d): f(d);
				case Failure(f): Failure(f);
			}
		);
	}
	
	@:from #if as3 public #end static function withEitherError<DIn, FIn, DOut, FOut>(f:DIn->Outcome<DOut, FOut>):OutcomeMap<DIn, FIn, DOut, Either<FIn, FOut>> {
		return new OutcomeMap(function (o)
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
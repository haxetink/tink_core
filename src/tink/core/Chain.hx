package tink.core;

import tink.core.Callback;
import tink.core.*;
using tink.core.Outcome;

//TODO: get rid of !! with next Haxe release
abstract Chain<D>(Future<Pair<D, Chain<D>>>) {
	
	public inline function new(f) this = f;
	
	static inline function mk<X>(data:X, next:Chain<X>)
		return new Pair(data, next);
	
	public function map<A>(f:D->A, ?gather = true):Chain<A>
		return new Chain(this.map(function (link) return 
			if (!!link) mk(f(link.a), link.b.map(f, gather))
			else Pair.nil()
		, gather));
	
	public function flatMap<A>(f:D->Future<A>, ?gather = true):Chain<A>
		return new Chain(this.flatMap(function (link) return 
			if (!!link) 
				f(link.a).map(function (data) return mk(data, link.b.flatMap(f, gather)))
			else 
				Future.ofConstant(Pair.nil())
		, gather));
	
	public function peek():Future<Outcome<D, String>>
		return this.map(function (link) return
			if (!!link) Success(link.a)
			else Failure('No more data')
		);
	
	public function step(?f:D->Void, ?end:Void->Void):Chain<D> {
		this.handle(function (link) 
			if (end != null && !link) end()
			else if (f != null && !!link) f(link.a)
		);
		return new Chain(this.flatMap(function (link) return 
			if (!!link) link.b.toFuture()
			else Future.ofConstant(Pair.nil())
		));
	}
	
	public function concat(other:Chain<D>, ?gather = true)
		return new Chain(this.flatMap(function (link) return 
			if (!!link) Future.ofConstant(mk(link.a, link.b.concat(other, gather)))
			else other.toFuture()
		, gather));
	
	public function zip<B, R>(other:Chain<B>, zipper:D->B->R, ?gather = true):Chain<R> 
		return new Chain(this.flatMap(function (l1) return 
			if (!!l1) other.toFuture().map(function (l2) return
				if (!!l2) mk(
					zipper(l1.a, l2.a),
					l1.b.zip(l2.b, zipper, gather)
				)
				else Pair.nil()
			, false)
			else Future.ofConstant(Pair.nil()) 
		, gather));
	
	public function skip(count:Int, ?gather = true):Chain<D>
		return new Chain(this.flatMap(function (link) return 
			if (count > 0 && !!link)
				link.b.skip(count - 1, gather).toFuture()
			else
				Future.ofConstant(link)
		, gather));
		
	public function limit(count:Int, ?gather = true):Chain<D>
		return new Chain(this.map(function (link) return 
			if (count > 0 && !!link) mk(
				link.a, 
				if (count == 1) new Chain(Future.ofConstant(Pair.nil())) 
				else link.b.limit(count - 1, gather)
			)
			else Pair.nil()
		, gather));	
		
	public function slice(count:Int) 
		return 
			until(function (_) return count-- <= 0, false)
			.fold([], function (ret:Array<D>, x) { ret.push(x); return ret; });//The implementation is hacky. But fast
	
	public function until(f:D->Bool, ?gather = true):Chain<D>
		return new Chain(this.map(function (link) return 
			if (!!link && !f(link.a)) mk(link.a, link.b.until(f, gather))
			else Pair.nil()
		, gather));
	
	inline function toFuture() return this;
	
	public function filter(f:D->Bool, ?gather = true):Chain<D>
		return new Chain(this.flatMap(function (link) return 
			if (!!link) {
				var next = link.b.filter(f, gather);
				if (f(link.a))
					Future.ofConstant(mk(link.a, next))
				else
					next.toFuture();				
			} 
			else 
				Future.ofConstant(null)
		, gather));
	
	//Lookahead for synchronous situations, that could otherwise cause stack overflows
	function sync(v:D->Void):Chain<D> {
		var end = this,
			next = null;
		while (true) {
			next = null;
			var l = end.handle(function (link) 
				if (link == null) next = end;
				else {
					next = link.b.toFuture();
					v(link.a);					
				}
			);
			if (next == end || next == null) {
				l.dissolve();
				break;
			}
			end = next;
		}
		
		return new Chain(end);
	}	
	
	public function fold<R>(start:R, calc:R->D->R):Future<R> 
		return sync(function (d) start = calc(start, d)).toFuture().flatMap(function (link) return
			if (!!link)
				link.b.fold(calc(start, link.a), calc)
			else
				Future.ofConstant(start)
		);
	
	public function forEach(f:Callback<D>):CallbackLink {
		var link:CallbackLink = null;
		var l = sync(f.invoke).toFuture().handle(
			function (l) if (l != null) {
				f.invoke(l.a);
				link = l.b.forEach(f);			
			}
		);
		if (link == null) link = l;
		return function () 
			link.dissolve();
	}
	static public function fix<D, F>(c:RustyChain<D, F>, kind:FixChain<D, F>, ?gather = true):Chain<D> 
		return
			switch kind {
				case Skip: 
					c.filter(function (o) return !o.isSuccess(), false)
						.map(function (o) return o.sure(), gather);
				case Abort:
					c.until(function (o) return !o.isSuccess(), false)
						.map(function (o) return o.sure(), gather);
				case Recover(recover):
					c.flatMap(function (o) return switch o { 
						case Success(d): Future.ofConstant(d);
						case Failure(f): recover(f); 
					}, gather);		
			}
	
	static public function async<D, E>(data:Signal<D>, ?end:Future<E>)
		return (function make() 
			return new Chain(Future.ofAsyncCall(function (cb:Pair<D, Chain<D>>->Void) {
				if (end != null) end.handle(function (e) cb(null));
				data.next().handle(function (d) cb(mk(d, make())));
			})))();
	
	static public function lazy<A>(f:Void->A, ?end:Void->Bool):Chain<A> 
		return 
			new Chain(Future.lazy(function () 
				return 
					if (end == null || end()) 
						mk(f(), lazy(f, end));
					else
						null
			));
	
	@:from static function ofSignal<A>(s:Signal<A>):Chain<A> return async(s);
	
	@:from static public function ofArray<A>(a:Array<A>):Chain<A> {
		var ret = new Chain(Future.ofConstant(null));
		for (i in 0...a.length) 
			ret = new Chain(Future.ofConstant(mk(a[a.length - i - 1], ret)));
		return ret;
	}
	
	@:from static public function ofIterable<A>(a:Iterable<A>):Chain<A> {
		var i = a.iterator();
		return lazy(i.next, i.hasNext);
	}
}

enum FixChain<D, F> {
	Skip;
	Abort;
	Recover(f:F->Future<D>);
}

typedef RustyChain<D, F> = Chain<Outcome<D, F>>;
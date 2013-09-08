package tink.core;

import haxe.ds.Option;
import tink.core.Callback;

using tink.core.Outcome;

abstract Chain<D>(Future<Option<{ data: D, next: Chain<D> }>>) {
	
	public function new(f) this = f;
	
	public function map<A>(f:D->A, ?gather = true):Chain<A> {
		return new Chain(this.map(function (data) return switch data {
			case Some({ data: d, next: n}):
				Some({ data: f(d), next: n.map(f, gather) });
			case None: None;
		}, gather));
	}
	
	public function zip<B, R>(other:Chain<B>, zipper:D->B->R, ?gather = true):Chain<R> {
		var that = other.toFuture();
		var ret = new Future(function (cb:Callback<Option<{ data: R, next: Chain<R> }>>) {
			var link = null;
			var l = this.when(function (o1) 
				link = that.when(function (o2)
					switch [o1, o2] {
						case [Some({ data: d1, next: n1}), Some({ data: d2, next: n2})]:
							cb.invoke(Some({ 
								data: zipper(d1, d2), 
								next: n1.zip(n2, zipper, gather)
							}));
						default:
							cb.invoke(None);
					}
				)
			);
			return 
				if (link == null) l;
				else link;
		});
		return new Chain(
			if (gather) ret.gather()
			else ret
		);
	}
	
	public function slice(count:Int) 
		return 
			until(function (_) return count-- <= 0, false)
			.fold([], function (ret:Array<D>, x) { ret.push(x); return ret; });//Modifying the array in place is not very pretty - but faster
	
	public function until(f:D->Bool, ?gather = true):Chain<D> {
		return new Chain(this.map(function (data) return switch data {
			case Some({ data: d, next: n}):
				if (f(d))
					None;
				else
					Some({ data: d, next: n.until(f, gather) });
			case None: None;
		}, gather));
	}
	
	function toFuture() return this;
	
	public function filter(f:D->Bool, ?gather = true):Chain<D> {
		return new Chain(this.flatMap(function (o) return switch o {
			case Some({ data: d, next: n }):
				n = n.filter(f, gather);
				if (f(d))
					Future.ofConstant(Some({ data: d, next: n }))
				else
					n.toFuture();
			case None: Future.ofConstant(None);
		}, gather));
	}
	
	//This is a lookahead for synchronous situations, that could otherwise cause stack overflows
	function sync(v:D->Void):Chain<D> {
		var end = this;
		while (true) {
			var next = null;
			end.when(function (o) switch o {
				case None: next = end;
				case Some({ data: d, next: n}):
					next = n.toFuture();
					v(d);
			});
			if (next == end || next == null) break;
			end = next;
		}
		return new Chain(end);
	}	
	
	public function fold<R>(start:R, calc:R->D->R):Future<R> 
		return sync(function (d) start = calc(start, d)).toFuture().flatMap(function (o) return switch o {
			case None: 
				Future.ofConstant(start);
			case Some({ data: d, next: n }):
				n.fold(calc(start, d), calc);
		});	
	
	public function forEach(f:Callback<D>):CallbackLink {
		var link:CallbackLink = null;
		var l = sync(f.invoke).toFuture().when(function (o) switch o {
			case Some({ data: d, next: n}):
				f.invoke(d);
				link = n.forEach(f);
			case v: 
		});
		if (link == null) link = l;
		return function () 
			link.dissolve();
	}
	
	static public function compose<D, E>(data:Signal<D>, ?end:Future<E>) {
		if (end == null) end = Future.never();
		function make() 
			return new Chain(Future.ofAsyncCall(function (cb:Option<{ data: D, next: Chain<D> }>->Void) {
				end.when(function (e) cb(None));
				data.next().when(function (d) cb(Some({ data: d, next: make() })));
			}));
		
		return make();
	}
	
	static public function lazy<A>(f:Void->Option<A>):Chain<A> 
		return 
			new Chain(Future.lazy(function () 
				return 
					switch f() {
						case None: None;
						case Some(data): Some({
							data: data,
							next: lazy(f),
						});
					}
			));
			
	@:from static public function ofArray<A>(a:Array<A>):Chain<A> {
		var i = 0;
		return lazy(function () {
			return 
				if (i < a.length) Some(a[i++]);
				else None;
		});
	}
	@:from static public function ofIterable<A>(a:Iterable<A>):Chain<A> {
		var i = a.iterator();
		return lazy(function () {
			return 
				if (i.hasNext()) Some(i.next());
				else None;
		});
	}
}

abstract RustyChain<D, F>(Chain<Outcome<D, F>>) {
	public function new(c) this = c;
	
	public function skip(?gather = true):Chain<D> 
		return 
			this.filter(function (o) return !o.isSuccess(), false)
				.map(function (o) return o.sure(), gather);
				
	public function recover(recover:F->D, ?gather = true):Chain<D>
		return this.map(function (o) return switch o { 
			case Success(d): d;
			case Failure(f): recover(f); 
		}, gather);
	
	public function abort(?gather = true):Chain<D> 
		return 
			this.until(function (o) return !o.isSuccess(), false)
				.map(function (o) return o.sure(), gather);
}
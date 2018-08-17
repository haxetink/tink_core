package;

using tink.CoreApi;

@:asserts
class Promises extends Base {
  public function testRecover() {
    var p:Promise<Int> = new Error("test");
    p.recover(function (_) return 4).handle(function(v) asserts.assert(v == 4));
    p.recover(function (_) return Future.sync(5)).handle(function(v) asserts.assert(v == 5));
    return asserts.done();
  }

  public function testInParallel() {
    
    var counter = 0;
    function make(fail:Bool) 
      return Future.async(function (cb) {
        var id = counter++;
        cb(if (fail) Failure(new Error('error')) else Success(id));
      }, true);

    counter = 0;
    var p = Promise.inParallel([for (i in 0...10) make(i > 5)], true);
    asserts.assert(0 == counter);
    p.handle(function (o) {
      asserts.assert(!o.isSuccess());
    });
    asserts.assert(7 == counter);   
     
    counter = 0;
    var t = Future.trigger();
    var p = Promise.inParallel([t, make(false), make(false)], true);
    asserts.assert(0 == counter);
    var done = false;
    p.handle(function (o) {
      done = true;
      asserts.assert(!o.isSuccess());
    });
    asserts.assert(2 == counter);    
    asserts.assert(!done);
    t.trigger(Failure(new Error('test')));
    asserts.assert(done);
    
    
    counter = 0;
    var p = Promise.inParallel([], true);
    asserts.assert(0 == counter);
    p.handle(function (o) {
      asserts.assert(o.isSuccess());
    });
    asserts.assert(0 == counter);  
    return asserts.done();
  }
  
  public function testInSequence() {
    var counter = 0;
    function make(fail:Bool) 
      return Future.async(function (cb) {
        var id = counter++;
        cb(if (fail) Failure(new Error('error')) else Success(id));
      }, true);

    counter = 0;
    var p = Promise.inSequence([for (i in 0...10) make(i > 5)]);
    asserts.assert(0 == counter);
    p.handle(function (o) {
      asserts.assert(!o.isSuccess());
    });
    asserts.assert(7 == counter);
    counter = 0;
    var p = Promise.inSequence([for (i in 0...10) make(false)]);
    asserts.assert(0 == counter);
    p.handle(function (o) {
      asserts.assert('0,1,2,3,4,5,6,7,8,9' == o.sure().join(','));
    });
    asserts.assert(10 == counter);
    return asserts.done();
  }
  function parse(s:String)
    return switch Std.parseInt(s) {
      case null: Failure(new Error(422, '$s is not a valid integer'));
      case v: Success(v);
    }
    
  public function testIterate() {
    inline function boolAnd(promises:Iterable<Promise<Bool>>, ?lazy):Promise<Bool>
      return Promise.iterate(promises, function(v) return v ? None : Some(false), true, lazy);
      
    inline function boolOr(promises:Iterable<Promise<Bool>>, ?lazy):Promise<Bool>
      return Promise.iterate(promises, function(v) return v ? Some(true) : None, false, lazy);
    
    boolAnd([true, true, true]).handle(function(o) asserts.assert(o.match(Success(true))));
    boolAnd([true, false, true]).handle(function(o) asserts.assert(o.match(Success(false))));
    boolOr([false, false, false]).handle(function(o) asserts.assert(o.match(Success(false))));
    boolOr([false, false, true]).handle(function(o) asserts.assert(o.match(Success(true))));
    
    return asserts.done();
  }

  public function test() {
    var p:Promise<Int> = 5;
    p = Success(5);
    p = new Error('test');
    p = Failure(new Error('test'));
    p = Future.sync(Success(5));
      
    for (i in 0...10) {
      
      (p = i)
        .next(function (x) return x * 2)
        .next(Std.string)
        .next(parse)
        .next(function (x) return x >> 1)
        .handle(function (x) asserts.assert(i == x.sure()));
    }
    
    return asserts.done();
  }
  
  #if !java
  public function testCache() {
    var v = 0;
    var expire = Future.trigger();
    function gen() return Promise.lift(new Pair(v++, expire.asFuture()));
    var cache = Promise.cache(gen);
    cache().handle(function(v) asserts.assert(v.match(Success(0))));
    cache().handle(function(v) asserts.assert(v.match(Success(0))));
    expire.trigger(Noise);
    expire = Future.trigger();
    cache().handle(function(v) asserts.assert(v.match(Success(1))));
    cache().handle(function(v) asserts.assert(v.match(Success(1))));
    expire.trigger(Noise);
    expire = Future.trigger();
    expire.trigger(Noise);
    cache().handle(function(v) asserts.assert(v.match(Success(2))));
    cache().handle(function(v) asserts.assert(v.match(Success(3))));
    
    function err() return Promise.lift(Error.withData('Fail', v++));
    var cache = Promise.cache(err);
    function getError(o:Outcome<Dynamic, Error>):Int
      return switch o {
        case Failure(e): e.data;
        case Success(_): throw 'assert';
      }
    cache().handle(function(o) asserts.assert(getError(o) == 4));
    cache().handle(function(o) asserts.assert(getError(o) == 5));
    
    return asserts.done();
  }
  #end
  
}
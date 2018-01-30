package;

using tink.CoreApi;

class Promises extends Base {

  function testRecover() {
    var p:Promise<Int> = new Error("test");
    p.recover(function (_) return 4).handle(assertEquals.bind(4));
    p.recover(function (_) return Future.sync(5)).handle(assertEquals.bind(5));
  }

  function testInParallel() {
    
    var counter = 0;
    function make(fail:Bool) 
      return Future.async(function (cb) {
        var id = counter++;
        cb(if (fail) Failure(new Error('error')) else Success(id));
      }, true);

    counter = 0;
    var p = Promise.inParallel([for (i in 0...10) make(i > 5)], true);
    assertEquals(0, counter);
    p.handle(function (o) {
      assertFalse(o.isSuccess());
    });
    assertEquals(7, counter);   
     
    counter = 0;
    var t = Future.trigger();
    var p = Promise.inParallel([t, make(false), make(false)], true);
    assertEquals(0, counter);
    var done = false;
    p.handle(function (o) {
      done = true;
      assertFalse(o.isSuccess());
    });
    assertEquals(2, counter);    
    assertFalse(done);
    t.trigger(Failure(new Error('test')));
    assertTrue(done);
    
    
    counter = 0;
    var p = Promise.inParallel([], true);
    assertEquals(0, counter);
    p.handle(function (o) {
      assertTrue(o.isSuccess());
    });
    assertEquals(0, counter);  
  }
  
  function testInSequence() {
    var counter = 0;
    function make(fail:Bool) 
      return Future.async(function (cb) {
        var id = counter++;
        cb(if (fail) Failure(new Error('error')) else Success(id));
      }, true);

    counter = 0;
    var p = Promise.inSequence([for (i in 0...10) make(i > 5)]);
    assertEquals(0, counter);
    p.handle(function (o) {
      assertFalse(o.isSuccess());
    });
    assertEquals(7, counter);
    counter = 0;
    var p = Promise.inSequence([for (i in 0...10) make(false)]);
    assertEquals(0, counter);
    p.handle(function (o) {
      assertEquals('0,1,2,3,4,5,6,7,8,9', o.sure().join(','));
    });
    assertEquals(10, counter);
  }
  function parse(s:String)
    return switch Std.parseInt(s) {
      case null: Failure(new Error(422, '$s is not a valid integer'));
      case v: Success(v);
    }

  function test() {
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
        .handle(function (x) assertEquals(i, x.sure()));
    }
  }
  
  function testCache() {
    var v = 0;
    function gen() return Promise.lift(v++);
    var expire = Future.trigger();
    var cache = Promise.cache(gen, function() return expire);
    cache().handle(function(v) assertTrue(v.match(Success(0))));
    cache().handle(function(v) assertTrue(v.match(Success(0))));
    expire.trigger(Noise);
    expire = Future.trigger();
    cache().handle(function(v) assertTrue(v.match(Success(1))));
    cache().handle(function(v) assertTrue(v.match(Success(1))));
    expire.trigger(Noise);
    expire = Future.trigger();
    cache().handle(function(v) assertTrue(v.match(Success(2))));
    cache().handle(function(v) assertTrue(v.match(Success(2))));
  }
  
}
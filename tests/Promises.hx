package;

using tink.CoreApi;

class Promises extends Base {
  function testMany() {
    var counter = 0;
    function make(fail:Bool) 
      return Future.async(function (cb) {
        var id = counter++;
        cb(if (fail) Failure(new Error('error')) else Success(id));
      }, true);

    counter = 0;
    var p = Promise.ofMany([for (i in 0...10) make(i > 5)]);
    assertEquals(0, counter);
    p.handle(function (o) {
      assertFalse(o.isSuccess());
    });
    assertEquals(7, counter);
    counter = 0;
    var p = Promise.ofMany([for (i in 0...10) make(false)]);
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
  
}
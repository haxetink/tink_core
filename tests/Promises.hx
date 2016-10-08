package;

using tink.CoreApi;

class Promises extends Base {
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
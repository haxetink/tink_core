package ;

import deepequal.DeepEqual.*;
using tink.CoreApi;

@:asserts
class Outcomes extends Base {
  public function testSure() {
    asserts.assert(4 == Success(4).sure());
    
    throws(
      asserts,
      function () Failure('four').sure(),
      String,
      function (f) return f == 'four'
    );
    throws(
      asserts,
      function () Failure(new Error('test')).sure(),
      Error,
      function (e) return e.message == 'test'
    );
    
    return asserts.done();
  }
  
  public function testEquals() {
    asserts.assert(Success(4).equals(4));
    asserts.assert(!Success(-4).equals(4));
    asserts.assert(!Failure(4).equals(4));
    return asserts.done();
  }
  
  public function testFlatMap() {
    final outcomeI  = Success(5);
    final outcomeII = Failure(true);
        
    asserts.assert(compare(Success(3), outcomeI.flatMap(function (x) return Success(x - 2))));
    asserts.assert(compare(Failure(true), outcomeII.flatMap(function (x) return Success(x - 2))));
    
    asserts.assert(compare(Failure(Right(7)), outcomeI.flatMap(function (x) return Failure(x + 2))));
    //TODO don't understand this
    //asserts.assert(compare(Failure(Left(true)), outcomeII.flatMap(function (x) return Failure(x + 2))));
    return asserts.done();
  }
  
  public function or() {
    var success = Success(1);
    var failure:Outcome<Int, Bool> = Failure(true);
    asserts.assert(success.orNull() == 1);
    asserts.assert(failure.orNull() == null);
        
    asserts.assert(success.or(5) == 1);
    asserts.assert(failure.or(5) == 5);
        
    asserts.assert(success.orTry(Success(2)).match(Success(1)));
    asserts.assert(failure.orTry(Success(2)).match(Success(2)));
    asserts.assert(failure.orTry(Failure(false)).match(Failure(false)));
    
    return asserts.done();
  }
  
}
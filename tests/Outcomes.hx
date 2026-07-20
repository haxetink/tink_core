package ;

import deepequal.DeepEqual.*;
using tink.CoreApi;

@:asserts
class Outcomes extends Base {
  public function testSure() {
    asserts.assert(4 == Success(4).sure());
    
    throws(
      asserts,
      () -> Failure('four').sure(),
      String,
      f -> f == 'four'
    );
    throws(
      asserts,
      () -> Failure(new Error('test')).sure(),
      Error,
      e -> e.message == 'test'
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
    final outcomes = [
      Success(5), 
      Failure(true)
    ];
        
    asserts.assert(compare(Success(3), outcomes[0].flatMap(x -> Success(x - 2))));
    asserts.assert(compare(Failure(true), outcomes[1].flatMap(x -> Success(x - 2))));
    
    asserts.assert(compare(Failure(Right(7)), outcomes[0].flatMap(x -> Failure(x + 2))));
    asserts.assert(compare(Failure(Left(true)), outcomes[1].flatMap(x -> Failure(x + 2))));
    return asserts.done();
  }
  
  public function or() {
    final success = Success(1);
    final failure:Outcome<Int, Bool> = Failure(true);
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

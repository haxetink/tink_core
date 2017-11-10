import tink.core.LazyIterator;
class LazyIterators extends Base {
  function testIterate(){
    var l = LazyIterator.lazy_iterator([1,2,3,4,5]);
    var itr = l.map(x -> x + 1).filter(x -> x > 3);
    var res = itr.fold((x,y) -> x + y, 0);
    assertEquals(res,9);
  }
}

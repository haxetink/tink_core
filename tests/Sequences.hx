package ;

using tink.CoreApi;

class Sequences extends Base {
  function testNull() {
    var count = 0;
    var sequence:Sequence<Int> = null;
    for(i in sequence) count++;
    assertEquals(0, count);
    
    for(i in sequence.copy()) count++;
    assertEquals(0, count);
    
    for(i in sequence.slice(1)) count++;
    assertEquals(0, count);
    
    for(i in sequence.filter(function(v) return false)) count++;
    assertEquals(0, count);
    
    for(i in sequence.map(function(v) return 1)) count++;
    assertEquals(0, count);
    
    assertEquals('[]', sequence.toString());
  }
}
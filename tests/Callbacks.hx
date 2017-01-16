package ;

using tink.CoreApi;

class Callbacks extends Base {
  function testInvoke() {
    var calls = 0;
    var cbs:Array<Callback<Int>> = [
      function () calls++,
      function (_) calls++
    ];  
    cbs.push(cbs.copy());
    
    for (c in cbs) 
      c.invoke(4);
      
    assertEquals(4, calls);
  }
  
  #if (js || flash || haxeVer >= 3.3)
  function testDefer() {
    
    var counter = 0;
    function count() 
      counter++;
    
    Callback.defer(count);
    Callback.defer(count);
    Callback.defer(function () { 
      assertEquals(2, counter); 
    } );
    
    assertEquals(0, counter);
  }
  #end
  
  function testList() {
    var cb = new CallbackList();
    
    assertEquals(cb.length, 0);
    
    var calls = 0,
      calls1 = 0,
      calls2 = 0;
    
    var link1 = cb.add(function () { calls++; calls1++; } ),
      link2 = cb.add(function (_) { calls++; calls2++; });
    
    assertEquals(cb.length, 2);
    
    cb.invoke(true);
    
    assertEquals(2, calls);
    assertEquals(1, calls1);
    assertEquals(1, calls2);
    
    link1.dissolve();
    
    assertEquals(cb.length, 1);
    
    link1.dissolve();
    
    assertEquals(cb.length, 1);
    
    cb.invoke(true);
    
    assertEquals(3, calls);
    assertEquals(1, calls1);
    assertEquals(2, calls2);
    
  }
}
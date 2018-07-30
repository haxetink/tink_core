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
      c.invoke(17);
      
    assertEquals(4, calls);
  }
  
  #if (js || flash || haxe_ver >= 3.3)
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
  
  function testIgnore() {
    var calls = 0;
    var cbNoise:Callback<Noise> = function () calls++;
    var cb:Callback<Int> = cbNoise;
    cb.invoke(17);
    assertEquals(1, calls);
  }
  
  function testSimpleLink() {
    var calls = 0;
    var link:CallbackLink = function () calls++;
    link.dissolve();
    link.dissolve();
    assertEquals(calls, 1);
  }
  
  function testLinkPair() {
    var calls = 0,
      calls1 = 0,
      calls2 = 0;
    
    var link1:CallbackLink = function () { calls++; calls1++; }
    var link2:CallbackLink = function () { calls++; calls2++; }
    var link = link1 & link2;
    
    link.dissolve();
    assertEquals(2, calls);
    assertEquals(1, calls1);
    assertEquals(1, calls2);
    
    link.dissolve();
    assertEquals(2, calls);
    
    link1.dissolve();
    assertEquals(1, calls1);
    
    link2.dissolve();
    assertEquals(1, calls2);
  }
  
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
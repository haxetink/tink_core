package ;

import tink.unit.Assert.*;

using tink.CoreApi;

@:asserts
class Callbacks extends Base {
  public function testInvoke() {
    var calls = 0;
    var cbs:Array<Callback<Int>> = [
      function () calls++,
      function (_) calls++
    ];  
    cbs.push(cbs.copy());
    
    for (c in cbs) 
      c.invoke(17);
      
    asserts.assert(calls == 4);
    return asserts.done();
  }
  
  #if (js || flash || haxe_ver >= 3.3)
  public function testDefer() {
    
    var counter = 0;
    function count() 
      counter++;
    
    Callback.defer(count);
    Callback.defer(count);
    Callback.defer(function () { 
      asserts.assert(counter == 2);
    } );
    
    asserts.assert(counter == 0);
    return asserts.done();
  }
  #end
  
  public function testIgnore() {
    var calls = 0;
    var cbNoise:Callback<Noise> = function () calls++;
    var cb:Callback<Int> = cbNoise;
    cb.invoke(17);
    asserts.assert(calls == 1);
    return asserts.done();
  }
  
  public function testSimpleLink() {
    var calls = 0;
    var link:CallbackLink = function () calls++;
    link.cancel();
    link.cancel();
    asserts.assert(calls == 1);
    return asserts.done();
  }
  
  public function testLinkPair() {
    var calls = 0,
      calls1 = 0,
      calls2 = 0;
    
    var link1:CallbackLink = function () { calls++; calls1++; }
    var link2:CallbackLink = function () { calls++; calls2++; }
    var link = link1 & link2;
    
    link.cancel();
    asserts.assert(calls == 2);
    asserts.assert(calls1 == 1);
    asserts.assert(calls2 == 1);
    
    link.cancel();
    asserts.assert(calls == 2);
    
    link1.cancel();
    asserts.assert(calls1 == 1);
    
    link2.cancel();
    asserts.assert(calls2 == 1);
    return asserts.done();
  }
  
  public function testList() {
    var cb = new CallbackList();
    
    asserts.assert(cb.length == 0);
    
    var calls = 0,
      calls1 = 0,
      calls2 = 0;
    
    var link1 = cb.add(function () { calls++; calls1++; } ),
      link2 = cb.add(function (_) { calls++; calls2++; });
    
    asserts.assert(cb.length == 2);
    
    cb.invoke(true);
    
    asserts.assert(calls == 2);
    asserts.assert(calls1 == 1);
    asserts.assert(calls2 == 1);
    
    link1.cancel();
    
    asserts.assert(cb.length == 1);
    
    link1.cancel();
    
    asserts.assert(cb.length == 1);
    
    cb.invoke(true);
    
    asserts.assert(calls == 3);
    asserts.assert(calls1 == 1);
    asserts.assert(calls2 == 2);
    return asserts.done();
    
  }

  @:include public function testListCompaction() {
    var list = new CallbackList();
    for (i in 0...100)
      list.add(function () {}).cancel();
    asserts.assert(list.length == 0);
    return asserts.done();
  }
}
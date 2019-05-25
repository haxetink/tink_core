package ;

using tink.CoreApi;

@:asserts
class Quotas extends Base {
  public function test() {
    var quota = new Quota(3);
    
    var i = 0;
    var callbacks:Array<CallbackLink> = [];
    
    function handler(cb) {
      i++;
      callbacks.push(cb);
    }
    
    quota.acquire().handle(handler);
    asserts.assert(i == 1);
    quota.acquire().handle(handler);
    asserts.assert(i == 2);
    quota.acquire().handle(handler);
    asserts.assert(i == 3);
    quota.acquire().handle(handler);
    asserts.assert(i == 3);
    quota.acquire().handle(handler);
    asserts.assert(i == 3);
    
    callbacks[0].dissolve();
    asserts.assert(i == 4);
    callbacks[1].dissolve();
    asserts.assert(i == 5);
    
    return asserts.done();
  } 
}
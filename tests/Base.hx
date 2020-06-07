package ;

import haxe.PosInfos;
import tink.core.Either;
import tink.unit.AssertionBuffer;
using tink.CoreApi;

abstract PhysicalType<T>(Either<Class<T>, Enum<T>>) {
  
  function new(v) this = v;
  
  public function toString() 
    return 
      switch this {
        case Left(c): Type.getClassName(c);
        case Right(e): Type.getEnumName(e);
      }
      
  public function check(v:T) 
    return 
      Std.is(v, this.getParameters()[0]);
  
  @:from static public function ofClass<C>(c:Class<C>) 
    return new PhysicalType(Left(c));
    
  @:from static public function ofEnum<E>(e:Enum<E>) 
    return new PhysicalType(Right(e));
}

class Base {
  public function new() {}
  function throws<T>(asserts:AssertionBuffer, f:Void->Void, t:PhysicalType<T>, ?check:T->Bool, ?pos:PosInfos):Void {
    try f()
    catch (e:Dynamic) {
      if (!t.check(e)) asserts.fail('Exception $e not of type $t', pos);
      if (check != null && !check(e)) asserts.fail('Exception $e does not satisfy condition', pos);
      asserts.assert(true, 'Expected throw', pos);
      return;
    }
    asserts.fail('no exception thrown', pos);
  }
  
  function delay(ms:Int):Promise<Noise> {
    return Future.async(function(cb) haxe.Timer.delay(cb.bind(Noise), ms));
  }
}
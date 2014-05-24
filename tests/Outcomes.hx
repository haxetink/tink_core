package ;

using tink.CoreApi;

class Outcomes extends Base {
	function testSure() {
		assertEquals(4, Success(4).sure());
		
		throws(
			function () Failure('four').sure(),
			String,
			function (f) return f == 'four'
		);
		throws(
			function () Failure(new Error('test')).sure(),
			Error,
			function (e) return e.message == 'test'
		);
	}
	
	function testEquals() {
		assertTrue(Success(4).equals(4));
		assertFalse(Success(-4).equals(4));
		assertFalse(Failure(4).equals(4));
	}
	
	function eq<A:EnumValue>(exp:A, found:A) 
		assertTrue(Type.enumEq(exp, found));
	
	function testFlatMap() {
		var outcomes = [
			Success(5), 
			Failure(true)
		];
				
		eq(Success(3), outcomes[0].flatMap(function (x) return Success(x - 2)));
		eq(Failure(true), outcomes[1].flatMap(function (x) return Success(x - 2)));
		
		eq(Failure(Right(7)), outcomes[0].flatMap(function (x) return Failure(x + 2)));
		eq(Failure(Left(true)), outcomes[1].flatMap(function (x) return Failure(x + 2)));
	}
}
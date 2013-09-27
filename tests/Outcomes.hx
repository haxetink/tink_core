package ;

using tink.core.Outcome;
using tink.core.Error;

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
}
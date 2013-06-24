package ;

using tink.core.Outcome;

private class Fail implements ThrowableFailure {
	public function new() {}
	public function throwSelf():Dynamic return throw 'four';
}
class Outcomes extends Base {
	function testSure() {
		assertEquals(4, Success(4).sure());
		
		throws(
			function () Failure('four').sure(),
			String,
			function (f) return f == 'four'
		);
		throws(
			function () Failure(new Fail()).sure(),
			String,
			function (f) return f == 'four'
		);
	}
	
	function testEquals() {
		assertTrue(Success(4).equals(4));
		assertFalse(Success(-4).equals(4));
		assertFalse(Failure(4).equals(4));
	}
}
package tink.core;

enum Either<A,B> {
	Left(a:A);
	Right(b:B);
}
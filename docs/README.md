# Tinkerbell Core Library

[![Build Status](https://travis-ci.org/haxetink/tink_core.svg)](https://travis-ci.org/haxetink/tink_core)
[![Gitter](https://img.shields.io/gitter/room/nwjs/nw.js.svg?maxAge=2592000)](https://gitter.im/haxetink/public)

The `tink_core` lib contains a set of lightweight tools for robust programming.

### Overview

Despite the rather long documentation here, `tink_core` does not exceed 1KLOC. And while was primarily drafted as the basis for the rest of tink, it can be used in isolation or for other libs to build on.

### Getting Started

See the [Install](getting-started/install.md) section.


### Types

  - [Annex](types/annex.md) - Allows "attaching" objects to a specific target
  - [Any](types/any.md) - Alternative to Haxe's `Dynamic`
  - [Callback](types/callback.md) - Callbacks and such
  - [Either](types/either.md) - Represents a value that can have either of two types
  - [Error](types/error.md) - Standard class for errors
  - [Future](types/future.md) - Something is going to happen in the future
  - [Lazy](types/lazy.md) - Primitive for [lazy evaluation](http://en.wikipedia.org/wiki/Lazy_evaluation)
  - [Named](types/named.md) - Basic helper type that holds a name/value pair
  - [Noise](types/noise.md) - Values of a type that always holds nothing
  - [Outcome](types/outcome.md) - Represent the result of an operation that either fails or succeeds
  - [Pair](types/pair.md) - Represents an [ordered pair](http://en.wikipedia.org/wiki/Ordered_pair)
  - [Promise](types/promise.md) - Abstract over [Surprise](types/future?id=surprise) with additional features
  - [Ref](types/ref.md) - Think pointer
  - [Signal](types/signal.md) - Signal implementation that aims at utmost simplicity and full integration with the rest of tink
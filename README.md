# Result Type
## An implementation of Rust's Result in D

### Motive
When working with functional programming one of the purposes is making chained,
shorted and understandable code that can be understandable. This code should be
easy to write, however, there are still some problems whithin D that do not
permit such *fancyness*:
```d
// lets say we are trying to parse strings to int, but not all strings are parsable
import std.algorithm : equal, filter, map;
import std.conv : ConvException, parse;
import std.range : only;

only("1", "45", "a", "6")
	.map!((s) {
		try {
			auto v = s.parse!int();
			return v;
		} catch(ConvException e) {
			return -1;
		}
	})
	.filter!"a > -1"
	.equal([1, 45, 6]);
```

With Result this can be avoided:
```d
import std.algorithm : each, equal, filter, map;

Result!(U, string) parse(U, T)(T value) {
	mixin makeResult;

	import std.conv : cparse = parse, ConvException;
	try {
		auto v = value.cparse!U;
		return Ok(v);
	} catch (ConvException e) {
		return Err(e.msg);
	}
}

only("1", "45", "a", "6")
	.map!(a => parse!int(a))
	.filter!isOk
	.map!unwrap
	.equal([1, 45, 6]);
```

By wrapping the `parse` function to return a Result with an Ok containing the
parsed value if all goes well and Err with the Exceptions message, we can
achieve the above in cleaner way;

### Nogc
Result avoids GC usage. Of course, some methods will need GC because Result
depends on some phobos implementations which make use of it internally. This
happens with conversions used for error output messages.

```d
int i = Result!(int, int).Ok(32).unwrap();
```

The above will use GC to convert `int` to `string`, however the following won't
use it:

```d
int i = Result!(int, string).Ok(32).unwrap();
```

Some ways to go arround this barrier when trying to extract the a value
contained in Result is to use `into` functions. They return the value contained
without safe checks and never assert. This functions are @system as they can
lead to undefined behavior when extracting the Ok value from an Err Result!
```d
auto res = Result!(int, int).Ok(45);
int i;

// always safe check before using intoOk
if (res.isOk())
{
	// now it's safe do extract
	i = (() @trusted => res.intoOk())(); // hacky D way to turn this into @safe
}
```

### BetterC
Result supports BetterC! Every method, but toString, is usable in BetterC,
however error messages will not output the value contained inside Result if the
same cannot be implicitly converted to `string`.
```d
import std.algorithm : each, equal, filter, map;
import std.range : only;

Result!(int, string) parseInt(string value) {
	mixin makeResult;

	if (value == "0") return Ok(0);

	import core.stdc.stdlib : atoi;
	auto v = (() @trusted => value.ptr.atoi())();
	return v == 0 ? Err("Invalid number!") : Ok(v);
}

only("1", "45", "a", "6")
	.map!parseInt
	.filter!isOk
	.map!unwrap
	.equal(only(1, 45, 6));
```

### Syntax
 * Result doesn't have a default initializer, so it **must** always be
	initialized with the `Ok` or `Err` functions or by using `.init`
	```d
	assert(!__traits(compiles, Result!(int,string)));
	assert(__traits(compiles, Result!(int,string).init));
	assert(__traits(compiles, Result!(int,string).Ok(45)));
	assert(__traits(compiles, Result!(int,string).Err("Error!")));
	```
 * Result initialized with `.init` will be Ok and it's value will be initialized
	to it's `.init`
	```d
	assert(Result!(int,string).init.contains(int.init));
	```
 * The mixin `makeResult` can be used inside function scopes explicitly
	returning a result to make writing less verbose
	```d
	Result!(U, string) parse(U, T)(T value) {
		mixin makeResult;

		import std.conv : cparse = parse, ConvException;
		try {
			auto v = value.cparse!U;
			return Ok(v);
		} catch (ConvException e) {
			return Err(e.msg);
		}
	}
	```

### Final thoughts
Removing all the overhead of `exceptions` is the other thing `Result` excels at,
however, using it with phobo's implementations won't do that. This can only
be achieved by implementing the methods from scrath with intent of using
`Result`. But, if one does not care about such things `Result` will still be a
visually appealing alternative that brings much more code readability.

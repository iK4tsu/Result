module result;

import std.traits : isPointer, TemplateOf, TemplateArgsOf;

private version(unittest)
{
	version (D_BetterC) {} else
	{
		import core.exception : AssertError;
		import std.format : format;
	}

	import std.exception : assertThrown;
	import std.meta : AliasSeq;
	import std.traits : isFloatingPoint;
	import std.typecons : Tuple, tuple;

	alias bfloats = AliasSeq!(float,double);
	alias afloats = AliasSeq!(float[],double[]);
	alias basic = AliasSeq!(byte,sizediff_t,byte[],sizediff_t[]);
	alias chars = AliasSeq!(char,dchar,wchar);
	alias strings = AliasSeq!(char[],dchar[],wchar[],string,dstring,wstring);
	alias ubasic = AliasSeq!(ubyte,size_t,ubyte[],size_t[]);

	alias pfloats = AliasSeq!(float*,double*);
	alias pbasic = AliasSeq!(byte*,sizediff_t*);
	alias pchars = AliasSeq!(char*,dchar*,wchar*);
	alias pubasic = AliasSeq!(ubyte*,size_t*);

	alias floats = AliasSeq!(bfloats,afloats,pfloats);
	alias nofloats = AliasSeq!(basic,chars,strings,ubasic,pbasic,pchars,pubasic);

	version(D_BetterC)
		alias all = AliasSeq!(floats,nofloats, NogcToString);
	else
		alias all = AliasSeq!(floats,nofloats, NogcToString, Foo);

	struct NogcToString {
		@safe pure nothrow @nogc
		string toString() { return "Foo"; }
	}

	version(D_BetterC) {} else
	class Foo {}
}

mixin template makeResult()
{
	import std.traits : isInstanceOf;
	static assert (isInstanceOf!(Result, typeof(return)));
	alias Ok = typeof(return).Ok;
	alias Err = typeof(return).Err;
}

struct Result(OkT, ErrT)
	if (!is(OkT == void) && !is(ErrT == void))
{
	@disable this();
	private this(ok payload) {
		_okpayload = payload;
		_state = State.Ok;
	}

	private this(err payload) {
		_errpayload = payload;
		_state = State.Err;
	}

	static Result!(OkT, ErrT) Ok(OkT value)
	{
		Result!(OkT, ErrT) res = Result!(OkT, ErrT)(ok(value));
		return res;
	}

	static Result!(OkT, ErrT) Err(ErrT value)
	{
		Result!(OkT, ErrT) res = Result!(OkT, ErrT)(err(value));
		return res;
	}


	version (D_BetterC) {} else
	/**
	returns: a `string` representing the Result.
	*/
	string toString()
	{
		return this.isOk()
			? "Ok("~_okpayload.toString()~")"
			: "Err("~_errpayload.toString()~")";
	}

	version (D_BetterC) {} else
	///
	unittest {
		assert(Result.Ok(OkT.init).toString() == OkT.init.format!"Ok(%s)");
		assert(Result.Err(ErrT.init).toString() == ErrT.init.format!"Err(%s)");
	}

private:
	noreturn failExpect(in string msg, in string payload)
	{
		import std.algorithm : all, cumulativeFold, each, map, sum;
		import std.range : chain, iota, only, take, zip, walkLength;
		import core.memory : pureMalloc;

		auto iter = only(msg, ": ", payload);
		auto to = iter.map!((a) => a.length).cumulativeFold!"a + b";
		auto from = 1.iota.chain(to.take(2));
		immutable len = iter.map!((a) => a.length).sum;

		// guaranty all ranges have the same length
		only(to.walkLength(), from.walkLength()).all!(l => l == len);

		auto str = (() @trusted pure nothrow @nogc => (cast(char*)(pureMalloc(len)))[0 .. len])();

		iter.each!((s) {
			str[from.front .. to.front] = s;
			from.popFront();
			to.popFront();
		});

		// asserts are not supposed to be catched
		// if one does catch it, then it can lead to undefined behavior
		// str will leak if this is catched
		assert(false, str);
	}


	union {
		ok _okpayload;
		err _errpayload;
	}

	struct ok
	{
		version(D_BetterC) {} else
		string toString()()
		{
			import std.traits : ReturnType, Unqual;
			static if (isPointer!OkT || is(OkT == class))
			{
				import std.format : format;
				return handle.format!"%s";
			}
			else static if (__traits(hasMember, OkT, "toString") && is(Unqual!(ReturnType!(OkT.toString)) == string))
				return handle.toString();
			else
			{
				import std.conv : to;
				return handle.to!string;
			}
		}

		OkT handle;
	}

	struct err
	{
		version(D_BetterC) {} else
		string toString()()
		{
			import std.traits : ReturnType, Unqual;
			static if (isPointer!ErrT || is(ErrT == class))
			{
				import std.format : format;
				return handle.format!"%s";
			}
			else static if (__traits(hasMember, ErrT, "toString") && is(Unqual!(ReturnType!(ErrT.toString)) == string))
				return handle.toString();
			else
			{
				import std.conv : to;
				return handle.to!string;
			}
		}

		ErrT handle;
	}

	enum State
	{
		Ok,
		Err,
	}

	State _state;
}

/// Result: instantiation
@safe pure nothrow @nogc unittest {
	assert(!__traits(compiles, Result!(int, string)()));
	assert( __traits(compiles, Result!(int, string).init));

	assert(Result!(int, string).init.isOk());
	assert(Result!(int, string).init.unwrap() == int.init);

	assert(Result!(int, string).Ok(int.init) == Result!(int, string).init);
	assert(Result!(int, string).Ok(4) != Result!(int, string).init);

	assert(Result!(int, string).Err("Error!").isErr());
	assert(Result!(int, string).Err("Error!").containsErr("Error!"));
}

version(D_BetterC)
/// Result: instantiation
@safe pure nothrow @nogc unittest {
	// BetterC error outputs does not display types which aren't
	// implicitly converted to string. This way we can have all methods @nogc.
	assert(Result!(int, string).Err("Error!").unwrapErr() == "Error!");

	// If an error were to be asserted the Output would be the assert error
	// message only .
}

version(D_BetterC) {} else
/// Result
@safe pure nothrow unittest {
	import std.algorithm : canFind, each, equal, filter, map, sort, uniq;
	import std.array : array;
	import std.exception : assumeWontThrow;

	struct Set(T) {
		Result!(T, string) insert(T value) {
			mixin makeResult;

			if (!data.canFind(value)) {
				data ~= value;
				return Ok(value);
			}
			else return Err(format!"Error inserting '%s' into Set. Set contains value!"(value));
		}

		T[] data;
	}

	auto arr = [1,5,5,4,8,7,15,14,12,12,14].sort();
	Set!int set;

	arr.map!(e => set.insert(e))
		.array
		.filter!isOk
		.map!unwrap
		.equal(arr.uniq)
		.assumeWontThrow;
}

version(D_BetterC) {} else
/// Result
@safe pure nothrow unittest {
	import std.algorithm : canFind, each, equal, filter, map, sort, uniq;
	import std.exception : assumeWontThrow;

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

	auto arr = ["1","5","3","a","45","b"];

	arr.map!(a => parse!int(a))
		.filter!isOk
		.map!unwrap
		.equal([1, 5, 3, 45])
		.assumeWontThrow;
}

version(D_BetterC)
/// Result
@safe nothrow @nogc unittest {
	import std.algorithm : canFind, each, equal, filter, map, sort, uniq;
	import std.range : enumerate, only;
	import std.exception : assumeWontThrow;

	Result!(int, string) parseInt(string value) {
		mixin makeResult;

		if (value == "0") return Ok(0);

		import core.stdc.stdlib : atoi;
		auto v = (() @trusted => value.ptr.atoi())();
		return v == 0 ? Err("Invalid number!") : Ok(v);
	}

	only("1", "5", "0", "3", "a", "45", "b")
		.map!parseInt
		.filter!isOk
		.map!unwrap
		.equal(only(1, 5, 0, 3, 45));
}


/**
Params:
	value = value to check.

Returns: `true` if Result is Ok with the given value.
*/
bool contains(OkT,ErrT)(auto ref Result!(OkT, ErrT) result, OkT value)
{
	return result.isOk() && result._okpayload.handle == value;
}

/// Contains: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isFloatingPoint!T)
			assert(!R1.Ok(T.init).contains(T.init)); // nanF <> nanF
		else
			assert( R1.Ok(T.init).contains(T.init));

		assert( R2.Ok(R1.init).contains(R1.init));
		assert(!R1.Err(T.init).contains(T.init));
		assert(!R2.Err(R1.init).contains(R1.init));
	}
}

/// Contains
@safe pure nothrow @nogc unittest {
	assert( Result!(int,string).Ok(9).contains(9));
	assert(!Result!(int,string).Ok(0).contains(9));
}


/**
Params:
	value = value to check.

Returns: `true` if Result is Err with the given value.
*/
bool containsErr(OkT, ErrT)(auto ref Result!(OkT, ErrT) result, ErrT value)
{
	return result.isErr() && result._errpayload.handle == value;
}

/// ContainsErr: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isFloatingPoint!T)
			assert(!R1.Err(T.init).containsErr(T.init)); // nanF <> nanF
		else
			assert( R1.Err(T.init).containsErr(T.init));

		assert( R2.Err(R1.init).containsErr(R1.init));
		assert(!R1.Ok(T.init).containsErr(T.init));
		assert(!R2.Ok(R1.init).containsErr(R1.init));
	}
}

/// ContainsErr
@safe pure nothrow @nogc unittest {
	assert( Result!(int,string).Err("Success").containsErr("Success"));
	assert(!Result!(int,string).Err("Fails").containsErr("Success"));
}


/**
Params:
	msg = message to print if Result is Err.

Returns: the value contained in Result if Ok.
*/
OkT expect(OkT, ErrT)(auto ref Result!(OkT, ErrT) result, in string msg)
{
	if (result.isOk()) return result._okpayload.handle;
	else version(D_BetterC) {
		static if (__traits(compiles, { string s = result._errpayload.handle; }))
			result.failExpect(msg, result._errpayload.handle);
		else
			result.failExpect(msg, "");
	}
	else result.failExpect(msg, result._errpayload.toString());
	assert(false);
}

/// Expect: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
			assert(R1.Ok(T.init).expect("Returns T") is T.init);
		else static if (isFloatingPoint!T)
			assert(R1.Ok(T.init).expect("Returns T") != T.init); // nanF <> nanF
		else
			assert(R1.Ok(T.init).expect("Returns T") == T.init);

		assert(R2.Ok(R1.init).expect("Returns R1") == R1.init);
		assert(is(typeof(R1.Ok(T.init).expect("Same type")) == T));
		assert(is(typeof(R2.Ok(R1.init).expect("Same type")) == R1));
	}
}

version (D_BetterC) {} else
/// Expect: generic tests
@system unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);
		bool expect;

		try {
			expect = true;
			cast(void)R1.Err(T.init).expect("This asserts");
		} catch(Error e) {
			assert(e.msg == format!"This asserts: %s"(T.init));
			expect = false;
		} finally {
			assert(!expect);
		}

		try {
			expect = true;
			cast(void)R2.Err(R1.init).expect("This asserts");
		} catch(Error e) {
			expect = false;
			assert(e.msg == format!"This asserts: %s"(R1.init));
		} finally {
			assert(!expect);
		}
	}
}


/**
Params:
	msg = message to print if Result is Ok.

Returns: the value contained in Result if Err.
*/
ErrT expectErr(OkT, ErrT)(auto ref Result!(OkT, ErrT) result, in string msg)
{
	if (result.isErr()) return result._errpayload.handle;
	else version(D_BetterC) {
		static if (__traits(compiles, { string s = result._okpayload.handle; }))
			result.failExpect(msg, result._okpayload.handle);
		else
			result.failExpect(msg, "");
	}
	else result.failExpect(msg, result._okpayload.toString());
	assert(0);
}

/// ExpectErr: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
			assert(R1.Err(T.init).expectErr("Returns T") is T.init);
		else static if (isFloatingPoint!T)
			assert(R1.Err(T.init).expectErr("Returns T") != T.init); // nanF <> nanF
		else
			assert(R1.Err(T.init).expectErr("Returns T") == T.init);

		assert(R2.Err(R1.init).expectErr("Returns R1") == R1.init);
		assert(is(typeof(R1.Err(T.init).expectErr("Same type")) == T));
		assert(is(typeof(R2.Err(R1.init).expectErr("Same type")) == R1));
	}
}

version (D_BetterC) {} else
/// ExpectErr: generic tests
@system unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);
		bool expect;

		try {
			expect = true;
			cast(void)R1.Ok(T.init).expectErr("This asserts");
		} catch(Error e) {
			assert(e.msg == format!"This asserts: %s"(T.init));
			expect = false;
		} finally {
			assert(!expect);
		}

		try {
			expect = true;
			cast(void)R2.Ok(R1.init).expectErr("This asserts");
		} catch(Error e) {
			expect = false;
			assert(e.msg == format!"This asserts: %s"(R1.init));
		} finally {
			assert(!expect);
		}
	}
}


/**
Converts a `Result!(Result!(OkT, ErrT), ErrT)` to `Result!(OkT, ErrT)`

Params:
	result = result to flatten.

Returns: a `Result!(OkT, ErrT)` with the previous result.
*/
Result!(OkT, ErrT) flatten(OkT, ErrT)(auto ref Result!(Result!(OkT, ErrT), ErrT) result)
{
	mixin makeResult;
	if (result.isOk()) return result._okpayload.handle;
	else return Err(result._errpayload.handle);
}

/// Flatten: generic tests
@safe pure nothrow @nogc unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, T);
		alias R3 = Result!(R2, T);

		assert(R2.Ok(R1.init).flatten() == R1.Ok(T.init));
		assert(R2.Ok(R1.Err(T.init)).flatten() == R1.Err(T.init));
		assert(R2.Err(T.init).flatten() == R1.Err(T.init));

		assert(R3.Ok(R2.init).flatten().flatten() == R1.Ok(T.init));
	}
}


/**
Returns the Ok value without ever asserting.

Returns: the OkT value in Result.
*/
@system pure
OkT intoOk(OkT, ErrT)(auto ref Result!(OkT, ErrT) result)
{
	return result._okpayload.handle;
}

/// IntoOk: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
		{
			assert(R1.Ok(T.init).intoOk() is T.init);
			assert(R2.Ok(R1.init).intoOk().intoOk() is T.init);
		}
		else static if (isFloatingPoint!T)
		{
			assert(R1.Ok(T.init).intoOk() != T.init);
			assert(R2.Ok(R1.init).intoOk().intoOk() != T.init);
		}
		else
		{
			assert(R1.Ok(T.init).intoOk() == T.init);
			assert(R2.Ok(R1.init).intoOk().intoOk() == T.init);
		}

		assert(R2.Ok(R1.init).intoOk() == R1.init);
	}
}


/**
Returns the Err value without ever asserting.

Returns: the ErrT value in Result.
*/
@system pure
ErrT intoErr(OkT, ErrT)(auto ref Result!(OkT, ErrT) result)
{
	return result._errpayload.handle;
}

/// IntoErr: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
		{
			assert(R1.Err(T.init).intoErr() is T.init);
			assert(R2.Err(R1.Err(T.init)).intoErr().intoErr() is T.init);
		}
		else static if (isFloatingPoint!T)
		{
			assert(R1.Err(T.init).intoErr() != T.init);
			assert(R2.Err(R1.Err(T.init)).intoErr().intoErr() != T.init);
		}
		else
		{
			assert(R1.Err(T.init).intoErr() == T.init);
			assert(R2.Err(R1.Err(T.init)).intoErr().intoErr() == T.init);
		}

		assert(R2.Err(R1.init).intoErr() == R1.init);
	}
}


/**
Returns the value in Resut being it Ok or Err.

Returns: the T value in Result.
*/
T intoEither(T)(auto ref Result!(T, T) result)
{
	if (result.isOk()) return result._okpayload.handle;
	else return result._errpayload.handle;
}

@safe pure nothrow @nogc unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
		{
			assert(R1.Ok(T.init).intoEither() is T.init);
			assert(R1.Err(T.init).intoEither() is T.init);
		}
		else static if (isFloatingPoint!T)
		{
			assert(R1.Ok(T.init).intoEither() != T.init);
			assert(R1.Err(T.init).intoEither() != T.init);
		}
		else
		{
			assert(R1.Ok(T.init).intoEither() == T.init);
			assert(R1.Err(T.init).intoEither() == T.init);
		}

		assert(R2.Ok(R1.init).intoEither() == R1.init);
		assert(R2.Err(R1.init).intoEither() == R1.init);
	}
}


/**
Returns: `true` if Result is Ok.
*/
bool isOk(OkT, ErrT)(auto ref in Result!(OkT, ErrT) result)
{
	return result._state == result.State.Ok;
}

/// IsOk: generic tests
@safe pure nothrow @nogc unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		assert( R1.Ok(T.init).isOk());
		assert( R2.Ok(R1.init).isOk());
		assert(!R1.Err(T.init).isOk());
		assert(!R2.Err(R1.init).isOk());
	}
}


/**
Returns: `true` if Result is Err.
*/
bool isErr(OkT, ErrT)(auto ref in Result!(OkT, ErrT) result)
{
	return !result.isOk();
}

/// IsErr: generic tests
@safe pure nothrow @nogc unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		assert( R1.Err(T.init).isErr());
		assert( R2.Err(R1.init).isErr());
		assert(!R1.Ok(T.init).isErr());
		assert(!R2.Ok(R1.init).isErr());
	}
}


/**
Returns: the value contained in Result if Ok.
*/
OkT unwrap(OkT, ErrT)(auto ref Result!(OkT, ErrT) result)
{
	if (result.isOk()) return result._okpayload.handle;
	else version(D_BetterC) {
		static if (__traits(compiles, { string s = result._errpayload.handle; }))
			assert(false, result._errpayload.handle);
		else
			assert(false);
	}
	else assert(false, result._errpayload.toString());
}

/// Unwrap: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
			assert(R1.Ok(T.init).unwrap() is T.init);
		else static if (isFloatingPoint!T)
			assert(R1.Ok(T.init).unwrap() != T.init); // nanF <> nanF
		else
			assert(R1.Ok(T.init).unwrap() == T.init);

		assert(R2.Ok(R1.init).unwrap() == R1.init);
		assert(is(typeof(R1.Ok(T.init).unwrap()) == T));
		assert(is(typeof(R2.Ok(R1.init).unwrap()) == R1));
	}
}

version (D_BetterC) {} else
/// Unwrap: generic tests
@system unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);
		bool expect;

		try {
			expect = true;
			cast(void)R1.Err(T.init).unwrap();
		} catch(Error e) {
			assert(e.msg == T.init.format!"%s");
			expect = false;
		} finally {
			assert(!expect);
		}

		try {
			expect = true;
			cast(void)R2.Err(R1.init).unwrap();
		} catch(Error e) {
			expect = false;
			assert(e.msg == R1.init.format!"%s");
		} finally {
			assert(!expect);
		}
	}
}


/**
Returns: the value contained in Result if Err.
*/
ErrT unwrapErr(OkT, ErrT)(auto ref Result!(OkT, ErrT) result)
{
	if (result.isErr()) return result._errpayload.handle;
	else version(D_BetterC) {
		static if (__traits(compiles, { string s = result._okpayload.handle; }))
			assert(false, result._okpayload.handle);
		else
			assert(false);
	}
	else assert(false, result._okpayload.toString());
}

/// UnwrapErr: generic tests
unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);

		static if (isPointer!T || is(T == class))
			assert(R1.Err(T.init).unwrapErr() is T.init);
		else static if (isFloatingPoint!T)
			assert(R1.Err(T.init).unwrapErr() != T.init); // nanF <> nanF
		else
			assert(R1.Err(T.init).unwrapErr() == T.init);

		assert(R2.Err(R1.init).unwrapErr() == R1.init);
		assert(is(typeof(R1.Err(T.init).unwrapErr()) == T));
		assert(is(typeof(R2.Err(R1.init).unwrapErr()) == R1));
	}
}

version (D_BetterC) {} else
/// UnwrapErr: generic tests
@system unittest {
	foreach (T; all) {
		alias R1 = Result!(T, T);
		alias R2 = Result!(R1, R1);
		bool expect;

		try {
			expect = true;
			cast(void)R1.Ok(T.init).unwrapErr();
		} catch(Error e) {
			assert(e.msg == T.init.format!"%s");
			expect = false;
		} finally {
			assert(!expect);
		}

		try {
			expect = true;
			cast(void)R2.Ok(R1.init).unwrapErr();
		} catch(Error e) {
			expect = false;
			assert(e.msg == R1.init.format!"%s");
		} finally {
			assert(!expect);
		}
	}
}

module testbetterc;

version(D_BetterC) {} else static assert(false, "Must compile with -betterC");
version(unittest) {} else static assert(false, "Must compile with -unittest");

extern(C) int main() {
	import core.stdc.stdio : puts, printf;
	import result;

	static foreach (test; __traits(getUnitTests, result)) {
		printf("Running %.*s\n", cast(int)test.stringof.length, test.stringof.ptr);
		test();
	}
	puts("Tests ran successfully");
	return 0;
}

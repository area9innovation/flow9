import { Minimatch } from 'minimatch';

// vscode-languageclient validates file operation globs with Minimatch#makeRe(),
// which minimatch 11 removed, and 11 is the first release that fixes
// GHSA-g3hv-75wg-m249. The client only checks that the result is truthy and
// then matches paths with match(), so put back a makeRe() that does just that.
// Remove this once vscode-languageclient stops calling makeRe().
class MinimatchRegExp extends RegExp {
	constructor(private readonly matcher: Minimatch) {
		super('(?:)');
	}

	test(path: string): boolean {
		return this.matcher.match(path);
	}
}

const prototype = Minimatch.prototype as Minimatch & { makeRe?(): RegExp | false };

if (typeof prototype.makeRe !== 'function') {
	prototype.makeRe = function (this: Minimatch): RegExp | false {
		return this.set.length > 0 ? new MinimatchRegExp(this) : false;
	};
}

class ResolveStd {
	public static function main() {
		var evalPath = haxe.macro.Context.resolvePath("eval");
		var stdPath = haxe.io.Path.directory(evalPath);
		Sys.println(stdPath);
	}
}

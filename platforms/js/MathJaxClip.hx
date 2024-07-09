import js.Browser;

class MathJaxClip extends NativeWidgetClip {

	public function new(laTeX : String) {
		super();
		if (nativeWidget == null) {
			isNativeWidget = true;
			createNativeWidget();
		}
		loadMathJax(function () {
			MathJaxClip.updateMathJaxClip(this, laTeX);
		});		
	} 

	public static function loadMathJax(cb : Void -> Void) {
		if (untyped __js__("typeof window['MathJax'] === 'undefined'")) {
			Util.loadJS('https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js', 'MathJax-script').then(function (d) {
				cb();
			});
			var mathjaxStyle : Dynamic = Browser.document.createElement('style');
			mathjaxStyle.type = 'text/css';
			var css = '.mathJax-nativeWidget * {position: unset;} ' +
				'mjx-container[display="true"] {margin: 0 ! important} ';
			mathjaxStyle.appendChild(Browser.document.createTextNode(css));
			Browser.document.head.appendChild(mathjaxStyle);
		};
	}

	public static function updateMathJaxClip(clip: Dynamic, latex: String) : Void {
		if (untyped __js__("typeof window['MathJax'] != 'undefined'") && clip.nativeWidget != null) {
			var output = clip.nativeWidget;
			output.innerHTML = '';
			untyped __js__ ("window['MathJax'].texReset()");
			var options = untyped __js__ ("window['MathJax'].getMetricsFor(output)");
			untyped __js__ ("MathJax.tex2chtmlPromise(latex, options).then(function (node) {
				output.appendChild(node);
				window['MathJax'].startup.document.clear();
				window['MathJax'].startup.document.updateDocument();
				setTimeout(function() {
					clip.updateMathJaxSize();
				}, 0);
			})");
			output.classList.add("mathJax-nativeWidget");
		}
	};

	public function updateMathJaxSize() : Void {
		var fs0 = Browser.document.createElement('span');
		fs0.appendChild(Browser.document.createTextNode('X'));
		fs0.style.fontSize = '0';
		fs0.style.visibility = 'hidden';
		nativeWidget.style.display = 'flex';
		nativeWidget.style.alignItems = 'baseline';
		nativeWidget.appendChild(fs0);
		var bbox = nativeWidget.getBoundingClientRect();
		setWidth(bbox.width);
		setHeight(bbox.height);
		var baseLine = fs0.getBoundingClientRect().top - bbox.top;
		//nativeWidget.style.display = null;
		//fs0.remove();

		DisplayObjectHelper.emitEvent(
			this,
			'mathexprresize',
			{
				width  : DisplayObjectHelper.getWidth(this),
				height : DisplayObjectHelper.getHeight(this),
				baseline : baseLine
			}
		);
	};
}

import js.html.URL;
import js.Browser;
import js.html.Event;
import js.lib.Set;
import pixi.core.text.Text in PixiCoreText;
import pixi.core.text.TextMetrics;
import pixi.core.text.TextStyle;
import pixi.core.math.shapes.Rectangle;
import pixi.core.math.Point;

import FlowFontStyle;

using DisplayObjectHelper;

class MathJaxClip extends NativeWidgetClip {

	public function new(laTeX : String) {
		super();
		untyped console.log('loadMathJax nativeWidget.SUPER() -> ', nativeWidget);
		loadMathJax(function () {
			untyped __js__("MathJax.texReset()");
			var mathJaxContainer = untyped __js__ ("window['MathJax'].tex2chtml(laTeX, {em: 12, ex: 6, display: false})");
			untyped __js__("console.log('MathJaxClip.laTeX -> ', laTeX)");
			untyped console.log('MathJaxClip.mathJaxContainer -> ', mathJaxContainer);
			if (nativeWidget != null) {
				untyped __js__("console.log('loadMathJax appendChild')");
				nativeWidget.appendChild(mathJaxContainer);
				nativeWidget.classList.add("mathJax-nativeWidget");
			};			
		});		
	} 

	public static function loadMathJax(cb : Void -> Void) {
		if (untyped __js__("typeof window['MathJax'] === 'undefined'")) {
			untyped __js__("console.log('loadMathJax 1')");
			//https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js
			//js/mathjax/tex-chtml.js
			Util.loadJS('https://cdn.jsdelivr.net/npm/mathjax@3/es5/tex-chtml.js', 'MathJax-script').then(function (d) {
				cb();
			});
			var mathjaxStyle : Dynamic = Browser.document.createElement('style');
			mathjaxStyle.type = 'text/css';
			var css = '.mathJax-nativeWidget * {position: unset;}';
			mathjaxStyle.appendChild(Browser.document.createTextNode(css));
			Browser.document.head.appendChild(mathjaxStyle);
		} else {
			untyped __js__("console.log('loadMathJax 2')");
			RenderSupport.deferUntilRender(cb);
		};
	}

	public static function updateMathJaxClip(clip: Dynamic, latex: String) : Void {
		if (untyped __js__("typeof window['MathJax'] != 'undefined'")) {
			var output = clip.nativeWidget;
			output.innerHTML = '';
			untyped __js__ ("window['MathJax'].texReset()");
			var options = untyped __js__ ("window['MathJax'].getMetricsFor(output)");
			untyped __js__ ("MathJax.tex2chtmlPromise(latex, options).then(function (node) {
				console.log('updateMathJaxClip.node -> ', node);
				output.appendChild(node);
				console.log('updateMathJaxClip.nativeWidgetWithNode -> ', output);
				window['MathJax'].startup.document.clear();
				window['MathJax'].startup.document.updateDocument();
			})");
			untyped __js__("console.log('updateMathJaxClip.options -> ', options)");
		}
	};

}


import js.Browser;
import js.Promise;

class PDF {
	private static var pdfjsLib : Dynamic = null;

	public static function loadPdfJsLibrary(cb : Void -> Void) : Void {
		if (untyped __js__("typeof window['pdfjs-dist/build/pdf'] === 'undefined'")) {
			var onLoad = function() {
				pdfjsLib = untyped Browser.window['pdfjs-dist/build/pdf'];
				pdfjsLib.GlobalWorkerOptions.workerSrc = "js/pdf.js/pdf.worker.min.js";

				cb();
			}
			var head = Browser.document.getElementsByTagName('head')[0];
			var node = Browser.document.createElement('script');
			node.setAttribute("type","text/javascript");
			node.setAttribute("src", 'js/pdf.js/pdf.min.js');
			node.onload = onLoad;
			head.appendChild(node);
		} else {
			cb();
		}
	}

	public static function getPdfDocument(url : String, onOK : Dynamic -> Void, onError : String -> Void) {
		var promise : Promise<Dynamic> = pdfjsLib.getDocument(url).promise;
		promise.then(onOK).catchError(onError);
	}

	public static function getPdfDocumentNumPages(document : Dynamic) {
		return document.numPages;
	}

	public static function getPdfDocumentPage(document : Dynamic, num : Int, onOK : Dynamic -> Void, onError : String -> Void) {
		var promise : Promise<Dynamic> = document.getPage(num);
		promise.then(onOK).catchError(onError);
	}

	public static function getPdfPageDimensions(page : Dynamic) : Array<Float> {
		var viewport = page.getViewport({ scale: 1.0 });
		return [viewport.width, viewport.height];
	}

	public static function makePdfClip() : Dynamic {
		return new PdfClip();
	}

	public static function setPdfClipRenderPage(clip : PdfClip, page : Dynamic, scale : Float) : Void {
		clip.setRenderPage(page, scale);
	}
}
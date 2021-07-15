import js.html.History;
import js.html.ScrollRestoration;
import js.Browser;
import haxe.Json;

class HistoryApi {
    public static function historyState() : String {
        return Json.stringify(Browser.window.history.state);
    }
    public static function pushState(data : String, title : String, url : Array<String>) : Void {
        if (url.length > 0) {
            Browser.window.history.pushState(Json.parse(data), title, url[0]);
        } else {
            Browser.window.history.pushState(Json.parse(data), title);
        }
    }
    public static function replaceState(data : String, title : String, url : Array<String>) : Void {
        if (url.length > 0) {
            Browser.window.history.replaceState(Json.parse(data), title, url[0]);
        } else {
            Browser.window.history.replaceState(Json.parse(data), title);
        }
    }
    public static function historyLength() : Int {
        return Browser.window.history.length;
    }
    public static function back() : Void {
        try {
            Browser.window.history.back();
        } catch (e : Dynamic) {}
    }
    public static function forward() : Void {
        try {
            Browser.window.history.forward();
        } catch (e : Dynamic) {}
    }
    public static function go(delta : Int) : Void {
        try {
            Browser.window.history.go(delta);
        } catch (e : Dynamic) {}
    }
    public static function setScrollRestoration(restoration : String) : Void {
        if (restoration == "auto")
            Browser.window.history.scrollRestoration = ScrollRestoration.AUTO;
        else if (restoration == "manual")
            Browser.window.history.scrollRestoration = ScrollRestoration.MANUAL;
    }
    public static function getBrowserURL() : String {
        return Browser.window.location.href;
    }
}
//To upload new splash screen you need to add new splashscreen.js file to js folder (like it is done in flowapps). That will replace this one on build
//Code below adds nice loading indicator, which adapts to window size.
function setSplashScreen() {
	if (getUrlParameter("splashscreen") == "none" || document.getElementsByTagName("canvas").length != 0) {return}
	// specify `splashOptions` object in custom.js with following keys to override splash "skin"
	// unspecified keys will use default values below
	var d = {
			splashSrc: 'images/splash/Area9_innovation_splash.png',
			splashWidth: 630,
			splashHeight: 440,
			progressSrc: 'images/splash/innovation_loader.gif',
			progressTop: '137px',
			progressBottom: 'unset',
			progressLeft: '50%',
			progressWidth: 'unset',
			progressHeight: 'unset',
			progressShown: true,
		},
		op = 'undefined' != typeof splashOptions ? splashOptions : d,
		g = function(key) { return op[key] === undefined ? d[key] : op[key]; },
		w = g('splashWidth'),
		h = g('splashHeight');
		c = document.createElement('div'),
		s = document.createElement('img'),
		wrap = document.createElement('div'),
		css = "width: "+w+"px; height: "+h+"px; top: 50%; left: 50%; transform: translate(-50%, -50%);";
	c.id = 'splash_container';
	c.style.cssText = css+"position: relative; transform-origin: center center;";
	s.id = 'splash';
	s.src = g('splashSrc');
	s.alt = '';
	s.style.position = 'absolute';
	c.appendChild(s);
	if (g('progressShown')) {
		var p = document.createElement('img');
		p.id = 'loading';
		p.src = g('progressSrc');
		p.alt = 'loading';
		p.style.cssText = "position: absolute; transform: translateX(-50%)"
			+"; width: "+g('progressWidth')
			+"; height: "+g('progressHeight')
			+"; top: "+g('progressTop')
			+"; left: "+g('progressLeft')
			+"; bottom: "+g('progressBottom');
		c.appendChild(p);
	}
	wrap.id = 'loading_js_indicator';
	wrap.style.cssText = css+"max-width: 100%; max-height: 100%; position: absolute; overflow: hidden;";
	wrap.appendChild(c);
	var scale = function () {
		var r = wrap.getBoundingClientRect(),
			s = Math.min(r.width/w, r.height/h);
		c.style.transform = "translate(-50%, -50%) scale("+s+")";
	};
	window.onresize = scale;
	document.body.appendChild(wrap);
	scale();
}
setSplashScreen();
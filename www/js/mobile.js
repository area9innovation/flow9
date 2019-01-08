/*
HOW TO USE IT:
<script type="text/javascript" src="mobile.js"></script>
<script type="text/javascript">
	checkForNativeApp(
		"application://", 
		"https://itunes.apple.com/en/app/application/id555555555?mt=5",
		"http://example.com/run.html?name=application", 
		"https://play.google.com/store/apps/details?id=com.example.application",
		"You do not seem to have the App installed, do you want to go download it now?",
		function() {
			swfobject.registerObject("myId", "9.0.277", "expressInstall.swf");
		}
	);
</script>
*/

function checkForNativeApp(iOSAppURL, iOSStoreURL, androidAppURL, androidStoreURL, confirmMessage, cb) {
	var userOS = getOS(); // will either be iOS, Android or unknown
	
	var params = "";
	var href = window.location.href;
	if ( href.indexOf("?") >= 0 ) 
		params = href.substring(href.indexOf("?") + 1);
	
	var appURL = null;
	var storeURL = null;
	
	if ( userOS == 'iOS' ) {
		appURL = iOSAppURL + ((iOSAppURL.indexOf("?") == -1) ? "?" : "&") + params;
		storeURL = iOSStoreURL;
	} else if ( userOS == 'Android' ) {
		appURL = androidAppURL + ((androidAppURL.indexOf("?") == -1) ? "?" : "&") + params;
		storeURL = androidStoreURL;
	}
	
	if ( userOS != 'iOS' && userOS != 'Android' ) {
		if ( cb != null )
			cb();
	} else {
		var timeout;
		function preventPopup() {
			clearTimeout(timeout);
			timeout = null;
			window.removeEventListener('pagehide', preventPopup);
		}
		
		document.location = appURL;
		// This line is useless for Safari, but will close tab on iPad Chrome
		setTimeout(close, 1300);
		timeout = setTimeout(function() {
			if(	confirm(confirmMessage) ) {
				document.location = storeURL;
				// This line is useless for Safari, but will close tab on iPad Chrome
				setTimeout(close, 300);
			}
		}, 1000);
		window.addEventListener('pagehide', preventPopup);
	}
}

function getOS() {
	var ua = navigator.userAgent;
	var userOS = 'unknown';
	
	// determine OS
	if ( ua.match(/iPad/i) || ua.match(/iPhone/i) )
		userOS = 'iOS';
	else if ( ua.match(/Android/i) )
		userOS = 'Android';
	
	return userOS;
}

function getOSVersion(userOS) {
	var userOSver = 'unknown';
	var ua = navigator.userAgent;
	var uaindex = -1;
				
	if ( userOS == 'iOS' )
		uaindex = ua.indexOf( 'OS ' );
	else if ( userOS == 'Android' )
		uaindex = ua.indexOf( 'Android ' );
	
	// determine version
	if ( userOS == 'iOS' && uaindex > -1 )
		userOSver = ua.substr( uaindex + 3, 3 ).replace( '_', '.' );
	else if ( userOS == 'Android' && uaindex > -1 )
		userOSver = ua.substr( uaindex + 8, 3 );

	return userOSver;
}

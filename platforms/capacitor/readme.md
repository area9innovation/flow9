# What is Capacitor

Capacitor is a framework, which allow to run wrapped web application as native mobile application. Capacitor supports both Android and iOS target (currently we have only iOS implemented).

# How it works

Capacitor runs a simple wrapper application with just WKWebView embedded which is configured with capacitor.config.json. It allows to running both web application deployed to a server or embedded web bundle into the app stored locally.
Basically all configuration stored into capacitor.config.json file in the platforms/capacitor folder. Specifications: https://capacitorjs.com/docs/config
Capacitor supports many features of native apps such as associated domains, iOS scheme, etc.


# Building for iOS

To build flow application for iOS target you need to have Xcode installed.
The project is App.xcodeproj. 

### Installing Capacitor

Simply run command `npm install` into platforms/capacitor folder. Note, you need to have Node.JS 18 or higher installed.

### Syncing configuration

Once you have configured your app at capacitor.config.json kindly run `npx cap sync ios` from platforms/capacitor folder. This will copy configuration and web assets if you want it to be embedded.

### .xcconfig files

We use both debug.xcconfig and release.xcconfig for setting up different environments. Their structure is identical:
    APP_NAME = test  // The name of executable file in the package. Also it is the suffix of bundle ID
    APP_VISIBLE_NAME = Test // The label on user's Home screen
    APP_VERSION = 1.0
    BUILD_ID = 4000 
	TARGET_SDK_VERSION = 13.0
    PRODUCT_BUNDLE_IDENTIFIER = dk.area9.test
    URL_SCHEME=${APP_NAME} // the scheme is a suffix of bundle ID by default. 

Also icons and splashscreen may be specified. See platforms/capacitor/ios/App/App/Assets.xcassets files group. Make sure the names and resolutions are the same as in the default
version.

## How to get Universal Links working on local setup

1. (This step is one per App per lifetime): on developer.apple.com -> Certificates, identifiers -> Identifiers -> (click on your app identifier, it should not contain asterisk at the end) -> Edit -> Enable "Associated Domains". 

	Container's identifier, for example, is com.activesim.connect.containertablet, and Prefix(Team ID) is AG9R6ZPL5S

* Local XCode settings update1: in General tab, Identity group, there is a “Bundle Identifier”. Write there exact identifier of the app (see step above). May be you need to change your Team a few settings below and press “Fix” button so there are no warnings on the screen

	If you continue getting errors that it's not possible to locate app's Bundle Id, it's probably your account which you use in the Team dropdown does not have access to the team. To check/fix it, go to developer.apple.com with credentials having access to the required App's Bundle Id and check People tab. If you can't find that buggy account, send an invite to the person

* Local XCode settings update2: in Capabilities tab, enable Associated Domains and add needed domains there, for example “applinks:mysite.com"

* Remove previously installed app with such Bundle ID, and “Run” this project from XCode so app will be installed on the device. 

* (Optional) Check logs of the web server (those which were in the “applinks” settings), there you should see something like "GET /apple-app-site-association … 200 … swcd (unknown version) CFNetwork/758.0.2 Darwin/15.0.0” swcd is probably unique UserAgent identifier related to this Universal Links mechanism. Answer should be 200 (or possibly 304?).

  If you get 404 Not found, check existence of "apple-app-site-association" file in the root of the site (https://mysite.com/apple-app-site-association). Create or edit it accordingly
* In the Notes app, write a new link which corresponds to the path in the appple-app-site-association (it's faster then creating and uploading page on the server with SSL support). Example “https://mysite.com/flow/connect.html”. Click it and your test app should handle the request through new delegate named continueUserActivity or restorationHandler.

## Troubleshooting
 If Safari opens that link then double-check steps above.
 In the browser, you should get your association file back, i.e. https://mysite.com/apple-app-site-association

 Also, using this command can ensure you that app is built with Associated Domains capabilities:
```
 codesign -d --entitlements - filename.ipa
```

 You should see something like this:
```xml
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:mysite.com</string>
        <string>applinks:site2.mysite.com</string>
        ...
    </array>
</dict>
```

Known and expected UL behaviour:

1. If link is already opened in the browser, to open the app one needs to have Universal Link pointing to another domain. The same domain will be opened in the same browser tab.

2. If user long-tapped on the link and chose "Open in new tab" (i.e. not in the app), this choice could be remembered and user might need to long-tap the link and chose "Open in App" to restore UL functionality.

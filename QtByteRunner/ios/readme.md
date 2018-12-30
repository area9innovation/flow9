# Building flow for iOS

To build flow application for iOS target you need to have Xcode installed.
The project is flow.xcodeproj. There are two targets in that project: "bundled" and "generic".

## Generic target:

Generic traget is the generic flow runner which allows to start different flow bytecode files from remote 
server or downloaded to the device (*.bytecode files).

To build iOS project at first you need provisioning profile and code-signing certificate. It may be your developer profile 
and development certificate if you need just to debug/test flow applications on your iOS device. If you need to distribute the 
package across other developers or to publish the package on the market you need AdHoc, Enterprise or AppStore provisioning profile and distribution certificate. Given profile and certificate should be set in the project's build settings "Code Signing"
section.

## Bundled target:

Bundled target contains flow bytecode file ("default.b") in the package resources and starts that bytecode right after launching.
One can specify package's data in the Bytecode.xcconfig file:

### Bytecode.xcconfig
    APP_NAME = test  // The name of executable file in the package. Also it is the suffix of bundle ID
    APP_VISIBLE_NAME = Test // The label on user's Home screen
    APP_VERSION = 1.0
    BUILD_ID = 4000 
    PREPROCESSOR_MACRO = DEFAULT_URL_PARAMETERS=\@\"\" FLOW_EMBEDDED FLOW_DFIELD_FONTS IOS FLOW_COMPACT_STRUCTS BYTECODE_FILE=\@\"default\"
    BUNDLE_ID_PREFIX = dk.area9
    APP_ICON_PREFIX = default
    BUNDLE_ID_10CH_PREFIX = 2DFEM5R927 // In fact it is team ID from Apple dev. account
    URL_SCHEME=${APP_NAME} // the scheme is a suffix of bundle ID by default. 
    NSLOCATION_WHEN_IN_USE_USAGE_DESCRIPTION = Turn on geolocation, please.

Also icons may be specified. See Resources/icons files group. Make sure the names and resolutions are the same as in the default
version.

## How to get Universal Links working on local setup

1. (This step is one per App per lifetime): on developer.apple.com -> Certificates, identifiers -> Identifiers -> (click on your app identifier, it should not contain asterisk at the end) -> Edit -> Enable "Associated Domains". 

	Container's identifier, for example, is com.activesim.connect.containertablet, and Prefix(Team ID) is AG9R6ZPL5S

* Local XCode settings update1: in General tab, Identity group, there is a “Bundle Identifier”. Write there exact identifier of the app (see step above). May be you need to change your Team a few settings below and press “Fix” button so there are no warnings on the screen

	If you continue getting errors that it's not possible to locate app's Bundle Id, it's probably your account which you use in the Team dropdown does not have access to the team. To check/fix it, go to developer.apple.com with credentials having access to the required App's Bundle Id and check People tab. If you can't find that buggy account, send an invite to the person

* Local XCode settings update2: in Capabilities tab, enable Associated Domains and add needed domains there, for example “applinks:newconnectdev2.mheducation.com"

* Remove previously installed app with such Bundle ID (in our setup it could be MHE Connect  or  Test), and “Run” this project from XCode so app will be installed on the device. 

* (Optional) Check logs of the web server (those which were in the “applinks” settings), there you should see something like "GET /apple-app-site-association … 200 … swcd (unknown version) CFNetwork/758.0.2 Darwin/15.0.0” swcd is probably unique UserAgent identifier related to this Universal Links mechanism. Answer should be 200 (or possibly 304?).

  If you get 404 Not found, check existence of "apple-app-site-association" file in the root of the site (https://cloud1.area9.dk/apple-app-site-association). Create or edit it accordingly
* In the Notes app, write a new link which corresponds to the path in the appple-app-site-association (it's faster then creating and uploading page on the server with SSL support). Example “https://newconnectdev2.mheducation.com/flow/connect.html”. Click it and your test app should handle the request through new delegate named continueUserActivity or restorationHandler.

## Troubleshooting
 If Safari opens that link then double-check steps above.
 In the browser, you should get your association file back, i.e. https://cloud1.area9.dk/apple-app-site-association

 Also, using this command can ensure you that app is built with Associated Domains capabilities:
```
 codesign -d --entitlements - filename.ipa
```

 You should see something like this:
```xml
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:newconnectdev2.mheducation.com</string>
        <string>applinks:ls-dev2.mheducation.com</string>
        ...
    </array>
</dict>
```

Known and expected UL behaviour:

1. If link is already opened in the browser, to open the app one needs to have Universal Link pointing to another domain. The same domain will be opened in the same browser tab.

2. If user long-tapped on the link and chose "Open in new tab" (i.e. not in the app), this choice could be remembered and user might need to long-tap the link and chose "Open in App" to restore UL functionality.

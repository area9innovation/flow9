# Webfonts

This is a script which analyzes fonts used in the application and prepares metrics data for script-based language fonts to be used within.

## Usage

When you added script-based font — they are usually for left-to-right languages, such as Arabic, Hebrew etc. — ensure you called the script to enable your application handle metrics properly.
Pass the root directory of application as the only parameter or ensure it is the current dir and call with no params.

The script logs fonts found and wether parsing was successful for each font.

This script modifies resources/fontconfig.json file adding or replacing object iside it by "webfontconfig"/"custom"/"metrics" path, which is associative array having successfully parsed fonts names as keys. This leads that after compilation the application gets this info as built-in data and can use it.
No way other than debugging can exactly determine if application gets the info, hence there was approximation implemented as a back up algo that has shown itself also quite well and we still have some issues related to BiDi which may or may not relate to letter-level text measurement.
BTW, if fontconfig.json is changed, you may ensure you get the info in WebFontsConfig field of RenderSupportJSPixi class after fonts are loaded.
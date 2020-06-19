# Webfonts

This is a script which analyzes fonts used in the application and prepares metrics data for script-based language fonts to be used within.

## Usage

When you added script-based font — they are usually for right-to-left languages, such as Arabic, Hebrew etc. — ensure you called the script to enable your application handle metrics properly.
Pass the root directory of application as the only parameter or ensure it is the current dir and call with no params.

The script logs fonts found and wether parsing was successful for each font.

This script modifies resources/fontconfig.json file adding or replacing object inside it by "webfontconfig"/"custom"/"metrics" path, which is associative array having successfully parsed fonts names as keys. This leads that after compilation the application gets this info as built-in data and can use it.
No way other than debugging can exactly determine if application gets the info, hence there was approximation implemented as a back up algo that has shown itself also quite well and we still have some issues related to BiDi which may or may not relate to letter-level text measurement.
BTW, if fontconfig.json is changed, you may ensure you get the info in WebFontsConfig field of RenderSupport class after fonts are loaded.

## Testing

To test collected metrics (or approximation algo) works, we must ensure each of the letters are measured correctly in any of two or four available forms.
Good testing examples are «فيلايت» and «دولار» words; former has all three letter forms except isolated, hence most of the letters linked together, latter has letters in isolated forms.
Selecting word fragments we can ensure selection boundary embraces letters we selected, without taking too much. If it takes too much, that means fragment selected is measured as separated word without connections to remaining parts and letter taking appropriate form; final and isolated forms often have more advance width, that's why.
Also there is a ligature «لا» in both words, which is made of letters «ل» and «ا». The ligature must be able to be selected as a whole and also as any half.
For tester unprepared for Arabic script it can be useful to delete selected letters and then undo, to ensure selected letters disappear and remainders of the word link together.
This often works exactly as described, except for letters that have no medial/initial forms — in that case remaining parts won't be connected.
Also when a tester deletes a part of «لا» ligature, one of «ل» and «ا» letters should remain and connect (for remaining «ل») or disconnect (for remaining «ا») the word.
Arabic reader can test the feature in natural way. 
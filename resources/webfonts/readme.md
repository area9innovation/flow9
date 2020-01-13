# Webfonts

This is a script which analyzes fonts used in the application and prepares metrics data for script-based language fonts to be used within.

## Usage

When you added script-based font — they are usually for left-to-right languages, such as Arabic, Hebrew etc. — ensure you called the script to enable your application handle metrics properly.
Pass the root directory of application as the only parameter or ensure it is the current dir and call with no params. 
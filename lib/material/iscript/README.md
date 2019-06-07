# Introduction #
## Brief description ##

IScript is an UI scripting system, which can be useful for automating some UI actions and creating various UI tests.

## Usage ##

To be able to record IScript, application should be run with command-line parameter `recordiscript=true` or `recordiscript=1`.
After run there will be the IScript panel on the upper side of the screen. It allows to record script, run it,
save it in file, restore from file (replace current or concatenate both scripts), open a directory of test files (batch test files)
for their sequential execution. Also it allows to modify current script with some actions, like writing some predefined value
into some input instead of recorded, or output particular behaviour value at some moment into file.

Script from file could be replayed just at the moment of application run, which is useful for UI tests.
This can be achieved by adding the command-line parameter `playiscript=file_name`.
After the end of the repetition, the application closes and returns the execution status - 0 if the script was executed
without errors and 1 if errors occurred during the execution of the script.

Scripts can be grouped in scenarios. Scenario will sequentially execute list of scripts.
Scenario also can be launched with `playiscriptscenario=scenario_name` command-line parameter. In this case exit status will represent a number of failed scripts.

There is possible to run script by passing it with JS messages. You can do this by calling `postMessage` with `{"iscript":"urlencoded script"}`. It can be obtained with corresponding save option. There are two parameters that can be used here: `callid` will be returned with response and `iscriptcheckerrors` for more checks during replay and more verbose errors in response.
Full call will look like this: `window.postMessage('{"callid":"someid","iscriptcheckerrors":true,"iscript":"urlencoded script"}', "*")`.
After replay iscript will send response with `postMessage`, so it can be recieved with `window.addEventListener("message", somefunction)`. Response has the following format: `{"callid":"someid", "status":"OK/ERROR", "errors":"array of errors, if any"}`.

"Save" and "Open" actions work with any available directory. This option works on CPP target only.

Script output is a serialized array of name-value pairs:
"[Pair("balance_before1", -2016.0), Pair("balance_after1", -3024.0)]". Name is the unique name(like "balance_before")
or standard Material component name + behaviour name + hierarchy descriptor(i.e. "MTextInput_content_(1,3)").

## Usage example ##

*You* want to obtain regression test for adding a line in table. First, you should add parameter, which is described in
section above. Next, after app is loaded, click on the "record" button on IScript panel. Now you're recording. Add some
data to the table as usually. Stop recording. You get your script. Save it pushing the "save" button. Now it should be
stored in "iscripts" folder. To replay it you'll need to manually load it with the aid of "load" button and push "play",
or re-run the application from the command line with the corresponding key. In both cases you'll see that your app 
does necessary actions automatically.

That was a simple usage scenario. Let's consider more complex example. Imagine, that we have a field, which is filled
with some calculated data, after we push "Calculate" button. The calculation delay is equal 0.5s. Let's skip all trivial 
actions, which are described in previous paragraph. We have a script and we want to change it so that we will have 
calculated content be saved in file. 

Let's find out the moment when we push our button. For that, click "Show recording sidebar" icon. Switch to the "Current stack"
tab on appeared sidebar panel. Type "Button" in "Search" field and see what happens. We need "click : true" event. Click 
on "Edit" icon on the particular line. See, what is written in "Delay" field. Cancel the dialog.

Push the "plus" button on IScript panel, then choose "Record interactive element" or "Record group of interactive elements".
This depends on field type(i.e column value in some table will be available only after manual code changes and only for
second one). Next we click on field and see the dialog, which contains:

1. Element name
2. Element id
3. Run delay after script start
4. Type of the interaction:
4.1 Event for events like click, focus, etc
4.2 Input for behaviours, that allow user input
4.3 Output for behaviours, which have value that could be logged into file
5. Event/Input/Output behaviour name
6. Alias for input or output(does not present in "event" case)

Fill the delay with value obtained later + *0.5s* (we remember, that it is value delay). For more accurate result it will be better 
to have *0.6s* pause. Choose "Output" action type and "content" output value. Assign a unique name, i.e "Calculated_value".
Push "ADD TO SCRIPT". We've done! 

Now it's time to check our script. Run it by pushing "play" button. Wait till the end of script execution. Open file manager 
and go to the project root folder. Find "iscript_output.txt" file. If it's absent, something went wrong. Try to redo all steps.
If it presents, open it. You should see something like "[Pair("Calculated_value", 1234.0)]. That's it. Now you can store this 
file somewhere and compare it with the new one after any app changes. 

Don't forget to save modified script with "save" button!

# Detailed menu items description #
## File operations (Upper left corner) ##
Alows to create new script (removes the existing one), load script from external file, save current script to the file (last opened or user-chosen) and open batch tests script.

## Start recording ##
Starts the recording of the new script. If current script is not empty, app asks for saving or deleting.
After record start this button is replaced by stop button.

## Replay recording ##
Starts current script, after starting button is replaced by stop button.

## Replay scenario ##
Starts all scripts in scenario sequentally, after starting button is replaced by stop button.

## Open scenario edit dialog ##
This tab contains list of test scripts in scenario. You can add a scenario description in the corresponding field.
Each script can be opened as current script. To do this, click on the rightmost button on the line of the corresponding script.
To move script up/down in list or delete script press corresponding buttons.

## Open test combinations dialog ##
TODO: Add a description here.

## Add behaviour record ##
### Capture single interaction ###
TODO: Add a description here.

### Capture group of interaction elements ###
TODO: Add a description here.

### Capture screenshot ###
Capture screenshot (image) and add it to the script.

### Capture snapshot of logical UI state ###
Capture snapshot of logical UI state of the current elements and add it to the script.

### Define alias for element ###
TODO: Add a description here.

### Define alias for the group of elements ###
TODO: Add a description here.

### Import script ###
TODO: Add a description here.

## Open record settings ##
There are several items, which allow to configure what will be captured during the recording.

### Capture callstack ###
TODO: Add a description here.

### Detailed capture for text inputs ###
If enabled, every change of text input's content will be recorded as a separate item. Also click events on input will be captured too.
Consider final input as "123".
With enabled option script will contain:
+ "1"
+ "12"
+ "123"

Without this option, single item "123" will attend.

### Capture HTTP requests ###
With this option enabled script captures requests to backend.

### Capture mouse events ###
With this option enabled script captures all mouse events, like move and button press.

### Capture keystroke events ###
With this option enabled script captures all keystroke events.

### Capture interaction events ###
With this option enabled script captures mouse interation events, like down, point, inside, focused.

### Capture hover events ###
With this option enabled script captures mouse hover events.

### Capture click events ###
With this option enabled script captures mouse click events.

### Capture appearance events ###
With this option enabled script captures appearance events, like visible and scale.

### Capture value events ###
With this option enabled script captures value change events.

### Capture enable events ###
With this option enabled script captures enable events.

### Capture selection events ###
With this option enabled script captures selection events, like selected, grab_xy and dragged_point.

### Capture input events ###
With this option enabled script captures changing of the input values.

### Capture wigi events ###
With this option enabled script captures wigi events.

### Capture pebble events ###
With this option enabled script captures pebble events.

### Capture custom events ###
With this option enabled script captures custom events.

### Capture misc events ###
With this option enabled script captures misc events, like error and is_ok.

## Open replay settings ##
There are several items, which allow to configure of the iscript replaying.

### Check errors ###
If this option is enabled, the behaviour values are compared with the recorded ones during replay. If there are not equal, an error raises.
If this option is disable, the behaviours replays without checking.

### Verbose output ###
Adds more verbose output.

### Speed ###
Sets the playback speed of the script from 0.1 to 10 (1 by default).

### Timeout, ms ###
Sets the timeout in milliseconds.

### Repeat counts ###
Sets the repeat counts of each event before raising an error.

### Current cursor theme ###
Changes the replay cursor theme.

## Show recording sidebar ##
This button brings additional panel with various useful information. The content of the panel consists of several tabs.

### Script tab ###
This tab contains current script and allows to do various manipulations with script's content
TODO describe manipulations

### Input/Output tab ###
This tab contains all inputs and outputs defined in script.
Each input allows to enter needed value, which automatically replaces the value in the script during replay.
Also input allows to enable asking for value at the moment of its substitution during replay.
On this moment script is paused until user provides value for the input.
Outputs just shown after each replay.

### Aliases tab ###
This tab contains list of all defined aliases. It is useful when you have component named as MTextButton [1,0,0,0,0,1,1,2,3],
so you can't determine quickly where this button is and what it does. Assigning alias helps to track these moments.

### UI Tree tab ###
Shows the UI structure as the tree with the ability to add record with particular element

### Errors tab ###
Shows errors after executing a separate script or scripts scenario. If the script runs without errors, then this panel is empty.








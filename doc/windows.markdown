# Flow: getting started (on Windows)

## Setup & compile the haxe-based flow compiler

First, download and install haXe and neko:

	http://haxe.org/download/

Haxe 3.4.* and 4.* should work.

Now install the "format" and "pixijs" haxe libraries:

	haxelib install format 3.3.0
	haxelib install pixijs 4.8.4
	(format 3.5.0 is not supported on Haxe 3.4.*, pixijs version 5 is not supported at all)

Now check that you can compile the compiler:

	cd c:\flow9\tools\flow
	haxe FlowNeko.hxml

# Install VC runtime

Run
	C:\flow9\platforms\qt\bin\windows\vc_redist.x64.exe

to install the Visual Studio runtime needed for our flow bytecode runner.

# Install Python 3.6.2 or later and Java 11 or later in a 64-bit version

This is required to run the flowc compiler.

## Add flow to your PATH

Now you are ready to start use flow. First add `c:\flow9\bin` to your PATH.

Now test that everything works by compiling & running the first program using
the c++ runner in a command line at `c:/flow9`:

	flowcpp sandbox/hello.flow

If it prints "Hello console" in your console and "Hello window" on the screen, *flow* is alive.

## Compile flow to JS and serve it from a web server

You can also run flow code in JavaScript, served by a web server. First set up a web-server such
that `http://localhost/flow/` points to the `/flow9/www` directory.

If you want to develop on Windows, you can do that using WampServer

	http://www.wampserver.com/

When installing on Windows 8 or later, run the installer as administrator.

Make sure you configure your Skype to not use port 80 in Settings, Advanced, Connection
and uncheck the check box for using port 80 and 443. In Wamp, next "Start all services".
Now add an alias by selecting Apache, Alias directories, Add an alias, and make "flow"
point to `c:/flow9/www`.

# Compile and run as JS

Now you can compile your code to JavaScript like

	flowc1 sandbox/hello.flow js=www/hello.js

or using the older, haxe-based compiler:

	flow --js www/hello.js sandbox/hello.flow

Then open this in your web browser:

	http://localhost/flow/flowjs.html?name=hello

To see the output from this program, open the JavaScript console in your
browser. That is ctrl+shift+J in Chrome in the address line.

## What is really happening when compiling flow code

When you run

	flowcpp sandbox/hello.flow

the program will be compiled to flow bytecode and then interpreted (JITed).
You can also do this manually like this. First compile to bytecode
with a command line like this:

	flowc1 sandbox/hello.flow bytecode=hello.bytecode

or with the haxe-based compiler like:

	flow -c hello.bytecode sandbox/hello.flow

Next, you can interpret that by the C++ runner by typing

	flowcpp hello.bytecode

in a command prompt in `c:\flow9`. This will use the Qt-based C++ flow runner.
See `QtBytecodeRunner/readme.txt` to learn more about this runner.

As you saw above, you can also compile directly to JavaScript by using

	flowc1 sandbox/hello.flow js=www/hello.js

or

	flow --js hello.js sandbox/hello.flow

and run it as

	http://localhost/flow/flowjs.html?name=hello

We use the [PixiJs](https://pixijs.io) rendering library to draw our 
js-compiled applications.

Please note that js target won't run any code unless you render something.

# Using EasyPHP instead of Wamp

You can use EasyPHP instead of Wamp, although it is not as easy.

	http://www.easyphp.org/

When installing WampServer or EasyPHP on Windows 8 or later, run the installer as administrator.

For EasyPHP, go to the administration, under LOCAL FILES click "add an alias" to make 
"flow" point to `c:/flow9/www`. Notice, however, recent versions of EasyPHP like to put 
an "edsa-" prefix to all alias, which is very annoying. To work around that,
you have to hack the http.conf setup manually.

        Alias /flow/ "C:/flow9/www/"

        <Directory "C:/flow9/www/">
                Options Indexes FollowSymLinks MultiViews
                AllowOverride all
                Order allow,deny
                Allow from all
                Require all granted
        </Directory>

There is another way to fix "edsa-" prefix
(https://stackoverflow.com/questions/39339513/how-to-prevent-easyphp-devserver-16-to-add-prefix-edsa-for-alias).
Go to the eds-dashboard subdirectory and edit the index.php file.

Change:
	$new_alias[0]['alias_name'] = 'edsa-' . $_POST['alias_name'];
	<?php echo wordwrap(substr($alias['alias_name'],5), 20, "<br />", true); ?>

For:
	$new_alias[0]['alias_name'] = $_POST['alias_name'];
	<?php echo wordwrap(substr($alias['alias_name'],0), 20, "<br />", true); ?>
	
Remove comments from php.ini for useful extensions:
	extension=php_openssl.dll
	extension=php_curl.dll

Because of this mess, we recommend Wamp instead.

## Why use PixiJs instead of DOM?

We tried to use DOM for rendering, but as a result we got huge DOM trees and browsers were unable to handle them and just kept crashing.
With PixiJs we render everything in one canvas and it can handle and reflect complicated UI trees quite well compared to DOM implementation.

## Sending emails

To be able to send email from your local machine, you should install the SSL certificate.
Though on Windows they are usually installed into the registry, in PHP this is done
by editing the file `php.ini`.

Download the following file: http://curl.haxx.se/ca/cacert.pem to any folder on your
hard drive. In the file `php.ini`, find a line

	openssl.cafile=

If it is commented, uncomment it and append the full path of the downloaded file `cacert.pem`.

## Compiling and running flow bytecode as CGI scripts in apache

Information on this topic can be found in platforms/qt/readme.md
in section "Enabling fast-cgi in apache"

# Memory exhaustion problems

When you compile big programs with `flow`, you might run into a neko memory limit.
If so, you can fix it by reverting to neko 2, and using a patched gc.dll

First, install Haxe with the neko 2.1. Then, go to `...\HaxeToolkit\` folder
where you installed Haxe and neko. You need to extract the
`flow9\resources\neko\neko-2.0.0-win.zip` file in this folder. Then you should copy the
`flow9\resources\neko\1.8.2-2.0.0\unlimited\gc.dll` on top of the one in the
neko-2.0.0 folder.
Now, rename the "neko" folder to "neko-2.1.0", and rename "neko-2.0.0" to "neko".
Restart any command prompts, and you should be able to use the latest haxe with
neko 2.0, with the unlimited heap.

At the end, you will have

- ...\HaxeToolkit\haxe
- ...\HaxeToolkit\neko-2.1        (unused)
- ...\HaxeToolkit\neko            (with neko 2.0)
- ...\HaxeToolkit\neko\gc.dll     (taken from `flow9\resources\neko\1.8.2-2.0.0\unlimited\gc.dll`)

Verify that you can compile and run programs, and you are all set.

## Running in a virtual environment?

### Running Windows guest under VMWare
VMWare with Windows guest seems to be fully functional, including C++ Runner, thanks to 3D support from VMWare.

### Running Windows guest under VirtualBox

VirtualBox with Windows guest support is limited to non-gui mode of C++ runner. All other stuff works fine though.

Running GUI programs with the C++ runner may fail with the error *"OpenGL ARB_framebuffer_object extension is not available"*.
In that case, you can still use the runner for command-line programs by running it with `flowcpp --batch`.
For testing GUI code, use JavaScript instead.

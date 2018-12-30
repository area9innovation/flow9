*Css support.*
======

We have basic CSS support in Tropic. The idea is to use standard CSS syntax and features as much as possible,
where applicable in Tropic. See the Tropic documentation for how to use this feature in Tropic. This document
outlines what parts of CSS we support.

* [Usage](#usage)
* [List of supported properties](#list_of_supported_properties)
* [Selectors and inherit](#selectors)

<h2 id=usage>Usage</h2>

To parse a css stylesheet from a string use the `parseCss` method. The result is a Stylesheet struct:

	Stylesheet(styles : Tree<string, StyleWithSelectors>);

which contains a map from the name of the style to the styles, as well as modifications for each selector. 
A CSS selector is basically different variations, and is used for "hover", "pressed" and similar states.

	StyleWithSelectors(style : CssStyle, selectors : Tree<string, CssStyle>);

The `style` fields contains properties of css style itself. Inside selectors tree all properties for every 
selector stored.

Here is an example:

	cssString = ".sample1
	{
		font-family:Calibri sans-serif;
		font-size:48.0pt;
		font-background:blue;
		color:grey;
		background:blue;
	}
	.sample2
	{
		width:150px;
		height: 104px;
		background:red;
	}";

	sheet = parseCss(cssString);

<h2 id=list_of_supported_properties>List of currently supported css properties</h2>

* [font-family](#font_family)
* [font-size](#font_size)
* [letter-spacing](#letter_spacing)
* [font-background](#font_background)
* [font-weight](#font_weight)
* [font-style](#font_style)
* [text-decoration](#text_decoration)
* [color](#color)
* [opacity](#opacity)
* [background and background-*](#background_and_friends)
* [width](#width)
* [height](#height)
* [border](#border)
* [border-radius and border-*-radius](#border_radius_and_friends)

<h2 id=font_family>font-family</h2>
The font-family property specifies the font for an element. Separate fonts by comma or whitespace. If a font name contains white-space, it must be quoted.
Only first font will be tried to use. If font is not supported, "Book" font will be used.

Here are some examples:

	font-family: Calibri, sans-serif;
	font-family: "Arial Black" sans-serif;


<h2 id=font_size>font-size</h2>
Sets the size of a font. Currently pt and px is equal. Percentage sets size to zero. Will be fixed later.

Here are some examples:

	font-size: 14.0pt;
	font-size: 14px;
	font-size: 80%;

<h2 id=letter_spacing>letter-spacing</h2>
Increases or decreases the space between characters in a text.

Here are some examples:

	letter-spacing: 15px;
	letter-spacing: -5px;

<h2 id=font_background>font-background</h2>
Sets background of the text. See how to correctly set value of property [here](#color).

<h2 id=font_weight>font-weight</h2>
Sets how thick or thin characters in text should be displayed. Only integer values is supported.
If value < 600 font is normal. If value >= 600 font is bold.

Here are some examples:

	font-weight: 400;
	font-weight: 620;


<h2 id=font_style>font-style</h2>
Specifies the font style for a text. Only 'italic' and 'normal' styles supported.

Here are some examples:

	font-style: italic;
	font-style: normal;

<h2 id=text_decoration>text-decoration</h2>
Specifies the decoration added to text. Currently this property support only 'none' value.

Here is an example:

	text-decoration: none;

<h2 id=color>color</h2>
Specifies the color of text.
You can use any color name from lib\colorname.flow. Or the same names from here: https://xkcd.com/color/rgb/
Also you can set color in hex or integer value.

Here are some examples:

	color: blue;
	color: #aabbcc;
	color: 12345;

<h2 id=opacity>opacity</h2>
The opacity property sets the opacity level for an element.

Here is an example:

	opacity: 0.5;

<h2 id=background_and_friends>background and background-*</h2>
The background property sets all the background properties in one declaration.
The background-color property sets the background color of an element.
The background-image property sets one or more background images for an element.
linear-gradient is also supported. See examples for linear gradient [here](#border)
Currently you can set only a color of background. See how to correctly set color value of property [here](#color).
You can use url inside background property.

Here are some examples:

	background: url("images/close.png");
	background-image: url(images/close.png);
	background-color: blue;

<h2 id=width>width</h2>
Sets the width of an element. Currently pt and px is equal. Percentage sets size to zero. Will be fixed later.

Here are some examples:

	width: 14.0pt;
	width: 14px;
	width: 80%;

<h2 id=height>height</h2>
Sets the height of an element. Currently pt and px is equal. Percentage sets size to zero. Will be fixed later.

Here are some examples:

	height: 14.0pt;
	height: 14px;
	height: 80%;

<h2 id=border>border</h2>
Allow you to specify the style, size, and color of an element's border.
Currently only solid style is supported.
linear-gradient is also supported. Syntax for linear-gradient:

	linear-gradient(angle in degrees, color1, color2, any number of other colors);

Here are some examples (order of border-style, border-width and border-color is not important):

	border: solid 30px blue;
	border: solid;
	border: solid 30px;
	border: solid blue;
	border: solid #acb;
	border: linear-gradient(0deg, red, blue, green);

<h2 id=border_radius_and_friends>border-radius and border-*-radius</h2>
The border-radius property is a shorthand property for setting the four border-*-radius properties.
The border-*-radius property defines the shape of the border of the * corner.

Here are some examples:

	border-radius: 2em;
	border-radius: 2em 70px;
	border-radius: 2em 70px 1em;
	border-radius: 2em 70px 1em 1px;
	border-top-left-radius:2em;
	border-top-right-radius:2em;
	border-bottom-right-radius:2em;
	border-bottom-left-radius:2em;

<h2 id=selectors>Selectors and inherit</h2>

Before you will extend any class, or add a selector, you should define this css class first.

You may extend one class with another using syntax:

	parent_class {
		color:black;
		width:20px;
		height:15px;
	}

	class1 parent_class_name {
		color:red;
		width:inherit;
	}

class1 in this example will be equal to

	class1 {
		color:red;
		width:20px;
		height:15px;
	}

You may also set definition to multiply classes with one definition:

	class1, class2, class3 {...}

Parser can parse one type of selectors:

	class_name:selector_name

In Tropico currently we support this selectors:

	:pressed
	:hover
	:disabled

Supported syntax:

	.sample1
	{
		font-family: unreal sans-serif;
		font-size:48.0pt;
		font-background:blue;
		font-style:normal;
		text-decoration:none;
		color:grey;
		width:14;
		height:15;
		background:blue;
	}
	.sample1:pressed
	{
		font-background:red;
		background:red;
	}
	.sample1:hover
	{
		font-background:black;
		background:black;
	}
	.sample1:disabled
	{
		font-background:green;
		background:green;
	}

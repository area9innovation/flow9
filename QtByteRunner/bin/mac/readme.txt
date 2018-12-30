Running on Mac OS X:
	QtByteRunner.app/Contents/MacOS/QtByteRunner --media-path {path to flow directory} {bytecodefile.bytecode}

Exaple:
	Assume QtByteRunner.app is in the flow directory and running learnsmart.b
	QtByteRunner.app/Contents/MacOS/QtByteRunner --media-path . learnsmart.b

Also you could run without bytecode file parameter to download it from the server.

Note:
- Unfortunately it is not possible to have widgets on top of OpenGL layer with Cocoa.
The temporary solution now is to open widgets as separate windows on top of main window.
- Qt does not support Phonon now :(  It looks like the right way is to use QtMultimedia istead.
May be it is the reason why app crashes on creating Phonon player. At least for Lion.


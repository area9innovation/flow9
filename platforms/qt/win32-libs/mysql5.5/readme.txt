Qt Mysql library support for Windows, compiled according to the following for Mysql 5.5:

http://www.pikopong.com/blog/2011/07/11/how-to-enable-mysql-support-in-qt-sdk-for-windows-part-2/


Copy the files in this directory to 

  C:\QtSDK\Desktop\Qt\4.8.9\mingw\plugins\sqldrivers


Copy the libmysql.dll file to the 

  QtByteRunner-build-desktop-Qt_4_7_4_for_Desktop_-_MinGW_4_4__Qt_SDK__Debug\debug

and

  QtByteRunner-build-desktop-Qt_4_7_4_for_Desktop_-_MinGW_4_4__Qt_SDK__Debug\release

folder also.

Now, database natives should work on your Windows box.

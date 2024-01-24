@echo off

rem if JDK was not located
rem if %JAVA_HOME% has been defined then use the existing value
if "%JAVA_HOME%"=="" goto NoExistingJavaHome
echo     Existing value of JAVA_HOME will be used:
echo         %JAVA_HOME%
goto endif

:NoExistingJavaHome
rem display message to the user that %JAVA_HOME% is not available
echo     No Existing value of JAVA_HOME is available.
echo     set JAVA_HOME=path to your jdk root
echo     and retry
goto endif

:endif

set JAVAC=%JAVA_HOME%\bin\javac
set LIBS=%~dp0..\platforms\java\lib\java-websocket-1.5.1\*;%~dp0..\platforms\java\lib\java-jwt-4.4.0\java-jwt-4.4.0.jar
set PATH_TO_FX=%~dp0..\platforms\java\lib\javafx-sdk-11.0.2\windows\lib

:argLoopTop
set FILE=%1
if "%FILE%"=="" goto argLoopEnd
if not "%FILE:.flow=%"=="%FILE%" goto argLoopEnd
shift
goto argLoopTop
:argLoopEnd

if "%FILE%"=="" (
	echo Could not find flow-file in arguments
	exit /b
)

set FILE=%FILE:/=\%
set JAVA_MAIN=%FILE:.flow=%
set JAVA_MAIN=%JAVA_MAIN:\=.%

for %%a in (%JAVA_MAIN:.= %) do set JAVA_CLASS=%%a

echo:
echo Flow file: %FILE%
echo Java flowapp: %JAVA_MAIN%.%JAVA_CLASS%
echo:

rem The runtime
pushd %~dp0..\platforms\java
"%JAVAC%" -d build --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -classpath "%LIBS%" -g com/area9innovation/flow/*.java javafx/com/area9innovation/flow/javafx/*.java
popd

rem Generate the Java for our program
pushd %~dp0..
rd /s /q javagen
popd

call %~dp0\flowc1 java-sub-host=RenderSupport=com.area9innovation.flow.javafx.FxRenderSupport,Native=com.area9innovation.flow.javafx.FxNative java=%~dp0\..\javagen %FILE%
rem call %~dp0/flow --java %~dp0/../javagen %*

pushd %~dp0..

dir javagen\*.java /S /B > temp_java_files.txt

rem Compile the generated code
"%JAVAC%" -d javagen/build  -Xlint:unchecked -encoding UTF-8 --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -cp "%LIBS%";platforms/java/build/ @temp_java_files.txt

del temp_java_files.txt

rem Run the program!
java --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -cp "%LIBS%";platforms/java/build;javagen/build com.area9innovation.flow.javafx.FxLoader --flowapp="%JAVA_MAIN%.%JAVA_CLASS%" %*
popd

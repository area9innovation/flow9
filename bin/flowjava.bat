@echo off
Setlocal EnableDelayedExpansion

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
set FLOW=%~dp0..
set JAVAGEN=%FLOW%\javagen
set TMP_FILE=%JAVAGEN%\temp_java_files.txt
set LIB=%FLOW%\platforms\java\lib
set BUILD_DIR=%FLOW%\platforms\java\build

set LIBS=%LIB%\java-websocket-1.5.1\*
for %%f in (%LIB%\*.jar) do set LIBS=!LIBS!;%%f
set PATH_TO_FX=%LIB%\javafx-sdk-17.0.12\windows\lib

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
pushd %FLOW%\platforms\java
"%JAVAC%" -d build --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -classpath "!LIBS!" -g com/area9innovation/flow/*.java javafx/com/area9innovation/flow/javafx/*.java
popd
if errorlevel 1 goto :eof

rem Generate the Java for our program
rd /s /q %JAVAGEN%
call %~dp0\flowc1 java-sub-host=RenderSupport=com.area9innovation.flow.javafx.FxRenderSupport,FlowRuntime=com.area9innovation.flow.javafx.FxFlowRuntime java=%JAVAGEN% %FILE%
if errorlevel 1 goto :eof

dir %JAVAGEN%\*.java /S /B > %TMP_FILE%

rem Compile the generated code

"%JAVAC%" -d %JAVAGEN%/build  -Xlint:unchecked -encoding UTF-8 --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -cp %BUILD_DIR% @%TMP_FILE%

del %TMP_FILE%

rem Run the program!
java --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -cp "!LIBS!";%BUILD_DIR%;%JAVAGEN%/build com.area9innovation.flow.javafx.FxLoader --flowapp="%JAVA_MAIN%.%JAVA_CLASS%" %*

endlocal

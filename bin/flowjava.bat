@echo off
pushd .
pushd .

for /d %%i in ("%ProgramFiles%\Java\jdk1.8*") do (set Located=%%i)
rem check if JDK was located
if "%Located%"=="" goto else
rem if JDK located display message to user
rem update %JAVA_HOME%
set JAVA_HOME=%Located%
echo     JAVA_HOME has been set to:
echo         %JAVA_HOME%
goto endif

:else
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
set LIBS=%~dp0..\platforms\java\lib\java-websocket-1.5.1\*:%~dp0..\platforms\java\lib\jjwt-api-0.10.8\jjwt-api-0.10.8.jar
set PATH_TO_FX=%~dp0..\platforms\java\lib\javafx-sdk-11.0.2\windows\lib


rem The runtime
cd %~dp0..\platforms\java
"%JAVAC%" -d build --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -classpath "%LIBS%" -g com/area9innovation/flow/*.java javafx/com/area9innovation/flow/javafx/*.java
popd

rem Generate the Java for our program
call %~dp0/flowc1 java=%~dp0/../javagen %*

rem call %~dp0/flow --java %~dp0/../javagen %*

cd %~dp0..

dir javagen\*.java /S /B > files.txt

rem Compile the generated code
"%JAVAC%" -d javagen/build  -Xlint:unchecked -encoding UTF-8 --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -cp "%LIBS%";platforms/java/build/ @files.txt

del files.txt

set FILE = %*
set empty =
set dot = .
set JAVA_MAIN=%FILE:.flow=!empty!%
set JAVA_MAIN=%JAVA_MAIN:/=!dot!%
set JAVA_MAIN=%JAVA_MAIN:\=!dot!%
set "JAVA_CLASS=%JAVA_MAIN:$=" & set "result=%"

rem Run the program!
java --module-path %PATH_TO_FX% --add-modules javafx.controls,javafx.fxml,javafx.base,javafx.graphics -cp "%LIBS%";platforms/java/build;javagen/build com.area9innovation.flow.javafx.FxLoader --flowapp="%JAVA_MAIN%.%JAVA_CLASS%"
popd

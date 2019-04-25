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


rem The runtime
cd %~dp0..\platforms\java 
"%JAVAC%" -d build -g com/area9innovation/flow/*.java com/area9innovation/flow/javafx/*.java
popd

rem Generate the Java for our program
call %~dp0/flow --java %~dp0/../javagen %*

cd %~dp0..

rem Compile the generated code
"%JAVAC%" -Xlint:unchecked -encoding UTF-8 -cp platforms/java/build/ javagen/*.java

rem Run the program!
java -cp platforms/java/build;. com.area9innovation.flow.javafx.FxLoader %*
popd

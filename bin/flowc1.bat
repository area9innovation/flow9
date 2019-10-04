::java -Xss32m -Xms256m -Xmx4G %argsFor8% -cp src/java/;. -jar %~dp0..\tools\flowc\flowc.jar bin-dir=%~dp0 %*


:: Script for Running Flowc compiler.
:: Make sure you have javac from JDK on your path!
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
set JAR=%JAVA_HOME%\bin\jar
set JAVA=%JAVA_HOME%\bin\java

set BASE_DIR=%~dp0..\

if exist %BASE_DIR%\tools\flowc\flowc.jar (
	"%JAVA%" -jar %BASE_DIR%\tools\flowc\flowc.jar %*
)

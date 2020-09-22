@echo off

PATH %PATH%;%JAVA_HOME%\bin\

where java
if ERRORLEVEL 1 (
	echo Java not found, please install OpenJDK 14 or newer, and set JAVA_HOME to the install location or add java to the path.
	goto :eof
)

for /f tokens^=2-5^ delims^=.-_^" %%j in ('java -fullversion 2^>^&1') do set "jver=%%j"
set argsFor8=
if %jver% == 8 (set argsFor8=-XX:+UseConcMarkSweepGC -XX:ParallelCMSThreads=2)

java -Xss32m -Xms256m -Xmx8G %argsFor8% -cp src/java/;. -jar %~dp0..\tools\flowc\flowc.jar bin-dir=%~dp0 %*

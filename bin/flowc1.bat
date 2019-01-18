::@echo off

::PATH %PATH%;%JAVA_HOME%\bin\
::for /f tokens^=2-5^ delims^=.-_^" %%j in ('java -fullversion 2^>^&1') do set "jver=%%j"
::set argsFor8=
::if %jver% == 8 (set argsFor8=-XX:+UseConcMarkSweepGC -XX:ParallelCMSThreads=2)

::java -Xss32m -Xms256m -Xmx4G %argsFor8% -cp src/java/;. -jar %~dp0..\tools\flowc\flowc.jar bin-dir=%~dp0 %*

:: Use python script to run flowc1
python %~dp0\flowc1 %*

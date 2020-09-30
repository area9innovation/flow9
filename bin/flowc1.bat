@echo off
PATH %PATH%;%JAVA_HOME%\bin\
java -Xss32m -Xms256m -Xmx8G -cp src/java/;. -jar %~dp0..\tools\flowc\flowc.jar bin-dir=%~dp0 %*

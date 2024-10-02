@echo off
PATH %PATH%;%JAVA_HOME%\bin\

where java >nul
if ERRORLEVEL 1 (
	echo Java not found, please install OpenJDK 14 or newer, and set JAVA_HOME to the install location or add java to the path.
	goto :eof
)

java -Xss32m -Xms256m -Xmx1G -cp src/java/;. -jar %~dp0..\tools\flowc_lsp\flowc_lsp.jar bin-dir=%~dp0 %*

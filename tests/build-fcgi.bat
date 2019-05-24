@echo off
call flowc1 file=fcgi.flow java=fcgi verbose=1

echo.
echo * Compiling the generated code
echo   ----------------------------
echo.

javac -encoding UTF-8 -cp ../platforms/java fcgi/com/area9innovation/flow/*.java

echo.
echo * Assembling 'fcgi.jar'
echo   ---------------------
echo.
jar cf fcgi.jar -C ../platforms/java com/area9innovation/flow/
jar feu fcgi.jar com.area9innovation.flow.Main -C fcgi com/area9innovation/flow

echo.
echo Compilation done.
echo.

echo * Starting FastCGI server...
echo   --------------------------
echo.

java -jar fcgi.jar
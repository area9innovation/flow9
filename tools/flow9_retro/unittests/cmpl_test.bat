@set path_flow="../../../"
@set vc_cmplr="C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\VC\Auxiliary\Build\vcvars64"

del "%1.obj" "%1.exe" /s /f /q

@echo Compiling Test
@rem compile to c++
call flow9 test=%1.flow cpp=1

@rem start Visual C++ Command Prompt
call %vc_cmplr%
@rem compile to exe
call cl /EHsc /std:c++17 /I%path_flow% /O2 %1.cpp


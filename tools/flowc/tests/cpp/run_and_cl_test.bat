call flowc force-build=1 cpp-remove-unused-vars=1 file=%1.flow cpp=out/%1.cpp
call cl /I ../../../.. /Ox /Ot /EHsc /GS- /std:c++latest out/%1.cpp
%1.exe

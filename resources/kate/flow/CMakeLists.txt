add_definitions(-DTRANSLATION_DOMAIN=\"kateflowplugin\")
include_directories(${CMAKE_CURRENT_BINARY_DIR})

set(CMAKE_CXX_FLAGS "-O0 -ggdb3")
set(CXXFLAGS "-O0 -ggdb3")
set(CPPFLAGS "-O0 -ggdb3")

add_subdirectory(syntax)

set(kateflowplugin_SRCS
	common.cpp
    Plugin.cpp
    DebugManager.cpp
    DebugView.cpp
    FlowView.cpp
    FlowConfig.cpp
    FlowManager.cpp
    FlowOutput.cpp
    FlowServer.cpp
    LocalsManager.cpp
    StackManager.cpp
    MiParser.cpp
    FlowValueParser.cpp
    DebugSymbols.cpp
    CompilerTextEdit.cpp
    execs/Builder.cpp
    execs/Compiler.cpp
    execs/Runner.cpp
)

set(syntaxhighlighting
	syntax/flow.xml
)

ki18n_wrap_ui(kateflowplugin_SRCS 
	FlowConfig.ui 
	StackLocals.ui 
	BreakPoints.ui 
	RenameDialog.ui 
	FlowOutput.ui
)

# resource for ui file and stuff
qt5_add_resources(kateflowplugin_SRCS plugin.qrc)

add_library(kateflowplugin MODULE ${kateflowplugin_SRCS})
kcoreaddons_desktop_to_json (kateflowplugin kateflowplugin.desktop)

target_link_libraries(kateflowplugin KF5::TextEditor KF5::I18n KF5::IconThemes)

install(TARGETS kateflowplugin DESTINATION ${PLUGIN_INSTALL_DIR}/ktexteditor)
install(TARGETS kateflowplugin DESTINATION ${CMAKE_INSTALL_PREFIX}/bin/ktexteditor)

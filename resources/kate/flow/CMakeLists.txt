add_definitions(-DTRANSLATION_DOMAIN=\"kateflowplugin\")
include_directories(${CMAKE_CURRENT_BINARY_DIR})

set(CMAKE_CXX_FLAGS "-O0 -ggdb3")
set(CXXFLAGS "-O0 -ggdb3")
set(CPPFLAGS "-O0 -ggdb3")

add_definitions(-DDEBUG=1)

add_subdirectory(syntax)

set(kateflowplugin_SRCS
	common.cpp
    Plugin.cpp
    FlowView.cpp
    FlowConfig.cpp
    FlowManager.cpp
    FlowOutput.cpp
    FlowServer.cpp
    Outline.cpp
    CompilerTextEdit.cpp

    execs/Builder.cpp
    execs/Compiler.cpp
    execs/Runner.cpp
    execs/Target.cpp

    tasks/Task.cpp
    tasks/TaskFactory.cpp
    tasks/TaskCompile.cpp
    tasks/TaskLookupDef.cpp
    tasks/TaskLookupType.cpp
    tasks/TaskLookupUses.cpp
    tasks/TaskDumpIDs.cpp
    tasks/TaskOutline.cpp
    tasks/TaskRename.cpp
    tasks/TaskRun.cpp
    tasks/TaskBuild.cpp
    tasks/TaskDebug.cpp
    tasks/TaskManager.cpp

	debug/DebugSymbols.cpp
	debug/DebugView.cpp
	debug/LocalsManager.cpp
    debug/StackManager.cpp
    debug/MiParser.cpp
    debug/DebugManager.cpp
    debug/FlowValueParser.cpp
)

set(syntaxhighlighting
	syntax/flow.xml
)

ki18n_wrap_ui(kateflowplugin_SRCS 
	FlowConfig.ui  
	RenameDialog.ui 
	FlowOutput.ui
	CompileOutput.ui
	LaunchOutput.ui
	DebugOutput.ui

	debug/StackLocals.ui 
	debug/BreakPoints.ui
)

# resource for ui file and stuff
qt5_add_resources(kateflowplugin_SRCS plugin.qrc)

add_library(kateflowplugin MODULE ${kateflowplugin_SRCS})
kcoreaddons_desktop_to_json (kateflowplugin kateflowplugin.desktop)

target_link_libraries(kateflowplugin KF5::TextEditor KF5::I18n)
#KF5::IconThemes

install(TARGETS kateflowplugin DESTINATION ${PLUGIN_INSTALL_DIR}/ktexteditor)
install(TARGETS kateflowplugin DESTINATION ${CMAKE_INSTALL_PREFIX}/bin/ktexteditor)

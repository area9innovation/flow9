#include "core/ByteCodeRunner.h"

#include "qt-backend/DatabaseSupport.h"
#include "qt-backend/QtTimerSupport.h"
#include "qt-backend/CgiSupport.h"
#include "qt-backend/HttpSupport.h"
#include "qt-backend/qfilesysteminterface.h"
#include "qt-backend/NotificationsSupport.h"
#include "qt-backend/StartProcess.h"
#include "qt-backend/QtGeolocationSupport.h"
#include "qt-backend/RunParallel.h"
#include "qt-backend/QWebSocketSupport.h"
#include "qt-backend/QtNatives.h"

#ifdef FLOW_MEDIARECORDER
#include "qt-backend/QMediaStreamSupport.h"
#include "qt-backend/QMediaRecorderSupport.h"
#endif

#include "utils/FileLocalStore.h"

#ifdef FLOW_DEBUGGER
#include "debugger.h"
#endif

#ifdef QT_GUI_LIB
#include "soundsupport.h"
#include "qt-gui/QGLRenderSupport.h"

#include <QApplication>
#include <QScrollArea>
#include <QDesktopWidget>
#include <QScreen>

#include <qt-gui/mainwindow.h>
#include <qt-gui/testopengl.h>

#ifdef FLOW_DEBUGGER
#include "qt-gui/QGLClipTreeBrowser.h"
#endif
#else
#include <QtCore/QCoreApplication>
#endif

#include <QProcess>
#include <QSettings>
#include <QFileInfo>
#include <QDir>
#include <QStringList>
#include <QUrlQuery>

#ifdef QT_GUI_LIB
#include <QMessageBox>
#include <QInputDialog>
#include <QLayout>
#endif

#include <stdio.h>
#ifdef _MSC_VER
    #include <windows.h>
#else
	#include <dirent.h>
	#include <unistd.h>
#endif
#include <stdlib.h>
#include <time.h>

#include <signal.h>

#ifdef FLOW_ANDROID
#define RESOURCE_BASE ":/"
#else
#define RESOURCE_BASE ""
#endif

#ifdef WIN32
#define EXECUTABLE_SCRIPT_EXT ".bat"
#else
#define EXECUTABLE_SCRIPT_EXT ""
#endif

using std::max;
using std::min;

#ifndef NATIVE_BUILD
// --profile-bytecode 2000 --url "http://localhost:81/flow/flowrunner.html?name=program" program.bytecode program.debug
static QString compileFlow(int const flowCompiler, QString const & flow, QString const & flow_path, QStringList const & args, bool /*cgi*/) {
    QFileInfo fileinfo(flow);
    QString base = fileinfo.baseName();
    QString bytecode = base + ".bytecode";
    QString compilerCmd = flowCompiler == 1 ? "flowcompiler1" : "flowc1";
	QString cmd = flowCompiler > 0 ? 
        flow_path + QLatin1String("/bin/") + compilerCmd + EXECUTABLE_SCRIPT_EXT : 
        QLatin1String("neko");
	QStringList arg_list;
	if (flowCompiler > 0) {
		arg_list << QLatin1String("file=") + flow;
		arg_list << QLatin1String("bytecode=") + base + QLatin1String(".bytecode");
		arg_list << QLatin1String("debug=1");
		arg_list << args;
	} else {
		arg_list << flow_path + QLatin1String("/bin/flow.n");
		arg_list << QLatin1String("--compile");
		arg_list << bytecode;
		arg_list << QLatin1String("--debuginfo");
		arg_list << base + QLatin1String(".debug");
		arg_list << args;
		arg_list << flow;
	};
	QProcess p;
    p.start(cmd, arg_list);
    p.waitForFinished(-1);
    QString output = p.readAllStandardOutput() + p.readAllStandardError();
    qDebug().noquote() << output;
    if (p.exitCode() != 0) {
    	cerr << output.toStdString() << endl;
    }

#ifdef QT_GUI_LIB
    if (p.exitCode() != 0) {
        return "";
	}
#endif
    return base;
}
#endif

static void shift_args(int &argc, char *argv[], int cnt)
{
    argc -= cnt;
    memmove(argv+1, argv+1+cnt, sizeof(char*)*(argc-1));
}

#ifdef QT_GUI_LIB
static void loadFonts(QGLRenderSupport *pRenderer, QDir media_dir) {
    media_dir.setFilter(QDir::Dirs);

    QStringList fontFolders = media_dir.entryList();
    for (int i = 0; i < fontFolders.size(); ++i) {
         QString folder = fontFolders.at(i);
         if (folder != "." && folder != "..") {
             pRenderer->LoadFont(folder.toStdString(), "resources/dfont/" + folder);
         }
    }
}
#endif

#ifdef QT_GUI_LIB
//TODO: remove it after update to Qt 5.7
void customMessageOutputHandler(QtMsgType type, const QMessageLogContext &context, const QString &msg)
{
    if (msg.compare("QObject::connect: Cannot connect (null)::stateChanged(QNetworkSession::State) to QNetworkReplyHttpImpl::_q_networkSessionStateChanged(QNetworkSession::State)", Qt::CaseInsensitive) == 0) {
        return;
    }
    QByteArray localMsg = msg.toLocal8Bit();
    switch (type) {
    case QtFatalMsg:
        fprintf(stderr, "Fatal: %s (%s:%u, %s)\n", localMsg.constData(), context.file, context.line, context.function);
        abort();
    default:
        fprintf(stderr, "%s\n", localMsg.constData());
        break;
    }
}
#endif

//#define HANDLE_SIGSEGV
#ifdef HANDLE_SIGSEGV
static ByteCodeRunner *main_runner = NULL;

static void sigsegv_handler(int)
{
    if (main_runner)
    {
        main_runner->PrintCallStack(std::cerr, false);
    }

    signal(SIGSEGV, SIG_DFL);
}
#endif

NativeProgram *load_native_program();

#ifdef FLOW_JIT
FlowJitProgram *loadJitProgram(ostream &e, const std::string &bytecode_file, const std::string &log_file, const unsigned long memory_limit = 0);
#endif

int main(int argc, char *argv[])
{
#ifdef WIN32
    {
        // It enables ANSI escape codes https://en.wikipedia.org/wiki/ANSI_escape_code
        HANDLE h = GetStdHandle(STD_OUTPUT_HANDLE);
        DWORD m = 0;
        GetConsoleMode(h, &m);
        SetConsoleMode(h, m | ENABLE_VIRTUAL_TERMINAL_PROCESSING);
    }
#endif
#ifdef DEBUG_FLOW
    qDebug() << "&Running the debug build.";
#endif

    int mem_prof_step = 0;
    int cpu_prof_step = 0;
    int time_prof_step = 0;
    int gui_prof_cost = 0;
    bool garbage_prof = false, coverage_prof = false;
    int garbage_stack = 5;
    bool disassemble = false;
    bool verbose = false;
    int flowCompiler = 2;
    bool use_jit = true;
	unsigned long jit_memory_limit = 0;
#ifdef FLOW_DEBUGGER
    bool debug = false, gdbmi = false;
#endif
    bool cgi = false;
    bool cgi_headers = false;
    bool gc_stress_test = false;
#ifdef QT_GUI_LIB
    bool cliptree = false;
    bool fake_touch = false;
    bool transparent = false;
    bool no_qglfb = false;
    int fake_dpi = 96;
    int screen_w = 1024;
    int screen_h = 600;
    bool screen_pos_set = false;
    int screen_x = 0;
    int screen_y = 0;
    bool fixed_screen = false;
    int msaa_samples = 16;
    QString fallback_font = "";
#else
	Q_UNUSED(gui_prof_cost)
#endif
    QString media_path = "";
    QStringList flowArgs;
    QStringList flowIncludes;

#ifdef QT_GUI_LIB

    QFile file("flow.config");
    if (file.open(QIODevice::ReadOnly)) {
        QTextStream in(&file);

        while(!in.atEnd()) {
            QString line = in.readLine();
            QStringList fields = line.split("=");
            if (fields.size() == 2) {
                QString key = fields.at(0);
                QString value = fields.at(1);
                if (key == "media-path") {
                    media_path = value;
                } else if (key == "flowcompiler") {
                    QString valueL = value.toLower();
                    if (value == "1" || valueL == "true" || valueL == "flowcompiler")
                        flowCompiler = 1;
                    if (value.isEmpty() || value == "0" || valueL == "false" || valueL == "nekocompiler")
                        flowCompiler = 0;
                    if (value == "2" || valueL == "flowc")
                        flowCompiler = 2;
                } else if (key == "fallback_font") {
                    fallback_font = value;
                } else if (key == "antialiassamples") {
                    msaa_samples = value.toInt();
                }
            }
        }
    }

#endif

    // gathering command-line parameters to keep them later
    QUrl params("https://localhost/flow/flowrunner.html");

    while (argc > 2) {
        if (!strcmp(argv[1], "--flowcompiler")) {
               //Overrides flow.config
               flowCompiler = 1;
               shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--nekocompiler")) {
               //Overrides flow.config
               flowCompiler = 0;
               shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--flowc")) {
            //Overrides flow.config
            flowCompiler = 2;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--profile-memory")) {
            mem_prof_step = atoi(argv[2]);
            use_jit = false;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--profile-bytecode")) {
            cpu_prof_step = atoi(argv[2]);
            use_jit = false;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--profile-time")) {
            time_prof_step = atoi(argv[2]);
            use_jit = false;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--profile-gui-cost")) {
            gui_prof_cost = atoi(argv[2]);
            use_jit = false;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--profile-garbage")) {
            garbage_prof = true;
            use_jit = false;
            garbage_stack = atoi(argv[2]);
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--profile-coverage")) {
            coverage_prof = true;
            use_jit = false;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--url")) {
            params = params.resolved(QUrl(QString(argv[2])));
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--disassemble")) {
            disassemble = true;
            use_jit = false;
            shift_args(argc, argv, 1);
        } else if(!strcmp(argv[1], "--gc-stress-test")) {
            gc_stress_test = true;
            use_jit = false;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--verbose")) {
            verbose = true;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--media-path")) {
            media_path = argv[2];
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--batch")) {
            cgi = true;
            cgi_headers = false;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--cgi")) {
            cgi = true;
            cgi_headers = true;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "-I")) {
            if (flowCompiler > 0) {
                //If several -I <path> are given, flow compiler will get several I=<path> and use first or last one only.
                //-I <path1,path2,path3> will produce I=<path1,path2,path3> and that is good input for flow compiler.
                if (flowCompiler == 2) {
                    flowIncludes << QString(argv[2]);
                } else {
                    flowArgs << "I=" + QString(argv[2]);
                }
            } else {
                flowArgs << "-I " + QString(argv[2]);
            }
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--no-jit")) {
            use_jit = false;
            shift_args(argc, argv, 1);
		} else if (!strcmp(argv[1], "--jit-memory-limit")) {
			jit_memory_limit = strtoul(argv[2], NULL, 10) * 1048576;
			shift_args(argc, argv, 2);
#ifdef FLOW_DEBUGGER
        } else if (!strcmp(argv[1], "--debug")) {
            debug = true;
            use_jit = false;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--debug-mi")) {
            debug = true; gdbmi = true;
            use_jit = false;
            shift_args(argc, argv, 1);
#ifdef QT_GUI_LIB
        } else if (!strcmp(argv[1], "--clip-tree")) {
            cliptree = true;
            shift_args(argc, argv, 1);
#endif
#endif
#ifdef QT_GUI_LIB
        } else if (!strcmp(argv[1], "--touch")) {
            fake_touch = true;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--dpi")) {
            fake_dpi = max(50, atoi(argv[2]));
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--screensize")) {
            screen_w = max(320, atoi(argv[2]));
            screen_h = max(200, atoi(argv[3]));
            shift_args(argc, argv, 3);
        } else if (!strcmp(argv[1], "--screenpos")) {
            screen_pos_set = true;
            screen_x = atoi(argv[2]);
            screen_y = atoi(argv[3]);
            shift_args(argc, argv, 3);
        } else if (!strcmp(argv[1], "--antialiassamples")) {
            msaa_samples = atoi(argv[2]);
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--fixedscreen")) {
           fixed_screen = true;
           screen_w = max(320, atoi(argv[2]));
           screen_h = max(200, atoi(argv[3]));
           shift_args(argc, argv, 3);
        } else if (!strcmp(argv[1], "--ephemeral-heap")) {
            EPHEMERAL_HEAP_SIZE = atoi(argv[2]) * 1048576;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--max-ephemeral-alloc")) {
            MAX_EPHEMERAL_ALLOC = atoi(argv[2]) * 1048576;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--no-qglfb")) {
            // GUI cannot work without qglfb now
            // no_qglfb = true;
            shift_args(argc, argv, 1);
        } else if (!strcmp(argv[1], "--fallback_font")) {
            fallback_font = argv[2];
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--transparent")) {
            transparent = true;
            shift_args(argc, argv, 1);
#endif
        } else if (!strcmp(argv[1], "--max-heap")) {
            MAX_HEAP_SIZE = atoi(argv[2]) * 1048576;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--min-heap")) {
            MIN_HEAP_SIZE = atoi(argv[2]) * 1048576;
            shift_args(argc, argv, 2);
        } else if (!strcmp(argv[1], "--use_utf8_js_style")) {
            setUtf8JsStyleGlobalFlag(true);
            shift_args(argc, argv, 1);
        } else if (argv[1][0] == '-') {
            printf("Unknown argument: %s\n", argv[1]);
            exit(1);
        } else {
            break;
        }
    }

#ifdef QT_GUI_LIB
    QSurfaceFormat format;
    format.setDepthBufferSize(24);
    format.setStencilBufferSize(8);
    format.setVersion(3,0);
    format.setProfile(QSurfaceFormat::CompatibilityProfile);
    format.setOptions(QSurfaceFormat::DeprecatedFunctions);
    format.setSwapBehavior(QSurfaceFormat::DoubleBuffer);
    if (msaa_samples > 1) format.setSamples(msaa_samples);
    //format.setSwapInterval(60);
    if (transparent)
        format.setAlphaBufferSize(8);
    QSurfaceFormat::setDefaultFormat(format);
#endif

    // We need to share the OpenGL context for Qt's QVideoWidget (when used)
    // to work, since otherwise QVideoWidget interferes with our own context
    QCoreApplication::setAttribute(Qt::AA_ShareOpenGLContexts, true);
    QCoreApplication::setAttribute(Qt::AA_UseDesktopOpenGL, true);

#ifdef QT_GUI_LIB
    qInstallMessageHandler(customMessageOutputHandler);
    QCoreApplication *app =
        cgi ? new QCoreApplication(argc, argv)
            : new QApplication(argc, argv);
#else
    QCoreApplication *app = new QCoreApplication(argc, argv);
#endif

    app->setOrganizationName("Area9");
    app->setOrganizationDomain("area9.dk");
    app->setApplicationName("FlowRunner");

    srand(time(NULL)); rand();

    QSettings ini(QSettings::IniFormat, QSettings::UserScope,
                  QCoreApplication::organizationName(),
                  QCoreApplication::applicationName());

    QString config_dir = QFileInfo(ini.fileName()).absolutePath();
    QDir().mkpath(config_dir);

    QDir flowdir;

    if (qEnvironmentVariableIsSet("FLOW")) {
        flowdir.setPath(qEnvironmentVariable("FLOW", QString("")));
    } else {
        flowdir.setPath(QCoreApplication::applicationDirPath());
#if __APPLE__
        // Also need to move out of the app bundle directory structure on Mac OS
        flowdir.cd("../../../../../../../");
#else
        flowdir.cdUp();
        flowdir.cdUp();
        flowdir.cdUp();
        if (!flowdir.path().endsWith("flow9"))
            flowdir.cdUp();
#endif
    }

    QString flow_path = flowdir.path();

    // If no media_path is given, we try the current directory
    if (media_path.isEmpty())
      media_path = ".";

    if (!media_path.endsWith('/') && !media_path.endsWith('\\'))
        media_path += '/';

    if (!flow_path.endsWith('/') && !flow_path.endsWith('\\'))
        flow_path += '/';

    if (verbose) {
        std::cout << "Flow path: " << flow_path.toStdString() << std::endl;
        std::cout << "Media path: " << media_path.toStdString() << std::endl;
    }

    ByteCodeRunner FlowRunner;
    QtTimerSupport QtTimer(&FlowRunner);
    FileLocalStore LocalStore(&FlowRunner);
    DatabaseSupport DbManager(&FlowRunner);
    StartProcess ProcStarter(&FlowRunner);
#ifdef FLOW_MEDIARECORDER
    QMediaStreamSupport MediaStream(&FlowRunner, app->applicationDirPath());
    QMediaRecorderSupport MediaRecorder(&FlowRunner, app->applicationDirPath());
#endif

#ifdef HANDLE_SIGSEGV
    main_runner = &FlowRunner;
    signal(SIGSEGV, sigsegv_handler);
#endif

#ifdef FLOW_DEBUGGER
    Debugger *pdbg = NULL;
    if (debug)
        pdbg = new Debugger(&FlowRunner, gdbmi);
#endif

    CgiSupport *cgihost = NULL;

    if (cgi) {
        cgihost = new CgiSupport(&FlowRunner, cgi_headers);

        FlowRunner.TargetTokens.insert("cgi");
    } else {
        FlowRunner.NotifyStubs = verbose;
    }

    if (gc_stress_test) {
        FlowRunner.enableGCStressTest();
    }

    LocalStore.SetBasePath(QString(config_dir + QString("/flow-local-store/")).toLocal8Bit().constData());

#ifdef QT_GUI_LIB
    QGLRenderSupport *pRenderer = NULL;
    MainWindow *Window = NULL;


    bool enable_gl_test = true;
    bool gl_test_passed = !enable_gl_test;
    if (!cgi)
    {
        Window = new MainWindow();

        std::function<void(bool)> testOpenGLCallback = [
            &gl_test_passed
        ](bool isMultisamplingSupported) mutable {
            if (!isMultisamplingSupported) {
                QSurfaceFormat format = QSurfaceFormat::defaultFormat();
                format.setSamples(-1);
                QSurfaceFormat::setDefaultFormat(format);
            }

            gl_test_passed = true;
        };

        if (enable_gl_test) {
            TestOpenGLWidget *test = new TestOpenGLWidget(testOpenGLCallback);
            Window->setCentralWidget(test);
        }

        if (screen_pos_set) {
            QRect screen = QApplication::primaryScreen()->geometry();
            screen_x = min(screen_x, screen.width() - screen_w);
            screen_y = min(screen_y, screen.height() - screen_h);

            Window->move(screen_x, screen_y);
        }

        Window->resize(screen_w, screen_h);
        Window->show();
        Window->raise();
        Window->activateWindow();

        while(!gl_test_passed) {
            // here is a loop while test is not passed
        }

        pRenderer = new QGLRenderSupport(Window, &FlowRunner, fake_touch, transparent);
        pRenderer->setDPI(fake_dpi);
        double real_density = QApplication::screens().at(QApplication::desktop()->screenNumber())->logicalDotsPerInch();

        pRenderer->setDisplayDensity(real_density / fake_dpi);
        pRenderer->no_qglfb = no_qglfb;
        pRenderer->ProfilingInsnCost = gui_prof_cost;

        QDesktopWidget desktop;
        int desktop_height = desktop.geometry().height();
        int desktop_width = desktop.geometry().width();

        if (fixed_screen || screen_h > desktop_height || screen_w > desktop_width) {
            QScrollArea * scroll = new QScrollArea();
            Window->setCentralWidget(scroll);
            scroll->setWidget(pRenderer);
            pRenderer->resize(screen_w, screen_h);
        } else {
            Window->setCentralWidget(pRenderer);
        }

#ifdef FLOW_DEBUGGER
        if (cliptree)
        {
            QGLClipTreeBrowser *tree = new QGLClipTreeBrowser(pRenderer);
            tree->show();
        }
#endif
    }

    QtSoundSupport Sounder(&FlowRunner);
    QtHttpSupport HttpManager(&FlowRunner);
    QFileSystemInterface FileSystem(&FlowRunner, Window);
    QtNotificationsSupport NotificationsManager(&FlowRunner, cgi);
    QtGeolocationSupport GeolocationManager(&FlowRunner);
    QWebSocketSupport AbstractWebSocketSupport(&FlowRunner);

    RunParallelHost RunParallel(&FlowRunner);

    if (pRenderer)
    {
        pRenderer->SetResourceBase(media_path);
        pRenderer->SetFlowBase(flow_path);

#ifndef FLOW_DFIELD_FONTS
        pRenderer->LoadFont("Book", media_path+"resources/FRABK.TTF");
        pRenderer->LoadFont("Italic", media_path+"resources/FRABKIT.TTF");
        pRenderer->LoadFont("Medium", media_path+"resources/framd.ttf");
        pRenderer->LoadFont("DejaVuSans", media_path+"resources/DejaVuSans.ttf");
#else
        // Scan the font folder for the fonts to load
        loadFonts(pRenderer, QDir(media_path + "resources/dfont/"));
        loadFonts(pRenderer, QDir(flow_path + "resources/dfont/"));

        if (fallback_font.compare("") != 0 && !pRenderer->setFallbackFont(qt2unicode(fallback_font))) {
            cerr << "Error: Failed to set FallbackFont '" << fallback_font.toStdString() << "'" << endl;
        }
#endif
    }
#else // no-gui:
    QtHttpSupport HttpManager(&FlowRunner);
	QFileSystemInterface FileSystem(&FlowRunner);
	QWebSocketSupport AbstractWebSocketSupport(&FlowRunner);
    RunParallelHost RunParallel(&FlowRunner);
	QtNatives qtNatives(&FlowRunner);
#endif // QT_GUI_LIB

#if !COMPILED
#ifdef NATIVE_BUILD
    	// Suppress the 'unused variables' warnings
    	UNUSED(mem_prof_step);
    	UNUSED(cpu_prof_step);
    	UNUSED(time_prof_step);
    	UNUSED(garbage_prof);
    	UNUSED(coverage_prof);
    	UNUSED(garbage_stack);
    	UNUSED(disassemble);
    	UNUSED(use_jit);
    	UNUSED(jit_memory_limit);
    	UNUSED(pdbg);

        FlowRunner.Init(load_native_program());
        FlowRunner.setUrl(params);
        // Here we add all command line arguments of the form: key=value as Url parameters
        QStringList args = app->arguments();
        args.removeFirst();
        for (auto& arg : args) {
        	if (!arg.startsWith(QLatin1String("--"))) {
				int equal = arg.indexOf('=');
				if (equal > 0) {
					QString key = arg.left(equal);
					QString value = arg.mid(equal + 1);
					FlowRunner.setUrlParameter(key, value);
				} else {
					FlowRunner.setUrlParameter(arg, QString());
				}
        	}
		}
        FlowRunner.RunMain();
#else
    if (argc >= 2) {
        QString bytecodeFile = argv[1];

        if (bytecodeFile.endsWith(".flow")) {
            // OK, we need to compile!
            if ((flowCompiler == 2) && (flowIncludes.count() > 0)) {
                flowArgs << "I=" + flowIncludes.join(",");
            }
            QString base = compileFlow(flowCompiler, argv[1], flow_path, flowArgs, cgi);
            if (base.length() == 0) {
            	cerr << "Compilation of " << argv[1] << " with flow path " << flow_path.toStdString() << " and arguments " << flowArgs.join(QLatin1Char(' ')).toStdString() << " failed";
                return 1;
            }

            bytecodeFile = base + ".bytecode";
            QString debugFile = base + ".debug";

            static ExtendedDebugInfo dbg_info;

            if (dbg_info.load_file(debugFile.toStdString()))
                FlowRunner.SetExtendedDebugInfo(&dbg_info);
            else {
                printf("Could not load extended debug info.\n");
                return 1;
            }
        }
        else
        {
            // Load debug info before the bytecode
            if (argc > 2 && argv[2][0] != '-') {
                static ExtendedDebugInfo dbg_info;

                if (dbg_info.load_file(argv[2]))
                    FlowRunner.SetExtendedDebugInfo(&dbg_info);
                else
                    printf("Could not load extended debug info.\n");

                shift_args(argc, argv, 1);
            }
        }

#ifdef FLOW_JIT
        if (use_jit)
        {
			FlowJitProgram *jit = loadJitProgram(cerr, bytecodeFile.toStdString(), verbose ? "flowjit" : "", jit_memory_limit);
            if (!jit) {
            	cerr << "Loading of bytecode " << bytecodeFile.toStdString() << " to jit failed";
                return 1;
            }

            FlowRunner.Init(jit);
            FlowRunner.setBytecodeFilename(bytecodeFile.toStdString());
        }
        else
#endif
        {
            FlowRunner.Init(bytecodeFile.toStdString());
        }

        if (disassemble) {
            FlowRunner.Disassemble(FlowRunner.flow_out, FlowRunner.CodeStartPtr(), FlowRunner.CodeSize());
            return 0;
        }

#ifdef FLOW_DEBUGGER
        if (pdbg) {} else
#endif
        if (mem_prof_step > 0)
            FlowRunner.BeginMemoryProfile("flowprof.mem", mem_prof_step);
        else if (cpu_prof_step > 0)
            FlowRunner.BeginInstructionProfile("flowprof.ins", cpu_prof_step);
        else if (time_prof_step > 0)
            FlowRunner.BeginTimeProfile("flowprof.time", time_prof_step);
        else if (garbage_prof)
            FlowRunner.BeginGarbageProfile(garbage_stack);
        else if (coverage_prof)
            FlowRunner.BeginCoverageProfile("flowprof.cover");

        FlowRunner.setUrl(params);

        if (argc > 2 && !strcmp(argv[2], "--")) {
            // There are arguments to the getUrlParameter
            int i = 3;
            while (argc > i) {
                QString a = argv[i];
                int equal = a.indexOf('=');
                if (equal > 0) {
                    QString key = a.left(equal);
                    QString value = a.mid(equal + 1);
                    FlowRunner.setUrlParameter(key, value);

                    setUtf8JsStyleGlobalFlag(!strcmp(argv[i], "use_utf8_js_style=1"));
                } else {
                    FlowRunner.setUrlParameter(a, QString());
                }
                ++i;
            }
        }

        FlowRunner.RunMain();
    }
    else {
#ifdef QT_GUI_LIB
        QApplication::processEvents();

        if (!QUrlQuery(params.query()).hasQueryItem("name") || !pRenderer) {
            QInputDialog input(pRenderer);

            if (pRenderer)
            {
                input.setWindowTitle("Program URL");
                input.setLabelText("Please enter the program URL:    ");
                input.setTextEchoMode(QLineEdit::Normal);
                input.setTextValue(params.toString());
                input.minimumSizeHint();
                input.layout()->setSizeConstraint(QLayout::SetDefaultConstraint);
                input.setMinimumWidth(800);
            }

            if (!pRenderer || !input.exec() || input.textValue().isEmpty()) {
#endif
                printf("Usage:\n %s [options] [bytecode-file|flow-file [debug-info-file]] [-- key=value*]\n", argv[0]);
                printf("Options:\n"
                       "--flowcompiler         Use flow compiler to produce bytecode (overrides flow.config)\n"
                       "--flowc                Use flowc compiler (3rd gen) to produce bytecode (overrides flow.config)\n"
                       "--nekocompiler         Use legacy compiler to produce bytecode (default, overrides flow.config if set)\n"
                       "--profile-memory N     Profile memory use every N instructions\n"
                       "--profile-bytecode N   Profile bytecode use every N instructions\n"
                       "--profile-time N       Profile time use every N instructions\n"
                       "--profile-garbage N    Profile live objects every full gc; N is stack depth cutoff\n"
                       "--profile-coverage     Profile code coverage: log all instructions executed for the first time\n"
                       "--profile-gui-cost N   Add extra instruction cost to some GUI natives.\n"
                       "--url http://url       Download bytecode from url and set URL parameters\n"
                       "--disassemble          Disassemble the bytecode\n"
                       "--gc-stress-test       Enable GC stress test to find head corruption\n"
                       "--media-path path      Define the path for finding font resources\n"
                       "--verbose              Dump stubbed natives and more debugging info\n"
                       "--batch                Run in batch mode, i.e. with no window or HTTP headers\n"
                       "--cgi                  Run in CGI mode, i.e. with no window, but with HTTP headers\n"
#ifdef FLOW_DEBUGGER
                       "--debug                Run in debug mode, with a GDB-like command line.\n"
                       "--debug-mi             Run in debug mode using a machine-oriented GDB-MI protocol.\n"
#ifdef QT_GUI_LIB
                       "--clip-tree            Show a window presenting a tree view of active clips.\n"
#endif
#endif
#ifdef QT_GUI_LIB
					   "--no-jit               Disable JIT compilation\n"
					   "--jit-memory-limit     Set memory amount available for JIT in mega-bytes\n"
                       "--touch                Enable a fake touchscreen mode in the GUI engine.\n"
                       "--dpi <value>          Report this screen DPI to the flow code.\n"
                       "--screenpos <x> <y>    Open the window at these screen position.\n"
                       "--screensize <w> <h>   Open the window with these inner dimensions.\n"
                       "--antialiassamples <count> Count of samples for multisampling antialiasing.\n"
                       "--fixedscreen <w> <h>  Set these constant dimensions for the flow stage.\n"
                       "--max-heap <m>         Maximum size of the heap in mega-bytes.\n"
                       "--min-heap <m>         Starting size of the heap in mega-bytes.\n"
                       "--ephemeral-heap <m>   Ephemeral heap size in mega-bytes.\n"
                       "--max-ephemeral-alloc <m>  Max ephemeral allocation size in mega-bytes.\n"
                       "--fallback_font <font> Enables lookup of unknown glyphs in the <font>. <font> example - DejaVuSans.\n"
                       "--transparent          Enables GL transparency.\n"
#endif
                       "--use_utf8_js_style    To switch UTF-8 parser to js style (3 bytes or more symbol codes converts into UTF-16).\n"
                       "-I dir                 passes -I parameter to flow compiler\n"
                       "Compiler, media-path, and fallback_font options can also be specified in flow.config file in properties format:\n"
                       "    flowcompiler=flowcompiler|nekocompiler|flowc\n"
                       "    media_path=<your_path>\n"
                       );
                return 1;
#ifdef QT_GUI_LIB
            }

            params = QUrl(input.textValue());

            if (!QUrlQuery(params.query()).hasQueryItem("name")) {
                printf("The URL must include a 'name' query parameter\n");
                return 1;
            }
        }

        qDebug() << "Loader URL: " << params.toString();

        FlowRunner.setUrl(params);
        pRenderer->StartBytecodeDownload(params);
#endif
    }
#endif
#endif

    int rv = 0;

    if (!FlowRunner.IsErrorReported() && (!cgihost || !cgihost->quitPending)) {
#ifdef DEBUG_FLOW
        if (!cgi) {
            qDebug() << "Entering Qt event loop.";
        }
#endif

        rv = app->exec();
        if (rv == 1) {
        	cerr << "app->exec() == 1";
        }
    }
    else if (cgihost && cgihost->quitPending) {
        rv = cgihost->quitCode;
        if (rv == 1) {
        	cerr << "cgihost->quitCode == 1";
        }
    }

#ifdef FLOW_DEBUGGER
    if (gdbmi)
    {
        if (!FlowRunner.IsErrorReported())
            FlowRunner.ReportError(InvalidCall, "The program has exited");
        app->exec();
    }
#endif

    if (FlowRunner.IsErrorReported()) {
    	cerr << "FlowRunner.IsErrorReported()";
        rv = 1;
    }

    delete app;

    return rv;
}

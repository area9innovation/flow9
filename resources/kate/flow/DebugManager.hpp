#pragma once

#include <QStringList>
#include <QProcess>
#include <QUrl>
#include <QTextStream>

#include "FlowConfig.hpp"
#include "FlowOutput.hpp"

namespace flow {

class FlowView;

struct DebugConf {
    QString     executable;
    QString     debuginfo;
    QString     workDir;
    QString     arguments;
    QString     fdbCmd;
    QStringList customInit;
    QStringList srcPaths;
};

class DebugManager : public QObject {
Q_OBJECT
public:
    DebugManager(FlowView& view);
    ~DebugManager();

    void runDebugger(const DebugConf &conf);

    bool hasBreakpoint(QUrl const& url, int line) const;
    int  breakpointIndex(QUrl const& url, int line) const;
    void toggleBreakpoint(QUrl const& url, int line);
    void issueCommand(QString const& cmd);
    void stackFrameSelected(int level);

    void writeConfig(KConfigGroup& config) const;
    void readConfig(const KConfigGroup& config);
    void eraseConfig(KConfigGroup& config);

public Q_SLOTS:
	void slotDebug(int);
    void slotInterrupt();
    void slotStepInto();
    void slotStepOver();
    void slotStepOut();
    void slotContinue();
    void slotKill();

    void slotError(QProcess::ProcessError err);
    void slotReadDebugStdOut();
    void slotReadDebugStdErr();
    void slotDebugFinished(int exitCode, QProcess::ExitStatus status);
    void slotIssueNextCommand();

Q_SIGNALS:
    void signalDebugLocationChanged(QUrl file, int lineNum);
    void signalBreakPointSet(QUrl file, int lineNum);
    void signalBreakPointCleared(const QUrl &file, int lineNum);
    void signalLocalsInfo(QString description);
    void signalStackInfo(QString stack);
    void signalArgsInfo(QString description, int frameIndex);

public:
    struct BreakPoint {
        int  number;
        QUrl file;
        int  line;
    };

    struct LineHandler {
    	virtual ~LineHandler() { }
    	virtual bool matches(const QString& line) const = 0;
    	virtual void handle(const QString&, DebugManager*) = 0;
	};
    struct RegExpLineHandler : public LineHandler {
    	RegExpLineHandler(const QString& m) : lineMatcher(m) { }
    	bool matches(const QString& line) const override {
    		return lineMatcher.exactMatch(line);
    	}
		QRegExp lineMatcher;
	};
    struct ExactMatchLineHandler : public LineHandler {
    	ExactMatchLineHandler(const QString& i, const QString& p) :
    		ignore_(i), prefix_(p) { }
    	bool matches(const QString& line) const override {
    		return line.startsWith(ignore_ + prefix_);
    	}
    	QString getMatch(const QString& line) const {
    		return line.mid(ignore_.size(), line.size() - ignore_.size());
    	}
		QString ignore_;
		QString prefix_;
	};

    void queryLocals();
    void processLine(const QString& output);
    QUrl resolveFileName(const QString &fileName);

    FlowView&           flowView_;
    QProcess            debugProcess_;
    DebugConf           debugConf_;
    QStringList         nextCommands_;
    QString             lastCommand_;
    bool                debugLocationChanged_;
    QList<BreakPoint>   breakPointList_;
    int                 currentFrame_;
    QString             collected_out;
};

}

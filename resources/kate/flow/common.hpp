#pragma once

#include <QMap>
#include <QString>
#include <QDateTime>
#include <QTableWidgetItem>
#include <QPlainTextEdit>
#include <KTextEditor/MainWindow>

namespace flow {

typedef QMap<QString, QDateTime> ProgTimestamps;
typedef QMap<QString, QString> ConfigFile;

QString curIdentifier(KTextEditor::MainWindow* mainWindow);
QString curFile(KTextEditor::MainWindow* mainWindow);
QString stripQuotes(const QString&);
QTableWidgetItem* setNotEditable(QTableWidgetItem* item);

ProgTimestamps progTimestamps(const QString& file, const QString& dir, const QStringList& includes);
bool progTimestampsChanged(const ProgTimestamps& dep1, const ProgTimestamps& dep2);
QByteArray progTimestampsToBinary(const ProgTimestamps&);
ProgTimestamps progTimestampsFromBinary(const QByteArray&);

QString findConfig(const QString& file);
ConfigFile parseConfig(const QString& confName);

// Try to guess the most shallow path, which includes any flow sources / configs.
// This directory is considered a common storage of all flow projects, and is
// used for global refactoring operations like renaming of functions / types,
// which may affect arbitrary set of sources systemwise.
QString findFlowRoot(const QString& file);

inline ConfigFile parseConfigForFile(const QString& file) {
	return parseConfig(findConfig(file));
}

void appendText(QPlainTextEdit* textEdit, const QString& text);

}

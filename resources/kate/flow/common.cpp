#include <QFile>
#include <QFileInfo>
#include <QDateTime>
#include <QDir>
#include <QTextCursor>

#include <KTextEditor/View>

#include "common.hpp"

namespace flow {

QString curFile(KTextEditor::MainWindow* mainWindow) {
	return mainWindow->activeView()->document()->url().toLocalFile();
}

QString curIdentifier(KTextEditor::MainWindow*  mainWindow) {
	KTextEditor::View* activeView = mainWindow->activeView();
	if (!activeView || !activeView->cursorPosition().isValid()) {
		return QString();
	}
	const int line = activeView->cursorPosition().line();
	const int col = activeView->cursorPosition().column();
	QString linestr = activeView->document()->line(line);

	int startPos = qMax(qMin(col, linestr.length() - 1), 0);
	int endPos = startPos;
	while (startPos >= 0) {
		bool inId = linestr[startPos].isLetterOrNumber();
		inId = inId || (linestr[startPos] == QLatin1Char('_'));
		inId = inId || (linestr[startPos] == QLatin1Char('-'));
		if (!inId) {
			break;
		}
		-- startPos;
	}
	while (endPos < linestr.length()) {
		bool inId = linestr[endPos].isLetterOrNumber();
		inId = inId || (linestr[endPos] == QLatin1Char('_'));
		inId = inId || (linestr[endPos] == QLatin1Char('-'));
		if (!inId) {
			break;
		}
		++ endPos;
	}
	if  (startPos == endPos) {
		return QString();
	}
	return linestr.mid(startPos + 1, endPos - startPos - 1);
}

QString stripQuotes(const QString& str) {
	if (str.isEmpty()) {
		return QString();
	} else if (str.length() == 1) {
		return (str[0].toLatin1() == '"') ? QString() : str;
	} else {
		int beg = (str[0].toLatin1() == '"') ? 1 : 0;
		int len = ((str[str.length() - 1].toLatin1() == '"') ? str.length() - 1 : str.length()) - beg;
		return str.mid(beg, len);
	}
}

QTableWidgetItem* setNotEditable(QTableWidgetItem* item) {
	Qt::ItemFlags flags = item->flags();
	item->setFlags(flags & ~Qt::ItemIsEditable);
	return item;
}

QString findConfig(const QString& file) {
	QFileInfo fileInfo(file);
	QDir dir = fileInfo.dir();
	while (true) {
		QFileInfoList conf = dir.entryInfoList(QStringList(QLatin1String("flow.config")));
		if (!conf.isEmpty()) {
			return conf[0].absoluteFilePath();
		} else if (dir.isRoot()) {
			break;
		} else {
			dir.cdUp();
		}
	}
	return QString();
}

ConfigFile parseConfig(const QString& confName) {
	QFile confFile(confName);
	QMap<QString, QString> ret;
	if (confFile.open(QIODevice::ReadOnly)) {
		QTextStream in(&confFile);
		while(!in.atEnd()) {
			QString line = in.readLine().trimmed();
			if (!line.isEmpty() && !line.startsWith(QLatin1Char('#'))) {
				QStringList fields = line.split(QLatin1Char('='));
				QString name = fields[0].toLower().trimmed();
				QString value = fields[1].trimmed();
				if (name == QLatin1String("include")) {
					value.replace(QLatin1Char(' '), QString());
				}
				ret[name] = value;
			}
		}
	}
	return ret;
}

QString findFlowRoot(const QString& file) {
	QFileInfo fileInfo(file);
	QDir dir = fileInfo.dir();
	QStringList flowStuff;
	flowStuff << QLatin1String("*.flow") << QLatin1String("flow.config");
	while (true) {
		QFileInfoList conf = dir.entryInfoList(flowStuff);
		if (!conf.isEmpty()) {
			dir.cdUp();
		} else {
			QFileInfoList siblings = dir.entryInfoList(QDir::Dirs | QDir::Files | QDir::NoDotAndDotDot);
			int siblingsWithFlowStuff = 0;
			for (QFileInfo sibling : siblings) {
				if (sibling.isDir()) {
					QDir d(sibling.filePath() + QDir::separator());
					if (d.entryInfoList(flowStuff).count() > 0) {
						++siblingsWithFlowStuff;
					}
				} else if (sibling.isFile()) {
					if (sibling.suffix() == QLatin1String("flow")) {
						++siblingsWithFlowStuff;
					}
				}
			}
			// A heuristic: siblings with flowfiles must be not less, then 1/3 of all siblings,
        	// otherwise the previous dir is what we search for
			if (siblingsWithFlowStuff * 3 < siblings.count()) {
				break;
			} else {
				dir.cdUp();
			}
		}
	}
	return dir.path();
}


void progTimestamps(ProgTimestamps& map, const QString& name, const QStringList& includes) {
	if (map.contains(name)) {
        return;
    }
	map[name] = QFileInfo(name).lastModified();
	QFile file(name);
	if (!file.open(QIODevice::ReadOnly | QIODevice::Text)) {
        return;
	}
	static QString importPrefix = QLatin1String("import");
	static int importPrefixLen = importPrefix.length();
    while (!file.atEnd()) {
        QString line = QString::fromLatin1(file.readLine());
        if (line.startsWith(importPrefix)) {
        	// remove prefix " import "
        	line = line.trimmed().mid(importPrefixLen).trimmed();
        	// remove postfix ";"
        	line = line.mid(0, line.indexOf(QLatin1Char(';')));
        	bool found = false;
        	for (auto inc : includes) {
        		if (!inc.endsWith(QLatin1Char('/'))) {
        			inc += QLatin1Char('/');
        		}
        		QString importPath = inc + line + QLatin1String(".flow");
        		QFileInfo import(importPath);
        		if (import.isFile()) {
        			progTimestamps(map, import.absoluteFilePath(), includes);
        			found = true;
        			break;
        		}
        	}
        	if (!found) {
        		QTextStream(stdout) << "file import: '" << line << "' is not found\n";
        		map[line] = QDateTime();
        	}
        }
    }
}

ProgTimestamps progTimestamps(const QString& file, const QString& dir, const QStringList& includes) {
	ProgTimestamps map;
	QDir current = QDir::current();
	QDir::setCurrent(dir);
	progTimestamps(map, file, includes);
	QDir::setCurrent(current.path());
	return map;
}

bool progTimestampsChanged(const ProgTimestamps& dep1, const ProgTimestamps& dep2) {
	if (dep1.count() != dep2.count()) {
		return true;
	}
	for (const auto& k : dep1.keys()) {
		if (dep1[k].toMSecsSinceEpoch() != dep2[k].toMSecsSinceEpoch()) {
			return true;
		}
	}
	return false;
}

QByteArray progTimestampsToBinary(const ProgTimestamps& timestamps) {
      QByteArray buffer;
      QDataStream out(&buffer, QIODevice::WriteOnly);
      out << timestamps;
      return buffer;
}

ProgTimestamps progTimestampsFromBinary(const QByteArray& buffer) {
	QDataStream in(buffer);
	ProgTimestamps timestamps;
	in >> timestamps;
	return timestamps;
}

void appendText(QPlainTextEdit* textEdit, const QString& text) {
	textEdit->moveCursor (QTextCursor::End);
	textEdit->insertPlainText(text);
	textEdit->moveCursor (QTextCursor::End);
}

}

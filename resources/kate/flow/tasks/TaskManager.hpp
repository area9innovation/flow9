#pragma once

#include <map>
#include <memory>
#include <QMap>
#include <QString>
#include "TaskFactory.hpp"

namespace flow {

class TaskManager {
public:
	TaskManager(FlowEnv e) : env(e) { }

	void compile();
	void run(int row);
	void build(int row, bool force);
	void lookupDef();
	void lookupType();
	void lookupUses();
	void outline(const QString& file);
	void rename(const QString& renamed);
	void dumpIDs(int row);
	void debug(int row);

	void terminate(const QString& pid);
	void remove(const QString& pid);

private:
	void startTask(Task*);

	FlowEnv env;
	std::map<QString, std::unique_ptr<Task>> tasks;
};

}

#include <QTextStream>
#include "tasks/TaskBuild.hpp"
#include "tasks/TaskCompile.hpp"
#include "tasks/TaskRun.hpp"
#include "tasks/TaskLookupDef.hpp"
#include "tasks/TaskLookupType.hpp"
#include "tasks/TaskLookupUses.hpp"
#include "tasks/TaskOutline.hpp"
#include "tasks/TaskRename.hpp"
#include "tasks/TaskDumpIDs.hpp"
#include "tasks/TaskDebug.hpp"
#include "tasks/TaskManager.hpp"

namespace flow {

void TaskManager::compile() {
	startTask((new TaskCompile(env))->task());
}

void TaskManager::run(int row) {
	startTask((new TaskRun(env, row))->task());
}

void TaskManager::build(int row, bool force) {
	startTask((new TaskBuild(env, row, force))->task());
}

void TaskManager::lookupDef() {
	startTask((new TaskLookupDef(env))->task());
}

void TaskManager::lookupType() {
	startTask((new TaskLookupType(env))->task());
}

void TaskManager::lookupUses() {
	startTask((new TaskLookupUses(env))->task());
}

void TaskManager::outline(const QString& file) {
	startTask((new TaskOutline(env, file))->task());
}

void TaskManager::rename(const QString& renamed) {
	startTask((new TaskRename(env, renamed))->task());
}

void TaskManager::dumpIDs(int row) {
	startTask((new TaskDumpIDs(env, row))->task());
}

void TaskManager::debug(int row) {
	startTask((new TaskDebug(env, row))->task());
}

void TaskManager::startTask(Task* task) {
	if (task) {
		task->slotStart();
		tasks.emplace(task->pid(), task);
	}
}

void TaskManager::terminate(const QString& pid) {
	if (tasks.count(pid)) {
		tasks[pid]->slotStop();
	} else {
		QTextStream(stdout) << "Task with PID: " << pid << " is not found\n";
	}
}

void TaskManager::remove(const QString& pid) {
	if (tasks.count(pid)) {
		tasks.erase(tasks.find(pid));
	} else {
		QTextStream(stdout) << "Task with PID: " << pid << " is not found\n";
	}
}

}

#pragma once

#include "execs/Target.hpp"

namespace flow {

struct Runner {
	Runner(const Ui::FlowConfig& ui, QString prog, QString targ, QString flowdir, QString outdir);
	QString invocation() const;
	QStringList args(QString execArgs, QString progArgs) const;
	const Target& target() const { return target_; }
private:
	Target target_;
};

}

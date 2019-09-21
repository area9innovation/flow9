#pragma once

#include "Compiler.hpp"

namespace flow {

struct Builder {
	Builder(const Ui::FlowConfig& ui, QString prog, QString targ, QString flowdir) :
		compiler_ (ui, prog, flowdir), target_(ui, prog, targ, flowdir) { }
	const Compiler& compiler() const { return compiler_; }
	const Target& target() const { return target_; }
	QString invocation() const;
	QStringList args(const QString& opts) const;
	QStringList compilerOpts(const QString&) const;
	QStringList builderOpts(const QString&) const;
private:
	Compiler compiler_;
	Target   target_;
};

}

#include "__flow_runtime_string.hpp"

using namespace flow;

Int Flow::componentSize() const {
	return 0;
}

// Further by default fail everywhere. Non-fails are specific to certain types.

TypeId Flow::componentTypeId(Int i) {
	fail("invalid flow value getter");
	return TypeFx::UNKNOWN;
}

Flow* Flow::getFlowRc1(Int i) {
	fail("invalid flow: getFlowRc1(" + std::to_string(i) + ") of\n" + toStdString());
	return nullptr;
}

Bool Flow::getBoolRc1(Int i) {
	fail("invalid flow: getBoolRc1(" + std::to_string(i) + ") of\n" + toStdString());
	return false;
}

Int Flow::getIntRc1(Int i) {
	fail("invalid flow: getIntRc1(" + std::to_string(i) + ") of\n" + toStdString());
	return 0;
}

Double Flow::getDoubleRc1(Int i) {
	fail("invalid flow: getDoubleRc1(" + std::to_string(i) + ") of\n" + toStdString());
	return 0.0;
}

void Flow::setFlowRc1(Int i, Flow* v) {
	fail("invalid flow: setFlowRc1(" + std::to_string(i) + ", " + v->toStdString() + ") of\n" + toStdString()); 
}

Flow* Flow::getFlowRc1(String* f) {
	fail("invalid flow: getFlowRc1(\"" + string2std(f->str()) + "\") of\n" + toStdString());
	return nullptr;
}

void Flow::setFlowRc1(String* f, Flow* v) {
	fail("invalid flow: setFlowRc1(\"" + string2std(f->str()) + "\", " + v->toStdString() + ") of\n" + toStdString());
}

Flow* Flow::callFlowRc1(const std::vector<Flow*>& args) {
	std::string args_str;
	for (auto i = 0; i < args.size(); ++ i) {
		if (i != 0) {
			args_str += ", ";
		}
		args_str += args.at(i)->toStdString();
	}
	fail("invalid flow: callFlowRc1(" + args_str + ") of\n" + toStdString());
	return nullptr;
}

Flow* Flow::getFlow(Int i) {
	fail("invalid flow: getFlow(" + std::to_string(i) + ") of\n" + toStdString());
	return nullptr;
}

Flow* Flow::getFlow(const string& f) {
	fail("invalid flow: getFlow(\"" + string2std(f) + "\") of\n" + toStdString());
	return nullptr;
}

#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

struct Union : public Flow {
	Union(TypeId struct_id) { RcBase::aux_ = struct_id; }
	TypeId structId() const { return RcBase::aux_; }
	virtual Int compare(Union* v) = 0;
	virtual Union* clone() = 0;
};

}

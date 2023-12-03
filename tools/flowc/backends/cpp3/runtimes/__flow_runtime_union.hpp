#pragma once

#include "__flow_runtime_flow.hpp"

namespace flow {

struct Union : public Flow {
	Union(TypeId struct_id): struct_id_(struct_id) { }
	TypeId structId() const { return struct_id_; }
	virtual Int compare(Union* v) = 0;
	virtual Union* clone() = 0;
private:
	const TypeId struct_id_;
};

}

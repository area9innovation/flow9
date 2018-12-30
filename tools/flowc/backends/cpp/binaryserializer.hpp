#include "flow_string.hpp"

#include <map>
#include <vector>

namespace flow {

class BinarySerializer
{
    std::map<int, int> structIdxs;
    std::vector<int> structIds;

	typedef flow::string::char_t unicode_char;
    std::vector<unicode_char> buf;
	static_assert(sizeof(unicode_char) == 2);

    inline void pushInt32(int val) {
        buf.push_back(val & 0xFFFF);
        buf.push_back(val >> 16);
    }

    void pushInteger(int value);

    void pushString(const unicode_char *data, unsigned len);
	
    void pushString(const flow::string &obj) {
		pushString(obj.cbegin(), obj.size()); 
	}

    void pushArraySize(unsigned len);

    int registerStruct(int id);
    void writeStructDefs();

    void writeBinaryValue(const flow_t & value);

public:

    void serialize(const flow_t &object);
	
	flow::string output() const {
		if (buf.size() > 0) {
			const char_t* begin = &buf[0];
			return flow::string(begin, begin + buf.size());
		} else {
			return flow::string(0);
		}
	}

};

void BinarySerializer::pushInteger(int int_value)
{
    if (int_value & 0xFFFF8000) {
        buf.push_back(0xFFF5);
        pushInt32(int_value);
    } else {
        buf.push_back(int_value);
    }
}

void BinarySerializer::pushString(const unicode_char *data, unsigned len)
{
    if (len & 0xFFFF0000) {
        buf.push_back(0xFFFB);
        pushInt32(len);
    } else {
        buf.push_back(0xFFFA);
        buf.push_back(len);
    }

	for (unsigned i = 0; i < len; i++) {
		buf.push_back(data[i]);
	}
}

void BinarySerializer::pushArraySize(unsigned len)
{
    if (len == 0) {
        buf.push_back(0xFFF7);
    } else {
        if (len & 0xFFFF0000) {
            buf.push_back(0xFFF9);
            pushInt32(len);
        } else {
            buf.push_back(0xFFF8);
            buf.push_back(len);
        }
    }
}

void BinarySerializer::writeStructDefs() {
    pushArraySize(structIds.size());
    for (unsigned i = 0; i < structIds.size(); ++i) {
        pushArraySize(2);
        const struct_desc& desc = get_struct_desc(structIds[i]);
        pushInteger(desc.fields_count);
        pushString(desc.name);
    }
}

int BinarySerializer::registerStruct(int struct_id)
{
    int struct_idx = 0;
    std::map<int,int>::iterator it = structIdxs.find(struct_id);
    if (it == structIdxs.end()) {
        structIdxs[struct_id] = struct_idx = structIds.size();
        structIds.push_back(struct_id);
    } else {
        struct_idx = it->second;
    }
    return struct_idx;
}

void BinarySerializer::writeBinaryValue(const flow_t& value)
{
    switch (value.index()) {
		case flow_t::is_struct: {
			int struct_idx = registerStruct(value.get_struct_type());
			buf.push_back(0xFFF4);
			buf.push_back(struct_idx);
			auto& s = value.get_object_ref();
			s.ptr_->toBinary([&] (const flow_t& field) {
				writeBinaryValue(field);
			});
			break;
		}
		case flow_t::is_int: {
            pushInteger(value.get_int());
			break;
		}
		case flow_t::is_array_of_flow_t: {
			const auto& a = value.get_array();
            int len = a.size();
            pushArraySize(len);
            for (int i = 0; i < len; ++i)
                writeBinaryValue(a[i]);
			break;
		}
		case flow_t::is_double: {
			double d = value.get_double();
            const int *pdata = (const int*)&d;
            buf.push_back(0xFFFC);
            pushInt32(pdata[0]);
            pushInt32(pdata[1]);
			break;
		}
		case flow_t::is_bool: {
            buf.push_back(value.get_bool() ? 0xFFFE : 0xFFFD);
			break;
		}
		case flow_t::is_string: {
            pushString(value.get_string());
			break;
		}
		/*
        case TVoid:
            buf.push_back(0xFFFF);
            break;
        case TRefTo:
            buf.push_back(0xFFF6);
            writeBinaryValue(RUNNER->GetRefTarget(value));
            break;
        default:
            RUNNER->ReportError(InvalidArgument, "Cannot serialize flow value. Invalid DataTag: %d", value.GetType());
            break;
		*/
		default:
			std::wcout << "index = " << value.index() << std::endl;
			FLOW_ABORT;
    }
}

void BinarySerializer::serialize(const flow_t& value) {
    buf.clear();
    structIds.clear();
    structIdxs.clear();

    buf.push_back(0); buf.push_back(0); // Stub for footer offset
    writeBinaryValue(value);

    int struct_defs_offset = buf.size();
    writeStructDefs();

    buf[0] = struct_defs_offset & 0xFFFF;
    buf[1] = struct_defs_offset >> 16;
}

/*
class BinaryDeserializer
{
    RUNNER_VAR;

    std::vector<int> structIndex;
    std::vector<int> structSize;
    std::vector<StackSlot> structFixups;
    bool has_fixups;

    const StackSlot *pinput, *pdefault;
    unsigned char_idx, ssize;

    // A check for corrupted array sizes
    int slot_budget;

    bool error;

    StackSlot NewRef();
    FlowPtr NewBuffer(int size);
    StackSlot NewArray(int size, bool map = true);

    void SetSlot(const StackSlot &vec, int index, const StackSlot &val);
    void SetRefTarget(const StackSlot &vec, const StackSlot &val);

    const unicode_char *readChars(int count) {
        unsigned new_idx = char_idx + count;
        if (new_idx < char_idx || new_idx > ssize) {
            error = true;
            return NULL;
        }
        unsigned cur_idx = char_idx;
        char_idx = new_idx;
        return RUNNER->GetStringPtr(*pinput) + cur_idx;
    }

    unicode_char readChar() {
        const unicode_char *data = readChars(1);
        return data ? *data : 0;
    }
    int readInt32() {
        const unicode_char *data = readChars(2);
        return data ? *(int*)data : 0;
    }

    int readInteger();
    int readArraySize();
    StackSlot readString();

    void readStructIndex(const StackSlot &fixups);

    StackSlot readValue();

public:
    BinaryDeserializer(RUNNER_VAR) : RUNNER(RUNNER) {
        //
    }

    StackSlot deserialize(const StackSlot &input, const StackSlot &defval, const StackSlot &fixups);

    bool success() { return !error; }
};

StackSlot BinaryDeserializer::deserialize(const StackSlot &input, const StackSlot &defval, const StackSlot &fixups)
{
    pinput = &input;
    pdefault = &defval;
    char_idx = 0;
    ssize = RUNNER->GetStringSize(input);
    error = false;
    has_fixups = false;
#ifdef FLOW_MMAP_HEAP
    mapped = false;
#endif

    RUNNER_RegisterNativeRoot(std::vector<StackSlot>, structFixups);

    readStructIndex(fixups);
    if (error || RUNNER->IsErrorReported())
        return defval;

    slot_budget = ssize + 1000;

#ifdef FLOW_MMAP_HEAP
    bool input_mapped = RUNNER->IsMappedArea(RUNNER->GetStringAddr(input));
    bool enough_free = (RUNNER->MapStringPtr - RUNNER->MapAreaBase) >= STACK_SLOT_SIZE*slot_budget;

    if (input_mapped && enough_free && !has_fixups)
    {
        MappedAreaInfo::Ptr ptr = RUNNER->FindMappedArea(RUNNER->GetStringAddr(input));

        if (ptr)
        {
            mapped = true;
            hp = hplimit = rhp = rhplimit = RUNNER->MapAreaBase;
            area = MappedAreaInfo::Ptr(new MappedAreaInfo(hp, 0));
            area->depends.push_back(ptr);
        }
    }
#endif

    StackSlot rv = readValue();

#ifdef FLOW_MMAP_HEAP
    if (mapped)
    {
        RUNNER->MapAreaBase = hp = FlowPtrAlignUp(hp, MEMORY->PageSize());
        area->length = hp - area->start;
        if (hp < hplimit)
            MEMORY->DecommitRange(hp, hplimit);
        RUNNER->MappedAreas[area->start] = area;
    }
#endif

    if (char_idx < ssize)
        RUNNER->flow_out << "Did not understand all!";
    return rv;
}
*/


} // namespace flow


#ifdef FLOWC_RUNTIME_INCLUDE_LIST2ARRAY

namespace flow {
	
	template <typename T>
	FLOW_ALWAYS_INLINE const Cons<T>* listToCons(const List<T>* list) {
		return &(*(list->toCons()));
	}
	
	template <typename T>
	FLOW_INLINE int getListLength(const List<T>& list) {
		int len = 0;
		const List<T>* cur = &list;
		while (cur->id_() == flow::types::Cons) {
			auto cons = listToCons(cur);
			cur = &cons->tail;
			len++;
		}
		return len;
	}
	
} // namespace flow

template <typename T>
flow::array_t<T> list2array(const List<T>& list) {
	// TODO: optimize it later. 
	// Consider having special version for simple types like ints and strings
	int len = flow::getListLength(list);
	const List<T>* cur = &list;
	std::vector<const flow::ptr_type_t<T>*> ptrs;
	ptrs.reserve(len);
	cur = &list;
	while (cur->id_() == flow::types::Cons) {
		auto cons = flow::listToCons(cur);
		ptrs.push_back(&cons->head);
		cur = &cons->tail;
	}
	std::vector<flow::ptr_type_t<T>> v;
	v.reserve(len);
	for (int i = 0; i < len; i++) {
		v.push_back(*ptrs[len-1-i]);
	}
	return v;
}

flow::string list2string(const List<flow::string>& list) {
	// can be optimized more by writing directly to flow::string rather than to std::string
	typedef flow::string::char_t char_t;
	std::vector<char_t> res;
	int len = 0;
	const List<flow::string>* cur = &list;
	while (cur->id_() == flow::types::Cons) {
		auto cons = flow::listToCons(cur);
		len += cons->head.size();
		cur = &cons->tail;
	}
	
	if (len == 0) return flow::string(0);
	
	res.resize(len);
	char_t* pos = (&res[0]) + len;
	
	cur = &list;
	while (cur->id_() == flow::types::Cons) {
		auto cons = flow::listToCons(cur);
		auto& s = cons->head;
		size_t sz = s.size();
		pos -= sz;
		std::copy(s.cbegin(), s.cend(), pos);
		cur = &cons->tail;
	}
	FLOW_ASSERT(pos == &res[0]);
	
	return flow::string(pos, pos + len);
}

#endif // FLOWC_RUNTIME_INCLUDE_LIST2ARRAY

#ifdef FLOWC_RUNTIME_INCLUDE_BINARY

flow_t fromBinary(const flow::string& s, const flow_t& default_, const std::function<Maybe<std::function<flow_t(flow::array<flow_t>)>>(flow::string)>& fixups) {
	return flow_t(s);
}

#endif // FLOWC_RUNTIME_INCLUDE_BINARY


#ifdef FLOWC_RUNTIME_INCLUDE_URLPARAMETER

Tree<flow::string, flow::string> getAllUrlParameters();

namespace flow {
	
	void refreshAllUrlParameters() {
		allUrlParameters = getAllUrlParameters();
	}
	
}

#endif // FLOWC_RUNTIME_INCLUDE_BINARY

#ifdef FLOWC_RUNTIME_INCLUDE_BINARYTREE

namespace flow {
	
	template <typename T>
	FLOW_INLINE int cmp(flow::fparam<T> l, flow::fparam<T> r) {
		if (l < r) return -1;
		if (l == r) return 0;
		return 1;
	}
	
	template <>
	FLOW_INLINE int cmp<flow::string>(const flow::string& l, const flow::string& r) {
		return l.cmp(r);
	}
	
}

std::map<const char*, uint64_t> g_lookup_types;

void printLookupTreeStats() {
	if (g_lookup_types.empty()) return;
	FLOW_PRN("--------------");
	for (auto& p : g_lookup_types) {
		FLOW_PRN(p.first << " - " << rdtsc2ms(p.second));
	}
	FLOW_PRN("--------------");
}

// #define FLOW_ENABLE_LOOKUPTREE_STATS

template <typename T1, typename T2> 
Maybe<T2> lookupTree(const Tree<T1, T2>& set, flow::fparam<T1> key) {
	tsc_holder holder(g_tree_lookup_tsc);
	#ifdef FLOW_ENABLE_LOOKUPTREE_STATS
		auto t1 = rdtsc();
	#endif 
	const flow::object* cur = set.ptr_.ptr_.get();
	while (true) {
		if (cur->obj_id_ == flow::types::TreeEmpty) {
			#ifdef FLOW_ENABLE_LOOKUPTREE_STATS
				auto t2 = rdtsc(); g_lookup_types[typeid(T1).name()] += t2 - t1;
			#endif 
			return flow::gNone;
		} else {
			FLOW_ASSERT(cur->obj_id_ == flow::types::TreeNode);
			const TreeNode<T1, T2>* cur2 = reinterpret_cast<const TreeNode<T1, T2>*>(cur);
			flow::fparam<T1> k = cur2->key;
			
			// if (1 !=
				// ((key < k) ? 1 : 0) +
				// ((k < key) ? 1 : 0) +
				// ((k == key) ? 1 : 0)) 
			// {
				// fcPrintln(toString(key));
				// fcPrintln(toString(k));
				// FLOW_PRN(((key < k) ? 1 : 0));
				// FLOW_PRN(((k < key) ? 1 : 0));
				// FLOW_PRN(((k == key) ? 1 : 0));
			// }
			
			FLOW_ASSERT(1 ==
				((key < k) ? 1 : 0) +
				((k < key) ? 1 : 0) +
				((k == key) ? 1 : 0)
			);
			int c;
			{
				// tsc_holder holder(g_tree_lookup_cmp_tsc);
				c = flow::cmp<T1>(key, k);
			}		
			if (c == 0) {
				#ifdef FLOW_ENABLE_LOOKUPTREE_STATS
					auto t2 = rdtsc(); g_lookup_types[typeid(T1).name()] += t2 - t1;
				#endif 
				return flow::create_struct_ptr<Some<T2>>(cur2->value);
			} else {
				if (c < 0) {
					cur = cur2->left.ptr_.ptr_.get();
					continue;
				} else {
					cur = cur2->right.ptr_.ptr_.get();
					continue;
				}
			}
		}
	}
}

#endif // FLOWC_RUNTIME_INCLUDE_BINARYTREE

# WebGPU Acceleration for Orbit: Pattern Matching and O-Graph Rewriting

## 1. Introduction

This document specifies a WebGPU-based implementation for accelerating pattern matching and equality saturation in the Orbit rewriting system. Building upon the O-Graph foundations established in the Orbit framework (an extension of e-graphs with domain annotations and canonical representatives), this implementation enables high-performance parallel processing of pattern matching and rewriting operations using GPU compute shaders expressed in WGSL (WebGPU Shading Language).

The core innovation is a specialized compiler that translates Orbit's pattern-based rewrite rules into optimized WGSL shader code, embedding both the rules and the initial expression state directly into a self-contained compute shader. This approach enables high-throughput parallel matching and rewriting while addressing the unique constraints of the GPU execution model. A key goal is to also **implement Orbit's core evaluation logic within WGSL**, allowing rule conditions and right-hand sides to be processed directly on the GPU.

## 2. System Architecture

### 2.1 Overall Architecture

The system consists of three main components:

1.  **Orbit-to-WGSL Compiler**: A Flow-based compiler that generates specialized WGSL code from Orbit patterns, expressions, and evaluation logic.
2.  **WebGPU Execution Runtime**: A lightweight TypeScript coordinator that executes the generated WGSL on available GPUs.
3.  **O-Graph State Decoder**: A Flow-based component that decodes the resulting O-Graph state and extracts optimized, canonical expressions.

```
┌────────────────┐          ┌─────────────────────┐          ┌────────────────┐
│  Orbit Rules   │          │    Generated WGSL   │          │   Canonical    │
│  & Expression  │──────────▶  with Embedded Data │──────────▶   Expression   │
│                │  compile │    & Eval Logic     │  execute │                │
└────────────────┘          └─────────────────────┘          └────────────────┘
```

### 2.2 Data Flow

1.  The user provides rewrite rules (patterns) and expressions to optimize.
2.  The compiler translates these into a self-contained WGSL file, embedding initial data and evaluation logic.
3.  The WebGPU runtime loads and executes this WGSL file on the GPU, performing equality saturation.
4.  The runtime captures the final O-Graph state as a binary blob.
5.  The decoder reconstructs the canonical expression from this binary state.

### 2.3 Key Design Principles

-   **Self-contained WGSL**: The generated shader contains pattern matching, rewriting, evaluation logic, and initial data.
-   **Minimal Memory Transfer**: Only the final optimized state is transferred back from the GPU.
-   **Specialized Kernels**: Rewrite rules and canonicalization logic are compiled into optimized GPU code.
-   **Batch Processing**: Multiple patterns are processed in parallel over candidate O-Graph nodes.
-   **Canonical Form Convergence**: The process drives O-Graph representatives towards their canonical forms.

## 3. O-Graph Representation

### 3.1 Core Data Structures

The O-Graph is represented using the following key data structures in WGSL, enhanced with region information for memory management:

```wgsl
// Region tag for memory management
struct RegionTag {
	stack_local: bool,       // Can live in thread-local memory
	workgroup_shared: bool,  // Should be shared within workgroup
	persistent: bool         // Must persist across kernel invocations
};

// Node in the O-Graph (represents an operation and children)
struct ENode {
	op_code: u32,                     // Operation code
	child_eclass_ids: array<u32, MAX_CHILDREN>,  // Child e-class IDs
	domains: u32                     // Bitset of domain annotations
};

// Equivalence class in the O-Graph
struct EClass {
	parent: atomic<u32>,             // Union-find parent pointer
	size: u32,                       // Size of this equivalence class
	best_enode_id: u32,              // Representative Node ID (converges to canonical form)
	// Cost removed, canonical form is the extraction target
	domains: u32,                    // Bitset of domain annotations
	region_info: RegionTag           // Memory region information
};

// Hash table entry for hash consing
struct HashEntry {
	enode_id: atomic<u32>            // ENode ID or empty marker
};
```

### 3.2 Buffer Organization

The WGSL implementation uses the following buffer structure:

```wgsl
@group(0) @binding(0) var<storage, read_write> enodes: array<ENode>;           // All nodes
@group(0) @binding(1) var<storage, read_write> eclasses: array<EClass>;        // All e-classes
@group(0) @binding(2) var<storage, read_write> hash_table: array<HashEntry>;   // Hash table
@group(0) @binding(3) var<storage, read_write> i32_values: array<i32>;         // Integer constants
@group(0) @binding(4) var<storage, read_write> f32_values: array<f32>;         // Float constants
// Other potential buffers: strings, temporary sort buffers, etc.
```

### 3.3 Initial State Representation

The initial expression to be optimized is embedded directly in the WGSL code as constant arrays:

```wgsl
const initial_enode_count: u32 = <count>u;
const initial_enodes_data: array<u32, <size>> = array<u32, <size>>(...);  // Flattened nodes
const initial_i32_count: u32 = <count>u;
const initial_i32_values_data: array<i32, <size>> = array<i32, <size>>(...);  // Integer constants
// Similar arrays for f32 and other value types
```

## 4. Pattern Matching and Rewriting

### 4.1 Pattern Representation

Orbit patterns are compiled into specialized WGSL functions. Each pattern translates into a matching function and an application (rewriting) function:

```wgsl
// For a pattern like "A + 0 => A"

// Matching function checks if the pattern applies
fn match_rule0(eclass_id: u32, bindings: ptr<function, array<u32, MAX_BINDINGS>>) -> bool {
	// Pattern-specific matching logic derived from "A + 0"
}

// Application function performs the rewrite based on "A"
fn apply_rule0(eclass_id: u32, bindings: ptr<function, array<u32, MAX_BINDINGS>>) {
	// Pattern-specific rewriting logic to represent "A"
}
```

### 4.2 Equality Saturation Algorithm Kernels

The equality saturation process proceeds in three main stages, implemented as separate compute shader kernels invoked repeatedly:

1.  **Pattern Matching Kernel**: Parallel attempt to match each rule against each e-class representative.
    ```wgsl
		 @compute @workgroup_size(256)
		 fn pattern_match_kernel(@builtin(global_invocation_id) global_id: vec3<u32>) {
				 let eclass_id = global_id.x;
				 if (eclass_id >= active_eclass_count) { return; }
				 // Match only against the canonical representative's root eclass ID
				 if (find(eclass_id) != eclass_id) { return; }

				 var bindings: array<u32, MAX_BINDINGS>;
				 // Initialize bindings...

				 // Try all compiled rules on this canonical eclass
				 if (match_rule0(eclass_id, &bindings)) { /* Record match */ }
				 if (match_rule1(eclass_id, &bindings)) { /* Record match */ }
				 // ... more rules
		 }
```

2.  **Rewrite Application Kernel**: Apply all successful matches recorded in the previous step in parallel.
    ```wgsl
		 @compute @workgroup_size(256)
		 fn apply_rewrites_kernel(@builtin(global_invocation_id) global_id: vec3<u32>) {
				 let match_id = global_id.x;
				 if (match_id >= match_count) { return; }

				 let match_entry = matches[match_id];

				 // Dispatch to appropriate rule application function
				 switch (match_entry.rule_id) {
						 case 0u: { apply_rule0(match_entry.eclass_id, &match_entry.bindings); }
						 case 1u: { apply_rule1(match_entry.eclass_id, &match_entry.bindings); }
						 // ... more rules
				 }
		 }
```

3.  **Congruence Closure & Canonicalization Kernel**: Rebuild congruence closure after rewrites. During this phase, the representative node (`best_enode_id`) for each e-class is updated to reflect the canonical form based on applied rules and ordering criteria (e.g., performing extract-sort-rebuild for `Sₙ`).
    ```wgsl
		 @compute @workgroup_size(256)
		 fn rebuild_congruence_and_canonicalize_kernel(@builtin(global_invocation_id) global_id: vec3<u32>) {
				 let enode_id = global_id.x;
				 if (enode_id >= enode_count) { return; }

				 let enode = enodes[enode_id];
				 let current_eclass_id = enode_to_eclass[enode_id]; // Assuming this mapping exists

				 // Find canonicalized versions of child eclasses
				 var canonical_children: array<u32, MAX_CHILDREN>;
				 for (var i = 0u; i < MAX_CHILDREN; i++) {
						 if(enode.child_eclass_ids[i] != INVALID_ID) {
								canonical_children[i] = find(enode.child_eclass_ids[i]);
						 } else {
								canonical_children[i] = INVALID_ID;
						 }
				 }

				 // Find or create a canonical version of this node structure via hash consing
				 let canonical_node_eclass_id = canonicalize_or_add_node(enode.op_code, canonical_children);

				 // Merge the e-class of the current node with the canonical one
				 if (canonical_node_eclass_id != INVALID_ID) {
						let merged = merge(current_eclass_id, canonical_node_eclass_id);
						// Optional: If merged, potentially trigger canonicalization update for the new root
						if (merged) {
								update_representative(find(current_eclass_id));
						}
				 }

				 // Separately, apply canonicalization rules based on domain (e.g., Sₙ sort)
				 // This might involve reading the current representative, extracting data, sorting,
				 // creating a new canonical node, and merging. This is complex on GPU.
				 // update_representative(find(current_eclass_id));
		 }

		 // Function to update the representative based on canonicalization rules
		 fn update_representative(root_eclass_id: u32) {
				// Check domains (e.g., S_n for commutativity)
				if (has_domain(root_eclass_id, DOMAIN_S_N)) {
						// Perform direct canonicalization on already-flattened n-ary representation
						// Orbit-to-SExpr lowering already converted a+b+c+(d+e)+f to `+`(a,b,c,d,e,f)
						// let current_repr_id = eclasses[root_eclass_id].best_enode_id;
						// let args = enodes[current_repr_id].args; // Direct access to flattened args
						// let sorted_args = sort_args_gpu(args); // Sort the already-flat argument list
						// let new_canonical_node_id = create_n_ary_node(OP_ADD, sorted_args);
						// let new_canonical_eclass_id = canonicalize_or_add_node(...);
						// eclasses[root_eclass_id].best_enode_id = node_id_from_eclass(new_canonical_eclass_id);
				}
				// Add logic for other groups like C_n, D_n
		 }
```

These kernels execute repeatedly until saturation (no new rewrites possible) or a maximum iteration count is reached.

### 4.3 Union-Find Implementation

The O-Graph uses an atomic union-find implementation with path compression:

```wgsl
fn find(id: u32) -> u32 {
	if (id >= eclass_count) { return INVALID_ID; }
	var current = id;
	var parent = atomicLoad(&eclasses[current].parent);

	// Find root with path compression
	while (parent != current) {
		current = parent;
		parent = atomicLoad(&eclasses[current].parent);
	}

	// Compress paths on second traversal
	var node = id;
	while (node != parent) {
		let next = atomicLoad(&eclasses[node].parent);
		atomicStore(&eclasses[node].parent, parent);
		node = next;
	}

	return parent;
}

fn merge(id1: u32, id2: u32) -> bool {
	let root1 = find(id1);
	let root2 = find(id2);

	if (root1 == root2) { return false; }

	// Union by size
	let size1 = eclasses[root1].size;
	let size2 = eclasses[root2].size;

	var parent: u32;
	var child: u32;

	if (size1 >= size2) {
		parent = root1;
		child = root2;
	} else {
		parent = root2;
		child = root1;
	}

	// Update parent and size
	atomicStore(&eclasses[child].parent, parent);
	eclasses[parent].size = size1 + size2;

	return true;
}
```

## 5. Compilation Pipeline: Orbit to WGSL

### 5.1 Overall Compilation Process

The compilation pipeline translates Orbit patterns, expressions, and relevant evaluation logic into a specialized WGSL shader:

1.  Parse Orbit rules and expression into AST representations.
2.  Analyze patterns to identify variables, constraints, and domain annotations.
3.  Perform region-based memory analysis.
4.  Generate specialized WGSL matching code for each pattern.
5.  Generate WGSL rewriting code for each rule's RHS, potentially including calls to compiled Orbit evaluation logic.
6.  Generate WGSL code for canonicalization algorithms (e.g., extract-sort-rebuild).
7.  Serialize the initial expression into WGSL constant arrays.
8.  Assign appropriate memory regions based on lifetime analysis.
9.  Assemble all components into a complete WGSL shader.

### 5.2 Pattern Analysis

For each pattern, the compiler performs the following analysis:

1. **Variable Identification**: Identify pattern variables (e.g., `A`, `B`) vs. concrete terms
2. **Structure Analysis**: Determine node types, arities, and child relationships
3. **Constraint Extraction**: Extract domain constraints (e.g., `A : Real`) and conditions
4. **Binding Order**: Determine optimal order for variable binding and checking

### 5.3 Code Generation Strategy

The compiler generates WGSL code components including:

1.  Operation Code Definitions (`const OP_ADD: u32 = ...;`)
2.  Initial State Data (`const initial_enodes_data: array<...> = ...;`)
3.  Region Information (`const initial_region_data: array<...> = ...;`)
4.  Matching Functions (`fn match_rule0(...) -> bool { ... }`)
5.  Rewriting Functions (`fn apply_rule0(...) { ... }`)
6.  **Canonicalization Functions:** (`fn canonicalize_S_n(...) { /* extract-sort-rebuild logic */ }`) - These might be complex to generate effectively.
7.  **Evaluation Logic:** (Portions of Orbit's interpreter logic compiled to WGSL for evaluating conditions or RHS).
8.  Memory Management Functions (`fn allocate_in_region(...)`)
9.  Dispatcher Functions (within kernels)

### 5.4 Optimization Techniques

The compiler applies several optimizations to improve WGSL performance:

1. **Early Pruning**: Generate code that tests the most likely failure conditions first
2. **Constant Propagation**: Pre-compute constant expressions during compilation
3. **Common Subpattern Elimination**: Identify shared subpatterns across rules
4. **Variable Binding Order**: Order variable bindings to minimize backtracking
5. **Operation Specialization**: Generate specialized code for common operators
6. **Memory Coalescing**: Optimize memory access patterns for GPU efficiency
7. **Region-Based Allocation**: Place data in appropriate memory regions based on lifetime analysis
8. **Escape Analysis**: Determine which expressions can safely be allocated in shorter-lived regions
9. **Memory Reuse**: Identify opportunities to reuse memory regions across kernel invocations

## 6. Pattern Matching Implementation Details

### 6.1 Pattern Variable Binding

Pattern variables are tracked using a binding array, with a dedicated position for each variable:

```wgsl
var bindings: array<u32, MAX_BINDINGS>;
// Initialize to INVALID_ID (0xFFFFFFFF)
for (var i = 0u; i < MAX_BINDINGS; i++) {
	bindings[i] = INVALID_ID;
}

// When matching a pattern variable 'A' at index 0
if (bindings[0u] == INVALID_ID) {
	// First occurrence - bind the variable
	bindings[0u] = eclass_id;
} else {
	// Subsequent occurrence - check that it matches the previous binding
	if (find(bindings[0u]) != find(eclass_id)) {
		return false; // Pattern match fails
	}
}
```

### 6.2 Domain Constraints

Domain constraints (e.g., `x : Real`) are checked using bitset operations on domain flags:

```wgsl
// Check if eclass has domain annotation
fn has_domain(eclass_id: u32, domain_id: u32) -> bool {
	let canonical_id = find(eclass_id);
	let domain_bitset = eclasses[canonical_id].domains;
	return (domain_bitset & (1u << domain_id)) != 0u;
}

// In pattern matching
if (pattern_requires_domain && !has_domain(eclass_id, required_domain_id)) {
	return false; // Domain constraint not satisfied
}
```

### 6.3 Conditional Rules

Conditions are evaluated on the GPU using the compiled evaluation logic:

```wgsl
fn match_rule_with_condition(...) -> bool {
	// ... standard pattern matching ...
	if (basic_match) {
		// Evaluate condition using compiled Orbit eval logic
		let condition_result = evaluate_orbit_condition_wgsl(condition_ast_id, &bindings);
		return condition_result;
	}
	// ...
}

fn evaluate_orbit_condition_wgsl(ast_node_id: u32, bindings: ptr<function, array<u32, MAX_BINDINGS>>) -> bool {
	// Invoke compiled WGSL interpreter for the condition AST
	// Needs access to O-Graph state and bindings
	// ... returns boolean result
}
```

## 7. Memory Management with Region-Based Allocation

### 7.1 Memory Regions in WGSL

WGSL provides several memory storage classes that align well with region-based memory management concepts:

1. **`private`**: Thread-local memory (like stack allocation)
2. **`workgroup`**: Shared within a workgroup (intermediate lifetime)
3. **`storage`**: Persistent across invocations (heap-like memory)

We use region annotations to guide the placement of data in these storage classes:

```wgsl
// Region-specific memory declarations
var<private> thread_local_data: array<u32, 64>;      // Stack-like, shortest lifetime
var<workgroup> shared_workgroup_data: array<u32, 256>; // Region shared across workgroup
var<storage, read_write> persistent_data: array<u32>;  // Longest-lived region
```

### 7.2 Node Creation with Region Awareness

Creating new nodes in WGSL requires careful memory management with region considerations. The system uses an atomic counter to allocate new nodes and places them according to their expected lifetime:

```wgsl
struct RegionTag {
	stack_local: bool,    // Can live in thread-local memory
	workgroup_shared: bool, // Should be shared within workgroup
	persistent: bool       // Must persist across kernel invocations
};

fn create_enode(op_code: u32, children: array<u32, MAX_CHILDREN>, region: RegionTag) -> u32 {
	// For short-lived nodes used within a single function
	if (region.stack_local) {
		// Use thread local memory when possible
		// (Implementation limited since WGSL doesn't support dynamic allocation)
		// For now, fall through to persistent storage
	}

	// For intermediate results shared within this workgroup
	if (region.workgroup_shared) {
		// Try to allocate in workgroup memory for faster access
		// Only possible for certain patterns with known bounds
		// For now, fall through to persistent storage
	}

	// Default case: persistent storage for nodes that may live beyond kernel execution
	// Get next available ENode slot
	let enode_id = atomicAdd(&enode_count, 1u);

	// Check if we're within bounds
	if (enode_id >= MAX_ENODES) {
		return INVALID_ID; // Out of memory
	}

	// Initialize the new ENode
	enodes[enode_id].op_code = op_code;
	for (var i = 0u; i < MAX_CHILDREN; i++) {
		enodes[enode_id].child_eclass_ids[i] = children[i];
	}

	// Create a new EClass for this node
	let eclass_id = atomicAdd(&eclass_count, 1u);
	if (eclass_id >= MAX_ECLASSES) {
		return INVALID_ID; // Out of memory
	}

	// Initialize the new EClass
	atomicStore(&eclasses[eclass_id].parent, eclass_id);
	eclasses[eclass_id].size = 1u;
	eclasses[eclass_id].best_enode_id = enode_id;
	eclasses[eclass_id].region_info = region;
	// ... other initialization

	return enode_id;
}
```

### 7.3 Hash Consing with Region Tracking

To avoid creating duplicate nodes, the system uses a hash-based approach to find existing equivalent nodes, while preserving region information:

```wgsl
fn hash_enode(op_code: u32, children: array<u32, MAX_CHILDREN>) -> u32 {
	// Compute hash of operation and canonicalized children
	var hash = op_code;
	for (var i = 0u; i < MAX_CHILDREN; i++) {
		if (children[i] == INVALID_ID) { break; }
		hash = ((hash << 5u) + hash) ^ find(children[i]);
	}
	return hash;
}

fn canonicalize_or_add_node(op_code: u32, children: array<u32, MAX_CHILDREN>) -> u32 {
	// Determine appropriate region based on operation and children
	let region = determine_node_region(op_code, children);

	// Canonicalize children first
	var canonical_children: array<u32, MAX_CHILDREN>;
	for (var i = 0u; i < MAX_CHILDREN; i++) {
		if (children[i] == INVALID_ID) {
			canonical_children[i] = INVALID_ID;
		} else {
			canonical_children[i] = find(children[i]);
		}
	}

	// Compute hash and look up in hash table
	let hash = hash_enode(op_code, canonical_children);
	let slot = hash % HASH_TABLE_SIZE;

	// Linear probing in hash table
	for (var i = 0u; i < MAX_HASH_PROBE; i++) {
		let current_slot = (slot + i) % HASH_TABLE_SIZE;
		let current_id = atomicLoad(&hash_table[current_slot].enode_id);

		if (current_id == INVALID_ID) {
			// Empty slot - try to claim it
			let new_enode_id = create_enode(op_code, canonical_children, region);
			if (new_enode_id == INVALID_ID) {
				return INVALID_ID; // Creation failed
			}

			let old = atomicCompareExchangeWeak(
				&hash_table[current_slot].enode_id,
				INVALID_ID,
				new_enode_id
			);

			if (old.exchanged) {
				return enode_to_eclass[new_enode_id]; // Successfully added
			} else {
				// Someone claimed this slot first - continue probing
				continue;
			}
		}

		// Check if existing node matches
		let existing_node = enodes[current_id];
		if (existing_node.op_code == op_code) {
			var match = true;
			for (var j = 0u; j < MAX_CHILDREN; j++) {
				if (find(existing_node.child_eclass_ids[j]) != canonical_children[j]) {
					match = false;
					break;
				}
			}

			if (match) {
				// Found match, but update region if needed to more persistent one
				merge_regions(enode_to_eclass[current_id], region);
				return enode_to_eclass[current_id]; // Found existing node
			}
		}
	}

	// Hash table probe limit exceeded
	return INVALID_ID;
}

// Determines the appropriate memory region for a node based on its operation and children
fn determine_node_region(op_code: u32, children: array<u32, MAX_CHILDREN>) -> RegionTag {
	// Default to persistent storage
	var region: RegionTag;
	region.persistent = true;

	// For simple value nodes that are used locally, we could optimize
	if (op_code == OP_VALUE_I32 || op_code == OP_VALUE_F32 || op_code == OP_VALUE_BOOL) {
		// Simple values might be candidates for stack or workgroup memory
		// Check usage patterns to determine if they can be optimized
	}

	// For operations used only within a pattern matching kernel
	if (is_pattern_local_operation(op_code)) {
		region.workgroup_shared = true;
		region.persistent = false;
	}

	// Propagate region requirements from children
	for (var i = 0u; i < MAX_CHILDREN; i++) {
		if (children[i] != INVALID_ID) {
			let child_eclass_id = find(children[i]);
			let child_region = eclasses[child_eclass_id].region_info;

			// If any child requires persistence, this node must too
			if (child_region.persistent) {
				region.persistent = true;
			}
		}
	}

	return region;
}

// Merges region information, ensuring the most conservative option is used
fn merge_regions(eclass_id: u32, new_region: RegionTag) {
	let canonical_id = find(eclass_id);
	var current_region = eclasses[canonical_id].region_info;

	// Always promote to more persistent region if needed
	if (new_region.persistent) {
		current_region.persistent = true;
	}

	if (new_region.workgroup_shared) {
		current_region.workgroup_shared = true;
	}

	eclasses[canonical_id].region_info = current_region;
}
```

### 7.4 Region-Aware Buffer Management

The WGSL implementation uses storage classes to reflect region-based allocation, with fixed-size buffers and atomic counters to track usage:

```wgsl
// Constants for buffer sizes
const MAX_ENODES: u32 = 100000u;
const MAX_ECLASSES: u32 = 100000u;
const HASH_TABLE_SIZE: u32 = 131072u; // Power of 2 for efficient modulo
const WORKGROUP_TEMP_SIZE: u32 = 256u; // Size for workgroup-shared temporary data

// Long-lived data in storage buffers (persistent region)
@group(0) @binding(0) var<storage, read_write> enodes: array<ENode, MAX_ENODES>;
@group(0) @binding(1) var<storage, read_write> eclasses: array<EClass, MAX_ECLASSES>;
@group(0) @binding(2) var<storage, read_write> hash_table: array<HashEntry, HASH_TABLE_SIZE>;

// Intermediate lifetime data (shared within workgroup region)
var<workgroup> workgroup_nodes: array<ENode, WORKGROUP_TEMP_SIZE>;
var<workgroup> workgroup_temp_data: array<u32, WORKGROUP_TEMP_SIZE>;

// Shortest lifetime data (thread-local region)
var<private> local_scratch: array<u32, 64>;
var<private> local_bindings: array<u32, MAX_BINDINGS>;

// Atomic counters
@group(0) @binding(5) var<storage, read_write> enode_count: atomic<u32>;
@group(0) @binding(6) var<storage, read_write> eclass_count: atomic<u32>;
@group(0) @binding(7) var<workgroup> workgroup_node_count: atomic<u32>;
```

### 7.5 Escape Analysis for Region Determination

The compiler performs basic escape analysis to determine appropriate regions for expressions:

```wgsl
// Pseudocode for the escape analysis process during compilation
fn analyze_escapes(expr) -> RegionTag {
	switch (expr.type) {
		case ConstantValue: {
			// Constants can often live in shorter-lived regions
			if (used_only_in_current_kernel(expr)) {
				return RegionTag(stack_local: true, workgroup_shared: false, persistent: false);
			}
			return RegionTag(persistent: true);
		}

		case TemporaryComputation: {
			// Check if result is only used within the current workgroup
			if (no_escape_from_workgroup(expr)) {
				return RegionTag(stack_local: false, workgroup_shared: true, persistent: false);
			}
			return RegionTag(persistent: true);
		}

		case EGraphNode: {
			// Nodes that persist across kernel invocations
			return RegionTag(persistent: true);
		}

		// Other expression types...
	}
}
```

## 8. WebGPU Runtime Integration

### 8.1 Runtime Implementation

The WebGPU runtime is implemented in TypeScript and handles GPU initialization, shader compilation, buffer creation, and kernel dispatch:

```typescript
async function runEqualitySaturation(wgslCode: string): Promise<Uint8Array> {
	// Initialize WebGPU
	if (!navigator.gpu) {
		throw new Error("WebGPU not supported");
	}

	const adapter = await navigator.gpu.requestAdapter();
	const device = await adapter.requestDevice();

	// Compile the WGSL shader
	const shaderModule = device.createShaderModule({
		code: wgslCode
	});

	// Create compute pipeline
	const computePipeline = device.createComputePipeline({
		layout: "auto",
		compute: {
			module: shaderModule,
			entryPoint: "pattern_match_kernel"
		}
	});

	// Create other compute pipelines (apply_rewrites, rebuild_congruence, cost_analysis)
	// ...

	// Create buffers
	const enodeBuffer = device.createBuffer({
		size: MAX_ENODES * ENODE_SIZE,
		usage: GPUBufferUsage.STORAGE | GPUBufferUsage.COPY_SRC | GPUBufferUsage.COPY_DST
	});

	// Create other buffers (eclasses, hash_table, value buffers, counters)
	// ...

	// Create bind group
	const bindGroup = device.createBindGroup({
		layout: computePipeline.getBindGroupLayout(0),
		entries: [
			{ binding: 0, resource: { buffer: enodeBuffer } },
			// Other buffer bindings
			// ...
		]
	});

	// Run initialization kernel to set up initial state
	// ...

	// Run equality saturation loop
	let changed = true;
	let iterations = 0;
	const MAX_ITERATIONS = 20;

	while (changed && iterations < MAX_ITERATIONS) {
		changed = false;
		iterations++;

		// Reset match count
		device.queue.writeBuffer(counterBuffers.matchCount, 0, new Uint32Array([0]));

		// 1. Pattern matching phase
		let commandEncoder = device.createCommandEncoder();
		let passEncoder = commandEncoder.beginComputePass();
		passEncoder.setPipeline(pipelines.patternMatch);
		passEncoder.setBindGroup(0, bindGroup);
		passEncoder.dispatchWorkgroups(Math.ceil(currentEClassCount / 256));
		passEncoder.end();
		device.queue.submit([commandEncoder.finish()]);

		// 2. Read match count and check if there were matches
		await device.queue.onSubmittedWorkDone();
		const matchCountBuffer = device.createBuffer({
			size: 4,
			usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
		});
		commandEncoder = device.createCommandEncoder();
		commandEncoder.copyBufferToBuffer(
			counterBuffers.matchCount, 0,
			matchCountBuffer, 0,
			4
		);
		device.queue.submit([commandEncoder.finish()]);

		await matchCountBuffer.mapAsync(GPUMapMode.READ);
		const matchCountData = new Uint32Array(matchCountBuffer.getMappedRange());
		const matchCount = matchCountData[0];
		matchCountBuffer.unmap();

		if (matchCount > 0) {
			changed = true;

			// 3. Apply rewrites phase
			commandEncoder = device.createCommandEncoder();
			passEncoder = commandEncoder.beginComputePass();
			passEncoder.setPipeline(pipelines.applyRewrites);
			passEncoder.setBindGroup(0, bindGroup);
			passEncoder.dispatchWorkgroups(Math.ceil(matchCount / 256));
			passEncoder.end();
			device.queue.submit([commandEncoder.finish()]);

			// 4. Rebuild congruence closure
			commandEncoder = device.createCommandEncoder();
			passEncoder = commandEncoder.beginComputePass();
			passEncoder.setPipeline(pipelines.rebuildCongruence);
			passEncoder.setBindGroup(0, bindGroup);
			passEncoder.dispatchWorkgroups(Math.ceil(currentENodeCount / 256));
			passEncoder.end();
			device.queue.submit([commandEncoder.finish()]);

			// 5. Update cost model
			commandEncoder = device.createCommandEncoder();
			passEncoder = commandEncoder.beginComputePass();
			passEncoder.setPipeline(pipelines.costAnalysis);
			passEncoder.setBindGroup(0, bindGroup);
			passEncoder.dispatchWorkgroups(Math.ceil(currentENodeCount / 256));
			passEncoder.end();
			device.queue.submit([commandEncoder.finish()]);
		}
	}

	// Read back final state
	const resultBuffers = await readBackBuffers(device, {
		enodes: enodeBuffer,
		eclasses: eclassBuffer,
		// Other buffers to read
		// ...
	});

	// Combine all buffer data into a single binary blob
	// ...

	return finalBinaryState;
}

async function readBackBuffers(device: GPUDevice, buffers: Record<string, GPUBuffer>):
	Promise<Record<string, ArrayBuffer>> {
	const results: Record<string, ArrayBuffer> = {};

	for (const [name, buffer] of Object.entries(buffers)) {
		const readBuffer = device.createBuffer({
			size: buffer.size,
			usage: GPUBufferUsage.COPY_DST | GPUBufferUsage.MAP_READ
		});

		const commandEncoder = device.createCommandEncoder();
		commandEncoder.copyBufferToBuffer(
			buffer, 0,
			readBuffer, 0,
			buffer.size
		);
		device.queue.submit([commandEncoder.finish()]);

		await readBuffer.mapAsync(GPUMapMode.READ);
		const data = readBuffer.getMappedRange();
		results[name] = data.slice(0);
		readBuffer.unmap();
	}

	return results;
}
```

### 8.2 Flow-to-WebGPU Interface

The integration between Flow and the WebGPU runtime is coordinated through file-based communication:

1. Flow compiler generates specialized WGSL code and saves it to a file
2. TypeScript WebGPU runtime loads this file and executes it
3. The runtime saves the binary result to another file or stdout
4. Flow reads this binary result and decodes it to extract the final optimized expression

## 9. Handling Advanced Orbit Features

### 9.1 Domain Hierarchies

Orbit's domain hierarchies (e.g., `Integer ⊂ Real ⊂ Complex`) are represented using bit flags and propagation rules:

```wgsl
// Domain constants
const DOMAIN_INTEGER: u32 = 1u;
const DOMAIN_REAL: u32 = 2u;
const DOMAIN_COMPLEX: u32 = 4u;

// Domain propagation rules
fn propagate_domains(eclass_id: u32, domain: u32) {
	let canonical_id = find(eclass_id);
	let current_domains = eclasses[canonical_id].domains;

	// Add new domain
	let updated_domains = current_domains | domain;

	// If domain is Integer, also add Real and Complex
	if (domain == DOMAIN_INTEGER) {
		updated_domains |= DOMAIN_REAL | DOMAIN_COMPLEX;
	}
	// If domain is Real, also add Complex
	else if (domain == DOMAIN_REAL) {
		updated_domains |= DOMAIN_COMPLEX;
	}

	// Update eclass domains
	eclasses[canonical_id].domains = updated_domains;
}
```

### 9.2 Symmetry Groups & Canonicalization on GPU

Orbit's symmetry groups (e.g., `S₂` for commutativity) are handled via canonicalization during the `rebuild_congruence_and_canonicalize_kernel` phase.

```wgsl
// Example S_n canonicalization logic within rebuild_congruence_and_canonicalize_kernel
// or called from update_representative:
fn canonicalize_S_n(root_eclass_id: u32) {
	// 1. Check if the representative node is an S_n operation (e.g., '+')
	let repr_node_id = eclasses[root_eclass_id].best_enode_id;
	let repr_node = enodes[repr_node_id];
	if (repr_node.op_code == OP_ADD /* or other S_n op */) {
		// 2. Access the already-flattened n-ary arguments directly
		// No tree traversal needed - Orbit-to-SExpr lowering already converted
		// expressions like a+b+c+(d+e)+f to `+`(a,b,c,d,e,f)
		let arg_count = repr_node.arity;
		var arguments: array<u32, MAX_ARGS_FOR_SORT>;
		for (var i = 0u; i < arg_count; i++) {
			arguments[i] = repr_node.args[i]; // Direct access to flattened args
		}

		// 3. Sort the argument e-class IDs
		// Requires a GPU sorting implementation (e.g., bitonic sort)
		sort_eclass_ids_gpu(&arguments, arg_count);

		// 4. Create canonical n-ary node directly
		// No tree rebuilding needed - just create new n-ary node with sorted args
		let canonical_node_id = create_n_ary_node(OP_ADD, &arguments, arg_count);

		// 5. Merge the original eclass with the canonical one
		let canonical_eclass_id = get_or_create_eclass(canonical_node_id);
		merge(root_eclass_id, canonical_eclass_id);
	}
}

// Simplified helper functions (no tree traversal/rebuilding needed)
fn sort_eclass_ids_gpu(elements: ptr<function, array<u32, MAX_ARGS_FOR_SORT>>, count: u32) { /* ... */ }
fn create_n_ary_node(op_code: u32, sorted_args: ptr<function, array<u32, MAX_ARGS_FOR_SORT>>, count: u32) -> u32 { /* ... */ }
fn get_or_create_eclass(node_id: u32) -> u32 { /* ... */ }
```
**Note:** Implementing the extract/sort/rebuild efficiently on the GPU is complex. It might involve temporary buffers, specialized sorting kernels, and careful handling of atomics if done concurrently. Simpler approaches might involve marking nodes for canonicalization and handling it in fewer threads or specific kernel passes.

### 9.3 Negative Domain Constraints

Orbit's negative domain constraints (e.g., `x !: Processed`) are implemented using bit operations:

```wgsl
// Check if eclass does NOT have a domain annotation
fn lacks_domain(eclass_id: u32, domain_id: u32) -> bool {
	let canonical_id = find(eclass_id);
	let domain_bitset = eclasses[canonical_id].domains;
	return (domain_bitset & (1u << domain_id)) == 0u;
}

// In pattern matching
if (pattern_requires_absence_of_domain && !lacks_domain(eclass_id, forbidden_domain_id)) {
	return false; // Negative constraint not satisfied
}
```

## 10. Performance Optimization Strategies

### 10.1 Workgroup Memory Usage

The WGSL implementation uses workgroup memory for frequently accessed data:

```wgsl
@compute @workgroup_size(256)
fn pattern_match_kernel(@builtin(global_invocation_id) global_id: vec3<u32>) {
	// Shared workgroup memory for frequently accessed e-classes
	var<workgroup> shared_eclasses: array<EClass, 256>;

	// Preload commonly accessed data
	if (global_id.x < 256u) {
		shared_eclasses[global_id.x] = eclasses[global_id.x];
	}
	workgroupBarrier();

	// Use shared_eclasses for frequent finds on small IDs
	// ...
}
```

### 10.2 Batched Processing

To optimize GPU utilization, multiple patterns are processed in batches:

```wgsl
// Instead of separate calls for each rule
if (match_rule0(eclass_id, &bindings)) { /* ... */ }
if (match_rule1(eclass_id, &bindings)) { /* ... */ }
// ...

// Use batched pattern matching
let batch_results = match_rule_batch(eclass_id, &bindings);
if ((batch_results & 1u) != 0u) { /* Rule 0 matched */ }
if ((batch_results & 2u) != 0u) { /* Rule 1 matched */ }
// ...

fn match_rule_batch(eclass_id: u32, bindings: ptr<function, array<u32, MAX_BINDINGS>>) -> u32 {
	// Common setup for all rules
	let canonical_id = find(eclass_id);
	let enode_id = eclasses[canonical_id].best_enode_id;
	if (enode_id == INVALID_ID) { return 0u; }
	let enode = enodes[enode_id];

	// Optimized batch pattern matching with common subpattern elimination
	// ...

	// Return bitset of matched rules
	return result_bitset;
}
```

### 10.3 Minimizing Atomic Operations

Atomic operations can be a performance bottleneck. The implementation minimizes them using techniques like batched updates and two-phase approaches:

```wgsl
// Instead of one match = one atomic update
for each match {
	atomicAdd(&match_count, 1u);
}

// Use workgroup-level batching
var<workgroup> local_matches: array<MatchInfo, 256>;
var<workgroup> local_match_count: atomic<u32>;

// First phase: accumulate in workgroup memory
let local_idx = atomicAdd(&local_match_count, 1u);
if (local_idx < 256u) {
	local_matches[local_idx] = match_info;
}
workgroupBarrier();

// Second phase: one thread performs the global update
if (local_thread_id == 0u) {
	let batch_start = atomicAdd(&match_count, local_match_count);
	for (var i = 0u; i < local_match_count; i++) {
		matches[batch_start + i] = local_matches[i];
	}
}
```

## 11. Serialization Format

### 11.1 Binary Encoding

The serialization format for the initial expression and final e-graph state follows these structures:

```
// Header format
{
	enodeCount: u32,
	eclassCount: u32,
	i32Count: u32,
	f32Count: u32,
	// Other counts
}

// ENode format (flattened array)
{
	op_code: u32,
	child_eclass_ids: [u32, ...] // up to MAX_CHILDREN
}[enodeCount]

// EClass format (flattened array)
{
	parent: u32,
	size: u32,
	best_enode_id: u32,
	domains: u32
}[eclassCount]

// i32 values
[i32][i32Count]

// f32 values
[f32][f32Count]

// Additional metadata
{
	rootEClassId: u32,
	// Other metadata
}
```

### 11.2 Extraction Algorithm

The extraction algorithm remains the same, using `best_enode_id` to recursively build the canonical expression from the final O-Graph state.

```flowish
fn extract(binary_state: [byte], root_eclass_id: int) -> EgExp {
	// Parse binary state
	memory = decode_binary_state(binary_state);

	// Find canonical root e-class ID
	canonical_root = find(root_eclass_id, memory.eclasses);

	// Recursively extract the canonical expression starting from the representative node
	return extract_from_eclass(canonical_root, memory);
}

fn extract_from_eclass(eclass_id: int, memory: Memory) -> EgExp {
	// Find canonical root for this ID
	canonical_id = find(eclass_id, memory.eclasses);
	eclass = memory.eclasses[canonical_id];

	// Use the representative ('best') node ID for extraction
	best_enode_id = eclass.best_enode_id;
	// ... (rest of extraction logic as before, using best_enode_id) ...
}

fn extract_from_enode(enode_id: int, memory: Memory) -> EgExp {
	enode = memory.enodes[enode_id];

	// Handle based on operation type
	switch (enode.op_code) {
		// Value types
		case OP_VALUE_I32: {
			value_idx = enode.child_eclass_ids[0];
			return EgInt(memory.ints[value_idx]);
		}
		case OP_VALUE_F32: {
			value_idx = enode.child_eclass_ids[0];
			return EgDouble(memory.f32s[value_idx]);
		}
		case OP_VALUE_BOOL: {
			return EgBool(enode.child_eclass_ids[0] != 0);
		}

		// Operations
		case OP_ADD: {
			left = extract_from_eclass(enode.child_eclass_ids[0], memory);
			right = extract_from_eclass(enode.child_eclass_ids[1], memory);
			return EgAdd(left, right);
		}
		case OP_MUL: {
			left = extract_from_eclass(enode.child_eclass_ids[0], memory);
			right = extract_from_eclass(enode.child_eclass_ids[1], memory);
			return EgMul(left, right);
		}
		// ... other operations

		default: {
			return EgError("Unknown operation: " + toString(enode.op_code));
		}
	}
}

fn find(id: int, eclasses: [EClass]) -> int {
	// Simple path compression
	if (eclasses[id].parent != id) {
		eclasses[id].parent = find(eclasses[id].parent, eclasses);
	}
	return eclasses[id].parent;
}
```

## 12. Challenges and Solutions

### 12.1 Limited Memory Management

**Challenge**: WebGPU has limited memory management capabilities with no dynamic allocation and distinct storage classes.

**Solution**: 
- Use fixed-size buffers with atomic counters to simulate allocation
- Implement region-based memory management to place data in appropriate storage classes
- Use hash consing for node reuse
- Perform static escape analysis during compilation to determine optimal allocation strategy

### 12.2 Race Conditions

**Challenge**: Multiple threads can attempt to update the same e-class or e-node simultaneously.

**Solution**: Use atomic operations for union-find and node creation, with careful synchronization in multi-phase kernels.

### 12.3 Repetitive Pattern Matching

**Challenge**: Naive pattern matching can waste GPU resources by repeatedly checking the same patterns.

**Solution**: Use worklists to focus on newly created or modified nodes, and employ early pruning to avoid expensive pattern matching on incompatible structures.

### 12.4 Limited Control Flow

**Challenge**: WGSL has limited support for complex control flow patterns used in recursive pattern matching.

**Solution**: Use iteration instead of recursion, with careful loop unrolling and inlining of pattern-specific logic.

### 12.5 Binary Data Exchange

**Challenge**: Transferring complex data structures between Flow and WebGPU is difficult.

**Solution**: Use a well-defined binary format for data exchange, with minimal state transfer (only final optimized state).

### 12.6 Memory Lifetime Management

**Challenge**: Different expressions have different lifetimes, but WGSL lacks automatic memory management.

**Solution**: 
- Use region annotations to track expression lifetimes during compilation
- Generate code that places expressions in appropriate memory regions based on their lifetime
- Implement a region verification system to ensure no references outlive their containing region
- Handle cross-region references by promoting objects to longer-lived regions when necessary

## 13. Future Extensions

### 13.1 Incremental E-Graph Updates

Extend the system to support incremental updates to the e-graph, allowing for efficient reoptimization when small changes are made.

### 13.2 Multi-GPU Support

Extend the system to distribute e-graph processing across multiple GPUs, with appropriate synchronization and data exchange.

### 13.3 Domain-Specific Rule Acceleration

Implement specialized WGSL kernels for common domain-specific rules, such as algebraic simplifications, tensor operations, or numerical methods.

### 13.4 Advanced Pattern Matching Algorithms

Explore advanced pattern matching algorithms like Rete or TREAT for more efficient parallel matching on the GPU.

### 13.5 Integration with External Solvers

Integrate with external constraint solvers or SMT solvers to handle complex conditions in rewrite rules.

### 13.6 Advanced Region-Based Memory Management

Enhance the region-based memory system with features like:
- Region polymorphism for operations that can work with multiple memory regions
- Gradual region inference to handle complex patterns without compiler annotations
- Region-aware data structure optimizations for e-graphs
- Hybrid regions that can migrate between storage classes based on runtime heuristics

### 13.7 Memory-Constrained Operation

Implement strategies for handling very large e-graphs that exceed GPU memory limits:
- Region-based spilling to host memory for rarely accessed nodes
- Workload partitioning based on region annotations
- Prioritized memory management that focuses on high-impact regions first

## 14. Conclusion

This document has specified an updated approach for a WebGPU-based implementation accelerating pattern matching and equality saturation in the Orbit rewriting system. By compiling Orbit patterns and evaluation logic directly to specialized WGSL code and leveraging the O-Graph's canonical representatives, we achieve high-performance parallel processing on GPUs. The system now explicitly addresses the need for GPU-side canonicalization of associative/commutative operations via an extract/sort/rebuild process and incorporates the goal of performing rule condition evaluation directly on the GPU. The integration of region-based memory management addresses WGSL's memory model constraints. This approach enables efficient pattern matching, rewriting, and convergence towards canonical forms across various domains supported by the Orbit framework.

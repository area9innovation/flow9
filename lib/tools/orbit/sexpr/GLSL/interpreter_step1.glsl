#version 450 core

// Include the AST data, constant pool, and primary tag/sform definitions
// The included file is expected to define:
// - TAG_SSINT, TAG_SSOPERATOR, TAG_SSLIST, TAG_SSSPECIALFORM, SFORM_BEGIN, etc.
// - PROGRAM_AST_SIZE, CONSTANT_POOL_SIZE
// - const float u_constant_pool[]
// - const float u_program_ast[]
#include "tests/basic2.glsl"

layout(std430, binding = 0) buffer OutputBuffer {
    float result_tag;
    float result_value;
} out_buffer;

// Runtime specific tags, not necessarily in the AST's own #defines
#define TAG_ERROR_RUNTIME 21.0f // Ensure this is distinct or aligned with basic2.glsl's TAG_ERROR if used

#define MAX_OPERAND_STACK_SIZE 16
#define MAX_CONTROL_STACK_SIZE 8

struct EvaluatedSexpr {
    float tag;
    float val1;
};

// Interpreter state (global for the shader invocation)
int pc;
EvaluatedSexpr operand_stack[MAX_OPERAND_STACK_SIZE];
int sp;

struct ControlFrame {
    int type; // What kind of operation is pending
    int node_idx; // Index of the aggregate node (LIST or BEGIN) this frame is for
    int current_child_to_eval; // For SSLIST: 0=op, 1=arg1, etc. (tracks how many children have been *scheduled*)
    int num_children_total;
    int children_start_idx_in_ast;
};
ControlFrame control_stack[MAX_CONTROL_STACK_SIZE];
int control_sp;

// --- Stack Helper Functions ---
void push_operand(EvaluatedSexpr val) {
    if (sp < MAX_OPERAND_STACK_SIZE) {
        operand_stack[sp++] = val;
    } else { /* Handle stack overflow */ operand_stack[0] = EvaluatedSexpr(TAG_ERROR_RUNTIME, 80.0f); sp=1; }
}

EvaluatedSexpr pop_operand() {
    if (sp > 0) {
        return operand_stack[--sp];
    }
    return EvaluatedSexpr(TAG_ERROR_RUNTIME, 81.0f); /* Stack underflow */
}

void push_control(ControlFrame frame) {
    if (control_sp < MAX_CONTROL_STACK_SIZE) {
        control_stack[control_sp++] = frame;
    } else { /* Handle control stack overflow */ push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 82.0f)); }
}

ControlFrame pop_control() {
    if (control_sp > 0) {
        return control_stack[--control_sp];
    }
    ControlFrame err_frame; err_frame.type = -1; // Invalid frame type
    return err_frame;
}
// --- End Stack Helper Functions ---

int get_node_size_from_type(float node_type_val) {
    if (node_type_val == TAG_SSINT || node_type_val == TAG_SSOPERATOR ||
        node_type_val == TAG_SSVARIABLE || node_type_val == TAG_SSCONSTRUCTOR || 
        node_type_val == TAG_SSDOUBLE || node_type_val == TAG_SSBOOL) { 
        return 2;
    }
    if (node_type_val == TAG_SSSTRING) return 3; 
    if (node_type_val == TAG_SSLIST || node_type_val == TAG_SSVECTOR) return 3; 
    if (node_type_val == TAG_SSSPECIALFORM) return 4;
    return 1; // Default/error or unknown type
}

#define CONTROL_TYPE_PENDING_LIST 1
#define CONTROL_TYPE_PENDING_BEGIN 2

void main() {
    pc = 0;
    sp = 0;
    control_sp = 0;
    bool running = true;

    while (running) {
        if (pc < 0 || pc >= PROGRAM_AST_SIZE) {
            push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 77.0f));
            running = false; break;
        }

        float current_node_type = u_program_ast[pc];

        if (current_node_type == TAG_SSINT) {
            push_operand(EvaluatedSexpr(current_node_type, u_program_ast[pc + 1]));
            pc += get_node_size_from_type(current_node_type);
        } else if (current_node_type == TAG_SSOPERATOR) {
            push_operand(EvaluatedSexpr(current_node_type, u_program_ast[pc + 1]));
            pc += get_node_size_from_type(current_node_type);
        } else if (current_node_type == TAG_SSSPECIALFORM) {
            float form_id = u_program_ast[pc + 1];
            int child_count = int(u_program_ast[pc + 2]);
            int children_start_idx = int(u_program_ast[pc + 3]);
            if (form_id == SFORM_BEGIN) {
                if (child_count == 0) {
                    push_operand(EvaluatedSexpr(TAG_SSBOOL, 0.0f)); 
                    pc += get_node_size_from_type(current_node_type);
                } else {
                    ControlFrame frame; frame.type = CONTROL_TYPE_PENDING_BEGIN; frame.node_idx = pc;
                    frame.num_children_total = child_count; frame.children_start_idx_in_ast = children_start_idx; frame.current_child_to_eval = 0;
                    push_control(frame);
                    pc = children_start_idx; 
                }
            } else {
                push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 10.0f)); running = false; 
            }
        } else if (current_node_type == TAG_SSLIST) {
            ControlFrame frame; frame.type = CONTROL_TYPE_PENDING_LIST; frame.node_idx = pc;
            frame.num_children_total = int(u_program_ast[pc + 1]);
            frame.children_start_idx_in_ast = int(u_program_ast[pc + 2]);
            frame.current_child_to_eval = 0; 
            if (frame.num_children_total > 0) {
                push_control(frame);
                pc = frame.children_start_idx_in_ast; 
            } else { 
                push_operand(EvaluatedSexpr(TAG_SSLIST, 0.0f)); 
                pc += get_node_size_from_type(current_node_type);
            }
        } else {
            push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 11.0f)); running = false; 
        }
        
        if (!running) break; // If initial node processing caused an error, stop before control stack processing

        while (control_sp > 0) {
            ControlFrame task = control_stack[control_sp - 1]; // Peek at the current task
            bool task_processed_or_advanced = false;

            if (task.type == CONTROL_TYPE_PENDING_LIST) {
                // Check if the child we *were* evaluating (task.current_child_to_eval) has produced its result on operand stack
                // We need sp to be task.current_child_to_eval + 1 for all results up to and including current_child_to_eval's result
                if (sp < task.current_child_to_eval + 1) {
                    break; // Waiting for current child's result, break from inner while, continue outer loop
                }

                task.current_child_to_eval++; // Advance to consider the next child / or completion

                if (task.current_child_to_eval < task.num_children_total) {
                    control_stack[control_sp - 1] = task; // Update task on stack
                    int next_child_pc = task.children_start_idx_in_ast;
                    for (int i = 0; i < task.current_child_to_eval; ++i) {
                        float child_node_type_to_skip = u_program_ast[next_child_pc];
                        next_child_pc += get_node_size_from_type(child_node_type_to_skip);
                    }
                    pc = next_child_pc;
                    task_processed_or_advanced = true; 
                    break; // Break from inner while to execute next child in outer while
                } else {
                    pop_control(); // All children evaluated
                    if (task.num_children_total == 3) { 
                        EvaluatedSexpr arg2 = pop_operand(); EvaluatedSexpr arg1 = pop_operand(); EvaluatedSexpr op = pop_operand();
                        if (op.tag == TAG_SSOPERATOR && op.val1 == 0.0f && arg1.tag == TAG_SSINT && arg2.tag == TAG_SSINT) {
                            push_operand(EvaluatedSexpr(TAG_SSINT, arg1.val1 + arg2.val1));
                        } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 12.0f)); running = false; }
                    } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 13.0f)); running = false; }
                    pc = task.node_idx + get_node_size_from_type(u_program_ast[task.node_idx]);
                    task_processed_or_advanced = true;
                }
            } else if (task.type == CONTROL_TYPE_PENDING_BEGIN) {
                 if (sp < 1 && task.num_children_total > 0 ) { // For BEGIN, we expect at least one result from its child sequence
                    break; // Waiting for child's result
                 }
                pop_control(); 
                // Result of BEGIN's child is already on operand stack and is the result of BEGIN.
                pc = task.node_idx + get_node_size_from_type(u_program_ast[task.node_idx]);
                task_processed_or_advanced = true;
            } else {
                 push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 14.0f)); running = false;
            }
            
            if (!running || !task_processed_or_advanced) break; // Error or if inner task couldn't advance, break inner while
        } 

        if (running && control_sp == 0 && sp == 1) { running = false; } // Successful completion
        else if (running && control_sp == 0 && pc >= PROGRAM_AST_SIZE) { // Reached end of AST processing by PC
            if(sp == 0 && u_program_ast[0] == TAG_SSSPECIALFORM && u_program_ast[1]==SFORM_BEGIN && int(u_program_ast[2])==0){
                // This was (begin) with no children which correctly left stack empty (or pushed specific void)
                // If TAG_SSBOOL, 0.0 was pushed for (begin), sp would be 1.
                // This path means (begin) was empty and its value is not on stack, we need to handle what this means.
                // For now, treat as error if not the explicit (begin) -> TAG_SSBOOL,0 case handled above. Better to ensure (begin) pushes a value.
                 push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 16.0f)); // Empty (begin) did not resolve to a value
            } else if(sp == 0) {
                 push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 15.0f));
            } else if (sp > 1) {
                 push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 17.0f)); // Too many values on stack
            }
            running = false;
        }
    }

    if (sp == 1) {
        out_buffer.result_tag = operand_stack[0].tag;
        out_buffer.result_value = operand_stack[0].val1;
    } else {
        if (sp == 0) { out_buffer.result_tag = TAG_ERROR_RUNTIME; out_buffer.result_value = 90.0f; }
        else { EvaluatedSexpr err_val = operand_stack[sp-1]; out_buffer.result_tag = err_val.tag; out_buffer.result_value = err_val.val1; }
    }
}

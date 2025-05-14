#version 450 core

// Include the AST data, constant pool, and primary tag/sform definitions
#include "tests/current_test_data.glsl"

layout(std430, binding = 0) buffer OutputBuffer {
    float result_tag;
    float result_value;
} out_buffer;

#define TAG_ERROR_RUNTIME 21.0f 

#define MAX_OPERAND_STACK_SIZE 16
#define MAX_CONTROL_STACK_SIZE 8

struct EvaluatedSexpr {
    float tag;
    float val1;
};

int pc;
EvaluatedSexpr operand_stack[MAX_OPERAND_STACK_SIZE];
int sp;

struct ControlFrame {
    int type; 
    int node_idx; 
    int current_child_to_eval; 
    int num_children_total;
    int children_start_idx_in_ast;
};
ControlFrame control_stack[MAX_CONTROL_STACK_SIZE];
int control_sp;

void push_operand(EvaluatedSexpr val) {
    if (sp < MAX_OPERAND_STACK_SIZE) { operand_stack[sp++] = val; } 
    else { operand_stack[0] = EvaluatedSexpr(TAG_ERROR_RUNTIME, 80.0f); sp=1; }
}
EvaluatedSexpr pop_operand() {
    if (sp > 0) { return operand_stack[--sp]; }
    return EvaluatedSexpr(TAG_ERROR_RUNTIME, 81.0f); 
}
void push_control(ControlFrame frame) {
    if (control_sp < MAX_CONTROL_STACK_SIZE) { control_stack[control_sp++] = frame; } 
    else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 82.0f)); }
}
ControlFrame pop_control() {
    if (control_sp > 0) { return control_stack[--control_sp]; }
    ControlFrame err_frame; err_frame.type = -1; return err_frame;
}

int get_node_size_from_type(float node_type_val) {
    // All nodes are now uniformly 4 bytes (4 float values)
    return 4;
}

#define CONTROL_TYPE_PENDING_LIST 1
#define CONTROL_TYPE_PENDING_BEGIN 2

void main() {
    pc = 0; sp = 0; control_sp = 0;
    bool running = true;

    while (running) {
        if (pc < 0 || pc >= PROGRAM_AST_SIZE) {
            push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 77.0f)); running = false; break;
        }
        float current_node_type = u_program_ast[pc];

        if (current_node_type == TAG_NOP) {
            // Skip NOP nodes (although they should only appear as padding)
            pc += get_node_size_from_type(current_node_type);
        } else if (current_node_type == TAG_SSINT) {
            push_operand(EvaluatedSexpr(current_node_type, u_program_ast[pc + 1]));
            pc += get_node_size_from_type(current_node_type);
        } else if (current_node_type == TAG_SSOPERATOR) {
            push_operand(EvaluatedSexpr(current_node_type, u_program_ast[pc + 1])); // val1 is const_pool_idx
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
            } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 10.0f)); running = false; }
        } else if (current_node_type == TAG_SSLIST) {
            ControlFrame frame; frame.type = CONTROL_TYPE_PENDING_LIST; frame.node_idx = pc;
            frame.num_children_total = int(u_program_ast[pc + 1]);
            frame.children_start_idx_in_ast = int(u_program_ast[pc + 2]);
            frame.current_child_to_eval = 0; 
            if (frame.num_children_total > 0) {
                push_control(frame); pc = frame.children_start_idx_in_ast; 
            } else { push_operand(EvaluatedSexpr(TAG_SSLIST, 0.0f)); pc += get_node_size_from_type(current_node_type); }
        } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 11.0f)); running = false; }
        
        if (!running) break;

        while (control_sp > 0) {
            ControlFrame task = control_stack[control_sp - 1];
            bool task_processed_or_advanced = false;

            if (task.type == CONTROL_TYPE_PENDING_LIST) {
                // Ensure the expected operand (result of last scheduled child) is on stack
                if (sp < task.current_child_to_eval + 1 && task.num_children_total > 0) { break; } 

                task.current_child_to_eval++; 
                if (task.current_child_to_eval < task.num_children_total) {
                    control_stack[control_sp - 1] = task; 
                    int next_child_pc = task.children_start_idx_in_ast;
                    for (int i = 0; i < task.current_child_to_eval; ++i) {
                        // Since all nodes are 4 bytes, we increment by 4
                        next_child_pc += 4;
                    }
                    pc = next_child_pc; task_processed_or_advanced = true; break; 
                } else {
                    pop_control(); 
                    if (task.num_children_total == 3) { // Assuming binary operators for now
                        EvaluatedSexpr arg2 = pop_operand(); EvaluatedSexpr arg1 = pop_operand(); EvaluatedSexpr op = pop_operand();
                        // Check for errors from pop_operand, though type checks below are primary for args
                        if (op.tag == TAG_ERROR_RUNTIME || arg1.tag == TAG_ERROR_RUNTIME || arg2.tag == TAG_ERROR_RUNTIME) {
                            push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 25.0f)); running = false; // Error during pop
                        } else if (op.tag == TAG_SSOPERATOR && arg1.tag == TAG_SSINT && arg2.tag == TAG_SSINT) {
                            float operator_pool_idx = op.val1;
                            int str_info_idx = int(operator_pool_idx); 

                            if (str_info_idx >= 0 && str_info_idx < CONSTANT_POOL_SIZE) {
                                float len = u_constant_pool[str_info_idx];
                                if ((str_info_idx + int(len)) < CONSTANT_POOL_SIZE) { 
                                    float first_char_code = u_constant_pool[str_info_idx + 1]; 
                                    
                                    if (len == 1.0f) { 
                                        if (first_char_code == 43.0f) { // '+'
                                            push_operand(EvaluatedSexpr(TAG_SSINT, arg1.val1 + arg2.val1));
                                        } else if (first_char_code == 45.0f) { // '-'
                                            push_operand(EvaluatedSexpr(TAG_SSINT, arg1.val1 - arg2.val1));
                                        } else if (first_char_code == 42.0f) { // '*'
                                            push_operand(EvaluatedSexpr(TAG_SSINT, arg1.val1 * arg2.val1));
                                        } else if (first_char_code == 47.0f) { // '/'
                                            if (arg2.val1 == 0.0f) {
                                                push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 22.0f)); running = false;
                                            } else {
                                                push_operand(EvaluatedSexpr(TAG_SSINT, float(int(arg1.val1) / int(arg2.val1))));
                                            }
                                        } else if (first_char_code == 61.0f) { // '='
                                            push_operand(EvaluatedSexpr(TAG_SSBOOL, (arg1.val1 == arg2.val1) ? 1.0f : 0.0f));
                                        } else if (first_char_code == 60.0f) { // '<'
                                            push_operand(EvaluatedSexpr(TAG_SSBOOL, (arg1.val1 < arg2.val1) ? 1.0f : 0.0f));
                                        } else if (first_char_code == 62.0f) { // '>'
                                            push_operand(EvaluatedSexpr(TAG_SSBOOL, (arg1.val1 > arg2.val1) ? 1.0f : 0.0f));
                                        } else {
                                            push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 18.0f)); running = false; 
                                        }
                                    } else if (len == 3.0f && 
                                               u_constant_pool[str_info_idx + 1] == 109.0f && 
                                               u_constant_pool[str_info_idx + 2] == 111.0f && 
                                               u_constant_pool[str_info_idx + 3] == 100.0f) { // "mod"
                                        if (arg2.val1 == 0.0f) {
                                            push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 23.0f)); running = false;
                                        } else {
                                            push_operand(EvaluatedSexpr(TAG_SSINT, float(int(arg1.val1) % int(arg2.val1))));
                                        }
                                    } else {
                                        push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 19.0f)); running = false; 
                                    }
                                } else { 
                                     push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 24.0f)); running = false; 
                                }
                            } else {
                                push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 20.0f)); running = false; 
                            }
                        } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 12.0f)); running = false; } 
                    } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 13.0f)); running = false; } 
                    pc = task.node_idx + get_node_size_from_type(u_program_ast[task.node_idx]);
                    task_processed_or_advanced = true;
                }
            } else if (task.type == CONTROL_TYPE_PENDING_BEGIN) {
                 if (sp < 1 && task.num_children_total > 0 ) { break; } 
                pop_control(); 
                pc = task.node_idx + get_node_size_from_type(u_program_ast[task.node_idx]);
                task_processed_or_advanced = true;
            } else { push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 14.0f)); running = false; } 
            
            if (!running || !task_processed_or_advanced) break; 
        } 

        if (running && control_sp == 0 && sp == 1) { 
            running = false;
        }
        else if (running && control_sp == 0 && pc >= PROGRAM_AST_SIZE) { 
            if(sp == 0) { 
                 push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 15.0f)); 
            } else if (sp > 1 && operand_stack[sp-1].tag != TAG_ERROR_RUNTIME) { 
                 push_operand(EvaluatedSexpr(TAG_ERROR_RUNTIME, 17.0f)); 
            } 
            running = false;
        }
    }

    if (sp == 1) {
        out_buffer.result_tag = operand_stack[0].tag;
        out_buffer.result_value = operand_stack[0].val1;
    } else { 
        if (sp == 0) { 
             out_buffer.result_tag = TAG_ERROR_RUNTIME;
             out_buffer.result_value = 90.0f; 
        } else { 
            EvaluatedSexpr top_val = operand_stack[sp-1]; 
            out_buffer.result_tag = top_val.tag;
            out_buffer.result_value = top_val.val1;
        }
    }
}

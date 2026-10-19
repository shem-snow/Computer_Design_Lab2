module PC_Logic(
	input reset,
	input clock,
	input [15:0] CDB, // Common Data Bus
	input [15:0] PC, // old/current $PC value
	input [15:0] imm, // immediate bits
	
	input pc_offset,
	input jump,
	input link,
	input return,
	
	output [15:0] new_pc
);

	// Internal connections
	wire [15:0] jump_amount, pc_plus_jump, pc_inc, new_pc_jump, new_pc_inc, linked_pc;
	reg [15:0] return_address_stack [0:7];
	reg [2:0] stack_pointer = 0;

	// Internal modules/blocks
	assign linked_pc = return_address_stack[stack_pointer];
	assign jump_amount = pc_offset? CDB : imm; // Mux for determining jump amount.
	assign pc_plus_jump = jump? jump_amount + PC: 16'b0; // Output of jump-adder.
	assign pc_inc = PC + 1; // typical PC increment.
	assign new_pc_jump = jump? pc_plus_jump : pc_inc; // Mux for final jump value.
	assign new_pc = return? linked_pc : new_pc_jump; // Mux at the output.
	
	integer i;
	always@(posedge clock) begin
		if(reset) begin
			stack_pointer <= 3'b0;
			for(i = 0; i < 16; i = i + 1) begin
				return_address_stack[i] <= 16'b0;
			end
		end
		else if(jump && link) begin
			return_address_stack[stack_pointer + 1] <= CDB;
			stack_pointer <= (stack_pointer >= 15)? 0 : stack_pointer + 1;
		end
		else if(return) begin
			stack_pointer <= (stack_pointer <= 0)? 0 : stack_pointer - 1;
		end
		else
			stack_pointer <= stack_pointer;
	end

endmodule
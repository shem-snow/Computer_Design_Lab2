module PC_Logic(
	input [15:0] CDB, // Common Data Bus. Carries R[target] for jumps.
	input [15:0] PC, // old/current $PC value
	input [15:0] imm, // sign-extended branch displacement
	
	input branch, // Bcond with a true condition: relative
	input jump, // Jcond with a true condition, or JAL: absolute
	
	output [15:0] new_pc,
	output [15:0] link_pc // return address. JAL writes this into Rlink.
);

	// Internal connections
	wire [15:0] pc_inc, pc_plus_branch, new_pc_branch;

	// Internal modules/blocks
	assign pc_inc = PC + 1; // Typical PC increment.
	assign pc_plus_branch = PC + imm; // Output of branch-adder.
	assign new_pc_branch = branch? pc_plus_branch : pc_inc; // Mux for branch or increment.
	assign new_pc = jump? CDB : new_pc_branch; // Mux at the output. Jumps are absolute.
	
	assign link_pc = pc_inc;

endmodule
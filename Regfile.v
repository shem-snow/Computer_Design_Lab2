module Regfile #(
	parameter WIDTH = 16,
	parameter NUM_REGISTERS = 16,
	parameter ADDRESS_WIDTH = 4
)	(
		input clock,
		input reset,
		
		input [ADDRESS_WIDTH-1:0] Rsrc_address,
		input [ADDRESS_WIDTH-1:0] Rdest_address,
		
		input [WIDTH-1:0] write_enable,
		input [WIDTH-1:0] write_data,
		
		output [WIDTH-1:0] Rsrc_data,
		output [WIDTH-1:0] Rdest_data
	);
	
		reg [WIDTH-1:0] regs [2**ADDRESS_WIDTH-1:0];
		integer i;
		
		assign Rsrc_data = regs[Rsrc_address];
		assign Rdest_data = regs[Rdest_address];
		
		always @(posedge clock) begin
			if (reset)
				for (i = 0; i < NUM_REGISTERS; i = i + 1)
					regs[i] <= {WIDTH{1'b0}};
			
			else
				for (i = 0; i < NUM_REGISTERS; i = i + 1)
					if (write_enable[i])
						regs[i] <= write_data;
		end
endmodule

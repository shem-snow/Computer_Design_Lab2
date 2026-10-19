In this project, I am making a RISC-V based processor which will execute the Tetris game.
Once Tetris is implemented, I want to edit the processor to execute multiple instructions at a time following Tomasulo's approach and see if it runs faster.


Some design decisions made along the way:

  1. Branching/Jumping:
      a. I can use relative or absolute addressing.
      b. I can use the ALU to compute destination addresses or add hardware into the datapath for calculating it.
          I chose absolute addressing over relative. I also abandoned an idea to instantiate a "PC_Logic" module that manages its own 8-deep stack of return addresses.
  2. ALU complexity:
      By placing a "decoder" unit in the datapath outside the ALU, I can make the ALU more simple. This is what I would have liked to do, but the
      course instructor specifically told me to do it in the ALUE and make the ALU handle every possible instruction even as I argued that it caused duplicate logic.
      When I get around to making the processor superscaler, I'll definitely change this.
  3. Number of write_enable signals at the register file.
      Only one write is needed for this ISA. Using multiple write_enables adds more FSM control signals. However, course instruction says to have multiple.
  4. Memory read-during-write mode.
      Memory.v has a WRITE_FIRST parameter. Write-first ("new data") is the default in Quartus' true dual-port template and it means a value written on a 
      port is what that port immediately reads back. testbenches/tb_Memory.v runs both modes side by side.
      The test FSM in demos/demo_Memory.v never reads an address on the same edge it writes it, so it works in either mode.
  5. What can store to memory?
      Everything written to memory must do so at the "Common_Data_BUS" which is at the output of the ALU.
     



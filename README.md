In this project, I am making a RISC-V based processor which will execute the Tetris game.
Once Tetris is implemented, I want to edit the processor to execute multiple instructions at a time following Tomasulo's approach and see if it runs faster.


Some design decisions made along the way:

  1. Branching/Jumping:
      a. I can use relative or absolute addressing.
      b. I can use the ALU to compute destination addresses or add hardware into the datapath for calculating it.
          With super-scaler processing in mind, I'm picking relative addressing with dedicated hardware in the datapath for computing new addresses.
  2. ALU complexity:
      By placing a "decoder" unit in the datapath outside the ALU, I can make the ALU more simple. This is what I would have liked to do, but the
      course instructions specified placing the decoder inside the ALU. When I get around to making the processor superscaler, I'll likely change this.
  3. Number of write_enable signals at the register file.
      Only one write is needed for this ISA. Using multiple write_enables adds more FSM control signals. However, course instruction says to have multiple.

In this project, I am making a RISC-V based processor which will execute the Tetris game.
Once Tetris is implemented, I want to edit the processor to execute multiple instructions at a time following Tomasulo's approach and see if it runs faster.


Some design decisions I made along the way:

  1. Branching/Jumping:
      a. I can use relative or absolute addressing.
      b. I can use the ALU to compute destination addresses or add hardware into the datapath for calculating it.
          Keeping super-scaler processing in mind, I'm picking relative addressing with dedicated hardware in the datapath.
  2. 

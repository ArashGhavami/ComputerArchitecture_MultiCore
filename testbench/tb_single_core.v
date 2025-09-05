module tb;
    reg clk, rst, Jen;
    reg [31:0] instructions[512];
    reg [31:0] data_mem[512];

    reg [31:0] Jin;
    wire [31:0] Jout;
    wire InstDone;
    wire [31:0] R[32];
    assign R[0] = 0;

    reg [31:0] inst_reg;
    reg [4:0] inst_rs, inst_rt, inst_rd;
    reg [31:0] val_rs, val_rt;
    reg [15:0] inst_imm;
    reg signed [31:0] inst_imm_sext;
    reg [8:0] ipc;
    reg [31:0] ireg[32];
    reg [31:0] ireghi, ireglo;
    reg [31:0] data_addr;
    reg signed [31:0] val_signed_rs;
    reg signed [31:0] val_signed_rt;
    task write2reg(input [4:0] reg_dest, input [31:0] val);
        begin
            if (reg_dest !== 0) ireg[reg_dest] = val;
        end
    endtask
    function [31:0] sra(input [31:0] a, input [4:0] b);
        begin
            sra = ({{32{a[31]}}, a} >> b);
        end
    endfunction
    task exec_internal;
        begin
            inst_reg = instructions[ipc];
            ipc += 1;

            inst_rs = inst_reg[25:21];
            inst_rt = inst_reg[20:16];
            inst_rd = inst_reg[15:11];
            inst_imm = inst_reg[15:0];
            inst_imm_sext = {{16{inst_imm[15]}}, inst_imm};
            val_rs = ireg[inst_rs];
            val_rt = ireg[inst_rt];
            val_signed_rs = val_rs;
            val_signed_rt = val_rt;
            case (inst_reg[31:26])
                6'b000000: begin  // RType
                    case (inst_reg[5:0])
                        6'b100000: write2reg(inst_rd, val_rs + val_rt);  // add
                        6'b100010: write2reg(inst_rd, val_rs - val_rt);  // sub
                        6'b100100: write2reg(inst_rd, val_rs & val_rt);  // and
                        6'b100101: write2reg(inst_rd, val_rs | val_rt);  // or
                        6'b100110: write2reg(inst_rd, val_rs ^ val_rt);  // xor
                        6'b000100: write2reg(inst_rd, val_rs << val_rt[4:0]);  // sll
                        6'b000110: write2reg(inst_rd, val_rs >> val_rt[4:0]);  // srl
                        6'b000111: write2reg(inst_rd, sra(val_rs, val_rt[4:0]));  // sra
                        6'b000000:
                        write2reg(inst_rd, val_rt << inst_reg[10:6]);  // sll (imm) rd=rt<<shamt
                        6'b011010: begin  // div HI=rs%rt; LO=rs/rt
                            ireghi = val_rs % val_rt;
                            ireglo = val_rs / val_rt;
                        end
                        6'b010000: write2reg(inst_rd, ireghi);  // mfhi rd=HI
                        6'b010010: write2reg(inst_rd, ireglo);  // mflo rd=LO
                        6'b001000: ipc = val_rs;  // jr : ipc=rs
                        default $display("NOT IMPLEMENTED : rtype[func: %b]", inst_reg[5:0]);
                    endcase
                end
                6'b001000: write2reg(inst_rt, val_rs + inst_imm_sext);  // addi
                6'b101011: begin  // sw *(int*)(offset+rs)=rt
                    // $display("wat", val_rs, " ", val_rt, " ", inst_imm_sext);
                    data_addr = val_rs + inst_imm_sext;
                    if (data_addr & 3 !== 0)
                        $display(
                            "WARNING : Unaligned data address (%x)",
                            data_addr,
                            "  %x => %x %x",
                            inst_rs,
                            val_rs,
                            inst_imm_sext
                        );
                    $display("stor %x", (data_addr >> 2) & 511);
                    data_mem[(data_addr>>2)&511] = val_rt;
                end
                6'b100011: begin  // lw rt=*(int*)(offset+rs)
                    data_addr = val_rs + inst_imm_sext;
                    if (data_addr & 3 !== 0)
                        $display(
                            "WARNING : Unaligned data address (%x)",
                            data_addr,
                            "  %x => %x %x",
                            inst_rs,
                            val_rs,
                            inst_imm_sext
                        );
                    $display("load %x", (data_addr >> 2) & 511);
                    write2reg(inst_rt, data_mem[(data_addr>>2)&511]);
                end
                6'b000101: begin  // bne if(rs!=rt) pc+=offset
                    $display("wat", val_rs, " != ", val_rt, " ", inst_imm_sext);
                    ipc += val_rs != val_rt ? inst_imm_sext : 0;
                end
                6'b000100: begin  // beq if(rs==rt) pc+=offset
                    $display("wat", val_rs, " == ", val_rt, " ", inst_imm_sext);
                    ipc += val_rs == val_rt ? inst_imm_sext : 0;
                end
                6'b001010: write2reg(inst_rt, val_rs < inst_imm_sext ? 1 : 0);  // slti rt=rs<imm
                6'b000010: ipc = inst_imm;  // j pc=target
                6'b000011: begin  // jal ra=pc pc=target
                    write2reg(31, ipc);
                    ipc = inst_imm;
                end
                6'b011100: begin  // mul rd = rs * rt
                    // instruction format is a bit convoluted!
                    write2reg(inst_rd, val_signed_rs * val_signed_rt);
                end
                default $display("NOT IMPLEMENTED : [opcode: %b]", inst_reg[31:26]);
            endcase
            // c inst_reg[31:26]
        end
    endtask

    main _main (
        .clk(clk),
        .rst(rst),
        .Jen(Jen),
        .Jin(Jin),
        .Jout(Jout),
        .InstDone(InstDone),
        .R1(R[1]),
        .R2(R[2]),
        .R3(R[3]),
        .R4(R[4]),
        .R5(R[5]),
        .R6(R[6]),
        .R7(R[7]),
        .R8(R[8]),
        .R9(R[9]),
        .R10(R[10]),
        .R11(R[11]),
        .R12(R[12]),
        .R13(R[13]),
        .R14(R[14]),
        .R15(R[15]),
        .R16(R[16]),
        .R17(R[17]),
        .R18(R[18]),
        .R19(R[19]),
        .R20(R[20]),
        .R21(R[21]),
        .R22(R[22]),
        .R23(R[23]),
        .R24(R[24]),
        .R25(R[25]),
        .R26(R[26]),
        .R27(R[27]),
        .R28(R[28]),
        .R29(R[29]),
        .R30(R[30]),
        .R31(R[31])
    );

    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end
	
    int time_cur1;
    int time_cur2;
    int i;
    int last_instr;
    int nsteps;
    int j;
    int fail_flag;
    initial begin
        for (i = 0; i < 512; i++) instructions[i] = 0;
        for (i = 0; i < 512; i++) data_mem[i] = 0;
        for (i = 0; i < 32; i++) ireg[i] = 0;
        ireghi = 0;
        ireglo = 0;
        ipc = 0;
        nsteps = 0;
    instructions[0] = 32'b00100000000000110000000000000000; // addi $3, $0, 0
	instructions[1] = 32'b00100000000001000000000100000000; // addi $4, $0, 256
	instructions[2] = 32'b10101100011000110000000000000000; // sw $3, 0($3)     
	instructions[3] = 32'b00100000011000110000000000000100; // addi $3, $3, 4
	instructions[4] = 32'b00010100011001001111111111111101; // bne $3, $4, -3
	instructions[5] = 32'b00100000000000110000000000000000; // addi $3, $0, 0
	instructions[6] = 32'b10101100011000110000000100000000; // sw $3, 256($3)     
    instructions[7] = 32'b00100000011000110000000000000100;// addi $3, $3, 4
    instructions[8] = 32'b00010100011001001111111111111101; // bne $3, $4, -3
	instructions[9] = 32'b00100000000000110000000000000000;// addi $3, $0, 0
	instructions[10] = 32'b00100000000001000000000000000100;// addi $4, $0, 4
	instructions[11] = 32'b00100000000001010000000000000000;// addi $5, $0, 0
	instructions[12] = 32'b00100000000001100000000000001000;// addi $6, $0, 8
	instructions[13] = 32'b00100000000001110000000000000000;// addi $7, $0, 0
	instructions[14] = 32'b00100000000010000000000000001000;// addi $8, $0, 8
	instructions[15] = 32'b00100000000010010000000000000000;// addi $9, $0, 0
	instructions[16] = 32'b00100000000010100000000000001000;// addi $10, $0, 8
	instructions[17] = 32'b00000000000000110101000011000000; // sll $10, $3, 3
	instructions[18] = 32'b00000001010001110101000000100000; // add $10, $10, $7
    instructions[19] = 32'b00000000000010100101000010000000;// sll $10, $10, 2
	instructions[20] = 32'b10001101010010100000000000000000; // lw $10, 0($10)
	instructions[21] = 32'b00100000000010110000000000001000;// addi $11, $0, 8
    instructions[22] = 32'b00000000000001110101100011000000;// sll $11, $7, 3
    instructions[23] = 32'b00000001011001010101100000100000;// add $11, $11, $5
    instructions[24] = 32'b00000000000010110101100010000000;// sll $11, $11, 2
    instructions[25] = 32'b10001101011010110000000000000000;// lw $11, 0($11)
	instructions[26] = 32'b01110001010010110101000000000000;// mul $10, $10, $11
	instructions[27] = 32'b00000001001010100100100000100000;// add $9, $9, $10
	instructions[28] = 32'b00100000111001110000000000000001;// addi $7, $7,1
	instructions[29] = 32'b00010101000001111111111111110010;// bne $8, $7, -14
	instructions[30] = 32'b00100000000010100000000000001000;// addi $10, $0, 8
	instructions[31] = 32'b00000000000000110101000011000000;// sll $10, $3, 3
	instructions[32] = 32'b00000001010001010101000000100000;// add $10, $10, $5
    instructions[33] = 32'b00000000000010100101000010000000;// sll $10, $10, 2 
	instructions[34] = 32'b10101101010010010000001000000000;// sw $9, 512($10)  
	instructions[35] = 32'b00100000101001010000000000000001;// addi $5, $5, 1 
	instructions[36] = 32'b00010100110001011111111111101000;// bne $5, $6, -24
	instructions[37] = 32'b00100000011000110000000000000001;// addi $3, $3, 1
	instructions[38] = 32'b00010100100000111111111111100100;// bne $4, $3, -28
    instructions[39] = 32'b00100000000010010000000000000000;//addi $9, $0, 0
	instructions[40] = 32'b00100000000000110000000000000000;// addi $3, $0, 0
	instructions[41] = 32'b00100000000001000000000000000100;// addi $4, $0, 4
	instructions[42] = 32'b00100000000001010000000000000000;// addi $5, $0, 0
	instructions[43] = 32'b00100000000001100000000000001000;// addi $6, $0, 8
    instructions[44] = 32'b00000000000000110101000000100000;//add $10, $0, $3
	instructions[45] = 32'b00000000000000110101000011000000;// sll $10, $3, 3
    instructions[46] = 32'b00000001010001010101000000100000;// add $10, $10, $5
    instructions[47] = 32'b00000000000010100101000010000000;// sll $10, $10, 2 
	instructions[48] = 32'b10001101010010010000001000000000;// lw $11, 512($10)
    instructions[49] = 32'b00000001001010110100100000100000;// add $9, $9, $11
	instructions[50] = 32'b00100000101001010000000000000001;// addi $5, $5, 1 
	instructions[51] = 32'b00010100110001011111111111111000;// bne $5, $6, -8
	instructions[52] = 32'b00100000011000110000000000000001;// addi $3, $3, 1
	instructions[53] = 32'b00010100100000111111111111110100;// bne $4, $3, -12
    instructions[54] = 32'b00100000000000110000000000000000;//addi $3, $0, 0
    instructions[55] = 32'b10101100011010010000000000000000;//sw $9, 0($3)

        last_instr = 56;
        nsteps = 4586;  // sorry

        rst = 1;
        #8 rst = 0;
        Jen = 1;
        for (i = 0; i < 512; i++) begin  // D mem
            Jin = data_mem[511-i];
            #2;
        end
        for (i = 0; i < 512; i++) begin
            Jin = instructions[511-i];
            #2;
        end
        Jen = 0;
        rst = 1;
        #2 rst = 0;  // cpu-ex
        fail_flag = 0;

        // $monitor(" [2]%x ", ireg[2], " , [4]%x ", ireg[4]);
        // $monitor("Expectation : ", " [1]%x", ireg[1], " [2]%x", ireg[2], " [3]%x", ireg[3],
        //          " [4]%x", ireg[4], " [5]%x", ireg[5],  /* " [6]%x", ireg[6], " [7]%x", ireg[7],
        //          " [8]%x", ireg[8], " [9]%x", ireg[9], " [10]%x", ireg[10], " [11]%x", ireg[11],
        //          " [12]%x", ireg[12], " [13]%x", ireg[13], " [14]%x", ireg[14], " [15]%x",
        //          ireg[15], " [16]%x", ireg[16], " [17]%x", ireg[17], " [18]%x", ireg[18],
        //          " [19]%x", ireg[19], " [20]%x", ireg[20], " [21]%x", ireg[21], " [22]%x",
        //          ireg[22], " [23]%x", ireg[23], " [24]%x", ireg[24], " [25]%x", ireg[25],
        //          " [26]%x", ireg[26], " [27]%x", ireg[27], " [28]%x", ireg[28], */
        //          " [29]%x", ireg[29], " [30]%x", ireg[30], " [31]%x", ireg[31]);
	//
	time_cur1 = $time;
        for (i = 0; ipc < last_instr && !fail_flag; i++) begin
            if (!fail_flag) begin
                $display("ipc : ", ipc);
                exec_internal();
                #2;
                while (InstDone !== 1) #2;  // waiting until your circuit is ready

                for (j = 1; j < 32; j++) if (R[j] !== ireg[j]) //fail_flag = 1;
                if (fail_flag) begin
                    //$display("Expectation : ", " [1]%x", ireg[1], " [2]%x", ireg[2], " [3]%x",
                  //           ireg[3], " [4]%x", ireg[4], " [5]%x", ireg[5],
                            // /* " [6]%x", ireg[6], " [7]%x", ireg[7],
                          //       " [8]%x", ireg[8], " [9]%x", ireg[9], " [10]%x", ireg[10], " [11]%x", ireg[11],
                        //         " [12]%x", ireg[12], " [13]%x", ireg[13], " [14]%x", ireg[14], " [15]%x",
                      //           ireg[15], " [16]%x", ireg[16], " [17]%x", ireg[17], " [18]%x", ireg[18],
                    //             " [19]%x", ireg[19], " [20]%x", ireg[20], " [21]%x", ireg[21], " [22]%x",
                  //               ireg[22], " [23]%x", ireg[23], " [24]%x", ireg[24], " [25]%x", ireg[25],
                //                 " [26]%x", ireg[26], " [27]%x", ireg[27], " [28]%x", ireg[28], */
              //               " [29]%x", ireg[29], " [30]%x", ireg[30], " [31]%x", ireg[31]);
            //        $display("Reality : ", " [1]%x", R[1], " [2]%x", R[2], " [3]%x", R[3],
                     //        " [4]%x", R[4], " [5]%x", R[5]  /* , " [6]%x", R[6], " [7]%x", R[7],
                   //     " [8]%x", R[8], " [9]%x", R[9], " [10]%x", R[10], " [11]%x", R[11],
                 //       " [12]%x", R[12], " [13]%x", R[13], " [14]%x", R[14], " [15]%x", R[15],
               //         " [16]%x", R[16], " [17]%x", R[17], " [18]%x", R[18], " [19]%x", R[19],
             //           " [20]%x", R[20], " [21]%x", R[21], " [22]%x", R[22], " [23]%x", R[23],
           //             " [24]%x", R[24], " [25]%x", R[25]  , " [26]%x", R[26], " [27]%x", R[27],
         //               " [28]%x", R[28]*/,
       //                      " [29]%x", R[29], " [30]%x", R[30], " [31]%x", R[31]);
                    $display("FAILED");
                    $display(i, " /", nsteps);
                end
            end
        end
        if (!fail_flag) begin
 //           $display("mem : ", "[1f9] : ", data_mem[505], "[1fa] : ", data_mem[506], "[1fb] : ",
   //                  data_mem[507], "[1fc] : ", data_mem[508], "[1fd] : ", data_mem[509],
     //                "[1fe] : ", data_mem[510], "[1ff] : ", data_mem[511]);
            $display("ACCEPTED");
            $display(i, " /", nsteps);
        end
	time_cur2 = $time;
	time_cur2 = time_cur2-time_cur1;
	$display("total time:%0d", time_cur2);

        $finish(0);
    end
endmodule
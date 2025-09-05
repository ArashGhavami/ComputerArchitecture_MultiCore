`timescale 1ps/1ps

module tb;
    reg clk, rst, Jen;
    reg [31:0] Jin;
    reg [31:0] instructions[512];
    reg [31:0] data_mem[512];
    wire [31:0] Jout;

    wire InstDone0, InstDone1;
    wire [31:0] R0[32], R1[32];
    assign R0[0] = 0; assign R1[0] = 0;

    reg [31:0] inst_reg0, inst_reg1;
    reg [4:0] inst_rs0, inst_rt0, inst_rd0, inst_rs1, inst_rt1, inst_rd1;
    reg [31:0] val_rs0, val_rt0, val_rs1, val_rt1;
    reg [15:0] inst_imm0, inst_imm1;
    reg signed [31:0] inst_imm_sext0, inst_imm_sext1;
    reg [8:0] ipc0, ipc1;
    reg [31:0] ireg0[32], ireg1[32];
    reg [31:0] ireghi0, ireglo0, ireghi1, ireglo1;
    reg [31:0] data_addr0, data_addr1;
    reg signed [31:0] val_signed_rs0, val_signed_rt0, val_signed_rs1, val_signed_rt1;

task write2reg0(input [4:0] rd, input [31:0] val); if (rd != 0) ireg0[rd] = val; endtask
task write2reg1(input [4:0] rd, input [31:0] val); if (rd != 0) ireg1[rd] = val; endtask

    function [31:0] sra(input [31:0] a, input [4:0] b);
        begin
            sra = ({{32{a[31]}}, a} >> b);
        end
    endfunction

    task exec_internal0;
        begin
            inst_reg0 = instructions[ipc0];
            ipc0 += 1;

            inst_rs0 = inst_reg0[25:21];
            inst_rt0 = inst_reg0[20:16];
            inst_rd0 = inst_reg0[15:11];
            inst_imm0 = inst_reg0[15:0];
            inst_imm_sext0 = {{16{inst_imm0[15]}}, inst_imm0};
            val_rs0 = ireg0[inst_rs0];
            val_rt0 = ireg0[inst_rt0];
            val_signed_rs0 = val_rs0;
            val_signed_rt0 = val_rt0;
            case (inst_reg0[31:26])
                6'b000000: begin  // RType
                    case (inst_reg0[5:0])
                        6'b100000: write2reg0(inst_rd0, val_rs0 + val_rt0);  // add
                        6'b100010: write2reg0(inst_rd0, val_rs0 - val_rt0);  // sub
                        6'b100100: write2reg0(inst_rd0, val_rs0 & val_rt0);  // and
                        6'b100101: write2reg0(inst_rd0, val_rs0 | val_rt0);  // or
                        6'b100110: write2reg0(inst_rd0, val_rs0 ^ val_rt0);  // xor
                        6'b000100: write2reg0(inst_rd0, val_rs0 << val_rt0[4:0]);  // sll
                        6'b000110: write2reg0(inst_rd0, val_rs0 >> val_rt0[4:0]);  // srl
                        6'b000111: write2reg0(inst_rd0, sra(val_rs0, val_rt0[4:0]));  // sra
                        6'b000000:
                        write2reg0(inst_rd0, val_rt0 << inst_reg0[10:6]);  // sll (imm) rd=rt<<shamt
                        6'b011010: begin  // div HI=rs%rt; LO=rs/rt
                            ireghi0 = val_rs0 % val_rt0;
                            ireglo0 = val_rs0 / val_rt0;
                        end
                        6'b010000: write2reg0(inst_rd0, ireghi0);  // mfhi rd=HI
                        6'b010010: write2reg0(inst_rd0, ireglo0);  // mflo rd=LO
                        6'b001000: ipc0 = val_rs0;  // jr : ipc=rs
                        default $display("NOT IMPLEMENTED : rtype[func: %b]", inst_reg0[5:0]);
                    endcase
                end
                6'b001000: write2reg0(inst_rt0, val_rs0 + inst_imm_sext0);  // addi
                6'b101011: begin  // sw *(int*)(offset+rs)=rt
                    // $display("wat", val_rs, " ", val_rt, " ", inst_imm_sext);
                    data_addr0 = val_rs0 + inst_imm_sext0;
                    if (data_addr0 & 3 !== 0)
                        $display(
                            "WARNING : Unaligned data address (%x)",
                            data_addr0,
                            "  %x => %x %x",
                            inst_rs0,
                            val_rs0,
                            inst_imm_sext0
                        );
                    $display("stor %x", (data_addr0 >> 2) & 511);
                    data_mem[(data_addr0>>2)&511] = val_rt0;
                end
                6'b100011: begin  // lw rt=*(int*)(offset+rs)
                    data_addr0 = val_rs0 + inst_imm_sext0;
                    if (data_addr0 & 3 !== 0)
                        $display(
                            "WARNING : Unaligned data address (%x)",
                            data_addr0,
                            "  %x => %x %x",
                            inst_rs0,
                            val_rs0,
                            inst_imm_sext0
                        );
                    $display("load %x", (data_addr0 >> 2) & 511);
                    write2reg0(inst_rt0, data_mem[(data_addr0>>2)&511]);
                end
                6'b000101: begin  // bne if(rs!=rt) pc+=offset
                    $display("wat", val_rs0, " != ", val_rt0, " ", inst_imm_sext0);
                    ipc0 += val_rs0 != val_rt0 ? inst_imm_sext0 : 0;
                end
                6'b000100: begin  // beq if(rs==rt) pc+=offset
                    $display("wat", val_rs0, " == ", val_rt0, " ", inst_imm_sext0);
                    ipc0 += val_rs0 == val_rt0 ? inst_imm_sext0 : 0;
                end
                6'b001010: write2reg0(inst_rt0, val_rs0 < inst_imm_sext0 ? 1 : 0);  // slti rt=rs<imm
                6'b000010: ipc0 = inst_imm0;  // j pc=target
                6'b000011: begin  // jal ra=pc pc=target
                    write2reg0(31, ipc0);
                    ipc0 = inst_imm0;
                end
                6'b011100: begin  // mul rd = rs * rt
                    // instruction format is a bit convoluted!
                    write2reg0(inst_rd0, val_signed_rs0 * val_signed_rt0);
                end
                6'b100000: begin  // cpuid rs = 0
                    write2reg0(inst_rs0, 0);
                end
                6'b101010: begin  // sync
                    // sync
                end
                default $display("NOT IMPLEMENTED : [opcode: %b]", inst_reg0[31:26]);
            endcase
            // c inst_reg[31:26]
        end
    endtask

    task exec_internal1;
        begin
            inst_reg1 = instructions[ipc1];
            ipc1 += 1;

            inst_rs1 = inst_reg1[25:21];
            inst_rt1 = inst_reg1[20:16];
            inst_rd1 = inst_reg1[15:11];
            inst_imm1 = inst_reg1[15:0];
            inst_imm_sext1 = {{16{inst_imm1[15]}}, inst_imm1};
            val_rs1 = ireg1[inst_rs1];
            val_rt1 = ireg1[inst_rt1];
            val_signed_rs1 = val_rs1;
            val_signed_rt1 = val_rt1;
            case (inst_reg1[31:26])
                6'b000000: begin  // RType
                    case (inst_reg1[5:0])
                        6'b100000: write2reg1(inst_rd1, val_rs1 + val_rt1);  // add
                        6'b100010: write2reg1(inst_rd1, val_rs1 - val_rt1);  // sub
                        6'b100100: write2reg1(inst_rd1, val_rs1 & val_rt1);  // and
                        6'b100101: write2reg1(inst_rd1, val_rs1 | val_rt1);  // or
                        6'b100110: write2reg1(inst_rd1, val_rs1 ^ val_rt1);  // xor
                        6'b000100: write2reg1(inst_rd1, val_rs1 << val_rt1[4:0]);  // sll
                        6'b000110: write2reg1(inst_rd1, val_rs1 >> val_rt1[4:0]);  // srl
                        6'b000111: write2reg1(inst_rd1, sra(val_rs1, val_rt1[4:0]));  // sra
                        6'b000000:
                        write2reg1(inst_rd1, val_rt1 << inst_reg1[10:6]);  // sll (imm) rd=rt<<shamt
                        6'b011010: begin  // div HI=rs%rt; LO=rs/rt
                            ireghi1 = val_rs1 % val_rt1;
                            ireglo1 = val_rs1 / val_rt1;
                        end
                        6'b010000: write2reg1(inst_rd1, ireghi1);  // mfhi rd=HI
                        6'b010010: write2reg1(inst_rd1, ireglo1);  // mflo rd=LO
                        6'b001000: ipc1 = val_rs1;  // jr : ipc=rs
                        default $display("NOT IMPLEMENTED : rtype[func: %b]", inst_reg1[5:0]);
                    endcase
                end
                6'b001000: write2reg1(inst_rt1, val_rs1 + inst_imm_sext1);  // addi
                6'b101011: begin  // sw *(int*)(offset+rs)=rt
                    // $display("wat", val_rs, " ", val_rt, " ", inst_imm_sext);
                    data_addr1 = val_rs1 + inst_imm_sext1;
                    if (data_addr1 & 3 !== 0)
                        $display(
                            "WARNING : Unaligned data address (%x)",
                            data_addr1,
                            "  %x => %x %x",
                            inst_rs1,
                            val_rs1,
                            inst_imm_sext1
                        );
                    $display("stor %x", (data_addr1 >> 2) & 511);
                    data_mem[(data_addr1>>2)&511] = val_rt1;
                end
                6'b100011: begin  // lw rt=*(int*)(offset+rs)
                    data_addr1 = val_rs1 + inst_imm_sext1;
                    if (data_addr1 & 3 !== 0)
                        $display(
                            "WARNING : Unaligned data address (%x)",
                            data_addr1,
                            "  %x => %x %x",
                            inst_rs1,
                            val_rs1,
                            inst_imm_sext1
                        );
                    $display("load %x", (data_addr1 >> 2) & 511);
                    write2reg1(inst_rt1, data_mem[(data_addr1>>2)&511]);
                end
                6'b000101: begin  // bne if(rs!=rt) pc+=offset
                    $display("wat", val_rs1, " != ", val_rt1, " ", inst_imm_sext1);
                    ipc1 += val_rs1 != val_rt1 ? inst_imm_sext1 : 0;
                end
                6'b000100: begin  // beq if(rs==rt) pc+=offset
                    $display("wat", val_rs1, " == ", val_rt1, " ", inst_imm_sext1);
                    ipc1 += val_rs1 == val_rt1 ? inst_imm_sext1 : 0;
                end
                6'b001010: write2reg1(inst_rt1, val_rs1 < inst_imm_sext1 ? 1 : 0);  // slti rt=rs<imm
                6'b000010: ipc1 = inst_imm1;  // j pc=target
                6'b000011: begin  // jal ra=pc pc=target
                    write2reg1(31, ipc1);
                    ipc1 = inst_imm1;
                end
                6'b011100: begin  // mul rd = rs * rt
                    // instruction format is a bit convoluted!
                    write2reg1(inst_rd1, val_signed_rs1 * val_signed_rt1);
                end
                6'b100000: begin  // cpuid rs = 0
                    write2reg1(inst_rs1, 1);
                end
                6'b101010: begin  // sync
                    // sync
                end
                default $display("NOT IMPLEMENTED : [opcode: %b]", inst_reg1[31:26]);
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
        .instDone0(InstDone0),
        .instDone1(InstDone1),
        .R1_0(R0[1]),
        .R2_0(R0[2]),
        .R3_0(R0[3]),
        .R4_0(R0[4]),
        .R5_0(R0[5]),
        .R6_0(R0[6]),
        .R7_0(R0[7]),
        .R8_0(R0[8]),
        .R9_0(R0[9]),
        .R10_0(R0[10]),
        .R11_0(R0[11]),
        .R12_0(R0[12]),
        .R13_0(R0[13]),
        .R14_0(R0[14]),
        .R15_0(R0[15]),
        .R16_0(R0[16]),
        .R17_0(R0[17]),
        .R18_0(R0[18]),
        .R19_0(R0[19]),
        .R20_0(R0[20]),
        .R21_0(R0[21]),
        .R22_0(R0[22]),
        .R23_0(R0[23]),
        .R24_0(R0[24]),
        .R25_0(R0[25]),
        .R26_0(R0[26]),
        .R27_0(R0[27]),
        .R28_0(R0[28]),
        .R29_0(R0[29]),
        .R30_0(R0[30]),
        .R31_0(R0[31]),
        .R1_1(R1[1]),
        .R2_1(R1[2]),
        .R3_1(R1[3]),
        .R4_1(R1[4]),
        .R5_1(R1[5]),
        .R6_1(R1[6]),
        .R7_1(R1[7]),
        .R8_1(R1[8]),
        .R9_1(R1[9]),
        .R10_1(R1[10]),
        .R11_1(R1[11]),
        .R12_1(R1[12]),
        .R13_1(R1[13]),
        .R14_1(R1[14]),
        .R15_1(R1[15]),
        .R16_1(R1[16]),
        .R17_1(R1[17]),
        .R18_1(R1[18]),
        .R19_1(R1[19]),
        .R20_1(R1[20]),
        .R21_1(R1[21]),
        .R22_1(R1[22]),
        .R23_1(R1[23]),
        .R24_1(R1[24]),
        .R25_1(R1[25]),
        .R26_1(R1[26]),
        .R27_1(R1[27]),
        .R28_1(R1[28]),
        .R29_1(R1[29]),
        .R30_1(R1[30]),
        .R31_1(R1[31])
    );

    initial begin
        clk = 0;
        forever #1 clk = ~clk;
    end

    int i;
    int last_instr;
    int j;
    int fail_flag0;
    int fail_flag1;
    int k;
    int l;
    initial begin
        for (i = 0; i < 512; i++) instructions[i] = 0;
        for (i = 0; i < 512; i++) data_mem[i] = 0;
        for (i = 0; i < 32; i++) begin 
            ireg0[i] = 0;
            ireg1[i] = 0;
        end
        ireghi0 = 0;
        ireglo0 = 0;
        ipc0 = 0;
        ireghi1 = 0;
        ireglo1 = 0;
        ipc1 = 0;
        
        instructions[0] = 32'b100000_00100_000000000000000000000;  // cpuid $4
        instructions[1] = 32'b000101_00100_000000000000000001001;  // bne $4 , $0, 9

        // core 0
        instructions[2] = 32'b001000_00000_01000_0000000000000101;  // addi $8, $0, 5     -> $8 = 5
        instructions[3] = 32'b001000_00000_01001_0000000000001010;  // addi $9, $0, 10    -> $9 = 10
        instructions[4] = 32'b001000_11101_11101_1111111111111000;  // -> $29 = 1111111111111000
        instructions[5] = 32'b001000_11110_11110_1111111111111100;  // -> $30 = 1111111111111100
        instructions[6] = 32'b101011_11101_01000_0000000000000000;  // sw $8, 0($29) 
        instructions[7] = 32'b101011_11110_01001_0000000000000000;  // sw $9, 0($30)
        instructions[8] = 32'b100011_11101_01010_0000000000000000;  // lw $10, 0($29)
        instructions[9] = 32'b100011_11110_01011_0000000000000000;  // lw $11, 0($30)
        instructions[10] = 32'b000010_00000000000000000000_010011;  // j end

        //core 1
        instructions[11] = 32'b001000_00000_01010_0000000000000111;  // addi $10, $0, 7  -> $10 = 7
        instructions[12] = 32'b001000_00000_01011_0000000000000100;  // addi $11, $0, 4  -> $11 = 4
        instructions[13] = 32'b001000_10000_10000_1111111111110000;  // -> $16 = 1111111111110000
        instructions[14] = 32'b001000_10001_10001_1111111111110100;  // -> $17 = 1111111111110100
        instructions[15] = 32'b101011_10000_01010_0000000000000000;  // sw $10, 0($16)
        instructions[16] = 32'b101011_10001_01011_0000000000000000;  // sw $11, 0($17)
        instructions[17] = 32'b100011_10000_01000_0000000000000000;  // lw $8, 0($16)
        instructions[18] = 32'b100011_10001_01001_0000000000000000;  // lw $9, 0($17)

        // end :
        last_instr = 19;

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
        #2 rst = 0; 
        fail_flag0 = 0;
        fail_flag1= 0;
    end

    initial begin  // core 0
        #2060;
        for (i = 0; ipc0 != last_instr && !fail_flag0; i++) begin
            if (!fail_flag0) begin
                $display("ipc0 : ", ipc0);
                exec_internal0();
                #2;
                while ((InstDone0 !== 1) ) #2;  
                for (j = 1; j < 32; j++) if (R0[j] !== ireg0[j]) fail_flag0 = 1;
                if (fail_flag0) begin
                    // $display("Expectation at core 0 : ", " [1]%x", ireg0[1], " [2]%x", ireg0[2], " [3]%x",
                    //          ireg0[3], " [4]%x", ireg0[4], " [5]%x", ireg0[5]," [29]%x", ireg0[29], " [30]%x", ireg0[30], " [31]%x", ireg0[31]);
                    // $display("Reality : ", " [1]%x", R0[1], " [2]%x", R0[2], " [3]%x", R0[3],
                    //          " [4]%x", R0[4], " [5]%x", R0[5] ," [29]%x", R0[29], " [30]%x", R0[30], " [31]%x", R0[31]);
                    $display("FAILED");
                end
            end
        end
        if (!fail_flag0) begin
            // $display("mem : ", "[1f9] : ", data_mem[505], "[1fa] : ", data_mem[506], "[1fb] : ",
            //          data_mem[507], "[1fc] : ", data_mem[508], "[1fd] : ", data_mem[509],
            //          "[1fe] : ", data_mem[510], "[1ff] : ", data_mem[511]);
            $display("ACCEPTED CORE 0, steps : %d", i);
            if(ipc1 == last_instr)
                $finish(0);
        end
    end

    initial begin  // core 1
        #2060;
        for (k = 0; ipc1 != last_instr && !fail_flag1; k++) begin
            if (!fail_flag1) begin
                $display("ipc1 : ", ipc1);
                exec_internal1();
                #2;
                while ((InstDone1 !== 1) ) #2;  

                for (l= 1; l < 32; l++) if (R1[l] !== ireg1[l]) fail_flag1 = 1;
                if (fail_flag1) begin
                    // $display("Expectation at core 0 : ", " [1]%x", ireg0[1], " [2]%x", ireg0[2], " [3]%x",
                    //          ireg0[3], " [4]%x", ireg0[4], " [5]%x", ireg0[5]," [29]%x", ireg0[29], " [30]%x", ireg0[30], " [31]%x", ireg0[31]);
                    // $display("Reality : ", " [1]%x", R0[1], " [2]%x", R0[2], " [3]%x", R0[3],
                    //          " [4]%x", R0[4], " [5]%x", R0[5] , " [29]%x", R0[29], " [30]%x", R0[30], " [31]%x", R0[31]);
                    $display("FAILED");
                end
            end
        end
        if (!fail_flag1) begin
            // $display("mem : ", "[1f9] : ", data_mem[505], "[1fa] : ", data_mem[506], "[1fb] : ",
            //          data_mem[507], "[1fc] : ", data_mem[508], "[1fd] : ", data_mem[509],
            //          "[1fe] : ", data_mem[510], "[1ff] : ", data_mem[511]);
            $display("ACCEPTED CORE 1, steps : %d",k);
            if (ipc0 == last_instr)
                $finish(0);
        end
    end
endmodule

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
        
        instructions[0] = 32'b001000_00000_10000_0000000000010100;  // addi $16, $0, 20
        instructions[1] = 32'b001000_00000_10001_0000001111101000;  // addi $17, $0, 1000
        instructions[2] = 32'b000100_00000_10001_0000000000000101;  // beq $17, $0, exit
       	instructions[3] = 32'b100011_10000_01000_0000000000000000;  // lw $4, 0($16)
        instructions[4] = 32'b001000_01000_01000_0000000000000001;  // addi $4, $4, 1
        instructions[5] = 32'b101011_10000_01000_0000000000000000;  // sw $4, 0($16)
        instructions[6] = 32'b001000_10001_10001_1111111111111111;  // addi $17, $17, -1
        instructions[7] = 32'b000010_00000000000000000000000010;  // j loop

        last_instr = 8; 

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
            end
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
            end
        end
    end

	initial begin  // test
		#80000;
		$display("value of memory cell: ", data_mem[5]);
		$finish;
	end
endmodule

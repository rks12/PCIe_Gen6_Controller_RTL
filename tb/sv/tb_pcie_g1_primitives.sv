/*
 * tb_pcie_g1_primitives.sv -- directed tests of standalone v0.2 RTL blocks.
 *
 * PURPOSE: Verify primitives not yet connected to the main RTL datapath.
 * TESTS: credit add/consume/saturation, sequence wrong/clear/1023->1 wrap,
 *        LCRC32 with independent standard CRC32 bytes+PCIe bit-order rule,
 *        and first-TLP Type/NOP monitor.
 * LIMITS: These are arithmetic primitive tests, NOT evidence of a full DLL,
 *         flow-control initialization, replay, or PCIe TLP parsing.
 * RUN: make tb-primitives (Verilator >=5), integrated in make tb-unit.
 */
`timescale 1ns/1ps
module tb_pcie_g1_primitives;
  logic clk=0;
  always #5 clk=~clk;
  logic rst_n=0, clear=0;
  logic grant_valid=0, consume_valid=0;
  logic [7:0] grant_amount=0, available;
  logic consume_ready;
  logic accepted_payload=0;
  logic [9:0] rx_sequence=0, expected_sequence;
  logic unexpected_sequence;
  logic start=0, in_valid=0;
  logic [7:0] in_byte=0;
  logic [31:0] crc_field;
  logic [1887:0] tlp_area='0;
  logic [7:0] first_type;
  logic first_is_nop;
  int passed=0;
  pcie_credit_counter #(.CW(8)) counter (.*);
  pcie_flit_sequence_tracker tracker (.*);
  pcie_lcrc32_reference lcrc (.*);
  pcie_tlp_type_monitor monitor (.*);

  task automatic check(input bit cond,input string name);
    if(!cond) $fatal(1,"FAIL primitive: %s at %0t",name,$time);
    passed=passed+1;
  endtask
  task automatic drive_seq(input logic [9:0] seq);
    @(negedge clk); accepted_payload=1;rx_sequence=seq;
    @(posedge clk);#1;
    @(negedge clk);accepted_payload=0;
  endtask
  task automatic send_lcrc(input logic [7:0] data_byte,
                           input bit is_first);
    @(negedge clk);
    in_valid=1; in_byte=data_byte; start=is_first;
    @(posedge clk);#1;
    @(negedge clk); in_valid=0;start=0;
  endtask
  initial begin : watchdog
    #500000;$fatal(1,"Primitive testbench watchdog timeout");
  end
  initial begin
    repeat(3) @(posedge clk);
    @(negedge clk);rst_n=1;
    #1;
    check(available==0 && !consume_ready,"credit reset");
    check(expected_sequence==10'h001,"sequence reset");
    check(first_is_nop && first_type==0,"NOP monitor initial");
    @(negedge clk);tlp_area[7:0]=8'h4A;
    #1;check(!first_is_nop && first_type==8'h4A,"non-NOP header monitor");
    @(negedge clk);grant_valid=1;grant_amount=5;
    @(posedge clk);#1;check(available==5,"credit grant");
    @(negedge clk);grant_valid=0;consume_valid=1;
    @(posedge clk);#1;check(available==4,"credit consume");
    @(negedge clk);grant_valid=1;grant_amount=2;
    @(posedge clk);#1;check(available==5,"simultaneous grant + consume");
    @(negedge clk);consume_valid=0;grant_amount=8'hff;
    @(posedge clk);#1;check(available==255,"credit saturation");
    @(negedge clk);grant_valid=0;consume_valid=1;
    @(posedge clk);#1;check(available==254,"consume after saturation");
    @(negedge clk);consume_valid=0;
    drive_seq(10'h001);
    check(expected_sequence==10'h002,"expected seq advances");
    @(negedge clk);accepted_payload=1;rx_sequence=10'h009;
    #1;check(unexpected_sequence,"unexpected sequence flagged");
    @(posedge clk);#1;check(expected_sequence==10'h002,"unexpected sequence stalls");
    @(negedge clk);accepted_payload=0;clear=1;
    @(posedge clk);#1;check(expected_sequence==10'h001,"sequence clear");
    @(negedge clk);clear=0;
    for(int n=1;n<=1023;n++) begin
      drive_seq(10'(n));
    end
    check(expected_sequence==10'h001,"sequence wraps 1023 to 1, skips 0");
    send_lcrc(8'h34,1);
    send_lcrc(8'h12,0);
    send_lcrc(8'hAA,0);
    send_lcrc(8'h55,0);
    send_lcrc(8'h10,0);
    send_lcrc(8'h3F,0);
    send_lcrc(8'hFE,0);
    #1;
    // zlib.crc32([34,12,AA,55,10,3F,FE])=57E7D35F;
    // reflect bits within each result byte for this PCIe LCRC output layout.
    check(crc_field===32'hEAE7CBFA,"LCRC independent CRC32 check");
    $display("ALL G1 PRIMITIVE HDL CHECKS PASSED: %0d assertions",passed);
    $finish;
  end
endmodule

module smoke_tb;
  logic clk_i=0,rst_ni=1,ce_i=1,valid_i=1;
  logic [15:0] data_i;
  wire valid_o,overflow_o;
  wire [17:0] data_o;
  constant_multiplier dut(.*);
  initial begin
    for (integer i=-32768;i<32768;i=i+1) begin
      data_i=16'(i);#1;
      if (!valid_o || overflow_o || $signed(data_o)!=(i*3)) $fatal(1,"CM-SMOKE-FAIL");
    end
    $display("CM-SMOKE-PASS");$finish;
  end
endmodule

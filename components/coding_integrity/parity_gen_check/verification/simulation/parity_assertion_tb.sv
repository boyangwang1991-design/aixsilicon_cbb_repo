`timescale 1ns/1ps
module parity_assertion_tb;
  localparam int WIDTHS[7]='{4,5,8,16,64,511,512};
  logic [511:0] data='0;
  wire [41:0] results;
  for(genvar w=0;w<7;w++) begin: widths
    for(genvar i=0;i<3;i++) begin: impls
      for(genvar p=0;p<2;p++) begin: parities
        parity_gen_check #(.DATA_WIDTH(WIDTHS[w]),.PC_IMPL(i),.PARITY_TYPE(p)) dut(
          .data_i(data[WIDTHS[w]-1:0]),.parity_o(results[w*6+i*2+p]));
      end
    end
  end
  function automatic bit golden(int width,bit odd);
    bit value;
    value=odd;
    for(int b=0;b<width;b++) value^=data[b];
    return value;
  endfunction
  initial begin
    int seed;
    seed=32'h20260914;void'($urandom(seed));
    #1ns;
    if($test$plusargs("INJECT_ERROR")) begin
      force widths[0].impls[0].parities[0].dut.parity_o=1'b1;
      #1ns;
      $display("MUTATION_EXECUTED");$finish;
    end
    for(int v=0;v<1024;v++) begin
      for(int b=0;b<16;b++) data[b*32+:32]=$urandom();
      if(v<512) data=512'b1<<v;
      #1ns;
      for(int w=0;w<7;w++) for(int i=0;i<3;i++) for(int p=0;p<2;p++)
        if(results[w*6+i*2+p]!==golden(WIDTHS[w],p)) $fatal(1,"GOLDEN_MISMATCH");
    end
    $display("PARITY_ASSERTION_TB PASS vectors=1024 instances=42");$finish;
  end
endmodule

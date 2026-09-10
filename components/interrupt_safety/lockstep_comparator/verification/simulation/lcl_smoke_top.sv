module lcl_smoke_top;
  timeunit 1ns; timeprecision 1ps;
  wire done;
  lcl_tester u_tester(.done(done));
  initial begin wait(done);$display("LCL_CORE_PASS");$finish;end
  initial begin #1000000;$fatal(1,"LCL_CORE_TIMEOUT");end
endmodule

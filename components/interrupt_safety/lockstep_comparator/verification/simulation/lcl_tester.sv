// SPDX-License-Identifier: Apache-2.0
module lcl_tester #(
 parameter int WIDTH=32, LOCKSTEP_DELAY=2, STARTUP_GUARD_CYCLES=0,
 parameter int CMP_PIPE_STAGES=0, LCL_REDUNDANCY_LEVEL=2,
 parameter logic [WIDTH-1:0] STATIC_COMPARE_MASK='1,
 parameter bit SUPPORT_RUNTIME_MASK=1, SUPPORT_VALID_MASK=1, SUPPORT_FAULT_INJECTION=1,
 parameter int CASE_ID=0
)(output bit done);
 timeunit 1ns; timeprecision 1ps;
 logic clk_i=0, rst_ni=0;
 logic [WIDTH-1:0] main_i='0,shadow_i='0,runtime_mask_i='1,valid_mask_i='1,fi_mask_i='0;
 logic compare_enable_i=1,main_active_i=1,shadow_active_i=1,error_clear_i=0,fi_enable_i=0;
 logic [1:0] fi_target_i=0;
 wire alignment_valid_o,main_shadow_mismatch_o,main_shadow_mismatch_pulse_o;
 wire main_shadow_mismatch_latched_o,lcl_internal_fault_o,lcl_internal_fault_latched_o,safety_fault_o;
 wire [WIDTH-1:0] mismatch_vector_o,mismatch_vector_sticky_o;
 lockstep_comparator_logic #(
 .WIDTH(WIDTH),.LOCKSTEP_DELAY(LOCKSTEP_DELAY),.STARTUP_GUARD_CYCLES(STARTUP_GUARD_CYCLES),
 .CMP_PIPE_STAGES(CMP_PIPE_STAGES),.LCL_REDUNDANCY_LEVEL(LCL_REDUNDANCY_LEVEL),
 .STATIC_COMPARE_MASK(STATIC_COMPARE_MASK),.SUPPORT_RUNTIME_MASK(SUPPORT_RUNTIME_MASK),
 .SUPPORT_VALID_MASK(SUPPORT_VALID_MASK),.SUPPORT_FAULT_INJECTION(SUPPORT_FAULT_INJECTION)
 ) dut(.*);
 localparam int HIST=(LOCKSTEP_DELAY>0)?LOCKSTEP_DELAY:1;
 logic [WIDTH-1:0] history_a[HIST],history_b[HIST];
 logic [WIDTH-1:0] pipe_a='0,pipe_b='0,sticky_vec='0;
 bit sticky_main=0,sticky_internal=0;
 int age=0,checks=0;
 int unsigned rng;
 bit force_a=0,force_b=0;
 function automatic int unsigned random_word();
   rng=rng^(rng<<13); rng=rng^(rng>>17); rng=rng^(rng<<5); return rng;
 endfunction
 function automatic logic [WIDTH-1:0] random_bits();
   for(int k=0;k<WIDTH;k++) random_bits[k]=1'(random_word());
 endfunction
 function automatic logic [WIDTH-1:0] align_a();
   if(LOCKSTEP_DELAY==0) return main_i ^ ((SUPPORT_FAULT_INJECTION && fi_enable_i && fi_target_i==2)?fi_mask_i:'0);
   return history_a[HIST-1];
 endfunction
 task automatic expected(output logic [WIDTH-1:0] a,b,raw_a,raw_b,output bit aligned);
   logic [WIDTH-1:0] aa,bb,mask;
   aligned=rst_ni && age>=LOCKSTEP_DELAY+STARTUP_GUARD_CYCLES;
   aa=align_a();
   if(LCL_REDUNDANCY_LEVEL<2) bb=aa;
   else if(LOCKSTEP_DELAY==0) bb=main_i ^ ((SUPPORT_FAULT_INJECTION && fi_enable_i && fi_target_i==3)?fi_mask_i:'0);
   else bb=history_b[HIST-1];
   if(SUPPORT_FAULT_INJECTION && fi_enable_i) begin
     if(fi_target_i==0) aa=aa^fi_mask_i;
     if(fi_target_i==1) bb=bb^fi_mask_i;
   end
   mask=STATIC_COMPARE_MASK;
   if(SUPPORT_RUNTIME_MASK) mask &= runtime_mask_i;
   if(SUPPORT_VALID_MASK) mask &= valid_mask_i;
   raw_a='0;raw_b='0;
   if(aligned && compare_enable_i && main_active_i && shadow_active_i) begin
     for(int k=0;k<WIDTH;k++) if(mask[k]) begin
       raw_a[k]=(aa[k]!=shadow_i[k]);
       if(LCL_REDUNDANCY_LEVEL>0) raw_b[k]=(bb[k]!=shadow_i[k]);
     end
   end
   a=(!rst_ni)?'0:((CMP_PIPE_STAGES==0)?raw_a:pipe_a);
   b=(!rst_ni)?'0:((CMP_PIPE_STAGES==0)?raw_b:pipe_b);
 endtask
 task automatic check_outputs();
   logic [WIDTH-1:0] a,b,ra,rb,v;
   bit av,ma,mb,mm,internal_fault;
   expected(a,b,ra,rb,av); v=a|b;
   ma=force_a?0:(|a);mb=force_b?0:(|b);
   mm=ma|mb;internal_fault=(LCL_REDUNDANCY_LEVEL>0)?(ma^mb):0;
   if ({alignment_valid_o,main_shadow_mismatch_o,lcl_internal_fault_o,safety_fault_o,
       main_shadow_mismatch_pulse_o,main_shadow_mismatch_latched_o,lcl_internal_fault_latched_o,
       mismatch_vector_o,mismatch_vector_sticky_o} !==
       {av,mm,internal_fault,(mm|internal_fault),(mm & ~sticky_main),sticky_main,sticky_internal,v,sticky_vec})
      $fatal(1,"LCL_SCOREBOARD case=%0d check=%0d age=%0d live=%b/%b internal=%b/%b vec=%h/%h sticky=%h/%h",CASE_ID,checks,age,main_shadow_mismatch_o,mm,lcl_internal_fault_o,internal_fault,mismatch_vector_o,v,mismatch_vector_sticky_o,sticky_vec);
   checks++;
 endtask
 task automatic tick();
   logic [WIDTH-1:0] a,b,ra,rb;
   bit av,ma,mb;
   #4; check_outputs();expected(a,b,ra,rb,av);
   ma=force_a?0:(|a);mb=force_b?0:(|b);
   if(!rst_ni) begin
     age=0;pipe_a='0;pipe_b='0;sticky_main=0;sticky_internal=0;sticky_vec='0;
     for(int k=0;k<HIST;k++) begin history_a[k]='0;history_b[k]='0;end
   end else begin
     sticky_main=(error_clear_i?0:sticky_main)|(ma|mb);
     sticky_internal=(error_clear_i?0:sticky_internal)|((LCL_REDUNDANCY_LEVEL>0)?ma^mb:0);
     sticky_vec=(error_clear_i?'0:sticky_vec)|a|b;
     pipe_a=ra;pipe_b=rb;
     for(int k=HIST-1;k>0;k--) begin history_a[k]=history_a[k-1];history_b[k]=history_b[k-1];end
     history_a[0]=main_i ^ ((SUPPORT_FAULT_INJECTION && fi_enable_i && fi_target_i==2)?fi_mask_i:'0);
     history_b[0]=main_i ^ ((SUPPORT_FAULT_INJECTION && fi_enable_i && fi_target_i==3)?fi_mask_i:'0);
     if(age<LOCKSTEP_DELAY+STARTUP_GUARD_CYCLES) age++;
   end
   clk_i=1;#1;check_outputs();#5;clk_i=0;
 endtask
 task automatic reset_case();
   rst_ni=0;age=0;pipe_a='0;pipe_b='0;sticky_main=0;sticky_internal=0;sticky_vec='0;
   for(int k=0;k<HIST;k++) begin history_a[k]='0;history_b[k]='0;end
   main_i='0;shadow_i='0;fi_enable_i=0;fi_mask_i='0;error_clear_i=0;
   runtime_mask_i='1;valid_mask_i='1;compare_enable_i=1;main_active_i=1;shadow_active_i=1;
   repeat(3) tick();rst_ni=1;
 endtask
 task automatic settle(); repeat(LOCKSTEP_DELAY+STARTUP_GUARD_CYCLES+CMP_PIPE_STAGES+3) tick(); endtask
 task automatic tc_alignment();
   reset_case();shadow_i='1;
   repeat(LOCKSTEP_DELAY+STARTUP_GUARD_CYCLES+4) tick();
   // Restart alignment during ACTIVE, including pending pipeline result.
   reset_case();settle();
   for(int n=0;n<20;n++) begin main_i=random_bits();shadow_i=align_a();tick();end
 endtask
 task automatic tc_compare();
   reset_case();settle();shadow_i='1;settle();
   runtime_mask_i='0;settle();runtime_mask_i='1;valid_mask_i='0;settle();valid_mask_i='1;
   compare_enable_i=0;settle();compare_enable_i=1;main_active_i=0;settle();
   main_active_i=1;shadow_active_i=0;settle();shadow_active_i=1;settle();
 endtask
 task automatic tc_injection();
   for(int target=0;target<4;target++) begin
     reset_case();settle();fi_enable_i=1;fi_target_i=2'(target);fi_mask_i='1;settle();
     fi_enable_i=0;settle();
   end
 endtask
 task automatic tc_sticky();
   reset_case();settle();shadow_i='1;settle();error_clear_i=1;tick(); // fault dominates clear
   error_clear_i=0;shadow_i='0;settle(); // sticky persists
   error_clear_i=1;tick();error_clear_i=0;tick(); // clear without alignment reset
   shadow_i='1;settle(); // event re-arms
 endtask
 task automatic tc_pipeline();
   reset_case();settle();shadow_i='1;tick();compare_enable_i=0;tick();tick();
   compare_enable_i=1;shadow_i='0;tick();shadow_i='1;tick();reset_case();settle();
 endtask
 task automatic tc_random();
   reset_case();settle();
   for(int n=0;n<500;n++) begin
     main_i=random_bits();shadow_i=(n%3==0)?align_a():random_bits();
     runtime_mask_i=random_bits();valid_mask_i=random_bits();
     compare_enable_i=(random_word()%8!=0);main_active_i=(random_word()%9!=0);shadow_active_i=(random_word()%7!=0);
     fi_enable_i=(random_word()%5==0);fi_target_i=2'(random_word());fi_mask_i=random_bits();
     error_clear_i=(random_word()%6==0);tick();
     if(n%97==0) reset_case();
   end
 endtask
 // Explicit single-path stuck-at-zero faults, separate from supported FI controls.
 if(LCL_REDUNDANCY_LEVEL>0) begin : g_stuck_tests
   task automatic tc_stuck();
     reset_case();settle();shadow_i='1;settle();
     force dut.mismatch_path[0]=1'b0;force_a=1;#1;tick();
     release dut.mismatch_path[0];force_a=0;#1;tick();
     force dut.mismatch_path[1]=1'b0;force_b=1;#1;tick();
     release dut.mismatch_path[1];force_b=0;#1;tick();
   endtask
 end
 bit tests_complete=0;
 initial begin
   done=0;rng=5005+32'(CASE_ID);
   tc_alignment();tc_compare();tc_injection();tc_sticky();tc_pipeline();tc_random();
   tests_complete=1;
 end
 if(LCL_REDUNDANCY_LEVEL>0) begin : g_finish_dual
   initial begin
     wait(tests_complete);g_stuck_tests.tc_stuck();
     $display("LCL_CASE_PASS id=%0d checks=%0d",CASE_ID,checks);done=1;
   end
 end else begin : g_finish_single
   initial begin
     wait(tests_complete);
     $display("LCL_CASE_PASS id=%0d checks=%0d",CASE_ID,checks);done=1;
   end
 end
endmodule

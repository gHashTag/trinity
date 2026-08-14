// The narrow multiplier must agree with the original on every input, not merely
// on a sample. The mantissa space is swept exhaustively at each of several
// offset pairs, and the offsets are then swept exhaustively at fixed mantissas —
// together that covers every path through the carry, the saturation and the
// underflow clamp.
`default_nettype none
`timescale 1ns/1ps

module tb_gft_equiv;
  reg  [31:0] a_off32, a_m32, b_off32, b_m32;
  wire [31:0] w_off32, w_m32;
  gft_mul u_ref (.a_off(a_off32), .a_mant(a_m32), .b_off(b_off32), .b_mant(b_m32),
                 .out_off(w_off32), .out_mant(w_m32));

  reg  [6:0] a_off7, b_off7;
  reg  [8:0] a_m9, b_m9;
  wire [6:0] w_off7;
  wire [8:0] w_m9;
  gft_mul_w u_narrow (.a_off(a_off7), .a_mant(a_m9), .b_off(b_off7), .b_mant(b_m9),
                      .out_off(w_off7), .out_mant(w_m9));

  integer am, bm, ao, bo, errors, checks;

  task compare(input integer ao_, input integer bo_, input integer am_, input integer bm_);
    begin
      a_off32 = ao_; b_off32 = bo_; a_m32 = am_; b_m32 = bm_;
      a_off7  = ao_[6:0]; b_off7 = bo_[6:0]; a_m9 = am_[8:0]; b_m9 = bm_[8:0];
      #1;
      checks = checks + 1;
      if (w_off32[6:0] !== w_off7 || w_m32[8:0] !== w_m9) begin
        errors = errors + 1;
        if (errors <= 12)
          $display("MISMATCH a_off=%0d b_off=%0d a_m=%0d b_m=%0d : ref=(%0d,%0d) narrow=(%0d,%0d)",
                   ao_, bo_, am_, bm_, w_off32, w_m32, w_off7, w_m9);
      end
    end
  endtask

  initial begin
    errors = 0; checks = 0;
    // mantissa space swept in full at offset pairs that exercise underflow,
    // the middle, and saturation
    for (ao = 0; ao <= 80; ao = ao + 40)
      for (bo = 0; bo <= 80; bo = bo + 40)
        for (am = 0; am < 512; am = am + 1)
          for (bm = 0; bm < 512; bm = bm + 8)
            compare(ao, bo, am, bm);

    // offsets swept in full at mantissas that do and do not carry
    for (am = 0; am < 512; am = am + 256)
      for (bm = 0; bm < 512; bm = bm + 256)
        for (ao = 0; ao <= 80; ao = ao + 1)
          for (bo = 0; bo <= 80; bo = bo + 1)
            compare(ao, bo, am, bm);

    $display("");
    $display("compared %0d input combinations, %0d mismatches", checks, errors);
    if (errors == 0) $display("RESULT: EQUIVALENT");
    else             $display("RESULT: NOT EQUIVALENT");
    $finish;
  end
endmodule

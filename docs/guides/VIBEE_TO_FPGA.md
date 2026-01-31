# From .vibee Specification to FPGA

## Step 1: Create Specification

```yaml
# specs/fpga/my_module.vibee
name: my_module
version: "1.0.0"
language: varlog
module: my_module

ports:
  inputs:
    clk: {width: 1}
    data_in: {width: 8}
  outputs:
    data_out: {width: 8}

behaviors:
  - name: process
    given: "Input data"
    when: "Clock edge"
    then: "Output processed data"
    implementation: |
      always @(posedge clk) begin
        data_out <= data_in + 8'd1;
      end
```

## Step 2: Generate Verilog

```bash
./bin/vibee gen specs/fpga/my_module.vibee
# Output: trinity/output/fpga/my_module.v
```

## Step 3: Simulate

```bash
iverilog -o sim trinity/output/fpga/my_module.v testbench.v
vvp sim
```

## Step 4: Synthesize (Vivado)

```tcl
create_project my_module ./vivado -part xc7a35tcpg236-1
add_files trinity/output/fpga/my_module.v
launch_runs synth_1 -jobs 4
launch_runs impl_1 -to_step write_bitstream
```

## Step 5: Program FPGA

```bash
openocd -f board/digilent_arty.cfg -c "pld load 0 my_module.bit; exit"
```

## BitNet Example

```bash
./bin/vibee gen specs/fpga/bitnet_core.vibee
# Generates ternary MAC array with 0 DSP blocks
```

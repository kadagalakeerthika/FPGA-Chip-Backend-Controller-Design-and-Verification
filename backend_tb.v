// Testbanch module for the backend. This has a module instantiation for
// the FPGA_model and the backend.
`timescale 1ns / 1ps
//==========================================================================
//Change the Verilog filenames approppriately.
`include "FPGA_model.v"
`include "backend.v"
//=========================================================================

module backend_tb();

reg resetbFPGA;
reg main_clk;
reg RO_clock_model; 
reg [3:0]ADCout;

wire [2:0]gainA1 ;
wire resetb_core;
wire resetbAll, resetb_amp,  enableRO; 
wire core_clk,RO_clk ;
wire sclk, sdin;
wire ready;
wire Ibias_2x;


//==========================================================================
//FPGA model instantiation
FPGA_model   FPGA_obj(	.i_resetbFPGA (resetbFPGA),
			.i_ready (ready),
			.o_resetbAll (resetbAll),
			.i_mainclk (main_clk),
			.o_sclk (sclk), 
			.o_sdout (sdin) );

// Backend instantiation 
backend backend_obj (	.i_resetbAll (resetbAll),
			.i_clk (main_clk),
			.i_sclk (sclk),
			.i_sdin (sdin),
			.i_RO_clk (RO_clk), 
			.i_ADCout(ADCout),
			.o_Ibias_2x (Ibias_2x),
			.o_core_clk  (core_clk ),
			.o_ready (ready),
			.o_resetb_amp (resetb_amp),
			.o_gain (gainA1),
			.o_enableRO (enableRO),
			.o_resetb_core (resetb_core) );
//============================================================================
// VCO clock model
assign RO_clk = (enableRO)?RO_clock_model:0;

initial
begin
$dumpfile ("comp.vcd") ;
$dumpvars (0, backend_tb) ;

end
//============================================================================

//Test signal generation
initial
begin
	resetbFPGA <= 0;
	main_clk <= 0;
	RO_clock_model <= 0;
	ADCout<= 1;
	#10 resetbFPGA <= 1;
		

	

	// Run simulation for 100 ns (My code)
    #10000 $finish;
end

//Generation of main_clk 
always #1 main_clk <= ~main_clk;

//Generation of internal clock models for the VCOs
always #0.5 RO_clock_model <= ~RO_clock_model;//1GHz, Range: 500MHz to 1.5GHz)



//============================================================================
endmodule
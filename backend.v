module backend( i_resetbAll,
		i_clk,
		i_sclk,
		i_sdin,
		i_RO_clk,
		i_ADCout,
		o_core_clk ,
		o_ready,
		o_resetb_amp,
		o_Ibias_2x,
		o_gain,
		o_enableRO,
		o_resetb_core,
		);


    input i_resetbAll, i_clk, i_sclk, i_sdin, i_RO_clk ;
    input [3:0]i_ADCout ;    
    output reg o_ready, o_Ibias_2x, o_resetb_amp, o_resetb_core, o_enableRO,o_core_clk ;
    output reg [2:0] o_gain;   // 3 bit gain of the OpAmp

	//Rest of the behavioral descriptions

// FSM state encoding
    	parameter RESET           = 4'b0000;
	parameter WAIT_SERIAL     = 4'b0001;
	parameter WAIT_5_CYCLES_1 = 4'b0010;
	parameter SET_GAIN        = 4'b0011;
	parameter ENABLE_RO       = 4'b0100;
	parameter RELEASE_RESETS  = 4'b0101;
	parameter WAIT_5_CYCLES_2  = 4'b0110;
	parameter READY 	  = 4'b0111;
/* We have modelled each state of the backend as a 7 state FSM, with the default next state being the reset state, 
hence in case of any faults, the backend automatically goes into the reset state   
The states are parameterised exactly in the order of the start up sequence
*/

	
// Declare state variables (4-bit register) is used to model the FSM
    reg [3:0] state, next_state;    //These variables will hold the current and next state of the machine
    reg wait_done_1, wait_done_2;    //These are flag variables, which are used later to indicate whether the 5 clock cycles delay (Steps - 6 and 9) have occured or not

    
    integer clk_counter;     // A counter variable used for calculating whether the 5 clock cycle delay has occured or not. The value of wait_done flags will change accordingly

    
    reg [4:0] shift_reg; //Shift register to store serial data input sdin
    reg [2:0] bit_count; // Counter to track the received bits, and figure out when 5 clock cycles of sclk have passed

    // Moving average filter registers
    reg [6:0] ADCsum;    // To store the sum of the current and past values of ADCout, in 6 bit values.
    reg [3:0] ADC_history [3:0]; // Store last 4 ADC values (0 index - current value, 1 index - 1 delayed cycle value, 2 index - 2 delayed clock cycle value and so on)
    reg [3:0] ADCavg;       // To store the average of ADC, by dividing ADC_sum by 4.

    
    
    always @(posedge i_clk or negedge i_resetbAll) begin
	// In case i_resetbAll transitions to low, then machine should enter the reset state
        if (!i_resetbAll) begin
            state <= RESET;      //naturally, in the case that i_resetbAll is low, then the next state of the machine should also be low 
        end else begin
            state <= next_state;   // the normal transition of state, in the case where i_resetbAll is high.
        end
    end
    
    always @(posedge i_sclk) begin               // For serial data input
	    if (bit_count <= 3'b100)            // Counting that the number of bits recieved is 5 (0 to 4)
            begin
		// Serial shift register configuration
            shift_reg <= {i_sdin, shift_reg[4:1]}; // Shift in new bit at posedge of i_sclk
		// the first bit to enter, d0 will enter into shift_reg[4], then move to shift_reg[3] and [2] and so on, and similarly d1,d2 etc.
            bit_count <= bit_count + 3'b001;    // Incrementing the bit counter, to keep a track of the number of bits recieved
            end
        
    end
    
    
// State transition logic begins
// The below code contains the FSM logic, which includes the next state to be transitioned into, and conditions for enabling the transition
    always @(*) begin
        case (state)
            RESET:
                next_state = i_resetbAll ? WAIT_SERIAL : RESET;      // Step -1 if i_resetbAll is high, next state will be the WAIT_SERIAL state, else machine will continue in RESET
            
            WAIT_SERIAL:begin
                
                next_state = (bit_count == 3'b101) ? SET_GAIN : WAIT_SERIAL;
                // Step - 2, 3: If all the serial data input bits are recieved (indicated by value of bit_count being 5), the machine can transition into setting OpAmp gain
            end

            SET_GAIN:
                next_state = ENABLE_RO;      // Step - 4: The machine just has to set the OPAMP gain and transition into the next state, hence no transition condition

            ENABLE_RO:
                next_state = WAIT_5_CYCLES_1;  // Step - 5: the enable_RO is set, and then machine transitions into waiting for 5 clock cycles to pass

            WAIT_5_CYCLES_1:
                next_state = (wait_done_1) ? RELEASE_RESETS : WAIT_5_CYCLES_1; //Step - 6: Machine waits for 5 clock cycles, for the first time, if 5 clock cycles have passed

            RELEASE_RESETS:
                next_state = WAIT_5_CYCLES_2;  // Step - 7,8: The filter is active, and the reset_amp and resetb_core are set to high 

            WAIT_5_CYCLES_2:
                next_state = (wait_done_2) ? READY : WAIT_5_CYCLES_2;  //Step - 9: Machine waits for 5 clock cycles, for the second time

            READY:
                next_state = READY;  // Step - 10, 11: Machine enters and remains in READY state. The start up sequence is complete

            default:
                next_state = RESET;   // default state being the reset state
        endcase
    end


    // Output logic, defining all operations that occur in a particular state
    always @(posedge i_clk) begin
        case (state)
            RESET: 
                begin
		// All registers and outputs are reset in the RESET state
                o_ready <= 0;
                o_resetb_amp <= 0;
                o_resetb_core <= 0;
                o_gain <= 3'b000;
		count <= 2'b00;
                o_enableRO <= 0;
                o_Ibias_2x <= 0;
                o_core_clk <= 0;
		divided_clk <= 0;
                clk_counter <= 0;
                bit_count <= 0;
                wait_done_1 <= 0;
                wait_done_2 <= 0;
		shift_reg <= 5'b0;
		ADCavg <= 0;
                end
            

            // Serial Data Shift Register, inputing the data bits serially
            WAIT_SERIAL: 
                begin
                	o_ready        <= o_ready;
    			o_resetb_amp   <= o_resetb_amp;
    			o_resetb_core  <= o_resetb_core;
    			o_gain         <= o_gain;
    			o_enableRO     <= o_enableRO;
    			o_Ibias_2x     <= o_Ibias_2x;
    	
                end
            

            SET_GAIN: begin
		// Shift register operation
                o_gain <= {shift_reg[2], shift_reg[3], shift_reg[4]};
		bit_count <= 3'b000;
            end

            ENABLE_RO: begin
                o_enableRO <= 1; // Step 5: Set enableRO after gain update
            end

            WAIT_5_CYCLES_1: begin
                clk_counter <= clk_counter + 1;
                if (clk_counter == 2) begin    
		// Duuring the exectution, the step runs within two always @(posedge clk) blocks, hence 2 time delays occur automatically. 
		// Hence, only 3 time delays are added here through a counter, which causes a 5 clock cycle delay
                    wait_done_1 <= 1'b1;
                    clk_counter <= 0;   // Reseting this counter value back to 0
            	end
            end

            

            
            RELEASE_RESETS: begin
                o_resetb_amp <= 1;
                o_resetb_core <= 1;
            end

            WAIT_5_CYCLES_2: begin
                clk_counter <= clk_counter + 1;   // Similar logic as the previous WAIT block
                if (clk_counter == 3) begin
                    wait_done_2 <= 1'b1;
                    clk_counter <= 0;
                end
            end

            READY: begin
                o_ready <= 1;
            end
        endcase
    end


    
        // Moving Average Filter (Runs Continuously), for the ADC operations.
    always @(posedge i_clk or negedge i_resetbAll) begin
	if (!i_resetbAll) begin
		// If resetbAll is low, then all registers should be reset to 0
	     ADCavg <= 0;
	     ADC_history[3] <= 0;
             ADC_history[2] <= 0;
             ADC_history[1] <= 0;
             ADC_history[0] <= 0;
	     ADCsum <= 0;
        end else begin	
		// Shift operation to propogate the delays for each subsequent ADC values, in order to compute the time based average.
	     ADC_history[3] <= ADC_history[2];
             ADC_history[2] <= ADC_history[1];
             ADC_history[1] <= ADC_history[0];
             ADC_history[0] <= i_ADCout;    //i_ADCout is the current value of ADCout. ADC_history stores the current and delayed values

             ADCsum <= ADC_history[0] + ADC_history[1] + ADC_history[2] + ADC_history[3];   // Sum of all the ADC values
             ADCavg <= ADCsum >> 2;  // Divide by 4, for calculating the average
        end
    end

    reg [1:0] count = 2'b00;  // Counter for divide-by-4 clock
    reg divided_clk = 0;      // Internal divided clock
    reg select = 1'b0;    // Flag variable. Incase the ADCavg value is greater than 12, select is set to be high

    // The below block implements a divide by 4 clock, which can be connected to o_core_clock if select is high
    always @(posedge i_clk or negedge i_resetbAll) begin
	if(!i_resetbAll) begin
            count <= 0;
	end else begin
		count <= count + 1;   // Counter variable, to keep track of number of cycles that have passed
        	if (count == 2'b01) begin // Toggle divided_clk every two cycles → Div/4
           		divided_clk <= ~divided_clk;
	    	count <= 2'b00;
		end
	end
    end
    

    //Continuous ADC Monitoring (Runs Independently of the current state of the machine)
    always @(posedge i_clk or negedge i_resetbAll) begin
        if (!i_resetbAll) begin
		// Incase i_resetbAll is low
            o_Ibias_2x <= 0;
            select <= 1'b0;  
        end else begin
            if (ADCavg > 4'b1100) begin
                o_Ibias_2x <= 1;
                select <= 1'b1;  // Slow mode, in case the ADCavg is greater than 12
            end else begin
                o_Ibias_2x <= 0;
                select <= 1'b0;  // Normal mode
            end
            // If 8 ≤ ADCavg ≤ 12, retain previous values (no changes)
        end
    end

// Connecting the o_core_clock to normal clock or divide by 4 clock depending on the value of the select flag
    always @(*) begin
        if (select && i_resetbAll) 
            o_core_clk = divided_clk;  // Divide-by-4 clock when select = 1
        else if (i_resetbAll)
            o_core_clk = i_clk;          // Pass through clk when select = 0
	else
	    o_core_clk <= 0;   // When i_resetbAll is low, then o_core_clock is reset to 0
    end

endmodule
// end of program

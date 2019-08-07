library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
    use ieee.std_logic_unsigned.all;
library libcommons;
    use libcommons.lfsr.all;
    
entity lfsr_test_object is
generic (
	LFSR_SIZE : natural;
	LFSR_CYCLE_STOP_STATE : boolean;
	STEP_OFFSET : integer
);
port (
   clk : in std_logic;
   rst_n : in std_logic;
   
   data_out : out std_logic_vector(LFSR_SIZE-1 downto 0);
   error : out std_logic;
   passed : out std_logic
);
end entity lfsr_test_object;

architecture Behavioural of lfsr_test_object is
    constant IT0 : lfsr_spec := new_lfsr_iterator(LFSR_SIZE, LFSR_CYCLE_STOP_STATE);
	signal sig0 : std_logic_vector(LFSR_SIZE-1 downto 0);
	
	signal actual_stepcount : natural;
	signal expected_seqlength : natural;
	signal expected_stepcount : natural;
	
	signal running : boolean;
	signal overflow : boolean;
begin
	expected_seqlength <= 2**LFSR_SIZE when LFSR_CYCLE_STOP_STATE else 2**LFSR_SIZE-1;
	expected_stepcount <= abs(expected_seqlength/STEP_OFFSET);
	
	data_out <= sig0;

	
    process (rst_n, clk)
    begin
		if rst_n = '0' then
			error <= '0';
			passed <= '0';
			sig0 <= init_lfsr(it0);
			actual_stepcount <= 0;
			running <= true;
        elsif rising_edge(clk) AND running then
            overflow <= false;
            
            sig0 <= step(it0, sig0, STEP_OFFSET);
			actual_stepcount <= actual_stepcount + 1;
			
			for i in 1 to abs(STEP_OFFSET) loop
				if ((step(it0, sig0, i) = init_lfsr(it0)) AND (STEP_OFFSET > 0))
				OR ((step(it0, sig0, -i) = init_lfsr(it0)) AND (STEP_OFFSET < 0)) then
					overflow <= true;
				end if;
			end loop;
			
			if overflow then
                running <= false;
				if actual_stepcount = expected_stepcount then
					error <= '0';
					passed <= '1';
				else
					error <= '1';
					passed <= '0';
					report "lfsr_test_object: Actual stepcount different from expected!";
					report "lfsr_test_object: Provided LFSR_SIZE: " & integer'IMAGE(LFSR_SIZE);
					report "lfsr_test_object: expected_stepcount: " & integer'IMAGE(expected_stepcount);
					report "lfsr_test_object: actual_stepcount: " & integer'IMAGE(actual_stepcount);
				end if;
			end if;
        end if;
    end process;
end Behavioural;
			
			
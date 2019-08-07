library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library libcommons;
    use libcommons.misc.all;
    use libcommons.lfsr.all;

    
entity lfsr_tb is
end entity lfsr_tb;

architecture Behavioural of lfsr_tb is
    constant clock_period : time := 0.1 ns; --10GHz
    signal clk : std_logic := '0';
	signal rst_n : std_logic := '0';
    
	
	type testcasespec is record
		LFSR_SIZE : natural;
		LFSR_CYCLE_STOP_STATE : boolean;
		STEP_OFFSET : integer;
	end record testcasespec;
	type testcasespec_vec is array(natural range <>) of testcasespec;
	
	constant testcasecount : natural := 4; --set to 5 to force assertion failure
	constant case_spec : testcasespec_vec(0 to 4) := (
		(5, false, 1),
		(8, false, -1),
		(14, true, 1),
		(24, false, 3),
		(0, false, 1)
	);
	
    signal passed : std_logic_vector(testcasecount-1 downto 0);
	signal error  : std_logic_vector(testcasecount-1 downto 0);
    signal stop : std_logic := '0';
begin
    clk <= NOT clk after clock_period/2;
	rst_n <= '1' after 100*clock_period;
	
	uutgen: for i in testcasecount-1 downto 0 generate
		uut: entity libcommons.lfsr_test_object
		generic map (
			LFSR_SIZE => case_spec(i).LFSR_SIZE,
			LFSR_CYCLE_STOP_STATE => case_spec(i).LFSR_CYCLE_STOP_STATE,
			STEP_OFFSET => case_spec(i).STEP_OFFSET
		) port map (
		   clk => clk,
		   rst_n => rst_n,
		   
		   data_out => open,
		   error => error(i),
		   passed => passed(i)
		);
	end generate;
    
    finalizeproc: process (clk)
    begin
		if stop = '0' and rising_edge(clk) then
			if is1(passed) then
				report "###########################################################";
				report "#####################All tests passed!#####################";
				report "###########################################################";
				stop <= '1';
			end if;
			
			for i in testcasecount-1 downto 0 loop
				if error(i) = '1' then
					report "Error encountered in test case: " & integer'IMAGE(i);
					stop <= '1';
				end if;
			end loop;
		end if;
    end process;
end Behavioural;
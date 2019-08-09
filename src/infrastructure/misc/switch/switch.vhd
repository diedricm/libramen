library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity switch is
generic (
	TUPPLE_COUNT : natural := 4;
	INPORT_CNT   : natural := 8;
	OUTPORT_CNT  : natural := 8;
	CDEST_PARSE_LENGTH : natural := 3;
	CDEST_PARSE_OFFSET : natural := 2;
	CONNECTION_MATRIX : slv2D(INPORT_CNT-1 downto 0)(OUTPORT_CNT-1 downto 0) := (others => (others => '1'))
);
Port (
	clk : in std_logic;
	rstn : in std_logic;

	stream_s  : in flit_vec(INPORT_CNT-1 downto 0)(tuples(TUPPLE_COUNT-1 downto 0));
	ready_s : out std_logic_vector(INPORT_CNT-1 downto 0);
	
	stream_m  : out flit_vec(OUTPORT_CNT-1 downto 0)(tuples(TUPPLE_COUNT-1 downto 0));
	ready_m : in std_logic_vector(OUTPORT_CNT-1 downto 0)
);
end switch;

architecture Behavioural of switch is
	constant INPORT_CNT_LOG2  : natural := log2_nat(INPORT_CNT);
	constant OUTPORT_CNT_LOG2 : natural := log2_nat(OUTPORT_CNT);

	signal outport_occupied  : std_logic_vector(OUTPORT_CNT-1 downto 0) := (others =>  '0');
	signal forward_enabled   : slv2D(OUTPORT_CNT-1 downto 0)(INPORT_CNT_LOG2-1 downto 0) := (others => (others => '0'));

	signal req_matrix : slv2D(INPORT_CNT-1 downto 0)(OUTPORT_CNT-1 downto 0) := (others => (others => '0'));
	signal last_selected_port : slv2D(OUTPORT_CNT-1 downto 0)(INPORT_CNT_LOG2-1 downto 0) := (others => (others => '0'));
begin

	assert CDEST_PARSE_LENGTH = OUTPORT_CNT_LOG2 report "Switch  CDEST_PARSE_LENGTH does not match number of output ports!" severity failure;
	assert (CDEST_PARSE_LENGTH + CDEST_PARSE_OFFSET) < CDEST_SIZE_IN_BIT report "Switch has exceeds CDEST_SIZE_IN_BIT limit during parsing" severity failure;

	main: process (clk)
		variable next_selected_inport : unsigned(INPORT_CNT_LOG2-1 downto 0);
        variable cdest_int : natural;
	begin
		if rising_edge(clk)  then
			for i in 0 to OUTPORT_CNT-1 loop
				stream_m(i) <=  stream_s(to_integer(unsigned(forward_enabled(i))));
				if is0(outport_occupied) OR is1(stream_m(i).valid AND stream_m(i).yield AND ready_m) then
					stream_m(i).valid <= '0';
                    outport_occupied(i) <= '0';
					for j in 0 to INPORT_CNT-1  loop
						next_selected_inport := unsigned(last_selected_port(i)) + j + 1;
						if is1(req_matrix(j)(to_integer(next_selected_inport))) then
							forward_enabled(i) <= std_logic_vector(next_selected_inport);
							outport_occupied(i) <= '1';
						end if;
					end loop;
				end if;
			end loop;
			
            for i in 0 to INPORT_CNT-1 loop
                cdest_int := to_integer(unsigned(stream_s(i).cdest(CDEST_PARSE_LENGTH+CDEST_PARSE_OFFSET downto CDEST_PARSE_OFFSET)));
                if (cdest_int < OUTPORT_CNT) AND is1(CONNECTION_MATRIX(i)(cdest_int)) AND is1(stream_s(i).valid) then
                    req_matrix(i)(cdest_int) <= '1';
                else
                    req_matrix(i)(cdest_int) <= '0';
                end if;  
            end loop;
		end if;
	end process;

	comb: process (ALL)
	begin
        
        ready_s <= (others => '0');
        
        for i in 0 to OUTPORT_CNT-1 loop
            if is1(outport_occupied(i)) then
                ready_s(to_integer(unsigned(forward_enabled(i)))) <= ready_m(i);
            end if;
        end loop;

	end process;

end architecture ; -- Behavioural
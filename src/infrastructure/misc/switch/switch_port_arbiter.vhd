library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity switch_port_arbiter is
generic (
	TUPPLE_COUNT : natural := 4;
	INPORT_CNT   : natural := 16;
	OUTPORT_CNT  : natural := 16
);
Port (
	clk : in std_logic;
	rstn : in std_logic;
	
	port_req : in std_logic_vector(INPORT_CNT-1 downto 0);

    stream_s_tuples  : in tuple_vec(INPORT_CNT*TUPPLE_COUNT-1 downto 0);
	stream_s_status  : in stream_status_vec(INPORT_CNT-1 downto 0);
	stream_s_ready   : out std_logic_vector(INPORT_CNT-1 downto 0);
	
	stream_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
	stream_m_status  : out stream_status;
	stream_m_ready : in std_logic
);
end switch_port_arbiter;

architecture Behavioural of switch_port_arbiter is
	constant INPORT_CNT_LOG2  : natural := log2_nat(INPORT_CNT);
	constant OUTPORT_CNT_LOG2 : natural := log2_nat(OUTPORT_CNT);
	
	subtype inport_id is unsigned(INPORT_CNT_LOG2-1 downto 0);
	type inport_id_vec is array (natural range <>) of inport_id;

	signal stream_reg_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
	signal stream_reg_status  : stream_status;

	signal outport_occupied  : std_logic := '0';
	signal selected_input    : inport_id := (others => '0');
begin

    comb: process (ALL)
    begin    
        stream_s_ready <= (others => '0'); 
        stream_s_ready(to_integer(selected_input)) <= stream_m_ready AND outport_occupied;
        
        stream_m_tuples <= stream_reg_tuples;
        stream_m_status <= stream_reg_status;
        stream_m_status.valid <= stream_reg_status.valid;
    end process;

    main: process (clk)
        variable test_inport_tmp : inport_id;
        variable cdest_int : natural;
    begin
        if rising_edge(clk)  then
            if is0(rstn) then
                stream_reg_status.valid <= '0';
            else
                if is1(stream_m_ready AND stream_m_status.valid) then
                    stream_reg_status.valid <= '0';
                end if;
            
                --Mux Data
                if (is1(stream_m_ready OR NOT(stream_m_status.valid))) AND is1(outport_occupied) then
                    for k in 0 to TUPPLE_COUNT-1 loop
                        stream_reg_tuples(k) <= stream_s_tuples(to_integer(selected_input)*TUPPLE_COUNT+k);
                    end loop;
                    stream_reg_status <= stream_s_status(to_integer(selected_input));
                    
                    if is1(stream_s_status(to_integer(selected_input)).yield) then
                        outport_occupied <= '0';
                    end if;
                end if;
                
                --Select new inputs
                if is0(outport_occupied) then
                    test_inport_tmp := selected_input;
                    for j in 0 to INPORT_CNT-1 loop
                        if is1(port_req(to_integer(test_inport_tmp))) then
                            selected_input <= test_inport_tmp;
                            outport_occupied <= '1';
                        end if;
                        test_inport_tmp := test_inport_tmp + 1;
                        if test_inport_tmp > INPORT_CNT-1 then
                            test_inport_tmp := (others => '0');
                        end if;
                    end loop;
                end if;
                
            end if;
        end if;
    end process;

end architecture ; -- Behavioural
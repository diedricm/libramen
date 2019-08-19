library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity switch_port_client is
generic (
	TUPPLE_COUNT : natural := 4;
	INPORT_CNT   : natural := 16;
	OUTPORT_CNT  : natural := 16;
    CDEST_PARSE_OFFSET : natural := 2;
    CONNECTION_VECTOR : slv(0 to OUTPORT_CNT-1) := (others => '1')
);
Port (
	clk : in std_logic;
	rstn : in std_logic;
	
	port_req : out std_logic_vector(OUTPORT_CNT-1 downto 0);

    stream_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
	stream_s_status  : in stream_status;
	stream_s_ready   : out std_logic;
	
	stream_m_ready   : in std_logic_vector(OUTPORT_CNT-1 downto 0)
);
end switch_port_client;

architecture Behavioural of switch_port_client is
    constant INPORT_CNT_LOG2  : natural := log2_nat(INPORT_CNT);
    constant OUTPORT_CNT_LOG2 : natural := log2_nat(OUTPORT_CNT);
    
    subtype outport_id is unsigned(OUTPORT_CNT_LOG2-1 downto 0);
    subtype inport_id is unsigned(INPORT_CNT_LOG2-1 downto 0);
    type inport_id_vec is array (natural range <>) of inport_id;

    signal is_running : std_logic := '0';
    signal illegal_cdest_req : std_logic := '0';
    signal selected_port : outport_id := (others => '0');
    signal terminate : std_logic;
begin

    main: process (clk)
        variable next_port : outport_id;
    begin
        if rising_edge(clk) then
        
            if is1(terminate) OR is0(is_running) then
                is_running <= '0';
                
                if is1(stream_s_status.valid) then
                    next_port := unsigned(stream_s_status.cdest(OUTPORT_CNT_LOG2+CDEST_PARSE_OFFSET-1 downto CDEST_PARSE_OFFSET));
                    if next_port < OUTPORT_CNT AND is1(CONNECTION_VECTOR(to_integer(next_port))) then
                        selected_port <= next_port;
                        is_running <= NOT(terminate);
                    else
                        illegal_cdest_req <= '1';
                        report "Illegal port reference!" severity error;
                    end if;
                end if;
            end if;
        
        end if;
    end process;

    comb: process (ALL)
    begin
        terminate <= stream_s_status.valid AND stream_s_status.yield AND stream_s_ready;
    
        port_req <= (others => '0'); 
        port_req(to_integer(selected_port)) <= is_running AND NOT(illegal_cdest_req);
        
        if is1(illegal_cdest_req) then
            stream_s_ready <= '1';
        elsif is1(is_running) then
            stream_s_ready <= stream_m_ready(to_integer(selected_port));
        else 
            stream_s_ready <= '0';
        end if;
    end process;

end architecture ; -- Behavioural
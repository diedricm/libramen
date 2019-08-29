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
    CDEST_PARSE_OFFSET : natural := 4;
    CDEST_PARSE_LENGTH : natural := 4;
    GATEWAY_ADDR_OFFSET : natural := 8;
	GATEWAY_ADDR_LENGTH : natural := 4;
	SUBNET_IDENTITY     : natural := 0;
	ENABLE_INTERNETWORK_ROUTING : boolean := true;
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
    
    signal selected_port : outport_id := (others => '0');
    
    signal cdest_tmp : outport_id;
    signal cdest_tmp_decode_valid : std_logic;
    
    signal cdest_reg : outport_id := (others => '0');
    signal cdest_tmp_decode_valid_reg : std_logic := '0';
    
    signal local_addr : outport_id;
    signal subnet_addr : unsigned(GATEWAY_ADDR_LENGTH-1 downto 0);
begin

    local_addr <= to_unsigned(to_integer(unsigned(stream_s_status.cdest(CDEST_PARSE_LENGTH+CDEST_PARSE_OFFSET-1 downto CDEST_PARSE_OFFSET))), OUTPORT_CNT_LOG2);
    subnet_addr <= unsigned(stream_s_status.cdest(GATEWAY_ADDR_LENGTH+GATEWAY_ADDR_OFFSET-1 downto GATEWAY_ADDR_OFFSET));

    compute_cdest: process (ALL)
        variable tmp : outport_id;
    begin
        if is1(stream_s_status.valid) then    
            if (ENABLE_INTERNETWORK_ROUTING)  then
                if subnet_addr /= SUBNET_IDENTITY then
                    tmp := (others => '0');
                else
                    tmp := local_addr+1;
                end if;
            else
                tmp := local_addr;
            end if;
            
            cdest_tmp_decode_valid <= '0';
            if tmp < OUTPORT_CNT AND is1(CONNECTION_VECTOR(to_integer(tmp))) then
                cdest_tmp_decode_valid <= '1';
            end if;
            
            cdest_tmp <= tmp;
        else
            cdest_tmp <= (others => '0');
            cdest_tmp_decode_valid <= '0';
        end if;
        
        if is1(is_running) then
            cdest_tmp <= cdest_reg;
            cdest_tmp_decode_valid <= cdest_tmp_decode_valid_reg;
        end if; 
    end process;

    comb_output: process (ALL)
    begin
        port_req <= (others => '0'); 
        port_req(to_integer(cdest_tmp)) <= cdest_tmp_decode_valid;
        
        if is0(cdest_tmp_decode_valid) or is0(is_running) then
            stream_s_ready <= '0';
        else
            stream_s_ready <= stream_m_ready(to_integer(cdest_tmp));
        end if;    
    end process;

    main: process (clk)
    begin
        if rising_edge(clk) then
            if is1(rstn) then
        
                cdest_reg <= cdest_tmp;
                cdest_tmp_decode_valid_reg <= cdest_tmp_decode_valid;
        
                if is0(is_running) then
                    if is1(stream_s_status.valid) then
                        is_running <= '1';
                        if is0(cdest_tmp_decode_valid) then 
                            report "Illegal port reference." severity error;
                        end if;
                    end if;
                end if;
                
                if is1(stream_s_status.valid AND stream_s_ready AND stream_s_status.yield) then
                    is_running <= '0';
                end if;
                
            end if;
        end if;
    end process;

end architecture ; -- Behavioural
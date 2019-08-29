library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity regfilter is
generic (
	TUPPLE_COUNT : natural := 4;
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	CHAN_ADDR_BY_CDEST : boolean := true;
	HIGH_REG_ADDR : natural := 2;
	INPUT_CONTAINS_DATA : boolean := true
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	regwrite_data : out slv(63 downto 0);
	regwrite_addr : out slv(31 downto 0);
	regwrite_chan : out slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	regwrite_valid : out std_logic;
	
    stream_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_s_status  : in stream_status;
	stream_s_ready   : out std_logic;
    stream_s_ldest   : in slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    
    stream_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_m_status  : out stream_status;
	stream_m_ready   : in  std_logic;
    stream_m_ldest   : out slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0)
);
end regfilter;

architecture Behavioral of regfilter is
    signal input_chan_by_cdest : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal input_chan_by_tagprefix : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal input_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal input_chan_is_active : std_logic;
    
    signal reg_addr : unsigned(31 downto 0);
    
    signal input_starts_circuit : std_logic;
    
    signal chan_active_reg : std_logic_vector(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
begin
    input_chan_by_cdest <= unsigned(stream_s_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
    input_chan_by_tagprefix <= unsigned(stream_s_tuples(0).tag(16+VIRTUAL_PORT_CNT_LOG2-1 downto 16));
    input_chan <= input_chan_by_cdest when CHAN_ADDR_BY_CDEST OR is1(chan_active_reg(to_integer(input_chan_by_cdest))) else input_chan_by_tagprefix;
      
    input_chan_is_active <= chan_active_reg(to_integer(input_chan));
    
    reg_addr(15 downto 0) <= unsigned(stream_s_tuples(0).tag(15 downto 0));
    reg_addr(31 downto 16) <= unsigned(stream_s_tuples(0).tag(31 downto 16)) when CHAN_ADDR_BY_CDEST else (others => '0');
    
    comb: process (ALL)
    begin
    
        stream_m_tuples <= stream_s_tuples;
        stream_m_status <= stream_s_status;
        stream_m_ldest  <= stream_s_ldest;
        stream_s_ready  <= stream_m_ready;
        
        if is1(input_chan_is_active) OR is0(reg_addr) OR (reg_addr > HIGH_REG_ADDR) then
            stream_m_status.valid <= stream_s_status.valid;
        else
            stream_m_status.valid <= '0'; 
        end if;
        
        regwrite_data <= stream_s_tuples(0).value;
        regwrite_addr <= std_logic_vector(reg_addr);
        regwrite_chan <= std_logic_vector(input_chan);
        regwrite_valid <= '0';
        
        if is1(stream_s_ready AND stream_s_status.valid AND NOT(input_chan_is_active)) AND (reg_addr <= HIGH_REG_ADDR) then
            regwrite_valid <= '1';
        end if;
        
    end process;
    
    seq: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
                assert is0(regwrite_valid) OR (stream_s_status.ptype = TLAST_MASK_HARDEND_3INVALID) report "Register accesses must hard end circuit after first tuple!" severity failure;
            
                if is0(regwrite_addr) AND is1(regwrite_valid) AND INPUT_CONTAINS_DATA then
                    chan_active_reg(to_integer(unsigned(regwrite_chan))) <= '1';
                end if;
                
                if is1(stream_s_ready AND stream_s_status.valid AND input_chan_is_active) AND is_hardend(stream_s_status) then
                    chan_active_reg(to_integer(input_chan)) <= '0';
                end if;
                
            end if;
        end if;
    end process;
    
end Behavioral;
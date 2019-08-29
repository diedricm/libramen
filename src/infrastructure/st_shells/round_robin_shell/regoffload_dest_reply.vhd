library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity regoffload_dest_reply is
generic (
	TUPPLE_COUNT : natural := 4;
	
    OFFLOAD_DEST_REPLACEMENT : boolean := true;
	OFFLOAD_RETURN_HANDLING : boolean := true;
	
    VIRTUAL_PORT_CNT_LOG2 : natural := 3;
    INPUT_CONTAINS_DATA : boolean := true
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
    stream_core_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_s_status  : in stream_status;
	stream_core_s_ready   : out std_logic;
	stream_core_s_ldest   : in slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);

    stream_core_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_core_m_status  : out stream_status;
	stream_core_m_ready   : in std_logic;

    stream_ext_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_ext_s_status  : in stream_status;
	stream_ext_s_ready   : out std_logic;
	
    stream_ext_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_ext_m_status  : out stream_status;
	stream_ext_m_ready   : in std_logic;
	stream_ext_m_ldest   : out slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0)
);
end regoffload_dest_reply;

architecture Behavioral of regoffload_dest_reply is

    function compute_high_reg_addr_based_on_features(OFFLOAD_DEST_REPLACEMENT : boolean; OFFLOAD_RETURN_HANDLING : boolean) return natural is
        variable tmp : unsigned(31 downto 0);
    begin
        if NOT(OFFLOAD_DEST_REPLACEMENT) AND NOT(OFFLOAD_RETURN_HANDLING) then
            tmp := (others => '1');
            return to_integer(tmp);
        elsif NOT(OFFLOAD_DEST_REPLACEMENT) AND OFFLOAD_RETURN_HANDLING then
            return 1;
        else
            return 2;
        end if;
    end;
	
    type addr_list is array (natural range <>) of std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
    
    type regslot is record
        return_cookie : slv(7 downto 0);
        return_addr   : slv(13 downto 0);
        dest_addr     : slv(13 downto 0);
    end record;
    type reg_vec is array (natural range <>) of regslot;
    signal regmap : reg_vec(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    
    signal regwrite_data : slv(63 downto 0);
	signal regwrite_addr : slv(31 downto 0);
	signal regwrite_chan : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal regwrite_valid : std_logic;
    
    signal send_return_frame : std_logic := '0';
    signal return_data : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal return_addr : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
    signal return_chan : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    
    signal replaced_tdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
    
    signal stream_ext_s_DEBUG_active : std_logic;
begin

    stream_ext_s_DEBUG_active <= ap_clk AND stream_ext_s_ready AND stream_ext_s_status.valid AND NOT(or_reduce(stream_ext_s_status.cdest));
    
    regfilter: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n AND regwrite_valid) then
               case (to_integer(unsigned(regwrite_addr))) is
                   when 0 => regmap(to_integer(unsigned(regwrite_chan))).return_cookie <= regwrite_data( 7 downto 0);
                   when 1 => regmap(to_integer(unsigned(regwrite_chan))).return_addr   <= regwrite_data(13 downto 0);
                   when 2 => regmap(to_integer(unsigned(regwrite_chan))).dest_addr     <= regwrite_data(13 downto 0);
                   when others => report "ERROR in regaccess decoding" severity failure;
               end case;
            end if;
        end if;
    end process;
    
    regproc: entity libramen.regfilter
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        CHAN_ADDR_BY_CDEST => true,
        HIGH_REG_ADDR => compute_high_reg_addr_based_on_features(OFFLOAD_DEST_REPLACEMENT, OFFLOAD_RETURN_HANDLING)
    ) port map (
        ap_clk => ap_clk,
        rst_n  => rst_n,
        
        regwrite_data  => regwrite_data,
        regwrite_addr  => regwrite_addr,
        regwrite_chan  => regwrite_chan, 
        regwrite_valid => regwrite_valid,
        
        stream_s_tuples  => stream_ext_s_tuples,
        stream_s_status  => stream_ext_s_status,
        stream_s_ready   => stream_ext_s_ready,
        stream_s_ldest   => (others => '0'),
        
        stream_m_tuples  => stream_core_m_tuples,
        stream_m_status  => stream_core_m_status,
        stream_m_ready   => stream_core_m_ready,
        stream_m_ldest   => OPEN
    );

-------------------------------OUTPUT PROCESSING--------------------------------
    
    
    replaced_tdest <= stream_core_s_status.cdest when NOT(OFFLOAD_DEST_REPLACEMENT) else regmap(to_integer(unsigned(stream_core_s_ldest))).dest_addr;
    
    stream_ext_m_tuples <= stream_core_s_tuples when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_data;
    stream_ext_m_status.cdest <= replaced_tdest when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_addr;
    stream_ext_m_status.ptype <= stream_core_s_status.ptype when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else TLAST_MASK_HARDEND_3INVALID;
    stream_ext_m_status.yield <= stream_core_s_status.yield when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '1';
    stream_ext_m_status.valid <= stream_core_s_status.valid when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '1';
    stream_ext_m_ldest <= stream_core_s_ldest when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_chan;
    stream_core_s_ready <= stream_ext_m_ready when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '0';
    
    outputreplace: process (ap_clk)
        variable chan : integer;
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
                chan := to_integer(unsigned(stream_core_s_ldest));
                if is0(send_return_frame) then
                    if is_hardend(stream_core_s_status) AND is1(stream_ext_m_status.valid AND stream_ext_m_ready) then
                        send_return_frame <= '1';
                        for i in 0 to TUPPLE_COUNT-1 loop
                            return_data(i).value <= (others => '0');
                            return_data(i).tag <= (others => '0');
                        end loop;
                        return_data(0).value(7 downto 0) <= regmap(chan).return_cookie;
                        return_addr <= regmap(chan).return_addr;
                        return_chan <= std_logic_vector(to_unsigned(chan, VIRTUAL_PORT_CNT_LOG2));
                    end if;
                else
                    if is1(stream_ext_m_status.valid AND stream_ext_m_ready) then
                        send_return_frame <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;
    
    assert NOT(OFFLOAD_DEST_REPLACEMENT) OR OFFLOAD_RETURN_HANDLING report "If OFFLOAD_DEST_REPLACEMENT is enabled, then OFFLOAD_RETURN_HANDLING must be too!" severity failure;

end Behavioral;
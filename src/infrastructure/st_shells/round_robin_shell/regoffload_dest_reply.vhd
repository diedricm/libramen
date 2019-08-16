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
	
    VIRTUAL_PORT_CNT_LOG2 : natural := 3
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

    type addr_list is array (natural range <>) of std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
    type cookie_list is array (natural range <>) of std_logic_vector(7 downto 0);
    
    signal return_cookie_mem : cookie_list(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal return_addr_mem : addr_list(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal destination_addr_mem : addr_list(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal chan_active : std_logic_vector(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    
    signal curr_input_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal curr_input_active : std_logic;
    signal curr_input_reg_addr : unsigned(TAG_SIZE_IN_BITS-1 downto 0);
    
    signal send_return_frame : std_logic := '0';
    signal return_data : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal return_addr : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
    
    signal replaced_tdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
begin

    curr_input_chan <= unsigned(stream_ext_s_status.cdest(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
    curr_input_active <= chan_active(to_integer(curr_input_chan));
    curr_input_reg_addr <= unsigned(stream_ext_s_tuples(0).tag);
    
    stream_core_m_tuples <= stream_ext_s_tuples;
    stream_core_m_status.cdest <= stream_ext_s_status.cdest;
    stream_core_m_status.ptype <= stream_ext_s_status.ptype;
    stream_core_m_status.yield <= stream_ext_s_status.yield;
    stream_core_m_status.valid<= stream_ext_s_status.valid when is1(curr_input_active)
                                             OR (curr_input_reg_addr > 2)
                                             OR (NOT(OFFLOAD_DEST_REPLACEMENT) AND (curr_input_reg_addr > 1))
                                             OR (NOT(OFFLOAD_RETURN_HANDLING) AND (curr_input_reg_addr /= 2))
                                             OR (NOT(OFFLOAD_RETURN_HANDLING) AND NOT (OFFLOAD_DEST_REPLACEMENT)) else '0';
    stream_ext_s_ready <= stream_core_m_ready;
    
    regfilter: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n AND stream_ext_s_status.valid AND stream_ext_s_ready) then
                assert NOT(OFFLOAD_DEST_REPLACEMENT) OR OFFLOAD_RETURN_HANDLING report "If OFFLOAD_DEST_REPLACEMENT is enabled, then OFFLOAD_RETURN_HANDLING must be too!" severity failure;
                assert is1(curr_input_active) OR (stream_ext_s_status.ptype = TLAST_MASK_HARDEND_3INVALID) report "Register accesses must hard end circuit after first tuple!" severity failure;
            
                case to_integer(curr_input_reg_addr) is
                
                    when START_REG_ADDR         =>  if is0(curr_input_active) then
                                                        chan_active(to_integer(curr_input_chan)) <= '1';
                                                        return_cookie_mem(to_integer(curr_input_chan)) <= stream_ext_s_tuples(0).value(8-1 downto 0);
                                                    end if;
                                                    
                    when RETURN_DEST_REG_ADDR   =>  if is0(curr_input_active) then
                                                        return_addr_mem(to_integer(curr_input_chan)) <= stream_ext_s_tuples(0).value(CDEST_SIZE_IN_BIT-1 downto 0);
                                                    end if;
                                                    
                    when FWD_DEST_REG_ADDR      =>  if is0(curr_input_active) then
                                                        destination_addr_mem(to_integer(curr_input_chan)) <= stream_ext_s_tuples(0).value(CDEST_SIZE_IN_BIT-1 downto 0);
                                                    end if;
                                                    
                    when others                 =>  if is1(curr_input_active) AND is_hardend(stream_ext_s_status) then
                                                        chan_active(to_integer(curr_input_chan)) <= '0';
                                                    end if;
                end case;
            end if;
        end if;
    end process;
    
    replaced_tdest <= stream_core_s_status.cdest when NOT(OFFLOAD_DEST_REPLACEMENT) else destination_addr_mem(to_integer(unsigned(stream_core_s_ldest)));
    
    
    stream_ext_m_tuples <= stream_core_s_tuples when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_data;
    stream_ext_m_status.cdest <= replaced_tdest when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_addr;
    stream_ext_m_status.ptype <= stream_core_s_status.ptype when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else TLAST_MASK_HARDEND_3INVALID;
    stream_ext_m_status.yield <= stream_core_s_status.yield when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '1';
    stream_ext_m_status.valid <= stream_core_s_status.valid when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '1';
    stream_ext_m_ldest <= stream_core_s_ldest;
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
                        return_data(0).value(7 downto 0) <= return_cookie_mem(chan);
                        return_addr <= return_addr_mem(chan);
                    end if;
                else
                    if is1(stream_ext_m_status.valid AND stream_ext_m_ready) then
                        send_return_frame <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
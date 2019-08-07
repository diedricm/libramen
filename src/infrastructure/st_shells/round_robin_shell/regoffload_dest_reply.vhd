library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity regoffload_dest_reply is
generic (
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
	
    OFFLOAD_DEST_REPLACEMENT : boolean := true;
	OFFLOAD_RETURN_HANDLING : boolean := true;
	
    VIRTUAL_PORT_CNT_LOG2 : natural := 3
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	TDATA_core_s  : in std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_core_s : in std_logic;
	TREADY_core_s : out std_logic;
	TDEST_core_s  : in std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_core_s  : in std_logic_vector(TUSER_EXT_SIZE_IN_BIT-1 downto 0);
	TLAST_core_s  : in std_logic;
	
	TDATA_core_m  : out std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_core_m : out std_logic;
	TREADY_core_m : in std_logic;
	TDEST_core_m  : out std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_core_m  : out std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_core_m  : out std_logic;
	
	TDATA_ext_s  : in std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_ext_s : in std_logic;
	TREADY_ext_s : out std_logic;
	TDEST_ext_s  : in std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_ext_s  : in std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_ext_s  : in std_logic;
	
	TDATA_ext_m  : out std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	TVALID_ext_m : out std_logic;
	TREADY_ext_m : in std_logic;
	TDEST_ext_m  : out std_logic_vector(TDEST_WIDTH-1 downto 0);
	TUSER_ext_m  : out std_logic_vector(TUSER_EXT_SIZE_IN_BIT-1 downto 0);
	TLAST_ext_m  : out std_logic
);
end regoffload_dest_reply;

architecture Behavioral of regoffload_dest_reply is

    type addr_list is array (natural range <>) of std_logic_vector(TDEST_WIDTH-1 downto 0);
    type cookie_list is array (natural range <>) of std_logic_vector(7 downto 0);
    
    signal return_cookie_mem : cookie_list(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal return_addr_mem : addr_list(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal destination_addr_mem : addr_list(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal chan_active : std_logic_vector(2**VIRTUAL_PORT_CNT_LOG2-1 downto 0) := (others => '0');
    
    signal curr_input_chan : unsigned(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal curr_input_active : std_logic;
    signal curr_input_reg_addr : unsigned(TAG_SIZE_IN_BITS-1 downto 0);
    
    signal send_return_frame : std_logic := '0';
    signal return_data : std_logic_vector(TDATA_WIDTH*8-1 downto 0);
    signal return_addr : std_logic_vector(TDEST_WIDTH-1 downto 0);
    
    signal replaced_tdest : std_logic_vector(TDEST_WIDTH-1 downto 0);
begin

    curr_input_chan <= unsigned(TDEST_ext_s(VIRTUAL_PORT_CNT_LOG2-1 downto 0));
    curr_input_active <= chan_active(to_integer(curr_input_chan));
    curr_input_reg_addr <= unsigned(TDATA_ext_s(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS-1 downto VALUE_SIZE_IN_BITS));
    
    TDATA_core_m  <= TDATA_ext_s;
    TDEST_core_m  <= TDEST_ext_s;
    TUSER_core_m  <= TUSER_ext_s;
    TLAST_core_m  <= TLAST_ext_s;
    TVALID_core_m <= TVALID_ext_s when is1(curr_input_active)
                                    OR (curr_input_reg_addr > 2)
                                    OR (NOT(OFFLOAD_DEST_REPLACEMENT) AND (curr_input_reg_addr > 1))
                                    OR (NOT(OFFLOAD_RETURN_HANDLING) AND (curr_input_reg_addr /= 2))
                                    OR (NOT(OFFLOAD_RETURN_HANDLING) AND NOT (OFFLOAD_DEST_REPLACEMENT)) else '0';
    TREADY_ext_s <= TREADY_core_m;
    
    regfilter: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n AND TVALID_ext_s AND TREADY_ext_s) then
                assert NOT(OFFLOAD_DEST_REPLACEMENT) OR OFFLOAD_RETURN_HANDLING report "If OFFLOAD_DEST_REPLACEMENT is enabled, then OFFLOAD_RETURN_HANDLING must be too!" severity failure;
                assert is1(curr_input_active) OR (TUSER_ext_s(2 downto 0) = VAXIS_TLAST_MASK_HARDEND_3INVALID) report "Register accesses must hard end circuit after first tuple!" severity failure;
            
                case to_integer(curr_input_reg_addr) is
                
                    when START_REG_ADDR         =>  if is0(curr_input_active) then
                                                        chan_active(to_integer(curr_input_chan)) <= '1';
                                                        return_cookie_mem(to_integer(curr_input_chan)) <=TDATA_ext_s(8-1 downto 0);
                                                    end if;
                                                    
                    when RETURN_DEST_REG_ADDR   =>  if is0(curr_input_active) then
                                                        return_addr_mem(to_integer(curr_input_chan)) <= TDATA_ext_s(TDEST_SIZE_IN_BIT-1 downto 0);
                                                    end if;
                                                    
                    when FWD_DEST_REG_ADDR      =>  if is0(curr_input_active) then
                                                        destination_addr_mem(to_integer(curr_input_chan)) <= TDATA_ext_s(TDEST_SIZE_IN_BIT-1 downto 0);
                                                    end if;
                                                    
                    when others                 =>  if is1(curr_input_active) AND is_hardend(TUSER_ext_s) then
                                                        chan_active(to_integer(curr_input_chan)) <= '0';
                                                    end if;
                end case;
            end if;
        end if;
    end process;
    
    replaced_tdest <= TDEST_core_s when NOT(OFFLOAD_DEST_REPLACEMENT) else destination_addr_mem(to_integer(unsigned(TUSER_core_s(6 downto 3))));
    
    TDATA_ext_m <= TDATA_core_s when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_data;
    TDEST_ext_m <= replaced_tdest when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else return_addr;
    TUSER_ext_m <= TUSER_core_s when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else "0000" & VAXIS_TLAST_MASK_HARDEND_3INVALID;
    TLAST_ext_m <= TLAST_core_s when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '1';
    TVALID_ext_m <= TVALID_core_s when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '1';
    TREADY_core_s <= TREADY_ext_m when (NOT(OFFLOAD_RETURN_HANDLING) OR is0(send_return_frame)) else '0';
    
    outputreplace: process (ap_clk)
        variable chan : integer;
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) then
                chan := to_integer(unsigned(TUSER_core_s(6 downto 3)));
                if is0(send_return_frame) then
                    if is_hardend(TUSER_core_s) AND is1(TVALID_ext_m AND TREADY_ext_m) then
                        send_return_frame <= '1';
                        return_data(7 downto 0) <= return_cookie_mem(chan);
                        return_data(95 downto 8) <= (others => '0');
                        return_addr <= return_addr_mem(chan);
                    end if;
                else
                    if is1(TVALID_ext_m AND TREADY_ext_m) then
                        send_return_frame <= '0';
                    end if;
                end if;
            end if;
        end if;
    end process;

end Behavioral;
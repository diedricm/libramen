library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
	use libcommons.lfsr.ALL;
library vaxis;
	use vaxis.vaxis_pkg.ALL;

entity vaxis_round_robin_st_shell_tb is
end vaxis_round_robin_st_shell_tb;

architecture Behavioral of vaxis_round_robin_st_shell_tb is

	constant TDATA_WIDTH : natural := 12;
	constant TDEST_WIDTH : natural := 14;
    
    --Offload common vaxis tasks
    constant OFFLOAD_DEST_REPLACEMENT : boolean := true;
	constant OFFLOAD_RETURN_HANDLING : boolean := true;
	
	--Set scheduling parameters
	constant LFSR_INSTEAD_OF_SEQ_ORDER : boolean := true;
	constant CREDIT_SENSITIVE_SCHEDULE : boolean := true;
	
	--IN/OUT fifo parameters
    constant VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	constant MEMORY_DEPTH_LOG2_INPUT : natural := 2;
	constant MEMORY_DEPTH_LOG2_OUTPUT : natural := 2;
	constant ALMOST_FULL_LEVEL_INPUT : natural := 4;
    constant ALMOST_FULL_LEVEL_OUTPUT : natural := 4;
	constant MEMORY_TYPE_INPUT : string := "distributed";
    constant MEMORY_TYPE_OUTPUT : string := "distributed";

    signal ap_clk : std_logic := '0';
	signal rst_n : std_logic := '0';
	
    signal credits_list_out_input : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    signal credits_list_out_output : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
	signal TDATA_core_s  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_core_s : std_logic;
	signal TREADY_core_s : std_logic;
	signal TDEST_core_s  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_core_s  : std_logic_vector(TUSER_EXT_SIZE_IN_BIT-1 downto 0);
	signal TLAST_core_s  : std_logic;
	
	signal TDATA_core_m  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_core_m : std_logic;
	signal TREADY_core_m : std_logic;
	signal TDEST_core_m  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_core_m  : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	signal TLAST_core_m  : std_logic;

	signal TVALID_core_m_tmp : std_logic;
	signal TREADY_core_m_tmp : std_logic;
    signal TVALID_core_s_tmp : std_logic;
	signal TREADY_core_s_tmp : std_logic;
	
	signal TDATA_ext_s  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_ext_s : std_logic;
	signal TREADY_ext_s : std_logic;
	signal TDEST_ext_s  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_ext_s  : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	signal TLAST_ext_s  : std_logic;
	
	signal TDATA_ext_m  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
	signal TVALID_ext_m : std_logic;
	signal TREADY_ext_m : std_logic;
	signal TDEST_ext_m  : std_logic_vector(TDEST_WIDTH-1 downto 0);
	signal TUSER_ext_m  : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	signal TLAST_ext_m  : std_logic;

    constant clock_period : time := 2ns;
    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec);
    
    signal core_busy_emulation : std_logic;
begin

    ap_clk <= NOT ap_clk after clock_period/2;
    rst_n <= '1' after clock_period*100;

    rand_vec <= step(rand_spec, rand_vec) after clock_period;

    randon_input: process (clk)
    begin
    
    end process;

    core_busy_emulation <= and_reduce(rand_vec(3 downto 0));
    TVALID_core_s <= TVALID_core_s_tmp AND NOT(core_busy_emulation);
    TREADY_core_s_tmp <= TREADY_core_s AND NOT(core_busy_emulation);
    TVALID_core_m_tmp <= TVALID_core_s AND NOT(core_busy_emulation);
    TREADY_core_m <= TREADY_core_m_tmp AND NOT(core_busy_emulation);
    
    TUSER_core_s(VIRTUAL_PORT_CNT_LOG2+3-1 downto 3) <= TDEST_core_s(VIRTUAL_PORT_CNT_LOG2-1 downto 0); 
    core_emu: entity vaxis.vaxis_multiport_fifo
    generic map  (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        VIRTUAL_PORT_CNT_LOG2 => 1,
        MEMORY_DEPTH_LOG2 => 32,
        ALMOST_FULL_LEVEL => 4,
        MEMORY_TYPE => "register"
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_input,
        
        almost_full => OPEN,
        almost_empty => OPEN,
        
        next_output_chan => (others => '0'),
        read_enable => '1',
        next_output_skip_prftchd_data => '0',

        fifo_port_dest => (others => '0'),
        
        TDATA_s  => TDATA_core_m,
        TVALID_s => TVALID_core_m_tmp,
        TREADY_s => TREADY_core_m_tmp,
        TDEST_s  => TDEST_core_m,
        TUSER_s  => TUSER_core_m,
        TLAST_s  => TLAST_core_m,
    
        TDATA_m  => TDATA_core_s,
        TVALID_m => TVALID_core_s_tmp,
        TREADY_m => TREADY_core_s_tmp,
        TDEST_m  => TDEST_core_s,
        TUSER_m  => TUSER_core_s(2 downto 0),
        TLAST_m  => TLAST_core_s
    );

    uut: entity vaxis.vaxis_round_robin_st_shell
    generic map (
        --IO settings
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        
        --Offload common vaxis tasks
        OFFLOAD_DEST_REPLACEMENT => OFFLOAD_DEST_REPLACEMENT,
        OFFLOAD_RETURN_HANDLING => OFFLOAD_RETURN_HANDLING,
        
        --Set scheduling parameters
        LFSR_INSTEAD_OF_SEQ_ORDER => LFSR_INSTEAD_OF_SEQ_ORDER,
        CREDIT_SENSITIVE_SCHEDULE => CREDIT_SENSITIVE_SCHEDULE,
        
        --IN/OUT fifo parameters
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT,
        ALMOST_FULL_LEVEL_INPUT => ALMOST_FULL_LEVEL_INPUT,
        ALMOST_FULL_LEVEL_OUTPUT => ALMOST_FULL_LEVEL_OUTPUT,
        MEMORY_TYPE_INPUT => MEMORY_TYPE_INPUT,
        MEMORY_TYPE_OUTPUT => MEMORY_TYPE_OUTPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out_input => credits_list_out_input,
        credits_list_out_output => credits_list_out_output,
        
        TDATA_core_s  => TDATA_core_s,
        TVALID_core_s => TVALID_core_s,
        TREADY_core_s => TREADY_core_s,
        TDEST_core_s  => TDEST_core_s,
        TUSER_core_s  => TUSER_core_s,
        TLAST_core_s  => TLAST_core_s,
        
        TDATA_core_m  => TDATA_core_m,
        TVALID_core_m => TVALID_core_m,
        TREADY_core_m => TREADY_core_m,
        TDEST_core_m  => TDEST_core_m,
        TUSER_core_m  => TUSER_core_m,
        TLAST_core_m  => TLAST_core_m,
        
        TDATA_ext_s   => TDATA_ext_s,
        TVALID_ext_s  => TVALID_ext_s,
        TREADY_ext_s  => TREADY_ext_s,
        TDEST_ext_s   => TDEST_ext_s,
        TUSER_ext_s   => TUSER_ext_s,
        TLAST_ext_s   => TLAST_ext_s,
        
        TDATA_ext_m   => TDATA_ext_m,
        TVALID_ext_m  => TVALID_ext_m,
        TREADY_ext_m  => TREADY_ext_m,
        TDEST_ext_m   => TDEST_ext_m,
        TUSER_ext_m   => TUSER_ext_m,
        TLAST_ext_m   => TLAST_ext_m
    );

end Behavioral;

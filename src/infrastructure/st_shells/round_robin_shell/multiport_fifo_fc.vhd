library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity vaxis_multiport_fifo_fc is
generic (
    --IO settings
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
	
	--IN/OUT fifo parameters
    VIRTUAL_PORT_CNT_LOG2 : natural := 3;
	MEMORY_DEPTH_LOG2_INPUT : natural := 6;
	MEMORY_DEPTH_LOG2_OUTPUT : natural := 6;
	ALMOST_FULL_LEVEL_INPUT : natural := 16;
    ALMOST_FULL_LEVEL_OUTPUT : natural := 16;
	MEMORY_TYPE_INPUT : string := "block";
    MEMORY_TYPE_OUTPUT : string := "block"
);
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
    credits_list_out_input : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
    change_output_chan_req_inp  : out std_logic;
    change_input_chan_req_out   : out std_logic;
    change_output_chan_req_out  : out std_logic;
    
    next_output_chan_inp        : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_inp             : in std_logic;
    next_output_chan_out        : in std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    read_enable_out             : in std_logic;
    next_output_skip_prftchd_data_out : in std_logic;
	
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
	TUSER_ext_m  : out std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_ext_m  : out std_logic
);
end vaxis_multiport_fifo_fc;

architecture Behavioral of vaxis_multiport_fifo_fc is
    signal TDATA_fc_in  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
    signal TVALID_fc_in : std_logic;
    signal TREADY_fc_in : std_logic;
    signal TDEST_fc_in  : std_logic_vector(TDEST_WIDTH-1 downto 0);
    signal TUSER_fc_in  : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    signal TLAST_fc_in  : std_logic;
    
    signal TDATA_fc_out  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
    signal TVALID_fc_out : std_logic;
    signal TREADY_fc_out : std_logic;
    signal TDEST_fc_out  : std_logic_vector(TDEST_WIDTH-1 downto 0);
    signal TUSER_fc_out  : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    signal TLAST_fc_out  : std_logic;
    
    signal almost_full  : std_logic;
    signal change_output_chan_req_out_1, change_output_chan_req_out_2 : std_logic;
begin

    change_output_chan_req_out <= change_output_chan_req_out_1 OR change_output_chan_req_out_2;

    input_fc: entity vaxis.vaxis_congestion_feedback
    generic map (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        TUSER_WIDTH => TUSER_SIZE_IN_BIT,
        BACKOFF_DETECTION_PERIOD => DEFAULT_BACKOFF_DETECTION_PERIOD,
        CIRCUIT_SETUP_PROBE_PERIOD => DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
        
        trigger_backoff => almost_full,
    
        TDATA_s  => TDATA_ext_s,
        TVALID_s => TVALID_ext_s,
        TREADY_s => TREADY_ext_s,
        TDEST_s  => TDEST_ext_s,
        TUSER_s  => TUSER_ext_s,
        TLAST_s  => TLAST_ext_s,
    
        TDATA_m  => TDATA_fc_in,
        TVALID_m => TVALID_fc_in,
        TREADY_m => TREADY_fc_in,
        TDEST_m  => TDEST_fc_in,
        TUSER_m  => TUSER_fc_in,
        TLAST_m  => TLAST_fc_in
    );

    input_fifo: entity vaxis.vaxis_multiport_fifo
    generic map  (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2_INPUT,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL_INPUT,
        MEMORY_TYPE => MEMORY_TYPE_INPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_input,
        
        almost_full => almost_full,
        almost_empty => change_output_chan_req_inp,
        
        next_output_chan => next_output_chan_inp,
        read_enable => read_enable_inp,
        next_output_skip_prftchd_data => '0',
        
        TDATA_s  => TDATA_fc_in,
        TVALID_s => TVALID_fc_in,
        TREADY_s => TREADY_fc_in,
        TDEST_s  => TDEST_fc_in,
        TUSER_s  => TUSER_fc_in,
        TLAST_s  => TLAST_fc_in,
        fifo_port_dest => TDEST_fc_in(VIRTUAL_PORT_CNT_LOG2-1 downto 0),
        
        TDATA_m  => TDATA_core_m,
        TVALID_m => TVALID_core_m,
        TREADY_m => TREADY_core_m,
        TDEST_m  => TDEST_core_m,
        TUSER_m  => TUSER_core_m,
        TLAST_m  => TLAST_core_m
    );
    
    output_fifo: entity vaxis.vaxis_multiport_fifo
    generic map  (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2_OUTPUT,
        ALMOST_FULL_LEVEL => ALMOST_FULL_LEVEL_OUTPUT,
        MEMORY_TYPE => MEMORY_TYPE_OUTPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out_output,
        
        almost_full => change_input_chan_req_out,
        almost_empty => change_output_chan_req_out_1,
        
        next_output_chan => next_output_chan_out,
        read_enable => read_enable_out,
        next_output_skip_prftchd_data => next_output_skip_prftchd_data_out,
        
        TDATA_s  => TDATA_core_s,
        TVALID_s => TVALID_core_s,
        TREADY_s => TREADY_core_s,
        TDEST_s  => TDEST_core_s,
        TUSER_s  => TUSER_core_s(2 downto 0),
        TLAST_s  => TLAST_core_s,
        fifo_port_dest => TUSER_core_s(2+VIRTUAL_PORT_CNT_LOG2 downto 3),
        
        TDATA_m  => TDATA_fc_out,
        TVALID_m => TVALID_fc_out,
        TREADY_m => TREADY_fc_out,
        TDEST_m  => TDEST_fc_out,
        TUSER_m  => TUSER_fc_out,
        TLAST_m  => TLAST_fc_out
    );
    
    output_fc: entity vaxis.vaxis_congestion_backoff
    generic map (
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        TUSER_WIDTH => TUSER_SIZE_IN_BIT,
        BACKOFF_DETECTION_PERIOD => DEFAULT_BACKOFF_DETECTION_PERIOD,
        CIRCUIT_SETUP_PROBE_PERIOD => DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
    
        backoff => change_output_chan_req_out_2,
        
        TDATA_s  => TDATA_fc_out,
        TVALID_s => TVALID_fc_out,
        TREADY_s => TREADY_fc_out,
        TDEST_s  => TDEST_fc_out,
        TUSER_s  => TUSER_fc_out,
        TLAST_s  => TLAST_fc_out,
    
        TDATA_m  => TDATA_ext_m,
        TVALID_m => TVALID_ext_m,
        TREADY_m => TREADY_ext_m,
        TDEST_m  => TDEST_ext_m,
        TUSER_m  => TUSER_ext_m,
        TLAST_m  => TLAST_ext_m
    );

end Behavioral;
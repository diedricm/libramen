library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity vaxis_round_robin_st_shell is
generic (
    --IO settings
	TDATA_WIDTH : natural := 12;
	TDEST_WIDTH : natural := 14;
    
    --Offload common vaxis tasks
    OFFLOAD_DEST_REPLACEMENT : boolean := true;
	OFFLOAD_RETURN_HANDLING : boolean := true;
	
	--Set scheduling parameters
	LFSR_INSTEAD_OF_SEQ_ORDER : boolean := true;
	CREDIT_SENSITIVE_SCHEDULE : boolean := true;
	
	--IN/OUT fifo parameters
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
	MEMORY_DEPTH_LOG2_INPUT : natural := 2;
	MEMORY_DEPTH_LOG2_OUTPUT : natural := 2;
	ALMOST_FULL_LEVEL_INPUT : natural := 4;
    ALMOST_FULL_LEVEL_OUTPUT : natural := 4;
	MEMORY_TYPE_INPUT : string := "distributed";
    MEMORY_TYPE_OUTPUT : string := "distributed"
);
Port (

	ap_clk : in std_logic;
	rst_n : in std_logic;
	
    credits_list_out_input : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    credits_list_out_output : out std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);
	
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
end vaxis_round_robin_st_shell;

architecture Behavioral of vaxis_round_robin_st_shell is
	ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of  TDEST_ext_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_S TDEST";
    ATTRIBUTE X_INTERFACE_INFO of  TDATA_ext_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_S TDATA";
    ATTRIBUTE X_INTERFACE_INFO of  TLAST_ext_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_S TLAST";
    ATTRIBUTE X_INTERFACE_INFO of  TUSER_ext_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_S TUSER";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_ext_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_S TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_ext_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_S TREADY";
    ATTRIBUTE X_INTERFACE_INFO of  TDEST_ext_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_M TDEST";
    ATTRIBUTE X_INTERFACE_INFO of  TDATA_ext_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_M TDATA";
    ATTRIBUTE X_INTERFACE_INFO of  TLAST_ext_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_M TLAST";
    ATTRIBUTE X_INTERFACE_INFO of  TUSER_ext_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_M TUSER";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_ext_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_M TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_ext_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_EXT_M TREADY";
    ATTRIBUTE X_INTERFACE_INFO of  TDEST_core_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_S TDEST";
    ATTRIBUTE X_INTERFACE_INFO of  TDATA_core_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_S TDATA";
    ATTRIBUTE X_INTERFACE_INFO of  TLAST_core_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_S TLAST";
    ATTRIBUTE X_INTERFACE_INFO of  TUSER_core_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_S TUSER";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_core_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_S TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_core_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_S TREADY";
    ATTRIBUTE X_INTERFACE_INFO of  TDEST_core_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_M TDEST";
    ATTRIBUTE X_INTERFACE_INFO of  TDATA_core_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_M TDATA";
    ATTRIBUTE X_INTERFACE_INFO of  TLAST_core_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_M TLAST";
    ATTRIBUTE X_INTERFACE_INFO of  TUSER_core_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_M TUSER";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_core_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_M TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_core_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_CORE_M TREADY";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_ext_m: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TID_WIDTH 0,TDEST_WIDTH 14";
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_ext_s: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TID_WIDTH 0,TDEST_WIDTH 14";
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_core_m: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TID_WIDTH 0,TDEST_WIDTH 14";
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_core_s: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TID_WIDTH 0,TDEST_WIDTH 14";

    signal credits_list_out_input_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    signal credits_list_out_output_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_OUTPUT-1 downto 0);

    signal change_output_chan_req_inp : std_logic;
    signal change_input_chan_req_out : std_logic;
    signal change_output_chan_req_out : std_logic;
    
    signal next_output_chan_inp : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal read_enable_inp : std_logic;
    signal next_output_chan_out : std_logic_vector(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    signal read_enable_out : std_logic;
    signal next_output_skip_prftchd_data_out : std_logic;
    
    signal TDATA_regfilter  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
    signal TVALID_regfilter : std_logic;
    signal TREADY_regfilter : std_logic;
    signal TDEST_regfilter  : std_logic_vector(TDEST_WIDTH-1 downto 0);
    signal TUSER_regfilter  : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    signal TLAST_regfilter  : std_logic;

    signal TDATA_destreplace  : std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
    signal TVALID_destreplace : std_logic;
    signal TREADY_destreplace : std_logic;
    signal TDEST_destreplace  : std_logic_vector(TDEST_WIDTH-1 downto 0);
    signal TUSER_destreplace  : std_logic_vector(TUSER_EXT_SIZE_IN_BIT-1 downto 0);
    signal TLAST_destreplace  : std_logic;
begin

    credits_list_out_input <= credits_list_out_input_buffer;
    credits_list_out_output <= credits_list_out_output_buffer;

    regoffload: entity vaxis.regoffload_dest_reply
    generic map (
    	TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        OFFLOAD_DEST_REPLACEMENT => OFFLOAD_DEST_REPLACEMENT,
        OFFLOAD_RETURN_HANDLING => OFFLOAD_RETURN_HANDLING,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
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
        
        TDATA_ext_s  => TDATA_regfilter,
        TVALID_ext_s => TVALID_regfilter,
        TREADY_ext_s => TREADY_regfilter,
        TDEST_ext_s  => TDEST_regfilter,
        TUSER_ext_s  => TUSER_regfilter,
        TLAST_ext_s  => TLAST_regfilter,
        
        TDATA_ext_m  => TDATA_destreplace,
        TVALID_ext_m => TVALID_destreplace,
        TREADY_ext_m => TREADY_destreplace,
        TDEST_ext_m  => TDEST_destreplace,
        TUSER_ext_m  => TUSER_destreplace,
        TLAST_ext_m  => TLAST_destreplace
    );

    scheduler: entity vaxis.roundrobin_scheduler
    generic map (
        LFSR_INSTEAD_OF_SEQ_ORDER => LFSR_INSTEAD_OF_SEQ_ORDER, 
        CREDIT_SENSITIVE_SCHEDULE => CREDIT_SENSITIVE_SCHEDULE, 
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT
    ) port map (
        clk => ap_clk,
        rst_n => rst_n,
    
        credits_list_out_input  => credits_list_out_input_buffer,
        credits_list_out_output => credits_list_out_output_buffer,

        change_output_chan_req_inp => change_output_chan_req_inp,
        change_input_chan_req_out  => change_input_chan_req_out,
        change_output_chan_req_out => change_output_chan_req_out,
    
        next_output_chan_inp    => next_output_chan_inp,
        read_enable_inp         => read_enable_inp,
        next_output_chan_out    => next_output_chan_out,
        read_enable_out         => read_enable_out,
        next_output_skip_prftchd_data_out => next_output_skip_prftchd_data_out
    );

    fifos: entity vaxis.vaxis_multiport_fifo_fc
    generic map (
        --IO settings
        TDATA_WIDTH => TDATA_WIDTH,
        TDEST_WIDTH => TDEST_WIDTH,
        
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
        
        credits_list_out_input => credits_list_out_input_buffer,
        credits_list_out_output => credits_list_out_output_buffer,
        
        
        change_output_chan_req_inp  => change_output_chan_req_inp,
        change_input_chan_req_out   => change_input_chan_req_out,
        change_output_chan_req_out  => change_output_chan_req_out,
        
        next_output_chan_inp        => next_output_chan_inp,
        read_enable_inp             => read_enable_inp,
        next_output_chan_out        => next_output_chan_out,
        read_enable_out             => read_enable_out,
        next_output_skip_prftchd_data_out => next_output_skip_prftchd_data_out,
        
        TDATA_core_s  => TDATA_destreplace,
        TVALID_core_s => TVALID_destreplace,
        TREADY_core_s => TREADY_destreplace,
        TDEST_core_s  => TDEST_destreplace,
        TUSER_core_s  => TUSER_destreplace,
        TLAST_core_s  => TLAST_destreplace,
        
        TDATA_core_m  => TDATA_regfilter, 
        TVALID_core_m => TVALID_regfilter,
        TREADY_core_m => TREADY_regfilter,
        TDEST_core_m  => TDEST_regfilter,
        TUSER_core_m  => TUSER_regfilter,
        TLAST_core_m  => TLAST_regfilter,
        
        TDATA_ext_s  => TDATA_ext_s,
        TVALID_ext_s => TVALID_ext_s,
        TREADY_ext_s => TREADY_ext_s,
        TDEST_ext_s  => TDEST_ext_s,
        TUSER_ext_s  => TUSER_ext_s,
        TLAST_ext_s  => TLAST_ext_s,
        
        TDATA_ext_m  => TDATA_ext_m,
        TVALID_ext_m => TVALID_ext_m,
        TREADY_ext_m => TREADY_ext_m,
        TDEST_ext_m  => TDEST_ext_m,
        TUSER_ext_m  => TUSER_ext_m,
        TLAST_ext_m  => TLAST_ext_m
    );

end Behavioral;
library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
	use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity load_store_system is
port (
    ap_clk : in std_logic;
	rst_n : in std_logic;

    stream_debug_port_s_tuples  : in tuple_vec(4-1 downto 0);
    stream_debug_port_s_status  : in stream_status;
	stream_debug_port_s_ready   : out std_logic;
    stream_debug_port_m_tuples  : out tuple_vec(4-1 downto 0);
    stream_debug_port_m_status  : out stream_status;
	stream_debug_port_m_ready   : in std_logic;

    interrupt : out std_logic;
    s_axi_AWADDR : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    s_axi_AWVALID : IN STD_LOGIC;
    s_axi_AWREADY : OUT STD_LOGIC;
    s_axi_WDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_WSTRB : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_WVALID : IN STD_LOGIC;
    s_axi_WREADY : OUT STD_LOGIC;
    s_axi_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_BVALID : OUT STD_LOGIC;
    s_axi_BREADY : IN STD_LOGIC;
    s_axi_ARADDR : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    s_axi_ARVALID : IN STD_LOGIC;
    s_axi_ARREADY : OUT STD_LOGIC;
    s_axi_RDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_RVALID : OUT STD_LOGIC;
    s_axi_RREADY : IN STD_LOGIC;

    m_axi_store_AWADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_store_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_store_AWSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_store_AWBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_store_AWLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_store_AWCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_store_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_store_AWVALID : OUT STD_LOGIC;
    m_axi_store_AWREADY : IN STD_LOGIC;
    m_axi_store_WDATA : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
    m_axi_store_WSTRB : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_store_WLAST : OUT STD_LOGIC;
    m_axi_store_WVALID : OUT STD_LOGIC;
    m_axi_store_WREADY : IN STD_LOGIC;
    m_axi_store_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_store_BVALID : IN STD_LOGIC;
    m_axi_store_BREADY : OUT STD_LOGIC;
    m_axi_store_ARADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_store_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_store_ARSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_store_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_store_ARLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_store_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_store_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_store_ARVALID : OUT STD_LOGIC;
    m_axi_store_ARREADY : IN STD_LOGIC;
    m_axi_store_RDATA : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    m_axi_store_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_store_RLAST : IN STD_LOGIC;
    m_axi_store_RVALID : IN STD_LOGIC;
    m_axi_store_RREADY : OUT STD_LOGIC;

    m_axi_loader_AWADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_loader_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_loader_AWSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_loader_AWBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_loader_AWLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_loader_AWCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_loader_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_loader_AWVALID : OUT STD_LOGIC;
    m_axi_loader_AWREADY : IN STD_LOGIC;
    m_axi_loader_WDATA : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
    m_axi_loader_WSTRB : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_loader_WLAST : OUT STD_LOGIC;
    m_axi_loader_WVALID : OUT STD_LOGIC;
    m_axi_loader_WREADY : IN STD_LOGIC;
    m_axi_loader_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_loader_BVALID : IN STD_LOGIC;
    m_axi_loader_BREADY : OUT STD_LOGIC;
    m_axi_loader_ARADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_loader_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_loader_ARSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_loader_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_loader_ARLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_loader_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_loader_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_loader_ARVALID : OUT STD_LOGIC;
    m_axi_loader_ARREADY : IN STD_LOGIC;
    m_axi_loader_RDATA : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    m_axi_loader_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_loader_RLAST : IN STD_LOGIC;
    m_axi_loader_RVALID : IN STD_LOGIC;
    m_axi_loader_RREADY : OUT STD_LOGIC
);
end load_store_system;

architecture Behavioral of load_store_system is

	constant TUPPLE_COUNT : natural := 4;
	
    constant SWITCH_PORT_CNT : natural := 4;
	constant CDEST_PARSE_OFFSET : natural := 4;
	constant CDEST_PARSE_LENGTH : natural := 4;
	constant GATEWAY_ADDR_OFFSET : natural := 8;
	constant GATEWAY_ADDR_LENGTH : natural := 4;
	constant SUBNET_IDENTITY     : natural := 0;
	constant ENABLE_INTERNETWORK_ROUTING : boolean := false;
    
    type sim_stream_group is record
        tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
        status  : stream_status;
    end record;
    type sim_stream_group_vec is array (natural range <>) of sim_stream_group;

    signal sw_stream_s_blob  : sim_stream_group_vec(SWITCH_PORT_CNT-1 downto 0);
    signal sw_stream_s_ready : slv(SWITCH_PORT_CNT-1 downto 0);

    signal sw_stream_m_blob  : sim_stream_group_vec(SWITCH_PORT_CNT-1 downto 0);
    signal sw_stream_m_ready : slv(SWITCH_PORT_CNT-1 downto 0);
begin

    sw_stream_s_blob(0).tuples <= stream_debug_port_s_tuples;
    sw_stream_s_blob(0).status <= stream_debug_port_s_status;  
	stream_debug_port_s_ready  <= sw_stream_s_ready(0);
	   
    stream_debug_port_m_tuples <= sw_stream_m_blob(0).tuples;
    stream_debug_port_m_status <= sw_stream_m_blob(0).status;
	sw_stream_m_ready(0)       <= stream_debug_port_m_ready;

    config: entity libramen.axi4lite_conf_st_unit
    port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
    
        stream_s_tuples  => sw_stream_m_blob(3).tuples,
        stream_s_status  => sw_stream_m_blob(3).status,
        stream_s_ready   => sw_stream_m_ready(3),
        
        stream_m_tuples  => sw_stream_s_blob(3).tuples,
        stream_m_status  => sw_stream_s_blob(3).status,
        stream_m_ready   => sw_stream_s_ready(3),
        
        interrupt => interrupt,
        
        s_axi_AWADDR => s_axi_AWADDR,
        s_axi_AWVALID => s_axi_AWVALID,
        s_axi_AWREADY => s_axi_AWREADY,
        s_axi_WDATA => s_axi_WDATA,
        s_axi_WSTRB => s_axi_WSTRB,
        s_axi_WVALID => s_axi_WVALID,
        s_axi_WREADY => s_axi_WREADY,
        s_axi_BRESP => s_axi_BRESP,
        s_axi_BVALID => s_axi_BVALID,
        s_axi_BREADY => s_axi_BREADY,
        s_axi_ARADDR => s_axi_ARADDR,
        s_axi_ARVALID => s_axi_ARVALID,
        s_axi_ARREADY => s_axi_ARREADY,
        s_axi_RDATA => s_axi_RDATA,
        s_axi_RRESP => s_axi_RRESP,
        s_axi_RVALID => s_axi_RVALID,
        s_axi_RREADY => s_axi_RREADY
    );

    store: entity libramen.store_st_unit
    generic map (
        VIRTUAL_PORT_CNT_LOG2 => 4,
        
        --IN/OUT fifo parameters  
        MEMORY_DEPTH_LOG2_INPUT => 6,
        ALMOST_FULL_LEVEL_INPUT => 8,
        MEMORY_TYPE_INPUT => "ultra"
    ) port map (
    
        ap_clk => ap_clk,
        rst_n => rst_n,
    
        stream_s_tuples  => sw_stream_m_blob(2).tuples,
        stream_s_status  => sw_stream_m_blob(2).status,
        stream_s_ready   => sw_stream_m_ready(2),
        
        stream_m_tuples  => sw_stream_s_blob(2).tuples,
        stream_m_status  => sw_stream_s_blob(2).status,
        stream_m_ready   => sw_stream_s_ready(2),
        
        m_axi_AWADDR  => m_axi_store_AWADDR,
        m_axi_AWLEN   => m_axi_store_AWLEN,
        m_axi_AWSIZE  => m_axi_store_AWSIZE,
        m_axi_AWBURST => m_axi_store_AWBURST, 
        m_axi_AWLOCK  => m_axi_store_AWLOCK,
        m_axi_AWCACHE => m_axi_store_AWCACHE,
        m_axi_AWPROT  => m_axi_store_AWPROT,
        m_axi_AWVALID => m_axi_store_AWVALID,
        m_axi_AWREADY => m_axi_store_AWREADY,
        m_axi_WDATA   => m_axi_store_WDATA,
        m_axi_WSTRB   => m_axi_store_WSTRB,
        m_axi_WLAST   => m_axi_store_WLAST,
        m_axi_WVALID  => m_axi_store_WVALID,
        m_axi_WREADY  => m_axi_store_WREADY,
        m_axi_BRESP   => m_axi_store_BRESP,
        m_axi_BVALID  => m_axi_store_BVALID,
        m_axi_BREADY  => m_axi_store_BREADY,
        m_axi_ARADDR  => m_axi_store_ARADDR,
        m_axi_ARLEN   => m_axi_store_ARLEN,
        m_axi_ARSIZE  => m_axi_store_ARSIZE,
        m_axi_ARBURST => m_axi_store_ARBURST,
        m_axi_ARLOCK  => m_axi_store_ARLOCK,
        m_axi_ARCACHE => m_axi_store_ARCACHE,
        m_axi_ARPROT  => m_axi_store_ARPROT,
        m_axi_ARVALID => m_axi_store_ARVALID,
        m_axi_ARREADY => m_axi_store_ARREADY,
        m_axi_RDATA   => m_axi_store_RDATA,
        m_axi_RRESP   => m_axi_store_RRESP,
        m_axi_RLAST   => m_axi_store_RLAST,
        m_axi_RVALID  => m_axi_store_RVALID,
        m_axi_RREADY  => m_axi_store_RREADY
    );

    loader: entity libramen.loader_st_unit
    generic map (
        VIRTUAL_PORT_CNT_LOG2 => 4,
        
        --IN/OUT fifo parameters  
        MEMORY_DEPTH_LOG2_OUTPUT => 6,
        ALMOST_FULL_LEVEL_OUTPUT => 8,
        MEMORY_TYPE_OUTPUT => "ultra"
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
    
        stream_s_tuples  => sw_stream_m_blob(1).tuples,
        stream_s_status  => sw_stream_m_blob(1).status,
        stream_s_ready   => sw_stream_m_ready(1),
        
        stream_m_tuples  => sw_stream_s_blob(1).tuples,
        stream_m_status  => sw_stream_s_blob(1).status,
        stream_m_ready   => sw_stream_s_ready(1),
        
        m_axi_AWADDR  => m_axi_loader_AWADDR,
        m_axi_AWLEN   => m_axi_loader_AWLEN,
        m_axi_AWSIZE  => m_axi_loader_AWSIZE,
        m_axi_AWBURST => m_axi_loader_AWBURST,
        m_axi_AWLOCK  => m_axi_loader_AWLOCK,
        m_axi_AWCACHE => m_axi_loader_AWCACHE,
        m_axi_AWPROT  => m_axi_loader_AWPROT,
        m_axi_AWVALID => m_axi_loader_AWVALID,
        m_axi_AWREADY => m_axi_loader_AWREADY,
        m_axi_WDATA   => m_axi_loader_WDATA,
        m_axi_WSTRB   => m_axi_loader_WSTRB,
        m_axi_WLAST   => m_axi_loader_WLAST,
        m_axi_WVALID  => m_axi_loader_WVALID,
        m_axi_WREADY  => m_axi_loader_WREADY,
        m_axi_BRESP   => m_axi_loader_BRESP,
        m_axi_BVALID  => m_axi_loader_BVALID,
        m_axi_BREADY  => m_axi_loader_BREADY,
        m_axi_ARADDR  => m_axi_loader_ARADDR,
        m_axi_ARLEN   => m_axi_loader_ARLEN,
        m_axi_ARSIZE  => m_axi_loader_ARSIZE,
        m_axi_ARBURST => m_axi_loader_ARBURST,
        m_axi_ARLOCK  => m_axi_loader_ARLOCK,
        m_axi_ARCACHE => m_axi_loader_ARCACHE,
        m_axi_ARPROT  => m_axi_loader_ARPROT,
        m_axi_ARVALID => m_axi_loader_ARVALID,
        m_axi_ARREADY => m_axi_loader_ARREADY,
        m_axi_RDATA   => m_axi_loader_RDATA,
        m_axi_RRESP   => m_axi_loader_RRESP,
        m_axi_RLAST   => m_axi_loader_RLAST,
        m_axi_RVALID  => m_axi_loader_RVALID,
        m_axi_RREADY  => m_axi_loader_RREADY
    );

    switch: entity libramen.switch
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT, 
        INPORT_CNT   => SWITCH_PORT_CNT,
        OUTPORT_CNT  => SWITCH_PORT_CNT,
        CDEST_PARSE_OFFSET => CDEST_PARSE_OFFSET,
        CDEST_PARSE_LENGTH => CDEST_PARSE_LENGTH,
        GATEWAY_ADDR_OFFSET => GATEWAY_ADDR_OFFSET,
        GATEWAY_ADDR_LENGTH => GATEWAY_ADDR_LENGTH,
        SUBNET_IDENTITY     => SUBNET_IDENTITY,
        ENABLE_INTERNETWORK_ROUTING => ENABLE_INTERNETWORK_ROUTING,
        CONNECTION_MATRIX => (others => '1')
    ) port map (
        clk => ap_clk,
        rstn => rst_n,
    
        stream_s_tuples(1*TUPPLE_COUNT-1 downto 0*TUPPLE_COUNT) => sw_stream_s_blob(0).tuples,
        stream_s_tuples(2*TUPPLE_COUNT-1 downto 1*TUPPLE_COUNT) => sw_stream_s_blob(1).tuples,
        stream_s_tuples(3*TUPPLE_COUNT-1 downto 2*TUPPLE_COUNT) => sw_stream_s_blob(2).tuples,
        stream_s_tuples(4*TUPPLE_COUNT-1 downto 3*TUPPLE_COUNT) => sw_stream_s_blob(3).tuples,
        stream_s_status(0) => sw_stream_s_blob(0).status,
        stream_s_status(1) => sw_stream_s_blob(1).status,
        stream_s_status(2) => sw_stream_s_blob(2).status,
        stream_s_status(3) => sw_stream_s_blob(3).status,
        stream_s_ready   => sw_stream_s_ready,
        
        stream_m_tuples(1*TUPPLE_COUNT-1 downto 0*TUPPLE_COUNT) => sw_stream_m_blob(0).tuples,
        stream_m_tuples(2*TUPPLE_COUNT-1 downto 1*TUPPLE_COUNT) => sw_stream_m_blob(1).tuples,
        stream_m_tuples(3*TUPPLE_COUNT-1 downto 2*TUPPLE_COUNT) => sw_stream_m_blob(2).tuples,
        stream_m_tuples(4*TUPPLE_COUNT-1 downto 3*TUPPLE_COUNT) => sw_stream_m_blob(3).tuples,
        stream_m_status(0) => sw_stream_m_blob(0).status,
        stream_m_status(1) => sw_stream_m_blob(1).status,
        stream_m_status(2) => sw_stream_m_blob(2).status,
        stream_m_status(3) => sw_stream_m_blob(3).status,
        stream_m_ready   => sw_stream_m_ready
    );

end Behavioral;
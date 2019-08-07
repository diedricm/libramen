library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity vaxis_aximm_loader_unit is
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	TDATA_s  : in std_logic_vector((TDATA_SINGLE_SIZE_IN_BYTES*8)-1 downto 0);
	TVALID_s : in std_logic;
	TREADY_s : out std_logic;
	TDEST_s  : in std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
	TUSER_s  : in std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_s  : in std_logic;
	
	TDATA_m  : out std_logic_vector((TDATA_QUAD_SIZE_IN_BYTES*8)-1 downto 0);
	TVALID_m : out std_logic;
	TREADY_m : in std_logic;
	TDEST_m  : out std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
	TUSER_m  : out std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
	TLAST_m  : out std_logic;
	
	--AXI4-MM-master
	--Write addr chan
    m_aximm_rdonly_awaddr  : out std_logic_vector(64-1 downto 0);
    m_aximm_rdonly_awvalid : out std_logic;
    m_aximm_rdonly_awlen   : out std_logic_vector(8-1 downto 0);
    m_aximm_rdonly_awready : in std_logic;
    --Write data chan
    m_aximm_rdonly_wdata   : out std_logic_vector(512-1 downto 0);
    m_aximm_rdonly_wstrb   : out std_logic_vector(512/8-1 downto 0);
    m_aximm_rdonly_wlast   : out std_logic;
    m_aximm_rdonly_wvalid  : out std_logic;
    m_aximm_rdonly_wready  : in std_logic;
    --Status chan
    m_aximm_rdonly_bvalid  : in std_logic;
    m_aximm_rdonly_bready  : out std_logic;
    --Read addr chan 
    m_aximm_rdonly_araddr  : out std_logic_vector(64-1 downto 0);
    m_aximm_rdonly_arlen   : out std_logic_vector(8-1 downto 0);
    m_aximm_rdonly_arvalid : out std_logic;
    m_aximm_rdonly_arready : in std_logic;
    --Read data chan
    m_aximm_rdonly_rdata   : in std_logic_vector(64-1 downto 0); 
    m_aximm_rdonly_rlast   : in std_logic;
    m_aximm_rdonly_rvalid  : in std_logic;
    m_aximm_rdonly_rready  : out std_logic
	
);
end vaxis_aximm_loader_unit;

architecture Behavioral of vaxis_aximm_loader_unit is
	ATTRIBUTE X_INTERFACE_INFO : STRING;
	ATTRIBUTE X_INTERFACE_INFO of TDEST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDEST";
	ATTRIBUTE X_INTERFACE_INFO of TDATA_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDATA";
	ATTRIBUTE X_INTERFACE_INFO of TLAST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TLAST";
	ATTRIBUTE X_INTERFACE_INFO of TUSER_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TUSER";
	ATTRIBUTE X_INTERFACE_INFO of TVALID_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TVALID";
	ATTRIBUTE X_INTERFACE_INFO of TREADY_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TREADY";
	ATTRIBUTE X_INTERFACE_INFO of TDEST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDEST";
	ATTRIBUTE X_INTERFACE_INFO of TDATA_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDATA";
	ATTRIBUTE X_INTERFACE_INFO of TLAST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TLAST";
	ATTRIBUTE X_INTERFACE_INFO of TUSER_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TUSER";
	ATTRIBUTE X_INTERFACE_INFO of TVALID_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TVALID";
	ATTRIBUTE X_INTERFACE_INFO of TREADY_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_awaddr	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly AWADDR";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_awlen	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly AWLEN";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_awvalid	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly AWVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_awready	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly AWREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_wdata	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly WDATA";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_wstrb	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly WSTRB";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_wlast	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly WLAST";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_wvalid	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly WVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_wready	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly WREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_bvalid	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly BVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_bready	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly BREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_araddr	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly ARADDR";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_arvalid	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly ARVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_arready	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly ARREADY";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_arlen	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly ARLEN";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_rdata	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly RDATA";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_rlast	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly RLAST";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_rvalid	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly RVALID";
    ATTRIBUTE X_INTERFACE_INFO of m_aximm_rdonly_rready	: SIGNAL is "xilinx.com:interface:aximm:1.0 m_aximm_rdonly RREADY";

    component aximm_vaxis_loader_unit_0 is
    Port ( 
        ap_clk : in STD_LOGIC;
        ap_rst_n : in STD_LOGIC;
        m_axi_aximem_V_AWADDR : out STD_LOGIC_VECTOR ( 63 downto 0 );
        m_axi_aximem_V_AWLEN : out STD_LOGIC_VECTOR ( 7 downto 0 );
        m_axi_aximem_V_AWSIZE : out STD_LOGIC_VECTOR ( 2 downto 0 );
        m_axi_aximem_V_AWBURST : out STD_LOGIC_VECTOR ( 1 downto 0 );
        m_axi_aximem_V_AWLOCK : out STD_LOGIC_VECTOR ( 1 downto 0 );
        m_axi_aximem_V_AWREGION : out STD_LOGIC_VECTOR ( 3 downto 0 );
        m_axi_aximem_V_AWCACHE : out STD_LOGIC_VECTOR ( 3 downto 0 );
        m_axi_aximem_V_AWPROT : out STD_LOGIC_VECTOR ( 2 downto 0 );
        m_axi_aximem_V_AWQOS : out STD_LOGIC_VECTOR ( 3 downto 0 );
        m_axi_aximem_V_AWVALID : out STD_LOGIC;
        m_axi_aximem_V_AWREADY : in STD_LOGIC;
        m_axi_aximem_V_WDATA : out STD_LOGIC_VECTOR ( 511 downto 0 );
        m_axi_aximem_V_WSTRB : out STD_LOGIC_VECTOR ( 63 downto 0 );
        m_axi_aximem_V_WLAST : out STD_LOGIC;
        m_axi_aximem_V_WVALID : out STD_LOGIC;
        m_axi_aximem_V_WREADY : in STD_LOGIC;
        m_axi_aximem_V_BRESP : in STD_LOGIC_VECTOR ( 1 downto 0 );
        m_axi_aximem_V_BVALID : in STD_LOGIC;
        m_axi_aximem_V_BREADY : out STD_LOGIC;
        m_axi_aximem_V_ARADDR : out STD_LOGIC_VECTOR ( 63 downto 0 );
        m_axi_aximem_V_ARLEN : out STD_LOGIC_VECTOR ( 7 downto 0 );
        m_axi_aximem_V_ARSIZE : out STD_LOGIC_VECTOR ( 2 downto 0 );
        m_axi_aximem_V_ARBURST : out STD_LOGIC_VECTOR ( 1 downto 0 );
        m_axi_aximem_V_ARLOCK : out STD_LOGIC_VECTOR ( 1 downto 0 );
        m_axi_aximem_V_ARREGION : out STD_LOGIC_VECTOR ( 3 downto 0 );
        m_axi_aximem_V_ARCACHE : out STD_LOGIC_VECTOR ( 3 downto 0 );
        m_axi_aximem_V_ARPROT : out STD_LOGIC_VECTOR ( 2 downto 0 );
        m_axi_aximem_V_ARQOS : out STD_LOGIC_VECTOR ( 3 downto 0 );
        m_axi_aximem_V_ARVALID : out STD_LOGIC;
        m_axi_aximem_V_ARREADY : in STD_LOGIC;
        m_axi_aximem_V_RDATA : in STD_LOGIC_VECTOR ( 511 downto 0 );
        m_axi_aximem_V_RRESP : in STD_LOGIC_VECTOR ( 1 downto 0 );
        m_axi_aximem_V_RLAST : in STD_LOGIC;
        m_axi_aximem_V_RVALID : in STD_LOGIC;
        m_axi_aximem_V_RREADY : out STD_LOGIC;
        config_in_TVALID : in STD_LOGIC;
        config_in_TREADY : out STD_LOGIC;
        config_in_TDATA : in STD_LOGIC_VECTOR ( 95 downto 0 );
        config_in_TLAST : in STD_LOGIC_VECTOR ( 0 to 0 );
        config_in_TUSER : in STD_LOGIC_VECTOR ( 2 downto 0 );
        config_in_TDEST : in STD_LOGIC_VECTOR ( 13 downto 0 );
        credit_counters_V : in STD_LOGIC_VECTOR ( 143 downto 0 );
        output_r_TVALID : out STD_LOGIC;
        output_r_TREADY : in STD_LOGIC;
        output_r_TDATA : out STD_LOGIC_VECTOR ( 383 downto 0 );
        output_r_TLAST : out STD_LOGIC_VECTOR ( 0 to 0 );
        output_r_TUSER : out STD_LOGIC_VECTOR ( 6 downto 0 );
        output_r_TDEST : out STD_LOGIC_VECTOR ( 13 downto 0 )
    );
    end component;

    constant VIRTUAL_PORT_CNT_LOG2 : natural := 4;
    constant MEMORY_DEPTH_LOG2 : natural := 9;
    
    signal credits_list_out : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2-1 downto 0);

	signal TPAYLOAD : vaxis_quad_ext;
    signal TREADY_forward : std_logic;
begin
    
    loader_core: aximm_vaxis_loader_unit_0
    port map (
        ap_clk => ap_clk,
        ap_rst_n => rst_n,
        
        credit_counters_V => credits_list_out,
        
        m_axi_aximem_V_AWADDR	=> m_aximm_rdonly_AWADDR,
        m_axi_aximem_V_AWLEN	=> m_aximm_rdonly_AWLEN,
        m_axi_aximem_V_AWSIZE	=> OPEN,
        m_axi_aximem_V_AWBURST	=> OPEN,
        m_axi_aximem_V_AWLOCK	=> OPEN,
        m_axi_aximem_V_AWREGION	=> OPEN,
        m_axi_aximem_V_AWCACHE	=> OPEN,
        m_axi_aximem_V_AWPROT	=> OPEN,
        m_axi_aximem_V_AWQOS	=> OPEN,
        m_axi_aximem_V_AWVALID	=> m_aximm_rdonly_AWVALID,
        m_axi_aximem_V_AWREADY	=> m_aximm_rdonly_AWREADY,
        
        m_axi_aximem_V_WDATA	=> m_aximm_rdonly_WDATA,
        m_axi_aximem_V_WSTRB	=> m_aximm_rdonly_WSTRB,
        m_axi_aximem_V_WLAST	=> m_aximm_rdonly_WLAST,
        m_axi_aximem_V_WVALID	=> m_aximm_rdonly_WVALID,
        m_axi_aximem_V_WREADY	=> m_aximm_rdonly_WREADY,
        
        m_axi_aximem_V_BRESP	=> (others => '0'),
        m_axi_aximem_V_BVALID	=> m_aximm_rdonly_BVALID,
        m_axi_aximem_V_BREADY	=> m_aximm_rdonly_BREADY,
        
        m_axi_aximem_V_ARADDR	=> m_aximm_rdonly_ARADDR,
        m_axi_aximem_V_ARLEN	=> m_aximm_rdonly_ARLEN,
        m_axi_aximem_V_ARSIZE	=> OPEN,
        m_axi_aximem_V_ARBURST	=> OPEN,
        m_axi_aximem_V_ARLOCK	=> OPEN,
        m_axi_aximem_V_ARREGION	=> OPEN,
        m_axi_aximem_V_ARCACHE	=> OPEN,
        m_axi_aximem_V_ARPROT	=> OPEN,
        m_axi_aximem_V_ARQOS	=> OPEN,
        m_axi_aximem_V_ARVALID	=> m_aximm_rdonly_ARVALID,
        m_axi_aximem_V_ARREADY	=> m_aximm_rdonly_ARREADY,
        
        m_axi_aximem_V_RDATA	=> m_aximm_rdonly_RDATA,
        m_axi_aximem_V_RRESP	=> (others => '0'),
        m_axi_aximem_V_RLAST	=> m_aximm_rdonly_RLAST,
        m_axi_aximem_V_RVALID	=> m_aximm_rdonly_RVALID,
        m_axi_aximem_V_RREADY	=> m_aximm_rdonly_RREADY,
        
        config_in_TVALID    => TVALID_s,
        config_in_TREADY    => TREADY_s,
        config_in_TDATA     => TDATA_s,
        config_in_TLAST(0)   => TLAST_s,
        config_in_TUSER     => TUSER_s,
        config_in_TDEST     => TDEST_s,
        
        output_r_TVALID     => TPAYLOAD.TVALID,
        output_r_TREADY     => TREADY_forward,
        output_r_TDATA      => TPAYLOAD.TDATA,
        output_r_TLAST(0)   => TPAYLOAD.TLAST,
        output_r_TUSER      => TPAYLOAD.TUSER,
        output_r_TDEST      => TPAYLOAD.TDEST
    );
    
    fifo_core: entity vaxis.vaxis_multiport_fifo_round_robin
    generic map (
        TDATA_WIDTH => TDATA_QUAD_SIZE_IN_BYTES,
        TDEST_WIDTH => TDEST_SIZE_IN_BIT,
        TUSER_WIDTH => TUSER_SIZE_IN_BIT,
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2 => MEMORY_DEPTH_LOG2,
        MEMORY_TYPE => "ultra"
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out => credits_list_out,
        
        TDATA_s  => TPAYLOAD.TDATA,
        TVALID_s => TPAYLOAD.TVALID,
        TREADY_s => TREADY_forward,
        TDEST_s  => TPAYLOAD.TDEST,
        TUSER_s  => TPAYLOAD.TUSER(2 downto 0),
        TLAST_s  => TPAYLOAD.TLAST,
        fifo_port_dest => TPAYLOAD.TUSER(6 downto 3),
        
        TDATA_m  => TDATA_m,
        TVALID_m => TVALID_m,
        TREADY_m => TREADY_m,
        TDEST_m  => TDEST_m,
        TUSER_m  => TUSER_m,
        TLAST_m  => TLAST_m
    );

end Behavioral;
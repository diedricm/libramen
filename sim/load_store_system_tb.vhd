library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
	use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity load_store_system_tb is
end load_store_system_tb;

architecture Behavioral of load_store_system_tb is
 
    constant clock_period : time := 2ns;    
    signal ap_clk : std_logic := '1';
	signal rst_n : std_logic := '0';

    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec);

    signal stream_debug_port_s_tuples  : tuple_vec(4-1 downto 0);
    signal stream_debug_port_s_status  : stream_status;
    signal stream_debug_port_s_ready   : std_logic;
    signal stream_debug_port_m_tuples  : tuple_vec(4-1 downto 0);
    signal stream_debug_port_m_status  : stream_status;
    signal stream_debug_port_m_ready   : std_logic;

    signal m_axi_store_AWADDR : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axi_store_AWLEN : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal m_axi_store_AWSIZE : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_store_AWBURST : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_store_AWLOCK : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_store_AWCACHE : STD_LOGIC_VECTOR(3 DOWNTO 0);
    signal m_axi_store_AWPROT : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_store_AWVALID : STD_LOGIC;
    signal m_axi_store_AWREADY : STD_LOGIC;
    signal m_axi_store_WDATA : STD_LOGIC_VECTOR(511 DOWNTO 0);
    signal m_axi_store_WSTRB : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axi_store_WLAST : STD_LOGIC;
    signal m_axi_store_WVALID : STD_LOGIC;
    signal m_axi_store_WREADY : STD_LOGIC;
    signal m_axi_store_BRESP : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_store_BVALID : STD_LOGIC;
    signal m_axi_store_BREADY : STD_LOGIC;
    signal m_axi_store_ARADDR : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axi_store_ARLEN : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal m_axi_store_ARSIZE : STD_LOGIC_VECTOR(2 DOWNTO 0);    
    signal m_axi_store_ARBURST : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_store_ARLOCK : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_store_ARCACHE : STD_LOGIC_VECTOR(3 DOWNTO 0);
    signal m_axi_store_ARPROT : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_store_ARVALID : STD_LOGIC;
    signal m_axi_store_ARREADY : STD_LOGIC;
    signal m_axi_store_RDATA : STD_LOGIC_VECTOR(511 DOWNTO 0);
    signal m_axi_store_RRESP : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_store_RLAST : STD_LOGIC;
    signal m_axi_store_RVALID : STD_LOGIC;
    signal m_axi_store_RREADY : STD_LOGIC;

    signal m_axi_loader_AWADDR : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axi_loader_AWLEN : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal m_axi_loader_AWSIZE : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_loader_AWBURST : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_loader_AWLOCK : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_loader_AWCACHE : STD_LOGIC_VECTOR(3 DOWNTO 0);
    signal m_axi_loader_AWPROT : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_loader_AWVALID : STD_LOGIC;
    signal m_axi_loader_AWREADY : STD_LOGIC;
    signal m_axi_loader_WDATA : STD_LOGIC_VECTOR(511 DOWNTO 0);
    signal m_axi_loader_WSTRB : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axi_loader_WLAST : STD_LOGIC;
    signal m_axi_loader_WVALID : STD_LOGIC;
    signal m_axi_loader_WREADY : STD_LOGIC;
    signal m_axi_loader_BRESP : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_loader_BVALID : STD_LOGIC;
    signal m_axi_loader_BREADY : STD_LOGIC;
    signal m_axi_loader_ARADDR : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal m_axi_loader_ARLEN : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal m_axi_loader_ARSIZE : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_loader_ARBURST : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_loader_ARLOCK : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_loader_ARCACHE : STD_LOGIC_VECTOR(3 DOWNTO 0);
    signal m_axi_loader_ARPROT : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal m_axi_loader_ARVALID : STD_LOGIC;
    signal m_axi_loader_ARREADY : STD_LOGIC;
    signal m_axi_loader_RDATA : STD_LOGIC_VECTOR(511 DOWNTO 0);
    signal m_axi_loader_RRESP : STD_LOGIC_VECTOR(1 DOWNTO 0);
    signal m_axi_loader_RLAST : STD_LOGIC;
    signal m_axi_loader_RVALID : STD_LOGIC;
    signal m_axi_loader_RREADY : STD_LOGIC;
begin

    ap_clk <= NOT ap_clk after clock_period/2;
    rst_n <= '1' after clock_period*100;

    rand_vec <= step(rand_spec, rand_vec) after clock_period;

    stream_debug_port_m_ready <= '1';
    system_setup: entity libramen.fixed_configuration_controller
    generic map (
        INSTR_LIST => (
                        0*16+0, 0,    42, --Test switch
                        
                        2*16+1, (2**16)*1+5,  1024, --store ch1, REQ_TAG_HIGH_REG_ADDR
                        2*16+1, (2**16)*1+4,     0, --store ch1, REQ_TAG_INDEX_REG_ADDR
                        2*16+1, (2**16)*1+3, 64*64, --store ch1, BUFFER_BASE_REG_ADDR, @block 64
                        2*16+1, (2**16)*1+1,     0, --store ch1, RETURN_DEST_REG_ADDR
                        2*16+1, (2**16)*1+0,     1, --store ch1, START_REG_ADDR
                        
                        2*16+0, (2**16)*0+5,   128, --store ch0, REQ_TAG_HIGH_REG_ADDR
                        2*16+0, (2**16)*0+4,     0, --store ch0, REQ_TAG_INDEX_REG_ADDR
                        2*16+0, (2**16)*0+3, 32*64, --store ch0, BUFFER_BASE_REG_ADDR, @block 32
                        2*16+0, (2**16)*0+1,     0, --store ch0, RETURN_DEST_REG_ADDR
                        2*16+0, (2**16)*0+0,     2, --store ch0, START_REG_ADDR
                        
                        1*16+3, 5,   704, --load ch3, REQ_TAG_HIGH_REG_ADDR 
                        1*16+3, 4,     0, --load ch3, REQ_TAG_INDEX_REG_ADDR
                        1*16+3, 3,128*64, --load ch3, BUFFER_BASE_REG_ADDR @block 128
                        1*16+3, 2,2*16+1, --load ch3, FWD_DEST_REG_ADDR store ch1
                        1*16+3, 1,     0, --load ch3, RETURN_DEST_REG_ADDR
                        1*16+3, 0,     3, --load ch3, START_REG_ADDR

                        1*16+4, 5,   152, --load ch4, REQ_TAG_HIGH_REG_ADDR 
                        1*16+4, 4,     0, --load ch4, REQ_TAG_INDEX_REG_ADDR
                        1*16+4, 3,     0, --load ch4, BUFFER_BASE_REG_ADDR @block 0
                        1*16+4, 2,2*16+0, --load ch4, FWD_DEST_REG_ADDR store ch0
                        1*16+4, 1,     0, --load ch4, RETURN_DEST_REG_ADDR
                        1*16+4, 0,     4  --load ch4, START_REG_ADDR                        
                      )
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        finished => OPEN,
        
        stream_m_tuples(0) => stream_debug_port_s_tuples(0),
        stream_m_status => stream_debug_port_s_status,
        stream_m_ready  => stream_debug_port_s_ready
    );
    
    storemembank: entity libramen.axi_sim_mem_slave
    Port map (
        s_axi_aclk => ap_clk,
        s_axi_aresetn => rst_n,
        
        s_axi_awaddr  => m_axi_store_awaddr(16 downto 0) ,
        s_axi_awlen   => m_axi_store_awlen  ,
        s_axi_awsize  => m_axi_store_awsize ,
        s_axi_awburst => m_axi_store_awburst,
        s_axi_awlock  => '0' ,
        s_axi_awcache => m_axi_store_awcache,
        s_axi_awprot  => m_axi_store_awprot ,
        s_axi_awvalid => m_axi_store_awvalid,
        s_axi_awready => m_axi_store_awready,
        s_axi_wdata   => m_axi_store_wdata  ,
        s_axi_wstrb   => m_axi_store_wstrb  ,
        s_axi_wlast   => m_axi_store_wlast  ,
        s_axi_wvalid  => m_axi_store_wvalid ,
        s_axi_wready  => m_axi_store_wready ,
        s_axi_bresp   => m_axi_store_bresp  ,
        s_axi_bvalid  => m_axi_store_bvalid ,
        s_axi_bready  => m_axi_store_bready ,
        s_axi_araddr  => m_axi_store_araddr(16 downto 0) ,
        s_axi_arlen   => m_axi_store_arlen  ,
        s_axi_arsize  => m_axi_store_arsize ,
        s_axi_arburst => m_axi_store_arburst,
        s_axi_arlock  => '0' ,
        s_axi_arcache => m_axi_store_arcache,
        s_axi_arprot  => m_axi_store_arprot ,
        s_axi_arvalid => m_axi_store_arvalid,
        s_axi_arready => m_axi_store_arready,
        s_axi_rdata   => m_axi_store_rdata  ,
        s_axi_rresp   => m_axi_store_rresp  ,
        s_axi_rlast   => m_axi_store_rlast  ,
        s_axi_rvalid  => m_axi_store_rvalid ,
        s_axi_rready  => m_axi_store_rready 
    );
    
    loadmembank: entity libramen.axi_sim_mem_slave
    Port map (
        s_axi_aclk => ap_clk,
        s_axi_aresetn => rst_n,
        
        s_axi_awaddr  => m_axi_loader_awaddr(16 downto 0) ,
        s_axi_awlen   => m_axi_loader_awlen  ,
        s_axi_awsize  => m_axi_loader_awsize ,
        s_axi_awburst => m_axi_loader_awburst,
        s_axi_awlock  => '0' ,
        s_axi_awcache => m_axi_loader_awcache,
        s_axi_awprot  => m_axi_loader_awprot ,
        s_axi_awvalid => m_axi_loader_awvalid,
        s_axi_awready => m_axi_loader_awready,
        s_axi_wdata   => m_axi_loader_wdata  ,
        s_axi_wstrb   => m_axi_loader_wstrb  ,
        s_axi_wlast   => m_axi_loader_wlast  ,
        s_axi_wvalid  => m_axi_loader_wvalid ,
        s_axi_wready  => m_axi_loader_wready ,
        s_axi_bresp   => m_axi_loader_bresp  ,
        s_axi_bvalid  => m_axi_loader_bvalid ,
        s_axi_bready  => m_axi_loader_bready ,
        s_axi_araddr  => m_axi_loader_araddr(16 downto 0) ,
        s_axi_arlen   => m_axi_loader_arlen  ,
        s_axi_arsize  => m_axi_loader_arsize ,
        s_axi_arburst => m_axi_loader_arburst,
        s_axi_arlock  => '0' ,
        s_axi_arcache => m_axi_loader_arcache,
        s_axi_arprot  => m_axi_loader_arprot ,
        s_axi_arvalid => m_axi_loader_arvalid,
        s_axi_arready => m_axi_loader_arready,
        s_axi_rdata   => m_axi_loader_rdata  ,
        s_axi_rresp   => m_axi_loader_rresp  ,
        s_axi_rlast   => m_axi_loader_rlast  ,
        s_axi_rvalid  => m_axi_loader_rvalid ,
        s_axi_rready  => m_axi_loader_rready 
    );

    uut: entity libramen.load_store_system
    port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
    
        stream_debug_port_s_tuples  => stream_debug_port_s_tuples,
        stream_debug_port_s_status  => stream_debug_port_s_status,
        stream_debug_port_s_ready   => stream_debug_port_s_ready,
        stream_debug_port_m_tuples  => stream_debug_port_m_tuples,
        stream_debug_port_m_status  => stream_debug_port_m_status,
        stream_debug_port_m_ready   => stream_debug_port_m_ready,
    
        interrupt => OPEN,
        s_axi_AWADDR => (others => '0'),
        s_axi_AWVALID => '0',
        s_axi_AWREADY => OPEN,
        s_axi_WDATA => (others => '0'),
        s_axi_WSTRB => (others => '0'),
        s_axi_WVALID => '0',
        s_axi_WREADY => OPEN,
        s_axi_BRESP => OPEN,
        s_axi_BVALID => OPEN,
        s_axi_BREADY => '0',
        s_axi_ARADDR => (others => '0'),
        s_axi_ARVALID => '0',
        s_axi_ARREADY => OPEN,
        s_axi_RDATA => OPEN,
        s_axi_RRESP => OPEN,
        s_axi_RVALID => OPEN,
        s_axi_RREADY => '0',

        m_axi_store_AWADDR  => m_axi_store_AWADDR,
        m_axi_store_AWLEN   => m_axi_store_AWLEN ,
        m_axi_store_AWSIZE  => m_axi_store_AWSIZE,
        m_axi_store_AWVALID => m_axi_store_AWVALID,
        m_axi_store_AWREADY => m_axi_store_AWREADY,
        m_axi_store_WDATA   => m_axi_store_WDATA,
        m_axi_store_WSTRB   => m_axi_store_WSTRB,
        m_axi_store_WLAST   => m_axi_store_WLAST,
        m_axi_store_WVALID  => m_axi_store_WVALID,
        m_axi_store_WREADY  => m_axi_store_WREADY,
        m_axi_store_BRESP   => m_axi_store_BRESP,
        m_axi_store_BVALID  => m_axi_store_BVALID,
        m_axi_store_BREADY  => m_axi_store_BREADY,
        m_axi_store_ARADDR  => m_axi_store_ARADDR,
        m_axi_store_ARLEN   => m_axi_store_ARLEN,
        m_axi_store_ARSIZE  => m_axi_store_ARSIZE,
        m_axi_store_ARVALID => m_axi_store_ARVALID,
        m_axi_store_ARREADY => m_axi_store_ARREADY,
        m_axi_store_RDATA   => m_axi_store_RDATA,
        m_axi_store_RRESP   => m_axi_store_RRESP,
        m_axi_store_RLAST   => m_axi_store_RLAST,
        m_axi_store_RVALID  => m_axi_store_RVALID,
        m_axi_store_RREADY  => m_axi_store_RREADY,
    
        m_axi_loader_AWADDR  => m_axi_loader_AWADDR,
        m_axi_loader_AWLEN   => m_axi_loader_AWLEN,
        m_axi_loader_AWSIZE  => m_axi_loader_AWSIZE,
        m_axi_loader_AWVALID => m_axi_loader_AWVALID,
        m_axi_loader_AWREADY => m_axi_loader_AWREADY,
        m_axi_loader_WDATA   => m_axi_loader_WDATA,
        m_axi_loader_WSTRB   => m_axi_loader_WSTRB,
        m_axi_loader_WLAST   => m_axi_loader_WLAST,
        m_axi_loader_WVALID  => m_axi_loader_WVALID,
        m_axi_loader_WREADY  => m_axi_loader_WREADY,
        m_axi_loader_BRESP   => m_axi_loader_BRESP,
        m_axi_loader_BVALID  => m_axi_loader_BVALID,
        m_axi_loader_BREADY  => m_axi_loader_BREADY,
        m_axi_loader_ARADDR  => m_axi_loader_ARADDR,
        m_axi_loader_ARLEN   => m_axi_loader_ARLEN,
        m_axi_loader_ARSIZE  => m_axi_loader_ARSIZE,
        m_axi_loader_ARVALID => m_axi_loader_ARVALID,
        m_axi_loader_ARREADY => m_axi_loader_ARREADY,
        m_axi_loader_RDATA   => m_axi_loader_RDATA,
        m_axi_loader_RRESP   => m_axi_loader_RRESP,
        m_axi_loader_RLAST   => m_axi_loader_RLAST,
        m_axi_loader_RVALID  => m_axi_loader_RVALID,
        m_axi_loader_RREADY  => m_axi_loader_RREADY
    );
end Behavioral;

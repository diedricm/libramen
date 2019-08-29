library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity axi_sim_mem_slave is
Port (
    s_axi_aclk : IN STD_LOGIC;
    s_axi_aresetn : IN STD_LOGIC;
    
    s_axi_awaddr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
    s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_awlock : IN STD_LOGIC;
    s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_awvalid : IN STD_LOGIC;
    s_axi_awready : OUT STD_LOGIC;
    s_axi_wdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    s_axi_wstrb : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
    s_axi_wlast : IN STD_LOGIC;
    s_axi_wvalid : IN STD_LOGIC;
    s_axi_wready : OUT STD_LOGIC;
    s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_bvalid : OUT STD_LOGIC;
    s_axi_bready : IN STD_LOGIC;
    s_axi_araddr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
    s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
    s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_arlock : IN STD_LOGIC;
    s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    s_axi_arvalid : IN STD_LOGIC;
    s_axi_arready : OUT STD_LOGIC;
    s_axi_rdata : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
    s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_rlast : OUT STD_LOGIC;
    s_axi_rvalid : OUT STD_LOGIC;
    s_axi_rready : IN STD_LOGIC
);
end axi_sim_mem_slave;

architecture Behavioral of axi_sim_mem_slave is
    COMPONENT axi_bram_ctrl_0
    PORT (
        s_axi_aclk : IN STD_LOGIC;
        s_axi_aresetn : IN STD_LOGIC;
        s_axi_awaddr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
        s_axi_awlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_awsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_awlock : IN STD_LOGIC;
        s_axi_awcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_awprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_awvalid : IN STD_LOGIC;
        s_axi_awready : OUT STD_LOGIC;
        s_axi_wdata : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_wstrb : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        s_axi_wlast : IN STD_LOGIC;
        s_axi_wvalid : IN STD_LOGIC;
        s_axi_wready : OUT STD_LOGIC;
        s_axi_bresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_bvalid : OUT STD_LOGIC;
        s_axi_bready : IN STD_LOGIC;
        s_axi_araddr : IN STD_LOGIC_VECTOR(16 DOWNTO 0);
        s_axi_arlen : IN STD_LOGIC_VECTOR(7 DOWNTO 0);
        s_axi_arsize : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arburst : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_arlock : IN STD_LOGIC;
        s_axi_arcache : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
        s_axi_arprot : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        s_axi_arvalid : IN STD_LOGIC;
        s_axi_arready : OUT STD_LOGIC;
        s_axi_rdata : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        s_axi_rresp : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        s_axi_rlast : OUT STD_LOGIC;
        s_axi_rvalid : OUT STD_LOGIC;
        s_axi_rready : IN STD_LOGIC;
        bram_rst_a : OUT STD_LOGIC;
        bram_clk_a : OUT STD_LOGIC;
        bram_en_a : OUT STD_LOGIC;
        bram_we_a : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        bram_addr_a : OUT STD_LOGIC_VECTOR(16 DOWNTO 0);
        bram_wrdata_a : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        bram_rddata_a : IN STD_LOGIC_VECTOR(511 DOWNTO 0)
    );
    END COMPONENT;
    
    COMPONENT blk_mem_gen_0
    PORT (
        clka : IN STD_LOGIC;
        ena : IN STD_LOGIC;
        wea : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        addra : IN STD_LOGIC_VECTOR(10 DOWNTO 0);
        dina : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        douta : OUT STD_LOGIC_VECTOR(511 DOWNTO 0)
    );
    END COMPONENT;
    
    signal bram_rst_a : STD_LOGIC;
    signal bram_clk_a : STD_LOGIC;
    signal bram_en_a : STD_LOGIC;
    signal bram_we_a : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal bram_addr_a : STD_LOGIC_VECTOR(16 DOWNTO 0);
    signal bram_wrdata_a : STD_LOGIC_VECTOR(511 DOWNTO 0);
    signal bram_rddata_a : STD_LOGIC_VECTOR(511 DOWNTO 0);
    
begin

    memory: blk_mem_gen_0
    PORT MAP (
        clka => bram_clk_a,
        ena => bram_en_a,
        wea(0) => bram_we_a(0),
        addra => bram_addr_a(10 downto 0),
        dina => bram_wrdata_a,
        douta => bram_rddata_a
    );

    axi_ctrl : axi_bram_ctrl_0
    PORT MAP (
        s_axi_aclk => s_axi_aclk,
        s_axi_aresetn => s_axi_aresetn,
        s_axi_awaddr => s_axi_awaddr,
        s_axi_awlen => s_axi_awlen,
        s_axi_awsize => s_axi_awsize,
        s_axi_awburst => s_axi_awburst,
        s_axi_awlock => s_axi_awlock,
        s_axi_awcache => s_axi_awcache,
        s_axi_awprot => s_axi_awprot,
        s_axi_awvalid => s_axi_awvalid,
        s_axi_awready => s_axi_awready,
        s_axi_wdata => s_axi_wdata,
        s_axi_wstrb => s_axi_wstrb,
        s_axi_wlast => s_axi_wlast,
        s_axi_wvalid => s_axi_wvalid,
        s_axi_wready => s_axi_wready,
        s_axi_bresp => s_axi_bresp,
        s_axi_bvalid => s_axi_bvalid,
        s_axi_bready => s_axi_bready,
        s_axi_araddr => s_axi_araddr,
        s_axi_arlen => s_axi_arlen,
        s_axi_arsize => s_axi_arsize,
        s_axi_arburst => s_axi_arburst,
        s_axi_arlock => s_axi_arlock,
        s_axi_arcache => s_axi_arcache,
        s_axi_arprot => s_axi_arprot,
        s_axi_arvalid => s_axi_arvalid,
        s_axi_arready => s_axi_arready,
        s_axi_rdata => s_axi_rdata,
        s_axi_rresp => s_axi_rresp,
        s_axi_rlast => s_axi_rlast,
        s_axi_rvalid => s_axi_rvalid,
        s_axi_rready => s_axi_rready,
        bram_rst_a => bram_rst_a,
        bram_clk_a => bram_clk_a,
        bram_en_a => bram_en_a,
        bram_we_a => bram_we_a,
        bram_addr_a => bram_addr_a,
        bram_wrdata_a => bram_wrdata_a,
        bram_rddata_a => bram_rddata_a
    );

end Behavioral;

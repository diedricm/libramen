library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity axi4lite_conf_st_unit is
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;

    stream_s_tuples  : in tuple_vec(4-1 downto 0);
    stream_s_status  : in stream_status;
	stream_s_ready   : out std_logic;
	
    stream_m_tuples  : out tuple_vec(4-1 downto 0);
    stream_m_status  : out stream_status;
	stream_m_ready   : in std_logic;
	
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
    s_axi_RREADY : IN STD_LOGIC
);
end axi4lite_conf_st_unit;

architecture Behavioral of axi4lite_conf_st_unit is

    COMPONENT axi4lite_stream_conf_unit_hls_0
    PORT (
    s_axi_AXILiteS_AWADDR : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    s_axi_AXILiteS_AWVALID : IN STD_LOGIC;
    s_axi_AXILiteS_AWREADY : OUT STD_LOGIC;
    s_axi_AXILiteS_WDATA : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_AXILiteS_WSTRB : IN STD_LOGIC_VECTOR(3 DOWNTO 0);
    s_axi_AXILiteS_WVALID : IN STD_LOGIC;
    s_axi_AXILiteS_WREADY : OUT STD_LOGIC;
    s_axi_AXILiteS_BRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_AXILiteS_BVALID : OUT STD_LOGIC;
    s_axi_AXILiteS_BREADY : IN STD_LOGIC;
    s_axi_AXILiteS_ARADDR : IN STD_LOGIC_VECTOR(5 DOWNTO 0);
    s_axi_AXILiteS_ARVALID : IN STD_LOGIC;
    s_axi_AXILiteS_ARREADY : OUT STD_LOGIC;
    s_axi_AXILiteS_RDATA : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
    s_axi_AXILiteS_RRESP : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    s_axi_AXILiteS_RVALID : OUT STD_LOGIC;
    s_axi_AXILiteS_RREADY : IN STD_LOGIC;
    ap_clk : IN STD_LOGIC;
    ap_rst_n : IN STD_LOGIC;
    interrupt : OUT STD_LOGIC;
    in_stream_TVALID : IN STD_LOGIC;
    in_stream_TREADY : OUT STD_LOGIC;
    in_stream_TDATA : IN STD_LOGIC_VECTOR(95 DOWNTO 0);
    in_stream_TLAST : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
    in_stream_TUSER : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
    in_stream_TDEST : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
    out_stream_TVALID : OUT STD_LOGIC;
    out_stream_TREADY : IN STD_LOGIC;
    out_stream_TDATA : OUT STD_LOGIC_VECTOR(95 DOWNTO 0);
    out_stream_TLAST : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
    out_stream_TUSER : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    out_stream_TDEST : OUT STD_LOGIC_VECTOR(13 DOWNTO 0)
    );
    END COMPONENT;
    
    
    signal output_TVALID : STD_LOGIC;
    signal output_TREADY : STD_LOGIC;
    signal output_TDATA : STD_LOGIC_VECTOR(95 DOWNTO 0);
    signal output_TLAST : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal output_TUSER : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal output_TDEST : STD_LOGIC_VECTOR(13 DOWNTO 0);
    
    signal input_TVALID : STD_LOGIC;
    signal input_TREADY : STD_LOGIC;
    signal input_TDATA : STD_LOGIC_VECTOR(95 DOWNTO 0);
    signal input_TLAST : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal input_TUSER : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal input_TDEST : STD_LOGIC_VECTOR(13 DOWNTO 0);
begin

    remap_output_stream: process (ALL)
    begin
        stream_m_status.yield <= output_TLAST(0);
        stream_m_status.ptype <= output_TUSER;
        stream_m_status.cdest <= output_TDEST;
        stream_m_status.valid <= output_TVALID;
        output_TREADY <= stream_m_ready;
        
        stream_m_tuples(0).value <= output_TDATA(64-1 downto 0);
        stream_m_tuples(0).tag <= output_TDATA(96-1 downto 64);
                
        for i in 1 to 3 loop
            stream_m_tuples(i).value <= (others => '0');
            stream_m_tuples(i).tag <= (others => '0');            
        end loop;
    end process;
    
    remap_input_stream: process (ALL)
    begin
        input_TLAST(0) <= stream_s_status.yield;
        input_TUSER <= stream_s_status.ptype;
        input_TDEST <= stream_s_status.cdest;
        input_TVALID <= stream_s_status.valid;
        stream_s_ready <= input_TREADY;
        
        input_TDATA(64-1 downto 0) <= stream_s_tuples(0).value;
        input_TDATA(96-1 downto 64) <= stream_s_tuples(0).tag;
    end process;

    hls_ip_core : axi4lite_stream_conf_unit_hls_0
    PORT MAP (
        s_axi_AXILiteS_AWADDR => s_axi_AWADDR,
        s_axi_AXILiteS_AWVALID => s_axi_AWVALID,
        s_axi_AXILiteS_AWREADY => s_axi_AWREADY,
        s_axi_AXILiteS_WDATA => s_axi_WDATA,
        s_axi_AXILiteS_WSTRB => s_axi_WSTRB,
        s_axi_AXILiteS_WVALID => s_axi_WVALID,
        s_axi_AXILiteS_WREADY => s_axi_WREADY,
        s_axi_AXILiteS_BRESP => s_axi_BRESP,
        s_axi_AXILiteS_BVALID => s_axi_BVALID,
        s_axi_AXILiteS_BREADY => s_axi_BREADY,
        s_axi_AXILiteS_ARADDR => s_axi_ARADDR,
        s_axi_AXILiteS_ARVALID => s_axi_ARVALID,
        s_axi_AXILiteS_ARREADY => s_axi_ARREADY,
        s_axi_AXILiteS_RDATA => s_axi_RDATA,
        s_axi_AXILiteS_RRESP => s_axi_RRESP,
        s_axi_AXILiteS_RVALID => s_axi_RVALID,
        s_axi_AXILiteS_RREADY => s_axi_RREADY,
        ap_clk => ap_clk,
        ap_rst_n => rst_n,
        interrupt => interrupt,
        in_stream_TVALID => input_TVALID,
        in_stream_TREADY => input_TREADY,
        in_stream_TDATA => input_TDATA,
        in_stream_TLAST => input_TLAST,
        in_stream_TUSER => input_TUSER,
        in_stream_TDEST => input_TDEST,
        out_stream_TVALID => output_TVALID,
        out_stream_TREADY => output_TREADY,
        out_stream_TDATA => output_TDATA,
        out_stream_TLAST => output_TLAST,
        out_stream_TUSER => output_TUSER,
        out_stream_TDEST => output_TDEST
    );

end Behavioral;
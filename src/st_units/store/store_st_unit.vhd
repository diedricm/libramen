library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;
  
entity store_st_unit is
generic (
    VIRTUAL_PORT_CNT_LOG2 : natural := 4;
    
    --IN/OUT fifo parameters  
    MEMORY_DEPTH_LOG2_INPUT : natural := 7;
    ALMOST_FULL_LEVEL_INPUT : natural := 8;
    MEMORY_TYPE_INPUT : string := "ultra"
);
Port (

    ap_clk : in std_logic;
    rst_n : in std_logic;

    stream_s_tuples  : in tuple_vec(4-1 downto 0);
    stream_s_status  : in stream_status;
    stream_s_ready   : out std_logic;
    
    stream_m_tuples  : out tuple_vec(4-1 downto 0);
    stream_m_status  : out stream_status;
    stream_m_ready   : in std_logic;
    
    m_axi_AWADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_AWSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_AWBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_AWLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_AWCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_AWVALID : OUT STD_LOGIC;
    m_axi_AWREADY : IN STD_LOGIC;
    m_axi_WDATA : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
    m_axi_WSTRB : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_WLAST : OUT STD_LOGIC;
    m_axi_WVALID : OUT STD_LOGIC;
    m_axi_WREADY : IN STD_LOGIC;
    m_axi_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_BVALID : IN STD_LOGIC;
    m_axi_BREADY : OUT STD_LOGIC;
    m_axi_ARADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
    m_axi_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
    m_axi_ARSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_ARLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
    m_axi_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
    m_axi_ARVALID : OUT STD_LOGIC;
    m_axi_ARREADY : IN STD_LOGIC;
    m_axi_RDATA : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
    m_axi_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
    m_axi_RLAST : IN STD_LOGIC;
    m_axi_RVALID : IN STD_LOGIC;
    m_axi_RREADY : OUT STD_LOGIC
);
end store_st_unit;

architecture Behavioral of store_st_unit is

    COMPONENT store_unit_hls_0
    PORT (
        agg_result_V_ap_vld : OUT STD_LOGIC;
        m_axi_memory_if_V_AWADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_memory_if_V_AWLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_memory_if_V_AWSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_memory_if_V_AWBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_memory_if_V_AWLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_memory_if_V_AWREGION : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_memory_if_V_AWCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_memory_if_V_AWPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_memory_if_V_AWQOS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_memory_if_V_AWVALID : OUT STD_LOGIC;
        m_axi_memory_if_V_AWREADY : IN STD_LOGIC;
        m_axi_memory_if_V_WDATA : OUT STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_memory_if_V_WSTRB : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_memory_if_V_WLAST : OUT STD_LOGIC;
        m_axi_memory_if_V_WVALID : OUT STD_LOGIC;
        m_axi_memory_if_V_WREADY : IN STD_LOGIC;
        m_axi_memory_if_V_BRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_memory_if_V_BVALID : IN STD_LOGIC;
        m_axi_memory_if_V_BREADY : OUT STD_LOGIC;
        m_axi_memory_if_V_ARADDR : OUT STD_LOGIC_VECTOR(63 DOWNTO 0);
        m_axi_memory_if_V_ARLEN : OUT STD_LOGIC_VECTOR(7 DOWNTO 0);
        m_axi_memory_if_V_ARSIZE : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_memory_if_V_ARBURST : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_memory_if_V_ARLOCK : OUT STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_memory_if_V_ARREGION : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_memory_if_V_ARCACHE : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_memory_if_V_ARPROT : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        m_axi_memory_if_V_ARQOS : OUT STD_LOGIC_VECTOR(3 DOWNTO 0);
        m_axi_memory_if_V_ARVALID : OUT STD_LOGIC;
        m_axi_memory_if_V_ARREADY : IN STD_LOGIC;
        m_axi_memory_if_V_RDATA : IN STD_LOGIC_VECTOR(511 DOWNTO 0);
        m_axi_memory_if_V_RRESP : IN STD_LOGIC_VECTOR(1 DOWNTO 0);
        m_axi_memory_if_V_RLAST : IN STD_LOGIC;
        m_axi_memory_if_V_RVALID : IN STD_LOGIC;
        m_axi_memory_if_V_RREADY : OUT STD_LOGIC;
        ap_clk : IN STD_LOGIC;
        ap_rst_n : IN STD_LOGIC;
        ap_start : IN STD_LOGIC;
        ap_done : OUT STD_LOGIC;
        ap_ready : OUT STD_LOGIC;
        ap_idle : OUT STD_LOGIC;
        agg_result_V : OUT STD_LOGIC_VECTOR(31 DOWNTO 0);
        stream_in_TVALID : IN STD_LOGIC;
        stream_in_TREADY : OUT STD_LOGIC;
        stream_in_TDATA : IN STD_LOGIC_VECTOR(383 DOWNTO 0);
        stream_in_TUSER : IN STD_LOGIC_VECTOR(2 DOWNTO 0);
        stream_in_TDEST : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
        stream_in_TLAST : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        output_r_TVALID : OUT STD_LOGIC;
        output_r_TREADY : IN STD_LOGIC;
        output_r_TDATA : OUT STD_LOGIC_VECTOR(383 DOWNTO 0);
        output_r_TUSER : OUT STD_LOGIC_VECTOR(2 DOWNTO 0);
        output_r_TDEST : OUT STD_LOGIC_VECTOR(13 DOWNTO 0);
        output_r_TLAST : OUT STD_LOGIC_VECTOR(0 DOWNTO 0);
        free_credits_in_buffer_V : IN STD_LOGIC_VECTOR(11 DOWNTO 0);
        regentry_active : IN STD_LOGIC_VECTOR(0 DOWNTO 0);
        regentry_buffer_base_V : IN STD_LOGIC_VECTOR(63 DOWNTO 0);
        regentry_buffer_iterator_V : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        regentry_buffer_length_V : IN STD_LOGIC_VECTOR(31 DOWNTO 0);
        regentry_return_addr_V : IN STD_LOGIC_VECTOR(13 DOWNTO 0);
        regentry_return_value_V : IN STD_LOGIC_VECTOR(7 DOWNTO 0)
    );
    END COMPONENT;

    constant BUFFER_BASE_REG_ADDR : natural := 3;
    constant REQ_TAG_RANGE_REG_ADDR : natural := 4;
    
    constant TUPPLE_COUNT : natural := 4;
    constant MEMORY_TYPE_OUTPUT : string := "distributed";
    constant MEMORY_DEPTH_LOG2_OUTPUT : natural := 3;
    constant ALMOST_FULL_LEVEL_OUTPUT : natural := 0;
    
    signal credits_list_out_input_buffer : std_logic_vector((2**VIRTUAL_PORT_CNT_LOG2)*MEMORY_DEPTH_LOG2_INPUT-1 downto 0);
    
    signal stream_core_s_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_core_s_status  : stream_status;
    signal stream_core_s_ready   : std_logic;
    
    signal stream_core_x_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_core_x_status  : stream_status;
    signal stream_core_x_ready   : std_logic;
    
    signal stream_core_m_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_core_m_status  : stream_status;
    signal stream_core_m_ready   : std_logic;
    signal stream_core_m_ldest  : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
    
    signal ap_start : STD_LOGIC;
    signal ap_done : STD_LOGIC;
    signal ap_idle : STD_LOGIC;
    signal ap_ready : STD_LOGIC;
    
    signal chan_req : slv(VIRTUAL_PORT_CNT_LOG2-1 downto 0);
	signal chan_req_valid : std_logic;
	signal chan_req_ready : std_logic;
    signal chan_clear_outstanding : std_logic;
    
    signal regentry_active : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal regentry_buffer_base : STD_LOGIC_VECTOR(63 DOWNTO 0);
    signal regentry_buffer_iterator : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal regentry_buffer_length : STD_LOGIC_VECTOR(31 DOWNTO 0);
    signal regentry_return_addr : STD_LOGIC_VECTOR(13 DOWNTO 0);
    signal regentry_return_value : STD_LOGIC_VECTOR(7 DOWNTO 0);
    signal free_credits_in_buffer : STD_LOGIC_VECTOR(11 DOWNTO 0);
    signal agg_result : STD_LOGIC_VECTOR(31 DOWNTO 0);
    
    signal output_r_TVALID : STD_LOGIC;
    signal output_r_TREADY : STD_LOGIC;
    signal output_r_TDATA : STD_LOGIC_VECTOR(383 DOWNTO 0);
    signal output_r_TLAST : STD_LOGIC_VECTOR(0 DOWNTO 0);
    signal output_r_TUSER : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal output_r_TDEST : STD_LOGIC_VECTOR(13 DOWNTO 0);
    
    signal stream_in_TVALID : STD_LOGIC;
    signal stream_in_TREADY : STD_LOGIC;
    signal stream_in_TDATA : STD_LOGIC_VECTOR(383 DOWNTO 0);
    signal stream_in_TUSER : STD_LOGIC_VECTOR(2 DOWNTO 0);
    signal stream_in_TDEST : STD_LOGIC_VECTOR(13 DOWNTO 0);
    signal stream_in_TLAST : STD_LOGIC_VECTOR(0 DOWNTO 0);
begin

    remap_output_stream: process (ALL)
    begin
        stream_core_m_ldest <= (others => '0');
        stream_core_m_status.yield <= output_r_TLAST(0);
        stream_core_m_status.ptype <= output_r_TUSER;
        stream_core_m_status.cdest <= output_r_TDEST;
        stream_core_m_status.valid <= output_r_TVALID;
        output_r_TREADY <= stream_core_m_ready;
        
        for i in 0 to 3 loop
            stream_core_m_tuples(i).value <= output_r_TDATA(i*96+64-1 downto i*96);
            stream_core_m_tuples(i).tag <= output_r_TDATA(i*96+96-1 downto i*96+64);
        end loop;
    end process;
    
    remap_input_stream: process (ALL)
    begin
        stream_in_TVALID <= stream_core_x_status.valid;
        stream_in_TLAST(0) <= stream_core_x_status.yield;
        stream_in_TUSER <= stream_core_x_status.ptype;
        stream_in_TDEST <= stream_core_x_status.cdest;
        stream_core_x_ready <= stream_in_TREADY;
        
        for i in 0 to 3 loop
            stream_in_TDATA(i*96+64-1 downto i*96) <= stream_core_x_tuples(i).value;
            stream_in_TDATA(i*96+96-1 downto i*96+64) <= stream_core_x_tuples(i).tag;
        end loop;
    end process;
   
    controller: entity libramen.store_st_unit_controller
    generic map (
        VIRTUAL_PORT_CNT_LOG2 => VIRTUAL_PORT_CNT_LOG2, 
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT
    ) port map (
    
        ap_clk => ap_clk,
        rst_n => rst_n,
    
        credits_list_out_input_buffer => credits_list_out_input_buffer,
        
        chan_req => chan_req,
        chan_req_valid => chan_req_valid,
        chan_req_ready => chan_req_ready,
        chan_clear_outstanding => chan_clear_outstanding,
        
        stream_s_tuples => stream_core_s_tuples,
        stream_s_status => stream_core_s_status,
        stream_s_ready  => stream_core_s_ready,
        
        stream_m_tuples => stream_core_x_tuples,
        stream_m_status => stream_core_x_status,
        stream_m_ready  => stream_core_x_ready,
        
        ap_start => ap_start,
        ap_done  => ap_done,
        ap_idle  => ap_idle,
        ap_ready => ap_ready,
        
        regentry_active => regentry_active,
        regentry_buffer_base => regentry_buffer_base,
        regentry_buffer_iterator => regentry_buffer_iterator,
        regentry_buffer_length => regentry_buffer_length,
        regentry_return_addr => regentry_return_addr,
        regentry_return_value => regentry_return_value,
        free_credits_in_buffer => free_credits_in_buffer,
        agg_result => agg_result
    );

    shell: entity libramen.request_st_shell
    generic map (
        --IO settings
        TUPPLE_COUNT => TUPPLE_COUNT,
        
        --IN/OUT fifo parameters  
        VIRTUAL_PORT_CNT_LOG2_INPUT => VIRTUAL_PORT_CNT_LOG2,
        VIRTUAL_PORT_CNT_LOG2_OUTPUT => VIRTUAL_PORT_CNT_LOG2,
        MEMORY_DEPTH_LOG2_INPUT => MEMORY_DEPTH_LOG2_INPUT,
        MEMORY_DEPTH_LOG2_OUTPUT => MEMORY_DEPTH_LOG2_OUTPUT,
        ALMOST_FULL_LEVEL_INPUT => ALMOST_FULL_LEVEL_INPUT,
        ALMOST_FULL_LEVEL_OUTPUT => ALMOST_FULL_LEVEL_OUTPUT,
        MEMORY_TYPE_INPUT => MEMORY_TYPE_INPUT,
        MEMORY_TYPE_OUTPUT => MEMORY_TYPE_OUTPUT
    ) port map (
        ap_clk => ap_clk,
        rst_n => rst_n,
        
        credits_list_out_input  => credits_list_out_input_buffer,
        credits_list_out_output => OPEN,
        
        chan_req => chan_req,
        chan_req_valid => chan_req_valid,
        chan_req_ready => chan_req_ready,
        chan_clear_outstanding => chan_clear_outstanding,
        
        stream_core_s_tuples  => stream_core_m_tuples,
        stream_core_s_status  => stream_core_m_status,
        stream_core_s_ready   => stream_core_m_ready,
        stream_core_s_ldest   => stream_core_m_ldest,
        
        stream_core_m_tuples  => stream_core_s_tuples,
        stream_core_m_status  => stream_core_s_status,
        stream_core_m_ready   => stream_core_s_ready,
        
        stream_ext_s_tuples   => stream_s_tuples,
        stream_ext_s_status   => stream_s_status,
        stream_ext_s_ready    => stream_s_ready,
        
        stream_ext_m_tuples   => stream_m_tuples,
        stream_ext_m_status   => stream_m_status,
        stream_ext_m_ready    => stream_m_ready
    );

    aximm_store : store_unit_hls_0
    PORT MAP (
        m_axi_memory_if_V_AWADDR => m_axi_AWADDR,
        m_axi_memory_if_V_AWLEN => m_axi_AWLEN,
        m_axi_memory_if_V_AWSIZE => m_axi_AWSIZE,
        m_axi_memory_if_V_AWBURST => m_axi_AWBURST,
        m_axi_memory_if_V_AWLOCK => m_axi_AWLOCK,
        m_axi_memory_if_V_AWREGION => OPEN,
        m_axi_memory_if_V_AWCACHE => m_axi_AWCACHE,
        m_axi_memory_if_V_AWPROT => m_axi_AWPROT,
        m_axi_memory_if_V_AWQOS => OPEN,
        m_axi_memory_if_V_AWVALID => m_axi_AWVALID,
        m_axi_memory_if_V_AWREADY => m_axi_AWREADY,
        m_axi_memory_if_V_WDATA => m_axi_WDATA,
        m_axi_memory_if_V_WSTRB => m_axi_WSTRB,
        m_axi_memory_if_V_WLAST => m_axi_WLAST,
        m_axi_memory_if_V_WVALID => m_axi_WVALID,
        m_axi_memory_if_V_WREADY => m_axi_WREADY,
        m_axi_memory_if_V_BRESP => m_axi_BRESP,
        m_axi_memory_if_V_BVALID => m_axi_BVALID,
        m_axi_memory_if_V_BREADY => m_axi_BREADY,
        m_axi_memory_if_V_ARADDR => m_axi_ARADDR,
        m_axi_memory_if_V_ARLEN => m_axi_ARLEN,
        m_axi_memory_if_V_ARSIZE => m_axi_ARSIZE,
        m_axi_memory_if_V_ARBURST => m_axi_ARBURST,
        m_axi_memory_if_V_ARLOCK => m_axi_ARLOCK,
        m_axi_memory_if_V_ARREGION => OPEN,
        m_axi_memory_if_V_ARCACHE => m_axi_ARCACHE,
        m_axi_memory_if_V_ARPROT => m_axi_ARPROT,
        m_axi_memory_if_V_ARQOS => OPEN,
        m_axi_memory_if_V_ARVALID => m_axi_ARVALID,
        m_axi_memory_if_V_ARREADY => m_axi_ARREADY,
        m_axi_memory_if_V_RDATA => m_axi_RDATA,
        m_axi_memory_if_V_RRESP => m_axi_RRESP,
        m_axi_memory_if_V_RLAST => m_axi_RLAST,
        m_axi_memory_if_V_RVALID => m_axi_RVALID,
        m_axi_memory_if_V_RREADY => m_axi_RREADY,
        ap_clk => ap_clk,
        ap_rst_n => rst_n,
        ap_start => ap_start,
        ap_done => ap_done,
        ap_ready => ap_ready,
        ap_idle => ap_idle,
        stream_in_TVALID => stream_in_TVALID,
        stream_in_TREADY => stream_in_TREADY,
        stream_in_TDATA => stream_in_TDATA,
        stream_in_TUSER => stream_in_TUSER,
        stream_in_TDEST => stream_in_TDEST,
        stream_in_TLAST => stream_in_TLAST,
        output_r_TVALID => output_r_TVALID,
        output_r_TREADY => output_r_TREADY,
        output_r_TDATA => output_r_TDATA,
        output_r_TUSER => output_r_TUSER,
        output_r_TDEST => output_r_TDEST,
        output_r_TLAST => output_r_TLAST,
        agg_result_V => agg_result,
        regentry_active => regentry_active,
        regentry_buffer_base_V => regentry_buffer_base,
        regentry_buffer_iterator_V => regentry_buffer_iterator,
        regentry_buffer_length_V => regentry_buffer_length,
        regentry_return_addr_V => regentry_return_addr,
        regentry_return_value_V => regentry_return_value,
        free_credits_in_buffer_V => free_credits_in_buffer
    );
end Behavioral;
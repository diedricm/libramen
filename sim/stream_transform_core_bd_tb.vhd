library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity stream_transform_core_bd_tb is
end stream_transform_core_bd_tb;

architecture Behavioral of stream_transform_core_bd_tb is
    signal ap_clk 				 : std_logic := '0';
    signal ap_rst_n 			 : std_logic := '0';
    signal interrupt 			 : std_logic;
    signal m00_axi_araddr 		 : std_logic_vector(63 downto 0);
    signal m00_axi_arburst 		 : std_logic_vector(1 downto 0);
    signal m00_axi_arcache 		 : std_logic_vector(3 downto 0);
    signal m00_axi_arlen 		 : std_logic_vector(7 downto 0);
    signal m00_axi_arlock 		 : std_logic_vector(0 downto 0);
    signal m00_axi_arprot 		 : std_logic_vector(2 downto 0);
    signal m00_axi_arqos 		 : std_logic_vector(3 downto 0);
    signal m00_axi_arready 		 : std_logic;
    signal m00_axi_arsize 		 : std_logic_vector(2 downto 0);
    signal m00_axi_arvalid 		 : std_logic;
    signal m00_axi_awaddr 		 : std_logic_vector(63 downto 0);
    signal m00_axi_awburst 		 : std_logic_vector(1 downto 0);
    signal m00_axi_awcache 		 : std_logic_vector(3 downto 0);
    signal m00_axi_awlen 		 : std_logic_vector(7 downto 0);
    signal m00_axi_awlock 		 : std_logic_vector(0 downto 0);
    signal m00_axi_awprot 		 : std_logic_vector(2 downto 0);
    signal m00_axi_awqos 		 : std_logic_vector(3 downto 0);
    signal m00_axi_awready 		 : std_logic;
    signal m00_axi_awsize 		 : std_logic_vector(2 downto 0);
    signal m00_axi_awvalid 		 : std_logic;
    signal m00_axi_bready 		 : std_logic;
    signal m00_axi_bresp 		 : std_logic_vector(1 downto 0);
    signal m00_axi_bvalid 		 : std_logic;
    signal m00_axi_rdata 		 : std_logic_vector(511 downto 0);
    signal m00_axi_rlast 		 : std_logic;
    signal m00_axi_rready 		 : std_logic;
    signal m00_axi_rresp 		 : std_logic_vector(1 downto 0);
    signal m00_axi_rvalid 		 : std_logic;
    signal m00_axi_wdata 		 : std_logic_vector(511 downto 0);
    signal m00_axi_wlast 		 : std_logic;
    signal m00_axi_wready 		 : std_logic;
    signal m00_axi_wstrb 		 : std_logic_vector(63 downto 0);
    signal m00_axi_wvalid 		 : std_logic;
    signal s_axi_control_araddr  : std_logic_vector(5 downto 0);
    signal s_axi_control_arready : std_logic;
    signal s_axi_control_arvalid : std_logic;
    signal s_axi_control_awaddr  : std_logic_vector(5 downto 0);
    signal s_axi_control_awready : std_logic;
    signal s_axi_control_awvalid : std_logic;
    signal s_axi_control_bready  : std_logic;
    signal s_axi_control_bresp 	 : std_logic_vector(1 downto 0);
    signal s_axi_control_bvalid  : std_logic;
    signal s_axi_control_rdata 	 : std_logic_vector(31 downto 0);
    signal s_axi_control_rready  : std_logic;
    signal s_axi_control_rresp 	 : std_logic_vector(1 downto 0);
    signal s_axi_control_rvalid  : std_logic;
    signal s_axi_control_wdata 	 : std_logic_vector(31 downto 0);
    signal s_axi_control_wready  : std_logic;
    signal s_axi_control_wstrb 	 : std_logic_vector(3 downto 0);
    signal s_axi_control_wvalid	 : std_logic;
begin

    ap_clk <= NOT ap_clk after 1ns;
    ap_rst_n <= '1' after 200ns;
    
    uut: entity work.stream_transform_core_bd_wrapper
    port map (
        ap_clk 					=> ap_clk,
        ap_rst_n 				=> ap_rst_n,
        interrupt 				=> interrupt,
        m00_axi_araddr 			=> m00_axi_araddr,	  
        m00_axi_arburst 		=> m00_axi_arburst,
        m00_axi_arcache 		=> m00_axi_arcache,
        m00_axi_arlen 			=> m00_axi_arlen,
        m00_axi_arlock 			=> m00_axi_arlock,
        m00_axi_arprot 			=> m00_axi_arprot,
        m00_axi_arqos 			=> m00_axi_arqos,  
        m00_axi_arready 		=> m00_axi_arready,
        m00_axi_arsize 			=> m00_axi_arsize, 
        m00_axi_arvalid 		=> m00_axi_arvalid,
        m00_axi_awaddr 			=> m00_axi_awaddr, 
        m00_axi_awburst 		=> m00_axi_awburst,
        m00_axi_awcache 		=> m00_axi_awcache,
        m00_axi_awlen 			=> m00_axi_awlen,  
        m00_axi_awlock 			=> m00_axi_awlock, 
        m00_axi_awprot 			=> m00_axi_awprot, 
        m00_axi_awqos 			=> m00_axi_awqos,  
        m00_axi_awready 		=> m00_axi_awready,
        m00_axi_awsize 			=> m00_axi_awsize, 
        m00_axi_awvalid 		=> m00_axi_awvalid,
        m00_axi_bready 			=> m00_axi_bready, 
        m00_axi_bresp 			=> m00_axi_bresp,  
        m00_axi_bvalid 			=> m00_axi_bvalid, 
        m00_axi_rdata 			=> m00_axi_rdata,  
        m00_axi_rlast 			=> m00_axi_rlast,  
        m00_axi_rready 			=> m00_axi_rready, 
        m00_axi_rresp 			=> m00_axi_rresp,  
        m00_axi_rvalid 			=> m00_axi_rvalid, 
        m00_axi_wdata 			=> m00_axi_wdata,  
        m00_axi_wlast 			=> m00_axi_wlast,  
        m00_axi_wready 			=> m00_axi_wready, 
        m00_axi_wstrb 			=> m00_axi_wstrb,  
        m00_axi_wvalid 			=> m00_axi_wvalid,  
        s_axi_control_araddr 	=> s_axi_control_araddr,     
        s_axi_control_arready 	=> s_axi_control_arready,     
        s_axi_control_arvalid 	=> s_axi_control_arvalid,     
        s_axi_control_awaddr 	=> s_axi_control_awaddr,     
        s_axi_control_awready 	=> s_axi_control_awready,     
        s_axi_control_awvalid 	=> s_axi_control_awvalid,     
        s_axi_control_bready 	=> s_axi_control_bready,     
        s_axi_control_bresp 	=> s_axi_control_bresp,  
        s_axi_control_bvalid 	=> s_axi_control_bvalid,
        s_axi_control_rdata 	=> s_axi_control_rdata,
        s_axi_control_rready 	=> s_axi_control_rready,
        s_axi_control_rresp 	=> s_axi_control_rresp,
        s_axi_control_rvalid 	=> s_axi_control_rvalid,
        s_axi_control_wdata 	=> s_axi_control_wdata,
        s_axi_control_wready 	=> s_axi_control_wready,
        s_axi_control_wstrb 	=> s_axi_control_wstrb,
        s_axi_control_wvalid 	=> s_axi_control_wvalid
    );

end Behavioral;

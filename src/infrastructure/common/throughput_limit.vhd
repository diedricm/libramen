library IEEE;
    use IEEE.STD_LOGIC_1164.ALL;
    use IEEE.NUMERIC_STD.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;

entity axis_throughput_limit is
generic (
    TDATA_WIDTH : natural := 4;
    TDEST_WIDTH : natural := 8;
    THR_DIVIDEND : natural := 5;
    THR_DIVISOR : natural := 10
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    TDATA_s  : in std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
    TVALID_s : in std_logic;
    TREADY_s : out std_logic;
    TDEST_s  : in std_logic_vector(TDEST_WIDTH-1 downto 0);
    TUSER_s  : in std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    TLAST_s  : in std_logic;
    
    TDATA_m  : out std_logic_vector((TDATA_WIDTH*8)-1 downto 0);
    TVALID_m : out std_logic;
    TREADY_m : in std_logic;
    TDEST_m  : out std_logic_vector(TDEST_WIDTH-1 downto 0);
    TUSER_m  : out std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    TLAST_m  : out std_logic
);
begin
    assert THR_DIVIDEND <= THR_DIVISOR report "axis_hroughput_limit: THR_DIVIDEND must be smaller or equal to THR_DIVISOR" severity failure;
end axis_throughput_limit;

architecture Behavioral of axis_throughput_limit is
    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of TDEST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDEST";
    ATTRIBUTE X_INTERFACE_INFO of TDATA_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDATA";
    ATTRIBUTE X_INTERFACE_INFO of TLAST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TLAST";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TREADY";
    ATTRIBUTE X_INTERFACE_INFO of TUSER_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TUSER";
    ATTRIBUTE X_INTERFACE_INFO of TDEST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDEST";
    ATTRIBUTE X_INTERFACE_INFO of TDATA_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDATA";
    ATTRIBUTE X_INTERFACE_INFO of TLAST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TLAST";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TREADY";
    ATTRIBUTE X_INTERFACE_INFO of TUSER_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TUSER";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_m: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TID_WIDTH 0,TDEST_WIDTH 14";
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_s: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TID_WIDTH 0,TDEST_WIDTH 14";
    
    signal turn_counter : natural := 0;
    signal transmission_allowed : std_logic;
begin

    process (clk)
    begin
        if rising_edge(clk) and rstn = '1' then
            turn_counter <= turn_counter + 1;
            if turn_counter = (THR_DIVISOR - 1) then
                turn_counter <= 0;
            end if;
        end if;
    end process;
    
    transmission_allowed <= '1' when (turn_counter < THR_DIVIDEND) else '0';
    
    TDATA_m  <= TDATA_s;
    TDEST_m  <= TDEST_s;
    TLAST_m  <= TLAST_s;
    TVALID_m <= TVALID_s AND TREADY_m AND transmission_allowed;
    TREADY_s <= TVALID_s AND TREADY_m AND transmission_allowed;
    TUSER_m <= TUSER_s;
    
end Behavioral;

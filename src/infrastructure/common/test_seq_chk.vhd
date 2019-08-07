library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;

entity axis_test_seq_chk is
generic (
    TEST_PAYLOAD : natural := 0
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    TDATA_s  : in std_logic_vector(TDATA_SINGLE_SIZE_IN_BYTES*8-1 downto 0);
    TVALID_s : in std_logic;
    TREADY_s : out std_logic;
    TDEST_s  : in std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
    TLAST_s  : in std_logic;
    TUSER_s  : in std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    
    slave_error_interrupt : out std_logic
);
end axis_test_seq_chk;

architecture Behavioral of axis_test_seq_chk is
    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of TDEST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDEST";
    ATTRIBUTE X_INTERFACE_INFO of TDATA_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TDATA";
    ATTRIBUTE X_INTERFACE_INFO of TLAST_s  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TLAST";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TREADY";
    ATTRIBUTE X_INTERFACE_INFO of TUSER_s : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_S TUSER";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_s: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TUSER_WIDTH 3,TID_WIDTH 0,TDEST_WIDTH 14,TDATA_NUM_BYTES 12";

    signal iterator_s : natural := 0;
begin
    
    TREADY_s <= rstn;
    
    slave: process (clk)
    begin
        if rising_edge(clk) then
            slave_error_interrupt <= '0';
            
            if (TVALID_s = '1') then
                iterator_s <= iterator_s + 1;
                
                if to_integer(unsigned(TDATA_s(VALUE_SIZE_IN_BITS-1 downto 0))) /= iterator_s then
                    slave_error_interrupt <= '1';
                    
                    report "axis_test_seq: Slave sequence TDATA mismatch. Expected: "
                    & integer'image(iterator_s) & " but recieved "
                    & integer'image(to_integer(unsigned(TDATA_s))) & "!"
                    severity error;
                end if;
                
                if to_integer(unsigned(TDATA_s(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS-1 downto VALUE_SIZE_IN_BITS))) /= TEST_PAYLOAD then
                    slave_error_interrupt <= '1';
                    
                    report "axis_test_seq: Slave tag TDATA mismatch. Expected: "
                    & integer'image(iterator_s) & " but recieved "
                    & integer'image(to_integer(unsigned(TDATA_s))) & "!"
                    severity error;
                end if;
                
                if is_hardend(TUSER_s) then
                    iterator_s <= 0;
                end if;
            end if;
        end if;    
    end process;

end Behavioral;
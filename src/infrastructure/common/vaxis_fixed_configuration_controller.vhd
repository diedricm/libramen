library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity vaxis_fixed_configuration_controller is
Port (
	ap_clk : in std_logic;
	rst_n : in std_logic;
	
	finished : out std_logic;
	
	TDATA_m  : out std_logic_vector(12*8-1 downto 0);
	TVALID_m : out std_logic;
	TREADY_m : in std_logic;
	TDEST_m  : out std_logic_vector(14-1 downto 0);
	TUSER_m  : out std_logic_vector(3-1 downto 0);
	TLAST_m  : out std_logic
);
end vaxis_fixed_configuration_controller;

architecture Behavioral of vaxis_fixed_configuration_controller is
	ATTRIBUTE X_INTERFACE_INFO : STRING;
	ATTRIBUTE X_INTERFACE_INFO of TDEST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDEST";
	ATTRIBUTE X_INTERFACE_INFO of TDATA_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDATA";
	ATTRIBUTE X_INTERFACE_INFO of TLAST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TLAST";
	ATTRIBUTE X_INTERFACE_INFO of TUSER_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TUSER";
	ATTRIBUTE X_INTERFACE_INFO of TVALID_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TVALID";
	ATTRIBUTE X_INTERFACE_INFO of TREADY_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TREADY";
	ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_m: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TUSER_WIDTH 3,TID_WIDTH 0,TDEST_WIDTH 14,TDATA_NUM_BYTES 12";

    type opcode is record
        tdest : integer;
        destreg : integer;
        value :  integer;
    end record;
    type opcode_list is array (natural range <>) of opcode;

    constant opcode_count : natural := 9;
    constant opmem : opcode_list(0 to opcode_count-1) := (
        (0, 2, 48), --TDEST: 1->3
        (1, 2, 64), --TDEST: 2->4
        (2, 2, 32), --TDEST: 3->2
        (3, 2, 16), --TDEST: 4->1
        (0, 1, 80),
        (1, 1, 80),
        (2, 1, 80),
        (3, 1, 80),
        (0, 0, 0) --NEED ZERO BYTE TERMINATION
    );
    signal memindex : unsigned(7 downto 0) := (others => '0');
begin
    
    finished <= '0' when (memindex + 1) /= opcode_count else '1';
    
    TDATA_m(63 downto 0) <= std_logic_vector(to_unsigned(opmem(to_integer(memindex)).value, 64));
    TDATA_m(95 downto 64) <= std_logic_vector(to_unsigned(opmem(to_integer(memindex)).destreg, 32));
    TVALID_m <= '1' when (memindex + 1) /= opcode_count else '0';
    TDEST_m <= std_logic_vector(to_unsigned(opmem(to_integer(memindex)).tdest, 14));
    TUSER_m <= VAXIS_TLAST_MASK_HARDEND_3INVALID;
    TLAST_m <= '1';
    
    output: process (ap_clk)
    begin
        if rising_edge(ap_clk) then
            if is1(rst_n) AND is1(TREADY_m) then
                if (memindex + 1) /= opcode_count then
                    memindex <= memindex + 1;
                end if;
            end if;
        end if;
        
    end process;

end Behavioral;
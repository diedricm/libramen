library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library vaxis;
    use vaxis.vaxis_pkg.ALL;
    
entity vaxis_test_seq_gen is
generic (
    TDEST_VAL : natural := 0;
    SEED : natural := 0;
    TEST_PAYLOAD : natural := 0
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    active : in std_logic;
    
    TDATA_m  : out std_logic_vector((TDATA_SINGLE_SIZE_IN_BYTES*8)-1 downto 0);
    TVALID_m : out std_logic;
    TREADY_m : in std_logic;
    TDEST_m  : out std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
    TUSER_m  : out std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
    TLAST_m  : out std_logic
);
end vaxis_test_seq_gen;

architecture Behavioral of vaxis_test_seq_gen is
    ATTRIBUTE X_INTERFACE_INFO : STRING;
    ATTRIBUTE X_INTERFACE_INFO of TDEST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDEST";
    ATTRIBUTE X_INTERFACE_INFO of TDATA_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TDATA";
    ATTRIBUTE X_INTERFACE_INFO of TLAST_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TLAST";
    ATTRIBUTE X_INTERFACE_INFO of TVALID_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TVALID";
    ATTRIBUTE X_INTERFACE_INFO of TREADY_m : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TREADY";
    ATTRIBUTE X_INTERFACE_INFO of TUSER_m  : SIGNAL is "xilinx.com:interface:axis:1.0 AXIS_M TUSER";
    ATTRIBUTE X_INTERFACE_PARAMETER : STRING;
    ATTRIBUTE X_INTERFACE_PARAMETER of TDEST_m: SIGNAL is "CLK_DOMAIN ap_clk,PHASE 0,FREQ_HZ 500000000,HAS_TLAST 1,HAS_TKEEP 0,HAS_TSTRB 0,HAS_TREADY 1,TUSER_WIDTH 3,TID_WIDTH 0,TDEST_WIDTH 14,TDATA_NUM_BYTES 12";

    constant rand_spec  : lfsr_spec := new_lfsr_iterator(64, true);
    
    signal rand_vec : std_logic_vector(64-1 downto 0) := init_lfsr(rand_spec, SEED);

    signal iterator_m : natural := 0;
    signal terminate_circuit : std_logic := '0';
begin

    TDATA_m(VALUE_SIZE_IN_BITS-1 downto 0) <= std_logic_vector(to_unsigned(iterator_m, VALUE_SIZE_IN_BITS));
    TDATA_m(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS-1 downto VALUE_SIZE_IN_BITS) <= std_logic_vector(to_unsigned(TEST_PAYLOAD, TAG_SIZE_IN_BITS)) when iterator_m /= 0 else (others => '0');
    TDEST_m <= std_logic_vector(to_unsigned(TDEST_VAL, TDEST_SIZE_IN_BIT));
    TLAST_m <= '1' when is1(terminate_circuit) OR is1(rand_vec(23 downto 20)) else '0';
    TVALID_m <= '1' when is1(active) else '0';
    TUSER_m <= VAXIS_TLAST_MASK_HARDEND_0INVALID when is1(terminate_circuit) else
           VAXIS_TLAST_MASK_HARDEND_3INVALID when iterator_m = 0 else
           VAXIS_TLAST_MASK_SOFTEND;
    
    main: process (clk)
    begin
        if rising_edge(clk) then
            if is1(rstn AND active) then
                rand_vec <= step(rand_spec, rand_vec);
                
                if is1(TREADY_m) then
                    iterator_m <= iterator_m + 1;
                    
                    if is0(rand_vec(20 downto 16)) then
                        
                    end if;
                    
                    if is1(terminate_circuit) then
                        iterator_m <= 0;
                        terminate_circuit <= '0';
                    end if;
                    
                    if is1(rand_vec(6 downto 0)) then
                        terminate_circuit <= '1';
                    end if;
                end if;

            end if;
        end if;
    end process;

end Behavioral;

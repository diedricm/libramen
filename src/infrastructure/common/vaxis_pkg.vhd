library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
library vaxis;

package vaxis_pkg is

    constant VALUE_SIZE_IN_BITS : natural := 64;
    constant TAG_SIZE_IN_BITS : natural := 32;
    constant TDATA_SINGLE_SIZE_IN_BYTES : natural := 12;
    constant TDATA_QUAD_SIZE_IN_BYTES : natural := 48;
    constant TDEST_SIZE_IN_BIT : natural := 14;
    constant TUSER_SIZE_IN_BIT : natural := 3;
    constant TUSER_EXT_SIZE_IN_BIT : natural := 7;

    constant VAXIS_TLAST_FALSE : std_logic := '0';
    constant VAXIS_TLAST_TRUE : std_logic := '1';
    constant VAXIS_TLAST_MASK_SOFTEND : std_logic_vector := std_logic_vector(to_unsigned(0, TUSER_SIZE_IN_BIT));
    constant VAXIS_TLAST_MASK_SOFTEND_NO_DATA : std_logic_vector := std_logic_vector(to_unsigned(1, TUSER_SIZE_IN_BIT));
    constant VAXIS_TLAST_MASK_HARDEND_NO_DATA : std_logic_vector := std_logic_vector(to_unsigned(3, TUSER_SIZE_IN_BIT));
    constant VAXIS_TLAST_MASK_HARDEND_0INVALID : std_logic_vector := std_logic_vector(to_unsigned(4, TUSER_SIZE_IN_BIT));
    constant VAXIS_TLAST_MASK_HARDEND_1INVALID : std_logic_vector := std_logic_vector(to_unsigned(5, TUSER_SIZE_IN_BIT));
    constant VAXIS_TLAST_MASK_HARDEND_2INVALID : std_logic_vector := std_logic_vector(to_unsigned(6, TUSER_SIZE_IN_BIT));
    constant VAXIS_TLAST_MASK_HARDEND_3INVALID : std_logic_vector := std_logic_vector(to_unsigned(7, TUSER_SIZE_IN_BIT));

    function is_hardend(TUSER : std_logic_vector) return boolean;

    constant DEFAULT_BACKOFF_DETECTION_PERIOD : natural := 3;
    constant DEFAULT_BACKOFF_TIME : natural := 3;
    constant DEFAULT_FIFO_ALMOST_FULL_LEVEL : natural := 16;
    constant DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD : natural := 3;
    
    --Default register space
    constant START_REG_ADDR : natural := 0;
    constant RETURN_DEST_REG_ADDR : natural := 1;
    constant FWD_DEST_REG_ADDR : natural := 2;

    type vaxis_single is record
        TDATA : std_logic_vector(TDATA_SINGLE_SIZE_IN_BYTES*8-1 downto 0);
        TDEST : std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
        TUSER : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
        TLAST : std_logic;
        TVALID : std_logic;
    end record vaxis_single;

    type vaxis_quad is record
        TDATA : std_logic_vector(TDATA_QUAD_SIZE_IN_BYTES*8-1 downto 0);
        TDEST : std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
        TUSER : std_logic_vector(TUSER_SIZE_IN_BIT-1 downto 0);
        TLAST : std_logic;
        TVALID : std_logic;
    end record vaxis_quad;

    type vaxis_quad_ext is record
        TDATA : std_logic_vector(TDATA_QUAD_SIZE_IN_BYTES*8-1 downto 0);
        TDEST : std_logic_vector(TDEST_SIZE_IN_BIT-1 downto 0);
        TUSER : std_logic_vector(TUSER_EXT_SIZE_IN_BIT-1 downto 0);
        TLAST : std_logic;
        TVALID : std_logic;
    end record vaxis_quad_ext;
    
end package vaxis_pkg;

package body vaxis_pkg is

    function is_hardend(TUSER : std_logic_vector) return boolean is
    begin
        return unsigned(TUSER(2 downto 0)) > 2;
    end;

end package body vaxis_pkg;
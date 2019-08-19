library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
library libramen;

package core_pkg is

    constant VALUE_SIZE_IN_BITS : natural := 64;
    constant TAG_SIZE_IN_BITS : natural := 32;
    constant DATA_SINGLE_SIZE_IN_BYTES : natural := (VALUE_SIZE_IN_BITS + TAG_SIZE_IN_BITS)/8;
    constant DATA_QUAD_SIZE_IN_BYTES : natural := DATA_SINGLE_SIZE_IN_BYTES * 8;
    constant CDEST_SIZE_IN_BIT : natural := 14;
    constant PTYPE_SIZE_IN_BIT : natural := 3;
    constant LDEST_SIZE_IN_BIT : natural := 4;
    constant TUSER_EXT_SIZE_IN_BIT : natural := PTYPE_SIZE_IN_BIT + LDEST_SIZE_IN_BIT;

    constant TLAST_FALSE : std_logic := '0';
    constant TLAST_TRUE : std_logic := '1';
    constant TLAST_MASK_SOFTEND : std_logic_vector := std_logic_vector(to_unsigned(0, PTYPE_SIZE_IN_BIT));
    constant TLAST_MASK_SOFTEND_NO_DATA : std_logic_vector := std_logic_vector(to_unsigned(1, PTYPE_SIZE_IN_BIT));
    constant TLAST_MASK_HARDEND_NO_DATA : std_logic_vector := std_logic_vector(to_unsigned(3, PTYPE_SIZE_IN_BIT));
    constant TLAST_MASK_HARDEND_0INVALID : std_logic_vector := std_logic_vector(to_unsigned(4, PTYPE_SIZE_IN_BIT));
    constant TLAST_MASK_HARDEND_1INVALID : std_logic_vector := std_logic_vector(to_unsigned(5, PTYPE_SIZE_IN_BIT));
    constant TLAST_MASK_HARDEND_2INVALID : std_logic_vector := std_logic_vector(to_unsigned(6, PTYPE_SIZE_IN_BIT));
    constant TLAST_MASK_HARDEND_3INVALID : std_logic_vector := std_logic_vector(to_unsigned(7, PTYPE_SIZE_IN_BIT));

    constant DEFAULT_BACKOFF_DETECTION_PERIOD : natural := 3;
    --constant DEFAULT_BACKOFF_TIME : natural := 3;
    constant DEFAULT_FIFO_ALMOST_FULL_LEVEL : natural := 8;
    constant DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD : natural := 4;
    
    --Default register space
    constant START_REG_ADDR : natural := 0;
    constant RETURN_DEST_REG_ADDR : natural := 1;
    constant FWD_DEST_REG_ADDR : natural := 2;
    
    type tuple is record
        value : std_logic_vector(VALUE_SIZE_IN_BITS-1 downto 0);
        tag : std_logic_vector(TAG_SIZE_IN_BITS-1 downto 0);
    end record;
    type tuple_vec is array (natural range <>) of tuple;
    type tuple_vec2D is array (natural range <>, natural range <>) of tuple;
    
    type stream_status is record
        valid : std_logic;
        yield : std_logic;
        cdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
        ptype : std_logic_vector(PTYPE_SIZE_IN_BIT-1 downto 0);
    end record;
    type stream_status_vec is array (natural range <>) of stream_status;
    
    function contains_data(ARG : stream_status) return boolean;
    function is_hardend(ARG : stream_status) return boolean;
    function to_slv(TUPLES : tuple_vec; stream_status : stream_status) return std_logic_vector;
    function get_tuples(ARG : std_logic_vector) return tuple_vec;
    function get_stream_status(ARG : std_logic_vector) return stream_status;
    
end package core_pkg;

package body core_pkg is

    function contains_data(ARG : stream_status) return boolean is
    begin
        return (ARG.ptype /= TLAST_MASK_SOFTEND_NO_DATA) AND (ARG.ptype /= TLAST_MASK_HARDEND_NO_DATA);
    end;

    function is_hardend(ARG : stream_status) return boolean is
    begin
        return unsigned(ARG.ptype) > 2;
    end;
    
    function to_slv(TUPLES : tuple_vec; STREAM_STATUS : stream_status) return std_logic_vector is
        variable result : std_logic_vector(TUPLES'LENGTH*DATA_SINGLE_SIZE_IN_BYTES*8+CDEST_SIZE_IN_BIT+PTYPE_SIZE_IN_BIT+2-1 downto 0);
        variable iterator : integer;
    begin
        iterator := 0;
        
        result(iterator) := STREAM_STATUS.valid;
        iterator := iterator + 1;
        
        result(iterator) := STREAM_STATUS.yield;
        iterator := iterator + 1;
        
        result(CDEST_SIZE_IN_BIT+iterator-1 downto iterator) := STREAM_STATUS.cdest;
        iterator := iterator + CDEST_SIZE_IN_BIT;
        
        result(PTYPE_SIZE_IN_BIT+iterator-1 downto iterator) := STREAM_STATUS.ptype;
        iterator := iterator + PTYPE_SIZE_IN_BIT;
        
        --assert false report "Range: " & integer'IMAGE(result'LENGTH) severity failure;
        
        for i in TUPLES'RANGE loop
            result(VALUE_SIZE_IN_BITS+iterator-1 downto iterator) := TUPLES(i).value;
            iterator := iterator + VALUE_SIZE_IN_BITS;
            
            result(TAG_SIZE_IN_BITS+iterator-1 downto iterator) := TUPLES(i).tag;
            iterator := iterator + TAG_SIZE_IN_BITS;
        end loop;
        
        return result;
    end;

    function get_tuples(ARG : std_logic_vector) return tuple_vec is
        constant TUPLE_CNT : integer := (ARG'LENGTH - CDEST_SIZE_IN_BIT - PTYPE_SIZE_IN_BIT - 2)/(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS);
        variable result : tuple_vec(TUPLE_CNT - 1 downto 0);
        variable iterator : natural;
    begin
        
        iterator := CDEST_SIZE_IN_BIT + PTYPE_SIZE_IN_BIT + 2;
        
        for i in result'RANGE loop
            result(i).value := ARG(VALUE_SIZE_IN_BITS+iterator-1 downto iterator);
            iterator := iterator + VALUE_SIZE_IN_BITS;
            
            result(i).tag := ARG(TAG_SIZE_IN_BITS+iterator-1 downto iterator);
            iterator := iterator + TAG_SIZE_IN_BITS;
        end loop;
        
        return result;
    end;
    
    function get_stream_status(ARG : std_logic_vector) return stream_status is
        variable result : stream_status;
        variable iterator : integer;
    begin
        iterator := 0;
        
        result.valid := ARG(iterator);
        iterator := iterator + 1;
        
        result.yield := ARG(iterator);
        iterator := iterator + 1;
        
        result.cdest := ARG(CDEST_SIZE_IN_BIT+iterator-1 downto iterator);
        iterator := iterator + CDEST_SIZE_IN_BIT;
        
        result.ptype := ARG(PTYPE_SIZE_IN_BIT+iterator-1 downto iterator);
        iterator := iterator + PTYPE_SIZE_IN_BIT;
        
        return result;
    end;

end package body core_pkg;
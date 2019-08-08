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
    constant DEFAULT_BACKOFF_TIME : natural := 3;
    constant DEFAULT_FIFO_ALMOST_FULL_LEVEL : natural := 4;
    constant DEFAULT_CIRCUIT_SETUP_PROBE_PERIOD : natural := 3;
    
    --Default register space
    constant START_REG_ADDR : natural := 0;
    constant RETURN_DEST_REG_ADDR : natural := 1;
    constant FWD_DEST_REG_ADDR : natural := 2;

    type tuple_t is record
        data : std_logic_vector(VALUE_SIZE_IN_BITS-1 downto 0);
        tag  : std_logic_vector(TAG_SIZE_IN_BITS-1 downto 0);
    end record tuple_t;
    type tuple_vec is array (natural range <>) of tuple_t;

    type flit is record
        tuples : tuple_vec;
        cdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
        ptype : std_logic_vector(PTYPE_SIZE_IN_BIT-1 downto 0);
        yield : std_logic;
        valid : std_logic;
    end record flit;
    type flit_vec is array (natural range <>) of flit;
    
    type flit_ext is record
        tuples : tuple_vec;
        cdest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
        ptype : std_logic_vector(PTYPE_SIZE_IN_BIT-1 downto 0);
        yield : std_logic;
        valid : std_logic;
        ldest : std_logic_vector(LDEST_SIZE_IN_BIT-1 downto 0);
    end record flit_ext;
    type flit_ext_vec is array (natural range <>) of flit_ext;
    
    type flit_axis_packed is record
        data : std_logic_vector;
        dest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
        user : std_logic_vector(PTYPE_SIZE_IN_BIT-1 downto 0);
        last : std_logic;
        valid : std_logic;
    end record flit_axis_packed;

    type flit_ext_axis_packed is record
        data : std_logic_vector;
        dest : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0);
        user : std_logic_vector(TUSER_EXT_SIZE_IN_BIT-1 downto 0);
        last : std_logic;
        valid : std_logic;
    end record flit_ext_axis_packed;
    

    function is_hardend(PTYPE : std_logic_vector) return boolean;
    function is_hardend(ARG : flit) return boolean;
    function is_hardend(ARG : flit_ext) return boolean;
    function extend_flit(ARG : flit) return flit_ext;
    function reduce_flit(ARG : flit_ext) return flit;
    function axis_to_flit(ARG : flit_axis_packed) return flit;
    function axis_to_flit(ARG : flit_ext_axis_packed) return flit_ext;
    function flit_to_axis(ARG : flit) return flit_axis_packed;
    function flit_to_axis(ARG : flit_ext) return flit_ext_axis_packed;
    function slv_to_flit(ARG : std_logic_vector) return flit;
    function slv_to_flit_ext(ARG : std_logic_vector) return flit_ext;
    function flit_to_slv(ARG : flit) return std_logic_vector;
    function flit_to_slv(ARG : flit_ext) return std_logic_vector;
end package core_pkg;

package body core_pkg is

    function is_hardend(PTYPE : std_logic_vector) return boolean is
    begin
        return unsigned(PTYPE) > 2;
    end;
    function is_hardend(ARG : flit) return boolean is
    begin
        return is_hardend(ARG.ptype);
    end;
    function is_hardend(ARG : flit_ext) return boolean is
    begin
        return is_hardend(ARG.ptype);
    end;
    
    function extend_flit(ARG : flit) return flit_ext is
        variable result : flit_ext(tuples(ARG.tuples'RANGE));
    begin
        result.tuples := ARG.tuples;
        result.cdest := ARG.cdest;
        result.ptype := ARG.ptype;
        result.yield := ARG.yield;
        result.valid := ARG.valid;
        result.ldest := ARG.cdest(lDEST_SIZE_IN_BIT-1 downto 0);
        
        return result;
    end;
    
    function reduce_flit(ARG : flit_ext) return flit is
        variable result : flit;
    begin
        result.tuples := ARG.tuples;
        result.cdest := ARG.cdest;
        result.ptype := ARG.ptype;
        result.yield := ARG.yield;
        result.valid := ARG.valid;
        
        return result;
    end;
    
    function axis_to_flit(ARG : flit_axis_packed) return flit is
        constant tuple_cnt : natural := ARG.data'HIGH / (DATA_SINGLE_SIZE_IN_BYTES * 8);
        variable result : flit;
    begin
        assert tuple_cnt = 1 OR tuple_cnt = 4 report "axis_to_flit: Only flits with 1 or 4 tuples should be used!" severity failure;
        
        result.yield := ARG.last;
        result.cdest := ARG.dest;
        result.ptype := ARG.user;
        result.valid := ARG.valid;
        
        for i in 0 to tuple_cnt-1 loop
            result.tuples(i).data := ARG.data((i+1)*VALUE_SIZE_IN_BITS-1 downto i*VALUE_SIZE_IN_BITS);
            result.tuples(i).tag  := ARG.data((i+1)*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS)-1 downto i*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS));
        end loop;
        
        return result;
    end;
    
    function axis_to_flit(ARG : flit_ext_axis_packed) return flit_ext is
        constant tuple_cnt : natural := ARG.data'HIGH / (DATA_SINGLE_SIZE_IN_BYTES * 8);
        variable result : flit_ext;
    begin
        assert tuple_cnt = 1 OR tuple_cnt = 4 report "axis_to_flit: Only flits with 1 or 4 tuples should be used!" severity failure;
        
        result.yield := ARG.last;
        result.cdest := ARG.dest;
        result.ptype := ARG.user(PTYPE_SIZE_IN_BIT-1 downto 0);
        result.valid := ARG.valid;
        result.ldest := ARG.user(LDEST_SIZE_IN_BIT-1 downto PTYPE_SIZE_IN_BIT);
        
        for i in 0 to tuple_cnt-1 loop
            result.tuples(i).data := ARG.data((i+1)*VALUE_SIZE_IN_BITS-1 downto i*VALUE_SIZE_IN_BITS);
            result.tuples(i).tag  := ARG.data((i+1)*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS)-1 downto i*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS));
        end loop;
        
        return result;
    end;
    
    function flit_to_axis(ARG : flit) return flit_axis_packed is
        constant tuple_cnt : natural := ARG.tuples'HIGH * (DATA_SINGLE_SIZE_IN_BYTES * 8);
        variable result : flit_axis_packed;
    begin
        result.last := ARG.yield;
        result.dest := ARG.cdest;
        result.user(PTYPE_SIZE_IN_BIT-1 downto 0) := ARG.ptype;
        result.valid := ARG.valid;
        
        for i in 0 to tuple_cnt-1 loop
            result.data((i+1)*VALUE_SIZE_IN_BITS-1 downto i*VALUE_SIZE_IN_BITS) := ARG.tuples(i).data;
            result.data((i+1)*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS)-1 downto i*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS))  := ARG.tuples(i).tag;
        end loop;
    end;
    
    function flit_to_axis(ARG : flit_ext) return flit_ext_axis_packed is
        constant tuple_cnt : natural := ARG.tuples'HIGH * (DATA_SINGLE_SIZE_IN_BYTES * 8);
        variable result : flit_ext_axis_packed;
    begin
        result.last := ARG.yield;
        result.dest := ARG.cdest;
        result.user(PTYPE_SIZE_IN_BIT-1 downto 0) := ARG.ptype;
        result.valid := ARG.valid;
        result.user(LDEST_SIZE_IN_BIT-1 downto PTYPE_SIZE_IN_BIT) := ARG.ldest;
        
        for i in 0 to tuple_cnt-1 loop
            result.data((i+1)*VALUE_SIZE_IN_BITS-1 downto i*VALUE_SIZE_IN_BITS) := ARG.tuples(i).data;
            result.data((i+1)*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS)-1 downto i*(VALUE_SIZE_IN_BITS+TAG_SIZE_IN_BITS))  := ARG.tuples(i).tag;
        end loop;
    end;
    
    function slv_to_flit(ARG : std_logic_vector) return flit is
        constant result_length : natural := (ARG'HIGH-CDEST_SIZE_IN_BIT-PTYPE_SIZE_IN_BIT-1)/(DATA_SINGLE_SIZE_IN_BYTES*8);
        variable result : flit(tuples(result_length-1 downto 0));
        variable counter : natural;
    begin
        counter := 0;
    
        result.yield := ARG(counter);
        counter := counter + 1;
        
        result.ptype := ARG(PTYPE_SIZE_IN_BIT+counter-1 downto counter);
        counter := counter + PTYPE_SIZE_IN_BIT;
        
        result.cdest := ARG(CDEST_SIZE_IN_BIT+counter-1 downto counter);
        counter := counter + CDEST_SIZE_IN_BIT;
        
        for i in result.tuples'RANGE loop
            result.tuples(i).data :=ARG(VALUE_SIZE_IN_BITS+counter-1 downto counter);
            counter := counter + VALUE_SIZE_IN_BITS;
            
            result.tuples(i).tag :=ARG(TAG_SIZE_IN_BITS+counter-1 downto counter);
            counter := counter + TAG_SIZE_IN_BITS;
        end loop;
        
        return result;
    end;
    
    function slv_to_flit_ext(ARG : std_logic_vector) return flit_ext is
        constant result_length : natural := (ARG'HIGH-CDEST_SIZE_IN_BIT-PTYPE_SIZE_IN_BIT-1)/(DATA_SINGLE_SIZE_IN_BYTES*8);
        variable result : flit_ext(tuples(result_length-1 downto 0));
        variable counter : natural;
    begin
        counter := 0;
    
        result.yield := ARG(counter);
        counter := counter + 1;
        
        result.ptype := ARG(PTYPE_SIZE_IN_BIT+counter-1 downto counter);
        counter := counter + PTYPE_SIZE_IN_BIT;
        
        result.cdest := ARG(CDEST_SIZE_IN_BIT+counter-1 downto counter);
        counter := counter + CDEST_SIZE_IN_BIT;
        
        for i in result.tuples'RANGE loop
            result.tuples(i).data :=ARG(VALUE_SIZE_IN_BITS+counter-1 downto counter);
            counter := counter + VALUE_SIZE_IN_BITS;
            
            result.tuples(i).tag :=ARG(TAG_SIZE_IN_BITS+counter-1 downto counter);
            counter := counter + TAG_SIZE_IN_BITS;
        end loop;
        
        result.ldest := ARG(LDEST_SIZE_IN_BIT+counter-1 downto counter);
        counter := counter + LDEST_SIZE_IN_BIT;
        
        return result;
    end;

    function flit_to_slv(ARG : flit) return std_logic_vector is
        constant result_length : natural := ARG.tuples'HIGH*DATA_SINGLE_SIZE_IN_BYTES*8+CDEST_SIZE_IN_BIT+PTYPE_SIZE_IN_BIT+1;
        variable result : std_logic_vector(result_length-1 downto 0);
        variable counter : natural;
    begin
        counter := 0;
    
        result(counter) := ARG.yield;
        counter := counter + 1;
        
        result(PTYPE_SIZE_IN_BIT+counter-1 downto counter) :=ARG.ptype;
        counter := counter + PTYPE_SIZE_IN_BIT;
        
        result(CDEST_SIZE_IN_BIT+counter-1 downto counter) :=ARG.cdest;
        counter := counter + CDEST_SIZE_IN_BIT;
        
        for i in ARG.tuples'RANGE loop
            result(VALUE_SIZE_IN_BITS+counter-1 downto counter) :=ARG.tuples(i).data;
            counter := counter + VALUE_SIZE_IN_BITS;
            
            result(TAG_SIZE_IN_BITS+counter-1 downto counter) :=ARG.tuples(i).tag;
            counter := counter + TAG_SIZE_IN_BITS;
        end loop;
        
        return result;
    end;
    
    function flit_to_slv(ARG : flit_ext) return std_logic_vector is
        constant result_length : natural := ARG.tuples'HIGH*DATA_SINGLE_SIZE_IN_BYTES*8+CDEST_SIZE_IN_BIT+PTYPE_SIZE_IN_BIT+LDEST_SIZE_IN_BIT+1;
        variable result : std_logic_vector(result_length-1 downto 0);
        variable counter : natural;
    begin
        counter := 0;
    
        result(counter) := ARG.yield;
        counter := counter + 1;
        
        result(PTYPE_SIZE_IN_BIT+counter-1 downto counter) :=ARG.ptype;
        counter := counter + PTYPE_SIZE_IN_BIT;
        
        result(CDEST_SIZE_IN_BIT+counter-1 downto counter) :=ARG.cdest;
        counter := counter + CDEST_SIZE_IN_BIT;
        
        for i in ARG.tuples'RANGE loop
            result(VALUE_SIZE_IN_BITS+counter-1 downto counter) :=ARG.tuples(i).data;
            counter := counter + VALUE_SIZE_IN_BITS;
            
            result(TAG_SIZE_IN_BITS+counter-1 downto counter) :=ARG.tuples(i).tag;
            counter := counter + TAG_SIZE_IN_BITS;
        end loop;
        
        result(LDEST_SIZE_IN_BIT+counter-1 downto counter) := ARG.ldest;
        counter := counter + LDEST_SIZE_IN_BIT;
        
        return result;
    end;

end package body core_pkg;
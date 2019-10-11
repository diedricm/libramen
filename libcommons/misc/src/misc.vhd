library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
	use ieee.math_real.log2;
	USE ieee.math_real.ceil;

package misc is
    --PUBLIC MEMBERS
    alias slv is std_logic_vector;
    type slv2D is array (natural range <>, natural range <>) of std_logic;
    type int_vec is array (natural range <>) of integer;
    
	--Returns the ciel of the log base 2 of ARG
	function log2_nat(ARG : natural) return natural;

	--Set to all '0'/'1'
	procedure b0(signal ARG : out std_logic);
	procedure b0(signal ARG : out std_logic_vector);
	procedure b0(signal ARG : out unsigned);
	procedure b1(signal ARG : out std_logic);
	procedure b1(signal ARG : out std_logic_vector);
	procedure b1(signal ARG : out unsigned);
	
	--check if all '0'/'1'
	function is0(ARG : std_logic) return boolean;
	function is0(ARG : std_logic_vector) return boolean;
	function is0(ARG : unsigned) return boolean;
	function is1(ARG : std_logic) return boolean;
	function is1(ARG : std_logic_vector) return boolean;
	function is1(ARG : unsigned) return boolean;
	function is_binary(ARG : std_logic) return boolean;
	function is_binary(ARG : std_logic_vector) return boolean;
	function is_binary(ARG : unsigned) return boolean;
    
    function and_reduce(ARG : std_logic_vector) return std_logic;
    function or_reduce(ARG : std_logic_vector) return std_logic;
    
    function min(A :  integer; B : integer) return integer;
    function min(A :   signed; B : signed) return signed;
    function min(A : unsigned; B : unsigned) return unsigned;
    function max(A :  integer; B : integer) return integer;
    function max(A :   signed; B : signed) return signed;
    function max(A : unsigned; B : unsigned) return unsigned;
    
    --Shorthands for handling binary numbers
    function slv2i(ARG : std_logic_vector) return integer;
    type integer_sign is (POS, NEG);
    function getSign(ARG: signed) return integer_sign;
	
	--True if any in ARG is '1' (OR '0' respectivly)
	function isAnySet(ARG : std_logic_vector) return boolean;
	function isAnyUnset(ARG : std_logic_vector) return boolean;
	
    --Gray code converter
    function gray2bin(ARG : unsigned) return unsigned;
    function bin2gray(ARG : unsigned) return unsigned;
    
    --One-Hot encoded positive number
    type onehot is array (natural range <>) of std_logic;
    function binToOnehotDefaultToZV(ARG : unsigned; MAXVAL : natural) return onehot;
    function binToOnehot(ARG : unsigned) return onehot;
    function onehotToBin(ARG : onehot) return unsigned;
    
    --K-biased signed for K is half of number range
    type halfbiased is array (natural range <>) of std_logic;
    function halfbiasedToTwos(ARG : halfbiased) return signed;
    function twosToHalfBiased(ARG : signed) return halfbiased;
    
    --convert slv to hex or octal string TAKEN FROM IEEE 2008 standard lib
    function slv_to_oct_string (value : STD_LOGIC_VECTOR) return STRING;
    function slv_to_hex_string (value : STD_LOGIC_VECTOR) return STRING;
    
    
    --VHDL 2008 N-dimensional types
    --type slv is array (natural range <>) of std_logic;
    --type slv2D is array (natural range <>) of std_logic_vector;
    --type slv3D is array (natural range <>) of slv2D;
    --type unsigned2D is array (natural range <>) of unsigned;
    --type unsigned3D is array (natural range <>) of unsigned2D;
    --type signed2D is array (natural range <>) of signed;
    --type signed3D is array (natural range <>) of signed2D;
end misc;

package body misc is

	function log2_nat(ARG : natural) return natural is
	begin
		return integer(ceil(log2(real(ARG))));
	end;

	procedure b0(signal ARG : out std_logic) is
    begin
		ARG <= '0';
	end;
	procedure b0(signal ARG : out std_logic_vector) is
    begin
        for i in ARG'LOW to ARG'HIGH loop
            ARG(i) <= '0';
        end loop;
	end;
	procedure b0(signal ARG : out unsigned) is
    begin
        for i in ARG'LOW to ARG'HIGH loop
            ARG(i) <= '0';
        end loop;
	end;
	procedure b1(signal ARG : out std_logic) is
    begin
		ARG <= '1';
	end;
	procedure b1(signal ARG : out std_logic_vector) is
    begin
        for i in ARG'LOW to ARG'HIGH loop
            ARG(i) <= '1';
        end loop;
	end;
	procedure b1(signal ARG : out unsigned) is
    begin
        for i in ARG'LOW to ARG'HIGH loop
            ARG(i) <= '1';
        end loop;
	end;
	
	function is_value(ARG : std_logic_vector; DVAL : std_logic) return boolean is
        variable result : boolean := true;
    begin
        for i in ARG'high downto ARG'low loop
            result := result AND (ARG(i) = DVAL);
        end loop;
        
        return result;
    end;
	
	function is0(ARG : std_logic) return boolean is
	begin
		return ARG = '0';
    end;
    function is0(ARG : std_logic_vector) return boolean is
	begin
		return is_value(ARG, '0');
    end;
	function is0(ARG : unsigned) return boolean is
	begin
		return is0(std_logic_vector(ARG));
    end;
		function is1(ARG : std_logic) return boolean is
	begin
		return ARG = '1';
    end;
    function is1(ARG : std_logic_vector) return boolean is
	begin
		return is_value(ARG, '1');
    end;
	function is1(ARG : unsigned) return boolean is
	begin
		return is1(std_logic_vector(ARG));
    end;
    
    function is_binary(ARG : std_logic) return boolean is
    begin
        return (is1(ARG) or is0(ARG));
    end;
    
	function is_binary(ARG : std_logic_vector) return boolean is
	begin
        for i in ARG'high downto ARG'low loop
            if NOT is_binary(ARG(i)) then
                return false;
            end if;
        end loop;
        return true;
    end;
    
	function is_binary(ARG : unsigned) return boolean is
	begin
	   return is_binary(std_logic_vector(ARG));
    end;
    
    function and_reduce(ARG : std_logic_vector) return std_logic is
    begin
        if is1(ARG) then
            return '1';
        else
            return '0';
        end if;
    end;
    
    function or_reduce(ARG : std_logic_vector) return std_logic is
    begin
        if is0(ARG) then
            return '0';
        else
            return '1';
        end if;
    end;
	
	function min(A :  integer; B : integer) return integer is
	begin
        if A < B then 
            return A;
        else
            return B;
        end if;
	end;
	
    function min(A :   signed; B : signed) return signed is
	begin
        if A < B then 
            return A;
        else
            return B;
        end if;	
	end;
	
    function min(A : unsigned; B : unsigned) return unsigned is
	begin
        if A < B then 
            return A;
        else
            return B;
        end if;
	end;
	
    function max(A :  integer; B : integer) return integer is
	begin
        if A < B then 
            return A;
        else
            return B;
        end if;
	end;
	
    function max(A :   signed; B : signed) return signed is
	begin
        if A < B then 
            return A;
        else
            return B;
        end if;
	end;
	
    function max(A : unsigned; B : unsigned) return unsigned is
	begin
        if A < B then 
            return A;
        else
            return B;
        end if;	
	end;
	
	
	function slv2i(ARG : std_logic_vector) return integer is
	begin
	   return to_integer(unsigned(ARG));
	end;
	
	function isAnySet(ARG : std_logic_vector) return boolean is
	begin
		for i in ARG'high-1 downto 0 loop
			if ARG(i) = '1' then
				return true;
			end if;
		end loop;
		return false;
	end;
	
	function isAnyUnset(ARG : std_logic_vector) return boolean is
	begin
		for i in ARG'high-1 downto 0 loop
			if ARG(i) = '0' then
				return true;
			end if;
		end loop;
		return false;
	end;
	
    function getSign(ARG: signed) return integer_sign is
    begin
        if is0(ARG(ARG'HIGH)) then
            return POS;
        else
            return NEG;
        end if;
    end;

    function gray2bin(ARG : unsigned) return unsigned is
        variable result : unsigned(ARG'HIGH downto 0) := ARG;
    begin
        for i in 1 to ARG'HIGH loop
            result := result XOR shift_right(ARG, i);
        end loop;
        return result;
    end;

    function bin2gray(ARG : unsigned) return unsigned is
    begin
        return ARG XOR shift_right(ARG, 1);
    end;
    
    function binToOnehotDefaultToZV(ARG : unsigned; MAXVAL : natural) return onehot is
    variable result : onehot(MAXVAL downto 0);
    begin
        result := (others => '0');
        for i in 0 to MAXVAL loop
            if ARG = to_unsigned(i, ARG'LENGTH) then
                result(i) := '1';
            end if;
        end loop;
        return result;
    end;
    
    function binToOnehot(ARG : unsigned) return onehot is
    begin
        return binToOnehotDefaultToZV(ARG, ARG'LENGTH**2-1);
    end;
    
    function onehotToBin(ARG : onehot) return unsigned is
        variable result : unsigned(log2_nat(ARG'LENGTH)-1 downto 0);
    begin
        for i in 0 to ARG'LENGTH loop
            if is1(ARG(i)) then
                result := to_unsigned(i, log2_nat(ARG'LENGTH));
            end if;
        end loop;
        return result;
    end;
    
    function halfbiasedToTwos(ARG : halfbiased) return signed is
        variable result : std_logic_vector(ARG'LENGTH-1 downto 0) := std_logic_vector(ARG);
    begin
        result(ARG'HIGH) := NOT(result(ARG'HIGH));
        return signed(result);
    end;
    
    function twosToHalfBiased(ARG : signed) return halfbiased is
        variable result : std_logic_vector(ARG'LENGTH-1 downto 0) := std_logic_vector(ARG);
    begin
        result(ARG'HIGH) := NOT(result(ARG'HIGH));
        return halfbiased(result);
    end;
    
    function slv_to_oct_string (value : STD_LOGIC_VECTOR) return STRING is
        constant result_length : NATURAL := (value'length+2)/3;
        variable pad           : STD_ULOGIC_VECTOR(1 to result_length*3 - value'length);
        variable padded_value  : STD_ULOGIC_VECTOR(1 to result_length*3);
        variable result        : STRING(1 to result_length);
        variable tri           : STD_ULOGIC_VECTOR(1 to 3);
    begin
        if value (value'left) = 'Z' then
            pad := (others => 'Z');
        else
            pad := (others => '0');
        end if;
        
        padded_value := pad & value;
        
        for i in 1 to result_length loop
            tri := To_X01Z(padded_value(3*i-2 to 3*i));
            case tri is
                when o"0"   => result(i) := '0';
                when o"1"   => result(i) := '1';
                when o"2"   => result(i) := '2';
                when o"3"   => result(i) := '3';
                when o"4"   => result(i) := '4';
                when o"5"   => result(i) := '5';
                when o"6"   => result(i) := '6';
                when o"7"   => result(i) := '7';
                when "ZZZ"  => result(i) := 'Z';
                when others => result(i) := 'X';
            end case;
        end loop;
        return result;
    end;
    
    function slv_to_hex_string (value : STD_LOGIC_VECTOR) return STRING is
        constant result_length : NATURAL := (value'length+3)/4;
        variable pad           : STD_ULOGIC_VECTOR(1 to result_length*4 - value'length);
        variable padded_value  : STD_ULOGIC_VECTOR(1 to result_length*4);
        variable result        : STRING(1 to result_length);
        variable quad          : STD_ULOGIC_VECTOR(1 to 4);
    begin
    
        if value (value'left) = 'Z' then
            pad := (others => 'Z');
        else
            pad := (others => '0');
        end if;
        
        padded_value := pad & value;
        
        for i in 1 to result_length loop
            quad := To_X01Z(padded_value(4*i-3 to 4*i));
            case quad is
                when x"0"   => result(i) := '0';
                when x"1"   => result(i) := '1';
                when x"2"   => result(i) := '2';
                when x"3"   => result(i) := '3';
                when x"4"   => result(i) := '4';
                when x"5"   => result(i) := '5';
                when x"6"   => result(i) := '6';
                when x"7"   => result(i) := '7';
                when x"8"   => result(i) := '8';
                when x"9"   => result(i) := '9';
                when x"A"   => result(i) := 'A';
                when x"B"   => result(i) := 'B';
                when x"C"   => result(i) := 'C';
                when x"D"   => result(i) := 'D';
                when x"E"   => result(i) := 'E';
                when x"F"   => result(i) := 'F';
                when "ZZZZ" => result(i) := 'Z';
                when others => result(i) := 'X';
            end case;
        end loop;
        
        return result;
    end;
end misc;
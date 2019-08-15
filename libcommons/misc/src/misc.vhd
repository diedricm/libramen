library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
	use ieee.math_real.log2;
	USE ieee.math_real.ceil;

package misc is
    --PUBLIC MEMBERS
    alias slv is std_logic_vector;
    type slv2D is array (natural range <>, natural range <>) of std_logic;
    
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
    
    function and_reduce(ARG : std_logic_vector) return std_logic;
    function or_reduce(ARG : std_logic_vector) return std_logic;
    
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
end misc;
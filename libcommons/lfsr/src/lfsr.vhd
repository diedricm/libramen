library ieee;
    use ieee.std_logic_1164.all;
    use ieee.numeric_std.all;
library libcommons;
    use libcommons.misc.all;
	
package lfsr is
    --GENERICS
    constant MAX_LFSR_SIZE : natural := 168;
    constant MIN_LFSR_SIZE : natural := 3;
    constant POLYPARTS : natural := 4;
    
    --TYPES
    type lfsr_poly is array(polyparts-1 downto 0) of natural range 0 to MAX_LFSR_SIZE;

	--Treat as black box
    type lfsr_spec is record
        poly : lfsr_poly;
		size : natural;
		cycle_stop_state : boolean;
    end record lfsr_spec;

	--Construct a lfsr_spec with the required parameters
	--Should be stored as constant for synthesis
	function new_lfsr_iterator (SIZE : natural) return lfsr_spec;
    function new_lfsr_iterator (SIZE : natural; CYCLE_STOP_STATE : boolean) return lfsr_spec;
	
	--Sets initial state for lfsr
	function init_lfsr (SPEC : lfsr_spec) return std_logic_vector;
	function init_lfsr (SPEC : lfsr_spec; START_OFFSET : integer) return std_logic_vector;

	--Advances the LFSR <INPUT> <STEPS> times according to <SPEC>. Returns new LFSR state.
	--<steps> may be negative. In this case it undoes positive steps.
    function step(SPEC : lfsr_spec; INPUT : std_logic_vector; STEPS : integer) return std_logic_vector;
    function step(SPEC : lfsr_spec; INPUT : std_logic_vector) return std_logic_vector;
end lfsr;

package body lfsr is
	--Constants
    type lfsr_polylist is array (NATURAL range <>) of lfsr_poly;
    constant lfsr_poly_lookup : lfsr_polylist(0 to MAX_LFSR_SIZE) := (
            (0,0,0,0),
            (0,0,0,0),
            (0,0,0,0),
            (2,0,0,0),
            (3,0,0,0),
            (3,0,0,0),
            (5,0,0,0),
            (6,0,0,0),
            (6,5,4,0),
            (5,0,0,0),
            (7,0,0,0),
            (9,0,0,0),
            (6,4,1,0),
            (4,3,1,0),
            (5,3,1,0),
            (14,0,0,0),
            (15,13,4,0),
            (14,0,0,0),
            (11,0,0,0),
            (6,2,1,0),
            (17,0,0,0),
            (19,0,0,0),
            (21,0,0,0),
            (18,0,0,0),
            (23,22,17,0),
            (22,0,0,0),
            (6,2,1,0),
            (5,2,1,0),
            (25,0,0,0),
            (27,0,0,0),
            (6,4,1,0),
            (28,0,0,0),
            (22,2,1,0),
            (20,0,0,0),
            (27,2,1,0),
            (33,0,0,0),
            (25,0,0,0),
            (5,4,3,2),
            (6,5,1,0),
            (35,0,0,0),
            (38,21,19,0),
            (38,0,0,0),
            (41,20,19,0),
            (42,38,37,0),
            (43,18,17,0),
            (44,42,41,0),
            (45,26,25,0),
            (42,0,0,0),
            (47,21,20,0),
            (40,0,0,0),
            (49,24,23,0),
            (50,36,35,0),
            (49,0,0,0),
            (52,38,37,0),
            (53,18,17,0),
            (31,0,0,0),
            (55,35,34,0),
            (50,0,0,0),
            (39,0,0,0),
            (58,38,37,0),
            (59,0,0,0),
            (60,46,45,0),
            (61,6,5,0),
            (62,0,0,0),
            (63,61,60,0),
            (47,0,0,0),
            (65,57,56,0),
            (66,58,57,0),
            (59,0,0,0),
            (67,42,40,0),
            (69,55,54,0),
            (65,0,0,0),
            (66,25,19,0),
            (48,0,0,0),
            (73,59,58,0),
            (74,65,64,0),
            (75,41,40,0),
            (76,47,46,0),
            (77,59,58,0),
            (70,0,0,0),
            (79,43,42,0),
            (77,0,0,0),
            (79,47,44,0),
            (82,38,37,0),
            (71,0,0,0),
            (84,58,57,0),
            (85,74,73,0),
            (74,0,0,0),
            (87,17,16,0),
            (51,0,0,0),
            (89,72,71,0),
            (90,8,7,0),
            (91,80,79,0),
            (91,0,0,0),
            (73,0,0,0),
            (84,0,0,0),
            (94,49,47,0),
            (91,0,0,0),
            (87,0,0,0),
            (97,54,52,0),
            (63,0,0,0),
            (100,95,94,0),
            (101,36,35,0),
            (94,0,0,0),
            (103,94,93,0),
            (89,0,0,0),
            (91,0,0,0),
            (105,44,42,0),
            (77,0,0,0),
            (108,103,102,0),
            (109,98,97,0),
            (101,0,0,0),
            (110,69,67,0),
            (104,0,0,0),
            (113,33,32,0),
            (114,101,100,0),
            (115,46,45,0),
            (115,99,97,0),
            (85,0,0,0),
            (111,0,0,0),
            (113,9,2,0),
            (103,0,0,0),
            (121,63,62,0),
            (121,0,0,0),
            (87,0,0,0),
            (124,18,17,0),
            (125,90,89,0),
            (126,0,0,0),
            (126,101,99,0),
            (124,0,0,0),
            (127,0,0,0),
            (130,84,83,0),
            (103,0,0,0),
            (132,82,81,0),
            (77,0,0,0),
            (124,0,0,0),
            (135,11,10,0),
            (116,0,0,0),
            (137,131,130,0),
            (136,134,131,0),
            (111,0,0,0),
            (140,110,109,0),
            (121,0,0,0),
            (142,123,122,0),
            (143,75,74,0),
            (93,0,0,0),
            (145,87,86,0),
            (146,110,109,0),
            (121,0,0,0),
            (148,40,39,0),
            (97,0,0,0),
            (148,0,0,0),
            (151,87,86,0),
            (152,0,0,0),
            (152,27,25,0),
            (154,124,123,0),
            (155,41,40,0),
            (156,131,130,0),
            (157,132,131,0),
            (128,0,0,0),
            (159,142,141,0),
            (143,0,0,0),
            (161,75,74,0),
            (162,104,103,0),
            (163,151,150,0),
            (164,135,134,0),
            (165,128,127,0),
            (161,0,0,0),
            (166,153,151,0)
    );

	function get_lfsr_poly(LFSR_SIZE : natural) return lfsr_poly is
	begin
		assert (MAX_LFSR_SIZE >= LFSR_SIZE) AND (MIN_LFSR_SIZE <= LFSR_SIZE)
		report "LFSR size " & natural'image(LFSR_SIZE) & " is not supported by lfsr_iterators. Supported range is from " & natural'image(MIN_LFSR_SIZE) & " to " & natural'image(MAX_LFSR_SIZE)  & "."
		severity failure;
		
		return lfsr_poly_lookup(LFSR_SIZE);
	end;

    ----CONSTRUCTORS----
	function new_lfsr_iterator (SIZE : natural) return lfsr_spec is
	begin
		return new_lfsr_iterator(SIZE, false);
	end function new_lfsr_iterator;
	
    function new_lfsr_iterator (SIZE : natural; CYCLE_STOP_STATE : boolean) return lfsr_spec is
        variable result : lfsr_spec;
    begin
		result.size := SIZE;
        result.poly := get_lfsr_poly(SIZE);
        result.cycle_stop_state := CYCLE_STOP_STATE;
        return result;
    end;
    

    ----METHODS----
	function init_lfsr (SPEC : lfsr_spec) return std_logic_vector is
		variable result : std_logic_vector(SPEC.size-1 downto 0);
	begin
		result := (others => '0');
		return result;
	end;
	
	function init_lfsr (SPEC : lfsr_spec; START_OFFSET : integer) return std_logic_vector is
	   variable result : std_logic_vector(SPEC.size-1 downto 0);
	begin
	   result := std_logic_vector(to_signed(START_OFFSET, SPEC.size));
	   return result;
	end;
	
    function get_next (SPEC : lfsr_spec; INPUT : std_logic_vector) return std_logic_vector is
		variable next_iter : std_logic_vector(INPUT'high downto 0);
        variable feedback_value : std_logic;
    begin
        feedback_value := INPUT(INPUT'high);
        if SPEC.cycle_stop_state AND is1(INPUT) then
            feedback_value := feedback_value XOR '1';
        end if;

        next_iter(0) := feedback_value;

        for i in 1 to INPUT'high loop
            next_iter(i) := INPUT(i-1);
        end loop;

        for i in 0 to polyparts-1 loop
            if SPEC.poly(i) /= 0 then
                next_iter(SPEC.poly(i)) := next_iter(SPEC.poly(i)) XNOR feedback_value;
            end if;
        end loop;
		
		return next_iter;
    end;

    function get_prev (SPEC : lfsr_spec; INPUT : std_logic_vector) return std_logic_vector is
		variable prev_iter : std_logic_vector(INPUT'high downto 0);
    begin
        for i in 0 to INPUT'high-1 loop
            prev_iter(i) := INPUT(i+1);
        end loop;

        for i in 0 to polyparts-1 loop
            if SPEC.poly(i) /= 0 then
                prev_iter(SPEC.poly(i)) := NOT(prev_iter(SPEC.poly(i)+1)) XOR INPUT(0);
            end if;
        end loop;

        if is1(prev_iter) then
            prev_iter(INPUT'high) := '1' XOR INPUT(0);
        else
            prev_iter(INPUT'high) := INPUT(0);
        end if;

		return prev_iter;
    end;

    function step(SPEC : lfsr_spec; INPUT : std_logic_vector; STEPS : integer) return std_logic_vector is
    begin
		assert (SPEC.size) = (INPUT'HIGH + 1)
		report "LFSR-Specification does not match INPUT length. SPEC.size:"
				& natural'IMAGE(SPEC.size) & " INPUT length: " & natural'IMAGE(INPUT'HIGH + 1)
		severity error;
		

        if STEPS > 0 then
            return get_next(SPEC, step(SPEC, INPUT, STEPS - 1));
        elsif STEPS < 0 then
            return get_next(SPEC, step(SPEC, INPUT, STEPS + 1));
        else
            return INPUT;
        end if;
    end;

    function step(SPEC : lfsr_spec; INPUT : std_logic_vector) return std_logic_vector is
    begin
        return step(SPEC, INPUT, 1);
    end;
end lfsr;
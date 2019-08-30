library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library vaxis;

entity varlen_predicate_core is
Generic (
	MATCHWIDTH : natural := 4;
	INSTR_COUNT_LOG2 : natural := 10;
	INSTR_BRANCHES_COUNT : natural := 5
);
Port (
	clk : in std_logic;
	rstn : in std_logic;

	TDATA_memconf_s : in std_logic_vector(25*8-1 downto 0);
	TVALID_memconf_s : in std_logic;
	
	TDATA_s  : in std_logic_vector((MATCHWIDTH*8)-1 downto 0);
	TREADY_s : out std_logic_vector(MATCHWIDTH-1 downto 0);

	TDATA_m  : out std_logic_vector(8-1 downto 0);
	TVALID_m : out std_logic
);
end varlen_predicate_core;

architecture Behavioral of varlen_predicate_core is
	constant INSTR_BRANCHES_COUNT_LOG2 : natural := log2_nat(INSTR_BRANCHES_COUNT);
	constant SYMBOL_ID : natural := log2_nat(MATCHWIDTH);

	subtype symbol is std_logic_vector(8-1 downto 0);
	type sym_vec is array (natural range <>) of symbol;

	type sym_id_vec is array (natural range <>) of unsigned(SYMBOL_ID-1 downto 0);

	subtype jmp_addr is unsigned(INSTR_COUNT_LOG2-1 downto 0);
	type jump_addr_vec is array (natural range <>) of jmp_addr;	

	type instruction_match_decode_tuple is record
		branch_id			: natural range 0 to INSTR_BRANCHES_COUNT-1;
		consumed_char_cnt	: natural range 0 to MATCHWIDTH;
	end record instruction_match_decode_tuple;
	type single_instruction_match_decode_list is array (natural range <>) of instruction_match_decode_tuple;

	type vlen_instruction is record
		matchword			: sym_vec(MATCHWIDTH-1 downto 0);							-- 32bit
		replacement_pos		: sym_id_vec(MATCHWIDTH-1 downto 0);								--+ 8bit
		jmp_vector			: jump_addr_vec(INSTR_BRANCHES_COUNT-1 downto 0);					--+50bit
		match_decode_vec	: single_instruction_match_decode_list(2**MATCHWIDTH-1 downto 0);				--+96bit
		required_matchwords	: unsigned(SYMBOL_ID-1 downto 0);								--+ 2bit
		is_valid_end_state	: std_logic;											--+ 1bit
		is_end_state        : std_logic;											--+ 1bit
	end record vlen_instruction;													--------
	type instr_mem is array (natural range <>) of vlen_instruction;					                                --190bit

	signal matchword_buffer, matchword_buffer_reg  : sym_vec(MATCHWIDTH-1 downto 0);
	signal valid_matchwords, valid_matchwords_reg : unsigned(SYMBOL_ID-1 downto 0);
	signal next_instruction, next_instruction_reg : vlen_instruction;
	signal read_position, read_position_reg: unsigned(SYMBOL_ID-1 downto 0);
    --signal consumed_chars_total : unsigned(11-1 downto 0);
    
    signal mem_read_addr : unsigned (INSTR_COUNT_LOG2-1 downto 0);
    signal mem_read_data : std_logic_vector(190-1 downto 0);
begin

	main: process (clk)
		variable tmp_matchword_buffer : sym_vec(MATCHWIDTH-1 downto 0);
		variable read_position_offset : unsigned(SYMBOL_ID-1 downto 0);
		variable match_result : unsigned(MATCHWIDTH-1 downto 0);
		variable matched_char_count : natural range 0 to MATCHWIDTH;
		variable next_addr : unsigned (INSTR_COUNT_LOG2-1 downto 0);
	begin
		if rising_edge(clk) then
			if is1(rstn) then

				TREADY_s <= (others => '0');
				TVALID_m <= '0';

				assert NOT(valid_matchwords > next_instruction.required_matchwords) report "Matchword residue is greater than required!" severity error;

				read_position_offset := read_position;
				for i in 0 to MATCHWIDTH-1 loop
				    if i < next_instruction.required_matchwords then 
                        if i < valid_matchwords then
                            tmp_matchword_buffer(i) := matchword_buffer(i);
                        else
                            tmp_matchword_buffer(i) := TDATA_s(to_integer(read_position_offset*8-1) downto 0);
                            TREADY_s(to_integer(read_position_offset)) <= '1';
                            read_position_offset := read_position_offset + 1;
                        end if;
					end if;
				end loop;
				read_position_reg <= read_position_offset;

				for i in 0 to MATCHWIDTH-1 loop
					if tmp_matchword_buffer(to_integer(next_instruction.replacement_pos(i))) = next_instruction.matchword(i) then
						match_result(i) := '1';
					else
						match_result(i) := '0';
					end if;
				end loop;
				
				
				next_addr := next_instruction.jmp_vector(next_instruction.match_decode_vec(to_integer(match_result)).branch_id);
				mem_read_addr <= next_addr; 

				matched_char_count := next_instruction.match_decode_vec(to_integer(match_result)).consumed_char_cnt;
				--consumed_chars_total <= consumed_chars_total + matched_char_count;
				for i in 0 to MATCHWIDTH-1 loop
				    read_position_offset := to_unsigned(i, SYMBOL_ID) + matched_char_count;
                    matchword_buffer_reg(i) <= tmp_matchword_buffer(to_integer(read_position_offset));
				end loop;

				valid_matchwords_reg <= next_instruction.required_matchwords - matched_char_count;

                if is1(next_instruction.is_end_state) then
                    if is1(next_instruction.is_valid_end_state) then
                        TDATA_m <= (others => '1');
                        TVALID_m <= '1';
                    else
                        TDATA_m <= (others => '0');
                        TVALID_m <= '1';
                    end if;
                end if;
				
                matchword_buffer <= matchword_buffer_reg;
                valid_matchwords <= valid_matchwords_reg;
                next_instruction <= next_instruction_reg;
                read_position    <= read_position_reg;
                
			end if;
		end if;
	end process;

	convert_mem_read: process (mem_read_data)
	   variable counter : natural;
	begin
		counter := 0;
		
		next_instruction_reg.is_valid_end_state <= mem_read_data(counter);
		counter := counter + 1;

		next_instruction_reg.is_end_state <= mem_read_data(counter);
		counter := counter + 1;
		
        next_instruction_reg.required_matchwords <= unsigned(mem_read_data(counter+2-1 downto counter));
		counter := counter + 2;

        for i in 0 to MATCHWIDTH-1 loop
            next_instruction_reg.matchword(i) <= mem_read_data(counter+8-1 downto counter);
            counter := counter + 8;
		end loop;
		
        for i in 0 to MATCHWIDTH-1 loop
            next_instruction_reg.replacement_pos(i) <= unsigned(mem_read_data(counter+2-1 downto counter));
            counter := counter + 2;
		end loop;

        for i in 0 to INSTR_BRANCHES_COUNT-1 loop
            next_instruction_reg.jmp_vector(i) <= unsigned(mem_read_data(counter+10-1 downto counter));
            counter := counter + 10;
		end loop;
		
        for i in 0 to 2**MATCHWIDTH-1 loop
            next_instruction_reg.match_decode_vec(i).branch_id <= to_integer(unsigned(mem_read_data(counter+3-1 downto counter)));
            counter := counter + 3;
            next_instruction_reg.match_decode_vec(i).consumed_char_cnt <= to_integer(unsigned(mem_read_data(counter+3-1 downto counter)));
            counter := counter + 3;
		end loop;
	end process;
	
	mem: entity vaxis.xilinx_configram_simple_dual_port
    generic map (
         AWIDTH => 10,
         DWIDTH => 190,
         MEMORY_TYPE => "block",
         DELAY_PIPELINE_DEPTH => 1
    ) port map (
         clk => clk,
         wea => TVALID_memconf_s,
         mem_en => '1',
         dina => TDATA_memconf_s(200-1 downto 10),  
         addra => TDATA_memconf_s(10-1 downto  0),
         addrb => std_logic_vector(mem_read_addr),
         doutb => mem_read_data
    );

end Behavioral;


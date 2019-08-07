library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;

entity cam_kvstore is
generic (
    KEYSIZE : natural;
    VALUESIZE : natural;
    MEMDEPTH_BASE2 : natural
);
port (
    clk : in std_logic;
    rst_n : in std_logic;
    
    key : in std_logic_vector(KEYSIZE-1 downto 0);
    value_in : in std_logic_vector(VALUESIZE-1 downto 0);
    input_valid : in std_logic;
    do_insert : in std_logic;
    
    output : out std_logic_vector(VALUESIZE-1 downto 0);
	no_match : out std_logic;
    output_valid : out std_logic
);
end cam_kvstore;

architecture Behavioral of cam_kvstore is
    constant MEMSIZE : natural := 2**MEMDEPTH_BASE2;

    type entry is record
        key : std_logic_vector(KEYSIZE-1 downto 0);
        value : std_logic_vector(VALUESIZE-1 downto 0);
        valid : std_logic;
    end record entry;
    type entryvec is array (natural range <>) of entry;
    
    signal mem : entryvec(MEMSIZE-1 downto 0);
    
    --first to second pipeline stage buffer
    signal key_fsb : std_logic_vector(KEYSIZE-1 downto 0);
    signal value_fsb : std_logic_vector(VALUESIZE-1 downto 0);
    signal do_insert_fsb : std_logic;
    signal input_valid_fsb : std_logic;
    
    signal matchvec : std_logic_vector(MEMSIZE-1 downto 0);
    
    --second to third pipeline stage buffer
    signal key_ssb : std_logic_vector(KEYSIZE-1 downto 0);
    signal value_ssb : std_logic_vector(VALUESIZE-1 downto 0);
    signal do_insert_ssb : std_logic;
    signal input_valid_ssb : std_logic;
    
	signal memaddr : unsigned(MEMDEPTH_BASE2-1 downto 0);
	signal memaddr_nomatch : std_logic;
	
	signal memiterator : unsigned(MEMDEPTH_BASE2-1 downto 0);
begin

    cam_match_stage: process(clk, rst_n)
    begin
        if rst_n = '0' then
            input_valid_fsb <= '0';
        elsif rising_edge(clk) then
            input_valid_fsb <= input_valid;
            key_fsb <= key;
            value_fsb <= value_in;
            do_insert_fsb <= do_insert;
            
            for i in MEMSIZE-1 downto 0 loop
                if mem(i).key = key then
                    matchvec(i) <= '1';
                else
                    matchvec(i) <= '0';
                end if;
            end loop;
        end if;
    end process;

    prioenc_stage: process(clk, rst_n)
    begin
        if rst_n = '0' then
            input_valid_ssb <= '0';
        elsif rising_edge(clk) then
            input_valid_ssb <= input_valid_fsb;
            key_ssb <= key_fsb;
            value_ssb <= value_fsb;
            do_insert_ssb <= do_insert_fsb;
            
            memaddr_nomatch <= '1';
            for i in MEMSIZE-1 downto 0 loop
                if matchvec(i) = '1' then
                    memaddr <= to_unsigned(i, MEMDEPTH_BASE2);
                    memaddr_nomatch <= '0';
                end if;
            end loop;
        end if;
    end process;

    memop_stage: process(clk, rst_n)
    begin
        if rst_n = '0' then
			output_valid <= '0';
            memiterator <= (others => '0'); 
			for i in MEMSIZE-1 downto 0 loop
                mem(i).valid <= '0';
			end loop;
        elsif rising_edge(clk) then
            output_valid <= '0';
        
            if input_valid_ssb = '1' then
                if do_insert_ssb = '1' then
                    if memaddr_nomatch = '1' then
                        mem(to_integer(memiterator)).key <= key_ssb;
                        mem(to_integer(memiterator)).value <= value_ssb;
                        mem(to_integer(memiterator)).valid <= '1';
                        memiterator <= memiterator + 1;
                    else
                        mem(to_integer(memaddr)).key <= key_ssb;
                        mem(to_integer(memaddr)).value <= value_ssb;
                    end if;
                else
                    output <= mem(to_integer(memaddr)).value;
                    output_valid <= '1';
                    no_match <= memaddr_nomatch OR NOT(mem(to_integer(memaddr)).valid);
                end if;
            end if;
			
        end if;
    end process;

end Behavioral;
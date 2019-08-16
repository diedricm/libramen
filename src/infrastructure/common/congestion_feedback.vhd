library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
    use libcommons.misc.ALL;
    use libcommons.lfsr.ALL;
library libramen;
    use libramen.core_pkg.ALL;

entity vaxis_congestion_feedback is
generic (
	TUPPLE_COUNT : natural := 1;
    BACKOFF_DETECTION_PERIOD : natural := 3;
    CIRCUIT_SETUP_PROBE_PERIOD : natural := 3
);
Port (
    clk : in std_logic;
    rstn : in std_logic;
    
    trigger_backoff : in std_logic;

    stream_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_s_status : in stream_status;
    stream_s_ready : out std_logic;
	
    stream_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_m_status : out stream_status;
    stream_m_ready : in std_logic
);
end vaxis_congestion_feedback;

architecture Behavioral of vaxis_congestion_feedback is
	-- State diagram:
	--
	--   +--------------+
	--   |     Await    |
	--   |    Backoff   |<-----------------+
	--   |    Request   |                  |
	--   +--------------+                  |
	--          |                          |
	--          |-backoff=1                |
	--          |                          |
    --          v                          |
	--   +--------------+                  |
	--   |     Block    |                  |-idle counter=0
	--   |    circuit   |                  |
	--   +--------------+                  |
	--          |                          |
	--          |-backoff counter=0        |
	--          |                          |
	--          v                          |
	--   +--------------+                  |
	--   |     IDLE     |------------------+
	--   +--------------+

	type unit_state is (AWAIT_BACKOFF_REQ, BLOCK_CIRCUIT, IDLE);
	signal curr_state : unit_state := AWAIT_BACKOFF_REQ;

    signal backoff_counter : natural;
    signal idle_counter : natural;

    signal transmission_active : std_logic;
    
    signal stream_reg_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_reg_status : stream_status;
    signal stream_reg_ready : std_logic;
begin

    
    main: process (clk)
    begin
        if rising_edge(clk) then
        	if rstn = '1' then
        		if (trigger_backoff = '1') AND (curr_state = AWAIT_BACKOFF_REQ) then
					curr_state <= BLOCK_CIRCUIT;
					backoff_counter <= BACKOFF_DETECTION_PERIOD;
        		end if;

    			if curr_state = BLOCK_CIRCUIT then
    				if backoff_counter /= 0 then
    					backoff_counter <= backoff_counter - 1;
					else
						curr_state <= IDLE;
						idle_counter <= CIRCUIT_SETUP_PROBE_PERIOD;
    				end if;
    			end if;

    			if curr_state = IDLE then
    				if idle_counter /= 0 then
    					idle_counter <= idle_counter - 1;
					else
						curr_state <= AWAIT_BACKOFF_REQ;
    				end if;
    			end if;

            end if;
        end if;
    end process;
    
    transmission_active <= '1' when (curr_state /= BLOCK_CIRCUIT) else '0';
    stream_reg_status.valid <= stream_s_status.valid AND transmission_active;
    stream_s_ready <= stream_reg_ready AND transmission_active;
	stream_reg_tuples <= stream_s_tuples;
	stream_reg_status.ptype <= stream_s_status.ptype;
	stream_reg_status.yield <= '0';
	stream_reg_status.cdest <= stream_s_status.cdest;
	
    regslice: entity libramen.stream_register_slice 
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT
    ) port map (
        clk => clk,
        rstn => rstn,

        stream_s_tuples => stream_reg_tuples,
        stream_s_status => stream_reg_status,
        stream_s_ready => stream_reg_ready,
        stream_s_ldest => (others => '-'),

        stream_m_tuples => stream_m_tuples,
        stream_m_status => stream_m_status,
        stream_m_ready => stream_m_ready,
        stream_m_ldest => OPEN
    );
end Behavioral;
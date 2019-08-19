library IEEE;
	use IEEE.STD_LOGIC_1164.ALL;
	use IEEE.NUMERIC_STD.ALL;
library libcommons;
	use libcommons.misc.ALL;
library libramen;
    use libramen.core_pkg.ALL;
    
entity vaxis_congestion_backoff is
generic (
	TUPPLE_COUNT : natural := 1;
	BACKOFF_DETECTION_PERIOD : natural := 2;
	CIRCUIT_SETUP_PROBE_PERIOD : natural := 4
);
Port (
	clk : in std_logic;
	rstn : in std_logic;

	backoff : out std_logic;
	
    stream_s_tuples  : in tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_s_status : in stream_status;
    stream_s_ready : out std_logic;
	
    stream_m_tuples  : out tuple_vec(TUPPLE_COUNT-1 downto 0);
    stream_m_status : out stream_status;
    stream_m_ready : in std_logic
);
end vaxis_congestion_backoff;

architecture Behavioral of vaxis_congestion_backoff is
	-- State diagram:
	--
	--   +--------------+
	--   |     Await    |   
	--   |   Connection | <-------------------------+<------------+
	--   |    Request   |                           ^             |
	--   +--------------+                           |             |
	--          |                                   |             |-buffer empty
	--          |-input.valid=1                     |             |
	--          |                                   |             |
    --          v                                   |             |
	--   +--------------+                           |      +--------------+
	--   |              | congestion counter=0      |      | CLEAR BUFFER |
	--   | INIT  Ciruit |---------------------------+      +--------------+
    --   |              |     OR new dest                         ^
	--   +--------------+                                         |
	--          |                                                 |
	--          |-transmit(M)                         transmit(R)-|
	--          |                                                 |
	--          |                                                 |
	--    +-------------+        congestion counter=0       +-----------+
	--    |PROBE circuit|---------------------------------->| Terminate |
	--    +-------------+            OR new dest            +-----------+
	--          |                                                 ^
	--          |                                                 |
	--          |-probe counter=0                                 |
	--          |                                                 |
	--          v                                                 |
	--   +--------------+                                         |
	--   | Await backoff|            congestion counter=0         |
	--   |    signal    |-----------------------------------------+
	--   +--------------+          OR new dest OR hardend
	               
	type backoff_state_type is (AWAIT_CONN_REQ, INIT_CIRCUIT, PROBE_CIRCUIT, AWAIT_BACKOFF_SIGNAL, TERMINATE, CLEAR_BUFFER);
	signal curr_state : backoff_state_type := AWAIT_CONN_REQ;
	signal next_state : backoff_state_type;
	
	signal circuit_destination : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0) := (others => '0');

	signal detection_counter : natural range 0 to BACKOFF_DETECTION_PERIOD*2;
	signal probe_counter : natural range 0 to CIRCUIT_SETUP_PROBE_PERIOD;

    signal stream_reg_tuples  : tuple_vec(TUPPLE_COUNT-1 downto 0);
    signal stream_reg_status : stream_status;
    signal stream_reg_ready : std_logic;
    signal clear_reg_slice : std_logic;
    signal reset_circuit : std_logic;
    signal buffer_empty : std_logic;
        
    signal stream_s_DEBUG_ACTIVE : std_logic;
    signal stream_m_DEBUG_ACTIVE : std_logic;
begin

    stream_s_DEBUG_ACTIVE <= '1' when is1(clk) AND is1(stream_s_ready) AND is1(stream_s_status.valid) else '0';
    stream_m_DEBUG_ACTIVE <= '1' when is1(clk) AND is1(stream_m_ready) AND is1(stream_m_status.valid) else '0';

	counters: process (clk)
	begin
		if rising_edge(clk) then
            curr_state <= next_state;

			if rstn = '1' then

				if stream_reg_ready = '1' then
				    if (curr_state = INIT_CIRCUIT) then
				        detection_counter <= BACKOFF_DETECTION_PERIOD*2;
				    else
                        detection_counter <= BACKOFF_DETECTION_PERIOD;
                    end if;
				else
					if detection_counter /= 0 then
						detection_counter <= detection_counter - 1;
					end if;
				end if;

				if (probe_counter /= 0) AND is1(stream_reg_ready) then
					probe_counter <= probe_counter - 1;
				end if;

				if (curr_state = AWAIT_CONN_REQ) AND (next_state = INIT_CIRCUIT) then
					circuit_destination <= stream_s_status.cdest;
					detection_counter <= BACKOFF_DETECTION_PERIOD*2;
				end if;
				
				if (curr_state = INIT_CIRCUIT) AND (next_state = PROBE_CIRCUIT) then
                    probe_counter <= CIRCUIT_SETUP_PROBE_PERIOD;
					detection_counter <= BACKOFF_DETECTION_PERIOD;
				end if;
			end if;

		end if;
	end process;

    backoff <= '1' when ((curr_state /= TERMINATE) AND (next_state = TERMINATE)) OR ((curr_state = INIT_CIRCUIT) AND (next_state = AWAIT_CONN_REQ)) else '0';
    clear_reg_slice <= '1' when (curr_state = INIT_CIRCUIT) AND (next_state = AWAIT_CONN_REQ) else '0';
    reset_circuit <= '1' when (detection_counter <= 1) OR (circuit_destination /= stream_s_status.cdest) else '0';
    
	state_transition: process (ALL)
	begin
		next_state <= curr_state;
		case curr_state is
			when AWAIT_CONN_REQ =>
				if is1(stream_s_status.valid) then
					next_state <= INIT_CIRCUIT;
				end if;
				
			when INIT_CIRCUIT =>
				if is1(reset_circuit) then
					next_state <= AWAIT_CONN_REQ;
				end if;

				if is1(stream_m_ready) then
					next_state <= PROBE_CIRCUIT;
				end if;

            when PROBE_CIRCUIT =>
                if is1(reset_circuit) then
					next_state <= TERMINATE;
				end if;
				
                if (probe_counter = 0) then
					next_state <= AWAIT_BACKOFF_SIGNAL;
				end if;

			when AWAIT_BACKOFF_SIGNAL => 
				if is1(reset_circuit) OR is_hardend(stream_s_status) then
					next_state <= TERMINATE;
				end if;

			when TERMINATE =>
				if is1(stream_reg_ready) then
					next_state <= CLEAR_BUFFER;
				end if;
				
            when CLEAR_BUFFER =>
                if is1(buffer_empty) then
                    next_state <= AWAIT_CONN_REQ;
                end if;

		end case;
	end process;

	stream_mux: process (ALL)
	begin
		case curr_state is
			when AWAIT_CONN_REQ => 
				stream_s_ready <= '0';
				stream_reg_status.valid <= '0';
				stream_reg_status.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg_status.yield <= '0';

			when INIT_CIRCUIT => 
				stream_s_ready <= '0';
				stream_reg_status.valid <= '1';
				stream_reg_status.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg_status.yield <= '0';
				
            when PROBE_CIRCUIT => 
				stream_s_ready <= '0';
				stream_reg_status.valid <= '1';
				stream_reg_status.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg_status.yield <= '0';

			when AWAIT_BACKOFF_SIGNAL => 
				stream_s_ready <= stream_reg_ready AND NOT(reset_circuit);
				stream_reg_status.valid <= stream_s_status.valid;
				stream_reg_status.ptype <= stream_s_status.ptype;
				if is_hardend(stream_s_status) then
				    stream_reg_status.yield <= '1';
				else
				    stream_reg_status.yield <= '0';
				end if;

			when TERMINATE => 
				stream_s_ready <= '0';
				stream_reg_status.valid <= '1';
				stream_reg_status.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg_status.yield <= '1';
				
            when CLEAR_BUFFER => 
				stream_s_ready <= '0';
				stream_reg_status.valid <= '0';
				stream_reg_status.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg_status.yield <= '0';

		end case;
	end process;

	stream_reg_status.cdest <= circuit_destination;
	stream_reg_tuples <= stream_s_tuples;
    
    regslice: entity libramen.stream_register_slice 
    generic map (
        TUPPLE_COUNT => TUPPLE_COUNT
    ) port map (
        clk => clk,
        rstn => rstn,
        
        clear => clear_reg_slice,
        is_empty => buffer_empty,
        
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
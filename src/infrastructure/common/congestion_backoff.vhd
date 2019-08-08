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
	
	stream_s  : in flit(tuples(TUPPLE_COUNT-1 downto 0));
	ready_s : out std_logic;
	
	stream_m  : out flit(tuples(TUPPLE_COUNT-1 downto 0));
	ready_m : in std_logic
);
end vaxis_congestion_backoff;

architecture Behavioral of vaxis_congestion_backoff is
	-- State diagram:
	--
	--   +--------------+
	--   |     Await    |      output.ready=1
	--   |   Connection | <-------------------------+
	--   |    Request   |                           |
	--   +--------------+                           |
	--          |                                   |
	--          |-input.valid=1                     |
	--          |                                   |
    --          v                                   |
	--   +--------------+                           |
	--   |              | congestion counter=0 +-----------+
	--   | Probe Ciruit |--------------------->| Terminate |
	--   |              |                      +-----------+
	--   +--------------+                           ^
	--          |                                   |
	--          |-probe counter=0                   |
	--          |                                   |
	--          v                                   |
	--   +--------------+                           |
	--   | Await backoff|  congestion counter=0     |
	--   |    signal    |---------------------------+
	--   +--------------+    OR new TDEST_s
	               
	type backoff_state_type is (AWAIT_CONN_REQ, PROBE_CIRCUIT_SETUP, AWAIT_BACKOFF_SIGNAL, TERMINATE);
	signal curr_state : backoff_state_type := AWAIT_CONN_REQ;
	signal next_state : backoff_state_type;
	
	signal circuit_destination : std_logic_vector(CDEST_SIZE_IN_BIT-1 downto 0) := (others => '0');

	signal detection_counter : natural range 0 to BACKOFF_DETECTION_PERIOD;
	signal probe_counter : natural range 0 to CIRCUIT_SETUP_PROBE_PERIOD;

    signal stream_reg : flit(tuples(TUPPLE_COUNT-1 downto 0));
    signal ready_reg : std_logic;
    
    signal stream_m_axi_enc : flit_axis_packed(data(TUPPLE_COUNT*DATA_SINGLE_SIZE_IN_BYTES-1 downto 0));
begin

	counters: process (clk)
	begin
		if rising_edge(clk) then
			backoff <= '0';

			if rstn = '1' then

				if ready_reg = '1' then
					detection_counter <= BACKOFF_DETECTION_PERIOD;
				else
					if detection_counter /= 0 then
						detection_counter <= detection_counter - 1;
					end if;
				end if;

				if probe_counter /= 0 then
					probe_counter <= probe_counter - 1;
				end if;

				if (curr_state = AWAIT_CONN_REQ) AND (next_state = PROBE_CIRCUIT_SETUP) then
					circuit_destination <= stream_s.cdest;
					probe_counter <= CIRCUIT_SETUP_PROBE_PERIOD;
				end if;

				if (curr_state /= TERMINATE) AND (next_state = TERMINATE) then
					backoff <= '1';
				end if;

			end if;

		end if;
	end process;

	state_transition: process (curr_state, detection_counter, probe_counter, stream_s, circuit_destination)
	begin
		next_state <= curr_state;
		case curr_state is
			when AWAIT_CONN_REQ =>
				if stream_s.valid = '1' then
					next_state <= PROBE_CIRCUIT_SETUP;
				end if;
				
			when PROBE_CIRCUIT_SETUP =>
				if detection_counter = 0 then
					next_state <= TERMINATE;
				end if;

				if (probe_counter = 0) AND (ready_reg = '1') then
					next_state <= AWAIT_BACKOFF_SIGNAL;
				end if;

			when AWAIT_BACKOFF_SIGNAL => 
				if (detection_counter = 0) OR (circuit_destination /= stream_s.cdest) then
					next_state <= TERMINATE;
				end if;

			when TERMINATE =>
				if ready_reg = '1' then
					next_state <= AWAIT_CONN_REQ;
				end if;

		end case;
	end process;

	stream_mux: process (curr_state, stream_reg, stream_s, stream_m)
	begin
		case curr_state is
			when AWAIT_CONN_REQ =>
				ready_s <= '0';
				stream_reg.valid <= '0';
				stream_reg.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg.yield <= '0';

			when PROBE_CIRCUIT_SETUP =>
				ready_s <= '0';
				stream_reg.valid <= '1';
				stream_reg.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg.yield <= '0';

			when AWAIT_BACKOFF_SIGNAL => 
				ready_s <= ready_m;
				stream_reg.valid <= stream_s.valid;
				stream_reg.ptype <= stream_s.ptype;
				stream_reg.yield <= stream_s.yield;

			when TERMINATE =>
				ready_s <= '0';
				stream_reg.valid <= '1';
				stream_reg.ptype <= TLAST_MASK_SOFTEND_NO_DATA;
				stream_reg.yield <= '1';

		end case;
	end process;

	stream_reg.cdest <= circuit_destination;
	stream_reg.tuples <= stream_s.tuples;
    
    stream_m <= axis_to_flit(stream_m_axi_enc);
    regslice: entity libramen.axis_register_slice
    generic map (
        TDATA_WIDTH => TUPPLE_COUNT*DATA_SINGLE_SIZE_IN_BYTES,
        TDEST_WIDTH => CDEST_SIZE_IN_BIT,
        TUSER_WIDTH => PTYPE_SIZE_IN_BIT
    ) port map (
        clk => clk,
        rstn => rstn,
        
        TDATA_s  => flit_to_axis(stream_reg).data,
        TVALID_s => flit_to_axis(stream_reg).valid,
        TREADY_s => ready_reg,
        TDEST_s  => flit_to_axis(stream_reg).dest,
        TUSER_s  => flit_to_axis(stream_reg).user,
        TLAST_s  => flit_to_axis(stream_reg).last,
        
        TDATA_m  => stream_m_axi_enc.data,
        TVALID_m => stream_m_axi_enc.valid,
        TREADY_m => ready_m,
        TDEST_m  => stream_m_axi_enc.dest,
        TUSER_m  => stream_m_axi_enc.user,
        TLAST_m  => stream_m_axi_enc.last
    );

end Behavioral;
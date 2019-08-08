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

	stream_s  : in flit(tuples(TUPPLE_COUNT-1 downto 0));
	ready_s : out std_logic;
	
	stream_m  : out flit(tuples(TUPPLE_COUNT-1 downto 0));
	ready_m : in std_logic
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
    
    signal stream_reg : flit(tuples(TUPPLE_COUNT-1 downto 0));
    signal ready_reg : std_logic;	
    
    signal stream_m_axi_enc : flit_axis_packed(data(TUPPLE_COUNT*DATA_SINGLE_SIZE_IN_BYTES-1 downto 0));
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
    stream_reg.valid <= stream_s.valid AND transmission_active;
    ready_s <= ready_reg AND transmission_active;
	stream_reg.tuples <= stream_s.tuples;
	stream_reg.ptype <= stream_s.ptype;
	stream_reg.yield <= '0';
	stream_reg.cdest <= stream_s.cdest;
	
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
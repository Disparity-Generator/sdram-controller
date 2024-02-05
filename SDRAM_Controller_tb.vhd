library ieee;
  use ieee.std_logic_1164.all;
  use ieee.numeric_std.all;
  use std.textio.all;
  use ieee.std_logic_textio.all;

entity SDRAM_CONTROLLER_TB is -- keine Schnittstellen
end entity SDRAM_CONTROLLER_TB;

architecture ARCH of SDRAM_CONTROLLER_TB is

  -- constant c_max_address      : integer := 10;
  constant c_max_address      : integer := 2000;

  type states_t is (WRITE, READ, FINISHED);

  signal w_next_state         : states_t;

  ------------------sdram--------------------------------
  signal w_sdram_initialized  : std_logic;

  signal r_state              : states_t := write;
  signal w_sdram_addr         : unsigned(24 downto 0);
  signal w_sdram_rdval        : std_logic;
  signal w_sdram_we_n         : std_logic;
  signal w_sdram_writedata    : std_logic_vector(31 downto 0);
  signal w_sdram_ack          : std_logic;

  signal w_dqml               : std_logic;
  signal w_dqmh               : std_logic;

  signal w_sdram_readdata     : std_logic_vector(31 downto 0);
  signal w_sdram_req          : std_logic;

  ---------------anwendung-----------------------------------
  signal r_ram_write_pointer  : integer range 0 to c_max_address := 0; -- 480*640 = 307.200

  -- Der Integer wird bei -1 initialisiert und nimmt diesen Zustand dann nie wieder ein.
  -- So kann überprüft werden, ob schon einmal gelesen wurde.
  -- Dies ist nötig für die write_ready flag beim ersten Durchlauf.
  signal r_ram_read_pointer   : integer range 0 to c_max_address := 0; -- 480*640 = 307.200

  signal w_clock              : std_logic;
  signal w_reset_n            : std_logic;

  signal w_dram_addr          : unsigned(12 downto 0);
  signal w_dram_ba            : unsigned(1 downto 0);
  signal w_dram_dq            : std_logic_vector(31 downto 0);
  signal w_dram_cke           : std_logic;
  signal w_dram_cs            : std_logic;
  signal w_dram_ras           : std_logic;
  signal w_dram_cas           : std_logic;
  signal w_dram_we            : std_logic;
  signal w_dram_dqml          : std_logic;
  signal w_dram_dqmh          : std_logic;
  signal w_sdram_clock : std_logic;

  signal dram_write_enable : std_logic;

  component SDRAM_CONTROLLER is
    generic (
      G_CLK_FREQ           : real := 50.0;

      G_ADDR_WIDTH         : natural := 25;

      G_SDRAM_ADDR_WIDTH   : natural := 13;
      G_SDRAM_DATA_WIDTH   : natural := 32;
      G_SDRAM_COL_WIDTH    : natural := 10;
      G_SDRAM_ROW_WIDTH    : natural := 13;
      G_SDRAM_BANK_WIDTH   : natural := 2;

      G_CAS_LATENCY        : natural := 2;

      G_BURST_LENGTH       : natural := 1;

      G_WRITE_BURST_MODE   : std_logic := '0';

      G_T_DESL             : real := 200000.0;
      G_T_MRD              : real := 15.0;
      G_T_RC               : real := 60.0;
      G_T_RCD              : real := 15.0;
      G_T_RP               : real := 15.0;
      G_T_WR               : real := 15.0;
      G_T_REFI             : real := 7812.5;
      -- 7812.5
      -- 1953.0
      G_USE_AUTO_PRECHARGE : std_logic := '0'
    );
    port (
      I_RESET_N           : in    std_logic := '1';
      I_CLOCK             : in    std_logic;
      I_ADDRESS           : in    unsigned(G_ADDR_WIDTH - 1 downto 0);
      I_DATA              : in    std_logic_vector(G_SDRAM_DATA_WIDTH - 1 downto 0);
      I_WRITE_ENABLE      : in    std_logic;
      I_REQUEST           : in    std_logic;
      O_ACKNOWLEDGE       : out   std_logic;
      O_VALID             : out   std_logic;
      O_Q                 : out   std_logic_vector(G_SDRAM_DATA_WIDTH - 1 downto 0);
      O_SDRAM_A           : out   unsigned(G_SDRAM_ADDR_WIDTH - 1 downto 0);
      O_SDRAM_BA          : out   unsigned(G_SDRAM_BANK_WIDTH - 1 downto 0);
      IO_SDRAM_DQ         : inout std_logic_vector(G_SDRAM_DATA_WIDTH - 1 downto 0);
      O_SDRAM_CKE         : out   std_logic;
      O_SDRAM_CS          : out   std_logic;
      O_SDRAM_RAS         : out   std_logic;
      O_SDRAM_CAS         : out   std_logic;
      O_SDRAM_WE          : out   std_logic;
      O_SDRAM_DQML        : out   std_logic;
      O_SDRAM_DQMH        : out   std_logic;
      O_SDRAM_INITIALIZED : out   std_logic
    );
  end component sdram_controller;

  component SDRAM_DE2_115_WRAPPER is
    port(
    I_CLOCK : in std_logic;
    I_SDRAM_A           : in   unsigned(13 - 1 downto 0);
     I_SDRAM_BA          : in   unsigned(2 - 1 downto 0);
     IO_SDRAM_DQ         : inout std_logic_vector(32 - 1 downto 0);
     I_SDRAM_CKE         : in   std_logic;
     I_SDRAM_CS          : in   std_logic;
     I_SDRAM_RAS         : in   std_logic;
     I_SDRAM_CAS         : in   std_logic;
     I_SDRAM_WE          : in   std_logic;
     I_SDRAM_DQML        : in   std_logic;
     I_SDRAM_DQMH        : in   std_logic
    );
  end component SDRAM_DE2_115_WRAPPER;

begin

  U3 : SDRAM_CONTROLLER
    port map (
      -- reset
      I_RESET_N           => w_reset_n,
      I_CLOCK             => w_clock,
      I_ADDRESS           => w_sdram_addr,
      I_DATA              => w_sdram_writedata,
      I_WRITE_ENABLE      => dram_write_enable,
      I_REQUEST           => w_sdram_req,
      O_ACKNOWLEDGE       => w_sdram_ack,
      O_VALID             => w_sdram_rdval,
      O_Q                 => w_sdram_readdata,
      O_SDRAM_A           => w_dram_addr,
      O_SDRAM_BA          => w_dram_ba,
      IO_SDRAM_DQ         => w_dram_dq,
      O_SDRAM_CKE         => w_dram_cke,
      O_SDRAM_CS          => w_dram_cs,
      O_SDRAM_RAS         => w_dram_ras,
      O_SDRAM_CAS         => w_dram_cas,
      O_SDRAM_WE          => w_dram_we,
      O_SDRAM_DQML        => w_dqml,
      O_SDRAM_DQMH        => w_dqmh,
      O_SDRAM_INITIALIZED => w_sdram_initialized
    );

    ram_model : SDRAM_DE2_115_WRAPPER 
    port map(
        I_CLOCK => w_sdram_clock,
        I_SDRAM_A           => w_dram_addr,
        I_SDRAM_BA          => w_dram_ba,
        IO_SDRAM_DQ         => w_dram_dq,
        I_SDRAM_CKE         => w_dram_cke,
        I_SDRAM_CS          => w_dram_cs,
        I_SDRAM_RAS         => w_dram_ras,
        I_SDRAM_CAS         => w_dram_cas,
        I_SDRAM_WE          => w_dram_we,
        I_SDRAM_DQML        => w_dqml,
        I_SDRAM_DQMH        => w_dqmh
    );

  P_CLK : process is

  begin
    wait for 3 ns;
  while true loop
    
    w_clock <= '1';
    wait for 10 ns;
    w_clock <= '0';
    wait for 10 ns;
  end loop;
    
  end process P_CLK;
  
  P_RAM_CLK : process is

  begin
    

    while true loop
      w_sdram_clock <= '1';
      wait for 10 ns;
      w_sdram_clock <= '0';
      wait for 10 ns;
    end loop;

  end process P_RAM_CLK;

  --------------------------------------------
  -- read/write state machine and registers --
  --------------------------------------------

  -- 24 downto 0 -> c_max_address

  dram_write_enable <= not w_sdram_we_n;
  w_sdram_writedata <= std_logic_vector(to_unsigned(r_ram_write_pointer, w_sdram_writedata'length));
  -- w_sdram_clock <= w_clock;

  PROC_STATE_OUT : process (r_ram_write_pointer, r_ram_read_pointer) is

  begin

    case r_state is

      when write =>

        if (r_ram_write_pointer >= c_max_address) then
          w_next_state <= read;
        else
          w_next_state <= write;
        end if;

        w_sdram_addr <= to_unsigned(r_ram_write_pointer, w_sdram_addr'length);
        w_sdram_we_n <= '0';

        w_sdram_req  <= '1';
        w_sdram_we_n <= '0';

      when read =>

        if (w_sdram_ack = '1' and r_ram_read_pointer >= c_max_address - 1) then
          w_next_state <= finished;
        else
          w_next_state <= read;
        end if;

        w_sdram_addr <= to_unsigned(r_ram_read_pointer, w_sdram_addr'length);
        w_sdram_we_n <= '1';
        w_sdram_req <= '1';

      when finished =>
        w_next_state <= finished;

    end case;

  end process PROC_STATE_OUT;

  PROC_SYNCHRONOUS : process (w_reset_n, w_clock) is
  begin

    if (w_reset_n = '0') then
      r_state             <= write;
      r_ram_read_pointer  <= 0;
      r_ram_write_pointer <= 0;
    elsif (rising_edge(w_clock)) then
      r_state <= w_next_state;

      case r_state is

        when write =>
          if (w_sdram_ack = '1') then
            if (r_ram_write_pointer < c_max_address) then
              r_ram_write_pointer <= r_ram_write_pointer + 1;
            else
              r_ram_write_pointer <= 0;
            end if;
          end if;

        when read =>
          if (w_sdram_ack = '1') then
            if (r_ram_read_pointer < c_max_address - 1) then
              r_ram_read_pointer <= r_ram_read_pointer + 1;
            else
              r_ram_read_pointer <= 0;
            end if;
          end if;

        when finished =>

      end case;

    end if;

  end process PROC_SYNCHRONOUS;

end architecture ARCH;

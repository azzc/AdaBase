--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

package body AdaBase.Connection.Base.PostgreSQL is

   ---------------------
   --  setCompressed  --
   ---------------------
   overriding
   procedure setCompressed (conn : out PostgreSQL_Connection; compressed : Boolean)
   is
   begin
      raise UNSUPPORTED_BY_PGSQL;
   end setCompressed;


   ------------------
   --  compressed  --
   ------------------
   overriding
   function compressed (conn : PostgreSQL_Connection) return Boolean is
   begin
      return False;
   end compressed;


   --------------------
   --  setUseBuffer  --
   --------------------
   overriding
   procedure setUseBuffer (conn : out PostgreSQL_Connection;
                           buffered : Boolean) is
   begin
      raise UNSUPPORTED_BY_PGSQL;
   end setUseBuffer;


   -----------------
   --  useBuffer  --
   -----------------
   overriding
   function useBuffer (conn : PostgreSQL_Connection) return Boolean is
   begin
      return False;
   end useBuffer;


   ---------------------
   --  driverMessage  --
   ---------------------
   overriding
   function driverMessage (conn : PostgreSQL_Connection) return String
   is
      result : BND.ICS.chars_ptr := BND.PQerrorMessage (conn.handle);
   begin
      return BND.ICS.Value (result);
   end driverMessage;


   ------------------
   --  driverCode  --
   ------------------
   overriding
   function driverCode (conn : PostgreSQL_Connection) return DriverCodes is
   begin
      if conn.cmd_sql_state = stateless or else
        conn.cmd_sql_state = "00000"
      then
         return 0;
      end if;
      if conn.cmd_sql_state (1 .. 2) = "01" then
         return 1;
      end if;
      return 2;
   end driverCode;


   ----------------------------
   --  SqlState (interface)  --
   ----------------------------
   overriding
   function SqlState (conn : PostgreSQL_Connection) return TSqlState is
   begin
      return conn.cmd_sql_state;
   end SqlState;


   -------------------
   --  SqlState #2  --
   -------------------
   function SqlState (conn : PostgreSQL_Connection; res : BND.PGresult_Access)
                      return TSqlState
   is
      fieldcode : constant BND.IC.int := BND.PG_DIAG_SQLSTATE;
      detail    : BND.ICS.chars_ptr;
   begin
      detail := BND.PQresultErrorField (res, fieldcode);
      return BND.ICS.Value (detail);
   end SqlState;


   -------------------
   --  description  --
   -------------------
   overriding
   function description (conn : PostgreSQL_Connection) return String
   is
   begin
      return conn.info_description;
   end description;


   -----------------------
   --  private_execute  --
   -----------------------
   procedure private_execute (conn : out PostgreSQL_Connection; sql : String)
   is
      use type BND.ExecStatusType;
      pgres   : BND.PGresult_Access;
      query   : BND.ICS.chars_ptr := BND.ICS.New_String (Str => sql);
      success : Boolean;
   begin
      pgres := BND.PQexec (conn => conn.handle, command => query);

      BND.ICS.Free (query);
      success := (BND.PQresultStatus (pgres) = BND.PGRES_COMMAND_OK);
      conn.cmd_sql_state := conn.SqlState (pgres);

      if success then
         conn.cmd_rows_impact := conn.rows_affected_by_execution (pgres);
      else
         conn.cmd_rows_impact := 0;
      end if;

      BND.PQclear (pgres);

      if not success then
         raise QUERY_FAIL;
      end if;

   end private_execute;


   ----------------------------------------------
   --  rows_affected_by_execution (interface)  --
   ----------------------------------------------
   overriding
   function rows_affected_by_execution (conn : PostgreSQL_Connection)
                                        return AffectedRows is
   begin
      return conn.cmd_rows_impact;
   end rows_affected_by_execution;


   -------------------------------------
   --  rows_affected_by_execution #2  --
   -------------------------------------
   function rows_affected_by_execution (conn : PostgreSQL_Connection;
                                        res  : BND.PGresult_Access)
                                        return AffectedRows
   is
      use type BND.IC.int;
      result : BND.IC.int := BND.PQntuples (res);
   begin
      if result < 0 then
         --  overflowed (> 2 ** 31)
         return AffectedRows'Last;
      end if;
      return AffectedRows (result);
   end rows_affected_by_execution;


   -------------------------
   --  begin_transaction  --
   -------------------------
   procedure begin_transaction (conn : out PostgreSQL_Connection) is
   begin
      conn.private_execute ("BEGIN");
      conn.dummy := True;
   exception
      when QUERY_FAIL => raise TRAX_BEGIN_FAIL;
   end begin_transaction;


   --------------
   --  commit  --
   --------------
   overriding
   procedure commit (conn : out PostgreSQL_Connection) is
   begin
      conn.private_execute ("COMMIT");
      conn.dummy := True;
   exception
      when QUERY_FAIL => raise COMMIT_FAIL;
   end commit;


   ----------------
   --  rollback  --
   ----------------
   overriding
   procedure rollback (conn : out PostgreSQL_Connection) is
   begin
      conn.private_execute ("ROLLBACK");
      conn.dummy := True;
   exception
      when QUERY_FAIL => raise ROLLBACK_FAIL;
   end rollback;


   ---------------------
   --  setAutoCommit  --
   ---------------------
   overriding
   procedure setAutoCommit (conn : out PostgreSQL_Connection; auto : Boolean)
   is
   begin
      if auto then
         conn.private_execute ("SET AUTOCOMMIT ON");
      else
         conn.private_execute ("SET AUTOCOMMIT OFF");
      end if;
      conn.dummy := True;
   exception
         when QUERY_FAIL => raise AUTOCOMMIT_FAIL;
   end setAutoCommit;


   ------------------
   --  disconnect  --
   ------------------
   overriding
   procedure disconnect (conn : out PostgreSQL_Connection)
   is
      use type BND.PGconn_Access;
   begin
      if conn.handle /= null then
         BND.PQfinish (conn => conn.handle);
         conn.handle := null;
      end if;
      conn.prop_active := False;
   end disconnect;


   --------------------
   --  fields_count  --
   --------------------
   function fields_count (conn : PostgreSQL_Connection;
                          res  : BND.PGresult_Access) return Natural
   is
      result : BND.IC.int := BND.PQnfields (res);
   begin
      return Natural (result);
   end fields_count;


   ---------------------
   --  field_is_null  --
   ---------------------
   function field_is_null  (conn : PostgreSQL_Connection;
                            res  : BND.PGresult_Access;
                            row_number    : Natural;
                            column_number : Natural) return Boolean
   is
      use type BND.IC.int;
      rownum : constant BND.IC.int := BND.IC.int (row_number);
      colnum : constant BND.IC.int := BND.IC.int (column_number);
      result : constant BND.IC.int := BND.PQgetisnull (res, rownum, colnum);
   begin
      return (result = 1);
   end field_is_null;


   --------------------
   --  field_length  --
   --------------------
   function field_length (conn : PostgreSQL_Connection;
                          res  : BND.PGresult_Access;
                          row_number    : Natural;
                          column_number : Natural) return Natural
   is
      rownum : constant BND.IC.int := BND.IC.int (row_number);
      colnum : constant BND.IC.int := BND.IC.int (column_number);
      result : constant BND.IC.int := BND.PQgetlength (res, rownum, colnum);
   begin
      return Natural (result);
   end field_length;


   ------------------------
   --  discard_pgresult  --
   ------------------------
   procedure discard_pgresult (conn : PostgreSQL_Connection;
                               res  : BND.PGresult_Access) is
   begin
      BND.PQclear (res);
   end discard_pgresult;


   ----------------------------
   --  field_data_is_binary  --
   ----------------------------
   function field_data_is_binary (conn : PostgreSQL_Connection;
                                  res  : BND.PGresult_Access;
                                  column_number : Natural) return Boolean
   is
      use type BND.IC.int;
      colnum : constant BND.IC.int := BND.IC.int (column_number);
      result : constant BND.IC.int := BND.PQfformat (res, colnum);
   begin
      return (result = 1);
   end field_data_is_binary;


   ----------------
   --  finalize  --
   ----------------
   overriding
   procedure finalize (conn : in out PostgreSQL_Connection) is
   begin
      conn.disconnect;
   end finalize;


   ---------------------
   --  setMultiQuery  --
   ---------------------
   overriding
   procedure setMultiQuery (conn     : out PostgreSQL_Connection;
                            multiple : Boolean)
   is
      --  Applicable only to driver.execute and implemented manually there
      --  (in order to use parameter execute rather than pgexec function
   begin
      conn.prop_multiquery := multiple;
   end setMultiQuery;


   ------------------
   --  multiquery  --
   ------------------
   overriding
   function multiquery (conn : PostgreSQL_Connection) return Boolean
   is
   begin
      return conn.prop_multiquery;
   end multiquery;


   -------------------------------
   --  setTransactionIsolation  --
   -------------------------------
   overriding
   procedure setTransactionIsolation (conn : out PostgreSQL_Connection;
                                      isolation : TransIsolation)
   is
      use type TransIsolation;
      sql : constant String := "SSET SESSION CHARACTERISTICS AS TRANSACTION " &
                               IsoKeywords (isolation);
   begin
      if conn.prop_active then
         conn.private_execute (sql);
      end if;

      conn.prop_trax_isolation := isolation;
   exception
      when QUERY_FAIL =>
         raise TRAXISOL_FAIL with sql;
   end setTransactionIsolation;


   ------------------------------------
   --  connection_attempt_succeeded  --
   ------------------------------------
   function connection_attempt_succeeded (conn : PostgreSQL_Connection)
                                          return Boolean
   is
      use type BND.ConnStatusType;
      status : constant BND.ConnStatusType := BND.PQstatus (conn.handle);
   begin
      return (status = BND.CONNECTION_OK);
   end connection_attempt_succeeded;


   -----------------------
   --  convert_version  --
   -----------------------
   function convert_version (pgsql_version : Natural) return CT.Text
   is
      six : String (1 .. 6) := (others => '0');
      raw : constant String := pgsql_version'Img;
      len : constant Natural := raw'Length;
   begin
      six (7 - len .. 6) := raw;
      return CT.SUS (raw (1 .. 2) & '.' & raw (3 .. 4) & '.' & raw (5 .. 6));
   end convert_version;


   --------------------------
   --  get_server_version  --
   --------------------------
   function get_server_version (conn : PostgreSQL_Connection) return Natural
   is
      use type BND.IC.int;
      version : BND.IC.int := BND.PQserverVersion (conn.handle);
   begin
      return Natural (version);
   end get_server_version;


   ---------------------------
   --  get_library_version  --
   ---------------------------
   function get_library_version return Natural
   is
      use type BND.IC.int;
      version : BND.IC.int := BND.PQlibVersion;
   begin
      return Natural (version);
   end get_library_version;


   -----------------------
   --  get_server_info  --
   -----------------------
   function get_server_info (conn : PostgreSQL_Connection) return CT.Text
   is
      use type BND.IC.int;
      protocol : BND.IC.int := BND.PQprotocolVersion (conn.handle);
   begin
      return CT.SUS ("Protocol " & CT.int2str (Integer (protocol)) & ".0");
   end get_server_info;


   -----------------------
   --  is_ipv4_or_ipv6  --
   -----------------------
   function is_ipv4_or_ipv6 (teststr : String) return Boolean
   is
      function is_byte (segment : String) return Boolean;
      function is_byte (segment : String) return Boolean is
      begin
         if segment'Length > 3 then
            return False;
         end if;
         for x in segment'Range loop
            case segment (x) is
               when '0' .. '9' => null;
               when others => return False;
            end case;
         end loop;
         return (Integer'Value (segment) < 256);
      end is_byte;

      num_dots : constant Natural := CT.count_char (teststr, '.');
      dot      : constant String  := ".";
   begin
      if num_dots = 3 then
         declare
            P1A : String := CT.part_1 (teststr, dot);
            P1B : String := CT.part_2 (teststr, dot);
         begin
            if is_byte (P1A) then
               declare
                  P2A : String := CT.part_1 (P1B, dot);
                  P2B : String := CT.part_2 (P1B, dot);
               begin
                  if is_byte (P2A) then
                     declare
                        P3A : String := CT.part_1 (P2B, dot);
                        P3B : String := CT.part_2 (P2B, dot);
                     begin
                        if is_byte (P3A) and then is_byte (P3B) then
                           return True;
                        end if;
                     end;
                  end if;
               end;
            end if;
         end;
      end if;
      for x in teststr'Range loop
         case teststr (x) is
            when ':' | '0' .. '9' | 'A' .. 'F' | 'a' .. 'f' => null;
            when others => return False;
         end case;
      end loop;
      return True;
   end is_ipv4_or_ipv6;


   ---------------
   --  connect  --
   ---------------
   overriding
   procedure connect (conn     : out PostgreSQL_Connection;
                      database : String;
                      username : String := blankstring;
                      password : String := blankstring;
                      hostname : String := blankstring;
                      socket   : String := blankstring;
                      port     : PosixPort := portless)
   is
      constr : CT.Text := CT.SUS ("dbname=" & database);
   begin
      if conn.prop_active then
         raise NOT_WHILE_CONNECTED;
      end if;

      if not CT.IsBlank (username) then
         CT.SU.Append (constr, " user=" & username);
      end if;
      if not CT.IsBlank (password) then
         CT.SU.Append (constr, " password=" & password);
      end if;
      if not CT.IsBlank (hostname) then
         if is_ipv4_or_ipv6 (hostname) then
            CT.SU.Append (constr, " hostaddr=" & hostname);
         else
            CT.SU.Append (constr, " host=" & hostname);
         end if;
      else
         if not CT.IsBlank (socket) then
            CT.SU.Append (constr, " host=" & socket);
         end if;
      end if;
      if port /= portless then
         CT.SU.Append (constr, " port=" & CT.int2str (port));
      end if;

      declare
         use type BND.PGconn_Access;
         conninfo : BND.ICS.chars_ptr := BND.ICS.New_String (CT.USS (constr));
      begin
         conn.handle := BND.PQconnectdb (conninfo);
         BND.ICS.Free (conninfo);

         if conn.handle = null then
            raise CONNECT_FAILED;
         end if;
      end;

      conn.prop_active := True;
      conn.info_client_version := convert_version (get_library_version);
      conn.info_client         := conn.info_client_version;
      conn.info_server_version := convert_version (conn.get_server_version);
      conn.info_server         := conn.get_server_info;

      --  not yet implemented  conn.set_character_set;
      conn.setTransactionIsolation (conn.prop_trax_isolation);
      conn.setAutoCommit (conn.prop_auto_commit);

   end connect;


   --------------------
   --  lastInsertID  --
   --------------------
   overriding
   function lastInsertID (conn : PostgreSQL_Connection) return TraxID is
   begin
      --  TO BE IMPLEMENTED (use SELECT lastval() ?)
      return 0;
   end lastInsertID;


   ---------------
   --  execute  --
   ---------------
   overriding
   procedure execute (conn : out PostgreSQL_Connection; sql : String)
   is
      --  Do NOT use PQexec which requires escaping, but allows multiple
      --  queries.  Instead, use PQexecParams in a loop (manually split
      --  query into semicolon-separated queries first), but only if
      --  multiquery option is enabled.  If option is disabled and multiple
      --  queries are detected, throw an error.
   begin
      --  TO BE IMPLEMENTED
      null;
   end execute;


end AdaBase.Connection.Base.PostgreSQL;

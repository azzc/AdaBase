--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

package body AdaBase.Driver.Base.MySQL is


   ------------------
   --  disconnect  --
   ------------------
   overriding
   procedure disconnect (driver : out MySQL_Driver)
   is
      msg : constant CT.Text :=
        CT.SUS ("Disconnect From " & CT.USS (driver.database) & "database");
      err : constant CT.Text :=
        CT.SUS ("ACK! Disconnect attempted on inactive connection");
   begin
      if driver.connection_active then
         driver.connection.disconnect;
         driver.connection_active := False;

         driver.log_nominal (category => disconnecting,
                             message  => msg);
      else
         --  Non-fatal attempt to disconnect db when none is connected
         driver.log_problem (category => disconnecting,
                             message  => err);
      end if;
   end disconnect;


   ----------------
   --  rollback  --
   ----------------
   overriding
   procedure rollback (driver : MySQL_Driver)
   is
      use type TransIsolation;
      err1 : constant CT.Text :=
        CT.SUS ("ACK! Rollback attempted on inactive connection");
      err2 : constant CT.Text :=
        CT.SUS ("ACK! Rollback attempted when autocommit mode set on");
      err3 : constant CT.Text :=
        CT.SUS ("Rollback attempt failed");
   begin
      if not driver.connection_active then
         --  Non-fatal attempt to roll back when no database is connected
         driver.log_problem (category => miscellaneous,
                             message  => err1);
         return;
      end if;
      if driver.connection.autoCommit then
         --  Non-fatal attempt to roll back when autocommit is on
         driver.log_problem (category => miscellaneous,
                             message  => err2);
         return;
      end if;

      driver.connection.rollback;

   exception
      when ACM.ROLLBACK_FAIL =>
         driver.log_problem (category   => miscellaneous,
                             message    => err3,
                             pull_codes => True);

   end rollback;


   --------------
   --  commit  --
   --------------
   overriding
   procedure commit (driver : MySQL_Driver)
   is
      use type TransIsolation;
      err1 : constant CT.Text :=
        CT.SUS ("ACK! Commit attempted on inactive connection");
      err2 : constant CT.Text :=
        CT.SUS ("ACK! Commit attempted when autocommit mode set on");
      err3 : constant CT.Text :=
        CT.SUS ("Commit attempt failed");
   begin
      if not driver.connection_active then
         --  Non-fatal attempt to commit when no database is connected
         driver.log_problem (category => transaction,
                             message  => err1);
         return;
      end if;
      if driver.connection.autoCommit then
         --  Non-fatal attempt to commit when autocommit is on
         driver.log_problem (category => transaction,
                             message  => err2);
         return;
      end if;

      driver.connection.all.commit;

   exception
      when ACM.COMMIT_FAIL =>
         driver.log_problem (category   => transaction,
                             message    => err3,
                             pull_codes => True);
   end commit;


   ----------------------
   --  last_insert_id  --
   ----------------------
   overriding
   function last_insert_id (driver : MySQL_Driver) return TraxID
   is
   begin
      return driver.connection.all.lastInsertID;
   end last_insert_id;


   ------------------------
   --  last_driver_code  --
   ------------------------
   overriding
   function last_sql_state (driver : MySQL_Driver) return TSqlState
   is
   begin
      return driver.connection.all.SqlState;
   end last_sql_state;


   ------------------------
   --  last_driver_code  --
   ------------------------
   overriding
   function last_driver_code (driver : MySQL_Driver) return DriverCodes
   is
   begin
      return driver.connection.all.driverCode;
   end last_driver_code;


   ---------------------------
   --  last_driver_message  --
   ---------------------------
   overriding
   function last_driver_message (driver : MySQL_Driver) return String
   is
   begin
      return driver.connection.all.driverMessage;
   end last_driver_message;


   ---------------
   --  execute  --
   ---------------
   overriding
   function execute (driver : MySQL_Driver; sql : String)
                     return AffectedRows
   is
      result : AffectedRows := 0;
      err1 : constant CT.Text :=
        CT.SUS ("ACK! Execution attempted on inactive connection");
   begin
      if driver.connection_active then
         driver.connection.all.execute (sql => sql);
         result := driver.connection.all.rows_affected_by_execution;
         driver.log_nominal (category => execution, message => CT.SUS (sql));
      else
         --  Non-fatal attempt to query an unccnnected database
         driver.log_problem (category => execution,
                             message  => err1);
      end if;
      return result;
   exception
      when ACM.QUERY_FAIL =>
         driver.log_problem (category   => execution,
                             message    => CT.SUS (sql),
                             pull_codes => True);
         return 0;
   end execute;

   -------------
   --  query  --
   -------------
   overriding
   function query (driver : MySQL_Driver; sql : String)
                   return AID.ASB.basic_statement
   is
   begin
      return AID.ASB.basic_statement (driver.private_query (sql => sql));
   end query;


   ------------------------------------------------------------------------
   --  PUBLIC ROUTINES NOT COVERED BY INTERFACES                         --
   ------------------------------------------------------------------------

   ---------------------------------
   --  trait_compressed_protocol  --
   ---------------------------------
   function trait_protocol_compressed (driver : MySQL_Driver) return Boolean
   is
   begin
      return driver.local_connection.all.compressed;
   end trait_protocol_compressed;


   --------------------------------
   --  trait_multiquery_enabled  --
   --------------------------------
   function trait_multiquery_enabled (driver : MySQL_Driver) return Boolean
   is
   begin
      return driver.local_connection.all.multiquery;
   end trait_multiquery_enabled;


   --------------------------------
   --  trait_query_buffers_used  --
   --------------------------------
   function trait_query_buffers_used  (driver : MySQL_Driver) return Boolean
   is
   begin
      return driver.local_connection.all.useBuffer;
   end trait_query_buffers_used;


   --------------------------------------
   --  set_trait_compressed_protocol  --
   -------------------------------------
   procedure set_trait_protocol_compressed (driver : MySQL_Driver;
                                            trait  : Boolean)
   is
   begin
      driver.local_connection.all.setCompressed (compressed => trait);
   end set_trait_protocol_compressed;


   ------------------------------------
   --  set_trait_multiquery_enabled  --
   ------------------------------------
   procedure set_trait_multiquery_enabled (driver : MySQL_Driver;
                                           trait  : Boolean)
   is
   begin
      driver.local_connection.all.setMultiQuery (multiple => trait);
   end set_trait_multiquery_enabled;


   ------------------------------
   --  set_query_buffers_used  --
   ------------------------------
   procedure set_trait_query_buffers_used (driver : MySQL_Driver;
                                           trait  : Boolean)
   is
   begin
      driver.local_connection.all.setUseBuffer (buffered => trait);
   end set_trait_query_buffers_used;


   ---------------------
   --  basic_connect  --
   ---------------------
   overriding
   procedure basic_connect (driver   : out MySQL_Driver;
                            database : String;
                            username : String;
                            password : String;
                            socket   : String)
   is
   begin
      driver.private_connect (database => database,
                              username => username,
                              password => password,
                              socket   => socket);
   end basic_connect;


   ---------------------
   --  basic_connect  --
   ---------------------
   overriding
   procedure basic_connect (driver   : out MySQL_Driver;
                            database : String;
                            username : String;
                            password : String;
                            hostname : String;
                            port     : PosixPort)
   is
   begin
      driver.private_connect (database => database,
                              username => username,
                              password => password,
                              hostname => hostname,
                              port     => port);
   end basic_connect;


   ------------------------------------------------------------------------
   --  PRIVATE ROUTINES NOT COVERED BY INTERFACES                        --
   ------------------------------------------------------------------------

   ------------------
   --  initialize  --
   ------------------
   overriding
   procedure initialize (Object : in out MySQL_Driver)
   is
   begin
      Object.connection       := backend'Access;
      Object.local_connection := backend'Access;
      Object.dialect          := driver_mysql;
   end initialize;


   -----------------------
   --  private_connect  --
   -----------------------
   procedure private_connect (driver   : out MySQL_Driver;
                              database : String;
                              username : String;
                              password : String;
                              hostname : String := blankstring;
                              socket   : String := blankstring;
                              port     : PosixPort := portless)
   is
      err1 : constant CT.Text :=
        CT.SUS ("ACK! Reconnection attempted on active connection");
      nom  : constant CT.Text :=
        CT.SUS ("Connection to " & database & " database succeeded.");
   begin
      if driver.connection_active then
         driver.log_problem (category => execution,
                             message  => err1);
         return;
      end if;
      driver.connection.connect (database => database,
                                 username => username,
                                 password => password,
                                 socket   => socket,
                                 hostname => hostname,
                                 port     => port);

      driver.connection_active := driver.connection.all.connected;

      driver.log_nominal (category => connecting, message => nom);
   exception
      when Error : others =>
         driver.log_problem
           (category => connecting,
            break    => True,
            message  => CT.SUS (ACM.EX.Exception_Message (X => Error)));
   end private_connect;


   ---------------------
   --  private_query  --
   ---------------------
   function private_query (driver : MySQL_Driver; sql : String)
                   return ASM.MySQL_statement_access
   is
      err1 : constant CT.Text :=
        CT.SUS ("ACK! Query attempted on inactive connection");
      duplicate : aliased constant CT.Text := CT.SUS (sql);
      shadow    : AID.ASB.stmttext_access := duplicate'Unrestricted_Access;
      statement : constant ASM.MySQL_statement_access :=
        new ASM.MySQL_statement
          (type_of_statement => AID.ASB.direct_statement,
           log_handler       => logger'Access,
           mysql_conn        => driver.local_connection,
           initial_sql       => shadow,
           con_error_mode    => driver.trait_error_mode,
           con_case_mode     => driver.trait_column_case,
           con_max_blob      => driver.trait_max_blob_size,
           con_buffered      => driver.trait_query_buffers_used);
   begin
      if driver.connection_active then
         driver.log_nominal
           (category => execution, message => CT.SUS ("query succeeded," &
              statement.rows_returned'Img & " rows returned"));
      else
         --  Non-fatal attempt to query an unccnnected database
         driver.log_problem (category => execution, message  => err1);
      end if;
      return statement;
   end private_query;


end AdaBase.Driver.Base.MySQL;

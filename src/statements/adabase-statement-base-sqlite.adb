--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with AdaBase.Results.Field;
with Ada.Characters.Handling;

package body AdaBase.Statement.Base.SQLite is

   package ARF renames AdaBase.Results.Field;
   package ACH renames Ada.Characters.Handling;

   ---------------------
   --  num_set_items  --
   ---------------------
   function num_set_items (nv : String) return Natural
   is
      result : Natural := 0;
   begin
      if not CT.IsBlank (nv) then
         result := 1;
         for x in nv'Range loop
            if nv (x) = ',' then
               result := result + 1;
            end if;
         end loop;
      end if;
      return result;
   end num_set_items;


   -------------------
   --  log_problem  --
   -------------------
   procedure log_problem
     (statement  : SQLite_statement;
      category   : LogCategory;
      message    : String;
      pull_codes : Boolean := False;
      break      : Boolean := False)
   is
      error_msg  : CT.Text     := CT.blank;
      error_code : DriverCodes := 0;
      sqlstate   : TSqlState   := stateless;
   begin
      if pull_codes then
         error_msg  := CT.SUS (statement.last_driver_message);
         error_code := statement.last_driver_code;
         sqlstate   := statement.last_sql_state;
      end if;

      logger_access.all.log_problem
          (driver     => statement.dialect,
           category   => category,
           message    => CT.SUS (message),
           error_msg  => error_msg,
           error_code => error_code,
           sqlstate   => sqlstate,
           break      => break);
   end log_problem;


   --------------------
   --  column_count  --
   --------------------
   overriding
   function column_count (Stmt : SQLite_statement) return Natural is
   begin
      return Stmt.num_columns;
   end column_count;


   -------------------
   --  column_name  --
   -------------------
   overriding
   function column_name (Stmt : SQLite_statement; index : Positive)
                         return String
   is
      maxlen : constant Natural := Natural (Stmt.column_info.Length);
   begin
      if index > maxlen then
         raise INVALID_COLUMN_INDEX with "Max index is" & maxlen'Img &
           " but" & index'Img & " attempted";
      end if;
      return CT.USS (Stmt.column_info.Element (Index => index).field_name);
   end column_name;


   --------------------
   --  column_table  --
   --------------------
   overriding
   function column_table (Stmt : SQLite_statement; index : Positive)
                          return String
   is
      maxlen : constant Natural := Natural (Stmt.column_info.Length);
   begin
      if index > maxlen then
         raise INVALID_COLUMN_INDEX with "Max index is" & maxlen'Img &
           " but" & index'Img & " attempted";
      end if;
      return CT.USS (Stmt.column_info.Element (Index => index).table);
   end column_table;


   ------------------
   --  initialize  --
   ------------------
   overriding
   procedure initialize (Object : in out SQLite_statement)
   is
      use type ACS.SQLite_Connection_Access;
      conn : ACS.SQLite_Connection_Access renames Object.sqlite_conn;

      len : Natural := CT.len (Object.initial_sql.all);
      logcat : LogCategory;
   begin

      if conn = null then
         return;
      end if;

      logger_access     := Object.log_handler;
      Object.dialect    := driver_sqlite;
      Object.sql_final  := new String (1 .. len);
      Object.connection := ACB.Base_Connection_Access (conn);

      case Object.type_of_statement is
         when direct_statement =>
            Object.sql_final.all := Object.initial_sql.all;
            logcat := statement_execution;
         when prepared_statement =>
            Object.sql_final.all :=
              Object.transform_sql (Object.initial_sql.all);
            logcat := statement_preparation;
      end case;

      if conn.prepare_statement (stmt => Object.stmt_handle,
                                 sql  => Object.sql_final.all)
      then
         Object.successful_execution := True;
         Object.log_nominal (category => logcat,
                             message  => Object.sql_final.all);
      else
         raise STMT_PREPARATION
           with "Failed to parse a direct SQL query";
      end if;

      if Object.type_of_statement = prepared_statement then
         --  Check that we have as many markers as expected
         declare
            params : Natural := conn.prep_markers_found (Object.stmt_handle);
            errmsg : String := "marker mismatch," &
              Object.realmccoy.Length'Img & " expected but" &
              params'Img & " found by SQLite";
         begin
            if params /= Natural (Object.realmccoy.Length) then
               raise ILLEGAL_BIND_SQL with errmsg;
            end if;
         end;
      else
         if not Object.private_execute then
            raise STMT_EXECUTION
              with "Failed to execute a direct SQL query";
         end if;
      end if;

      Object.scan_column_information;

   exception
      when HELL : others =>
         Object.log_problem
           (category => statement_preparation,
            message  => ACS.EX.Exception_Message (HELL));
   end initialize;


   -------------------------------
   --  scan_column_information  --
   -------------------------------
   procedure scan_column_information (Stmt : out SQLite_statement)
   is
      function fn (raw : String) return CT.Text;
      function sn (raw : String) return String;
      function fn (raw : String) return CT.Text is
      begin
         case Stmt.con_case_mode is
            when upper_case =>
               return CT.SUS (ACH.To_Upper (raw));
            when lower_case =>
               return CT.SUS (ACH.To_Lower (raw));
            when natural_case =>
               return CT.SUS (raw);
         end case;
      end fn;
      function sn (raw : String) return String is
      begin
         case Stmt.con_case_mode is
            when upper_case =>
               return ACH.To_Upper (raw);
            when lower_case =>
               return ACH.To_Lower (raw);
            when natural_case =>
               return raw;
         end case;
      end sn;

      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      Stmt.num_columns := conn.fields_in_result (Stmt.stmt_handle);
      for index in Natural range 0 .. Stmt.num_columns - 1 loop
         declare
            info  : column_info;
            brec  : bindrec;
            name  : String := conn.field_name (Stmt.stmt_handle, index);
            table : String := conn.field_table (Stmt.stmt_handle, index);
            dbase : String := conn.field_database (Stmt.stmt_handle, index);
         begin
            brec.v00          := False;   --  placeholder
            info.field_name   := fn (name);
            info.table        := fn (table);

            conn.get_field_meta_data (stmt      => Stmt.stmt_handle,
                                      database  => dbase,
                                      table     => table,
                                      column    => name,
                                      data_type => info.sqlite_type,
                                      nullable  => info.null_possible);

            case info.sqlite_type is
               when BND.SQLITE_INTEGER => info.field_type := ft_byte8;
               when BND.SQLITE_TEXT    => info.field_type := ft_textual;
               when BND.SQLITE_BLOB    => info.field_type := ft_chain;
               when BND.SQLITE_FLOAT   => info.field_type := ft_real18;
               when BND.SQLITE_NULL    => info.field_type := ft_nbyte0;
            end case;

            Stmt.column_info.Append (New_Item => info);
            --  The following pre-populates for bind support
            Stmt.crate.Append (New_Item => brec);
            Stmt.headings_map.Insert (Key      => sn (name),
                                      New_Item => Stmt.crate.Last_Index);
         end;
      end loop;
   end scan_column_information;


   --------------------------
   --  column_native_type  --
   --------------------------
   overriding
   function column_native_type (Stmt : SQLite_statement; index : Positive)
                                return field_types
   is
      maxlen : constant Natural := Natural (Stmt.column_info.Length);
   begin
      if index > maxlen then
         raise INVALID_COLUMN_INDEX with "Max index is" & maxlen'Img &
           " but" & index'Img & " attempted";
      end if;
      return Stmt.column_info.Element (Index => index).field_type;
   end column_native_type;


   ----------------------
   --  last_insert_id  --
   ----------------------
   overriding
   function last_insert_id (Stmt : SQLite_statement) return TraxID
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      return conn.lastInsertID;
   end last_insert_id;


   ----------------------
   --  last_sql_state  --
   ----------------------
   overriding
   function last_sql_state (Stmt : SQLite_statement) return TSqlState
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      return conn.SqlState;
   end last_sql_state;


   ------------------------
   --  last_driver_code  --
   ------------------------
   overriding
   function last_driver_code (Stmt : SQLite_statement) return DriverCodes
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      return conn.driverCode;
   end last_driver_code;


   ---------------------------
   --  last_driver_message  --
   ---------------------------
   overriding
   function last_driver_message (Stmt : SQLite_statement) return String
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      return conn.driverMessage;
   end last_driver_message;


   ---------------------
   --  rows_returned  --
   ---------------------
   overriding
   function rows_returned (Stmt : SQLite_statement) return AffectedRows is
   begin
      --  Not supported by SQLite
      return 0;
   end rows_returned;


   --------------------
   --  discard_rest  --
   --------------------
   overriding
   procedure discard_rest (Stmt : out SQLite_statement)
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      Stmt.rows_leftover := (Stmt.step_result = data_pulled);
      conn.reset_prep_stmt (stmt => Stmt.stmt_handle);
      Stmt.step_result := unset;
   end discard_rest;


   -----------------------
   --  private_execute  --
   -----------------------
   function private_execute (Stmt : out SQLite_statement) return Boolean
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      if conn.prep_fetch_next (Stmt.stmt_handle) then
         Stmt.step_result := data_pulled;
      else
         Stmt.step_result := progam_complete;
         Stmt.impacted := conn.rows_affected_by_execution;
      end if;
      return True;
   exception
      when ACS.STMT_FETCH_FAIL =>
         Stmt.step_result := error_seen;
         return False;
   end private_execute;


   ------------------
   --  execute #1  --
   ------------------
   overriding
   function execute (Stmt : out SQLite_statement) return Boolean
   is
      conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;

      num_markers : constant Natural := Natural (Stmt.realmccoy.Length);
      status_successful : Boolean := True;
   begin
      if Stmt.type_of_statement = direct_statement then
         raise INVALID_FOR_DIRECT_QUERY
           with "The execute command is for prepared statements only";
      end if;
      Stmt.successful_execution := False;

      if not Stmt.virgin then
         conn.reset_prep_stmt (Stmt.stmt_handle);
         Stmt.reclaim_canvas;
         Stmt.step_result := unset;
         Stmt.virgin := False;
      end if;

      if num_markers > 0 then
         --  Check to make sure all prepared markers are bound
         for sx in Natural range 1 .. num_markers loop
            if not Stmt.realmccoy.Element (sx).bound then
               raise STMT_PREPARATION
                 with "Prep Stmt column" & sx'Img & " unbound";
            end if;
         end loop;

         --  Now bind the actual values to the markers
         begin
            for sx in Natural range 1 .. num_markers loop
               Stmt.bind_canvas.Append (Stmt.construct_bind_slot (sx));
            end loop;
            Stmt.log_nominal (category => statement_execution,
                              message => "Exec with" & num_markers'Img &
                                " bound parameters");
         exception
            when CBS : others =>
               Stmt.log_problem (category => statement_execution,
                                 message  => ACS.EX.Exception_Message (CBS));
               return False;
         end;

      else
         --  No binding required, just execute the prepared statement
         Stmt.log_nominal (category => statement_execution,
                           message => "Exec without bound parameters");
      end if;

      begin
         if conn.prep_fetch_next (Stmt.stmt_handle) then
            Stmt.step_result := data_pulled;
         else
            Stmt.step_result := progam_complete;
            Stmt.impacted := conn.rows_affected_by_execution;
         end if;
         Stmt.successful_execution := True;
      exception
         when ACS.STMT_FETCH_FAIL =>
            Stmt.step_result := error_seen;
            status_successful := False;
      end;

      return status_successful;

   end execute;


   ------------------
   --  execute #2  --
   ------------------
   overriding
   function execute (Stmt : out SQLite_statement; parameters : String;
                     delimiter  : Character := '|') return Boolean
   is
      pragma Unreferenced (Stmt);
      --  conn : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      --  TO BE IMPLEMENTED
      return True;
   end execute;

   ------------------
   --  fetch_next  --
   ------------------
   overriding
   function fetch_next (Stmt : out SQLite_statement) return ARS.DataRow
   is
      conn   : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;
   begin
      if Stmt.step_result /= data_pulled then
         return ARS.Empty_DataRow;
      end if;
      declare
         maxlen : constant Natural := Natural (Stmt.column_info.Length);
         result : ARS.DataRow;
      begin

         for F in 1 .. maxlen loop
            declare
               field    : ARF.std_field;
               dvariant : ARF.variant;
               scol     : constant Natural := F - 1;
               last_one : constant Boolean := (F = maxlen);
               heading  : constant String := CT.USS
                          (Stmt.column_info.Element (Index => F).field_name);
               EN       : constant Boolean :=
                          conn.field_is_null (Stmt.stmt_handle, scol);
            begin
               case Stmt.column_info.Element (Index => F).field_type is
                  when ft_nbyte0  =>
                     --  This should never occur though
                     dvariant := (datatype => ft_nbyte0, v00 => False);
                  when ft_byte8   =>
                     dvariant :=
                       (datatype => ft_byte8,
                        v10 => conn.retrieve_integer (Stmt.stmt_handle, scol));
                  when ft_real18  =>
                     dvariant :=
                       (datatype => ft_real18,
                        v12 => conn.retrieve_double (Stmt.stmt_handle, scol));
                  when ft_textual =>
                     dvariant :=
                       (datatype => ft_textual,
                        v13 => conn.retrieve_text (Stmt.stmt_handle, scol));
                  when ft_chain   => null;
                  when others => raise INVALID_FOR_RESULT_SET
                       with "Impossible field type (internal bug??)";
               end case;
               case Stmt.column_info.Element (Index => F).field_type is
                  when ft_chain =>
                     field := ARF.spawn_field
                       (binob => ARC.convert
                          (conn.retrieve_blob
                               (stmt  => Stmt.stmt_handle,
                                index => scol,
                                maxsz => Stmt.con_max_blob)));
                  when ft_nbyte0 | ft_byte8 | ft_real18 | ft_textual =>
                     field := ARF.spawn_field (data => dvariant,
                                               null_data => EN);
                  when others => null;
               end case;
               result.push (heading    => heading,
                            field      => field,
                            last_field => last_one);
            end;
         end loop;
         begin
            if conn.prep_fetch_next (Stmt.stmt_handle) then
               Stmt.step_result := data_pulled;
            else
               Stmt.step_result := progam_complete;
            end if;
         exception
            when ACS.STMT_FETCH_FAIL =>
               Stmt.step_result := error_seen;
         end;
         return result;
      end;
   end fetch_next;


   ------------------
   --  fetch_bound --
   ------------------
   overriding
   function fetch_bound (Stmt : out SQLite_statement) return Boolean
   is
      pragma Unreferenced (Stmt);
   begin
      --  TO BE IMPLEMENTED
      return False;
   end fetch_bound;


   -----------------
   --  fetch_all  --
   -----------------
   overriding
   function fetch_all (Stmt : out SQLite_statement) return ARS.DataRowSet
   is
      subtype rack_range is Positive range 1 .. 1000000;
      type TRack is array (rack_range) of ARS.DataRow_Access;
      nullset      : ARS.DataRowSet (1 .. 0);
   begin
      if Stmt.step_result /= data_pulled then
         return nullset;
      end if;
      --  With SQLite, we don't know many rows of data are fetched, ever.
      --  For practical purposes, let's limit a result set to 1 million rows
      --  We'll create an access array and dynamically allocate memory for
      --  each row.  At the end, we'll copy the data to a properly sized
      --  array, free the memory and return the result.

      declare
         rack         : TRack;
         dataset_size : Natural    := 0;
         arrow        : rack_range := rack_range'First;
      begin
         loop
            rack (arrow) := new ARS.DataRow;
            rack (arrow).all := Stmt.fetch_next;
            exit when rack (arrow).data_exhausted;
            dataset_size := dataset_size + 1;
            if arrow = rack_range'Last then
               Stmt.discard_rest;
               exit;
            end if;
            arrow := arrow + 1;
         end loop;
         if dataset_size = 0 then
            --  nothing was fetched
            free_datarow (rack (arrow));
            return nullset;
         end if;

         declare
            returnset : ARS.DataRowSet (1 .. dataset_size);
         begin
            for x in returnset'Range loop
               returnset (x) := rack (x).all;
            end loop;
            for x in rack_range range rack_range'First .. arrow loop
               free_datarow (rack (x));
            end loop;
            return returnset;
         end;
      end;
   end fetch_all;


   --------------
   --  Adjust  --
   --------------
   overriding
   procedure Adjust (Object : in out SQLite_statement) is
   begin
      --  The stmt object goes through this evolution:
      --  A) created in private_prepare()
      --  B) copied to new object in prepare(), A) destroyed
      --  C) copied to new object in program, B) destroyed
      --  We don't want to take any action until C) is destroyed, so add a
      --  reference counter upon each assignment.  When finalize sees a
      --  value of "2", it knows it is the program-level statement and then
      --  it can release memory releases, but not before!
      Object.assign_counter := Object.assign_counter + 1;

      --  Since the finalization is looking for a specific reference
      --  counter, any further assignments would fail finalization, so
      --  just prohibit them outright.
      if Object.assign_counter > 2 then
         raise STMT_PREPARATION
           with "Statement objects cannot be re-assigned.";
      end if;
   end Adjust;


   ----------------
   --  finalize  --
   ----------------
   overriding
   procedure finalize (Object : in out SQLite_statement) is
   begin
      if Object.assign_counter /= 2 then
         return;
      end if;

      if not Object.sqlite_conn.prep_finalize (Object.stmt_handle) then
         Object.log_problem
           (category   => statement_preparation,
            message    => "Deallocating statement resources",
            pull_codes => True);
      end if;

      free_sql (Object.sql_final);
      --  Object.clear_column_information;
      Object.reclaim_canvas;
   end finalize;


   ---------------------------
   --  construct_bind_slot  --
   ---------------------------
   function construct_bind_slot (Stmt : SQLite_statement; marker : Positive)
                                 return sqlite_canvas
   is
      zone    : bindrec renames Stmt.realmccoy.Element (marker);
      conn    : ACS.SQLite_Connection_Access renames Stmt.sqlite_conn;

      vartype : constant field_types := zone.output_type;
      okay    : Boolean := True;
      product : sqlite_canvas;

      BT      : BND.ICS.chars_ptr         renames product.buffer_text;
      BB      : BND.ICS.char_array_access renames product.buffer_binary;

      use type AR.nbyte0_access;
      use type AR.nbyte1_access;
      use type AR.nbyte2_access;
      use type AR.nbyte3_access;
      use type AR.nbyte4_access;
      use type AR.nbyte8_access;
      use type AR.byte1_access;
      use type AR.byte2_access;
      use type AR.byte3_access;
      use type AR.byte4_access;
      use type AR.byte8_access;
      use type AR.real9_access;
      use type AR.real18_access;
      use type AR.str1_access;
      use type AR.str2_access;
      use type AR.str4_access;
      use type AR.time_access;
      use type AR.enum_access;
      use type AR.chain_access;
      use type AR.settype_access;
   begin
      if zone.null_data then
         if not conn.marker_is_null (Stmt.stmt_handle, marker) then
            raise STMT_EXECUTION
              with "failed to bind NULL marker" & marker'Img;
         end if;
      else
         case vartype is
            when ft_nbyte0 | ft_nbyte1 | ft_nbyte2 | ft_nbyte3 | ft_nbyte4 |
                 ft_nbyte8 | ft_byte1  | ft_byte2  | ft_byte3  | ft_byte4  |
                 ft_byte8 =>
               declare
                  hold : AR.byte8;
               begin
                  case vartype is
                     when ft_nbyte0 =>
                        if zone.a00 = null then
                           hold := ARC.convert (zone.v00);
                        else
                           hold := ARC.convert (zone.a00.all);
                        end if;
                     when ft_nbyte1 =>
                        if zone.a01 = null then
                           hold := ARC.convert (zone.v01);
                        else
                           hold := ARC.convert (zone.a01.all);
                        end if;
                     when ft_nbyte2 =>
                        if zone.a02 = null then
                           hold := ARC.convert (zone.v02);
                        else
                           hold := ARC.convert (zone.a02.all);
                        end if;
                     when ft_nbyte3 =>
                        if zone.a03 = null then
                           hold := ARC.convert (zone.v03);
                        else
                           hold := ARC.convert (zone.a03.all);
                        end if;
                     when ft_nbyte4 =>
                        if zone.a04 = null then
                           hold := ARC.convert (zone.v04);
                        else
                           hold := ARC.convert (zone.a04.all);
                        end if;
                     when ft_nbyte8 =>
                        if zone.a05 = null then
                           hold := ARC.convert (zone.v05);
                        else
                           hold := ARC.convert (zone.a05.all);
                        end if;
                     when ft_byte1 =>
                        if zone.a06 = null then
                           hold := ARC.convert (zone.v06);
                        else
                           hold := ARC.convert (zone.a06.all);
                        end if;
                     when ft_byte2 =>
                        if zone.a07 = null then
                           hold := ARC.convert (zone.v07);
                        else
                           hold := ARC.convert (zone.a07.all);
                        end if;
                     when ft_byte3 =>
                        if zone.a08 = null then
                           hold := ARC.convert (zone.v08);
                        else
                           hold := ARC.convert (zone.a08.all);
                        end if;
                     when ft_byte4 =>
                        if zone.a09 = null then
                           hold := ARC.convert (zone.v09);
                        else
                           hold := ARC.convert (zone.a09.all);
                        end if;
                     when ft_byte8 =>
                        if zone.a10 = null then
                           hold := zone.v10;
                        else
                           hold := zone.a10.all;
                        end if;
                     when others => hold := 0;
                  end case;
                  okay := conn.marker_is_integer (Stmt.stmt_handle,
                                                  marker, hold);
               end;
            when ft_real9 | ft_real18 =>
               declare
                  hold : AR.real18;
               begin
                  if vartype = ft_real18 then
                     if zone.a10 = null then
                        hold := zone.v12;
                     else
                        hold := zone.a12.all;
                     end if;
                  else
                     if zone.a11 = null then
                        hold := ARC.convert (zone.v11);
                     else
                        hold := ARC.convert (zone.a11.all);
                     end if;
                  end if;
                  okay := conn.marker_is_double (Stmt.stmt_handle,
                                                 marker, hold);
               end;
            when ft_textual =>
               if zone.a13 = null then
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v13), BT);
               else
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a13.all), BT);
               end if;
            when ft_widetext =>
               if zone.a14 = null then
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v14), BT);
               else
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a14.all), BT);
               end if;
           when ft_supertext =>
               if zone.a15 = null then
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v15), BT);
               else
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a15.all), BT);
               end if;
            when ft_timestamp =>
               if zone.a16 = null then
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v16), BT);
               else
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a16.all), BT);
               end if;
            when ft_enumtype =>
               if zone.a18 = null then
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v18), BT);
               else
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a18.all), BT);
               end if;
            when ft_settype =>
               if zone.a19 = null then
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v19), BT);
               else
                  okay := conn.marker_is_text (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a19.all), BT);
               end if;
            when ft_chain =>
               if zone.a17 = null then
                  okay := conn.marker_is_blob (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.v17), BB);
               else
                  okay := conn.marker_is_blob (Stmt.stmt_handle, marker,
                                               ARC.convert (zone.a17.all), BB);
               end if;
         end case;
         if not okay then
            raise STMT_EXECUTION with "failed to bind " & vartype'Img &
              " type to marker " & marker'Img;
         end if;
      end if;
      return product;
   end construct_bind_slot;


   ----------------------
   --  reclaim_canvas  --
   ----------------------
   procedure reclaim_canvas (Stmt : out SQLite_statement)
   is
      use type BND.ICS.char_array_access;
      use type BND.ICS.chars_ptr;
   begin
      for x in Positive range 1 .. Natural (Stmt.bind_canvas.Length) loop
         declare
            SC : sqlite_canvas renames Stmt.bind_canvas.Element (x);
            BT : BND.ICS.chars_ptr         := SC.buffer_text;
            BB : BND.ICS.char_array_access := SC.buffer_binary;
         begin
            if BT /= BND.ICS.Null_Ptr then
               BND.ICS.Free (BT);
            end if;
            if BB /= null then
               free_binary (BB);
            end if;
         end;
      end loop;
      Stmt.bind_canvas.Clear;
   end reclaim_canvas;


end AdaBase.Statement.Base.SQLite;

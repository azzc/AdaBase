--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with Ada.Exceptions;
with Ada.Characters.Handling;
with AdaBase.Results.Field;
with Ada.Unchecked_Conversion;

package body AdaBase.Statement.Base.MySQL is

   package EX  renames Ada.Exceptions;
   package ARF renames AdaBase.Results.Field;
   package ACH renames Ada.Characters.Handling;

   --------------------
   --  discard_rest  --
   --------------------
   overriding
   procedure discard_rest (Stmt : out MySQL_statement)
   is
      use type ABM.MYSQL_RES_Access;
      use type ABM.MYSQL_STMT_Access;
   begin
      case Stmt.type_of_statement is
      when direct_statement =>
         if Stmt.result_handle /= null then
            Stmt.rows_leftover := True;
            Stmt.mysql_conn.all.free_result (Stmt.result_handle);
         end if;
      when prepared_statement =>
         if Stmt.stmt_handle /= null then
            Stmt.rows_leftover := True;
            Stmt.mysql_conn.all.prep_free_result (Stmt.stmt_handle);
         end if;
      end case;
      Stmt.clear_column_information;
      Stmt.delivery := completed;
   end discard_rest;


   --------------------
   --  column_count  --
   --------------------
   overriding
   function column_count (Stmt : MySQL_statement) return Natural is
   begin
      return Stmt.num_columns;
   end column_count;


   ---------------------------
   --  last_driver_message  --
   ---------------------------
   overriding
   function last_driver_message (Stmt : MySQL_statement) return String is
   begin
      case Stmt.type_of_statement is
         when direct_statement   =>
            return Stmt.mysql_conn.all.driverMessage;
         when prepared_statement =>
            return Stmt.mysql_conn.all.prep_DriverMessage
              (Stmt.stmt_handle);
      end case;

   end last_driver_message;


   ----------------------
   --  last_insert_id  --
   ----------------------
   overriding
   function last_insert_id (Stmt : MySQL_statement) return TraxID is
   begin
      case Stmt.type_of_statement is
         when direct_statement   =>
            return Stmt.mysql_conn.all.lastInsertID;
         when prepared_statement =>
            return Stmt.mysql_conn.all.prep_LastInsertID
              (Stmt.stmt_handle);
      end case;
   end last_insert_id;


   ----------------------
   --  last_sql_state  --
   ----------------------
   overriding
   function last_sql_state (Stmt : MySQL_statement) return TSqlState is
   begin
      case Stmt.type_of_statement is
         when direct_statement   =>
            return Stmt.mysql_conn.all.SqlState;
         when prepared_statement =>
            return Stmt.mysql_conn.all.prep_SqlState
              (Stmt.stmt_handle);
      end case;
   end last_sql_state;


   ------------------------
   --  last_driver_code  --
   ------------------------
   overriding
   function last_driver_code (Stmt : MySQL_statement) return DriverCodes is
   begin
      case Stmt.type_of_statement is
         when direct_statement   =>
            return Stmt.mysql_conn.all.driverCode;
         when prepared_statement =>
            return Stmt.mysql_conn.all.prep_DriverCode
              (Stmt.stmt_handle);
      end case;
   end last_driver_code;


   ----------------------------
   --  execute  (version 1)  --
   ----------------------------
   overriding
   function execute (Stmt : out MySQL_statement) return Boolean
   is
      num_markers : constant Natural := Natural (Stmt.realmccoy.Length);
      status_successful : Boolean := True;
   begin
      if Stmt.type_of_statement = direct_statement then
         raise INVALID_FOR_DIRECT_QUERY
           with "execute is for prepared statements";
      end if;
      Stmt.successful_execution := False;
      if num_markers > 0 then
         --  Check to make sure all prepared markers are bound
         for sx in Natural range 1 .. num_markers loop
            if not Stmt.realmccoy.Element (sx).bound then
               raise PS_COLUMN_UNBOUND
                 with "Prep Stmt column" & sx'Img & " missing value";
            end if;
         end loop;
         declare
            slots : ABM.MYSQL_BIND_Array (1 .. num_markers);
            vault : mysql_canvases (1 .. num_markers);
         begin
            for sx in slots'Range loop
               Stmt.construct_bind_slot (struct => slots (sx),
                                         canvas => vault (sx),
                                         marker => sx);
            end loop;

            if not Stmt.mysql_conn.all.prep_bind_parameters
              (Stmt.stmt_handle, slots)
            then
               Stmt.log_problem (category => statement_preparation,
                                 message => "failed to bind parameters",
                                 pull_codes => True);
               status_successful := False;
            end if;

            if status_successful then
               Stmt.log_nominal (category => statement_execution,
                                 message => "Exec with" & num_markers'Img &
                                   " bound parameters");
               if Stmt.mysql_conn.all.prep_execute (Stmt.stmt_handle) then
                  Stmt.successful_execution := True;
               else
                  Stmt.log_problem (category => statement_execution,
                                    message => "failed to exec prep stmt",
                                    pull_codes => True);
                  status_successful := False;
               end if;
            end if;

            --  Recover dynamically allocated data
            for sx in slots'Range loop
               case Stmt.realmccoy.Element (sx).output_type is
                  when ft_textual | ft_widetext | ft_supertext |
                       ft_chain | ft_enumtype | ft_settype =>
                     ABM.ICS.Free (vault (sx).buffer_binary);
                  when others =>
                     null;
               end case;
            end loop;
         end;
      else
         --  No binding required, just execute the prepared statement
         Stmt.log_nominal (category => statement_execution,
                           message => "Exec without bound parameters");
         if Stmt.mysql_conn.all.prep_execute (Stmt.stmt_handle) then
            Stmt.successful_execution := True;
         else
            Stmt.log_problem (category => statement_execution,
                              message => "failed to exec prep stmt",
                              pull_codes => True);
            status_successful := False;
         end if;
      end if;
      Stmt.internal_post_prep_stmt;

      return status_successful;
   end execute;


   ----------------------------
   --  execute  (version 2)  --
   ----------------------------
   overriding
   function execute (Stmt : out MySQL_statement; bind_piped : String)
                     return Boolean
   is
   begin
      if Stmt.type_of_statement = direct_statement then
         raise INVALID_FOR_DIRECT_QUERY
           with "execute is for prepared statements";
      end if;
      --  TODO : IMPLEMENT
      --  Change, use strings directly (no double conversion)
      raise ILLEGAL_BIND_SQL with "to be implemented";
      return Stmt.execute;
   end execute;


   ------------------
   --  initialize  --
   ------------------
   overriding
   procedure initialize (Object : in out MySQL_statement)
   is
      use type ACM.MySQL_Connection_Access;
      len : Natural := CT.len (Object.initial_sql.all);
   begin
      if Object.mysql_conn = null then
         return;
      end if;

      logger_access     := Object.log_handler;
      Object.dialect    := driver_mysql;
      Object.sql_final  := new String (1 .. len);
      Object.connection := ACB.Base_Connection_Access (Object.mysql_conn);
      case Object.type_of_statement is
         when direct_statement =>
            Object.sql_final.all := CT.USS (Object.initial_sql.all);
            Object.internal_direct_post_exec;
         when prepared_statement =>
            Object.transform_sql (sql => CT.USS (Object.initial_sql.all),
                                  new_sql => Object.sql_final.all);
            Object.mysql_conn.initialize_and_prepare_statement
              (stmt => Object.stmt_handle, sql => Object.sql_final.all);
            declare
                 params : Natural := Object.mysql_conn.prep_markers_found
                   (stmt => Object.stmt_handle);
            begin
               if params /= Natural (Object.realmccoy.Length) then
                  raise ILLEGAL_BIND_SQL
                    with "marker mismatch," & Object.realmccoy.Length'Img
                      & " expected but" & params'Img & " found by MySQL";
               end if;
               Object.log_nominal
                 (category => statement_preparation,
                  message => Object.sql_final.all);
            end;
            Object.result_handle := Object.mysql_conn.prep_result_metadata
                                    (Object.stmt_handle);
            --  Direct statements always produce result sets, but prepared
            --  statements very well may not.  The procedure below ends early
            --  after erasing column data if the result_handle above is null.
            Object.scan_column_information;
      end case;
   end initialize;


   ---------------------
   --  direct_result  --
   ---------------------
   procedure process_direct_result (Stmt : out MySQL_statement)
   is
      use type ABM.MYSQL_RES_Access;
   begin
      case Stmt.con_buffered is
         when True => Stmt.mysql_conn.all.store_result
              (result_handle => Stmt.result_handle);
         when False => Stmt.mysql_conn.all.use_result
              (result_handle => Stmt.result_handle);
      end case;
      Stmt.result_present := (Stmt.result_handle /= null);
   end process_direct_result;


   ---------------------
   --  rows_returned  --
   ---------------------
   overriding
   function rows_returned (Stmt : MySQL_statement) return AffectedRows is
   begin
      if not Stmt.successful_execution then
         raise PRIOR_EXECUTION_FAILED
           with "Has query been executed yet?";
      end if;
      if Stmt.result_present then
         if Stmt.con_buffered then
            return Stmt.size_of_rowset;
         else
            raise INVALID_FOR_RESULT_SET
              with "Row set size is not known (Use query buffers to fix)";
         end if;
      else
         raise INVALID_FOR_RESULT_SET
           with "Result set not found; use rows_affected";
      end if;
   end rows_returned;


   --------------------------------
   --  clear_column_information  --
   --------------------------------
   procedure clear_column_information (Stmt : out MySQL_statement) is
   begin
      Stmt.column_info.Clear;
      Stmt.crate.Clear;
      Stmt.headings_map.Clear;
   end clear_column_information;


   -------------------------------
   --  scan_column_information  --
   -------------------------------
   procedure scan_column_information (Stmt : out MySQL_statement)
   is
      use type ABM.MYSQL_FIELD_Access;
      use type ABM.MYSQL_RES_Access;
      field : ABM.MYSQL_FIELD_Access;
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
   begin
      Stmt.clear_column_information;
      if Stmt.result_handle = null then
         return;
      end if;
      loop
         field := Stmt.mysql_conn.fetch_field
           (result_handle => Stmt.result_handle);
         exit when field = null;
         declare
            info : column_info;
            brec : bindrec;
         begin
            brec.v00         := False;   --  placeholder
            info.field_name  := fn (Stmt.mysql_conn.field_name_field (field));
            info.table       := fn (Stmt.mysql_conn.field_name_table (field));
            info.mysql_type  := field.field_type;
            info.null_possible := Stmt.mysql_conn.field_allows_null (field);
            Stmt.mysql_conn.field_data_type
              (field    => field,
               std_type => info.field_type,
               size     => info.field_size);
            Stmt.column_info.Append (New_Item => info);
            --  The following pre-populates for bind support
            Stmt.crate.Append (New_Item => brec);
            Stmt.headings_map.Insert
              (Key => sn (Stmt.mysql_conn.field_name_field (field)),
               New_Item => Stmt.crate.Last_Index);
         end;
      end loop;
   end scan_column_information;


   -------------------
   --  column_name  --
   -------------------
   overriding
   function column_name (Stmt : MySQL_statement; index : Positive)
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
   function column_table (Stmt : MySQL_statement; index : Positive)
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


   --------------------------
   --  column_native_type  --
   --------------------------
   overriding
   function column_native_type (Stmt : MySQL_statement; index : Positive)
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


   ------------------
   --  fetch_next  --
   ------------------
   overriding
   function fetch_next (Stmt    : out MySQL_statement;
                        datarow : out ARS.DataRow_Access) return Boolean
   is
      use type ARS.DataRow_Access;
   begin
      datarow := null;
      if Stmt.delivery = completed then
         return False;
      end if;
      datarow := Stmt.internal_fetch_row;
      return (datarow /= null);
   end fetch_next;


   -------------------
   --  fetch_bound  --
   -------------------
   overriding
   function fetch_bound (Stmt : out MySQL_statement) return Boolean is
   begin
      if Stmt.delivery = completed then
         return False;
      end if;
      return Stmt.internal_fetch_bound;
   end fetch_bound;


   -----------------
   --  fetch_all  --
   -----------------
   overriding
   function fetch_all (Stmt : out MySQL_statement) return ARS.DataRowSet
   is
      maxrows : Natural := Natural (Stmt.rows_returned);
      tmpset  : ARS.DataRowSet (1 .. maxrows + 1) := (others => null);
      nullset : ARS.DataRowSet (1 .. 0);
      index   : Natural := 1;
   begin
      if (Stmt.delivery = completed) or else (maxrows = 0) then
         return nullset;
      end if;
      --  It is possible that one or more rows was individually fetched
      --  before the entire set was fetched.  Let's consider this legal so
      --  use a repeat loop to check each row and return a partial set
      --  if necessary.
      loop
         exit when not Stmt.fetch_next (tmpset (index));
         index := index + 1;
         exit when index > maxrows + 1;  --  should never happen
      end loop;
      if index = 1 then
         return nullset;   --  nothing was fetched
      end if;
      return tmpset (1 .. index - 1);
   end fetch_all;


   ----------------------
   --  fetch_next_set  --
   ----------------------
   overriding
   procedure fetch_next_set (Stmt         : out MySQL_statement;
                             data_present : out Boolean;
                             data_fetched : out Boolean)
   is
     use type ABM.MYSQL_RES_Access;
   begin
      data_fetched := False;
      if Stmt.result_handle /= null then
         Stmt.mysql_conn.all.free_result (Stmt.result_handle);
      end if;
      data_present := Stmt.mysql_conn.fetch_next_set;
      if not data_present then
         return;
      end if;
      declare
      begin
         Stmt.process_direct_result;
      exception
         when others =>
            Stmt.log_nominal (category => statement_execution,
                              message  => "Result set missing from: "
                                          & Stmt.sql_final.all);
            return;
      end;
      Stmt.internal_direct_post_exec (newset => True);
      data_fetched := True;
   end fetch_next_set;


   ---------------------------
   --  convert to Ada Time  --
   ---------------------------
   function convert (nv : String) return CAL.Time
   is
      len    : constant Natural  := nv'Length;
      year   : CAL.Year_Number   := CAL.Year_Number'First;
      month  : CAL.Month_Number  := CAL.Month_Number'First;
      day    : CAL.Day_Number    := CAL.Day_Number'First;
      hour   : CFM.Hour_Number   := CFM.Hour_Number'First;
      minute : CFM.Minute_Number := CFM.Minute_Number'First;
      second : CFM.Second_Number := CFM.Second_Number'First;
      cursor : Positive;
   begin
      case len is
         when 8 | 14 => cursor := 5;
         when others => cursor := 3;
      end case;
      year := Integer'Value (nv (nv'First .. cursor - 1));
      if len > 2 then
         month := Integer'Value (nv (cursor .. cursor + 1));
         cursor := cursor + 2;
         if len > 4 then
            day := Integer'Value (nv (cursor .. cursor + 1));
            cursor := cursor + 2;
            if len > 6 then
               hour := Integer'Value (nv (cursor .. cursor + 1));
               cursor := cursor + 2;
               if len > 8 then
                  minute := Integer'Value (nv (cursor .. cursor + 1));
                  cursor := cursor + 2;
                  if len > 10 then
                     second := Integer'Value (nv (cursor .. cursor + 1));
                  end if;
               end if;
            end if;
         end if;
      end if;
      --  If this raises an exception, it probable means the date < 1901 or
      --  greater than 2099.  Turn this into a string time in that case.
      return CFM.Time_Of (Year   => year,
                          Month  => month,
                          Day    => day,
                          Hour   => hour,
                          Minute => minute,
                          Second => second);
   end convert;


   ----------------------------------
   --  convert string to enumtype  --
   ----------------------------------
   function convert (nv : String) return AR.settype
   is
      num_enums : Natural := 1;
      nv_len    : Natural := nv'Length;
   begin
      for x in nv'Range loop
         if nv (x) = ',' then
            num_enums := num_enums + 1;
         end if;
      end loop;
      declare
         result : AR.settype (1 .. num_enums);
         cursor : Natural  := 1;
         curend : Natural  := 0;
         index  : Positive := 1;
      begin
         for x in nv'Range loop
            if nv (x) = ',' then
               result (index).enumeration := CT.SUS (nv (cursor .. curend));
               result (index).index := 0;  -- not supported on MySQL
               index := index + 1;
               cursor := x + 1;
            end if;
            curend := curend + 1;
         end loop;
         result (index).enumeration := CT.SUS (nv (cursor .. curend));
         result (index).index := 0;
         return result;
      end;
   end convert;


   ---------------------------------
   --  internal_fetch_row_direct  --
   ---------------------------------
   function internal_fetch_row (Stmt : out MySQL_statement)
                                return ARS.DataRow_Access
   is
      use type ABM.ICS.chars_ptr;
      use type ABM.MYSQL_ROW_access;
      rptr : ABM.MYSQL_ROW_access :=
        Stmt.mysql_conn.fetch_row (Stmt.result_handle);
   begin
      if rptr = null then
         Stmt.delivery := completed;
         Stmt.mysql_conn.free_result (Stmt.result_handle);
         Stmt.clear_column_information;
         return null;
      end if;
      Stmt.delivery := progressing;

      declare
         maxlen : constant Natural := Natural (Stmt.column_info.Length);
         type rowtype is array (1 .. maxlen) of ABM.ICS.chars_ptr;
         type rowtype_access is access all rowtype;

         row    : rowtype_access;
         result : ARS.DataRow_Access := new ARS.DataRow;

         field_lengths : constant ACM.fldlen := Stmt.mysql_conn.fetch_lengths
           (result_handle => Stmt.result_handle,
            num_columns   => maxlen);

         function Convert is new Ada.Unchecked_Conversion
           (Source => ABM.MYSQL_ROW_access, Target => rowtype_access);
      begin
         row := Convert (rptr);
         for F in 1 .. maxlen loop
            declare
               field    : ARF.field_access;
               last_one : constant Boolean := (F = maxlen);
               heading  : constant String := CT.USS
                 (Stmt.column_info.Element (Index => F).field_name);
               sz : constant Natural := field_lengths (F);
               EN : constant Boolean := row (F) = ABM.ICS.Null_Ptr;
               ST : constant String  := ABM.ICS.Value
                 (Item => row (F), Length => ABM.IC.size_t (sz));
               dvariant : ARF.variant;
            begin
               case Stmt.column_info.Element (Index => F).field_type is
                  when ft_nbyte0 =>
                     dvariant := (datatype => ft_nbyte0, v00 => ST = "1");
                  when ft_nbyte1 =>
                     dvariant := (datatype => ft_nbyte1, v01 => convert (ST));
                  when ft_nbyte2 =>
                     dvariant := (datatype => ft_nbyte2, v02 => convert (ST));
                  when ft_nbyte3 =>
                     dvariant := (datatype => ft_nbyte3, v03 => convert (ST));
                  when ft_nbyte4 =>
                     dvariant := (datatype => ft_nbyte4, v04 => convert (ST));
                  when ft_nbyte8 =>
                     dvariant := (datatype => ft_nbyte8, v05 => convert (ST));
                  when ft_byte1  =>
                     dvariant := (datatype => ft_byte1, v06 => convert (ST));
                  when ft_byte2  =>
                     dvariant := (datatype => ft_byte2, v07 => convert (ST));
                  when ft_byte3  =>
                     dvariant := (datatype => ft_byte3, v08 => convert (ST));
                  when ft_byte4  =>
                     dvariant := (datatype => ft_byte4, v09 => convert (ST));
                  when ft_byte8  =>
                     dvariant := (datatype => ft_byte8, v10 => convert (ST));
                  when ft_real9  =>
                     dvariant := (datatype => ft_real9, v11 => convert (ST));
                  when ft_real18 =>
                     dvariant := (datatype => ft_real18, v12 => convert (ST));
                  when ft_textual =>
                     dvariant := (datatype => ft_textual,
                                  v13 => convert (ST, Stmt.con_max_blob));
                  when ft_widetext =>
                     dvariant := (datatype => ft_widetext,
                                  v14 => convert (ST, Stmt.con_max_blob));
                  when ft_supertext =>
                     dvariant := (datatype => ft_supertext,
                                  v15 => convert (ST, Stmt.con_max_blob));
                  when ft_timestamp =>
                     begin
                        dvariant := (datatype => ft_timestamp,
                                     v16 => convert (ST));
                     exception
                        when CAL.Time_Error =>
                           dvariant := (datatype => ft_textual, v13 =>
                                           convert (ST, Stmt.con_max_blob));
                     end;
                  when ft_enumtype =>
                     --  It seems that mysql doesn't give up the enum index
                     --  easily.  Set to "0" for all members
                     dvariant := (datatype => ft_enumtype,
                                  V18 => (enumeration =>
                                             convert (ST, Stmt.con_max_blob),
                                            index => 0));
                  when others =>
                     null;

               end case;
               case Stmt.column_info.Element (Index => F).field_type is
                  when ft_chain =>
                     field := ARF.spawn_field
                       (binob => convert (ST, Stmt.con_max_blob));
                  when ft_settype =>
                     field := ARF.spawn_field (enumset => convert (ST));
                  when others =>
                     field := ARF.spawn_field (data => dvariant,
                                               null_data => EN);
               end case;

               result.push (heading    => heading,
                            field      => field,
                            last_field => last_one);
            end;
         end loop;
         return result;
      end;

   end internal_fetch_row;


   -----------------------------------
   --  internal_fetch_bound_direct  --
   -----------------------------------
   function internal_fetch_bound (Stmt : out MySQL_statement) return Boolean
   is
      use type ABM.ICS.chars_ptr;
      use type ABM.MYSQL_ROW_access;
      rptr : ABM.MYSQL_ROW_access :=
        Stmt.mysql_conn.fetch_row (Stmt.result_handle);
   begin
      if rptr = null then
         Stmt.delivery := completed;
         Stmt.mysql_conn.free_result (Stmt.result_handle);
         Stmt.clear_column_information;
         return False;
      end if;
      Stmt.delivery := progressing;

      declare
         maxlen : constant Natural := Natural (Stmt.column_info.Length);
         type rowtype is array (1 .. maxlen) of ABM.ICS.chars_ptr;
         type rowtype_access is access all rowtype;

         row : rowtype_access;
         field_lengths : constant ACM.fldlen := Stmt.mysql_conn.fetch_lengths
           (result_handle => Stmt.result_handle,
            num_columns   => maxlen);

         function Convert is new Ada.Unchecked_Conversion
           (Source => ABM.MYSQL_ROW_access, Target => rowtype_access);
      begin
         row := Convert (rptr);
         for F in 1 .. maxlen loop
            if Stmt.crate.Element (Index => F).bound then
               declare
                  last_one : constant Boolean := (F = maxlen);
                  heading  : constant String := CT.USS
                    (Stmt.column_info.Element (Index => F).field_name);
                  sz : constant Natural := field_lengths (F);
                  EN : constant Boolean := row (F) = ABM.ICS.Null_Ptr;
                  ST : constant String  := ABM.ICS.Value
                    (Item => row (F), Length => ABM.IC.size_t (sz));

                  Tout : constant field_types :=
                    Stmt.crate.Element (Index => F) .output_type;
                  Tnative : constant field_types :=
                    Stmt.column_info.Element (Index => F).field_type;
               begin
                  if Tnative /= Tout then
                     raise BINDING_TYPE_MISMATCH with "native type : " &
                       field_types'Image (Tnative) & " binding type : " &
                       field_types'Image (Tout);
                  end if;
                  case Tnative is
                     when ft_nbyte0 =>
                        Stmt.crate.Element (F).a00.all := (ST = "1");
                     when ft_nbyte1 =>
                        Stmt.crate.Element (F).a01.all := convert (ST);
                     when ft_nbyte2 =>
                        Stmt.crate.Element (F).a02.all := convert (ST);
                     when ft_nbyte3 =>
                        Stmt.crate.Element (F).a03.all := convert (ST);
                     when ft_nbyte4 =>
                        Stmt.crate.Element (F).a04.all := convert (ST);
                     when ft_nbyte8 =>
                        Stmt.crate.Element (F).a05.all := convert (ST);
                     when ft_byte1 =>
                        Stmt.crate.Element (F).a06.all := convert (ST);
                     when ft_byte2 =>
                        Stmt.crate.Element (F).a07.all := convert (ST);
                     when ft_byte3 =>
                        Stmt.crate.Element (F).a08.all := convert (ST);
                     when ft_byte4 =>
                        Stmt.crate.Element (F).a09.all := convert (ST);
                     when ft_byte8 =>
                        Stmt.crate.Element (F).a10.all := convert (ST);
                     when ft_real9  =>
                        Stmt.crate.Element (F).a11.all := convert (ST);
                     when ft_real18 =>
                        Stmt.crate.Element (F).a12.all := convert (ST);
                     when ft_textual =>
                        Stmt.crate.Element (F).a13.all :=
                          convert (ST, Stmt.con_max_blob);
                     when ft_widetext =>
                        Stmt.crate.Element (F).a14.all :=
                          convert (ST, Stmt.con_max_blob);
                     when ft_supertext =>
                        Stmt.crate.Element (F).a15.all :=
                          convert (ST, Stmt.con_max_blob);
                     when ft_timestamp =>
                        begin
                           Stmt.crate.Element (F).a16.all := convert (ST);
                        exception
                           when CAL.Time_Error =>
                              Stmt.crate.Element (F).a16.all := CAL.Time_Of
                                (Year  => CAL.Year_Number'First,
                                 Month => CAL.Month_Number'First,
                                 Day   => CAL.Day_Number'First);
                        end;
                     when ft_chain =>
                        if Stmt.crate.Element (F).a17.all'Length /= sz then
                           raise BINDING_SIZE_MISMATCH with "native size : " &
                             Stmt.crate.Element (F).a17.all'Length'Img &
                             " binding size : " & sz'Img;
                        end if;
                        Stmt.crate.Element (F).a17.all :=
                          convert (ST, Stmt.con_max_blob);
                     when ft_enumtype =>
                        --  It seems that mysql doesn't give up the enum index
                        --  easily.  Set to "0" for all members
                        Stmt.crate.Element (F).a18.all :=
                          (enumeration => convert (ST, Stmt.con_max_blob),
                           index => 0);
                     when ft_settype =>
                        Stmt.crate.Element (F).a19.all := convert (ST);
                  end case;
               end;
            end if;
         end loop;
         return True;
      end;
   end internal_fetch_bound;


   ----------------------------------
   --  internal_direct_post_exec   --
   ----------------------------------
   procedure internal_direct_post_exec (Stmt : out MySQL_statement;
                                        newset : Boolean := False) is
   begin
      Stmt.num_columns := 0;
      Stmt.successful_execution := False;
      if newset then
         Stmt.log_nominal (category => statement_execution,
                           message => "Fetch next rowset from: "
                                       & Stmt.sql_final.all);
      else
         Stmt.connection.execute (sql => Stmt.sql_final.all);
         Stmt.log_nominal (category => statement_execution,
                           message => Stmt.sql_final.all);
         Stmt.process_direct_result;
      end if;
      Stmt.successful_execution := True;
      if Stmt.result_present then
         Stmt.num_columns := Stmt.mysql_conn.fields_in_result
                               (Stmt.result_handle);
         if Stmt.con_buffered then
            Stmt.size_of_rowset := Stmt.mysql_conn.rows_in_result
                                     (Stmt.result_handle);
         end if;
         Stmt.scan_column_information;
         Stmt.delivery := pending;
      else
         declare
            returned_cols : Natural;
         begin
            returned_cols := Stmt.mysql_conn.all.field_count;
            if returned_cols = 0 then
               Stmt.impacted := Stmt.mysql_conn.rows_affected_by_execution;
            else
               raise ACM.RESULT_FAIL with "Columns returned without result";
            end if;
         end;
         Stmt.delivery := completed;
      end if;

   exception
      when ACM.QUERY_FAIL =>
         Stmt.log_problem (category   => statement_execution,
                           message    => Stmt.sql_final.all,
                           pull_codes => True);
      when RES : ACM.RESULT_FAIL =>
         Stmt.log_problem (category   => statement_execution,
                           message    => EX.Exception_Message (X => RES),
                           pull_codes => True);
   end internal_direct_post_exec;


   -------------------------------
   --  internal_post_prep_stmt  --
   -------------------------------
   procedure internal_post_prep_stmt (Stmt : out MySQL_statement) is
   begin
      Stmt.num_columns := 0;
      Stmt.process_direct_result;
      if Stmt.result_present then
         Stmt.num_columns := Stmt.mysql_conn.fields_in_result
                               (Stmt.result_handle);
         if Stmt.con_buffered then
            Stmt.size_of_rowset := Stmt.mysql_conn.rows_in_result
                                     (Stmt.result_handle);
         end if;
         Stmt.scan_column_information;
         Stmt.delivery := pending;
      else
         declare
            returned_cols : Natural;
         begin
            returned_cols := Stmt.mysql_conn.all.field_count;
            if returned_cols = 0 then
               Stmt.impacted := Stmt.mysql_conn.rows_affected_by_execution;
            else
               raise ACM.RESULT_FAIL with "Columns returned without result";
            end if;
         end;
         Stmt.delivery := completed;
      end if;
   end internal_post_prep_stmt;


   ---------------------------
   --  construct_bind_slot  --
   ---------------------------
   procedure construct_bind_slot (Stmt   : MySQL_statement;
                                  struct : out ABM.MYSQL_BIND;
                                  canvas : out mysql_canvas;
                                  marker : Positive)
   is
      zone    : bindrec renames Stmt.realmccoy.Element (marker);
      vartype : constant field_types := zone.output_type;

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
      use type AR.settype_access;
   begin
      case vartype is
         when ft_nbyte0 | ft_nbyte1 | ft_nbyte2 | ft_nbyte3 | ft_nbyte4 |
              ft_nbyte8 => struct.is_unsigned := 1;
         when others => null;
      end case;
      case vartype is
         when ft_nbyte0 => struct.buffer_type := ABM.MYSQL_TYPE_TINY;
            if zone.a00 = null then
               if zone.v00 then
                  canvas.buffer_uint8 := 1;
               end if;
            else
               if zone.a00.all then
                  canvas.buffer_uint8 := 1;
               end if;
            end if;
            struct.buffer := canvas.buffer_uint8'Address;
         when ft_nbyte1 =>
            struct.buffer_type := ABM.MYSQL_TYPE_TINY;
            struct.buffer      := canvas.buffer_uint8'Address;
            if zone.a01 = null then
               canvas.buffer_uint8 := ABM.IC.unsigned_char (zone.v01);
            else
               canvas.buffer_uint8 := ABM.IC.unsigned_char (zone.a01.all);
            end if;
         when ft_nbyte2 =>
            struct.buffer_type := ABM.MYSQL_TYPE_SHORT;
            struct.buffer      := canvas.buffer_uint16'Address;
            if zone.a02 = null then
               canvas.buffer_uint16 := ABM.IC.unsigned_short (zone.v02);
            else
               canvas.buffer_uint16 := ABM.IC.unsigned_short (zone.a02.all);
            end if;
         when ft_nbyte3 =>
            struct.buffer_type := ABM.MYSQL_TYPE_LONG;
            struct.buffer      := canvas.buffer_uint32'Address;
            --  ABM.MYSQL_TYPE_INT24 not for input, use next biggest
            if zone.a03 = null then
               canvas.buffer_uint32 := ABM.IC.unsigned (zone.v03);
            else
               canvas.buffer_uint32 := ABM.IC.unsigned (zone.a03.all);
            end if;
         when ft_nbyte4 =>
            struct.buffer_type := ABM.MYSQL_TYPE_LONG;
            struct.buffer      := canvas.buffer_uint32'Address;
            if zone.a04 = null then
               canvas.buffer_uint32 := ABM.IC.unsigned (zone.v04);
            else
               canvas.buffer_uint32 := ABM.IC.unsigned (zone.a04.all);
            end if;
         when ft_nbyte8 =>
            struct.buffer_type := ABM.MYSQL_TYPE_LONGLONG;
            struct.buffer      := canvas.buffer_uint64'Address;
            if zone.a05 = null then
               canvas.buffer_uint64 := ABM.IC.unsigned_long (zone.v05);
            else
               canvas.buffer_uint64 := ABM.IC.unsigned_long (zone.a05.all);
            end if;
         when ft_byte1 =>
            struct.buffer_type := ABM.MYSQL_TYPE_TINY;
            struct.buffer      := canvas.buffer_int8'Address;
            if zone.a06 = null then
               canvas.buffer_int8 := ABM.IC.signed_char (zone.v06);
            else
               canvas.buffer_int8 := ABM.IC.signed_char (zone.a06.all);
            end if;
         when ft_byte2 =>
            struct.buffer_type := ABM.MYSQL_TYPE_SHORT;
            struct.buffer      := canvas.buffer_int16'Address;
            if zone.a07 = null then
               canvas.buffer_int16 := ABM.IC.short (zone.v07);
            else
               canvas.buffer_int16 := ABM.IC.short (zone.a07.all);
            end if;
         when ft_byte3 =>
            struct.buffer_type := ABM.MYSQL_TYPE_LONG;
            struct.buffer      := canvas.buffer_int32'Address;
            --  ABM.MYSQL_TYPE_INT24 not for input, use next biggest
            if zone.a08 = null then
               canvas.buffer_int32 := ABM.IC.int (zone.v08);
            else
               canvas.buffer_int32 := ABM.IC.int (zone.a08.all);
            end if;
         when ft_byte4 =>
            struct.buffer_type := ABM.MYSQL_TYPE_LONG;
            struct.buffer      := canvas.buffer_int32'Address;
            if zone.a09 = null then
               canvas.buffer_int32 := ABM.IC.int (zone.v09);
            else
               canvas.buffer_int32 := ABM.IC.int (zone.a09.all);
            end if;
         when ft_byte8 =>
            struct.buffer_type := ABM.MYSQL_TYPE_LONGLONG;
            struct.buffer      := canvas.buffer_int64'Address;
            if zone.a10 = null then
               canvas.buffer_int64 := ABM.IC.long (zone.v10);
            else
               canvas.buffer_int64 := ABM.IC.long (zone.a10.all);
            end if;
         when ft_real9 =>
            struct.buffer_type := ABM.MYSQL_TYPE_FLOAT;
            struct.buffer      := canvas.buffer_float'Address;
            if zone.a11 = null then
               canvas.buffer_float := ABM.IC.C_float (zone.v11);
            else
               canvas.buffer_float := ABM.IC.C_float (zone.a11.all);
            end if;
         when ft_real18 =>
            struct.buffer_type := ABM.MYSQL_TYPE_DOUBLE;
            struct.buffer      := canvas.buffer_double'Address;
            if zone.a12 = null then
               canvas.buffer_double := ABM.IC.double (zone.v12);
            else
               canvas.buffer_double := ABM.IC.double (zone.a12.all);
            end if;
         when ft_textual =>
            struct.buffer_type := ABM.MYSQL_TYPE_STRING;
            struct.buffer      := canvas.buffer_binary'Address;
            struct.length      := canvas.length'Unchecked_Access;
            if zone.a13 = null then
               declare
                  str : constant String := ARC.convert (zone.v13);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            else
               declare
                  str : constant String := ARC.convert (zone.a13.all);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            end if;
         when ft_widetext =>
            struct.buffer_type := ABM.MYSQL_TYPE_STRING;
            struct.buffer      := canvas.buffer_binary'Address;
            struct.length      := canvas.length'Unchecked_Access;
            if zone.a14 = null then
               declare
                  str : constant String := ARC.convert (zone.v14);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            else
               declare
                  str : constant String := ARC.convert (zone.a14.all);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            end if;
         when ft_supertext =>
            struct.buffer_type := ABM.MYSQL_TYPE_STRING;
            struct.buffer      := canvas.buffer_binary'Address;
            struct.length      := canvas.length'Unchecked_Access;
            if zone.a15 = null then
               declare
                  str : constant String := ARC.convert (zone.v15);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            else
               declare
                  str : constant String := ARC.convert (zone.a15.all);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            end if;
         when ft_timestamp =>
            struct.buffer_type := ABM.MYSQL_TYPE_DATETIME;
            struct.buffer      := canvas.buffer_time'Address;
            declare
               hack : CAL.Time;
            begin
               if zone.a16 = null then
                  hack := zone.v16;
               else
                  hack := zone.a16.all;
               end if;
               --  Negative time not supported
               canvas.buffer_time.year   := ABM.IC.unsigned (CFM.Year (hack));
               canvas.buffer_time.month  := ABM.IC.unsigned (CFM.Month (hack));
               canvas.buffer_time.day    := ABM.IC.unsigned (CFM.Day (hack));
               canvas.buffer_time.hour   := ABM.IC.unsigned (CFM.Hour (hack));
               canvas.buffer_time.minute := ABM.IC.unsigned (CFM.Minute (hack));
               canvas.buffer_time.second := ABM.IC.unsigned (CFM.Second (hack));
               canvas.buffer_time.second_part :=
                 ABM.IC.unsigned_long (CFM.Sub_Second (hack) * 1000000);
            end;
         when ft_chain =>
            struct.buffer_type := ABM.MYSQL_TYPE_BLOB;
            struct.buffer      := canvas.buffer_binary'Address;
            struct.length      := canvas.length'Unchecked_Access;
            --  Chains are only available via access
            canvas.length := ABM.IC.unsigned_long (zone.a17.all'Length);
            declare
               chainstr : String (1 .. zone.a17.all'Length);
            begin
               for x in chainstr'Range loop
                  chainstr (x) := Character'Val (zone.a17.all (x));
               end loop;
               canvas.buffer_binary := ABM.ICS.New_Char_Array
                 (ABM.IC.To_C (Item => chainstr, Append_Nul => False));
            end;
         when ft_enumtype =>
            --  ENUM is essentially a specific string on MySQL
            struct.buffer_type := ABM.MYSQL_TYPE_STRING;
            struct.buffer      := canvas.buffer_binary'Address;
            struct.length      := canvas.length'Unchecked_Access;
            if zone.a18 = null then
               declare
                  str : constant String := ARC.convert (zone.v18);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            else
               declare
                  str : constant String := ARC.convert (zone.a18.all);
               begin
                  canvas.buffer_binary := ABM.ICS.New_String (str);
                  canvas.length := ABM.IC.unsigned_long (str'Length + 1);
               end;
            end if;
         when ft_settype =>
            --  Set types are imploded strings on MySQL
            --  Only access is available here
            struct.buffer_type := ABM.MYSQL_TYPE_STRING;
            struct.buffer      := canvas.buffer_binary'Address;
            struct.length      := canvas.length'Unchecked_Access;
            declare
               str : constant String := ARC.convert (zone.a19);
            begin
               canvas.buffer_binary := ABM.ICS.New_String (str);
               canvas.length := ABM.IC.unsigned_long (str'Length + 1);
            end;
      end case;
   end construct_bind_slot;


   -------------------
   --  log_problem  --
   -------------------
   procedure log_problem
     (statement  : MySQL_statement;
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


--     -------------------
--     --  auto_assign  --
--     -------------------
--     procedure auto_assign (Stmt  : out Base_Statement;
--                            index : Positive;
--                            value : String)
--     is
--     begin
--        --  this reads the column metadata, converts the value string to
--        --  native type and calls the correct assign
--
--        null;
--        case Stmt.column_info.Element (index).field_type is
--           when ft_nbyte0 => Stmt.assign (index, (value = "1"));
--           when ft_nbyte1 => Stmt.assign (index, AR.nbyte1 (convert (ST)));
--           when ft_nbyte2 => Stmt.assign (index, AR.nbyte2 (convert (ST)));
--           when ft_nbyte3 => Stmt.assign (index, AR.nbyte3 (convert (ST)));
--           when ft_nbyte4 => Stmt.assign (index, AR.nbyte4 (convert (ST)));
--           when ft_nbyte8 => Stmt.assign (index, AR.nbyte8 (convert (ST)));
--                    when ft_nbyte1 =>
--                       dvariant := (datatype => ft_nbyte1, v01 => convert (ST));
--                    when ft_nbyte2 =>
--                       dvariant := (datatype => ft_nbyte2, v02 => convert (ST));
--                    when ft_nbyte3 =>
--                       dvariant := (datatype => ft_nbyte3, v03 => convert (ST));
--                    when ft_nbyte4 =>
--                       dvariant := (datatype => ft_nbyte4, v04 => convert (ST));
--                    when ft_nbyte8 =>
--                       dvariant := (datatype => ft_nbyte8, v05 => convert (ST));
--                    when ft_byte1  =>
--                       dvariant := (datatype => ft_byte1, v06 => convert (ST));
--                    when ft_byte2  =>
--                       dvariant := (datatype => ft_byte2, v07 => convert (ST));
--                    when ft_byte3  =>
--                       dvariant := (datatype => ft_byte3, v08 => convert (ST));
--                    when ft_byte4  =>
--                       dvariant := (datatype => ft_byte4, v09 => convert (ST));
--                    when ft_byte8  =>
--                       dvariant := (datatype => ft_byte8, v10 => convert (ST));
--                    when ft_real9  =>
--                       dvariant := (datatype => ft_real9, v11 => convert (ST));
--                    when ft_real18 =>
--                       dvariant := (datatype => ft_real18, v12 => convert (ST));
--                    when ft_textual =>
--                       dvariant := (datatype => ft_textual,
--                                    v13 => convert (ST, Stmt.con_max_blob));
--                    when ft_widetext =>
--                       dvariant := (datatype => ft_widetext,
--                                    v14 => convert (ST, Stmt.con_max_blob));
--                    when ft_supertext =>
--                       dvariant := (datatype => ft_supertext,
--                                    v15 => convert (ST, Stmt.con_max_blob));
--                    when ft_timestamp =>
--                       begin
--                          dvariant := (datatype => ft_timestamp,
--                                       v16 => convert (ST));
--                       exception
--                          when CAL.Time_Error =>
--                             dvariant := (datatype => ft_textual, v13 =>
--                                             convert (ST, Stmt.con_max_blob));
--                       end;
--                    when ft_enumtype =>
--                       --  It seems that mysql doesn't give up the enum index
--                       --  easily.  Set to "0" for all members
--                       dvariant := (datatype => ft_enumtype,
--                                    V18 => (enumeration =>
--                                               convert (ST, Stmt.con_max_blob),
--                                              index => 0));
--                    when others =>
--                       null;
--
--                 end case;
--                 case Stmt.column_info.Element (Index => F).field_type is
--                    when ft_chain =>
--                       field := ARF.spawn_field
--                         (binob => convert (ST, Stmt.con_max_blob));
--                    when ft_settype =>
--                       field := ARF.spawn_field (enumset => convert (ST));
--                    when others =>
--                       field := ARF.spawn_field (data => dvariant,
--                                                 null_data => EN);
--                 end case;
--   end auto_assign;

end AdaBase.Statement.Base.MySQL;

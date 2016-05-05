--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

package body AdaBase.Statement.Base is

   ------------------
   --  successful  --
   ------------------
   overriding
   function successful  (Stmt : Base_Statement) return Boolean
   is
   begin
      return Stmt.successful_execution;
   end successful;


   ----------------------
   --  data_discarded  --
   ----------------------
   overriding
   function data_discarded  (Stmt : Base_Statement) return Boolean
   is
   begin
      return Stmt.rows_leftover;
   end data_discarded;


   ---------------------
   --  rows_affected  --
   ---------------------
   overriding
   function rows_affected (Stmt : Base_Statement) return AffectedRows
   is
   begin
      if not Stmt.successful_execution then
         raise PRIOR_EXECUTION_FAILED
           with "Has query been executed yet?";
      end if;
      if Stmt.result_present then
         raise INVALID_FOR_RESULT_SET
           with "Result set found; use rows_returned";
      else
         return Stmt.impacted;
      end if;
   end rows_affected;


   ---------------------
   --  transform_sql  --
   ---------------------
   procedure transform_sql (Stmt : out Base_Statement; sql : String;
                            new_sql : out String)
   is
      sql_mask : String := sql;
   begin
      new_sql := sql;
      Stmt.alpha_markers.Clear;
      Stmt.realmccoy.Clear;
      if sql'Length = 0 then
         return;
      end if;
      declare
         --  This block will mask anything between quotes (single or double)
         --  These are considered to be literal and not suitable for binding
         type seeking is (none, single, double);
         seek_status : seeking := none;
         arrow : Positive := 1;
      begin
         loop
            case sql (arrow) is
               when ''' =>
                  case seek_status is
                     when none =>
                        seek_status := single;
                        sql_mask (arrow) := '#';
                     when single =>
                        seek_status := none;
                        sql_mask (arrow) := '#';
                     when double => null;
                  end case;
               when ASCII.Quotation =>
                  case seek_status is
                     when none =>
                        seek_status := double;
                        sql_mask (arrow) := '#';
                     when double =>
                        seek_status := none;
                        sql_mask (arrow) := '#';
                     when single => null;
                  end case;
               when others => null;
            end case;
            exit when arrow = sql'Length;
            arrow := arrow + 1;
         end loop;
      end;
      declare
         --  This block does two things:
         --  1) finds "?" and increments the replacement index
         --  2) finds ":[A-Za-z0-9]*", replaces with "?", increments the
         --     replacement index, and pushes the string into alpha markers
         --  Normally ? and : aren't mixed but we will support it.
         procedure replace_alias;
         procedure save_classic_marker;
         start    : Natural  := 0;
         final    : Natural  := 0;
         arrow    : Positive := 1;
         scanning : Boolean  := False;

         procedure replace_alias is
            len    : Natural := final - start;
            alias  : String (1 .. len) := sql_mask (start + 1 .. final);
            scab   : String (1 .. len + 1) := ('?', others => ' ');
            brec   : bindrec;
         begin
            if Stmt.alpha_markers.Contains (Key => alias) then
               raise ILLEGAL_BIND_SQL with "multiple instances of " & alias;
            end if;
            brec.v00 := False;
            Stmt.realmccoy.Append (New_Item => brec);
            Stmt.alpha_markers.Insert (Key => alias,
                                       New_Item => Stmt.realmccoy.Last_Index);
            new_sql (start .. final) := scab;
            scanning := False;
         end replace_alias;

         procedure save_classic_marker
         is
            brec   : bindrec;
         begin
            brec.v00 := False;
            Stmt.realmccoy.Append (New_Item => brec);
         end save_classic_marker;

         adjacent_error : constant String :=
                          "Bindings are not separated; they are touching: ";

      begin
         loop
            case sql_mask (arrow) is
               when ASCII.Query =>
                  if scanning then
                     raise ILLEGAL_BIND_SQL
                       with adjacent_error & new_sql (start .. arrow);
                  end if;
                  save_classic_marker;
               when ASCII.Colon =>
                  if scanning then
                     raise ILLEGAL_BIND_SQL
                       with adjacent_error & new_sql (start .. arrow);
                  end if;
                  scanning := True;
                  start := arrow;
               when others =>
                  if scanning then
                     case sql_mask (arrow) is
                        when 'A' .. 'Z' | 'a' .. 'z' | '0' .. '9' | '_' =>
                           final := arrow;
                        when others => replace_alias;
                     end case;
                  end if;
            end case;
            if scanning and then arrow = sql_mask'Length then
               replace_alias;
            end if;
            exit when arrow = sql_mask'Length;
            arrow := arrow + 1;
         end loop;
      end;
   end transform_sql;


   -------------------------------
   --  convert string to chain  --
   -------------------------------
   function convert (nv : String; maxsize : BLOB_maximum) return AR.chain
   is
      maxlinks : Natural := nv'Last;
   begin
      if maxlinks > maxsize then
         maxlinks := maxsize;
      end if;
      declare
         result : AR.chain (nv'First .. maxlinks);
      begin
         for x in 1 .. maxlinks loop
            result (x) := AR.nbyte1 (Character'Pos (nv (x)));
         end loop;
         return result;
      end;
   end convert;


   ---------------------------------
   --  convert string to textual  --
   ---------------------------------
   function convert (nv : String; maxsize : BLOB_maximum) return AR.textual
   is
      maxlinks : Natural := nv'Last;
   begin
      if maxlinks > maxsize then
         maxlinks := maxsize;
      end if;
      return CT.SUS (nv (nv'First .. maxlinks));
   end convert;


   -------------------------------------
   --  convert string to textwide #1  --
   -------------------------------------
   function convert (nv : String; maxsize : BLOB_maximum) return AR.textwide
   is
      maxlinks : Natural := nv'Last;
   begin
      if maxlinks > maxsize then
         maxlinks := maxsize;
      end if;
      return SUW.To_Unbounded_Wide_String
        (ACC.To_Wide_String (nv (nv'First .. maxlinks)));
   end convert;


   -------------------------------------
   --  convert string to textwide #2  --
   -------------------------------------
   function convert (nv : String) return AR.textwide is
   begin
      return SUW.To_Unbounded_Wide_String (ACC.To_Wide_String (nv));
   end convert;


   --------------------------------------
   --  convert string to textsuper #1  --
   --------------------------------------
   function convert (nv : String; maxsize : BLOB_maximum) return AR.textsuper
   is
      maxlinks : Natural := nv'Last;
   begin
      if maxlinks > maxsize then
         maxlinks := maxsize;
      end if;
      return SWW.To_Unbounded_Wide_Wide_String
        (ACC.To_Wide_Wide_String (nv (nv'First .. maxlinks)));
   end convert;


   --------------------------------------
   --  convert string to textsuper #2  --
   --------------------------------------
   function convert (nv : String) return AR.textsuper is
   begin
      return SWW.To_Unbounded_Wide_Wide_String (ACC.To_Wide_Wide_String (nv));
   end convert;


   --------------------
   --  Same_Strings  --
   --------------------
   function Same_Strings (S, T : String) return Boolean is
   begin
      return S = T;
   end Same_Strings;


   -------------------
   --  log_nominal  --
   -------------------
   procedure log_nominal (statement : Base_Statement;
                          category  : LogCategory;
                          message   : String)
   is
   begin
      logger_access.all.log_nominal
        (driver   => statement.dialect,
         category => category,
         message  => CT.SUS (message));
   end log_nominal;


   --------------------
   --  bind_proceed  --
   --------------------
   function bind_proceed (Stmt : Base_Statement; index : Positive)
                          return Boolean is
   begin
      if not Stmt.successful_execution then
         raise PRIOR_EXECUTION_FAILED
           with "Use bind after 'execute' but before 'fetch_next'";
      end if;
      if index > Stmt.crate.Last_Index then
         raise BINDING_COLUMN_NOT_FOUND
           with "Index" & index'Img & " is too high; only" &
           Stmt.crate.Last_Index'Img & " columns exist.";
      end if;
      return True;
   end bind_proceed;


   ------------------
   --  bind_index  --
   ------------------
   function bind_index (Stmt : Base_Statement; heading : String)
                        return Positive
   is
      use type Markers.Cursor;
      cursor : Markers.Cursor;
   begin
      cursor := Stmt.headings_map.Find (Key => heading);
      if cursor = Markers.No_Element then
         raise BINDING_COLUMN_NOT_FOUND with
           "There is no column named '" & heading & "'.";
      end if;
      return Markers.Element (Position => cursor);
   end bind_index;


   ------------------------------------------------------
   --  20 bind functions (impossible to make generic)  --
   ------------------------------------------------------
   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte0_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_nbyte0, a00 => vaxx, v00 => False,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte1_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_nbyte1, a01 => vaxx, v01 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte2_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_nbyte2, a02 => vaxx, v02 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte3_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_nbyte3, a03 => vaxx, v03 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte4_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_nbyte4, a04 => vaxx, v04 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte8_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_nbyte8, a05 => vaxx, v05 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte1_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_byte1, a06 => vaxx, v06 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte2_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_byte2, a07 => vaxx, v07 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte3_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_byte3, a08 => vaxx, v08 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte4_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_byte4, a09 => vaxx, v09 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte8_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_byte8, a10 => vaxx, v10 => 0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.real9_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_real9, a11 => vaxx, v11 => 0.0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.real18_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_real18, a12 => vaxx, v12 => 0.0,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.str1_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_textual, a13 => vaxx, v13 => CT.blank,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.str2_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_widetext, a14 => vaxx,
                    v14 => SUW.Null_Unbounded_Wide_String, bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.str4_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_supertext, a15 => vaxx,
                    v15 => SWW.Null_Unbounded_Wide_Wide_String,
                    bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.time_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_timestamp, a16 => vaxx,
                    v16 => CAL.Clock, bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.chain_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_chain, a17 => vaxx,
                    v17 => CT.blank, bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.enum_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_enumtype, a18 => vaxx,
                    v18 => (CT.blank, 0), bound => True));
      end if;
   end bind;

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.settype_access) is
   begin
      if Stmt.bind_proceed (index => index) then
         Stmt.crate.Replace_Element
           (index, (output_type => ft_settype, a19 => vaxx,
                    v19 => CT.blank, bound => True));
      end if;
   end bind;


   ------------------------------------------------------------------
   --  bind via headings  (believe me, generics are not possible)  --
   ------------------------------------------------------------------
   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte0_access) is
   begin
      Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte1_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte2_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte3_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte4_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte8_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte1_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte2_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte3_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte4_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte8_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.real9_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.real18_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.str1_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.str2_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.str4_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.time_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.chain_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.enum_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.settype_access) is
   begin
        Stmt.bind (vaxx => vaxx, index => Stmt.bind_index (heading));
   end bind;


   --------------------
   --  assign_index  --
   --------------------
   function assign_index (Stmt : Base_Statement; moniker : String)
                          return Positive
   is
      use type Markers.Cursor;
      cursor : Markers.Cursor;
   begin
      cursor := Stmt.alpha_markers.Find (Key => moniker);
      if cursor = Markers.No_Element then
         raise MARKER_NOT_FOUND with
           "There is no marker known as '" & moniker & "'.";
      end if;
      return Markers.Element (Position => cursor);
   end assign_index;


   ------------------------------------------------------------------
   --  assign via moniker (Access, 20)                                        --
   ------------------------------------------------------------------
   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte0_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte1_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte2_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte3_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte4_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte8_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte1_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte2_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte3_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte4_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte8_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real9_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real18_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.str1_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.str2_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.str4_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.time_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.chain_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.enum_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.settype_access) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;


   ------------------------------------------------------------------
   --  assign via moniker (Value, 20)                                        --
   ------------------------------------------------------------------
   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte0) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte1) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte2) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte3) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte4) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte8) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte1) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte2) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte3) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte4) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte8) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real9) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real18) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : String) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.textual) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.textwide) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.textsuper) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : CAL.Time) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.chain) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.enumtype) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.settype) is
   begin
      Stmt.assign (vaxx => vaxx, index => Stmt.assign_index (moniker));
   end assign;

   ------------------------------------------------------
   --  20 + 20 = 40 assign functions                   --
   ------------------------------------------------------
   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte0_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte0, a00 => vaxx, v00 => False,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte0) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte0, a00 => null, v00 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte1_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte1, a01 => vaxx, v01 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte1) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte1, a01 => null, v01 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte2_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte2, a02 => vaxx, v02 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte2) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte2, a02 => null, v02 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte3_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte3, a03 => vaxx, v03 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte3) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte3, a03 => null, v03 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte4_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte4, a04 => vaxx, v04 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte4) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte4, a04 => null, v04 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte8_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte8, a05 => vaxx, v05 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte8) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_nbyte8, a05 => null, v05 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte1_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte1, a06 => vaxx, v06 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte1) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte1, a06 => null, v06 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte2_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte2, a07 => vaxx, v07 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte2) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte2, a07 => null, v07 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte3_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte3, a08 => vaxx, v08 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte3) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte3, a08 => null, v08 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte4_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte4, a09 => vaxx,  v09 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte4) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte4, a09 => null,  v09 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte8_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte8, a10 => vaxx,  v10 => 0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte8) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_byte8, a10 => null,  v10 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real9_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_real9, a11 => vaxx, v11 => 0.0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real9) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_real9, a11 => null, v11 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real18_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_real18, a12 => vaxx, v12 => 0.0,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real18) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_real18, a12 => null, v12 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.str1_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_textual, a13 => vaxx, v13 => CT.blank,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : String) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_textual, a13 => null, v13 => CT.SUS (vaxx),
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.textual) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_textual, a13 => null, v13 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.str2_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_widetext, a14 => vaxx,
                 v14 => SUW.Null_Unbounded_Wide_String, bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.textwide) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_widetext, a14 => null, v14 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.str4_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_supertext, a15 => vaxx,
                 v15 => SWW.Null_Unbounded_Wide_Wide_String,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.textsuper) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_supertext, a15 => null, v15 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.time_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_timestamp, a16 => vaxx,
                 v16 => CAL.Clock, bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : CAL.Time) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_timestamp, a16 => null, v16 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.chain_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_chain, a17 => vaxx,
                 v17 => CT.blank, bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.chain)
   is
      payload : String := (vaxx'Range => '_');
   begin
      for x in vaxx'Range loop
         payload (x) := Character'Val (vaxx (x));
      end loop;
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_chain, a17 => null,
                 v17 => CT.SUS (payload), bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.enum_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_enumtype, a18 => vaxx,
                 v18 => (CT.blank, 0), bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.enumtype) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_enumtype, a18 => null, v18 => vaxx,
                 bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.settype_access) is
   begin
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_settype, a19 => vaxx,
                 v19 => CT.blank, bound => True));
   end assign;

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.settype)
   is
      payload : AR.textual := CT.blank;
   begin
      for x in vaxx'Range loop
         if x /= vaxx'First then
            CT.SU.Append (payload, ",");
         end if;
         CT.SU.Append (payload, vaxx (x).enumeration);
      end loop;
      Stmt.realmccoy.Replace_Element
        (index, (output_type => ft_settype, a19 => null,
                 v19 => payload, bound => True));
   end assign;


end AdaBase.Statement.Base;

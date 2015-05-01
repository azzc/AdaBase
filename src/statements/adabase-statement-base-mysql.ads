--
--  Copyright (c) 2015 John Marino <draco@marino.st>
--
--  Permission to use, copy, modify, and distribute this software for any
--  purpose with or without fee is hereby granted, provided that the above
--  copyright notice and this permission notice appear in all copies.
--
--  THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
--  WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
--  MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
--  ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
--  WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
--  ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
--  OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
--

with AdaBase.Connection.Base.MySQL;
with AdaBase.Bindings.MySQL;

package AdaBase.Statement.Base.MySQL is

   package ACM renames AdaBase.Connection.Base.MySQL;
   package ABM renames AdaBase.Bindings.MySQL;

   type MySQL_statement (<>) is limited new Base_Statement and AIS.iStatement
     with private;

   overriding
   function successful  (Stmt : MySQL_statement) return Boolean;

   overriding
   function column_count (Stmt : MySQL_statement) return Natural;

   overriding
   function last_insert_id (Stmt : MySQL_statement) return TraxID;

   overriding
   function last_sql_state (Stmt : MySQL_statement) return TSqlState;

   overriding
   function last_driver_code (Stmt : MySQL_statement) return DriverCodes;

   overriding
   function last_driver_message (Stmt : MySQL_statement) return String;

   overriding
   procedure discard_rest  (Stmt : out MySQL_statement;
                            was_complete : out Boolean);

   ------------------------------------------------
   --  These routines are not part of interface  --
   ------------------------------------------------

   procedure clear_buffer (Stmt : out MySQL_statement);


private
   type MySQL_statement (con_handle      : ACM.MySQL_Connection_Access;
                         con_error_mode  : ErrorMode;
                         con_case_mode   : CaseMode;
                         con_string_mode : StringMode;
                         con_max_blob    : BLOB_maximum;
                         con_buffered    : Boolean)
   is limited new Base_Statement and AIS.iStatement with
      record
         stmt_handle : ABM.MYSQL_STMT_Access := null;
         res_handle  : ABM.MYSQL_RES_Access  := null;
         num_columns : Natural := 0;
      end record;

end AdaBase.Statement.Base.MySQL;

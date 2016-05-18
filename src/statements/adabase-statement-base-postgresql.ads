--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with Ada.Containers;
with AdaBase.Connection.Base.PostgreSQL;
with AdaBase.Bindings.PostgreSQL;

package AdaBase.Statement.Base.PostgreSQL is

   package BND renames AdaBase.Bindings.PostgreSQL;
   package CON renames AdaBase.Connection.Base.PostgreSQL;
   package AC  renames Ada.Containers;

   type PostgreSQL_statement
     (type_of_statement : stmt_type;
      log_handler       : ALF.LogFacility_access;
      pgsql_conn        : CON.PostgreSQL_Connection_Access;
      initial_sql       : SQL_access;
      con_error_mode    : ErrorMode;
      con_case_mode     : CaseMode;
      con_max_blob      : BLOB_maximum;
      con_buffered      : Boolean)
   is new Base_Statement and AIS.iStatement with private;
   type PostgreSQL_statement_access is access all PostgreSQL_statement;

   overriding
   function column_count (Stmt : PostgreSQL_statement) return Natural;

   overriding
   function last_insert_id (Stmt : PostgreSQL_statement) return TraxID;

   overriding
   function last_sql_state (Stmt : PostgreSQL_statement) return TSqlState;

   overriding
   function last_driver_code (Stmt : PostgreSQL_statement) return DriverCodes;

   overriding
   function last_driver_message (Stmt : PostgreSQL_statement) return String;

   overriding
   procedure discard_rest (Stmt : out PostgreSQL_statement);

   overriding
   function execute   (Stmt : out PostgreSQL_statement) return Boolean;

   overriding
   function execute   (Stmt : out PostgreSQL_statement; parameters : String;
                       delimiter  : Character := '|') return Boolean;

   overriding
   function rows_returned (Stmt : PostgreSQL_statement) return AffectedRows;

   overriding
   function column_name   (Stmt : PostgreSQL_statement; index : Positive)
                           return String;

   overriding
   function column_table  (Stmt : PostgreSQL_statement; index : Positive)
                           return String;

   overriding
   function column_native_type (Stmt : PostgreSQL_statement; index : Positive)
                                return field_types;

   overriding
   function fetch_next (Stmt : out PostgreSQL_statement) return ARS.DataRow;

   overriding
   function fetch_all  (Stmt : out PostgreSQL_statement) return ARS.DataRowSet;

   overriding
   function fetch_bound (Stmt : out PostgreSQL_statement) return Boolean;

   overriding
   procedure fetch_next_set (Stmt         : out PostgreSQL_statement;
                             data_present : out Boolean;
                             data_fetched : out Boolean);


private

   type fetch_status is (pending, progressing, completed);

   type column_info is record
      table         : CT.Text;
      field_name    : CT.Text;
      field_type    : field_types;
      field_size    : Natural;
      null_possible : Boolean;
      --  mysql_type    : ABM.enum_field_types;
   end record;

   package VColumns is new AC.Vectors (Index_Type   => Positive,
                                       Element_Type => column_info);

   type PostgreSQL_statement
     (type_of_statement : stmt_type;
      log_handler       : ALF.LogFacility_access;
      pgsql_conn        : CON.PostgreSQL_Connection_Access;
      initial_sql       : SQL_access;
      con_error_mode    : ErrorMode;
      con_case_mode     : CaseMode;
      con_max_blob      : BLOB_maximum;
      con_buffered      : Boolean)
   is new Base_Statement and AIS.iStatement with
      record
         delivery       : fetch_status          := completed;
         result_handle  : BND.PGresult_Access   := null;
         assign_counter : Natural               := 0;
         num_columns    : Natural               := 0;
         size_of_rowset : TraxID                := 0;
         column_info    : VColumns.Vector;
         sql_final      : SQL_access;
      end record;

   function reformat_markers (parameterized_sql : String) return String;

end AdaBase.Statement.Base.PostgreSQL;
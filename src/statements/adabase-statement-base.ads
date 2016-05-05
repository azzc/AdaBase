--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with CommonText;
with AdaBase.Connection.Base;
with AdaBase.Interfaces.Statement;
with AdaBase.Logger.Facility;
with AdaBase.Results.Converters;
with AdaBase.Results.Generic_Converters;
with Ada.Calendar.Formatting;
with Ada.Containers.Indefinite_Hashed_Maps;
with Ada.Containers.Vectors;
with Ada.Strings.Hash;
with Ada.Strings.Wide_Unbounded;
with Ada.Strings.Wide_Wide_Unbounded;
with Ada.Characters.Conversions;

package AdaBase.Statement.Base is

   package CT  renames CommonText;
   package SUW renames Ada.Strings.Wide_Unbounded;
   package SWW renames Ada.Strings.Wide_Wide_Unbounded;
   package CAL renames Ada.Calendar;
   package CFM renames Ada.Calendar.Formatting;
   package ACC renames Ada.Characters.Conversions;
   package AR  renames AdaBase.Results;
   package ACB renames AdaBase.Connection.Base;
   package AIS renames AdaBase.Interfaces.Statement;
   package ALF renames AdaBase.Logger.Facility;
   package ARC renames AdaBase.Results.Converters;
   package RGC renames AdaBase.Results.Generic_Converters;

   type stmttext_access is access all CT.Text;

   type Base_Statement is
     abstract limited new Base_Pure and AIS.iStatement with private;
   type basic_statement is access all Base_Statement'Class;

   type stmt_type is (direct_statement, prepared_statement);

   ILLEGAL_BIND_SQL         : exception;
   INVALID_FOR_DIRECT_QUERY : exception;
   INVALID_FOR_RESULT_SET   : exception;
   INVALID_COLUMN_INDEX     : exception;
   PRIOR_EXECUTION_FAILED   : exception;
   BINDING_COLUMN_NOT_FOUND : exception;
   BINDING_TYPE_MISMATCH    : exception;
   BINDING_SIZE_MISMATCH    : exception;
   STMT_PREPARATION         : exception;
   STMT_EXECUTION           : exception;
   MARKER_NOT_FOUND         : exception;

   overriding
   function rows_affected (Stmt : Base_Statement) return AffectedRows;

   overriding
   function successful (Stmt : Base_Statement) return Boolean;

   overriding
   function data_discarded (Stmt : Base_Statement) return Boolean;


   -------------------------------------------
   --      20 bind using integer index      --
   -------------------------------------------
   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte0_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte1_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte2_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte3_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte4_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.nbyte8_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte1_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte2_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte3_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte4_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.byte8_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.real9_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.real18_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.str1_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.str2_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.str4_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.time_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.chain_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.enum_access);

   procedure bind (Stmt  : out Base_Statement;
                   index : Positive;
                   vaxx  : AR.settype_access);


   -------------------------------------------
   --    20 bind using header for index     --
   -------------------------------------------
   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte0_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte1_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte2_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte3_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte4_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.nbyte8_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte1_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte2_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte3_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte4_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.byte8_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.real9_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.real18_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.str1_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.str2_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.str4_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.time_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.chain_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.enum_access);

   procedure bind (Stmt    : out Base_Statement;
                   heading : String;
                   vaxx    : AR.settype_access);


   --------------------------------------------
   --  20 assign/access using integer index  --
   --------------------------------------------
   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte0_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte1_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte2_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte3_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte4_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte8_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte1_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte2_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte3_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte4_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte8_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real9_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real18_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.str1_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.str2_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.str4_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.time_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.chain_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.enum_access);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.settype_access);

   ------------------------------------------------
   --  20 assign/access using moniker for index  --
   ------------------------------------------------
   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte0_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte1_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte2_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte3_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte4_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte8_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte1_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte2_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte3_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte4_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte8_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real9_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real18_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.str1_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.str2_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.str4_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.time_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.chain_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.enum_access);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.settype_access);


   -------------------------------------------
   --  20 assign/value using integer index  --
   -------------------------------------------
   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte0);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte1);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte2);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte3);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte4);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.nbyte8);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte1);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte2);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte3);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte4);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.byte8);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real9);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.real18);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : String);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.textual);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.textwide);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.textsuper);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : CAL.Time);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.chain);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.enumtype);

   procedure assign (Stmt  : out Base_Statement;
                     index : Positive;
                     vaxx  : AR.settype);


   -----------------------------------------------
   --  20 assign/value using moniker for index  --
   -----------------------------------------------
   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte0);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte1);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte2);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte3);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte4);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.nbyte8);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte1);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte2);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte3);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte4);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.byte8);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real9);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.real18);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : String);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.textual);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.textwide);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.textsuper);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : CAL.Time);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.chain);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.enumtype);

   procedure assign (Stmt    : out Base_Statement;
                     moniker : String;
                     vaxx    : AR.settype);

private

   logger_access : ALF.LogFacility_access;

   function Same_Strings (S, T : String) return Boolean;

   procedure transform_sql (Stmt : out Base_Statement; sql : String;
                           new_sql : out String);

   procedure log_nominal (statement : Base_Statement;
                          category  : LogCategory;
                          message   : String);

   package Markers is new Ada.Containers.Indefinite_Hashed_Maps
     (Key_Type        => String,
      Element_Type    => Positive,
      Equivalent_Keys => Same_Strings,
      Hash            => Ada.Strings.Hash);

   function convert is new RGC.convert4str (IntType => AR.nbyte1);
   function convert is new RGC.convert4str (IntType => AR.nbyte2);
   function convert is new RGC.convert4str (IntType => AR.nbyte3);
   function convert is new RGC.convert4str (IntType => AR.nbyte4);
   function convert is new RGC.convert4str (IntType => AR.nbyte8);
   function convert is new RGC.convert4str (IntType => AR.byte1);
   function convert is new RGC.convert4str (IntType => AR.byte2);
   function convert is new RGC.convert4str (IntType => AR.byte3);
   function convert is new RGC.convert4str (IntType => AR.byte4);
   function convert is new RGC.convert4str (IntType => AR.byte8);
   function convert is new RGC.convert4st2 (RealType => AR.real9);
   function convert is new RGC.convert4st2 (RealType => AR.real18);
   function convert (nv : String; maxsize : BLOB_maximum) return AR.chain;
   function convert (nv : String; maxsize : BLOB_maximum) return AR.textual;
   function convert (nv : String; maxsize : BLOB_maximum) return AR.textwide;
   function convert (nv : String; maxsize : BLOB_maximum) return AR.textsuper;
   function convert (nv : String) return AR.textwide;
   function convert (nv : String) return AR.textsuper;

   type bindrec (output_type : field_types := ft_nbyte0) is record
      bound : Boolean := False;
      case output_type is
         when ft_nbyte0    => a00 : AR.nbyte0_access;
                              v00 : AR.nbyte0;
         when ft_nbyte1    => a01 : AR.nbyte1_access;
                              v01 : AR.nbyte1;
         when ft_nbyte2    => a02 : AR.nbyte2_access;
                              v02 : AR.nbyte2;
         when ft_nbyte3    => a03 : AR.nbyte3_access;
                              v03 : AR.nbyte3;
         when ft_nbyte4    => a04 : AR.nbyte4_access;
                              v04 : AR.nbyte4;
         when ft_nbyte8    => a05 : AR.nbyte8_access;
                              v05 : AR.nbyte8;
         when ft_byte1     => a06 : AR.byte1_access;
                              v06 : AR.byte1;
         when ft_byte2     => a07 : AR.byte2_access;
                              v07 : AR.byte2;
         when ft_byte3     => a08 : AR.byte3_access;
                              v08 : AR.byte3;
         when ft_byte4     => a09 : AR.byte4_access;
                              v09 : AR.byte4;
         when ft_byte8     => a10 : AR.byte8_access;
                              v10 : AR.byte8;
         when ft_real9     => a11 : AR.real9_access;
                              v11 : AR.real9;
         when ft_real18    => a12 : AR.real18_access;
                              v12 : AR.real18;
         when ft_textual   => a13 : AR.str1_access;
                              v13 : AR.textual;
         when ft_widetext  => a14 : AR.str2_access;
                              v14 : AR.textwide;
         when ft_supertext => a15 : AR.str4_access;
                              v15 : AR.textsuper;
         when ft_timestamp => a16 : AR.time_access;
                              v16 : CAL.Time;
         when ft_chain     => a17 : AR.chain_access;
                              v17 : AR.textual;
         when ft_enumtype  => a18 : AR.enum_access;
                              v18 : AR.enumtype;
         when ft_settype   => a19 : AR.settype_access;
                              v19 : AR.textual;
      end case;
   end record;



   --  For fetch_bound
   function bind_proceed (Stmt : Base_Statement; index : Positive)
                          return Boolean;

   function bind_index (Stmt : Base_Statement; heading : String)
                        return Positive;

   function assign_index (Stmt : Base_Statement; moniker : String)
                          return Positive;

   package bind_crate is new Ada.Containers.Vectors
     (Index_Type   => Positive,
      Element_Type => bindrec);

   type Base_Statement is
     abstract limited new Base_Pure and AIS.iStatement with record
      successful_execution : Boolean      := False;
      result_present       : Boolean      := False;
      rows_leftover        : Boolean      := False;
      dialect              : TDriver      := foundation;
      impacted             : AffectedRows := 0;
      connection           : ACB.Base_Connection_Access;
      alpha_markers        : Markers.Map;
      headings_map         : Markers.Map;
      crate                : bind_crate.Vector;
      realmccoy            : bind_crate.Vector;
   end record;

end AdaBase.Statement.Base;

--  This file is covered by the Internet Software Consortium (ISC) License
--  Reference: ../../License.txt

with CommonText;
with AdaBase.Logger.Base.File;
with AdaBase.Logger.Base.Screen;

package AdaBase.Logger.Facility is

   package CT  renames CommonText;
   package AL  renames AdaBase.Logger.Base;
   package ALF renames AdaBase.Logger.Base.File;
   package ALS renames AdaBase.Logger.Base.Screen;

   type LogFacility is tagged private;
   type LogFacility_access is access all LogFacility;
   type TAction is (attach, detach);
   type TLogger is (file, screen);

   ALREADY_ATTACHED  : exception;
   ALREADY_DETACHED  : exception;

   procedure standard_logger (facility : out LogFacility;
                              logger   : TLogger;
                              action   : TAction);
   procedure set_log_file    (facility : LogFacility;
                              filename : String);
   procedure set_error_mode (facility : out LogFacility;
                             mode     : Error_Modes);
   function  error_mode     (facility : LogFacility) return Error_Modes;

   procedure detach_custom_logger (facility : out LogFacility);
   procedure attach_custom_logger (facility : out LogFacility;
                                   logger_access : AL.BaseClass_Logger_access);

   procedure log_nominal (facility  : LogFacility;
                          driver    : Driver_Type;
                          category  : Log_Category;
                          message   : CT.Text);

   procedure log_problem
     (facility   : LogFacility;
      driver     : Driver_Type;
      category   : Log_Category;
      message    : CT.Text;
      error_msg  : CT.Text      := CT.blank;
      error_code : Driver_Codes := 0;
      sqlstate   : SQL_State    := stateless;
      break      : Boolean      := False);

private
   type LogFacility is tagged record
      prop_error_mode : Error_Modes := warning;
      listener_file   : ALF.File_Logger_access := null;
      listener_screen : ALS.Screen_Logger_access := null;
      listener_custom : AL.BaseClass_Logger_access := null;
   end record;

   logger_file     : aliased ALF.File_Logger;
   logger_screen   : aliased ALS.Screen_Logger;

end AdaBase.Logger.Facility;

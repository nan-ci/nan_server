with Ada.Directories, Ada.Environment_Variables, Ada.Strings.Fixed, Ada.Text_IO, Lib.Process, Lib.File,
     Lib.Text, Log, Lib.Sets, Ada.Strings.Wide_Wide_Maps, Lib.Console, Lib.Locking, Lib.Strings;
use Lib, Lib.Strings;

procedure NaN_Server is

   package Maps  renames Ada.Strings.Wide_Wide_Maps;
   package Dir   renames Ada.Directories;
   package Env   renames Ada.Environment_Variables;
   package Fixed renames Ada.Strings.Fixed;
   package TIO   renames Ada.Text_IO;

   use type Char_Set;
   use type Text.T;

   IP : constant Str := Get (Item    => To_Str (Env.Value ("SSH_CLIENT")),
                             Pattern => To_Suite (Pattern  => "d.d.d.d",
                                                  Matching => (1 => ('d', Sets.Digit))));

   pragma Assert (for all Number of Split (IP, '.') =>
                     Value (Slice (IP, Number)) in 0 .. 255);

   Args      : constant Str := To_Str (Env.Value ("SSH_ORIGINAL_COMMAND"));
   User      : constant Str := To_Str (Env.Value ("USER"));
   Home      : constant Str := To_Str (Env.Value ("HOME"));
   Log_Path  : constant Str := Home & "/log";
   Last_Path : constant Str := Home & "/last";
   Lock_Path : constant Str := Home & "/lock";

   SSH : constant Str := "ssh -p 22 -oStrictHostKeyChecking=no -oCheckHostIP=no";

   function Disconnected return Boolean is
      function Is_User_Unlocked (Last_IP : Str) return Boolean is
         (Process.Spawn (SSH & " root@" & Last_IP & " try_lock /run/nan_user_" & User & ".lock"));
   begin
      return not File.Exists (Last_Path) or else Is_User_Unlocked (File.Read (Last_Path));
   end Disconnected;

--     procedure Sync (Client, Server : Subvolume_List) is
--        Common : constant Subvolume_List := Client and Server;
--     begin
--        if Common.Is_Empty then
--           Spawn ("btrfs send " & Name (Client.Last_Element) & " | ssh btrfs receive");
--        else
--           null;
--        end if;
--     end Sync;

   procedure Print (Key, Val : String) is
   begin
      TIO.Put_Line (Key & '=' & Val);
   end Print;

   Lock : Locking.T;
begin
   Lock.Create (Lock_Path);
   Env.Iterate (Print'Access);

   if Args = "connect" then
      if Disconnected then
         File.Overwrite (Last_Path, IP);
      else
         raise Program_Error;
      end if;

   elsif Args = "disconnect" then
      File.Exclude (Last_Path);
   else
      raise Program_Error;
   end if;

   Lock.Delete;
exception
   when others =>
      Lock.Delete;
      raise;
end NaN_Server;

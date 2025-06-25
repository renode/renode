#define DIR GetEnv('windows_package_src')
#define BASE GetEnv('BASE')
#define VERSION GetEnv('VERSION')
[Setup]
AppName=Renode
AppVersion={#VERSION}
AppId=Renode
AppReadmeFile=https://renode.readthedocs.io/en/latest/
; Publisher Information
AppPublisher=Antmicro
AppPublisherURL=https://antmicro.com/
AppCopyright=Copyright (C) 2010-2025 Antmicro
; Architecture settings
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputBaseFilename=RenodeSetup-{#version}
; Default install directory
DefaultDirName={autopf}\Renode
DefaultGroupName=Renode
; Compression settings
Compression=lzma
SolidCompression=yes
; Appearance
WizardStyle=modern
SetupIconFile=lib\resources\images\windows_setup\renode.ico
UninstallDisplayIcon={app}\renode.exe
WizardImageFile=lib\resources\images\windows_setup\wizard_image.bmp
WizardSmallImageFile=lib\resources\images\windows_setup\wizard_image_small.bmp
; Allows the user to skip creating a start menu shortcut
AllowNoIcons=yes
; Tells Windows that enviroment variables such as PATH should be reloaded after installation
ChangesEnvironment=yes
; Input and output directories for the build
; SourceDir expands to the renode directory, and is used as the working dir for Inno Setup
SourceDir="..\{#BASE}"
OutputDir="output\packages"

[Files]
; Since not all of our files gets tagged with incrementing versions we have to use the ignoreversion flag to ensure update installs work as they should
Source: "tools\packaging\{#DIR}\*"; DestDir: "{app}"; Flags: recursesubdirs ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Create a Desktop Icon"; Flags: unchecked
Name: "addtopath"; Description: "Add Renode to PATH";

; Despite the name, this section creates shortcuts
[Icons]
Name: "{group}\Renode"; Filename: "{app}\renode.exe"; WorkingDir: "{app}"
Name: "{commondesktop}\Renode"; Filename: "{app}\renode.exe"; WorkingDir: "{app}"; Tasks: desktopicon

[Registry]
#define EnvironmentRootKey "HKLM"
#define EnvironmentKey "System\CurrentControlSet\Control\Session Manager\Environment"
Root: {#EnvironmentRootKey}; Subkey: "{#EnvironmentKey}"; ValueType: expandsz; ValueName: "Path"; ValueData: "{code:AddToPath|{app}}"; Tasks: addtopath; Check: NeedsAddToPath(ExpandConstant('{app}'))

[Code]
// Check for version using the old installer before installation
function InitializeSetup: Boolean;
var
  UninstallKeys: TArrayOfString;
  I: Integer;
  ResultStr: String;
  ResultCode: Integer;
begin
  if IsMsiProductInstalled('{7e549c3f-a15a-4101-8071-9d52a16a28f6}', PackVersionComponents(0,0,0,0)) then
    begin
      case SuppressibleTaskDialogMsgBox(ExpandConstant('{cm:OldRenode} '), 'A version of Renode installed with the old installer has been detected. It will be uninstalled automatically before starting the setup', mbConfirmation, MB_OKCANCEL, [], 0, IDOK) of
        IDOK:
          begin
            if RegGetSubkeyNames(HKEY_LOCAL_MACHINE, 'Software\Microsoft\Windows\CurrentVersion\Uninstall', UninstallKeys) then
              begin
                for I := 0 to GetArrayLength(UninstallKeys) - 1 do
                  begin
                    if RegQueryStringValue(HKEY_LOCAL_MACHINE, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\' + UninstallKeys[i], 'DisplayName', ResultStr) then
                    begin
                      if CompareText('Renode', ResultStr) = 0 then
                        begin
                          // We found the old renode installation
                          if Exec('MsiExec.exe', '/quiet /passive /X' + UninstallKeys[i], '', SW_HIDE, ewWaitUntilTerminated, ResultCode) then
                          begin
                            SuppressibleMsgBox('Successfully uninstalled old Renode version', mbInformation, MB_OK, MB_OK);
                          end
                          else
                            RaiseException('Failed to uninstall the old Renode version. Please uninstall it manually and then re-run this setup');
                        end
                    end
                  end;
                Result := True;
              end
            else
              begin
                Result := False;
              end
          end;
        IDCANCEL: Result := False;
      end;
    end
  else
    Result := True;
end;
// Based on the add to path logic from the vscode installer
function NeedsAddToPath(Renode: string): boolean;
var
  OrigPath: string;
begin
  if not RegQueryStringValue({#EnvironmentRootKey}, '{#EnvironmentKey}', 'Path', OrigPath)
  then begin
    Result := True;
    exit;
  end;
  Result := Pos(';' + Renode + ';', ';' + OrigPath + ';') = 0;
end;

function AddToPath(Renode: string): string;
var
  OrigPath: string;
begin
  RegQueryStringValue({#EnvironmentRootKey}, '{#EnvironmentKey}', 'Path', OrigPath)

  if (Length(OrigPath) > 0) and (OrigPath[Length(OrigPath)] = ';') then
    Result := OrigPath + Renode
  else
    Result := OrigPath + ';' + Renode
end;

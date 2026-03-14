; CrispyTivi — Inno Setup installer configuration
; Usage: iscc /DAppVersion=0.2.0 scripts/inno_setup.iss

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif

[Setup]
AppName=CrispyTivi
AppVersion={#AppVersion}
AppPublisher=CrispyTivi
AppPublisherURL=https://github.com/user/crispy-tivi
DefaultDirName={autopf}\CrispyTivi
DefaultGroupName=CrispyTivi
OutputDir=Output
OutputBaseFilename=CrispyTivi-{#AppVersion}-windows-setup
Compression=lzma2/ultra64
SolidCompression=yes
SetupIconFile=assets\icons\app_icon.ico
UninstallDisplayIcon={app}\crispy_tivi.exe
WizardStyle=modern
PrivilegesRequired=admin
MinVersion=10.0
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked
Name: "startmenu"; Description: "Create a Start Menu shortcut"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{group}\CrispyTivi"; Filename: "{app}\crispy_tivi.exe"
Name: "{group}\{cm:UninstallProgram,CrispyTivi}"; Filename: "{uninstallexe}"
Name: "{commondesktop}\CrispyTivi"; Filename: "{app}\crispy_tivi.exe"; Tasks: desktopicon
Name: "{userstartmenu}\CrispyTivi"; Filename: "{app}\crispy_tivi.exe"; Tasks: startmenu

[Run]
Filename: "{app}\crispy_tivi.exe"; Description: "{cm:LaunchProgram,CrispyTivi}"; Flags: nowait postinstall skipifsilent

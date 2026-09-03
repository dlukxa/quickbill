; QuickBill POS - Inno Setup Installer Script
#define MyAppName "QuickBill POS"
#define MyAppVersion "1.0.6"
#define MyAppPublisher "QuickBill POS Solutions"
#define MyAppURL "https://quickbill.lk"
#define MyAppExeName "quickbill.exe"

[Setup]
AppId={{C8E2682C-4A2D-4C9F-9C1D-8E7B2F1A3B5E}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
ArchitecturesInstallIn64BitMode=x64compatible
DisableProgramGroupPage=yes
OutputDir=..\..\build\windows_installer
OutputBaseFilename=QuickBill_Setup
SetupIconFile=..\runner\resources\app_icon.ico
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
PrivilegesRequired=admin

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main Flutter Windows Release Application Files
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Bundled Visual C++ 2015-2022 Redistributable
Source: "..\..\vc_redist.x64.exe"; DestDir: "{tmp}"; Flags: deleteafterinstall

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; IconFilename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
; Silently install or verify Microsoft Visual C++ 2015-2022 Runtime
Filename: "{tmp}\vc_redist.x64.exe"; Parameters: "/install /passive /norestart"; StatusMsg: "Configuring Microsoft Visual C++ Runtime and System Components..."; Flags: waituntilterminated
; Launch QuickBill POS at the end of setup
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent

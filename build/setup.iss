; Inno Setup 6 script for Dope Wars: Omaha Metro Edition.

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceExe
  #error SourceExe must be defined (path to the Godot-exported game .exe)
#endif
#ifndef OutputDir
  #define OutputDir "..\dist"
#endif
#ifndef OutputFilename
  #define OutputFilename "dope_wars_setup"
#endif

#define AppName      "Dope Wars Omaha"
#define AppPublisher "Tim Goergen"
#define AppURL       "https://github.com/TimGoergen/dope-wars"
#define AppExeName   "dope_wars.exe"

[Setup]
AppId={{8E2D4C91-5F3B-4A1E-9C84-6A7B2E1F09D3}
AppName={#AppName}
AppVersion={#AppVersion}
AppPublisher={#AppPublisher}
AppPublisherURL={#AppURL}
AppSupportURL={#AppURL}
PrivilegesRequired=lowest
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
OutputDir={#OutputDir}
OutputBaseFilename={#OutputFilename}
Compression=lzma
SolidCompression=yes
WizardStyle=modern

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "{#SourceExe}"; DestDir: "{app}"; DestName: "{#AppExeName}"; Flags: ignoreversion

[Icons]
Name: "{group}\{#AppName}";                          Filename: "{app}\{#AppExeName}"
Name: "{group}\{cm:UninstallProgram,{#AppName}}";    Filename: "{uninstallexe}"
Name: "{commondesktop}\{#AppName}";                  Filename: "{app}\{#AppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExeName}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent

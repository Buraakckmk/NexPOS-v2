; NexPOS - Inno Setup Script
; Bu projede Flutter Windows release çıktısı runner\Release altında oluşur.

#define MyAppName "NexPOS"
#define MyAppVersion "2.0.0"
#define MyAppPublisher "NexPOS"
#define MyAppExeName "NEXPOS.exe"
#define BuildSourceDir "frontend\\build\\windows\\x64\\runner\\Release"

[Setup]
AppId={{A8AAB34C-7FC8-4A45-8FA6-4D9D8D535F2A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
DefaultDirName={autopf}\{#MyAppName}
DefaultGroupName={#MyAppName}
OutputDir=.
OutputBaseFilename=NexPOS-Setup
Compression=lzma
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
PrivilegesRequired=admin

[Languages]
Name: "turkish"; MessagesFile: "compiler:Languages\Turkish.isl"

[Tasks]
Name: "desktopicon"; Description: "Masaüstü kısayolu oluştur"; GroupDescription: "Ek görevler:"; Flags: checkedonce

[Files]
Source: "{#BuildSourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "backend\*"; DestDir: "{app}\backend"; Flags: ignoreversion recursesubdirs createallsubdirs; Excludes: "logs\*,node_modules\.cache\*"

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{group}\NexPOS Backend"; Filename: "{app}\backend\start_backend.bat"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon
Name: "{autodesktop}\NexPOS Backend Servisi"; Filename: "{app}\backend\start_backend.bat"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{#MyAppName} uygulamasını başlat"; Flags: nowait postinstall skipifsilent

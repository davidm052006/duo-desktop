; Duo Desktop installer (Inno Setup).
;
; Installs the DuoLauncher layout (DuoLauncher.exe, launcher-config.json,
; current.json, versions\<AppVersion>\{app,service}) per user, without admin
; rights: DuoLauncher writes updates into its own folder, so it cannot live
; under Program Files.
;
; Build:
;   ISCC.exe /DAppVersion=1.0.12 /DSourceDir=<staged layout> /DOutputDir=<out> duo-desktop.iss

#ifndef AppVersion
  #error Define AppVersion, e.g. /DAppVersion=1.0.12
#endif
#ifndef SourceDir
  #error Define SourceDir, the staged DuoLauncher layout
#endif
#ifndef OutputDir
  #define OutputDir "."
#endif

[Setup]
AppId={{F976B252-FAC2-4A76-B6D6-A55A2C08808D}
AppName=Duo Desktop
AppVersion={#AppVersion}
AppVerName=Duo Desktop {#AppVersion}
AppPublisher=davidm052006
AppPublisherURL=https://github.com/davidm052006/duo-desktop
DefaultDirName={localappdata}\Programs\Duo Desktop
DefaultGroupName=Duo Desktop
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
OutputDir={#OutputDir}
OutputBaseFilename=DuoDesktop-Setup-{#AppVersion}
SetupIconFile=duo.ico
UninstallDisplayIcon={app}\DuoLauncher.exe
UninstallDisplayName=Duo Desktop
WizardStyle=modern
WizardSmallImageFile=wizard-small.bmp
Compression=lzma2/max
SolidCompression=yes
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "es"; MessagesFile: "compiler:Languages\Spanish.isl"

[Tasks]
Name: "desktopicon"; Description: "Crear un acceso directo en el escritorio"; GroupDescription: "Accesos directos:"

[Files]
Source: "{#SourceDir}\DuoLauncher.exe"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\launcher-config.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\current.json"; DestDir: "{app}"; Flags: ignoreversion
Source: "{#SourceDir}\versions\{#AppVersion}\*"; DestDir: "{app}\versions\{#AppVersion}"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "duo.ico"; DestDir: "{app}"; Flags: ignoreversion

[Icons]
Name: "{autoprograms}\Duo Desktop"; Filename: "{app}\DuoLauncher.exe"; WorkingDir: "{app}"; IconFilename: "{app}\duo.ico"
Name: "{autodesktop}\Duo Desktop"; Filename: "{app}\DuoLauncher.exe"; WorkingDir: "{app}"; IconFilename: "{app}\duo.ico"; Tasks: desktopicon

[Run]
Filename: "{app}\DuoLauncher.exe"; WorkingDir: "{app}"; Description: "Abrir Duo Desktop"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
; Versions and staging downloaded later by DuoLauncher's auto-updates.
Type: filesandordirs; Name: "{app}\versions"
Type: filesandordirs; Name: "{app}\updates"
Type: files; Name: "{app}\current.json"

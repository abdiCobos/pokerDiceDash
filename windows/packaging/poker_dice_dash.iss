; Inno Setup 6 script for Poker Dice Dash. Built by windows/packaging/build_release.ps1,
; which passes AppVersion, SourceDir (the staged release folder) and OutputDir.

#ifndef AppVersion
  #define AppVersion "1.0.0"
#endif

[Setup]
; Never change AppId: it lets newer installers upgrade the existing installation.
AppId={{8C5E2A41-7F3B-4D0E-9B6A-2F1D4C7E9A35}
AppName=Poker Dice Dash
AppVersion={#AppVersion}
AppVerName=Poker Dice Dash {#AppVersion}
AppPublisher=abdiCobos
AppPublisherURL=https://github.com/abdiCobos/pokerDiceDash
AppSupportURL=https://github.com/abdiCobos/pokerDiceDash/issues
AppUpdatesURL=https://github.com/abdiCobos/pokerDiceDash/releases
DefaultDirName={autopf}\Poker Dice Dash
DefaultGroupName=Poker Dice Dash
DisableProgramGroupPage=yes
; Per-user install by default (no admin needed); the user may choose all users.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile={#SourceDir}\LICENSE.txt
OutputDir={#OutputDir}
OutputBaseFilename=PokerDiceDash-{#AppVersion}-setup
SetupIconFile=..\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\poker_dice_dash.exe
UninstallDisplayName=Poker Dice Dash
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
VersionInfoVersion={#AppVersion}
VersionInfoProductName=Poker Dice Dash
VersionInfoCompany=abdiCobos
VersionInfoCopyright=Copyright (C) 2026 abdiCobos. GPL-3.0.

[Languages]
Name: "spanish"; MessagesFile: "compiler:Languages\Spanish.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Poker Dice Dash"; Filename: "{app}\poker_dice_dash.exe"
Name: "{autodesktop}\Poker Dice Dash"; Filename: "{app}\poker_dice_dash.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\poker_dice_dash.exe"; Description: "{cm:LaunchProgram,Poker Dice Dash}"; Flags: nowait postinstall skipifsilent

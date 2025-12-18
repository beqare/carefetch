[Setup]
AppName=carefetch
AppVersion=1.0.0
AppPublisher=carefetch
DefaultDirName={pf}\carefetch
DefaultGroupName=carefetch
UninstallDisplayIcon={app}\carefetch.exe
Compression=lzma
SolidCompression=yes
ArchitecturesAllowed=x64
ArchitecturesInstallIn64BitMode=x64
Uninstallable=yes
SetupLogging=yes
AppId={{E4F1D5B2-3A8C-4D9E-9B1A-7C3F2E6D8A0C}
AppMutex=carefetch_mutex
ChangesEnvironment=yes

[Files]
Source: ".\build\carefetch.exe"; DestDir: "{app}"; Flags: ignoreversion

[Tasks]
Name: "addpath"; Description: "Add carefetch to PATH"; Flags: checkedonce

[Registry]
; PATH Eintrag hinzufügen
Root: HKLM; Subkey: "SYSTEM\CurrentControlSet\Control\Session Manager\Environment"; \
    ValueType: expandsz; ValueName: "Path"; \
    ValueData: "{olddata};{app}"; \
    Flags: preservestringtype; Tasks: addpath; Check: not IsUninstaller

; Uninstall Information
Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch"; \
    ValueType: string; ValueName: "DisplayName"; ValueData: "carefetch"; \
    Flags: uninsdeletekey; Check: not IsUninstaller

Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch"; \
    ValueType: string; ValueName: "UninstallString"; \
    ValueData: """{uninstallexe}"""; Check: not IsUninstaller

Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch"; \
    ValueType: string; ValueName: "DisplayVersion"; ValueData: "{#SetupSetting("AppVersion")}"; \
    Check: not IsUninstaller

Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch"; \
    ValueType: string; ValueName: "Publisher"; ValueData: "carefetch"; \
    Check: not IsUninstaller

Root: HKLM; Subkey: "Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch"; \
    ValueType: string; ValueName: "InstallLocation"; ValueData: "{app}"; \
    Check: not IsUninstaller

[Code]
var
  // Globale Variablen für die gespeicherten PATH Werte
  OriginalPath: string;
  UninstallTask: string;

// Funktion zum Entfernen aus PATH
procedure RemoveFromPath(PathToRemove: string);
var
  Paths: TArrayOfString;
  NewPath: string;
  I: Integer;
begin
  // Aktuellen PATH lesen
  if RegQueryStringValue(HKEY_LOCAL_MACHINE,
    'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
    'Path', OriginalPath) then
  begin
    // PATH in Array aufteilen
    NewPath := '';
    if Explode(Paths, OriginalPath, ';') then
    begin
      for I := 0 to GetArrayLength(Paths) - 1 do
      begin
        // Nur behalten, wenn nicht der zu entfernende Pfad
        if (Paths[I] <> PathToRemove) and 
           (Paths[I] <> PathToRemove + '\') then
        begin
          if NewPath <> '' then
            NewPath := NewPath + ';';
          NewPath := NewPath + Paths[I];
        end;
      end;
      
      // Neuen PATH setzen
      RegWriteStringValue(HKEY_LOCAL_MACHINE,
        'SYSTEM\CurrentControlSet\Control\Session Manager\Environment',
        'Path', NewPath);
    end;
  end;
end;

// Wird vor der Deinstallation aufgerufen
procedure CurUninstallStepChanged(CurUninstallStep: TUninstallStep);
begin
  if CurUninstallStep = usUninstall then
  begin
    // Aus PATH entfernen
    RemoveFromPath(ExpandConstant('{app}'));
    
    // Registry-Eintrag des Uninstallers bereinigen
    RegDeleteKeyIncludingSubkeys(HKEY_LOCAL_MACHINE,
      'Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch');
  end;
end;

// Funktion zur Erkennung, ob bereits installiert
function IsUpgrade: Boolean;
var
  InstalledVersion: string;
begin
  Result := False;
  if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch',
    'DisplayVersion', InstalledVersion) then
  begin
    Result := True;
  end;
end;

// Bei Upgrade: Vorherige Version entfernen
procedure CurStepChanged(CurStep: TSetupStep);
begin
  if (CurStep = ssInstall) and IsUpgrade then
  begin
    // Alte Version aus PATH entfernen
    RemoveFromPath(ExpandConstant('{app}'));
    
    // Alte Dateien löschen
    DelTree(ExpandConstant('{app}\*'), False, True, False);
  end;
end;

// Setup-Type für Reparatur/Ändern
function InitializeSetup(): Boolean;
var
  InstalledVersion: string;
  UninstallString: string;
  ResultCode: Integer;
begin
  Result := True;
  
  // Prüfen ob bereits installiert
  if RegQueryStringValue(HKLM, 'Software\Microsoft\Windows\CurrentVersion\Uninstall\carefetch',
    'UninstallString', UninstallString) then
  begin
    // Dialog für Upgrade/Reparatur/Deinstallation
    if MsgBox('carefetch ist bereits installiert.' + #13#10 +
              'Möchten Sie:' + #13#10 +
              '  • Neuinstallieren/Reparieren' + #13#10 +
              '  • Deinstallieren' + #13#10 +
              '  • Abbrechen',
              mbInformation, MB_YESNOCANCEL) = IDYES then
    begin
      // Neuinstallation/Reparatur - weiter mit Setup
      Result := True;
    end
    else if MsgBox('carefetch ist bereits installiert.' + #13#10 +
                   'Möchten Sie deinstallieren?',
                   mbInformation, MB_YESNO) = IDYES then
    begin
      // Deinstallation starten
      Exec(RemoveQuotes(UninstallString), '/SILENT', '', SW_SHOW, ewWaitUntilTerminated, ResultCode);
      Result := False; // Setup abbrechen
    end
    else
    begin
      // Abbruch
      Result := False;
    end;
  end;
end;

[Run]
Filename: "{cmd}"; Parameters: "/C echo carefetch wurde erfolgreich installiert! && timeout /t 2"; \
  Flags: runhidden; Description: "Installation abgeschlossen"; StatusMsg: "Installation wird abgeschlossen..."

[UninstallRun]
; Hier können zusätzliche Deinstallationsschritte hinzugefügt werden

[UninstallDelete]
Type: filesandordirs; Name: "{app}"
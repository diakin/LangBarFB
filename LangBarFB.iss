; ---------------------------------------------------------------------------
;  LangBarFB.iss - установщик LangBarFB (Inno Setup 5: 6-й не работает
;  в Windows 7). Файл в кодировке windows-1251.
;
;  Основан на LangBarXX.iss (https://github.com/Krot66/LangBarXX).
;  Перед сборкой: build.bat (bin\langbar32.exe, bin\rqlcl32.dll).
;  Программа только 32-битная. Папка flags
;  (картинки флагов LangBarXX) попадает в установщик, если лежит рядом.
;  Результат: bin\LangBarFB_setup_<версия>.exe
;
;  Программа пишет langbarfb.ini, словари, user_dict.dic и backup\ в свою
;  папку, поэтому ставится в профиль пользователя (%LOCALAPPDATA%), а не в
;  Program Files: туда без прав администратора писать нельзя.
; ---------------------------------------------------------------------------

; та же, что APP_VERSION в src\ui\dlg_about.bi
#define MyAppVersion "1.0"
#define MyAppName "LangBarFB"
#define MyAppURL "https://github.com/diakin/LangBarFB"
; имя класса служебного окна (src\ui\tray.bi): по нему программа
; закрывается перед установкой и удалением
#define ServiceClass "LangBarFB_Service"

[Setup]
AppId={{6B0C7F3A-4E2D-4C61-9A57-2F1E8D3B5C90}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppVerName={#MyAppName} {#MyAppVersion}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
DefaultDirName={localappdata}\{#MyAppName}
DefaultGroupName={#MyAppName}
UsePreviousAppDir=yes
DisableDirPage=auto
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
Uninstallable=not IsTaskSelected('portablemode')
OutputDir=bin
OutputBaseFilename=LangBarFB_setup_{#MyAppVersion}
Compression=lzma2
SolidCompression=yes
ShowLanguageDialog=auto
UninstallDisplayName={#MyAppName}
UninstallDisplayIcon={app}\langbar32.exe
; LGPL-3.0, как у LangBarXX; COPYING (GPL-3.0) ставится рядом
LicenseFile=COPYING.LESSER

[Languages]
Name: "russian"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "english"; MessagesFile: "compiler:Default.isl"

[CustomMessages]
russian.TypeStandard=Стандартная (русский и английский словари)
russian.TypeFull=Полная (все словари)
russian.TypeMinimal=Минимальная (без автопереключения)
russian.TypeCustom=Выборочная
russian.CompProgram=Программа
russian.CompHunspell=Автопереключение (библиотека Hunspell)
russian.CompDictEn=Английский словарь
russian.CompDictRu=Русский словарь
russian.CompDictUk=Украинский словарь
russian.CompDictBe=Белорусский словарь
russian.CompDictDe=Немецкий словарь
russian.CompDictFr=Французский словарь
russian.TaskPortable=Переносная версия (без удаления через Панель управления и без ярлыков)
russian.TaskAutostart=Запускать при старте Windows
russian.HelpShortcut=Справка
english.TypeStandard=Standard (English and Russian dictionaries)
english.TypeFull=Full (all dictionaries)
english.TypeMinimal=Minimal (no auto switching)
english.TypeCustom=Custom
english.CompProgram=Program
english.CompHunspell=Auto switching (Hunspell library)
english.CompDictEn=English dictionary
english.CompDictRu=Russian dictionary
english.CompDictUk=Ukrainian dictionary
english.CompDictBe=Belarusian dictionary
english.CompDictDe=German dictionary
english.CompDictFr=French dictionary
english.TaskPortable=Portable version (no uninstaller, no shortcuts)
english.TaskAutostart=Start with Windows
english.HelpShortcut=Help

[Types]
Name: "standard"; Description: "{cm:TypeStandard}"
Name: "full"; Description: "{cm:TypeFull}"
Name: "minimal"; Description: "{cm:TypeMinimal}"
Name: "custom"; Description: "{cm:TypeCustom}"; Flags: iscustom

[Components]
Name: "program"; Description: "{cm:CompProgram}"; Types: full standard minimal custom; Flags: fixed
Name: "hunspell"; Description: "{cm:CompHunspell}"; Types: full standard
Name: "hunspell\en"; Description: "{cm:CompDictEn}"; Types: full standard
Name: "hunspell\ru"; Description: "{cm:CompDictRu}"; Types: full standard
Name: "hunspell\uk"; Description: "{cm:CompDictUk}"; Types: full
Name: "hunspell\be"; Description: "{cm:CompDictBe}"; Types: full
Name: "hunspell\de"; Description: "{cm:CompDictDe}"; Types: full
Name: "hunspell\fr"; Description: "{cm:CompDictFr}"; Types: full

[Tasks]
Name: "portablemode"; Description: "{cm:TaskPortable}"; Flags: unchecked
Name: "autostart"; Description: "{cm:TaskAutostart}"
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "bin\langbar32.exe"; DestDir: "{app}"; Components: program; Flags: ignoreversion
Source: "bin\rqlcl32.dll"; DestDir: "{app}"; Components: program; Flags: ignoreversion
Source: "COPYING"; DestDir: "{app}"; Components: program; Flags: ignoreversion
Source: "COPYING.LESSER"; DestDir: "{app}"; Components: program; Flags: ignoreversion
Source: "help\*"; DestDir: "{app}\help"; Components: program; Flags: ignoreversion
Source: "sounds\*"; DestDir: "{app}\sounds"; Components: program; Flags: ignoreversion
#if DirExists("flags")
Source: "flags\*"; DestDir: "{app}\flags"; Components: program; Flags: ignoreversion
#endif

Source: "hunspell\*"; DestDir: "{app}\hunspell"; Components: hunspell; Flags: ignoreversion
Source: "dict\README.md"; DestDir: "{app}\dict"; Components: hunspell; Flags: ignoreversion
Source: "dict\en-US\*"; DestDir: "{app}\dict\en-US"; Components: hunspell\en; Flags: ignoreversion recursesubdirs
Source: "dict\ru-RU\*"; DestDir: "{app}\dict\ru-RU"; Components: hunspell\ru; Flags: ignoreversion recursesubdirs
Source: "dict\uk-UA\*"; DestDir: "{app}\dict\uk-UA"; Components: hunspell\uk; Flags: ignoreversion recursesubdirs
Source: "dict\be-BY\*"; DestDir: "{app}\dict\be-BY"; Components: hunspell\be; Flags: ignoreversion recursesubdirs
Source: "dict\de-DE\*"; DestDir: "{app}\dict\de-DE"; Components: hunspell\de; Flags: ignoreversion recursesubdirs
Source: "dict\fr-FR\*"; DestDir: "{app}\dict\fr-FR"; Components: hunspell\fr; Flags: ignoreversion recursesubdirs

; перенос со старой копии: папки рядом с установщиком
Source: "{src}\flags\*"; DestDir: "{app}\flags"; Flags: external skipifsourcedoesntexist ignoreversion
Source: "{src}\dict\*"; DestDir: "{app}\dict"; Flags: external skipifsourcedoesntexist ignoreversion recursesubdirs
Source: "{src}\langbarfb.ini"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist onlyifdoesntexist
Source: "{src}\user_dict.dic"; DestDir: "{app}"; Flags: external skipifsourcedoesntexist onlyifdoesntexist

[Icons]
Name: "{group}\{#MyAppName}"; Filename: "{app}\langbar32.exe"; Check: not IsTaskSelected('portablemode')
Name: "{group}\{cm:HelpShortcut}"; Filename: "{app}\help\langbarfb.ru.html"; Languages: russian; Check: not IsTaskSelected('portablemode')
Name: "{group}\{cm:HelpShortcut}"; Filename: "{app}\help\langbarfb.en.html"; Languages: english; Check: not IsTaskSelected('portablemode')
Name: "{group}\{cm:UninstallProgram,{#MyAppName}}"; Filename: "{uninstallexe}"; Check: not IsTaskSelected('portablemode')
Name: "{userdesktop}\{#MyAppName}"; Filename: "{app}\langbar32.exe"; Tasks: desktopicon

[Registry]
; то же значение пишет сама программа (галка «Запускать при старте Windows»)
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueType: string; ValueName: "LangBarFB"; ValueData: """{app}\langbar32.exe"""; Tasks: autostart and not portablemode; Flags: uninsdeletevalue
Root: HKCU; Subkey: "Software\Microsoft\Windows\CurrentVersion\Run"; ValueName: "LangBarFB"; Flags: uninsdeletevalue dontcreatekey; Check: not IsTaskSelected('portablemode')

[INI]
; язык интерфейса - как у установщика, если ini ещё не было
Filename: "{app}\langbarfb.ini"; Section: "General"; Key: "Language"; String: "ru"; Languages: russian; Flags: createkeyifdoesntexist
Filename: "{app}\langbarfb.ini"; Section: "General"; Key: "Language"; String: "en"; Languages: english; Flags: createkeyifdoesntexist
Filename: "{app}\langbarfb.ini"; Section: "General"; Key: "AutoStart"; String: "1"; Tasks: autostart and not portablemode

[Run]
Filename: "{app}\langbar32.exe"; Description: "{cm:LaunchProgram,{#MyAppName}}"; Flags: nowait postinstall skipifsilent

[UninstallDelete]
Type: files; Name: "{app}\langbarfb.ini"
Type: filesandordirs; Name: "{app}\backup"
Type: dirifempty; Name: "{app}"

[Code]
// Закрыть запущенный LangBarFB: WM_CLOSE служебному окну - программа
// завершается сама и убирает значок из трея. Не закрылась за 3 с -
// taskkill.
procedure CloseLangBarFB();
var
  ServiceWnd: HWND;
  WaitCount: Integer;
  ExitCode: Integer;
begin
  ServiceWnd := FindWindowByClassName('{#ServiceClass}');
  if ServiceWnd = 0 then
    Exit;
  PostMessage(ServiceWnd, 16, 0, 0);
  WaitCount := 0;
  while (FindWindowByClassName('{#ServiceClass}') <> 0) and (WaitCount < 30) do
  begin
    Sleep(100);
    WaitCount := WaitCount + 1;
  end;
  if FindWindowByClassName('{#ServiceClass}') <> 0 then
  begin
    Exec('taskkill', '/im langbar32.exe /f', '', SW_HIDE, ewWaitUntilTerminated, ExitCode);
  end;
end;

function PrepareToInstall(var NeedsRestart: Boolean): String;
begin
  CloseLangBarFB();
  Result := '';
end;

function InitializeUninstall(): Boolean;
begin
  CloseLangBarFB();
  Result := True;
end;

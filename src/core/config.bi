' ---------------------------------------------------------------------------
'  config.bi - настройки LangBarFB в langbarfb.ini рядом с exe.
'
'  [General]  AutoStart, AutoSwitch, CaretFlag, Sounds (0/1); MouseFlag -
'             флажок у указателя мыши (MOUSE_FLAG_...); Language - язык
'             интерфейса: ru, en (нет - по языку Windows)
'  [Hotkeys]  Action1..Action4 - сочетание словами: "Shift + Break",
'             пусто - не назначено
'  [Sounds]   On1..On4 (0/1), File1..File4, Beep (1 - сигнал динамика
'             вместо файла)
'  [Switch]   LShift, RShift, LCtrl, RCtrl - что делает одиночное нажатие:
'             пусто - ничего, next / prev - следующая / предыдущая
'             раскладка, код раскладки (ru-RU) - эта раскладка;
'             DoublePress (0/1) - срабатывать по двойному нажатию;
'             LangSelect - раскладка по номеру: 0 нет, 1 левый Ctrl + N,
'             2 левый Alt + N, 3 левый Win + N
'  [Keys]     CapsLock - режим (CAPS_...), ShiftCapsLock (0/1), NumLockOn,
'             ShiftBackspace, CtrlCapsLock (0/1) - эти сочетания тоже
'             исправляют последнее слово, как Break
'  [AutoSwitch] Folder - папка с hunspell\ и dict\ (пусто - рядом с exe
'             или выше); IgnoreDigits, IgnoreCaps - не переключать слова
'             с цифрами и из одних заглавных; SingleLetter - переключать
'             слова из одной буквы; Remember - слово, переключение которого
'             отменили Break, записывать в user_dict.dic (0/1);
'             Early - проверять начало слова с третьей буквы (0/1);
'             DictAsked - вопрос о скачивании словарей уже задавали (0/1)
'  Чтение настроек LangBarXX (langbarxx.ini) - открытый вопрос плана.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "lang.bi"

Const HOTKEY_ACTION_COUNT = 4
' номера действий горячих клавиш (с 0)
Const ACTION_UNDO_CONVERT = 0       ' отменить конвертацию раскладки
Const ACTION_CONVERT_SELECTION = 1  ' сменить раскладку выделенного текста
Const ACTION_TOGGLE_CASE = 2        ' сменить регистр выделенного текста
Const ACTION_TRANSLIT = 3           ' транслитерировать выделенный текст

Const SOUND_EVENT_COUNT = 4
Const SOUND_AUTOSWITCH = 0          ' автопереключение раскладки
Const SOUND_UNDO_AUTOSWITCH = 1     ' отмена автопереключения / конвертации
Const SOUND_CONVERT_SELECTION = 2   ' конвертация выделенного текста
Const SOUND_CONVERT_CLIPBOARD = 3   ' конвертация текста в буфере (позже)

' одиночные клавиши (номер = VK_LSHIFT..VK_RCONTROL - &hA0)
Const SOLO_KEY_COUNT = 4
Dim Shared SoloKeyIniNames(0 To SOLO_KEY_COUNT - 1) As ZString * 8 = {"LShift", "RShift", "LCtrl", "RCtrl"}
Dim Shared SoloKeyTitles(0 To SOLO_KEY_COUNT - 1) As ZString * 16 = {"Левый Shift", "Правый Shift", "Левый Ctrl", "Правый Ctrl"}

' режимы Caps Lock
Const CAPS_NORMAL = 0       ' как обычно
Const CAPS_OFF = 1          ' не действует
Const CAPS_SWITCH = 2       ' следующая раскладка
Const CAPS_UNDO_WORD = 3    ' последнее слово в другой раскладке (как Break)
Const CAPS_INVERT_CASE = 4  ' регистр выделенного текста (как Alt + Break)

' флажок у указателя мыши
Const MOUSE_FLAG_OFF = 0        ' нет
Const MOUSE_FLAG_ALWAYS = 1     ' всегда
Const MOUSE_FLAG_ON_CHANGE = 2  ' несколько секунд после смены раскладки
Const MOUSE_FLAG_SHOW_MS = 3000 ' сколько секунд - как Cursor_Show LangBarXX

Type AppSettings
    AutoStart As Long
    AutoSwitch As Long
    CaretFlag As Long
    SoundsOn As Long
    SoundBeep As Long
    Hotkey(0 To HOTKEY_ACTION_COUNT - 1) As String
    SoundOn(0 To SOUND_EVENT_COUNT - 1) As Long
    SoundFile(0 To SOUND_EVENT_COUNT - 1) As String
    SoloKeyAction(0 To SOLO_KEY_COUNT - 1) As String
    DoublePress As Long
    LangSelect As Long
    CapsMode As Long
    ShiftCaps As Long
    NumLockOn As Long
    ShiftBackspace As Long
    CtrlCaps As Long
    SpellFolder As String
    AutoIgnoreDigits As Long
    AutoIgnoreCaps As Long
    AutoSingleLetter As Long
    AutoRemember As Long
    DictAsked As Long
    AutoEarly As Long
    MouseFlag As Long
    Language As String
End Type

Dim Shared Settings As AppSettings

Dim Shared HotkeyActionNames(0 To HOTKEY_ACTION_COUNT - 1) As ZString * 48 = { _
    "Отменить конвертацию раскладки", _
    "Сменить раскладку выделенного текста", _
    "Сменить регистр выделенного текста", _
    "Транслитерировать выделенный текст"}
Dim Shared HotkeyDefaults(0 To HOTKEY_ACTION_COUNT - 1) As ZString * 32 = { _
    "Break", "Shift + Break", "Alt + Break", "Alt + Scroll Lock"}

Dim Shared SoundEventNames(0 To SOUND_EVENT_COUNT - 1) As ZString * 48 = { _
    "Автопереключение раскладки", _
    "Отмена автопереключения", _
    "Конвертация выделенного текста", _
    "Конвертация текста в буфере"}
' файлы - из папки sounds LangBarXX
Dim Shared SoundDefaults(0 To SOUND_EVENT_COUNT - 1) As ZString * 48 = { _
    "sounds\autocorrect.wav", "sounds\undo.wav", "sounds\autoreplace.wav", "sounds\autoreplace.wav"}

Function ConfigFileName() As String
    Return ExePath & "\langbarfb.ini"
End Function

Private Function IniRead(ByRef Section As String, ByRef KeyName As String, ByRef DefaultValue As String) As String
    Dim ValueBuffer As ZString * 1024
    Dim FileName As String = ConfigFileName()
    LbGetPrivateProfileString(StrPtr(Section), StrPtr(KeyName), StrPtr(DefaultValue), _
        @ValueBuffer, 1024, StrPtr(FileName))
    Return ValueBuffer
End Function

Private Sub IniWrite(ByRef Section As String, ByRef KeyName As String, ByRef Value As String)
    Dim FileName As String = ConfigFileName()
    LbWritePrivateProfileString(StrPtr(Section), StrPtr(KeyName), StrPtr(Value), StrPtr(FileName))
End Sub

Private Function IniReadFlag(ByRef Section As String, ByRef KeyName As String, ByVal DefaultValue As Long) As Long
    Return IIf(Val(IniRead(Section, KeyName, Str(DefaultValue))) <> 0, 1, 0)
End Function

Sub ConfigLoad()
    With Settings
        .AutoStart = IniReadFlag("General", "AutoStart", 0)
        .AutoSwitch = IniReadFlag("General", "AutoSwitch", 1)
        .CaretFlag = IniReadFlag("General", "CaretFlag", 1)
        .SoundsOn = IniReadFlag("General", "Sounds", 1)
        .SoundBeep = IniReadFlag("Sounds", "Beep", 0)
        Dim ItemIdx As Long
        For ItemIdx = 0 To HOTKEY_ACTION_COUNT - 1
            ' "-" в файле - сочетание снято пользователем (пустое значение
            ' GetPrivateProfileString не отличает от отсутствующего)
            .Hotkey(ItemIdx) = IniRead("Hotkeys", "Action" & (ItemIdx + 1), HotkeyDefaults(ItemIdx))
            If .Hotkey(ItemIdx) = "-" Then .Hotkey(ItemIdx) = ""
        Next
        For ItemIdx = 0 To SOUND_EVENT_COUNT - 1
            .SoundOn(ItemIdx) = IniReadFlag("Sounds", "On" & (ItemIdx + 1), 1)
            .SoundFile(ItemIdx) = IniRead("Sounds", "File" & (ItemIdx + 1), SoundDefaults(ItemIdx))
        Next
        For ItemIdx = 0 To SOLO_KEY_COUNT - 1
            .SoloKeyAction(ItemIdx) = IniRead("Switch", SoloKeyIniNames(ItemIdx), "")
        Next
        .DoublePress = IniReadFlag("Switch", "DoublePress", 0)
        .LangSelect = ValInt(IniRead("Switch", "LangSelect", "0"))
        If .LangSelect < 0 Or .LangSelect > 3 Then .LangSelect = 0
        .CapsMode = ValInt(IniRead("Keys", "CapsLock", "0"))
        If .CapsMode < CAPS_NORMAL Or .CapsMode > CAPS_INVERT_CASE Then .CapsMode = CAPS_NORMAL
        .ShiftCaps = IniReadFlag("Keys", "ShiftCapsLock", 1)
        .NumLockOn = IniReadFlag("Keys", "NumLockOn", 0)
        .ShiftBackspace = IniReadFlag("Keys", "ShiftBackspace", 0)
        .CtrlCaps = IniReadFlag("Keys", "CtrlCapsLock", 0)
        .SpellFolder = IniRead("AutoSwitch", "Folder", "")
        .AutoIgnoreDigits = IniReadFlag("AutoSwitch", "IgnoreDigits", 1)
        .AutoIgnoreCaps = IniReadFlag("AutoSwitch", "IgnoreCaps", 1)
        .AutoSingleLetter = IniReadFlag("AutoSwitch", "SingleLetter", 0)
        .AutoRemember = IniReadFlag("AutoSwitch", "Remember", 1)
        .DictAsked = IniReadFlag("AutoSwitch", "DictAsked", 0)
        .AutoEarly = IniReadFlag("AutoSwitch", "Early", 1)
        .MouseFlag = ValInt(IniRead("General", "MouseFlag", Str(MOUSE_FLAG_ON_CHANGE)))
        If .MouseFlag < MOUSE_FLAG_OFF Or .MouseFlag > MOUSE_FLAG_ON_CHANGE Then .MouseFlag = MOUSE_FLAG_ON_CHANGE
        .Language = LCase(IniRead("General", "Language", ""))
        If .Language <> "ru" And .Language <> "en" Then
            ' русский, украинский, белорусский Windows - русский интерфейс
            Select Case LbGetUserDefaultUILanguage() And &h3FF
            Case &h19, &h22, &h23
                .Language = "ru"
            Case Else
                .Language = "en"
            End Select
        End If
    End With
End Sub

Sub ConfigSave()
    With Settings
        IniWrite("General", "AutoStart", Str(.AutoStart))
        IniWrite("General", "AutoSwitch", Str(.AutoSwitch))
        IniWrite("General", "CaretFlag", Str(.CaretFlag))
        IniWrite("General", "Sounds", Str(.SoundsOn))
        IniWrite("Sounds", "Beep", Str(.SoundBeep))
        Dim ItemIdx As Long
        For ItemIdx = 0 To HOTKEY_ACTION_COUNT - 1
            IniWrite("Hotkeys", "Action" & (ItemIdx + 1), IIf(.Hotkey(ItemIdx) = "", "-", .Hotkey(ItemIdx)))
        Next
        For ItemIdx = 0 To SOUND_EVENT_COUNT - 1
            IniWrite("Sounds", "On" & (ItemIdx + 1), Str(.SoundOn(ItemIdx)))
            IniWrite("Sounds", "File" & (ItemIdx + 1), .SoundFile(ItemIdx))
        Next
        For ItemIdx = 0 To SOLO_KEY_COUNT - 1
            IniWrite("Switch", SoloKeyIniNames(ItemIdx), .SoloKeyAction(ItemIdx))
        Next
        IniWrite("Switch", "DoublePress", Str(.DoublePress))
        IniWrite("Switch", "LangSelect", Str(.LangSelect))
        IniWrite("Keys", "CapsLock", Str(.CapsMode))
        IniWrite("Keys", "ShiftCapsLock", Str(.ShiftCaps))
        IniWrite("Keys", "NumLockOn", Str(.NumLockOn))
        IniWrite("Keys", "ShiftBackspace", Str(.ShiftBackspace))
        IniWrite("Keys", "CtrlCapsLock", Str(.CtrlCaps))
        IniWrite("AutoSwitch", "Folder", .SpellFolder)
        IniWrite("AutoSwitch", "IgnoreDigits", Str(.AutoIgnoreDigits))
        IniWrite("AutoSwitch", "IgnoreCaps", Str(.AutoIgnoreCaps))
        IniWrite("AutoSwitch", "SingleLetter", Str(.AutoSingleLetter))
        IniWrite("AutoSwitch", "Remember", Str(.AutoRemember))
        IniWrite("AutoSwitch", "DictAsked", Str(.DictAsked))
        IniWrite("AutoSwitch", "Early", Str(.AutoEarly))
        IniWrite("General", "MouseFlag", Str(.MouseFlag))
        IniWrite("General", "Language", .Language)
    End With
End Sub

' Запуск при входе в Windows: значение LangBarFB в HKCU\...\Run
Sub ConfigApplyAutoStart(ByVal Enabled As Long)
    Dim RunKey As Any Ptr
    If LbRegOpenKeyEx(LB_HKEY_CURRENT_USER, "Software\Microsoft\Windows\CurrentVersion\Run", _
            0, LB_KEY_SET_VALUE, RunKey) <> 0 Then Exit Sub
    If Enabled Then
        Dim ExeName As ZString * 1024
        LbGetModuleFileName(0, @ExeName, 1024)
        Dim CommandLine As String = """" & ExeName & """"
        LbRegSetValueEx(RunKey, "LangBarFB", 0, LB_REG_SZ, StrPtr(CommandLine), Len(CommandLine) + 1)
    Else
        LbRegDeleteValue(RunKey, "LangBarFB")
    End If
    LbRegCloseKey(RunKey)
End Sub

' Полный путь к звуковому файлу: относительный - от папки exe, а если там
' нет - на уровень выше (как папка flags)
Function SoundPath(ByRef FileName As String) As String
    If FileName = "" Then Return ""
    If Mid(FileName, 2, 1) = ":" Or Left(FileName, 2) = "\\" Then Return FileName
    If FileExists(ExePath & "\" & FileName) Then Return ExePath & "\" & FileName
    Return ExePath & "\..\" & FileName
End Function

Sub PlayEventSound(ByVal EventIdx As Long)
    If Settings.SoundsOn = 0 Or Settings.SoundOn(EventIdx) = 0 Then Exit Sub
    If Settings.SoundBeep Then
        LbMessageBeep(&hFFFFFFFF)
        Exit Sub
    End If
    Dim FullPath As String = SoundPath(Settings.SoundFile(EventIdx))
    If FullPath = "" Then Exit Sub
    LbPlaySound(StrPtr(FullPath), 0, LB_SND_FILENAME Or LB_SND_ASYNC Or LB_SND_NODEFAULT)
End Sub

' Сброс к значениям по умолчанию. Прежний langbarfb.ini копируется в
' backup\langbarfb_ГГГГ.ММ.ДД_ЧЧ.ММ.СС.ini рядом с exe (как бэкап LangBarXX,
' только без zip). Язык интерфейса и «словари уже предлагали» остаются.
' Возвращает имя копии ("" - ini не было или копия не записалась).
Function ConfigReset() As String
    Dim FileName As String = ConfigFileName()
    Dim BackupName As String
    If FileExists(FileName) Then
        Dim BackupFolder As String = ExePath & "\backup"
        LbCreateDirectory(StrPtr(BackupFolder), 0)
        ' Date - мм-дд-гггг, Time - чч:мм:сс
        Dim DateText As String = Date, TimeText As String = Time
        BackupName = BackupFolder & "\langbarfb_" & Mid(DateText, 7, 4) & "." & Left(DateText, 2) & "." _
            & Mid(DateText, 4, 2) & "_" & Left(TimeText, 2) & "." & Mid(TimeText, 4, 2) & "." & Right(TimeText, 2) & ".ini"
        If LbCopyFile(StrPtr(FileName), StrPtr(BackupName), 0) = 0 Then BackupName = ""
        LbDeleteFile(StrPtr(FileName))
    End If
    Dim KeepLanguage As String = Settings.Language
    Dim KeepDictAsked As Long = Settings.DictAsked
    ConfigLoad()
    Settings.Language = KeepLanguage
    Settings.DictAsked = KeepDictAsked
    ConfigSave()
    Return BackupName
End Function

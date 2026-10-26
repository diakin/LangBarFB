' ---------------------------------------------------------------------------
'  spell.bi - проверка слов по словарям Hunspell, как Lib/Spell.ahk у
'  LangBarXX: та же библиотека NHunspell (hunspell\Hunspellx86.dll, сборка
'  только 32-битная) и те же словари (dict\ru-RU\*.aff и *.dic).
'
'  Папка, где лежат hunspell\ и dict\, ищется так: из настроек
'  ([AutoSwitch] Folder), рядом с exe, на уровень выше. Для каждой
'  раскладки Windows берётся dict\<код раскладки>\: первый *.aff с *.dic
'  того же имени - основной словарь, остальные *.dic - списки слов,
'  которые к нему добавляются (как Spell_InitCustom).
'
'  user_dict.dic рядом с langbarfb.ini - слова, которые не переключаются
'  (по одному в строке, ";" - комментарий). Они добавляются во все
'  словари; туда же пишутся слова, автопереключение которых отменили Break.
'
'  Текст - массивы UTF-16 (UShort), как в sendkeys.bi.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "dir.bi"
#include once "winapi.bi"
#include once "layouts.bi"
#include once "wordstart.bi"

' NHunspell: функции cdecl, строки UTF-16. bool C++ - один байт в AL,
' поэтому результат берётся And &hFF.
Type HunspellInitFn As Function cdecl (ByVal AffPath As WString Ptr, ByVal DicPath As WString Ptr, _
    ByVal KeyText As Any Ptr) As Any Ptr
' NHunspell 0.9.6 и новее (пакет NuGet): содержимое файлов и их размеры
Type HunspellInitDataFn As Function cdecl (ByVal AffData As Any Ptr, ByVal AffSize As UInteger, _
    ByVal DicData As Any Ptr, ByVal DicSize As UInteger, ByVal KeyText As Any Ptr) As Any Ptr
Type HunspellWordFn As Function cdecl (ByVal SpellHandle As Any Ptr, ByVal WordText As WString Ptr) As Long
Type HunspellFreeFn As Sub cdecl (ByVal SpellHandle As Any Ptr)

Const SPELL_MAX_WORD = 64

Dim Shared SpellLibrary As Any Ptr
Dim Shared HunspellInit As HunspellInitFn
Dim Shared HunspellInitData As HunspellInitDataFn
' 1 - библиотека новая, HunspellInit принимает содержимое файлов
Dim Shared SpellInitByData As Long
Dim Shared HunspellSpell As HunspellWordFn
Dim Shared HunspellAdd As HunspellWordFn
Dim Shared HunspellFree As HunspellFreeFn
' словарь каждой раскладки LayoutList; 0 - словаря нет
Dim Shared SpellDict(0 To MAX_LAYOUTS - 1) As Any Ptr
Dim Shared SpellDictCount As Long
' папка с hunspell\ и dict\ и итог загрузки словами (окно настроек, отладка)
Dim Shared SpellBaseFolder As String
Dim Shared SpellStatus As String

Const SPELL_DLL_NAME = "Hunspellx86.dll"

' --- строки ---

' Строка CP1251 (путь) - в UTF-16 с нулём в конце
Private Sub SpellWideOf(ByRef AnsiText As String, WideChars() As UShort)
    Dim CharCount As Long = LbMultiByteToWideChar(LB_CP_ACP, 0, StrPtr(AnsiText), Len(AnsiText), 0, 0)
    ReDim WideChars(0 To CharCount)
    If CharCount > 0 Then
        LbMultiByteToWideChar(LB_CP_ACP, 0, StrPtr(AnsiText), Len(AnsiText), _
            Cast(WString Ptr, @WideChars(0)), CharCount)
    End If
    WideChars(CharCount) = 0
End Sub

' Кусок текста UTF-16 - строкой CP1251 (для окна отладки)
Function SpellAnsiOf(TextChars() As UShort, ByVal StartIdx As Long, ByVal CharCount As Long) As String
    If CharCount <= 0 Then Return ""
    Dim AnsiText As String = String(CharCount * 2, 0)
    Dim ByteCount As Long = LbWideCharToMultiByte(LB_CP_ACP, 0, Cast(WString Ptr, @TextChars(StartIdx)), _
        CharCount, StrPtr(AnsiText), Len(AnsiText), 0, 0)
    Return Left(AnsiText, ByteCount)
End Function

' Файл целиком в UTF-16: UTF-8 (с BOM или без) или, если это не UTF-8, CP1251.
' Возвращает число символов; -1 - файл не прочитан.
Private Function SpellReadTextFile(ByRef FileName As String, TextChars() As UShort) As Long
    Dim FileNum As Long = FreeFile
    If Open(FileName For Binary Access Read As #FileNum) <> 0 Then Return -1
    Dim FileBytes As String = String(Lof(FileNum), 0)
    If Len(FileBytes) > 0 Then Get #FileNum, , FileBytes
    Close #FileNum
    Dim SkipBytes As Long
    If Left(FileBytes, 3) = Chr(&hEF, &hBB, &hBF) Then SkipBytes = 3
    Dim SourcePtr As ZString Ptr = StrPtr(FileBytes) + SkipBytes
    Dim SourceLen As Long = Len(FileBytes) - SkipBytes
    If SourceLen <= 0 Then Return 0
    ' флаг 8 - ошибка на неверной последовательности UTF-8
    Dim CodePage As ULong = LB_CP_UTF8
    Dim CharCount As Long = LbMultiByteToWideChar(CodePage, 8, SourcePtr, SourceLen, 0, 0)
    If CharCount <= 0 Then
        CodePage = LB_CP_ACP
        CharCount = LbMultiByteToWideChar(CodePage, 0, SourcePtr, SourceLen, 0, 0)
    End If
    If CharCount <= 0 Then Return 0
    ReDim TextChars(0 To CharCount - 1)
    LbMultiByteToWideChar(CodePage, 0, SourcePtr, SourceLen, Cast(WString Ptr, @TextChars(0)), CharCount)
    Return CharCount
End Function

' --- проверка слова ---

' Слово без знаков по краям: от первой буквы до последней (дефис и
' апостроф внутри остаются). Возвращает число букв; 0 - букв нет.
Function SpellCoreRange(TextChars() As UShort, ByVal CharCount As Long, _
        ByRef CoreStart As Long, ByRef CoreLength As Long) As Long
    Dim FirstIdx As Long = -1, LastIdx As Long = -1, Letters As Long
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        If LbIsCharAlpha(TextChars(CharIdx)) Then
            If FirstIdx < 0 Then FirstIdx = CharIdx
            LastIdx = CharIdx
            Letters += 1
        End If
    Next
    If FirstIdx < 0 Then
        CoreStart = 0 : CoreLength = 0
        Return 0
    End If
    CoreStart = FirstIdx
    CoreLength = LastIdx - FirstIdx + 1
    Return Letters
End Function

' Слово TextChars(StartIdx..) в словаре раскладки LayoutIdx. Слово только
' из строчных проверяется ещё и с заглавной первой буквой: «москва» -
' «Москва» (так же делает LangBarXX).
Function SpellCheck(ByVal LayoutIdx As Long, TextChars() As UShort, ByVal StartIdx As Long, _
        ByVal CharCount As Long) As Long
    If LayoutIdx < 0 Or LayoutIdx >= MAX_LAYOUTS Then Return 0
    Dim DictHandle As Any Ptr = SpellDict(LayoutIdx)
    If DictHandle = 0 Or CharCount <= 0 Or CharCount > SPELL_MAX_WORD Then Return 0
    Dim WordBuffer(0 To SPELL_MAX_WORD) As UShort
    Dim CharIdx As Long, AllLower As Long = 1
    For CharIdx = 0 To CharCount - 1
        WordBuffer(CharIdx) = TextChars(StartIdx + CharIdx)
        If LbIsCharUpper(WordBuffer(CharIdx)) Then AllLower = 0
    Next
    WordBuffer(CharCount) = 0
    If (HunspellSpell(DictHandle, Cast(WString Ptr, @WordBuffer(0))) And &hFF) <> 0 Then Return 1
    If AllLower = 0 Then Return 0
    LbCharUpperBuff(@WordBuffer(0), 1)
    Return IIf((HunspellSpell(DictHandle, Cast(WString Ptr, @WordBuffer(0))) And &hFF) <> 0, 1, 0)
End Function

' Слово - в словарь раскладки и в её таблицу начал слов
Private Sub SpellAddTo(ByVal LayoutIdx As Long, TextChars() As UShort, ByVal StartIdx As Long, _
        ByVal CharCount As Long)
    If LayoutIdx < 0 Or LayoutIdx >= MAX_LAYOUTS Then Exit Sub
    Dim DictHandle As Any Ptr = SpellDict(LayoutIdx)
    If DictHandle = 0 Or CharCount <= 0 Or CharCount > SPELL_MAX_WORD Then Exit Sub
    StartsAddWord(LayoutIdx, TextChars(), StartIdx, CharCount)
    Dim WordBuffer(0 To SPELL_MAX_WORD) As UShort
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount - 1
        WordBuffer(CharIdx) = TextChars(StartIdx + CharIdx)
    Next
    WordBuffer(CharCount) = 0
    HunspellAdd(DictHandle, Cast(WString Ptr, @WordBuffer(0)))
End Sub

' Слова файла (по одному в строке) - в словарь; у строк вида «слово/флаги»
' флаги отбрасываются, первая строка .dic с числом слов пропускается.
' TargetIdx -1 - во все словари. Возвращает число слов.
Private Function SpellAddWordsFromFile(ByRef FileName As String, ByVal TargetIdx As Long) As Long
    Dim TextChars() As UShort
    Dim CharCount As Long = SpellReadTextFile(FileName, TextChars())
    If CharCount <= 0 Then Return 0
    Dim WordCount As Long, LineStart As Long, LineIdx As Long
    Dim CharIdx As Long
    For CharIdx = 0 To CharCount
        If CharIdx < CharCount AndAlso TextChars(CharIdx) <> 10 Then Continue For
        ' строка LineStart..CharIdx-1: до «/», без пробелов и CR по краям
        Dim WordStart As Long = LineStart, WordEnd As Long = LineStart
        While WordEnd < CharIdx AndAlso TextChars(WordEnd) <> Asc("/") AndAlso TextChars(WordEnd) <> 13
            WordEnd += 1
        Wend
        While WordStart < WordEnd AndAlso TextChars(WordStart) <= 32
            WordStart += 1
        Wend
        While WordEnd > WordStart AndAlso TextChars(WordEnd - 1) <= 32
            WordEnd -= 1
        Wend
        Dim IsWord As Long = IIf(WordEnd > WordStart, 1, 0)
        If IsWord AndAlso TextChars(WordStart) = Asc(";") Then IsWord = 0
        If IsWord And LineIdx = 0 Then
            ' число слов в начале .dic
            If TextChars(WordStart) >= Asc("0") And TextChars(WordStart) <= Asc("9") Then IsWord = 0
        End If
        If IsWord Then
            If TargetIdx >= 0 Then
                SpellAddTo(TargetIdx, TextChars(), WordStart, WordEnd - WordStart)
            Else
                Dim LayoutIdx As Long
                For LayoutIdx = 0 To LayoutCount - 1
                    SpellAddTo(LayoutIdx, TextChars(), WordStart, WordEnd - WordStart)
                Next
            End If
            WordCount += 1
        End If
        LineStart = CharIdx + 1
        LineIdx += 1
    Next
    Return WordCount
End Function

Function SpellUserDictName() As String
    Return ExePath & "\user_dict.dic"
End Function

' Слово больше не переключается: в словарь раскладки и в user_dict.dic
Sub SpellRemember(ByVal LayoutIdx As Long, TextChars() As UShort, ByVal StartIdx As Long, _
        ByVal CharCount As Long, ByVal WriteFile As Long)
    If LayoutIdx < 0 Or LayoutIdx >= LayoutCount Then Exit Sub
    SpellAddTo(LayoutIdx, TextChars(), StartIdx, CharCount)
    If WriteFile = 0 Or CharCount <= 0 Then Exit Sub
    Dim LineBytes As String = String(CharCount * 3 + 2, 0)
    Dim ByteCount As Long = LbWideCharToMultiByte(LB_CP_UTF8, 0, Cast(WString Ptr, @TextChars(StartIdx)), _
        CharCount, StrPtr(LineBytes), Len(LineBytes), 0, 0)
    If ByteCount <= 0 Then Exit Sub
    Dim FileNum As Long = FreeFile
    If Open(SpellUserDictName() For Binary As #FileNum) <> 0 Then Exit Sub
    Dim LineText As String = Left(LineBytes, ByteCount) & Chr(13, 10)
    ' дописать в конец; если файл кончается не переводом строки - сначала он
    If Lof(FileNum) > 0 Then
        Dim LastByte As String = " "
        Get #FileNum, Lof(FileNum), LastByte
        If LastByte <> Chr(10) Then LineText = Chr(13, 10) & LineText
    End If
    Put #FileNum, Lof(FileNum) + 1, LineText
    Close #FileNum
End Sub

' --- загрузка ---

Private Function SpellHasDll(ByRef BaseFolder As String) As Long
    If BaseFolder = "" Then Return 0
    Return IIf(FileExists(BaseFolder & "\hunspell\" & SPELL_DLL_NAME), 1, 0)
End Function

Sub SpellUnload()
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To MAX_LAYOUTS - 1
        If SpellDict(LayoutIdx) <> 0 Then HunspellFree(SpellDict(LayoutIdx))
        SpellDict(LayoutIdx) = 0
        StartsClear(LayoutIdx)
    Next
    SpellDictCount = 0
End Sub

' Файл целиком в строку байтов; 0 - не прочитан или пустой
Private Function SpellReadBytes(ByRef FileName As String, ByRef FileBytes As String) As Long
    Dim FileNum As Long = FreeFile
    If Open(FileName For Binary Access Read As #FileNum) <> 0 Then Return 0
    FileBytes = String(Lof(FileNum), 0)
    If Len(FileBytes) > 0 Then Get #FileNum, , FileBytes
    Close #FileNum
    Return Len(FileBytes)
End Function

' Версия NHunspell не ниже 0.9.6: HunspellInit принимает содержимое
' файлов (у 0.9.2 из LangBarXX - пути)
Private Function SpellDllTakesData(ByRef DllPath As String) As Long
    Dim InfoSize As ULong = LbGetFileVersionInfoSize(StrPtr(DllPath), 0)
    If InfoSize = 0 Then Return 0
    Dim InfoBlock As String = String(InfoSize, 0)
    If LbGetFileVersionInfo(StrPtr(DllPath), 0, InfoSize, StrPtr(InfoBlock)) = 0 Then Return 0
    Dim FixedInfo As ULong Ptr, InfoLen As ULong
    If LbVerQueryValue(StrPtr(InfoBlock), "\", @FixedInfo, @InfoLen) = 0 Or InfoLen < 16 Then Return 0
    ' VS_FIXEDFILEINFO: [2] - старшая часть версии, [3] - младшая
    Dim VersionHigh As ULong = FixedInfo[2], VersionLow As ULong = FixedInfo[3]
    Dim MajorPart As Long = VersionHigh Shr 16, MinorPart As Long = VersionHigh And &hFFFF
    Dim BuildPart As Long = VersionLow Shr 16
    If MajorPart > 0 Or MinorPart > 9 Then Return 1
    Return IIf(MinorPart = 9 And BuildPart >= 6, 1, 0)
End Function

' Словарь раскладки LayoutIdx из BaseFolder\dict\<код>\
Private Sub SpellLoadLayout(ByVal LayoutIdx As Long, ByRef DictFolder As String)
    Dim AffName As String = Dir(DictFolder & "\*.aff")
    If AffName = "" Then Exit Sub
    Dim MainDic As String = Left(AffName, Len(AffName) - 4) & ".dic"
    If FileExists(DictFolder & "\" & MainDic) = 0 Then Exit Sub
    Dim AffPath() As UShort, DicPath() As UShort
    SpellWideOf(DictFolder & "\" & AffName, AffPath())
    SpellWideOf(DictFolder & "\" & MainDic, DicPath())
    If SpellInitByData Then
        Dim AffBytes As String, DicBytes As String
        If SpellReadBytes(DictFolder & "\" & AffName, AffBytes) = 0 Then Exit Sub
        If SpellReadBytes(DictFolder & "\" & MainDic, DicBytes) = 0 Then Exit Sub
        SpellDict(LayoutIdx) = HunspellInitData(StrPtr(AffBytes), Len(AffBytes), StrPtr(DicBytes), Len(DicBytes), 0)
    Else
        SpellDict(LayoutIdx) = HunspellInit(Cast(WString Ptr, @AffPath(0)), Cast(WString Ptr, @DicPath(0)), 0)
    End If
    If SpellDict(LayoutIdx) = 0 Then Exit Sub
    SpellDictCount += 1
    StartsBuild(LayoutIdx, DictFolder & "\" & AffName, DictFolder & "\" & MainDic)
    ' остальные .dic папки - дополнительные списки слов
    Dim ExtraName As String = Dir(DictFolder & "\*.dic")
    While ExtraName <> ""
        If LCase(ExtraName) <> LCase(MainDic) Then
            SpellAddWordsFromFile(DictFolder & "\" & ExtraName, LayoutIdx)
        End If
        ExtraName = Dir()
    Wend
End Sub

' Загружает библиотеку и словари всех раскладок. PreferredFolder - папка
' из настроек (может быть пустой). Возвращает число словарей.
Function SpellLoad(ByRef PreferredFolder As String) As Long
    SpellUnload()
    SpellBaseFolder = ""
    Dim Candidates(0 To 2) As String
    Candidates(0) = PreferredFolder
    Candidates(1) = ExePath
    Candidates(2) = ExePath & "\.."
    Dim CandIdx As Long
    For CandIdx = 0 To 2
        If SpellHasDll(Candidates(CandIdx)) Then
            SpellBaseFolder = Candidates(CandIdx)
            Exit For
        End If
    Next
    If SpellBaseFolder = "" Then
        SpellStatus = Tr("не найдена hunspell\") & SPELL_DLL_NAME
        Return 0
    End If
    If SpellLibrary = 0 Then
        SpellLibrary = LbLoadLibrary(SpellBaseFolder & "\hunspell\" & SPELL_DLL_NAME)
        If SpellLibrary = 0 Then
            SpellStatus = Tr("не загрузилась ") & SPELL_DLL_NAME & Tr(" (ошибка ") & LbGetLastError() & ")"
            Return 0
        End If
        HunspellInit = LbGetProcAddress(SpellLibrary, "HunspellInit")
        HunspellInitData = Cast(HunspellInitDataFn, HunspellInit)
        SpellInitByData = SpellDllTakesData(SpellBaseFolder & "\hunspell\" & SPELL_DLL_NAME)
        HunspellSpell = LbGetProcAddress(SpellLibrary, "HunspellSpell")
        HunspellAdd = LbGetProcAddress(SpellLibrary, "HunspellAdd")
        HunspellFree = LbGetProcAddress(SpellLibrary, "HunspellFree")
        If HunspellInit = 0 Or HunspellSpell = 0 Or HunspellAdd = 0 Or HunspellFree = 0 Then
            SpellStatus = Tr("в ") & SPELL_DLL_NAME & Tr(" нет функций Hunspell")
            SpellLibrary = 0
            Return 0
        End If
    End If

    Dim Loaded As String, Missing As String
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        Dim LocaleCode As String = LayoutList(LayoutIdx).LocaleCode
        SpellLoadLayout(LayoutIdx, SpellBaseFolder & "\dict\" & LocaleCode)
        If SpellDict(LayoutIdx) <> 0 Then
            Loaded &= IIf(Loaded = "", "", ", ") & LocaleCode
        Else
            Missing &= IIf(Missing = "", "", ", ") & LocaleCode
        End If
    Next
    Dim UserWords As Long
    If SpellDictCount > 0 Then UserWords = SpellAddWordsFromFile(SpellUserDictName(), -1)
    If Loaded = "" Then
        SpellStatus = Tr("словарей нет в ") & SpellBaseFolder & "\dict"
    Else
        SpellStatus = Tr("словари: ") & Loaded
        If Missing <> "" Then SpellStatus &= Tr("; нет словаря: ") & Missing
        If UserWords > 0 Then SpellStatus &= Tr("; слов пользователя: ") & UserWords
    End If
    Return SpellDictCount
End Function

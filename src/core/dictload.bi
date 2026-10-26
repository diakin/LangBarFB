' ---------------------------------------------------------------------------
'  dictload.bi - скачивание библиотеки Hunspell и словарей.
'
'  Основной источник - репозиторий LangBarFB (папки hunspell и dict, из
'  установщика LangBarXX 1.8.4, и sounds - звуки LangBarXX): файлы скачиваются по одному с GitHub в
'  папку exe, только языки раскладок Windows.
'
'  Запасные источники - если с основного не скачалось:
'  - словари: репозиторий словарей LibreOffice (github.com/LibreOffice/
'    dictionaries), те же языки, имена файлов там свои;
'  - библиотека: пакет NHunspell 1.2 на nuget.org. Это zip; нужная DLL
'    достаётся из него скриптом Shell.Application (cscript). Эта версия
'    библиотеки принимает содержимое словарей, а не пути (spell.bi).
'
'  Файлы одного языка (группа) берутся из одного источника: .aff одной
'  версии с .dic другой может не работать. Если не скачался любой
'  обязательный файл группы, группа целиком качается из запасного.
'
'  Скачивание идёт в отдельном потоке (URLDownloadToFile ждёт сеть, а
'  главный поток должен разбирать вызовы хука). Поток работает только с
'  буферами DictJobs и функциями Windows; по окончании он посылает
'  DictNotifyMessage окну DictNotifyWindow.
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"
#include once "layouts.bi"
#include once "spell.bi"

Const DICT_BASE_URL = "https://raw.githubusercontent.com/diakin/LangBarFB/master/"
Const DICT_MIRROR_URL = "https://raw.githubusercontent.com/LibreOffice/dictionaries/master/"
Const DICT_SOUNDS_MIRROR = "https://raw.githubusercontent.com/Krot66/LangBarXX/master/sounds/"
Const DICT_NUGET_URL = "https://api.nuget.org/v3-flatcontainer/nhunspell/1.2.5554.16953/nhunspell.1.2.5554.16953.nupkg"
' страница со словарями - если скачать не вышло, их можно взять вручную
Const DICT_PAGE_URL = "https://github.com/diakin/LangBarFB/tree/master/dict"
' словари других языков (ссылка из меню LangBarXX «Словари Hunspell»)
Const DICT_MORE_URL = "https://drive.google.com/drive/folders/1Xe13v0hm3nzipRkTSIcbuAaTZGIYYpP2"

' Словари: код раскладки и файлы через «|». Файл - «имя у нас=путь в
' репозитории LibreOffice»; без «=путь» запасного источника у файла нет,
' и он необязательный. README_*.txt - описание и лицензия словаря.
Const DICT_LANG_COUNT = 6
Dim Shared DictLangCodes(0 To DICT_LANG_COUNT - 1) As ZString * 8 = { _
    "en-US", "ru-RU", "uk-UA", "be-BY", "de-DE", "fr-FR"}
Dim Shared DictLangFiles(0 To DICT_LANG_COUNT - 1) As ZString * 200 = { _
    "en_US.aff=en/en_US.aff|en_US.dic=en/en_US.dic|en_US_(computer_abbr).dic|README_en_US.txt=en/README_en_US.txt", _
    "ru_RU.aff=ru_RU/ru_RU.aff|ru_RU.dic=ru_RU/ru_RU.dic|README_ru_RU.txt=ru_RU/README_ru_RU.txt", _
    "uk_UA.aff=uk_UA/uk_UA.aff|uk_UA.dic=uk_UA/uk_UA.dic|README_uk_UA.txt=uk_UA/README_uk_UA.txt", _
    "be_BY.aff=be_BY/be-official.aff|be_BY.dic=be_BY/be-official.dic|README_be_BY.txt=be_BY/README_be_BY.txt", _
    "de_DE.aff=de/de_DE_frami.aff|de_DE.dic=de/de_DE_frami.dic|README_de_DE_frami.txt=de/README_de_DE_frami.txt", _
    "fr_FR.aff=fr_FR/dictionaries/fr.aff|fr_FR.dic=fr_FR/dictionaries/fr.dic|README_dict_fr.txt=fr_FR/dictionaries/README_dict_fr.txt"}

Type DictJob
    SourceUrl As ZString * 512
    MirrorUrl As ZString * 512     ' пусто - запасного нет (файл необязательный)
    TargetPath As ZString * 512
    GroupIdx As Long               ' 0 - библиотека, дальше - языки
    FromZip As Long                ' запасной источник - zip, файл достаёт скрипт
End Type

Const DICT_MAX_JOBS = 40
Const DICT_MAX_GROUPS = 16
Dim Shared DictJobs(0 To DICT_MAX_JOBS - 1) As DictJob
Dim Shared DictJobCount As Long
Dim Shared DictGroupCount As Long
Dim Shared DictGroupNames(0 To DICT_MAX_GROUPS - 1) As ZString * 32
' итог группы: 0 - не скачалась, 1 - основной источник, 2 - запасной
Dim Shared DictGroupResult(0 To DICT_MAX_GROUPS - 1) As Long
Dim Shared DictGroupError(0 To DICT_MAX_GROUPS - 1) As Long
Dim Shared DictRunning As Long
Dim Shared DictNotifyWindow As Any Ptr
Dim Shared DictNotifyMessage As ULong
' для распаковки библиотеки из пакета NuGet
Dim Shared DictZipPath As ZString * 512
Dim Shared DictScriptPath As ZString * 512
Dim Shared DictScriptCommand As ZString * 1100
' языки, которые скачиваются (для сообщения)
Dim Shared DictLangList As String

' --- поток ---

Private Function DictFileExists(ByVal FileName As ZString Ptr) As Long
    Return IIf(LbGetFileAttributes(FileName) <> LB_INVALID_FILE_ATTRIBUTES, 1, 0)
End Function

' Достаёт библиотеку из скачанного zip (скрипт пишет главный поток)
Private Function DictUnzipLibrary(ByVal TargetPath As ZString Ptr) As Long
    Dim StartInfo As LbStartupInfo
    Dim ProcInfo As LbProcessInfo
    StartInfo.StructSize = SizeOf(LbStartupInfo)
    If LbCreateProcess(0, @DictScriptCommand, 0, 0, 0, LB_CREATE_NO_WINDOW, 0, 0, StartInfo, ProcInfo) = 0 Then Return 0
    LbWaitForSingleObject(ProcInfo.ProcessHandle, 60000)
    LbCloseHandle(ProcInfo.ProcessHandle)
    LbCloseHandle(ProcInfo.ThreadHandle)
    LbDeleteFile(@DictZipPath)
    Return DictFileExists(TargetPath)
End Function

' Скачивает файлы группы из основного (UseMirror = 0) или запасного
' источника. Возвращает 0 при успехе или код ошибки.
Private Function DictLoadGroup(ByVal GroupIdx As Long, ByVal UseMirror As Long) As Long
    Dim JobIdx As Long
    For JobIdx = 0 To DictJobCount - 1
        With DictJobs(JobIdx)
            If .GroupIdx <> GroupIdx Then Continue For
            Dim ResultCode As Long
            If UseMirror = 0 Then
                ResultCode = LbURLDownloadToFile(0, @.SourceUrl, @.TargetPath, 0, 0)
            ElseIf .MirrorUrl[0] = 0 Then
                Continue For
            ElseIf .FromZip Then
                ResultCode = LbURLDownloadToFile(0, @.MirrorUrl, @DictZipPath, 0, 0)
                If ResultCode = 0 AndAlso DictUnzipLibrary(@.TargetPath) = 0 Then ResultCode = -1
            Else
                ResultCode = LbURLDownloadToFile(0, @.MirrorUrl, @.TargetPath, 0, 0)
            End If
            If ResultCode <> 0 Then
                LbDeleteFile(@.TargetPath)
                ' необязательный файл (нет запасного источника) - без него можно
                If .MirrorUrl[0] <> 0 Then Return ResultCode
            End If
        End With
    Next
    Return 0
End Function

Private Sub DictDeleteGroup(ByVal GroupIdx As Long)
    Dim JobIdx As Long
    For JobIdx = 0 To DictJobCount - 1
        If DictJobs(JobIdx).GroupIdx = GroupIdx Then LbDeleteFile(@DictJobs(JobIdx).TargetPath)
    Next
End Sub

Private Function DictThreadProc stdcall (ByVal Param As Any Ptr) As ULong
    LbCoInitialize(0)
    Dim GroupIdx As Long
    For GroupIdx = 0 To DictGroupCount - 1
        Dim ResultCode As Long = DictLoadGroup(GroupIdx, 0)
        If ResultCode = 0 Then
            DictGroupResult(GroupIdx) = 1
            Continue For
        End If
        DictGroupError(GroupIdx) = ResultCode
        DictDeleteGroup(GroupIdx)
        If DictLoadGroup(GroupIdx, 1) = 0 Then
            DictGroupResult(GroupIdx) = 2
        Else
            DictDeleteGroup(GroupIdx)
        End If
    Next
    LbDeleteFile(@DictScriptPath)
    LbCoUninitialize()
    LbPostMessage(DictNotifyWindow, DictNotifyMessage, 0, 0)
    Return 0
End Function

' --- главный поток ---

Private Sub DictAddJob(ByRef RelativePath As String, ByRef MirrorUrl As String, ByVal FromZip As Long, _
        ByRef TargetFolder As String)
    If DictJobCount >= DICT_MAX_JOBS Then Exit Sub
    Dim UrlPath As String = RelativePath
    Dim CharIdx As Long
    For CharIdx = 0 To Len(UrlPath) - 1
        If UrlPath[CharIdx] = Asc("\") Then UrlPath[CharIdx] = Asc("/")
    Next
    With DictJobs(DictJobCount)
        .SourceUrl = DICT_BASE_URL & UrlPath
        .MirrorUrl = MirrorUrl
        .TargetPath = TargetFolder & "\" & RelativePath
        .GroupIdx = DictGroupCount
        .FromZip = FromZip
    End With
    DictJobCount += 1
End Sub

' Группа уже скачана: все обязательные файлы на месте
Private Function DictGroupPresent(ByVal GroupIdx As Long) As Long
    Dim JobIdx As Long
    For JobIdx = 0 To DictJobCount - 1
        With DictJobs(JobIdx)
            If .GroupIdx = GroupIdx And .MirrorUrl <> "" Then
                If FileExists(.TargetPath) = 0 Then Return 0
            End If
        End With
    Next
    Return 1
End Function

' Закрывает группу: если всё уже скачано, её задания убираются
Private Sub DictEndGroup(ByRef GroupName As String, ByVal FirstJob As Long)
    If DictGroupPresent(DictGroupCount) Then
        DictJobCount = FirstJob
        Exit Sub
    End If
    DictGroupNames(DictGroupCount) = GroupName
    DictGroupResult(DictGroupCount) = 0
    DictGroupError(DictGroupCount) = 0
    DictGroupCount += 1
End Sub

' Скрипт распаковки библиотеки из пакета NuGet (zip): content\<DLL>
Private Sub DictWriteUnzipScript(ByRef TargetFolder As String)
    DictZipPath = TargetFolder & "\hunspell\nhunspell.zip"
    DictScriptPath = TargetFolder & "\hunspell\unzip.vbs"
    Dim FileNum As Long = FreeFile
    If Open(DictScriptPath For Output As #FileNum) <> 0 Then Exit Sub
    Print #FileNum, "Set shellApp = CreateObject(""Shell.Application"")"
    Print #FileNum, "Set fileSys = CreateObject(""Scripting.FileSystemObject"")"
    Print #FileNum, "Set zipRoot = shellApp.NameSpace(""" & DictZipPath & """)"
    Print #FileNum, "Set dllItem = zipRoot.ParseName(""content"").GetFolder.ParseName(""" & SPELL_DLL_NAME & """)"
    Print #FileNum, "shellApp.NameSpace(""" & TargetFolder & "\hunspell"").CopyHere dllItem, 20"
    ' CopyHere копирует асинхронно - ждём файл
    Print #FileNum, "waitCount = 0"
    Print #FileNum, "Do Until fileSys.FileExists(""" & TargetFolder & "\hunspell\" & SPELL_DLL_NAME & """) Or waitCount > 300"
    Print #FileNum, "    WScript.Sleep 100"
    Print #FileNum, "    waitCount = waitCount + 1"
    Print #FileNum, "Loop"
    Print #FileNum, "WScript.Sleep 500"
    Close #FileNum
    DictScriptCommand = "cscript.exe //nologo //B """ & DictScriptPath & """"
End Sub

' Начинает скачивание в TargetFolder. Возвращает число файлов (0 - всё
' уже есть или словарей для раскладок нет), -1 - скачивание уже идёт.
Function DictDownloadStart(ByRef TargetFolder As String, ByVal NotifyWindow As Any Ptr, _
        ByVal NotifyMessage As ULong) As Long
    If DictRunning Then Return -1
    DictJobCount = 0
    DictGroupCount = 0
    DictLangList = ""
    MkDir TargetFolder & "\hunspell"
    MkDir TargetFolder & "\dict"
    DictWriteUnzipScript(TargetFolder)
    DictAddJob("hunspell\" & SPELL_DLL_NAME, DICT_NUGET_URL, 1, TargetFolder)
    DictEndGroup("Hunspell", 0)
    ' звуки (из LangBarXX; запасной источник - его репозиторий)
    MkDir TargetFolder & "\sounds"
    Dim FirstSound As Long = DictJobCount
    Dim SoundNames(0 To 2) As String
    SoundNames(0) = "autocorrect.wav" : SoundNames(1) = "undo.wav" : SoundNames(2) = "autoreplace.wav"
    Dim SoundIdx As Long
    For SoundIdx = 0 To 2
        DictAddJob("sounds\" & SoundNames(SoundIdx), DICT_SOUNDS_MIRROR & SoundNames(SoundIdx), 0, TargetFolder)
    Next
    DictEndGroup("звуки", FirstSound)
    Dim LayoutIdx As Long, LangIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        For LangIdx = 0 To DICT_LANG_COUNT - 1
            If LayoutList(LayoutIdx).LocaleCode <> DictLangCodes(LangIdx) Then Continue For
            If DictGroupCount >= DICT_MAX_GROUPS Then Continue For
            Dim LangCode As String = DictLangCodes(LangIdx)
            MkDir TargetFolder & "\dict\" & LangCode
            Dim FirstJob As Long = DictJobCount
            Dim FileList As String = DictLangFiles(LangIdx) & "|"
            Dim BarPos As Long = InStr(FileList, "|")
            While BarPos > 0
                Dim FileSpec As String = Left(FileList, BarPos - 1)
                Dim EqualPos As Long = InStr(FileSpec, "=")
                If EqualPos > 0 Then
                    DictAddJob("dict\" & LangCode & "\" & Left(FileSpec, EqualPos - 1), _
                        DICT_MIRROR_URL & Mid(FileSpec, EqualPos + 1), 0, TargetFolder)
                Else
                    DictAddJob("dict\" & LangCode & "\" & FileSpec, "", 0, TargetFolder)
                End If
                FileList = Mid(FileList, BarPos + 1)
                BarPos = InStr(FileList, "|")
            Wend
            Dim GroupsBefore As Long = DictGroupCount
            DictEndGroup(LangCode, FirstJob)
            If DictGroupCount > GroupsBefore Then DictLangList &= IIf(DictLangList = "", "", ", ") & LangCode
        Next
    Next
    If DictJobCount = 0 Then
        Kill DictScriptPath
        Return 0
    End If
    DictNotifyWindow = NotifyWindow
    DictNotifyMessage = NotifyMessage
    Dim ThreadHandle As Any Ptr = LbCreateThread(0, 0, @DictThreadProc, 0, 0, 0)
    If ThreadHandle = 0 Then Return 0
    LbCloseHandle(ThreadHandle)
    DictRunning = 1
    Return DictJobCount
End Function

' Итог потока (пришло DictNotifyMessage): что скачалось и откуда. Failed -
' число групп, которые не скачались.
Function DictDownloadResult(ByRef Failed As Long) As String
    DictRunning = 0
    Failed = 0
    Dim ResultText As String, GroupIdx As Long
    For GroupIdx = 0 To DictGroupCount - 1
        Dim LineText As String = DictGroupNames(GroupIdx) & ": "
        Select Case DictGroupResult(GroupIdx)
        Case 1
            LineText &= "скачано"
        Case 2
            LineText &= "скачано из запасного источника (основной: ошибка 0x" & Hex(DictGroupError(GroupIdx)) & ")"
        Case Else
            LineText &= "НЕ скачано (ошибка 0x" & Hex(DictGroupError(GroupIdx)) & ")"
            Failed += 1
        End Select
        ResultText &= LineText & Chr(13, 10)
    Next
    Return ResultText
End Function

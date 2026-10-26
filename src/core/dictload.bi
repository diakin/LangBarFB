' ---------------------------------------------------------------------------
'  dictload.bi - скачивание библиотеки Hunspell и словарей.
'
'  Файлы лежат в репозитории LangBarFB (папки hunspell и dict, взяты из
'  установщика LangBarXX 1.8.4) и скачиваются по одному с GitHub в папку
'  exe: hunspell\Hunspellx86.dll (или x64) и словари только тех языков,
'  раскладки которых есть в Windows. Распаковывать ничего не нужно.
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
' страница со словарями - если скачать не вышло, их можно взять вручную
Const DICT_PAGE_URL = "https://github.com/diakin/LangBarFB/tree/master/dict"
' словари других языков (ссылка из меню LangBarXX «Словари Hunspell»)
Const DICT_MORE_URL = "https://drive.google.com/drive/folders/1Xe13v0hm3nzipRkTSIcbuAaTZGIYYpP2"

' какие словари есть в репозитории: код раскладки и файлы через «|»
Const DICT_LANG_COUNT = 6
Dim Shared DictLangCodes(0 To DICT_LANG_COUNT - 1) As ZString * 8 = { _
    "en-US", "ru-RU", "uk-UA", "be-BY", "de-DE", "fr-FR"}
Dim Shared DictLangFiles(0 To DICT_LANG_COUNT - 1) As ZString * 80 = { _
    "en_US.aff|en_US.dic|en_US_(computer_abbr).dic", "ru_RU.aff|ru_RU.dic", "uk_UA.aff|uk_UA.dic", _
    "be_BY.aff|be_BY.dic", "de_DE.aff|de_DE.dic", "fr_FR.aff|fr_FR.dic"}

Type DictJob
    SourceUrl As ZString * 512
    TargetPath As ZString * 512
End Type

Const DICT_MAX_JOBS = 32
Dim Shared DictJobs(0 To DICT_MAX_JOBS - 1) As DictJob
Dim Shared DictJobCount As Long
Dim Shared DictRunning As Long
' итог потока: номер файла, который не скачался (-1 - все), и код ошибки
Dim Shared DictFailedIdx As Long
Dim Shared DictFailedCode As Long
Dim Shared DictNotifyWindow As Any Ptr
Dim Shared DictNotifyMessage As ULong
' языки, которые скачиваются (для сообщения)
Dim Shared DictLangList As String

Private Function DictThreadProc stdcall (ByVal Param As Any Ptr) As ULong
    LbCoInitialize(0)
    DictFailedIdx = -1
    Dim JobIdx As Long
    For JobIdx = 0 To DictJobCount - 1
        Dim ResultCode As Long = LbURLDownloadToFile(0, @DictJobs(JobIdx).SourceUrl, @DictJobs(JobIdx).TargetPath, 0, 0)
        If ResultCode <> 0 Then
            DictFailedIdx = JobIdx
            DictFailedCode = ResultCode
            ' недокачанный файл не оставлять
            LbDeleteFile(@DictJobs(JobIdx).TargetPath)
            Exit For
        End If
    Next
    LbCoUninitialize()
    LbPostMessage(DictNotifyWindow, DictNotifyMessage, 0, 0)
    Return 0
End Function

Private Sub DictAddJob(ByRef RelativePath As String, ByRef TargetFolder As String)
    If DictJobCount >= DICT_MAX_JOBS Then Exit Sub
    Dim TargetPath As String = TargetFolder & "\" & RelativePath
    ' уже скачанное не скачивается заново
    If FileExists(TargetPath) Then Exit Sub
    Dim UrlPath As String = RelativePath
    Dim CharIdx As Long
    For CharIdx = 0 To Len(UrlPath) - 1
        If UrlPath[CharIdx] = Asc("\") Then UrlPath[CharIdx] = Asc("/")
    Next
    DictJobs(DictJobCount).SourceUrl = DICT_BASE_URL & UrlPath
    DictJobs(DictJobCount).TargetPath = TargetPath
    DictJobCount += 1
End Sub

' Начинает скачивание в TargetFolder. Возвращает число файлов (0 - всё
' уже есть или словарей для раскладок нет), -1 - скачивание уже идёт.
Function DictDownloadStart(ByRef TargetFolder As String, ByVal NotifyWindow As Any Ptr, _
        ByVal NotifyMessage As ULong) As Long
    If DictRunning Then Return -1
    DictJobCount = 0
    DictLangList = ""
    MkDir TargetFolder & "\hunspell"
    MkDir TargetFolder & "\dict"
    DictAddJob("hunspell\" & SPELL_DLL_NAME, TargetFolder)
    Dim LayoutIdx As Long, LangIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        For LangIdx = 0 To DICT_LANG_COUNT - 1
            If LayoutList(LayoutIdx).LocaleCode <> DictLangCodes(LangIdx) Then Continue For
            Dim LangCode As String = DictLangCodes(LangIdx)
            DictLangList &= IIf(DictLangList = "", "", ", ") & LangCode
            MkDir TargetFolder & "\dict\" & LangCode
            Dim FileList As String = DictLangFiles(LangIdx) & "|"
            Dim BarPos As Long = InStr(FileList, "|")
            While BarPos > 0
                DictAddJob("dict\" & LangCode & "\" & Left(FileList, BarPos - 1), TargetFolder)
                FileList = Mid(FileList, BarPos + 1)
                BarPos = InStr(FileList, "|")
            Wend
        Next
    Next
    If DictJobCount = 0 Then Return 0
    DictNotifyWindow = NotifyWindow
    DictNotifyMessage = NotifyMessage
    Dim ThreadHandle As Any Ptr = LbCreateThread(0, 0, @DictThreadProc, 0, 0, 0)
    If ThreadHandle = 0 Then Return 0
    LbCloseHandle(ThreadHandle)
    DictRunning = 1
    Return DictJobCount
End Function

' Сообщение для пользователя по итогам потока (DictNotifyMessage пришло)
Function DictDownloadResult() As String
    DictRunning = 0
    If DictFailedIdx < 0 Then Return ""
    Return "Не скачался файл " & DictJobs(DictFailedIdx).SourceUrl & Chr(13, 10) _
        & "(ошибка 0x" & Hex(DictFailedCode) & ")."
End Function

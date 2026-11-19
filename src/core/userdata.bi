' ---------------------------------------------------------------------------
'  userdata.bi - папка данных пользователя в репозитории.
'
'  Если рядом с exe, на один или на два уровня выше есть папка userdata
'  (exe собран в bin, src или src\bin репозитория LangBarFB), слова пользователя (user_dict.dic)
'  и правила переключения (rules.ini) хранятся в ней, а не рядом с exe.
'  Папка лежит в git: правки сохраняются коммитом (save_userdata.bat) и не
'  пропадают при пересборке, сбросе настроек или запуске exe из другой
'  папки. Без папки userdata (установленная программа) всё как раньше -
'  рядом с exe.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

Const USERDATA_FOLDER_NAME = "userdata"
Const USERDATA_ATTR_DIRECTORY = &h10

Private Function UserDataIsFolder(ByRef FolderPath As String) As Long
    Dim FileAttr As ULong = LbGetFileAttributes(StrPtr(FolderPath))
    If FileAttr = LB_INVALID_FILE_ATTRIBUTES Then Return 0
    Return IIf((FileAttr And USERDATA_ATTR_DIRECTORY) <> 0, 1, 0)
End Function

' Папка userdata рядом с exe, на один или на два уровня выше (bin, src,
' src\bin репозитория); "" - её нет
Function UserDataFolder() As String
    Dim LevelPrefix(0 To 2) As String = {"\", "\..\", "\..\..\"}
    Dim LevelIdx As Long
    For LevelIdx = 0 To 2
        Dim FolderPath As String = ExePath & LevelPrefix(LevelIdx) & USERDATA_FOLDER_NAME
        If UserDataIsFolder(FolderPath) Then Return FolderPath
    Next
    Return ""
End Function

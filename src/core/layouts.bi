' ---------------------------------------------------------------------------
'  layouts.bi - раскладки: список, раскладка активного окна, смена.
'
'  Список - GetKeyboardLayoutList, в порядке Windows. Для каждой раскладки
'  код вида ru-RU (имя файла флажка, как flags\ru-RU.png у LangBarXX) и
'  короткая подпись для текстового флажка (код страны: RU, US, UA).
'  Раскладка консоли и окон UWP этим способом читается неверно - их разбор
'  (LangBarXX, Lib/InputLayout.ahk) не перенесён.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "winapi.bi"

Const MAX_LAYOUTS = 16

Type LayoutEntry
    LayoutHandle As UInteger
    LanguageId As ULong
    LocaleCode As String     ' ru-RU
    ShortLabel As String     ' RU
    LanguageName As String   ' название языка в языке Windows (CP1251)
    FlagColor As ULong       ' &hRRGGBB текстового флажка
End Type

Type LayoutInfo
    WindowHandle As Any Ptr
    WindowClass As String
    LayoutHandle As UInteger
    LanguageId As ULong
    LanguageCode As String
End Type

Dim Shared LayoutList(0 To MAX_LAYOUTS - 1) As LayoutEntry
Dim Shared LayoutCount As Long

' Цвета текстовых флажков по порядку раскладок - как default_colors LangBarXX
Dim Shared LayoutDefaultColors(0 To 7) As ULong = { _
    &h003FA5, &hBF003F, &h406300, &h994A03, &hC632A1, &h1B7785, &h444444, &h8201D8}

Private Function LocaleField(ByVal LanguageId As ULong, ByVal FieldType As ULong) As String
    Dim FieldBuffer As ZString * 16
    If LbGetLocaleInfo(LanguageId, FieldType, @FieldBuffer, 16) > 0 Then Return FieldBuffer
    Return ""
End Function

' Перечитывает список раскладок; возвращает их число
Function LayoutsLoad() As Long
    Dim HandleList(0 To MAX_LAYOUTS - 1) As Any Ptr
    LayoutCount = LbGetKeyboardLayoutList(MAX_LAYOUTS, @HandleList(0))
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        With LayoutList(LayoutIdx)
            .LayoutHandle = Cast(UInteger, HandleList(LayoutIdx))
            .LanguageId = .LayoutHandle And &hFFFF
            Dim LanguagePart As String = LocaleField(.LanguageId, LB_LOCALE_SISO639LANGNAME)
            Dim CountryPart As String = LocaleField(.LanguageId, LB_LOCALE_SISO3166CTRYNAME)
            If LanguagePart <> "" And CountryPart <> "" Then
                .LocaleCode = LanguagePart & "-" & CountryPart
                .ShortLabel = UCase(Left(CountryPart, 2))
            Else
                .LocaleCode = "0x" & Right("0000" & Hex(.LanguageId), 4)
                .ShortLabel = "??"
            End If
            .FlagColor = LayoutDefaultColors(LayoutIdx Mod 8)
            Dim NameBuffer As ZString * 80
            If LbGetLocaleInfo(.LanguageId, LB_LOCALE_SLANGUAGE, @NameBuffer, 80) > 0 Then
                .LanguageName = NameBuffer
            Else
                .LanguageName = .LocaleCode
            End If
        End With
    Next
    Return LayoutCount
End Function

' Номер раскладки по коду (ru-RU); -1 - такой нет
Function LayoutIndexOfCode(ByRef LocaleCode As String) As Long
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        If LCase(LayoutList(LayoutIdx).LocaleCode) = LCase(LocaleCode) Then Return LayoutIdx
    Next
    Return -1
End Function

' Номер раскладки в списке по HKL; -1 - нет в списке
Function LayoutIndexOf(ByVal LayoutHandle As UInteger) As Long
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To LayoutCount - 1
        If LayoutList(LayoutIdx).LayoutHandle = LayoutHandle Then Return LayoutIdx
    Next
    ' другая раскладка того же языка (например, после смены в настройках) -
    ' по коду языка
    For LayoutIdx = 0 To LayoutCount - 1
        If LayoutList(LayoutIdx).LanguageId = (LayoutHandle And &hFFFF) Then Return LayoutIdx
    Next
    Return -1
End Function

Function LayoutOfWindow(ByVal WindowHandle As Any Ptr) As LayoutInfo
    Dim Result As LayoutInfo
    Result.WindowHandle = WindowHandle
    If WindowHandle = 0 Then Return Result

    Dim ClassBuffer As ZString * 256
    LbGetClassName(WindowHandle, @ClassBuffer, 256)
    Result.WindowClass = ClassBuffer

    Dim ThreadId As ULong = LbGetWindowThreadProcessId(WindowHandle, 0)
    Result.LayoutHandle = Cast(UInteger, LbGetKeyboardLayout(ThreadId))
    Result.LanguageId = Result.LayoutHandle And &hFFFF

    Result.LanguageCode = LocaleField(Result.LanguageId, LB_LOCALE_SISO639LANGNAME)
    If Result.LanguageCode = "" Then Result.LanguageCode = "?"
    Return Result
End Function

Function LayoutOfForeground() As LayoutInfo
    Return LayoutOfWindow(LbGetForegroundWindow())
End Function

' Просит окно WindowHandle сменить раскладку на LayoutHandle
' (WM_INPUTLANGCHANGEREQUEST, как SetInputLayout у LangBarXX без клавиш).
' Сообщение уходит элементу с фокусом, а если его не узнать - самому окну.
Sub LayoutRequest(ByVal WindowHandle As Any Ptr, ByVal LayoutHandle As UInteger)
    If WindowHandle = 0 Then Exit Sub
    Dim TargetWindow As Any Ptr = WindowHandle
    Dim ThreadInfo As LbGuiThreadInfo
    ThreadInfo.cbSize = SizeOf(LbGuiThreadInfo)
    If LbGetGUIThreadInfo(LbGetWindowThreadProcessId(WindowHandle, 0), ThreadInfo) Then
        If ThreadInfo.hwndFocus <> 0 Then TargetWindow = ThreadInfo.hwndFocus
    End If
    LbPostMessage(TargetWindow, LB_WM_INPUTLANGCHANGEREQUEST, 0, Cast(Integer, LayoutHandle))
End Sub

' Раскладка, следующая (Shift = 1) или предыдущая (Shift = -1) после
' раскладки окна
Function LayoutShifted(ByVal WindowHandle As Any Ptr, ByVal Shift As Long) As UInteger
    If LayoutCount < 1 Then Return 0
    Dim CurrentIdx As Long = LayoutIndexOf(LayoutOfWindow(WindowHandle).LayoutHandle)
    If CurrentIdx < 0 Then CurrentIdx = 0
    Return LayoutList((CurrentIdx + Shift + LayoutCount) Mod LayoutCount).LayoutHandle
End Function

' Следующая раскладка по кругу после той, что сейчас у окна
Sub LayoutNext(ByVal WindowHandle As Any Ptr)
    If LayoutCount < 2 Then Exit Sub
    Dim Current As LayoutInfo = LayoutOfWindow(WindowHandle)
    Dim CurrentIdx As Long = LayoutIndexOf(Current.LayoutHandle)
    LayoutRequest(WindowHandle, LayoutList((CurrentIdx + 1) Mod LayoutCount).LayoutHandle)
End Sub

' Предыдущая раскладка по кругу
Sub LayoutPrev(ByVal WindowHandle As Any Ptr)
    If LayoutCount < 2 Then Exit Sub
    Dim Current As LayoutInfo = LayoutOfWindow(WindowHandle)
    Dim CurrentIdx As Long = LayoutIndexOf(Current.LayoutHandle)
    If CurrentIdx < 0 Then CurrentIdx = 0
    LayoutRequest(WindowHandle, LayoutList((CurrentIdx + LayoutCount - 1) Mod LayoutCount).LayoutHandle)
End Sub

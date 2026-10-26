' ---------------------------------------------------------------------------
'  LangBarFB - переключатель раскладки на FreeBASIC (перенос LangBarXX).
'
'  Сейчас (этап 1 и часть этапа 4):
'  - одна копия программы (мьютекс);
'  - значок в области уведомлений - флажок раскладки активного окна:
'    flags\<код>.png (ru-RU.png, en-US.png - как у LangBarXX), а если
'    файла нет - цветной прямоугольник с кодом страны;
'  - флажок у текстовой каретки (под ней; окна с системной кареткой) и крупный
'    флажок посреди экрана на 0,7 с при смене раскладки;
'  - щелчок по значку или флажку у каретки - следующая раскладка в окне,
'    где работали;
'  - меню значка (правый щелчок): настройки, автопереключение, звуки,
'    о программе, помощь, выход; с нажатым Shift - ещё «Окно отладки»;
'  - окно настроек: общие, горячие клавиши, звуки (langbarfb.ini);
'  - переключение с клавиатуры (этап 2): одиночные Shift/Ctrl, левый
'    Ctrl/Alt/Win + цифра, режимы Caps Lock, Num Lock при запуске;
'  - горячие клавиши (хук WH_KEYBOARD_LL глотает их нажатия): Break -
'    последнее слово в другой раскладке, Shift+Break - выделенный текст в
'    другой раскладке, Alt+Break - регистр, Alt+Scroll Lock - транслит;
'  - автопереключение (этап 5): слово перед пробелом проверяется по
'    словарям Hunspell LangBarXX и при ошибке раскладки перепечатывается.
'
'  Сборка: build.bat или unIDE (см. README.md). Только 32-битная: 64-битный
'  вариант не нужен (хуки LL, GetGUIThreadInfo, SendInput работают с окнами
'  любой разрядности).
' ---------------------------------------------------------------------------

#ifdef __FB_64BIT__
#error "LangBarFB собирается только 32-битным fbc (win32)"
#endif

#include once "dir.bi"
#include once "rqlcl.bi"
#include once "core/winapi.bi"
#include once "core/kbhook.bi"
#include once "core/layouts.bi"
#include once "core/caret.bi"
#include once "core/config.bi"
#include once "core/hotkeys.bi"
#include once "core/actions.bi"
#include once "core/switchkeys.bi"
#include once "core/autoswitch.bi"
#include once "core/dictload.bi"
#include once "ui/gfx.bi"
#include once "ui/tray.bi"
#include once "ui/overlay.bi"
#include once "ui/dlg_settings.bi"
#include once "ui/dlg_about.bi"

Const APP_TITLE = "LangBarFB"
Const MUTEX_NAME = "LangBarFB_SingleInstance"
Const HELP_URL = "https://github.com/diakin/LangBarFB#readme"
' сообщения служебному окну (tray.bi передаёт их в OnAppMessage)
Const KEY_EVENT_MSG = LB_WM_APP + 2
Const HOTKEY_ACTION_MSG = LB_WM_APP + 3
Const HOTKEY_CAPTURE_MSG = LB_WM_APP + 4
Const MOUSE_CLICK_MSG = LB_WM_APP + 5
Const SWITCH_SOLO_MSG = LB_WM_APP + 6
Const SWITCH_LAYOUT_MSG = LB_WM_APP + 7
Const DICT_DONE_MSG = LB_WM_APP + 8
' двойное нажатие одиночной клавиши - не дольше этого, секунды
Const DOUBLE_PRESS_SECONDS = 0.4
Const MAX_LOG_LINES = 300
Const LB_INFINITE = &hFFFFFFFF
' флажок у каретки: ширина и место. CARET_FLAG_BELOW = 1 - под кареткой
' (от её левого края), 0 - правее каретки в той же строке, по центру
' её высоты. Зазор - от каретки до флажка.
Const CARET_FLAG_WIDTH = 16
Const CARET_FLAG_BELOW = 1
Const CARET_FLAG_GAP = 2
' уведомление - значения по умолчанию LangBarXX ([LangNote] Note_Size,
' Note_Duration)
Const NOTE_SIZE_PERCENT = 8
Const NOTE_DURATION_MS = 700
' флажок у указателя мыши: ширина и сдвиг от острия стрелки - значения по
' умолчанию LangBarXX ([Cursor] Flag_Width, Flag_X, Flag_Y)
Const MOUSE_FLAG_WIDTH = 18
Const MOUSE_FLAG_DX = 4
Const MOUSE_FLAG_DY = 22

Dim Shared MainForm As QFORM
Dim Shared LayoutLabel As QLABEL
Dim Shared HookLabel As QLABEL
Dim Shared FlagsLabel As QLABEL
Dim Shared SpellLabel As QLABEL
Dim Shared EventList As QLISTBOX
Dim Shared ClearButton As QBUTTON
Dim Shared PollTimer As QTIMER
Dim Shared CaretTimer As QTIMER
Dim Shared NoteTimer As QTIMER
Dim Shared CaretFlag As OverlayWindow
Dim Shared NoteFlag As OverlayWindow
Dim Shared MouseFlag As OverlayWindow
Dim Shared MouseTimer As QTIMER
' быстрая перепроверка раскладки после нажатий и переключений: значок и
' флажки не ждут PollTimer (250 мс). QUICK_REFRESH_TICKS раз по
' QUICK_REFRESH_MS - окно меняет раскладку не мгновенно
Const QUICK_REFRESH_MS = 30
Const QUICK_REFRESH_TICKS = 6
Dim Shared QuickTimer As QTIMER
Dim Shared QuickTicksLeft As Long
Declare Sub StartQuickRefresh()
' раскладка во флажке у мыши, его место и до какого Timer его показывать
Dim Shared MouseFlagLayout As UInteger
Dim Shared MouseFlagPos As LbPoint
Dim Shared MouseFlagUntil As Double
' раскладка, нарисованная во флажке у каретки, и его место
Dim Shared CaretFlagLayout As UInteger
Dim Shared CaretFlagPos As LbPoint

Dim Shared ExitRequested As Long
' после выхода запустить себя снова (смена языка интерфейса)
Dim Shared RestartRequested As Long
' язык, с которым построены окна
Dim Shared LoadedLanguage As String
Dim Shared LastEventTick As Double
' окно, где пользователь работал последним (не панель задач и не наши окна):
' щелчок по значку меняет раскладку в нём
Dim Shared LastUserWindow As Any Ptr
Dim Shared ShownLayout As UInteger
Dim Shared ShownLayoutWindow As Any Ptr
Dim Shared FlagsFolder As String
Dim Shared FlagImages(0 To MAX_LAYOUTS - 1) As Any Ptr
' первая часть строки FlagsLabel (флажки); вторая - каретка, по таймеру
Dim Shared FlagsLabelText As String
' папка словарей из настроек, с которой они загружены
Dim Shared SpellLoadedFolder As String

Function HexByte(ByVal Value As ULong) As String
    Return Right("0" & Hex(Value), 2)
End Function

Function FolderExists(ByRef FolderPath As String) As Long
    Return IIf(Dir(FolderPath, fbDirectory) <> "", 1, 0)
End Function

' Папка флажков: flags рядом с exe или на уровень выше (exe в bin\ или src\,
' flags в корне проекта)
Function FindFlagsFolder() As String
    If FolderExists(ExePath & "\flags") Then Return ExePath & "\flags\"
    If FolderExists(ExePath & "\..\flags") Then Return ExePath & "\..\flags\"
    Return ""
End Function

Sub LoadFlags()
    Dim LayoutIdx As Long
    For LayoutIdx = 0 To MAX_LAYOUTS - 1
        GfxFreeImage(FlagImages(LayoutIdx))
    Next
    LayoutsLoad()
    FlagsFolder = FindFlagsFolder()
    Dim FoundCount As Long
    For LayoutIdx = 0 To LayoutCount - 1
        If FlagsFolder <> "" Then
            FlagImages(LayoutIdx) = GfxLoadImage(FlagsFolder & LayoutList(LayoutIdx).LocaleCode & ".png")
        End If
        If FlagImages(LayoutIdx) <> 0 Then FoundCount += 1
    Next
    If FlagsFolder = "" Then
        FlagsLabelText = "Флажки: папки flags нет - текстовые флажки. Раскладок: " & LayoutCount
    Else
        FlagsLabelText = "Флажки: " & FlagsFolder & " - найдено " & FoundCount & " из " & LayoutCount
    End If
    FlagsLabel.Caption = FlagsLabelText
End Sub

' Словари Hunspell - по одному на раскладку списка, поэтому загружаются
' после него (при запуске, при новой раскладке, при смене папки)
Sub LoadSpell()
    SpellLoad(Settings.SpellFolder)
    SpellLoadedFolder = Settings.SpellFolder
    SpellLabel.Caption = "Hunspell: " & SpellStatus
End Sub

Function IsOwnOrShellWindow(ByVal WindowHandle As Any Ptr) As Long
    If WindowHandle = 0 Then Return 1
    If WindowHandle = TrayWindow Then Return 1
    If WindowHandle = CaretFlag.WindowHandle Or WindowHandle = NoteFlag.WindowHandle Then Return 1
    If WindowHandle = MouseFlag.WindowHandle Then Return 1
    If WindowHandle = Cast(Any Ptr, MainForm.Handle) Then Return 1
    If WindowHandle = Cast(Any Ptr, SettingsForm.Handle) Then Return 1
    If WindowHandle = Cast(Any Ptr, CaptureForm.Handle) Then Return 1
    If WindowHandle = Cast(Any Ptr, AboutForm.Handle) Then Return 1
    Dim ClassBuffer As ZString * 64
    LbGetClassName(WindowHandle, @ClassBuffer, 64)
    Select Case ClassBuffer
    Case "Shell_TrayWnd", "NotifyIconOverflowWindow", "TopLevelWindowForOverflowXamlIsland"
        Return 1
    End Select
    Return 0
End Function

' Крупный флажок посреди основного экрана; через NOTE_DURATION_MS прячется.
' Мышь проходит сквозь него.
Sub ShowLayoutNote(ByVal LayoutIdx As Long)
    Dim NoteWidth As Long = LbGetSystemMetrics(LB_SM_CXSCREEN) * NOTE_SIZE_PERCENT \ 100
    Dim NoteImage As Any Ptr
    With LayoutList(LayoutIdx)
        NoteImage = GfxMakeFlagImage(FlagImages(LayoutIdx), .ShortLabel, .FlagColor, NoteWidth)
    End With
    If NoteImage = 0 Then Exit Sub
    Dim ImgHeight As ULong
    GdipGetImageHeight(NoteImage, ImgHeight)
    OverlayShowImage(NoteFlag, NoteImage, _
        (LbGetSystemMetrics(LB_SM_CXSCREEN) - NoteWidth) \ 2, _
        (LbGetSystemMetrics(LB_SM_CYSCREEN) - CLng(ImgHeight)) \ 2)
    GfxFreeImage(NoteImage)
    NoteTimer.Enabled = 0
    NoteTimer.Enabled = 1
End Sub

Sub OnNoteTimer()
    NoteTimer.Enabled = 0
    OverlayHide(NoteFlag)
End Sub

' Флажок у каретки активного окна: раз в 50 мс. Нет каретки, активна
' панель задач или наше окно - флажок прячется.
Sub OnCaretTimer()
    Dim ForegroundWindow As Any Ptr = LbGetForegroundWindow()
    Dim CaretPos As LbPoint, CaretHeight As Long
    If Settings.CaretFlag = 0 Or IsOwnOrShellWindow(ForegroundWindow) Or _
            CaretOfWindow(ForegroundWindow, CaretPos, CaretHeight) = 0 Then
        If OverlayVisible(CaretFlag) Then OverlayHide(CaretFlag)
        Exit Sub
    End If
    Dim NewPos As LbPoint
    If CARET_FLAG_BELOW Then
        NewPos.PosX = CaretPos.PosX
        NewPos.PosY = CaretPos.PosY + CaretHeight + CARET_FLAG_GAP
    Else
        ' высота флажка 3:4 от ширины; у картинки другой пропорции
        ' центр сместится на пару точек
        NewPos.PosX = CaretPos.PosX + CARET_FLAG_GAP + 1
        NewPos.PosY = CaretPos.PosY + (CaretHeight - CARET_FLAG_WIDTH * 3 \ 4) \ 2
    End If

    Dim Current As LayoutInfo = LayoutOfWindow(ForegroundWindow)
    If Current.LayoutHandle <> CaretFlagLayout Or OverlayVisible(CaretFlag) = 0 Then
        Dim LayoutIdx As Long = LayoutIndexOf(Current.LayoutHandle)
        If LayoutIdx < 0 Then Exit Sub
        Dim FlagImage As Any Ptr
        With LayoutList(LayoutIdx)
            FlagImage = GfxMakeFlagImage(FlagImages(LayoutIdx), .ShortLabel, .FlagColor, CARET_FLAG_WIDTH)
        End With
        If FlagImage = 0 Then Exit Sub
        OverlayShowImage(CaretFlag, FlagImage, NewPos.PosX, NewPos.PosY)
        GfxFreeImage(FlagImage)
        CaretFlagLayout = Current.LayoutHandle
        CaretFlagPos = NewPos
    ElseIf NewPos.PosX <> CaretFlagPos.PosX Or NewPos.PosY <> CaretFlagPos.PosY Then
        OverlayMove(CaretFlag, NewPos.PosX, NewPos.PosY)
        CaretFlagPos = NewPos
    End If
End Sub

' Флажок у указателя мыши: раскладка значка в трее. Таймер идёт, пока
' флажок нужен: всегда или MOUSE_FLAG_SHOW_MS после смены раскладки.
' Мышь проходит сквозь флажок.
Sub OnMouseTimer()
    Dim CursorInfo As LbCursorInfo
    CursorInfo.cbSize = SizeOf(LbCursorInfo)
    Dim NeedFlag As Long = 1
    Select Case Settings.MouseFlag
    Case MOUSE_FLAG_OFF
        NeedFlag = 0
    Case MOUSE_FLAG_ON_CHANGE
        If Timer > MouseFlagUntil Then NeedFlag = 0
    End Select
    If NeedFlag = 0 Then
        MouseTimer.Enabled = 0
        If OverlayVisible(MouseFlag) Then OverlayHide(MouseFlag)
        Exit Sub
    End If
    ' указатель скрыт (программа прячет его при наборе) - флажок тоже
    If LbGetCursorInfo(CursorInfo) = 0 Or (CursorInfo.flags And LB_CURSOR_SHOWING) = 0 Or ShownLayout = 0 Then
        If OverlayVisible(MouseFlag) Then OverlayHide(MouseFlag)
        Exit Sub
    End If
    Dim NewPos As LbPoint
    NewPos.PosX = CursorInfo.ptScreenPos.PosX + MOUSE_FLAG_DX
    NewPos.PosY = CursorInfo.ptScreenPos.PosY + MOUSE_FLAG_DY
    If ShownLayout <> MouseFlagLayout Or OverlayVisible(MouseFlag) = 0 Then
        Dim LayoutIdx As Long = LayoutIndexOf(ShownLayout)
        If LayoutIdx < 0 Then Exit Sub
        Dim FlagImage As Any Ptr
        With LayoutList(LayoutIdx)
            FlagImage = GfxMakeFlagImage(FlagImages(LayoutIdx), .ShortLabel, .FlagColor, MOUSE_FLAG_WIDTH)
        End With
        If FlagImage = 0 Then Exit Sub
        OverlayShowImage(MouseFlag, FlagImage, NewPos.PosX, NewPos.PosY)
        GfxFreeImage(FlagImage)
        MouseFlagLayout = ShownLayout
        MouseFlagPos = NewPos
    ElseIf NewPos.PosX <> MouseFlagPos.PosX Or NewPos.PosY <> MouseFlagPos.PosY Then
        OverlayMove(MouseFlag, NewPos.PosX, NewPos.PosY)
        MouseFlagPos = NewPos
    End If
End Sub

' Раскладка сменилась или поменялись настройки - флажок у мыши показать
Sub StartMouseFlag()
    If Settings.MouseFlag = MOUSE_FLAG_OFF Then
        OnMouseTimer()
        Exit Sub
    End If
    MouseFlagUntil = Timer + MOUSE_FLAG_SHOW_MS / 1000
    MouseTimer.Enabled = 1
    OnMouseTimer()
End Sub

' Флажок не активируется, поэтому активным остаётся окно с кареткой
Function IsClickOnCaretFlag() As Long
    If OverlayVisible(CaretFlag) = 0 Then Return 0
    With KbLastClickPos
        Return IIf(.PosX >= CaretFlagPos.PosX And .PosX < CaretFlagPos.PosX + CaretFlag.ImageWidth _
            And .PosY >= CaretFlagPos.PosY And .PosY < CaretFlagPos.PosY + CaretFlag.ImageHeight, 1, 0)
    End With
End Function

' Правый щелчок по флажку у каретки - как Break (ПКМ по флажку у LangBarXX)
Sub OnCaretFlagRightClick()
    RunHotkeyAction(ACTION_UNDO_CONVERT)
End Sub

Sub OnCaretFlagClick()
    Dim ForegroundWindow As Any Ptr = LbGetForegroundWindow()
    If IsOwnOrShellWindow(ForegroundWindow) Then ForegroundWindow = LastUserWindow
    LayoutNext(ForegroundWindow)
End Sub

' Значок трея - флажок раскладки LayoutHandle окна WindowHandle
Sub ShowLayoutInTray(ByVal LayoutHandle As UInteger, ByVal WindowHandle As Any Ptr)
    Dim LayoutIdx As Long = LayoutIndexOf(LayoutHandle)
    If LayoutIdx < 0 Then
        ' раскладку добавили в Windows после запуска
        LoadFlags()
        LoadSpell()
        LayoutIdx = LayoutIndexOf(LayoutHandle)
        If LayoutIdx < 0 Then Exit Sub
    End If
    Dim IconSize As Long = LbGetSystemMetrics(LB_SM_CXSMICON)
    If IconSize < 16 Then IconSize = 16
    With LayoutList(LayoutIdx)
        TraySetIcon(GfxMakeFlagIcon(FlagImages(LayoutIdx), .ShortLabel, .FlagColor, IconSize))
        TraySetTip(APP_TITLE & ": " & .LocaleCode)
    End With
    ' уведомление - только когда раскладку сменили в том же окне; при
    ' запуске и при переходе в окно с другой раскладкой его нет
    If ShownLayout <> 0 And WindowHandle = ShownLayoutWindow Then ShowLayoutNote(LayoutIdx)
    Dim LayoutChanged As Long = IIf(ShownLayout <> 0 And LayoutHandle <> ShownLayout, 1, 0)
    ShownLayout = LayoutHandle
    ShownLayoutWindow = WindowHandle
    If LayoutChanged Then StartMouseFlag()
End Sub

Function DescribeEvent(ByRef KeyEvent As KbEvent) As String
    Dim Direction As String = IIf(KeyEvent.IsKeyUp, "отпущена", "нажата  ")
    Dim LineText As String = Time & "  " & Direction & "  vk=" & HexByte(KeyEvent.VirtualKey) _
        & "  sc=" & HexByte(KeyEvent.ScanCode)
    If (KeyEvent.KeyFlags And LB_LLKHF_EXTENDED) <> 0 Then LineText &= "  ext"
    If (KeyEvent.KeyFlags And LB_LLKHF_ALTDOWN) <> 0 Then LineText &= "  alt"
    If KeyEvent.IsInjected Then LineText &= "  программная"
    If KeyEvent.IsSwallowed Then LineText &= "  проглочена (сочетание)"
    If KeyEvent.Modifiers <> 0 Then LineText &= "  mods=" & KeyEvent.Modifiers
    If KeyEvent.HeldMask <> 0 Then LineText &= "  held=" & Hex(KeyEvent.HeldMask)
    ' раскладка активного окна на момент разбора события
    Dim Current As LayoutInfo = LayoutOfForeground()
    Dim LayoutIdx As Long = LayoutIndexOf(Current.LayoutHandle)
    If LayoutIdx >= 0 Then LineText &= "  [" & LayoutList(LayoutIdx).LocaleCode & "]"
    Return LineText
End Function

' Сигнал хука: разбираем всё, что накопилось в буфере
Sub OnKeyEvents()
    Dim KeyEvent As KbEvent
    Dim AddedCount As Long
    While KbHookTakeEvent(KeyEvent)
        WordBufferFeed(KeyEvent)
        ' список ведётся, только пока окно отладки открыто
        If MainForm.Visible Then
            EventList.AddItems(DescribeEvent(KeyEvent))
            AddedCount += 1
        End If
    Wend
    LastEventTick = Timer
    If AddedCount > 0 Then
        While EventList.ItemCount > MAX_LOG_LINES
            EventList.DelItems(0)
        Wend
        EventList.ItemIndex = EventList.ItemCount - 1
    End If
    ' автопереключение: начало слова (третья буква) и слово перед пробелом
    If WordLetterFed Then
        WordLetterFed = 0
        AutoSwitchStart()
    End If
    If WordSpaceFed Then
        WordSpaceFed = 0
        AutoSwitchWord()
    End If
    StartQuickRefresh()
End Sub

' Окно, где менять раскладку: активное, а если активно наше окно или
' панель задач - то, где работали до них
Function SwitchTargetWindow() As Any Ptr
    Dim ForegroundWindow As Any Ptr = LbGetForegroundWindow()
    If IsOwnOrShellWindow(ForegroundWindow) Then Return LastUserWindow
    Return ForegroundWindow
End Function

' Строка в окне отладки (пока оно открыто)
Sub DebugLog(ByRef LineText As String)
    If MainForm.Visible = 0 Then Exit Sub
    EventList.AddItems(Time & "  " & LineText)
    EventList.ItemIndex = EventList.ItemCount - 1
End Sub

' Смена раскладки с клавиатуры: с проверкой и записью в окно отладки
Sub SwitchFromKeyboard(ByRef Reason As String, ByVal TargetWindow As Any Ptr, ByVal LayoutHandle As UInteger)
    Static SwitchBusy As Long
    If SwitchBusy Or LayoutHandle = 0 Then Exit Sub
    SwitchBusy = 1
    ' 30 мс - чтобы окно успело получить отпускание клавиши
    Dim SwitchResult As Long = LayoutSwitchChecked(TargetWindow, LayoutHandle, 30)
    StartQuickRefresh()
    Dim TargetIdx As Long = LayoutIndexOf(LayoutHandle)
    Dim TargetCode As String = IIf(TargetIdx >= 0, LayoutList(TargetIdx).LocaleCode, Hex(LayoutHandle))
    Dim ResultText As String
    Select Case SwitchResult
    Case 1
        ResultText = "сменилась"
    Case 2
        ResultText = "сменилась со второго запроса (окну)"
    Case Else
        ResultText = "НЕ сменилась, у окна " & Hex(LayoutOfWindow(TargetWindow).LayoutHandle)
    End Select
    DebugLog(Reason & " -> " & TargetCode & ": " & ResultText & ", класс окна " & LayoutOfWindow(TargetWindow).WindowClass)
    SwitchBusy = 0
End Sub

' Одиночный Shift или Ctrl отпущен
Sub OnSoloKey(ByVal KeyIdx As Long)
    Static LastKeyIdx As Long = -1
    Static LastPressTime As Double
    If KeyIdx < 0 Or KeyIdx >= SOLO_KEY_COUNT Then Exit Sub
    If Settings.DoublePress Then
        If KeyIdx <> LastKeyIdx Or Timer - LastPressTime > DOUBLE_PRESS_SECONDS Then
            LastKeyIdx = KeyIdx
            LastPressTime = Timer
            DebugLog(SoloKeyTitles(KeyIdx) & ": первое нажатие, ждём второе")
            Exit Sub
        End If
        LastKeyIdx = -1
    End If
    Dim TargetWindow As Any Ptr = SwitchTargetWindow()
    Dim KeyAction As String = Settings.SoloKeyAction(KeyIdx)
    Dim LayoutHandle As UInteger
    Select Case KeyAction
    Case "next"
        LayoutHandle = LayoutShifted(TargetWindow, 1)
    Case "prev"
        LayoutHandle = LayoutShifted(TargetWindow, -1)
    Case Else
        Dim LayoutIdx As Long = LayoutIndexOfCode(KeyAction)
        If LayoutIdx >= 0 Then LayoutHandle = LayoutList(LayoutIdx).LayoutHandle
    End Select
    SwitchFromKeyboard(SoloKeyTitles(KeyIdx) & " (" & KeyAction & ")", TargetWindow, LayoutHandle)
End Sub

' Раскладка по номеру (левый Ctrl/Alt/Win + цифра) или следующая (Caps Lock)
Sub OnSwitchLayout(ByVal LayoutIdx As Long)
    ' после проглоченной цифры отпущенный Alt или Win открыл бы меню
    If LayoutIdx >= 0 And Settings.LangSelect >= 2 Then SendKeyTap(LB_VK_MENU_MASK)
    Dim TargetWindow As Any Ptr = SwitchTargetWindow()
    If LayoutIdx < 0 Then
        SwitchFromKeyboard("Caps Lock", TargetWindow, LayoutShifted(TargetWindow, 1))
    ElseIf LayoutIdx < LayoutCount Then
        SwitchFromKeyboard("Раскладка номер " & (LayoutIdx + 1), TargetWindow, LayoutList(LayoutIdx).LayoutHandle)
    End If
End Sub

' --- словари ---

' Скачать библиотеку Hunspell и словари раскладок в папку exe
Sub StartDictDownload()
    Dim FileCount As Long = DictDownloadStart(ExePath, TrayWindow, DICT_DONE_MSG)
    Select Case FileCount
    Case -1
        LbMessageBox(0, Tr("Словари уже скачиваются."), APP_TITLE, LB_MB_ICONINFORMATION)
    Case 0
        LoadSpell()
        If SpellDictCount > 0 Then
            LbMessageBox(0, Tr("Скачивать нечего: ") & SpellStatus & ".", APP_TITLE, LB_MB_ICONINFORMATION)
        Else
            LbMessageBox(0, Tr("Для раскладок Windows нет словарей в LangBarFB.") & Chr(13, 10) _
                & Tr("Словари других языков: меню «Словари других языков...»."), APP_TITLE, LB_MB_ICONINFORMATION)
        End If
    Case Else
        DebugLog("скачивание словарей: " & FileCount & " файлов, языки " & DictLangList)
    End Select
End Sub

' Поток скачивания закончил
Sub OnDictDone()
    Dim FailedCount As Long
    Dim ResultText As String = DictDownloadResult(FailedCount)
    LoadSpell()
    DebugLog("скачивание словарей: " & ResultText & "Hunspell: " & SpellStatus)
    If FailedCount > 0 Then
        LbMessageBox(0, ResultText & Chr(13, 10) & "Hunspell: " & SpellStatus & "." & Chr(13, 10) & Chr(13, 10) _
            & Tr("Папки hunspell и dict можно скачать вручную: ") & DICT_PAGE_URL & Chr(13, 10) _
            & Tr("и положить рядом с программой (") & ExePath & ").", APP_TITLE, LB_MB_ICONWARNING)
    Else
        LbMessageBox(0, ResultText & Chr(13, 10) & "Hunspell: " & SpellStatus & ".", APP_TITLE, LB_MB_ICONINFORMATION)
    End If
End Sub

' Словарей нет - предложить скачать. 1 - пользователь согласился.
Function AskDictDownload() As Long
    Dim Answer As Long = LbMessageBox(0, Tr("Для автопереключения нужны словари Hunspell (") & SpellStatus & ")." _
        & Chr(13, 10) & Tr("Скачать их сейчас? Это несколько мегабайт, только языки ваших раскладок."), _
        APP_TITLE, LB_MB_YESNO Or LB_MB_ICONQUESTION)
    If Answer <> LB_IDYES Then Return 0
    StartDictDownload()
    Return 1
End Function

Sub OnAppMessage(ByVal Msg As ULong, ByVal WParam As UInteger)
    Select Case Msg
    Case KEY_EVENT_MSG
        OnKeyEvents()
    Case HOTKEY_ACTION_MSG
        ' нажатия, пришедшие до сочетания, должны попасть в буфер слова
        OnKeyEvents()
        RunHotkeyAction(CLng(WParam))
        StartQuickRefresh()
    Case HOTKEY_CAPTURE_MSG
        SettingsCaptureDone()
    Case SWITCH_SOLO_MSG
        OnKeyEvents()
        DebugLog("одиночная клавиша: " & SoloKeyTitles(CLng(WParam) And 3))
        OnSoloKey(CLng(WParam))
    Case SWITCH_LAYOUT_MSG
        OnSwitchLayout(CLng(Cast(Integer, WParam)))
    Case DICT_DONE_MSG
        OnDictDone()
    Case MOUSE_CLICK_MSG
        ' каретка могла уйти - набранное слово больше не перед ней. Щелчок
        ' по флажку у каретки каретку не двигает (правый - исправляет слово)
        If IsClickOnCaretFlag() = 0 Then WordBufferReset()
    End Select
End Sub

Sub OnPollTimer()
    Dim ForegroundWindow As Any Ptr = LbGetForegroundWindow()
    If IsOwnOrShellWindow(ForegroundWindow) = 0 Then LastUserWindow = ForegroundWindow

    ' флажок - раскладка окна, где работают; пока открыто меню значка
    ' или окно отладки - раскладка того окна, что было до них
    Dim Current As LayoutInfo = LayoutOfWindow(LastUserWindow)
    If Current.LayoutHandle <> 0 And _
            (Current.LayoutHandle <> ShownLayout Or LastUserWindow <> ShownLayoutWindow) Then
        ShowLayoutInTray(Current.LayoutHandle, LastUserWindow)
    End If

    If MainForm.Visible = 0 Then Exit Sub
    LayoutLabel.Caption = "Раскладка окна: " & Current.LanguageCode _
        & " (0x" & Right("0000" & Hex(Current.LanguageId), 4) & "), класс окна: " & Current.WindowClass
    Dim HookState As String = IIf(KbHookHandle <> 0, "хук стоит", "хука нет")
    Dim SinceLast As String = "-"
    If LastEventTick > 0 Then SinceLast = Str(Int((Timer - LastEventTick) * 10) / 10) & " с назад"
    HookLabel.Caption = HookState & ";  вызовов: " & KbHookCalls _
        & ";  в обработчике: среднее " & KbHookAverageMicros() & " мкс, наибольшее " & KbMaxHookMicros & " мкс" _
        & ";  потеряно: " & KbLostEvents & ";  последнее нажатие: " & SinceLast
    FlagsLabel.Caption = FlagsLabelText & ";  " & CaretDebugText
End Sub

' Раскладку, значок и флажки - сразу и ещё несколько раз подряд
Sub OnQuickTimer()
    OnPollTimer()
    OnCaretTimer()
    QuickTicksLeft -= 1
    If QuickTicksLeft <= 0 Then QuickTimer.Enabled = 0
End Sub

Sub StartQuickRefresh()
    QuickTicksLeft = QUICK_REFRESH_TICKS
    OnPollTimer()
    OnCaretTimer()
    QuickTimer.Enabled = 1
End Sub

Sub OnClearClick()
    EventList.Clear
End Sub

Sub OnTrayClick()
    LayoutNext(LastUserWindow)
    ' Windows может не дать окну активироваться обратно после щелчка по
    ' значку; раскладку окно получит и без этого
    LbSetForegroundWindow(LastUserWindow)
End Sub

Sub OnTrayShow()
    MainForm.WindowState = 0
    MainForm.Show
    LbSetForegroundWindow(Cast(Any Ptr, MainForm.Handle))
End Sub

Sub OnTrayExit()
    ExitRequested = 1
    LbPostMessage(TrayWindow, LB_WM_NULL, 0, 0)
End Sub

' Настройки поменялись (окно настроек, меню значка)
Sub ApplySettings()
    ConfigApplyAutoStart(Settings.AutoStart)
    HotkeysLoadTable()
    SwitchLoadTable()
    SwitchFixLockKeys()
    If Settings.CaretFlag = 0 Then OverlayHide(CaretFlag)
    StartMouseFlag()
    If Settings.SpellFolder <> SpellLoadedFolder Then LoadSpell()
    SpellLabel.Caption = "Hunspell: " & SpellStatus
    If Settings.Language <> LoadedLanguage Then
        ' вопрос - на языке, который выбрали
        LangSet(Settings.Language)
        Dim Answer As Long = LbMessageBox(0, Tr("Язык интерфейса сменится после перезапуска. Перезапустить LangBarFB сейчас?"), _
            APP_TITLE, LB_MB_YESNO Or LB_MB_ICONQUESTION)
        LangSet(LoadedLanguage)
        If Answer = LB_IDYES Then
            RestartRequested = 1
            If SettingsOpen Then SettingsForm.Close
            OnTrayExit()
        End If
    End If
End Sub

' Справка: help\langbarfb.<язык>.html рядом с exe или на уровень выше,
' иначе README на GitHub
Sub ShowHelp()
    Dim HelpName As String = "help\langbarfb." & LoadedLanguage & ".html"
    Dim HelpPath As String
    If FileExists(ExePath & "\" & HelpName) Then
        HelpPath = ExePath & "\" & HelpName
    ElseIf FileExists(ExePath & "\..\" & HelpName) Then
        HelpPath = ExePath & "\..\" & HelpName
    Else
        HelpPath = HELP_URL
    End If
    LbShellExecute(0, "open", HelpPath, 0, 0, LB_SW_SHOWNORMAL)
End Sub

' --- меню значка (правый щелчок) ---
Const CMD_SETTINGS = 101
Const CMD_AUTOSWITCH = 102
Const CMD_SOUNDS = 103
Const CMD_ABOUT = 104
Const CMD_HELP = 105
Const CMD_EXIT = 106
Const CMD_DEBUG_WINDOW = 107
Const CMD_DICT_DOWNLOAD = 108
Const CMD_DICT_MORE = 109
Const CMD_RESET = 110

Private Function CheckedFlag(ByVal IsOn As Long) As ULong
    Return IIf(IsOn, LB_MF_CHECKED, 0)
End Function

Function BuildTrayMenu() As Any Ptr
    Dim MainMenu As Any Ptr = LbCreatePopupMenu()
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_SETTINGS, Tr("Настройки..."))
    LbAppendMenu(MainMenu, LB_MF_SEPARATOR, 0, 0)
    LbAppendMenu(MainMenu, LB_MF_STRING Or CheckedFlag(Settings.AutoSwitch), CMD_AUTOSWITCH, Tr("Автопереключение"))
    LbAppendMenu(MainMenu, LB_MF_STRING Or CheckedFlag(Settings.SoundsOn), CMD_SOUNDS, Tr("Звуковые эффекты"))
    LbAppendMenu(MainMenu, LB_MF_SEPARATOR, 0, 0)
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_DICT_DOWNLOAD, Tr("Скачать словари"))
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_DICT_MORE, Tr("Словари других языков..."))
    LbAppendMenu(MainMenu, LB_MF_SEPARATOR, 0, 0)
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_RESET, Tr("Сброс настроек..."))
    LbAppendMenu(MainMenu, LB_MF_SEPARATOR, 0, 0)
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_ABOUT, Tr("О LangBarFB"))
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_HELP, Tr("Помощь"))
    ' окно отладки - только если меню открыли с нажатым Shift
    If (LbGetAsyncKeyState(LB_VK_SHIFT) And &h8000) <> 0 Then
        LbAppendMenu(MainMenu, LB_MF_STRING, CMD_DEBUG_WINDOW, Tr("Окно отладки"))
    End If
    LbAppendMenu(MainMenu, LB_MF_SEPARATOR, 0, 0)
    LbAppendMenu(MainMenu, LB_MF_STRING, CMD_EXIT, Tr("Выход"))
    ' пункт по умолчанию Windows рисует жирным
    LbSetMenuDefaultItem(MainMenu, CMD_SETTINGS, 0)
    Return MainMenu
End Function

Sub OnTrayCommand(ByVal CommandId As Long)
    Select Case CommandId
    Case CMD_SETTINGS
        SettingsShow()
    Case CMD_AUTOSWITCH
        Settings.AutoSwitch Xor= 1
        ConfigSave()
        If Settings.AutoSwitch And SpellDictCount = 0 Then AskDictDownload()
    Case CMD_DICT_DOWNLOAD
        StartDictDownload()
    Case CMD_DICT_MORE
        LbShellExecute(0, "open", DICT_MORE_URL, 0, 0, LB_SW_SHOWNORMAL)
    Case CMD_SOUNDS
        Settings.SoundsOn Xor= 1
        ConfigSave()
    Case CMD_ABOUT
        AboutShow()
    Case CMD_HELP
        ShowHelp()
    Case CMD_RESET
        SettingsResetAsk()
    Case CMD_DEBUG_WINDOW
        OnTrayShow()
    Case CMD_EXIT
        OnTrayExit()
    End Select
End Sub

' --- настройки и язык: сообщения ниже уже на выбранном языке ---
ConfigLoad()
LoadedLanguage = Settings.Language
LangSet(LoadedLanguage)

' --- одна копия. С ключом /restart (перезапуск после смены языка) прежняя
' копия ещё завершается - ждём её до 5 с ---
Dim Shared InstanceMutex As Any Ptr
Dim MutexRetries As Long
Do
    InstanceMutex = LbCreateMutex(0, 0, MUTEX_NAME)
    If LbGetLastError() <> LB_ERROR_ALREADY_EXISTS Then Exit Do
    LbCloseHandle(InstanceMutex)
    If InStr(LCase(Command()), "/restart") = 0 Or MutexRetries >= 50 Then
        LbMessageBox(0, Tr("LangBarFB уже запущен."), APP_TITLE, LB_MB_ICONINFORMATION)
        End 0
    End If
    MutexRetries += 1
    Sleep 100
Loop

' --- окно отладки (закрытие прячет его; программа остаётся в трее) ---
MainForm.Caption = APP_TITLE & " - отладка"
MainForm.Width = 720
MainForm.Height = 480
MainForm.Center

LayoutLabel.Parent = MainForm
LayoutLabel.Left = 8 : LayoutLabel.Top = 8
LayoutLabel.Caption = "Раскладка окна: ..."

HookLabel.Parent = MainForm
HookLabel.Left = 8 : HookLabel.Top = 30
HookLabel.Caption = "..."

FlagsLabel.Parent = MainForm
FlagsLabel.Left = 8 : FlagsLabel.Top = 52
FlagsLabel.Caption = "..."

SpellLabel.Parent = MainForm
SpellLabel.Left = 116 : SpellLabel.Top = 80
SpellLabel.Caption = "Hunspell: ..."

ClearButton.Parent = MainForm
ClearButton.Left = 8 : ClearButton.Top = 76 : ClearButton.Width = 100
ClearButton.Caption = "Очистить"
ClearButton.OnClick = @OnClearClick

EventList.Parent = MainForm
EventList.Left = 8 : EventList.Top = 110
EventList.Width = MainForm.ClientWidth - 16
EventList.Height = MainForm.ClientHeight - 118

' --- настройки ---
' путь в автозапуске - к этому exe (программу могли перенести)
If Settings.AutoStart Then ConfigApplyAutoStart(1)
SettingsCreate()
AboutCreate()
SettingsOnApply = @ApplySettings
ActionLog = @DebugLog

' --- значок, флажки, хук ---
If GfxStart() = 0 Then
    LbMessageBox(0, Tr("Не удалось запустить GDI+: флажков не будет."), APP_TITLE, 0)
End If
LoadFlags()
LoadSpell()

TrayBuildMenu = @BuildTrayMenu
TrayOnCommand = @OnTrayCommand
TrayOnClick = @OnTrayClick
TrayOnClose = @OnTrayExit
TrayOnAppMessage = @OnAppMessage
If TrayCreate(APP_TITLE) = 0 Then
    LbMessageBox(0, Tr("Не удалось создать значок в области уведомлений."), APP_TITLE, 0)
End If
LastUserWindow = LbGetForegroundWindow()
If IsOwnOrShellWindow(LastUserWindow) Then LastUserWindow = 0
OnPollTimer()

If KbHookInstall(TrayWindow, KEY_EVENT_MSG) = 0 Then
    LbMessageBox(0, Tr("Не удалось поставить хук клавиатуры (ошибка ") & LbGetLastError() & ").", APP_TITLE, 0)
End If
HotkeysStart(TrayWindow, HOTKEY_ACTION_MSG, HOTKEY_CAPTURE_MSG)
' общий фильтр хука (горячие клавиши и переключение) ставит SwitchStart
SwitchStart(SWITCH_SOLO_MSG, SWITCH_LAYOUT_MSG)
KbMouseHookInstall(MOUSE_CLICK_MSG)

PollTimer.Interval = 250
PollTimer.OnTimer = @OnPollTimer

CaretFlag.OnClick = @OnCaretFlagClick
CaretFlag.OnRightClick = @OnCaretFlagRightClick
OverlayCreate(CaretFlag, 0)
OverlayCreate(NoteFlag, 1)
OverlayCreate(MouseFlag, 1)
MouseTimer.Enabled = 0
MouseTimer.Interval = 15
MouseTimer.OnTimer = @OnMouseTimer
If Settings.MouseFlag = MOUSE_FLAG_ALWAYS Then StartMouseFlag()
NoteTimer.Enabled = 0
NoteTimer.Interval = NOTE_DURATION_MS
NoteTimer.OnTimer = @OnNoteTimer
CaretTimer.Interval = 50
QuickTimer.Enabled = 0
QuickTimer.Interval = QUICK_REFRESH_MS
QuickTimer.OnTimer = @OnQuickTimer
CaretTimer.OnTimer = @OnCaretTimer

' первый запуск без словарей - предложить их скачать (один раз)
If SpellDictCount = 0 And Settings.DictAsked = 0 Then
    Settings.DictAsked = 1
    ConfigSave()
    AskDictDownload()
End If

' --- цикл сообщений: окно не нужно, программа живёт в трее ---
' DoEvents (Application.ProcessMessages) разбирает всё, что пришло, в том
' числе вызовы хука; MsgWaitForMultipleObjects ждёт следующего сообщения
Do
    DoEvents
    If ExitRequested Then Exit Do
    LbMsgWaitForMultipleObjects(0, 0, 0, LB_INFINITE, LB_QS_ALLINPUT)
Loop

PollTimer.Enabled = 0
CaretTimer.Enabled = 0
NoteTimer.Enabled = 0
OverlayDestroy(CaretFlag)
OverlayDestroy(NoteFlag)
MouseTimer.Enabled = 0
QuickTimer.Enabled = 0
OverlayDestroy(MouseFlag)
KbMouseHookRemove()
KbHookRemove()
TrayDestroy()
Dim FlagIdx As Long
For FlagIdx = 0 To MAX_LAYOUTS - 1
    GfxFreeImage(FlagImages(FlagIdx))
Next
GfxStop()
MainForm.Close
LbCloseHandle(InstanceMutex)
If RestartRequested Then
    Dim SelfName As ZString * 1024
    LbGetModuleFileName(0, @SelfName, 1024)
    LbShellExecute(0, "open", SelfName, "/restart", 0, LB_SW_SHOWNORMAL)
End If

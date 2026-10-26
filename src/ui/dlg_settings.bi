' ---------------------------------------------------------------------------
'  dlg_settings.bi - окно настроек (как у Punto Switcher, только нужные
'  пункты): слева разделы, справа страница раздела.
'
'  Общие            - запуск с Windows, автопереключение, флажок у каретки
'  Переключение     - одиночные Shift/Ctrl, раскладка по номеру, режим
'                     Caps Lock, Num Lock (switchkeys.bi)
'  Горячие клавиши  - четыре действия; «Назначить...» ждёт нажатия
'                     сочетания (его ловит хук, hotkeys.bi)
'  Звуки            - события с галками, файл каждого, сигнал динамика
'  Автопереключение - какие слова не трогать, папка словарей Hunspell
'
'  Окно правит копию настроек (EditSettings); «OK» и «Применить» переносят
'  её в Settings, пишут ini и вызывают SettingsOnApply.
' ---------------------------------------------------------------------------

#pragma once

#include once "rqlcl.bi"
#include once "../core/winapi.bi"
#include once "../core/config.bi"
#include once "../core/hotkeys.bi"
#include once "../core/sendkeys.bi"
#include once "../core/spell.bi"

Type SettingsApplyFn As Sub()

Dim Shared SettingsOnApply As SettingsApplyFn
Dim Shared EditSettings As AppSettings
Dim Shared SettingsOpen As Long

Dim Shared SettingsForm As QFORM
Dim Shared SectionList As QLISTBOX
Dim Shared GeneralPage As QPANEL
Dim Shared SwitchPage As QPANEL
Dim Shared HotkeysPage As QPANEL
Dim Shared SoundsPage As QPANEL
Dim Shared AutoPage As QPANEL
Dim Shared OkButton As QBUTTON
Dim Shared CancelButton As QBUTTON
Dim Shared ApplyButton As QBUTTON

Dim Shared AutoStartCheck As QCHECKBOX
Dim Shared AutoSwitchCheck As QCHECKBOX
Dim Shared CaretFlagCheck As QCHECKBOX

Dim Shared SoloLabels(0 To SOLO_KEY_COUNT - 1) As QLABEL
Dim Shared SoloCombos(0 To SOLO_KEY_COUNT - 1) As QCOMBOBOX
Dim Shared DoublePressCheck As QCHECKBOX
Dim Shared LangSelectLabel As QLABEL
Dim Shared LangSelectCombo As QCOMBOBOX
Dim Shared CapsLabel As QLABEL
Dim Shared CapsCombo As QCOMBOBOX
Dim Shared ShiftCapsCheck As QCHECKBOX
Dim Shared NumLockCheck As QCHECKBOX
Dim Shared SoloNote As QLABEL

Dim Shared HotkeyView As QLISTVIEW
Dim Shared ExtraUndoLabel As QLABEL
Dim Shared ShiftBackspaceCheck As QCHECKBOX
Dim Shared CtrlCapsCheck As QCHECKBOX
Dim Shared AssignButton As QBUTTON
Dim Shared ClearHotkeyButton As QBUTTON
Dim Shared DefaultHotkeyButton As QBUTTON

Dim Shared SoundsOnCheck As QCHECKBOX
Dim Shared SoundView As QLISTVIEW
Dim Shared SoundFileRadio As QRADIOBUTTON
Dim Shared SoundBeepRadio As QRADIOBUTTON
Dim Shared ChangeSoundButton As QBUTTON
Dim Shared PlaySoundButton As QBUTTON
Dim Shared DefaultSoundButton As QBUTTON
Dim Shared SoundDialog As QOPENDIALOG

Dim Shared AutoDigitsCheck As QCHECKBOX
Dim Shared AutoCapsCheck As QCHECKBOX
Dim Shared AutoSingleCheck As QCHECKBOX
Dim Shared AutoRememberCheck As QCHECKBOX
Dim Shared SpellFolderLabel As QLABEL
Dim Shared SpellFolderEdit As QEDIT
Dim Shared SpellBrowseButton As QBUTTON
Dim Shared SpellReloadButton As QBUTTON
Dim Shared UserDictButton As QBUTTON
Dim Shared SpellStatusLabel As QLABEL
Dim Shared AutoNote As QLABEL
Dim Shared SpellDialog As QOPENDIALOG

' окно «Назначить сочетание»
Dim Shared CaptureForm As QFORM
Dim Shared CaptureLabel As QLABEL
Dim Shared CaptureCancelButton As QBUTTON
Dim Shared CaptureActionIdx As Long

' --- заполнение из EditSettings и обратно ---

Private Sub FillHotkeyView()
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        Dim ComboText As String = EditSettings.Hotkey(ActionIdx)
        If ComboText = "" Then ComboText = "(нет)"
        HotkeyView.SetSubItem(ActionIdx, 0, ComboText)
    Next
End Sub

Private Function SoundFileShown(ByVal EventIdx As Long) As String
    If EditSettings.SoundFile(EventIdx) = "" Then Return "(нет)"
    Return EditSettings.SoundFile(EventIdx)
End Function

Private Sub FillSoundView()
    Dim EventIdx As Long
    For EventIdx = 0 To SOUND_EVENT_COUNT - 1
        SoundView.Item(EventIdx).Checked = EditSettings.SoundOn(EventIdx)
        SoundView.SetSubItem(EventIdx, 0, SoundFileShown(EventIdx))
    Next
End Sub

' Пункты одиночной клавиши: Выкл., следующая, предыдущая, раскладки
' Windows (список мог измениться с прошлого раза)
Private Sub FillSoloCombos()
    Dim KeyIdx As Long, LayoutIdx As Long
    For KeyIdx = 0 To SOLO_KEY_COUNT - 1
        SoloCombos(KeyIdx).Clear
        SoloCombos(KeyIdx).AddItems("Выкл.", "Следующая раскладка", "Предыдущая раскладка")
        For LayoutIdx = 0 To LayoutCount - 1
            With LayoutList(LayoutIdx)
                SoloCombos(KeyIdx).AddItems(.LanguageName & " (" & .LocaleCode & ")")
            End With
        Next
        Dim KeyAction As String = EditSettings.SoloKeyAction(KeyIdx)
        Dim ShownIdx As Long
        Select Case KeyAction
        Case ""
            ShownIdx = 0
        Case "next"
            ShownIdx = 1
        Case "prev"
            ShownIdx = 2
        Case Else
            ' раскладки, которой уже нет в Windows, - «Выкл.»
            ShownIdx = LayoutIndexOfCode(KeyAction) + 3
            If ShownIdx < 3 Then ShownIdx = 0
        End Select
        SoloCombos(KeyIdx).ItemIndex = ShownIdx
    Next
End Sub

Private Sub ReadSoloCombos()
    Dim KeyIdx As Long
    For KeyIdx = 0 To SOLO_KEY_COUNT - 1
        Dim ShownIdx As Long = SoloCombos(KeyIdx).ItemIndex
        Select Case ShownIdx
        Case 1
            EditSettings.SoloKeyAction(KeyIdx) = "next"
        Case 2
            EditSettings.SoloKeyAction(KeyIdx) = "prev"
        Case 3 To LayoutCount + 2
            EditSettings.SoloKeyAction(KeyIdx) = LayoutList(ShownIdx - 3).LocaleCode
        Case Else
            EditSettings.SoloKeyAction(KeyIdx) = ""
        End Select
    Next
End Sub

Private Sub FillForm()
    AutoStartCheck.Checked = EditSettings.AutoStart
    AutoSwitchCheck.Checked = EditSettings.AutoSwitch
    CaretFlagCheck.Checked = EditSettings.CaretFlag
    SoundsOnCheck.Checked = EditSettings.SoundsOn
    SoundFileRadio.Checked = IIf(EditSettings.SoundBeep = 0, 1, 0)
    SoundBeepRadio.Checked = EditSettings.SoundBeep
    FillSoloCombos()
    DoublePressCheck.Checked = EditSettings.DoublePress
    LangSelectCombo.ItemIndex = EditSettings.LangSelect
    CapsCombo.ItemIndex = EditSettings.CapsMode
    ShiftCapsCheck.Checked = EditSettings.ShiftCaps
    NumLockCheck.Checked = EditSettings.NumLockOn
    ShiftBackspaceCheck.Checked = EditSettings.ShiftBackspace
    CtrlCapsCheck.Checked = EditSettings.CtrlCaps
    AutoDigitsCheck.Checked = EditSettings.AutoIgnoreDigits
    AutoCapsCheck.Checked = EditSettings.AutoIgnoreCaps
    AutoSingleCheck.Checked = EditSettings.AutoSingleLetter
    AutoRememberCheck.Checked = EditSettings.AutoRemember
    SpellFolderEdit.Text = EditSettings.SpellFolder
    SpellStatusLabel.Caption = "Сейчас: " & SpellStatus
    FillHotkeyView()
    FillSoundView()
End Sub

' Галки и переключатели - в EditSettings (сочетания и файлы туда пишут
' сами кнопки)
Private Sub ReadForm()
    EditSettings.AutoStart = IIf(AutoStartCheck.Checked, 1, 0)
    EditSettings.AutoSwitch = IIf(AutoSwitchCheck.Checked, 1, 0)
    EditSettings.CaretFlag = IIf(CaretFlagCheck.Checked, 1, 0)
    EditSettings.SoundsOn = IIf(SoundsOnCheck.Checked, 1, 0)
    EditSettings.SoundBeep = IIf(SoundBeepRadio.Checked, 1, 0)
    ReadSoloCombos()
    EditSettings.DoublePress = IIf(DoublePressCheck.Checked, 1, 0)
    If LangSelectCombo.ItemIndex >= 0 Then EditSettings.LangSelect = LangSelectCombo.ItemIndex
    If CapsCombo.ItemIndex >= 0 Then EditSettings.CapsMode = CapsCombo.ItemIndex
    EditSettings.ShiftCaps = IIf(ShiftCapsCheck.Checked, 1, 0)
    EditSettings.NumLockOn = IIf(NumLockCheck.Checked, 1, 0)
    EditSettings.ShiftBackspace = IIf(ShiftBackspaceCheck.Checked, 1, 0)
    EditSettings.CtrlCaps = IIf(CtrlCapsCheck.Checked, 1, 0)
    EditSettings.AutoIgnoreDigits = IIf(AutoDigitsCheck.Checked, 1, 0)
    EditSettings.AutoIgnoreCaps = IIf(AutoCapsCheck.Checked, 1, 0)
    EditSettings.AutoSingleLetter = IIf(AutoSingleCheck.Checked, 1, 0)
    EditSettings.AutoRemember = IIf(AutoRememberCheck.Checked, 1, 0)
    EditSettings.SpellFolder = Trim(SpellFolderEdit.Text)
    Dim EventIdx As Long
    For EventIdx = 0 To SOUND_EVENT_COUNT - 1
        EditSettings.SoundOn(EventIdx) = IIf(SoundView.Item(EventIdx).Checked, 1, 0)
    Next
End Sub

Private Sub ApplyEdits()
    ReadForm()
    Settings = EditSettings
    ConfigSave()
    If SettingsOnApply <> 0 Then SettingsOnApply()
End Sub

' --- кнопки окна ---

Private Sub OnSectionClick()
    Dim SectionIdx As Long = SectionList.ItemIndex
    GeneralPage.Visible = IIf(SectionIdx = 0, 1, 0)
    SwitchPage.Visible = IIf(SectionIdx = 1, 1, 0)
    HotkeysPage.Visible = IIf(SectionIdx = 2, 1, 0)
    SoundsPage.Visible = IIf(SectionIdx = 3, 1, 0)
    AutoPage.Visible = IIf(SectionIdx = 4, 1, 0)
End Sub

Private Sub OnOkClick()
    ApplyEdits()
    SettingsForm.Close
End Sub

Private Sub OnCancelClick()
    SettingsForm.Close
End Sub

Private Sub OnApplyClick()
    ApplyEdits()
End Sub

' --- горячие клавиши ---

Private Sub OnCaptureCancelClick()
    HotkeyCaptureMode = 0
    CaptureForm.Close
End Sub

' Хук поймал сочетание (сообщение HotkeyCaptureMessage)
Sub SettingsCaptureDone()
    If CaptureForm.Visible = 0 Then Exit Sub
    ' клавиша проглочена - без лишнего нажатия отпущенный Win открыл бы «Пуск»
    If (HotkeyCapturedMods And (KB_MOD_ALT Or KB_MOD_WIN)) <> 0 Then SendKeyTap(LB_VK_MENU_MASK)
    If HotkeyCapturedKey = LB_VK_ESCAPE And HotkeyCapturedMods = 0 Then
        CaptureForm.Close
        Exit Sub
    End If
    Dim ComboText As String = HotkeyFormat(HotkeyCapturedKey, HotkeyCapturedMods)
    ' то же сочетание у другого действия снимается
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        If ActionIdx <> CaptureActionIdx And EditSettings.Hotkey(ActionIdx) = ComboText Then
            EditSettings.Hotkey(ActionIdx) = ""
        End If
    Next
    EditSettings.Hotkey(CaptureActionIdx) = ComboText
    CaptureForm.Close
End Sub

Private Function SelectedHotkey() As Long
    Dim ActionIdx As Long = HotkeyView.ItemIndex
    If ActionIdx < 0 Or ActionIdx >= HOTKEY_ACTION_COUNT Then Return -1
    Return ActionIdx
End Function

Private Sub OnAssignClick()
    Dim ActionIdx As Long = SelectedHotkey()
    If ActionIdx < 0 Then Exit Sub
    CaptureActionIdx = ActionIdx
    CaptureLabel.Caption = HotkeyActionNames(ActionIdx) & ":" & Chr(13, 10) & Chr(13, 10) _
        & "нажмите сочетание клавиш (Esc - отмена)"
    HotkeyCaptureMode = 1
    CaptureForm.Center
    CaptureForm.ShowModal
    HotkeyCaptureMode = 0
    FillHotkeyView()
End Sub

Private Sub OnClearHotkeyClick()
    Dim ActionIdx As Long = SelectedHotkey()
    If ActionIdx < 0 Then Exit Sub
    EditSettings.Hotkey(ActionIdx) = ""
    FillHotkeyView()
End Sub

Private Sub OnDefaultHotkeyClick()
    Dim ActionIdx As Long
    For ActionIdx = 0 To HOTKEY_ACTION_COUNT - 1
        EditSettings.Hotkey(ActionIdx) = HotkeyDefaults(ActionIdx)
    Next
    FillHotkeyView()
End Sub

' --- звуки ---

Private Function SelectedSound() As Long
    Dim EventIdx As Long = SoundView.ItemIndex
    If EventIdx < 0 Or EventIdx >= SOUND_EVENT_COUNT Then Return -1
    Return EventIdx
End Function

Private Sub OnChangeSoundClick()
    Dim EventIdx As Long = SelectedSound()
    If EventIdx < 0 Then Exit Sub
    SoundDialog.Caption = SoundEventNames(EventIdx)
    SoundDialog.Filter = "Звуки (*.wav)|*.wav|Все файлы (*.*)|*.*"
    SoundDialog.FileName = SoundPath(EditSettings.SoundFile(EventIdx))
    If SoundDialog.Execute() = 0 Then Exit Sub
    EditSettings.SoundFile(EventIdx) = SoundDialog.FileName
    SoundView.SetSubItem(EventIdx, 0, SoundFileShown(EventIdx))
End Sub

Private Sub OnPlaySoundClick()
    Dim EventIdx As Long = SelectedSound()
    If EventIdx < 0 Then Exit Sub
    If SoundBeepRadio.Checked Then
        LbMessageBeep(&hFFFFFFFF)
        Exit Sub
    End If
    Dim FullPath As String = SoundPath(EditSettings.SoundFile(EventIdx))
    If FullPath <> "" Then LbPlaySound(StrPtr(FullPath), 0, LB_SND_FILENAME Or LB_SND_ASYNC Or LB_SND_NODEFAULT)
End Sub

Private Sub OnDefaultSoundClick()
    Dim EventIdx As Long
    For EventIdx = 0 To SOUND_EVENT_COUNT - 1
        EditSettings.SoundFile(EventIdx) = SoundDefaults(EventIdx)
        EditSettings.SoundOn(EventIdx) = 1
    Next
    FillSoundView()
End Sub

' --- автопереключение ---

' Выбрана Hunspellx86.dll - папка на уровень выше её папки hunspell
Private Sub OnSpellBrowseClick()
    SpellDialog.Caption = "Где лежит " & SPELL_DLL_NAME & " (папка hunspell LangBarXX)"
    SpellDialog.Filter = "Hunspell (Hunspell*.dll)|Hunspell*.dll|Все файлы (*.*)|*.*"
    SpellDialog.FileName = ""
    If SpellDialog.Execute() = 0 Then Exit Sub
    Dim FolderPath As String = SpellDialog.FileName
    Dim SlashPos As Long = InStrRev(FolderPath, "\")
    If SlashPos > 0 Then FolderPath = Left(FolderPath, SlashPos - 1)
    If LCase(Right(FolderPath, 9)) = "\hunspell" Then FolderPath = Left(FolderPath, Len(FolderPath) - 9)
    SpellFolderEdit.Text = FolderPath
End Sub

Private Sub OnSpellReloadClick()
    SpellLoad(Trim(SpellFolderEdit.Text))
    SpellStatusLabel.Caption = "Сейчас: " & SpellStatus
End Sub

Private Sub OnUserDictClick()
    Dim FileName As String = SpellUserDictName()
    If FileExists(FileName) = 0 Then
        Dim FileNum As Long = FreeFile
        If Open(FileName For Output As #FileNum) = 0 Then
            Print #FileNum, "; слова, которые не надо переключать, по одному в строке (UTF-8)"
            Close #FileNum
        End If
    End If
    LbShellExecute(0, "open", "notepad.exe", Chr(34) & FileName & Chr(34), 0, LB_SW_SHOWNORMAL)
End Sub

Private Sub OnSettingsShow()
    LbSetForegroundWindow(Cast(Any Ptr, SettingsForm.Handle))
End Sub

Private Sub OnCaptureShow()
    LbSetForegroundWindow(Cast(Any Ptr, CaptureForm.Handle))
End Sub

' --- создание окна (один раз, при запуске) ---

Private Sub PlaceButton(ByRef Button As QBUTTON, ByRef ParentCtl As QCONTROL, ByRef Caption As String, _
        ByVal PosX As Long, ByVal PosY As Long, ByVal ButtonWidth As Long)
    Button.Parent = ParentCtl
    Button.Left = PosX : Button.Top = PosY
    Button.Width = ButtonWidth : Button.Height = 25
    Button.Caption = Caption
End Sub

Private Sub PlaceCheck(ByRef Check As QCHECKBOX, ByRef ParentCtl As QCONTROL, ByRef Caption As String, _
        ByVal PosY As Long)
    Check.Parent = ParentCtl
    Check.Left = 8 : Check.Top = PosY : Check.Width = 400
    Check.Caption = Caption
End Sub

Private Sub PreparePage(ByRef Page As QPANEL)
    Page.Parent = SettingsForm
    Page.Left = 172 : Page.Top = 8
    Page.Width = 420 : Page.Height = 344
    Page.BevelOuter = 0
    Page.Caption = ""
End Sub

Private Sub PlaceCombo(ByRef Combo As QCOMBOBOX, ByRef Caption As QLABEL, ByRef CaptionText As String, _
        ByVal PosY As Long, ByVal ComboLeft As Long)
    Caption.Parent = SwitchPage
    Caption.Left = 8 : Caption.Top = PosY + 3
    Caption.Caption = CaptionText
    Combo.Parent = SwitchPage
    Combo.Left = ComboLeft : Combo.Top = PosY
    Combo.Width = 412 - ComboLeft
    ' только выбор из списка
    Combo.Style = 2
End Sub

Sub SettingsCreate()
    SettingsForm.Caption = "Настройки LangBarFB"
    SettingsForm.BorderStyle = 3
    SettingsForm.ClientWidth = 600
    SettingsForm.ClientHeight = 392
    SettingsForm.OnShow = @OnSettingsShow

    SectionList.Parent = SettingsForm
    SectionList.Left = 8 : SectionList.Top = 8
    SectionList.Width = 156 : SectionList.Height = 344
    SectionList.AddItems("Общие", "Переключение", "Горячие клавиши", "Звуки", "Автопереключение")
    SectionList.OnClick = @OnSectionClick

    PreparePage(GeneralPage)
    PreparePage(SwitchPage)
    PreparePage(HotkeysPage)
    PreparePage(SoundsPage)
    PreparePage(AutoPage)

    ' Общие
    PlaceCheck(AutoStartCheck, GeneralPage, "Запускать при старте Windows", 8)
    PlaceCheck(AutoSwitchCheck, GeneralPage, "Автопереключение", 36)
    PlaceCheck(CaretFlagCheck, GeneralPage, "Показывать флажок у текстового курсора", 64)

    ' Переключение
    Dim KeyIdx As Long
    For KeyIdx = 0 To SOLO_KEY_COUNT - 1
        PlaceCombo(SoloCombos(KeyIdx), SoloLabels(KeyIdx), SoloKeyTitles(KeyIdx), 8 + KeyIdx * 30, 120)
    Next
    PlaceCheck(DoublePressCheck, SwitchPage, "Срабатывать по двойному нажатию", 128)
    PlaceCombo(LangSelectCombo, LangSelectLabel, "Раскладка по номеру", 162, 160)
    LangSelectCombo.AddItems("Выкл.", "Левый Ctrl + 1...9", "Левый Alt + 1...9", "Левый Win + 1...9")
    PlaceCombo(CapsCombo, CapsLabel, "Caps Lock", 196, 160)
    CapsCombo.AddItems("Обычный", "Не действует", "Следующая раскладка", _
        "Последнее слово в другой раскладке", "Регистр выделенного текста")
    PlaceCheck(ShiftCapsCheck, SwitchPage, "Shift + Caps Lock включает и выключает Caps Lock", 228)
    PlaceCheck(NumLockCheck, SwitchPage, "Включать Num Lock при запуске", 256)
    SoloNote.Parent = SwitchPage
    SoloNote.Left = 8 : SoloNote.Top = 292
    SoloNote.Width = 404 : SoloNote.Height = 44
    SoloNote.WordWrap = 1
    SoloNote.Caption = "Одиночная клавиша срабатывает, если её нажали и отпустили без других клавиш и щелчков мыши."

    ' Горячие клавиши
    HotkeyView.Parent = HotkeysPage
    HotkeyView.Left = 0 : HotkeyView.Top = 0
    HotkeyView.Width = 420 : HotkeyView.Height = 200
    HotkeyView.ViewStyle = 3
    HotkeyView.RowSelect = 1
    HotkeyView.ReadOnly = 1
    HotkeyView.HideSelection = 0
    HotkeyView.AddColumns("Действие", "Сочетание")
    HotkeyView.Column(0).Width = 270
    HotkeyView.Column(1).Width = 140
    Dim ItemIdx As Long
    For ItemIdx = 0 To HOTKEY_ACTION_COUNT - 1
        HotkeyView.AddItems(HotkeyActionNames(ItemIdx))
    Next
    HotkeyView.OnDblClick = @OnAssignClick
    ExtraUndoLabel.Parent = HotkeysPage
    ExtraUndoLabel.Left = 0 : ExtraUndoLabel.Top = 212
    ExtraUndoLabel.Caption = "Последнее слово исправляют также:"
    PlaceCheck(ShiftBackspaceCheck, HotkeysPage, "Левый Shift + Backspace", 234)
    PlaceCheck(CtrlCapsCheck, HotkeysPage, "Ctrl + Caps Lock", 258)
    PlaceButton(AssignButton, HotkeysPage, "Назначить...", 0, 310, 100)
    PlaceButton(ClearHotkeyButton, HotkeysPage, "Снять", 108, 310, 100)
    PlaceButton(DefaultHotkeyButton, HotkeysPage, "По умолчанию", 216, 310, 110)
    AssignButton.OnClick = @OnAssignClick
    ClearHotkeyButton.OnClick = @OnClearHotkeyClick
    DefaultHotkeyButton.OnClick = @OnDefaultHotkeyClick

    ' Звуки
    SoundsOnCheck.Parent = SoundsPage
    SoundsOnCheck.Left = 0 : SoundsOnCheck.Top = 0 : SoundsOnCheck.Width = 400
    SoundsOnCheck.Caption = "Звуковые эффекты"
    SoundView.Parent = SoundsPage
    SoundView.Left = 0 : SoundView.Top = 28
    SoundView.Width = 420 : SoundView.Height = 200
    SoundView.ViewStyle = 3
    SoundView.CheckBoxes = 1
    SoundView.RowSelect = 1
    SoundView.ReadOnly = 1
    SoundView.HideSelection = 0
    SoundView.AddColumns("Событие", "Файл")
    SoundView.Column(0).Width = 220
    SoundView.Column(1).Width = 190
    For ItemIdx = 0 To SOUND_EVENT_COUNT - 1
        SoundView.AddItems(SoundEventNames(ItemIdx))
    Next
    SoundView.OnDblClick = @OnChangeSoundClick
    SoundFileRadio.Parent = SoundsPage
    SoundFileRadio.Left = 0 : SoundFileRadio.Top = 236 : SoundFileRadio.Width = 400
    SoundFileRadio.Caption = "Проигрывать файлы"
    SoundBeepRadio.Parent = SoundsPage
    SoundBeepRadio.Left = 0 : SoundBeepRadio.Top = 260 : SoundBeepRadio.Width = 400
    SoundBeepRadio.Caption = "Стандартный сигнал Windows"
    PlaceButton(ChangeSoundButton, SoundsPage, "Изменить...", 0, 310, 100)
    PlaceButton(PlaySoundButton, SoundsPage, "Проиграть", 108, 310, 100)
    PlaceButton(DefaultSoundButton, SoundsPage, "По умолчанию", 216, 310, 110)
    ChangeSoundButton.OnClick = @OnChangeSoundClick
    PlaySoundButton.OnClick = @OnPlaySoundClick
    DefaultSoundButton.OnClick = @OnDefaultSoundClick

    ' Автопереключение
    PlaceCheck(AutoDigitsCheck, AutoPage, "Не переключать слова с цифрами", 8)
    PlaceCheck(AutoCapsCheck, AutoPage, "Не переключать слова из заглавных букв (аббревиатуры)", 32)
    PlaceCheck(AutoSingleCheck, AutoPage, "Переключать слова из одной буквы", 56)
    PlaceCheck(AutoRememberCheck, AutoPage, "Слово, переключение которого отменили Break, - в user_dict.dic", 80)
    SpellFolderLabel.Parent = AutoPage
    SpellFolderLabel.Left = 8 : SpellFolderLabel.Top = 114
    SpellFolderLabel.Caption = "Папка с hunspell\ и dict\ (пусто - рядом с программой или выше):"
    SpellFolderEdit.Parent = AutoPage
    SpellFolderEdit.Left = 8 : SpellFolderEdit.Top = 134 : SpellFolderEdit.Width = 300
    PlaceButton(SpellBrowseButton, AutoPage, "Обзор...", 316, 132, 96)
    PlaceButton(SpellReloadButton, AutoPage, "Перечитать словари", 8, 166, 140)
    PlaceButton(UserDictButton, AutoPage, "Слова пользователя", 156, 166, 140)
    SpellBrowseButton.OnClick = @OnSpellBrowseClick
    SpellReloadButton.OnClick = @OnSpellReloadClick
    UserDictButton.OnClick = @OnUserDictClick
    SpellStatusLabel.Parent = AutoPage
    SpellStatusLabel.Left = 8 : SpellStatusLabel.Top = 202
    SpellStatusLabel.Width = 404 : SpellStatusLabel.Height = 48
    SpellStatusLabel.WordWrap = 1
    AutoNote.Parent = AutoPage
    AutoNote.Left = 8 : AutoNote.Top = 260
    AutoNote.Width = 404 : AutoNote.Height = 76
    AutoNote.WordWrap = 1
    AutoNote.Caption = "Слово проверяется после пробела: если в текущей раскладке его нет в словаре, " _
        & "а в другой есть, оно перепечатывается и раскладка меняется. Break сразу после этого " _
        & "возвращает слово. Библиотека и словари - из LangBarXX (папки hunspell и dict)."

    ' кнопки окна
    PlaceButton(OkButton, SettingsForm, "OK", 356, 360, 75)
    PlaceButton(CancelButton, SettingsForm, "Отмена", 436, 360, 75)
    PlaceButton(ApplyButton, SettingsForm, "Применить", 516, 360, 76)
    OkButton.Default = 1
    CancelButton.Cancel = 1
    OkButton.OnClick = @OnOkClick
    CancelButton.OnClick = @OnCancelClick
    ApplyButton.OnClick = @OnApplyClick

    ' окно записи сочетания
    CaptureForm.Caption = "Назначить сочетание"
    CaptureForm.BorderStyle = 3
    CaptureForm.ClientWidth = 360
    CaptureForm.ClientHeight = 110
    CaptureForm.OnShow = @OnCaptureShow
    CaptureLabel.Parent = CaptureForm
    CaptureLabel.Left = 12 : CaptureLabel.Top = 12
    CaptureLabel.Width = 336 : CaptureLabel.Height = 56
    CaptureLabel.WordWrap = 1
    PlaceButton(CaptureCancelButton, CaptureForm, "Отмена", 272, 76, 76)
    CaptureCancelButton.OnClick = @OnCaptureCancelClick
End Sub

' Показывает окно настроек; возвращается, когда его закрыли
Sub SettingsShow(ByVal SectionIdx As Long = 0)
    If SettingsOpen Then
        LbSetForegroundWindow(Cast(Any Ptr, SettingsForm.Handle))
        Exit Sub
    End If
    SettingsOpen = 1
    EditSettings = Settings
    FillForm()
    SectionList.ItemIndex = SectionIdx
    OnSectionClick()
    HotkeyView.ItemIndex = 0
    SoundView.ItemIndex = 0
    ' пока окно открыто, сочетания не действуют: их назначают
    HotkeysEnabled = 0
    SettingsForm.Center
    SettingsForm.ShowModal
    HotkeysEnabled = 1
    SettingsOpen = 0
End Sub

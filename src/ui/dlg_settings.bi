' ---------------------------------------------------------------------------
'  dlg_settings.bi - окно настроек (как у Punto Switcher, только нужные
'  пункты): слева разделы, справа страница раздела.
'
'  Общие            - запуск с Windows, автопереключение, флажок у каретки
'                     и у указателя мыши, язык интерфейса, сброс настроек
'  Переключение     - одиночные Shift/Ctrl, раскладка по номеру, режим
'                     Caps Lock, Num Lock (switchkeys.bi)
'  Горячие клавиши  - четыре действия; «Назначить...» ждёт нажатия
'                     сочетания (его ловит хук, hotkeys.bi)
'  Звуки            - события с галками, файл каждого, сигнал динамика
'  Автопереключение - какие слова не трогать, папка словарей Hunspell
'  Правила переключения - список правил и окно правила (rules.bi)
'
'  Окно правит копию настроек (EditSettings); «OK» и «Применить» переносят
'  её в Settings, пишут ini и вызывают SettingsOnApply.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
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
Dim Shared RulesPage As QPANEL
Dim Shared OkButton As QBUTTON
Dim Shared CancelButton As QBUTTON
Dim Shared ApplyButton As QBUTTON

Dim Shared AutoStartCheck As QCHECKBOX
Dim Shared AutoSwitchCheck As QCHECKBOX
Dim Shared CaretFlagCheck As QCHECKBOX
Dim Shared MouseFlagLabel As QLABEL
Dim Shared MouseFlagCombo As QCOMBOBOX
Dim Shared LanguageLabel As QLABEL
Dim Shared LanguageCombo As QCOMBOBOX
Dim Shared LanguageNote As QLABEL
Dim Shared ResetButton As QBUTTON

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
Dim Shared KeepDotCommaCheck As QCHECKBOX
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
Dim Shared AutoEarlyCheck As QCHECKBOX
Dim Shared SpellFolderLabel As QLABEL
Dim Shared SpellFolderEdit As QEDIT
Dim Shared SpellBrowseButton As QBUTTON
Dim Shared SpellReloadButton As QBUTTON
Dim Shared UserDictButton As QBUTTON
Dim Shared SpellStatusLabel As QLABEL
Dim Shared AutoNote As QLABEL
Dim Shared SpellDialog As QOPENDIALOG
' Правила переключения
Dim Shared RulesNote As QLABEL
Dim Shared RulesView As QLISTVIEW
Dim Shared AddRuleButton As QBUTTON
Dim Shared EditRuleButton As QBUTTON
Dim Shared DeleteRuleButton As QBUTTON
Dim Shared SuggestRuleCheck As QCHECKBOX
Dim Shared SuggestCountEdit As QEDIT
Dim Shared SuggestCountLabel As QLABEL

' окно правила (добавить / изменить)
Dim Shared RuleForm As QFORM
Dim Shared RuleTextLabel As QLABEL
Dim Shared RuleTextEdit As QEDIT
Dim Shared RuleCondLabel As QLABEL
Dim Shared RuleCondCombo As QCOMBOBOX
Dim Shared RuleCaseLabel As QLABEL
Dim Shared RuleCaseCombo As QCOMBOBOX
Dim Shared RuleActionLabel As QLABEL
Dim Shared RuleActionCombo As QCOMBOBOX
Dim Shared RuleOkButton As QBUTTON
Dim Shared RuleCancelButton As QBUTTON
Dim Shared RuleFormOk As Long

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
        If ComboText = "" Then ComboText = Tr("(нет)")
        HotkeyView.SetSubItem(ActionIdx, 0, ComboText)
    Next
End Sub

Private Function SoundFileShown(ByVal EventIdx As Long) As String
    If EditSettings.SoundFile(EventIdx) = "" Then Return Tr("(нет)")
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
        SoloCombos(KeyIdx).AddItems(Tr("Выкл."), Tr("Следующая раскладка"), Tr("Предыдущая раскладка"))
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

Private Sub FillRulesView()
    Dim KeepIdx As Long = RulesView.ItemIndex
    RulesView.Clear
    Dim RuleIdx As Long
    For RuleIdx = 0 To EditSettings.RuleCount - 1
        With EditSettings.Rule(RuleIdx)
            RulesView.AddItems(.RuleText)
            RulesView.SetSubItem(RuleIdx, 0, Tr(RuleConditionNames(.Condition)))
            RulesView.SetSubItem(RuleIdx, 1, Tr(RuleCaseNames(.MatchCase)))
            RulesView.SetSubItem(RuleIdx, 2, Tr(RuleActionNames(.Action)))
        End With
    Next
    If KeepIdx >= EditSettings.RuleCount Then KeepIdx = EditSettings.RuleCount - 1
    If KeepIdx < 0 And EditSettings.RuleCount > 0 Then KeepIdx = 0
    RulesView.ItemIndex = KeepIdx
End Sub

Private Sub FillForm()
    AutoStartCheck.Checked = EditSettings.AutoStart
    AutoSwitchCheck.Checked = EditSettings.AutoSwitch
    CaretFlagCheck.Checked = EditSettings.CaretFlag
    MouseFlagCombo.ItemIndex = EditSettings.MouseFlag
    LanguageCombo.ItemIndex = IIf(EditSettings.Language = "en", 1, 0)
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
    KeepDotCommaCheck.Checked = EditSettings.KeepDotComma
    AutoDigitsCheck.Checked = EditSettings.AutoIgnoreDigits
    AutoCapsCheck.Checked = EditSettings.AutoIgnoreCaps
    AutoSingleCheck.Checked = EditSettings.AutoSingleLetter
    AutoRememberCheck.Checked = EditSettings.AutoRemember
    AutoEarlyCheck.Checked = EditSettings.AutoEarly
    SpellFolderEdit.Text = EditSettings.SpellFolder
    SpellStatusLabel.Caption = Tr("Сейчас: ") & SpellStatus
    SuggestRuleCheck.Checked = EditSettings.SuggestRule
    SuggestCountEdit.Text = Str(EditSettings.SuggestCount)
    FillHotkeyView()
    FillSoundView()
    FillRulesView()
End Sub

' Галки и переключатели - в EditSettings (сочетания и файлы туда пишут
' сами кнопки)
Private Sub ReadForm()
    EditSettings.AutoStart = IIf(AutoStartCheck.Checked, 1, 0)
    EditSettings.AutoSwitch = IIf(AutoSwitchCheck.Checked, 1, 0)
    EditSettings.CaretFlag = IIf(CaretFlagCheck.Checked, 1, 0)
    If MouseFlagCombo.ItemIndex >= 0 Then EditSettings.MouseFlag = MouseFlagCombo.ItemIndex
    If LanguageCombo.ItemIndex >= 0 Then EditSettings.Language = IIf(LanguageCombo.ItemIndex = 1, "en", "ru")
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
    EditSettings.KeepDotComma = IIf(KeepDotCommaCheck.Checked, 1, 0)
    EditSettings.AutoIgnoreDigits = IIf(AutoDigitsCheck.Checked, 1, 0)
    EditSettings.AutoIgnoreCaps = IIf(AutoCapsCheck.Checked, 1, 0)
    EditSettings.AutoSingleLetter = IIf(AutoSingleCheck.Checked, 1, 0)
    EditSettings.AutoRemember = IIf(AutoRememberCheck.Checked, 1, 0)
    EditSettings.AutoEarly = IIf(AutoEarlyCheck.Checked, 1, 0)
    EditSettings.SpellFolder = Trim(SpellFolderEdit.Text)
    EditSettings.SuggestRule = IIf(SuggestRuleCheck.Checked, 1, 0)
    Dim SuggestCount As Long = ValInt(SuggestCountEdit.Text)
    If SuggestCount >= 1 And SuggestCount <= 99 Then EditSettings.SuggestCount = SuggestCount
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
    RulesPage.Visible = IIf(SectionIdx = 5, 1, 0)
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

' Сброс настроек: спросить, сбросить с копией прежнего ini, применить.
' Из меню значка и кнопкой на странице «Общие».
Sub SettingsResetAsk()
    If LbMessageBox(0, Tr("Сбросить все настройки к значениям по умолчанию?") & Chr(13, 10) _
            & Tr("Копия текущих настроек сохранится в папке backup рядом с программой."), _
            "LangBarFB", LB_MB_YESNO Or LB_MB_ICONQUESTION) <> LB_IDYES Then Exit Sub
    Dim BackupName As String = ConfigReset()
    EditSettings = Settings
    If SettingsOpen Then FillForm()
    If SettingsOnApply <> 0 Then SettingsOnApply()
    If BackupName <> "" Then
        LbMessageBox(0, Tr("Настройки сброшены. Копия прежних: ") & BackupName, "LangBarFB", LB_MB_ICONINFORMATION)
    Else
        LbMessageBox(0, Tr("Настройки сброшены."), "LangBarFB", LB_MB_ICONINFORMATION)
    End If
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
    CaptureLabel.Caption = Tr(HotkeyActionNames(ActionIdx)) & ":" & Chr(13, 10) & Chr(13, 10) _
        & Tr("нажмите сочетание клавиш (Esc - отмена)")
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
    SoundDialog.Caption = Tr(SoundEventNames(EventIdx))
    SoundDialog.Filter = Tr("Звуки (*.wav)|*.wav|Все файлы (*.*)|*.*")
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
    SpellDialog.Caption = Tr("Где лежит ") & SPELL_DLL_NAME & Tr(" (папка hunspell LangBarXX)")
    SpellDialog.Filter = Tr("Hunspell (Hunspell*.dll)|Hunspell*.dll|Все файлы (*.*)|*.*")
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
    SpellStatusLabel.Caption = Tr("Сейчас: ") & SpellStatus
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

' --- правила переключения ---

Private Sub OnRuleOkClick()
    If Trim(RuleTextEdit.Text) = "" Then
        LbMessageBox(Cast(Any Ptr, RuleForm.Handle), Tr("Введите сочетание букв."), "LangBarFB", LB_MB_ICONWARNING)
        Exit Sub
    End If
    RuleFormOk = 1
    RuleForm.Close
End Sub

Private Sub OnRuleCancelClick()
    RuleForm.Close
End Sub

Private Sub OnRuleFormShow()
    LbSetForegroundWindow(Cast(Any Ptr, RuleForm.Handle))
    RuleTextEdit.SetFocus
End Sub

' Окно правила: RuleIdx - номер правила в EditSettings, -1 - новое.
' 1 - нажали OK, правило записано в EditSettings.
Private Function EditRule(ByVal RuleIdx As Long) As Long
    If RuleIdx < 0 Then
        RuleForm.Caption = Tr("Новое правило")
        RuleTextEdit.Text = ""
        RuleCondCombo.ItemIndex = RULE_WHOLE
        RuleCaseCombo.ItemIndex = 0
        RuleActionCombo.ItemIndex = RULE_KEEP
    Else
        RuleForm.Caption = Tr("Изменить правило")
        With EditSettings.Rule(RuleIdx)
            RuleTextEdit.Text = .RuleText
            RuleCondCombo.ItemIndex = .Condition
            RuleCaseCombo.ItemIndex = .MatchCase
            RuleActionCombo.ItemIndex = .Action
        End With
    End If
    RuleFormOk = 0
    RuleForm.Center
    RuleForm.ShowModal
    If RuleFormOk = 0 Then Return 0
    If RuleIdx < 0 Then
        RuleIdx = EditSettings.RuleCount
        EditSettings.RuleCount += 1
    End If
    With EditSettings.Rule(RuleIdx)
        .RuleText = Trim(RuleTextEdit.Text)
        .Condition = IIf(RuleCondCombo.ItemIndex >= RULE_WHOLE And RuleCondCombo.ItemIndex <= RULE_PART, _
            RuleCondCombo.ItemIndex, RULE_WHOLE)
        .MatchCase = IIf(RuleCaseCombo.ItemIndex = 1, 1, 0)
        .Action = IIf(RuleActionCombo.ItemIndex = RULE_SWITCH, RULE_SWITCH, RULE_KEEP)
    End With
    FillRulesView()
    RulesView.ItemIndex = RuleIdx
    Return 1
End Function

Private Function SelectedRule() As Long
    Dim RuleIdx As Long = RulesView.ItemIndex
    If RuleIdx < 0 Or RuleIdx >= EditSettings.RuleCount Then Return -1
    Return RuleIdx
End Function

Private Sub OnAddRuleClick()
    If EditSettings.RuleCount >= MAX_RULES Then
        LbMessageBox(Cast(Any Ptr, SettingsForm.Handle), Tr("Правил не может быть больше ") & MAX_RULES & ".", _
            "LangBarFB", LB_MB_ICONWARNING)
        Exit Sub
    End If
    EditRule(-1)
End Sub

Private Sub OnEditRuleClick()
    Dim RuleIdx As Long = SelectedRule()
    If RuleIdx < 0 Then Exit Sub
    EditRule(RuleIdx)
End Sub

Private Sub OnDeleteRuleClick()
    Dim RuleIdx As Long = SelectedRule()
    If RuleIdx < 0 Then Exit Sub
    Dim MoveIdx As Long
    For MoveIdx = RuleIdx To EditSettings.RuleCount - 2
        EditSettings.Rule(MoveIdx) = EditSettings.Rule(MoveIdx + 1)
    Next
    EditSettings.RuleCount -= 1
    EditSettings.Rule(EditSettings.RuleCount).RuleText = ""
    FillRulesView()
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
        ByVal PosY As Long, ByVal ComboLeft As Long, ByRef ParentCtl As QCONTROL = SwitchPage)
    Caption.Parent = ParentCtl
    Caption.Left = 8 : Caption.Top = PosY + 3
    Caption.Caption = CaptionText
    Combo.Parent = ParentCtl
    Combo.Left = ComboLeft : Combo.Top = PosY
    Combo.Width = 412 - ComboLeft
    ' только выбор из списка
    Combo.Style = 2
End Sub

Private Sub PlaceRuleCombo(ByRef Combo As QCOMBOBOX, ByRef Caption As QLABEL, ByRef CaptionText As String, _
        ByVal PosY As Long)
    Caption.Parent = RuleForm
    Caption.Left = 12 : Caption.Top = PosY + 3
    Caption.Caption = CaptionText
    Combo.Parent = RuleForm
    Combo.Left = 120 : Combo.Top = PosY
    Combo.Width = 208
    Combo.Style = 2
End Sub

Sub SettingsCreate()
    SettingsForm.Caption = Tr("Настройки LangBarFB")
    SettingsForm.BorderStyle = 3
    SettingsForm.ClientWidth = 600
    SettingsForm.ClientHeight = 392
    SettingsForm.OnShow = @OnSettingsShow

    SectionList.Parent = SettingsForm
    SectionList.Left = 8 : SectionList.Top = 8
    SectionList.Width = 156 : SectionList.Height = 344
    SectionList.AddItems(Tr("Общие"), Tr("Переключение"), Tr("Горячие клавиши"), Tr("Звуки"), Tr("Автопереключение"), _
        Tr("Правила переключения"))
    SectionList.OnClick = @OnSectionClick

    PreparePage(GeneralPage)
    PreparePage(SwitchPage)
    PreparePage(HotkeysPage)
    PreparePage(SoundsPage)
    PreparePage(AutoPage)
    PreparePage(RulesPage)

    ' Общие
    PlaceCheck(AutoStartCheck, GeneralPage, Tr("Запускать при старте Windows"), 8)
    PlaceCheck(AutoSwitchCheck, GeneralPage, Tr("Автопереключение"), 36)
    PlaceCheck(CaretFlagCheck, GeneralPage, Tr("Показывать флажок у текстового курсора"), 64)
    PlaceCombo(MouseFlagCombo, MouseFlagLabel, Tr("Флажок у указателя мыши"), 98, 180, GeneralPage)
    MouseFlagCombo.AddItems(Tr("Не показывать"), Tr("Показывать всегда"), Tr("3 секунды после смены раскладки"))
    PlaceCombo(LanguageCombo, LanguageLabel, Tr("Язык интерфейса"), 132, 180, GeneralPage)
    LanguageCombo.AddItems("Русский", "English")
    LanguageNote.Parent = GeneralPage
    LanguageNote.Left = 180 : LanguageNote.Top = 160
    LanguageNote.Caption = Tr("Язык меняется после перезапуска программы.")
    PlaceButton(ResetButton, GeneralPage, Tr("Сбросить настройки..."), 8, 310, 160)
    ResetButton.OnClick = @SettingsResetAsk

    ' Переключение
    Dim KeyIdx As Long
    For KeyIdx = 0 To SOLO_KEY_COUNT - 1
        PlaceCombo(SoloCombos(KeyIdx), SoloLabels(KeyIdx), Tr(SoloKeyTitles(KeyIdx)), 8 + KeyIdx * 30, 120)
    Next
    PlaceCheck(DoublePressCheck, SwitchPage, Tr("Срабатывать по двойному нажатию"), 128)
    PlaceCombo(LangSelectCombo, LangSelectLabel, Tr("Раскладка по номеру"), 162, 160)
    LangSelectCombo.AddItems(Tr("Выкл."), Tr("Левый Ctrl + 1...9"), Tr("Левый Alt + 1...9"), Tr("Левый Win + 1...9"))
    PlaceCombo(CapsCombo, CapsLabel, "Caps Lock", 196, 160)
    CapsCombo.AddItems(Tr("Обычный"), Tr("Не действует"), Tr("Следующая раскладка"), _
        Tr("Последнее слово в другой раскладке"), Tr("Регистр выделенного текста"))
    PlaceCheck(ShiftCapsCheck, SwitchPage, Tr("Shift + Caps Lock включает и выключает Caps Lock"), 228)
    PlaceCheck(NumLockCheck, SwitchPage, Tr("Включать Num Lock при запуске"), 256)
    SoloNote.Parent = SwitchPage
    SoloNote.Left = 8 : SoloNote.Top = 292
    SoloNote.Width = 404 : SoloNote.Height = 44
    SoloNote.AutoSize = 0
    SoloNote.WordWrap = 1
    SoloNote.Caption = Tr("Одиночная клавиша срабатывает, если её нажали и отпустили без других клавиш и щелчков мыши.")

    ' Горячие клавиши
    HotkeyView.Parent = HotkeysPage
    HotkeyView.Left = 0 : HotkeyView.Top = 0
    HotkeyView.Width = 420 : HotkeyView.Height = 200
    HotkeyView.ViewStyle = 3
    HotkeyView.RowSelect = 1
    HotkeyView.ReadOnly = 1
    HotkeyView.HideSelection = 0
    HotkeyView.AddColumns(Tr("Действие"), Tr("Сочетание"))
    HotkeyView.Column(0).Width = 270
    HotkeyView.Column(1).Width = 140
    Dim ItemIdx As Long
    For ItemIdx = 0 To HOTKEY_ACTION_COUNT - 1
        HotkeyView.AddItems(Tr(HotkeyActionNames(ItemIdx)))
    Next
    HotkeyView.OnDblClick = @OnAssignClick
    ExtraUndoLabel.Parent = HotkeysPage
    ExtraUndoLabel.Left = 0 : ExtraUndoLabel.Top = 212
    ExtraUndoLabel.Caption = Tr("Последнее слово исправляют также:")
    PlaceCheck(ShiftBackspaceCheck, HotkeysPage, Tr("Левый Shift + Backspace"), 234)
    PlaceCheck(CtrlCapsCheck, HotkeysPage, "Ctrl + Caps Lock", 258)
    PlaceCheck(KeepDotCommaCheck, HotkeysPage, Tr("Точку и запятую не менять при смене раскладки текста"), 284)
    PlaceButton(AssignButton, HotkeysPage, Tr("Назначить..."), 0, 310, 100)
    PlaceButton(ClearHotkeyButton, HotkeysPage, Tr("Снять"), 108, 310, 100)
    PlaceButton(DefaultHotkeyButton, HotkeysPage, Tr("По умолчанию"), 216, 310, 110)
    AssignButton.OnClick = @OnAssignClick
    ClearHotkeyButton.OnClick = @OnClearHotkeyClick
    DefaultHotkeyButton.OnClick = @OnDefaultHotkeyClick

    ' Звуки
    SoundsOnCheck.Parent = SoundsPage
    SoundsOnCheck.Left = 0 : SoundsOnCheck.Top = 0 : SoundsOnCheck.Width = 400
    SoundsOnCheck.Caption = Tr("Звуковые эффекты")
    SoundView.Parent = SoundsPage
    SoundView.Left = 0 : SoundView.Top = 28
    SoundView.Width = 420 : SoundView.Height = 200
    SoundView.ViewStyle = 3
    SoundView.CheckBoxes = 1
    SoundView.RowSelect = 1
    SoundView.ReadOnly = 1
    SoundView.HideSelection = 0
    SoundView.AddColumns(Tr("Событие"), Tr("Файл"))
    SoundView.Column(0).Width = 220
    SoundView.Column(1).Width = 190
    For ItemIdx = 0 To SOUND_EVENT_COUNT - 1
        SoundView.AddItems(Tr(SoundEventNames(ItemIdx)))
    Next
    SoundView.OnDblClick = @OnChangeSoundClick
    SoundFileRadio.Parent = SoundsPage
    SoundFileRadio.Left = 0 : SoundFileRadio.Top = 236 : SoundFileRadio.Width = 400
    SoundFileRadio.Caption = Tr("Проигрывать файлы")
    SoundBeepRadio.Parent = SoundsPage
    SoundBeepRadio.Left = 0 : SoundBeepRadio.Top = 260 : SoundBeepRadio.Width = 400
    SoundBeepRadio.Caption = Tr("Стандартный сигнал Windows")
    PlaceButton(ChangeSoundButton, SoundsPage, Tr("Изменить..."), 0, 310, 100)
    PlaceButton(PlaySoundButton, SoundsPage, Tr("Проиграть"), 108, 310, 100)
    PlaceButton(DefaultSoundButton, SoundsPage, Tr("По умолчанию"), 216, 310, 110)
    ChangeSoundButton.OnClick = @OnChangeSoundClick
    PlaySoundButton.OnClick = @OnPlaySoundClick
    DefaultSoundButton.OnClick = @OnDefaultSoundClick

    ' Автопереключение
    PlaceCheck(AutoEarlyCheck, AutoPage, Tr("Проверять начало слова (с третьей буквы)"), 104)
    PlaceCheck(AutoDigitsCheck, AutoPage, Tr("Не переключать слова с цифрами"), 8)
    PlaceCheck(AutoCapsCheck, AutoPage, Tr("Не переключать слова из заглавных букв (аббревиатуры)"), 32)
    PlaceCheck(AutoSingleCheck, AutoPage, Tr("Переключать слова из одной буквы"), 56)
    PlaceCheck(AutoRememberCheck, AutoPage, Tr("Слово, переключение которого отменили Break, - в user_dict.dic"), 80)
    SpellFolderLabel.Parent = AutoPage
    SpellFolderLabel.Left = 8 : SpellFolderLabel.Top = 138
    SpellFolderLabel.Caption = Tr("Папка с hunspell\ и dict\ (пусто - рядом с программой или выше):")
    SpellFolderEdit.Parent = AutoPage
    SpellFolderEdit.Left = 8 : SpellFolderEdit.Top = 158 : SpellFolderEdit.Width = 300
    PlaceButton(SpellBrowseButton, AutoPage, Tr("Обзор..."), 316, 156, 96)
    PlaceButton(SpellReloadButton, AutoPage, Tr("Перечитать словари"), 8, 190, 140)
    PlaceButton(UserDictButton, AutoPage, Tr("Слова пользователя"), 156, 190, 140)
    SpellBrowseButton.OnClick = @OnSpellBrowseClick
    SpellReloadButton.OnClick = @OnSpellReloadClick
    UserDictButton.OnClick = @OnUserDictClick
    SpellStatusLabel.Parent = AutoPage
    SpellStatusLabel.Left = 8 : SpellStatusLabel.Top = 224
    SpellStatusLabel.Width = 404 : SpellStatusLabel.Height = 48
    SpellStatusLabel.AutoSize = 0
    SpellStatusLabel.WordWrap = 1
    AutoNote.Parent = AutoPage
    AutoNote.Left = 8 : AutoNote.Top = 272
    AutoNote.Width = 404 : AutoNote.Height = 70
    AutoNote.AutoSize = 0
    AutoNote.WordWrap = 1
    AutoNote.Caption = Tr("Слово проверяется на третьей букве (по началам слов словаря) и после пробела ") _
        & Tr("(по словарю): если в текущей раскладке его нет, а в другой есть, оно перепечатывается ") _
        & Tr("и раскладка меняется. Break сразу после этого возвращает слово.")

    ' Правила переключения
    RulesNote.Parent = RulesPage
    RulesNote.Left = 0 : RulesNote.Top = 0
    RulesNote.Width = 420 : RulesNote.Height = 44
    RulesNote.AutoSize = 0
    RulesNote.WordWrap = 1
    RulesNote.Caption = Tr("Правила автопереключения: при наборе каких слов переключать раскладку, ") _
        & Tr("а при каких нет. Проверяются по порядку, действует первое подходящее.")
    RulesView.Parent = RulesPage
    RulesView.Left = 0 : RulesView.Top = 48
    RulesView.Width = 420 : RulesView.Height = 222
    RulesView.ViewStyle = 3
    RulesView.RowSelect = 1
    RulesView.ReadOnly = 1
    RulesView.HideSelection = 0
    RulesView.AddColumns(Tr("Сочетание"), Tr("Условие"), Tr("Регистр"), Tr("Действие"))
    RulesView.Column(0).Width = 100
    RulesView.Column(1).Width = 100
    RulesView.Column(2).Width = 100
    RulesView.Column(3).Width = 110
    PlaceButton(AddRuleButton, RulesPage, Tr("Добавить..."), 0, 278, 100)
    PlaceButton(EditRuleButton, RulesPage, Tr("Изменить..."), 108, 278, 100)
    PlaceButton(DeleteRuleButton, RulesPage, Tr("Удалить"), 216, 278, 100)
    AddRuleButton.OnClick = @OnAddRuleClick
    EditRuleButton.OnClick = @OnEditRuleClick
    DeleteRuleButton.OnClick = @OnDeleteRuleClick
    RulesView.OnDblClick = @OnEditRuleClick
    SuggestRuleCheck.Parent = RulesPage
    SuggestRuleCheck.Left = 0 : SuggestRuleCheck.Top = 316 : SuggestRuleCheck.Width = 250
    SuggestRuleCheck.Caption = Tr("Предлагать добавить правило после")
    SuggestCountEdit.Parent = RulesPage
    SuggestCountEdit.Left = 254 : SuggestCountEdit.Top = 314 : SuggestCountEdit.Width = 36
    SuggestCountEdit.MaxLength = 2
    SuggestCountLabel.Parent = RulesPage
    SuggestCountLabel.Left = 296 : SuggestCountLabel.Top = 317
    SuggestCountLabel.Caption = Tr("отмен подряд")

    ' кнопки окна
    PlaceButton(OkButton, SettingsForm, "OK", 356, 360, 75)
    PlaceButton(CancelButton, SettingsForm, Tr("Отмена"), 436, 360, 75)
    PlaceButton(ApplyButton, SettingsForm, Tr("Применить"), 516, 360, 76)
    OkButton.Default = 1
    CancelButton.Cancel = 1
    OkButton.OnClick = @OnOkClick
    CancelButton.OnClick = @OnCancelClick
    ApplyButton.OnClick = @OnApplyClick

    ' окно правила
    RuleForm.BorderStyle = 3
    RuleForm.ClientWidth = 340
    RuleForm.ClientHeight = 184
    RuleForm.OnShow = @OnRuleFormShow
    RuleTextLabel.Parent = RuleForm
    RuleTextLabel.Left = 12 : RuleTextLabel.Top = 15
    RuleTextLabel.Caption = Tr("Сочетание букв")
    RuleTextEdit.Parent = RuleForm
    RuleTextEdit.Left = 120 : RuleTextEdit.Top = 12 : RuleTextEdit.Width = 208
    RuleTextEdit.MaxLength = 60
    PlaceRuleCombo(RuleCondCombo, RuleCondLabel, Tr("Условие"), 44)
    PlaceRuleCombo(RuleCaseCombo, RuleCaseLabel, Tr("Регистр"), 76)
    PlaceRuleCombo(RuleActionCombo, RuleActionLabel, Tr("Действие"), 108)
    RuleCondCombo.AddItems(Tr(RuleConditionNames(0)), Tr(RuleConditionNames(1)), Tr(RuleConditionNames(2)), _
        Tr(RuleConditionNames(3)))
    RuleCaseCombo.AddItems(Tr(RuleCaseNames(0)), Tr(RuleCaseNames(1)))
    RuleActionCombo.AddItems(Tr(RuleActionNames(0)), Tr(RuleActionNames(1)))
    PlaceButton(RuleOkButton, RuleForm, "OK", 172, 148, 75)
    PlaceButton(RuleCancelButton, RuleForm, Tr("Отмена"), 253, 148, 75)
    RuleOkButton.Default = 1
    RuleCancelButton.Cancel = 1
    RuleOkButton.OnClick = @OnRuleOkClick
    RuleCancelButton.OnClick = @OnRuleCancelClick

    ' окно записи сочетания
    CaptureForm.Caption = Tr("Назначить сочетание")
    CaptureForm.BorderStyle = 3
    CaptureForm.ClientWidth = 360
    CaptureForm.ClientHeight = 110
    CaptureForm.OnShow = @OnCaptureShow
    CaptureLabel.Parent = CaptureForm
    CaptureLabel.Left = 12 : CaptureLabel.Top = 12
    CaptureLabel.Width = 336 : CaptureLabel.Height = 56
    CaptureLabel.AutoSize = 0
    CaptureLabel.WordWrap = 1
    PlaceButton(CaptureCancelButton, CaptureForm, Tr("Отмена"), 272, 76, 76)
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

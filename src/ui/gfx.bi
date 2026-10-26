' ---------------------------------------------------------------------------
'  gfx.bi - картинки через GDI+ (плоский API gdiplus.dll): флажок из png
'  или текстовый флажок, значок (HICON) нужного размера.
'  Объявления свои, как в winapi.bi; GpStatus 0 - успех.
'
'  Часть LangBarFB (https://github.com/diakin/LangBarFB), лицензия LGPL-3.0
'  (COPYING.LESSER и COPYING в корне репозитория).
' ---------------------------------------------------------------------------

#pragma once

#include once "../core/winapi.bi"

Const GP_PIXEL_FORMAT_32BPP_ARGB = &h26200A
Const GP_UNIT_PIXEL = 2
Const GP_INTERPOLATION_HIGH_QUALITY_BICUBIC = 7
Const GP_SMOOTHING_ANTIALIAS = 4
Const GP_TEXT_RENDERING_ANTIALIAS_GRIDFIT = 3
Const GP_STRING_ALIGNMENT_CENTER = 1
Const GP_FONT_STYLE_BOLD = 1

Type GpStartupInput
    GdiplusVersion As ULong
    DebugEventCallback As Any Ptr
    SuppressBackgroundThread As Long
    SuppressExternalCodecs As Long
End Type

Type GpRectF
    PosX As Single
    PosY As Single
    RectWidth As Single
    RectHeight As Single
End Type

Declare Function GdiplusStartup Lib "gdiplus" Alias "GdiplusStartup" ( _
    ByRef Token As UInteger, ByRef StartupInput As GpStartupInput, ByVal StartupOutput As Any Ptr) As Long
Declare Sub GdiplusShutdown Lib "gdiplus" Alias "GdiplusShutdown" (ByVal Token As UInteger)
Declare Function GdipCreateBitmapFromFile Lib "gdiplus" Alias "GdipCreateBitmapFromFile" ( _
    ByVal FileName As WString Ptr, ByRef Bitmap As Any Ptr) As Long
Declare Function GdipCreateBitmapFromScan0 Lib "gdiplus" Alias "GdipCreateBitmapFromScan0" ( _
    ByVal BmpWidth As Long, ByVal BmpHeight As Long, ByVal Stride As Long, _
    ByVal PixelFormat As Long, ByVal Scan0 As Any Ptr, ByRef Bitmap As Any Ptr) As Long
Declare Function GdipGetImageWidth Lib "gdiplus" Alias "GdipGetImageWidth" ( _
    ByVal Image As Any Ptr, ByRef ImgWidth As ULong) As Long
Declare Function GdipGetImageHeight Lib "gdiplus" Alias "GdipGetImageHeight" ( _
    ByVal Image As Any Ptr, ByRef ImgHeight As ULong) As Long
Declare Function GdipDisposeImage Lib "gdiplus" Alias "GdipDisposeImage" (ByVal Image As Any Ptr) As Long
Declare Function GdipGetImageGraphicsContext Lib "gdiplus" Alias "GdipGetImageGraphicsContext" ( _
    ByVal Image As Any Ptr, ByRef Graphics As Any Ptr) As Long
Declare Function GdipDeleteGraphics Lib "gdiplus" Alias "GdipDeleteGraphics" (ByVal Graphics As Any Ptr) As Long
Declare Function GdipSetInterpolationMode Lib "gdiplus" Alias "GdipSetInterpolationMode" ( _
    ByVal Graphics As Any Ptr, ByVal Mode As Long) As Long
Declare Function GdipSetSmoothingMode Lib "gdiplus" Alias "GdipSetSmoothingMode" ( _
    ByVal Graphics As Any Ptr, ByVal Mode As Long) As Long
Declare Function GdipSetTextRenderingHint Lib "gdiplus" Alias "GdipSetTextRenderingHint" ( _
    ByVal Graphics As Any Ptr, ByVal Mode As Long) As Long
Declare Function GdipDrawImageRectI Lib "gdiplus" Alias "GdipDrawImageRectI" ( _
    ByVal Graphics As Any Ptr, ByVal Image As Any Ptr, ByVal PosX As Long, ByVal PosY As Long, _
    ByVal DrawWidth As Long, ByVal DrawHeight As Long) As Long
Declare Function GdipCreateSolidFill Lib "gdiplus" Alias "GdipCreateSolidFill" ( _
    ByVal ArgbColor As ULong, ByRef Brush As Any Ptr) As Long
Declare Function GdipDeleteBrush Lib "gdiplus" Alias "GdipDeleteBrush" (ByVal Brush As Any Ptr) As Long
Declare Function GdipFillRectangleI Lib "gdiplus" Alias "GdipFillRectangleI" ( _
    ByVal Graphics As Any Ptr, ByVal Brush As Any Ptr, ByVal PosX As Long, ByVal PosY As Long, _
    ByVal FillWidth As Long, ByVal FillHeight As Long) As Long
Declare Function GdipCreateFontFamilyFromName Lib "gdiplus" Alias "GdipCreateFontFamilyFromName" ( _
    ByVal FamilyName As WString Ptr, ByVal FontCollection As Any Ptr, ByRef FontFamily As Any Ptr) As Long
Declare Function GdipDeleteFontFamily Lib "gdiplus" Alias "GdipDeleteFontFamily" (ByVal FontFamily As Any Ptr) As Long
Declare Function GdipCreateFont Lib "gdiplus" Alias "GdipCreateFont" ( _
    ByVal FontFamily As Any Ptr, ByVal EmSize As Single, ByVal FontStyle As Long, _
    ByVal SizeUnit As Long, ByRef GpFont As Any Ptr) As Long
Declare Function GdipDeleteFont Lib "gdiplus" Alias "GdipDeleteFont" (ByVal GpFont As Any Ptr) As Long
Declare Function GdipCreateStringFormat Lib "gdiplus" Alias "GdipCreateStringFormat" ( _
    ByVal FormatFlags As Long, ByVal Language As UShort, ByRef StringFormat As Any Ptr) As Long
Declare Function GdipDeleteStringFormat Lib "gdiplus" Alias "GdipDeleteStringFormat" ( _
    ByVal StringFormat As Any Ptr) As Long
Declare Function GdipSetStringFormatAlign Lib "gdiplus" Alias "GdipSetStringFormatAlign" ( _
    ByVal StringFormat As Any Ptr, ByVal Align As Long) As Long
Declare Function GdipSetStringFormatLineAlign Lib "gdiplus" Alias "GdipSetStringFormatLineAlign" ( _
    ByVal StringFormat As Any Ptr, ByVal Align As Long) As Long
Declare Function GdipDrawString Lib "gdiplus" Alias "GdipDrawString" ( _
    ByVal Graphics As Any Ptr, ByVal Text As WString Ptr, ByVal TextLength As Long, _
    ByVal GpFont As Any Ptr, ByRef LayoutRect As GpRectF, ByVal StringFormat As Any Ptr, _
    ByVal Brush As Any Ptr) As Long
Declare Function GdipCreateHBITMAPFromBitmap Lib "gdiplus" Alias "GdipCreateHBITMAPFromBitmap" ( _
    ByVal Bitmap As Any Ptr, ByRef BitmapHandle As Any Ptr, ByVal Background As ULong) As Long
Declare Function GdipCreateHICONFromBitmap Lib "gdiplus" Alias "GdipCreateHICONFromBitmap" ( _
    ByVal Bitmap As Any Ptr, ByRef IconHandle As Any Ptr) As Long

Dim Shared GfxToken As UInteger

Function GfxStart() As Long
    If GfxToken <> 0 Then Return 1
    Dim StartupInput As GpStartupInput
    StartupInput.GdiplusVersion = 1
    Return IIf(GdiplusStartup(GfxToken, StartupInput, 0) = 0, 1, 0)
End Function

Sub GfxStop()
    If GfxToken <> 0 Then
        GdiplusShutdown(GfxToken)
        GfxToken = 0
    End If
End Sub

' Строка Windows (CP_ACP) -> UTF-16 для GDI+
Private Function GfxWide(ByRef AnsiText As String) As WString Ptr
    Dim WideLen As Long = LbMultiByteToWideChar(LB_CP_ACP, 0, StrPtr(AnsiText), -1, 0, 0)
    If WideLen <= 0 Then WideLen = 1
    Dim WideText As WString Ptr = Allocate((WideLen + 1) * SizeOf(WString))
    LbMultiByteToWideChar(LB_CP_ACP, 0, StrPtr(AnsiText), -1, WideText, WideLen)
    WideText[WideLen] = 0
    Return WideText
End Function

' Картинка из файла (png, bmp, ico...); 0 - нет файла или не читается.
' Освобождать GfxFreeImage.
Function GfxLoadImage(ByRef FileName As String) As Any Ptr
    If FileName = "" Then Return 0
    Dim WideName As WString Ptr = GfxWide(FileName)
    Dim Image As Any Ptr
    If GdipCreateBitmapFromFile(WideName, Image) <> 0 Then Image = 0
    Deallocate(WideName)
    Return Image
End Function

Sub GfxFreeImage(ByRef Image As Any Ptr)
    If Image <> 0 Then
        GdipDisposeImage(Image)
        Image = 0
    End If
End Sub

' Высота флажка при ширине FlagWidth: по пропорциям картинки, без неё 3:4
Function GfxFlagHeight(ByVal FlagImage As Any Ptr, ByVal FlagWidth As Long) As Long
    Dim FlagHeight As Long = FlagWidth * 3 \ 4
    If FlagImage <> 0 Then
        Dim ImgWidth As ULong, ImgHeight As ULong
        GdipGetImageWidth(FlagImage, ImgWidth)
        GdipGetImageHeight(FlagImage, ImgHeight)
        If ImgWidth > 0 Then FlagHeight = CLng(FlagWidth * ImgHeight \ ImgWidth)
    End If
    If FlagHeight < 1 Then FlagHeight = 1
    Return FlagHeight
End Function

' Рисует флажок в прямоугольник: картинку FlagImage (если не 0) или
' прямоугольник цвета FlagColor (&hRRGGBB) с подписью Label
Sub GfxDrawFlag(ByVal Graphics As Any Ptr, ByVal FlagImage As Any Ptr, ByRef Label As String, _
        ByVal FlagColor As ULong, ByVal PosX As Long, ByVal PosY As Long, _
        ByVal FlagWidth As Long, ByVal FlagHeight As Long)
    GdipSetInterpolationMode(Graphics, GP_INTERPOLATION_HIGH_QUALITY_BICUBIC)
    GdipSetSmoothingMode(Graphics, GP_SMOOTHING_ANTIALIAS)
    If FlagImage <> 0 Then
        GdipDrawImageRectI(Graphics, FlagImage, PosX, PosY, FlagWidth, FlagHeight)
        Exit Sub
    End If

    Dim FillBrush As Any Ptr, TextBrush As Any Ptr
    GdipCreateSolidFill(&hFF000000 Or (FlagColor And &hFFFFFF), FillBrush)
    GdipFillRectangleI(Graphics, FillBrush, PosX, PosY, FlagWidth, FlagHeight)
    GdipDeleteBrush(FillBrush)

    Dim FontFamily As Any Ptr, LabelFont As Any Ptr, LabelFormat As Any Ptr
    Dim FamilyName As WString * 8 = "Arial"
    GdipCreateFontFamilyFromName(@FamilyName, 0, FontFamily)
    GdipCreateFont(FontFamily, FlagHeight * 0.8, GP_FONT_STYLE_BOLD, GP_UNIT_PIXEL, LabelFont)
    GdipCreateStringFormat(0, 0, LabelFormat)
    GdipSetStringFormatAlign(LabelFormat, GP_STRING_ALIGNMENT_CENTER)
    GdipSetStringFormatLineAlign(LabelFormat, GP_STRING_ALIGNMENT_CENTER)
    GdipSetTextRenderingHint(Graphics, GP_TEXT_RENDERING_ANTIALIAS_GRIDFIT)
    GdipCreateSolidFill(&hFFFFFFFF, TextBrush)
    Dim LabelRect As GpRectF
    LabelRect.PosX = PosX - FlagWidth * 0.1 : LabelRect.PosY = PosY
    LabelRect.RectWidth = FlagWidth * 1.2 : LabelRect.RectHeight = FlagHeight
    Dim WideLabel As WString Ptr = GfxWide(Label)
    GdipDrawString(Graphics, WideLabel, -1, LabelFont, LabelRect, LabelFormat, TextBrush)
    Deallocate(WideLabel)
    GdipDeleteBrush(TextBrush)
    GdipDeleteStringFormat(LabelFormat)
    GdipDeleteFont(LabelFont)
    GdipDeleteFontFamily(FontFamily)
End Sub

' Пустая прозрачная картинка 32 бит с альфа-каналом; освобождать GfxFreeImage
Function GfxNewCanvas(ByVal CanvasWidth As Long, ByVal CanvasHeight As Long) As Any Ptr
    Dim Canvas As Any Ptr
    If GdipCreateBitmapFromScan0(CanvasWidth, CanvasHeight, 0, GP_PIXEL_FORMAT_32BPP_ARGB, 0, Canvas) <> 0 Then Return 0
    Return Canvas
End Function

' Квадратный значок IconSize x IconSize: флажок растянут на весь значок.
' Освобождать LbDestroyIcon.
Function GfxMakeFlagIcon(ByVal FlagImage As Any Ptr, ByRef Label As String, _
        ByVal FlagColor As ULong, ByVal IconSize As Long) As Any Ptr
    Dim Canvas As Any Ptr = GfxNewCanvas(IconSize, IconSize)
    If Canvas = 0 Then Return 0
    Dim Graphics As Any Ptr, IconHandle As Any Ptr
    GdipGetImageGraphicsContext(Canvas, Graphics)
    ' флажок растягивается на весь квадрат значка: так он крупнее в трее
    GfxDrawFlag(Graphics, FlagImage, Label, FlagColor, 0, 0, IconSize, IconSize)
    GdipDeleteGraphics(Graphics)
    If GdipCreateHICONFromBitmap(Canvas, IconHandle) <> 0 Then IconHandle = 0
    GdipDisposeImage(Canvas)
    Return IconHandle
End Function

' Флажок FlagWidth в ширину как картинка GDI+ (для окон overlay.bi);
' освобождать GfxFreeImage
Function GfxMakeFlagImage(ByVal FlagImage As Any Ptr, ByRef Label As String, _
        ByVal FlagColor As ULong, ByVal FlagWidth As Long) As Any Ptr
    Dim FlagHeight As Long = GfxFlagHeight(FlagImage, FlagWidth)
    Dim Canvas As Any Ptr = GfxNewCanvas(FlagWidth, FlagHeight)
    If Canvas = 0 Then Return 0
    Dim Graphics As Any Ptr
    GdipGetImageGraphicsContext(Canvas, Graphics)
    GfxDrawFlag(Graphics, FlagImage, Label, FlagColor, 0, 0, FlagWidth, FlagHeight)
    GdipDeleteGraphics(Graphics)
    Return Canvas
End Function

object HistogramWin: THistogramWin
  Left = 1057
  Top = 391
  Width = 223
  Height = 100
  Caption = 'Histogram'
  Color = clBtnFace
  Constraints.MinHeight = 100
  Constraints.MinWidth = 100
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'MS Sans Serif'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  OnMouseDown = FormMouseDown
  OnMouseMove = FormMouseMove
  OnMouseUp = FormMouseUp
  OnPaint = FormPaint
  OnResize = FormResize
  PixelsPerInch = 96
  TextHeight = 13
  object Button1: TButton
    Left = 169
    Top = 1
    Width = 45
    Height = 17
    Anchors = [akTop, akRight]
    Caption = 'Refresh'
    TabOrder = 0
    OnClick = Button1Click
  end
end
#NoEnv
SetBatchLines, -1
#Include ABA.ahk
ABAFile := "ABA_Test.bin"
If !(ABA1 := ABA_Create(ABAFile, True)) {
   MsgBox, 48, File error!, Error opening %ABAFile% for reading. (%ErrorLevel%)
   ExitApp
}
Gui, Margin, 10, 10
Gui, Color, Black
Gui, Font, s24, Arial
Gui, Add, Pic, xm vPic hwndHPIC, % "HBITMAP:" . ABA1.GetBitmap(1, W, H, True)
Gui, Add, Text, xp xp hp wp vEnd +Hidden +Center +0x200 cWhite, THE END
Gui, Show, , ABA Test
HDC := DllCall("GetDC", "Ptr", HPIC, "UPtr")
MDC := DllCall("CreateCompatibleDC", "Ptr", HDC, "UPtr")
Loop {
   OBM := DllCall("SelectObject", "Ptr", MDC, "Ptr", ABA1.GetBitmap(A_Index, , , True))
	DllCall("BitBlt", "Ptr", HDC, "Int", 0, "Int", 0, "Int", W, "Int", H, "Ptr", MDC, "Int", 0, "Int", 0, "UInt", 0x00CC0020)
   DllCall("DeleteObject", "Ptr", OBM)
   Sleep, 60
} Until (A_Index >= ABA1.EntryCount)
GuiControl, Show, End
DllCall("DeleteDC", "Ptr", MDC)
DllCall("ReleaseDC", "Ptr", HPIC, "Ptr", HDC)
Return
GuiClose:
ExitApp
CreateResources() {
   Return False
   FileInstall, ABA_Test.bin, -
}
#NoEnv
SetBatchLines, -1
SetWinDelay, 0
#Include ABAED.ahk
; Context menus ====================================================================================================================
ContextMenus := ["ContextFile", "ContextStr", "ContextData"]
; ----------------------------------------------------------------------------------------------------------------------------------
Menu, ContextFile, Add, Show picture, ContextShowPic
Menu, ContextFile, Add
Menu, ContextFile, Add, Extract, ContextExtract
Menu, ContextFile, Add, Delete, ContextDelete
Menu, ContextFile, Add
Menu, ContextFile, Add, Replace file, ContextReplaceFile
Menu, ContextFile, Add, Update file, ContextUpdateFile
; ----------------------------------------------------------------------------------------------------------------------------------
Menu, ContextStr, Add, Show string, ContextShowStr
Menu, ContextStr, Add
Menu, ContextStr, Add, Delete, ContextDelete
Menu, ContextStr, Add
Menu, ContextStr, Add, Update string, ContextReplaceStr
; ----------------------------------------------------------------------------------------------------------------------------------
Menu, ContextData, Add, Show picture, ContextShowPic
Menu, ContextData, Add
Menu, ContextData, Add, Delete, ContextDelete
; ----------------------------------------------------------------------------------------------------------------------------------
Menu, ContextMulti, Add, Delete selected, ContextMultiDelete
Menu, ContextMulti, Add, Extract selected, ContextMultiExtract
; Main GUI menubar =================================================================================================================
Menu, File, Add, New`tCtrl+n, FileNewABA
Menu, File, Add, Open`tCtrl+o, FileOpenABA
Menu, File, Add, Save`tCtrl+s, FileSaveABA
Menu, File, Add
Menu, File, Add, Open BRA, FileOpenBRA
Menu, File, Add
Menu, File, Add, Exit`tCtrl+x, MainGuiClose
; ----------------------------------------------------------------------------------------------------------------------------------
Menu, Edit, Add, Add Files, EditAddFiles
Menu, Edit, Add, Add String, EditAddstring
; ----------------------------------------------------------------------------------------------------------------------------------
Menu, GuiMenu, Add, &File, :File
Menu, GuiMenu, Add, &Edit, :Edit
; Main GUI =========================================================================================================================
Gui, Main:New, +Resize
Gui, Menu, GuiMenu
Gui, Margin, 0, 0
Gui, Add, ListView, w800 r20 vABALV hwndHABALV, #|Name|Type|Size|%A_Space%
LV_ModifyCol(1, "Integer")
LV_ModifyCol(4, "Integer")
Gui, Add, StatusBar, vSB
GuiControlGet, SB, Pos
Gui, Show, , ABA Editor
Return
; ==================================================================================================================================
; Main GUI labels
; ==================================================================================================================================
MainGuiClose:
ExitApp
; ----------------------------------------------------------------------------------------------------------------------------------
MainGuiContextMenu:
If (A_GuiControl = "ABALV") && (EntryRow := LV_GetNext()) {
   If (LV_GetCount("Selected") > 1)
      Menu, ContextMulti, Show
   Else {
      LV_GetText(EntryIndex, EntryRow, 1)
      LV_GetText(EntryName, EntryRow, 2)
      LV_GetText(EntryType, EntryRow, 3)
      Menu, % ContextMenus[EntryType], Show
   }
}
Return
; ----------------------------------------------------------------------------------------------------------------------------------
MainGuiDropFiles:
FileNames := StrSplit(A_GuiEvent, "`n")
AddFiles(HABALV, ABAObj, FileNames)
Return
; ----------------------------------------------------------------------------------------------------------------------------------
MainGuiSize:
If (A_EventInfo <> 1)
   GuiControl, Move, ABALV, % "w" . A_GuiWidth . " h" . (A_GuiHeight - SBH)
Return
; ==================================================================================================================================
; File menu
; ==================================================================================================================================
FileNewABA:
Gui, Main:Default
Gui, +OwnDialogs
If !(ABAObj := ABAED_Create("")) {
   MsgBox, 16, Error!, Could not create a newABA object!`nError: %ErrorLevel%
   Return
}
ABAFile := ABAObj.FilePath
ReloadListView(HABALV, ABAObj)
WinSetTitle, ABA Editor - %ABAFile%
Return
; ----------------------------------------------------------------------------------------------------------------------------------
FileOpenABA:
Gui, Main:Default
Gui, +OwnDialogs
FileSelectFile, ABAFile, 3, %A_ScriptDir%, Select an ABA file, ABA files (*.bin)
If (ErrorLevel)
   Return
If !(ABAObj := ABAED_Create(ABAFile)) {
   MsgBox, 16, Error!, %ABAFile% is not a valid ABA file!`nError: %ErrorLevel%
   Return
}
ReloadListView(HABALV, ABAObj)
WinSetTitle, ABA Editor - %ABAFile%
Return
; ----------------------------------------------------------------------------------------------------------------------------------
FileSaveABA:
Gui, Main:Default
Gui, +OwnDialogs
ABAFile := ABAObj.FilePath
FileSelectFile, FileName, S18, %ABAFile%, Save the ABA file, ABA files (*.bin)
If (ErrorLevel)
   Return
If !ABAObj.Save(FileName) {
   MsgBox, 16, Error!, Could not save %FileName%!`nError: %ErrorLevel%
   Return
}
WinSetTitle, ABA Editor - %FileName%
Return
; ----------------------------------------------------------------------------------------------------------------------------------
FileOpenBRA:
Gui, Main:Default
Gui, +OwnDialogs
FileSelectFile, BRAFile, 3, %A_ScriptDir%, Select a BRA file, BRA files (*.bra)
If (ErrorLevel)
   Return
If !(ABAObj := ABAED_Create(BRAFile)) {
   MsgBox, 16, Error!, %BRAFile% is not a valid BRA file!`nError: %ErrorLevel%
   Return
}
ABAFile := ABAObj.FilePath
ReloadListView(HABALV, ABAObj)
WinSetTitle, ABA Editor - %ABAFile%
Return
; ==================================================================================================================================
; Edit menu:
; ==================================================================================================================================
EditAddstring:
Gui, Main:Default
Gui, +OwnDialogs
EntryName := EntryStr := "", Encode := False
Gosub, AddStrGui
If (EntryName <> "") && (EntryStr <> "") {
   Gui, Main:Default
   Gui, +OwnDialogs
   If !(Index := ABAObj.AddString(EntryName, EntryStr, Encode)) {
      MsgBox, 16, Error!, Could not add string entry %EntryName%`n`nError: %ErrorLevel%!
      Return
   }
   Entry := ABAObj.Entries[Index]
   GuiControl, -Redraw, ABALV
   LV_Modify(LV_Add("", Index, Entry.Name, Entry.Type, Entry.Size), "Vis")
   Loop, 4
      LV_ModifyCol(A_Index, "AutoHdr")
   GuiControl, +Redraw, ABALV
   SB_SetText("   Number of entries: " . ABAObj.EntryCount)
}
Return
; ----------------------------------------------------------------------------------------------------------------------------------
EditAddFiles:
Gui, Main:Default
Gui, +OwnDialogs
FileSelectFile, FileNames, M3, %A_ScriptDir%, Select the files to add
If (ErrorLevel)
   Return
FileNames := StrSplit(FileNames, "`n")
Folder := RTrim(FileNames.RemoveAt(1), "\")
For Index, FileName In FileNames
   FileNames[Index] := Folder . "\" . FileName
AddFiles(HABALV, ABAObj, FileNames)
Return
; ==================================================================================================================================
; Context menu
; ==================================================================================================================================
ContextExtract:
Gui, Main:Default
Gui, +OwnDialogs
FileSelectFile, FileName, S18, %EntryName%, Save the entry %EntryName% as file
If (ErrorLevel)
   Return
If !ABAObj.ExtractFile(EntryIndex, FileName) {
   MsgBox, 16, Error!, Could not save %EntryName% as %FileName%!`nError: %ErrorLevel%
   Return
}
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextDelete:
Gui, Main:Default
Gui, +OwnDialogs
If !ABAObj.DeleteEntries(EntryIndex) {
   MsgBox, 16, Error!, Could not delete %EntryName%!
   Return
}
ReloadListView(HABALV, ABAObj, True)
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextReplaceFile:
Gui, Main:Default
Gui, +OwnDialogs
If (EntryType <> 1) {
   MsgBox, 16, Error!, %EntryName% is not a file entry!
   Return
}
FileSelectFile, FileName, 3, %EntryName%, Select the file to replace %EntryName% with
If (ErrorLevel)
   Return
If !ABAObj.ReplaceFile(EntryIndex, FileName) {
   MsgBox, 16, Error!, Could not replace %EntryName% with %FileName%!`nError: %ErrorLevel%
   Return
}
GuiControl, -Redraw, ABALV
LV_Modify(EntryRow, "Col2", ABAObj.Entries[EntryIndex, "Name"])
LV_ModifyCol(2, "AutoHdr")
LV_Modify(EntryRow, "Col4", ABAObj.Entries[EntryIndex, "Size"])
LV_ModifyCol(4, "AutoHdr")
GuiControl, +Redraw, ABALV
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextReplaceStr:
Gui, Main:Default
Gui, +OwnDialogs
If (EntryType <> 2) {
   MsgBox, 16, Error!, %EntryName% is not a string entry!
   Return
}
NewEntryStr := ""
Encoded := ABAObj.Entries[EntryIndex, "Enc"]
Gosub, ReplStrGui
If (NewEntryStr <> "") {
   Gui, Main:Default
   Gui, +OwnDialogs
   If !ABAObj.ReplaceString(EntryIndex, NewEntryStr, Encode) {
      MsgBox, 16, Error!, Could not replace the string for %EntryName%!`nError: %ErrorLevel%
      Return
   }
   GuiControl, -Redraw, ABALV
   LV_Modify(EntryRow, "Col4", ABAObj.Entries[EntryIndex, "Size"])
   LV_ModifyCol(4, "AutoHdr")
   GuiControl, +Redraw, ABALV
}
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextShowPic:
Gui, Main:+OwnDialogs
If (EntryType = 2) {
   MsgBox, 16, Error!, %EntryName% is a string entry!
   Return
}
If !(HBITMAP := ABAObj.GetBitmap(EntryIndex, BitmapWidth, BitmapHeight, True)) {
   MsgBox, 16, Error!, %EntryName% does not contain a bitmap!
   Return
}
Gosub, ShowPicGui
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextShowStr:
Gui, Main:+OwnDialogs
If (EntryType <> 2) {
   MsgBox, 16, Error!, %EntryName% is not a string entry!
   Return
}
If !(EntryStr := ABAObj.GetString(EntryIndex)) {
   MsgBox, 16, Error!, %EntryName% does not contain a string!
   Return
}
Gosub, ShowStrGui
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextUpdateFile:
Gui, Main:Default
Gui, +OwnDialogs
If (EntryType <> 1) {
   MsgBox, 16, Error!, %EntryName% is not a file entry!
   Return
}
If !ABAObj.ReplaceFile(EntryIndex) {
   MsgBox, 16, Error!, Could not update %EntryName%!`nError: %ErrorLevel%
   Return
}
Return
; ==================================================================================================================================
; Context menu for multiple entries
; ==================================================================================================================================
ContextMultiExtract:
Gui, Main:Default
Gui, +OwnDialogs
UseInternalNames := False
MsgBox, 36, Extract files, Do you want to extract all files using the internal names and overwrite existing files?
IfMsgBox, Yes
   UseInternalNames := True
ExtractFiles := []
While (Row := LV_GetNext(Row)) {
   LV_GetText(EntryName, Row, 2)
   LV_GetText(EntryType, Row, 3)
   If (EntryType <> 1) {
      MsgBox, 20, Error!, %EntryName% is not a file entry and will be skipped!`nDo you want to continue?
      IfMsgBox, Yes
         Continue
      Return
   }
   ExtractFiles.Push(EntryName)
}
For Each, EntryName In ExtractFiles {
   If (UseInternalNames)
      FileName := EntryName
   Else {
      FileSelectFile, FileName, S18, %EntryName%, Save the entry %EntryName% as file
      If (ErrorLevel)
         Return
   }
   If !ABAObj.ExtractFile(EntryName, FileName) {
      MsgBox, 16, Error!, Could not save %EntryName% as %FileName%!`nError: %ErrorLevel%
      Return
   }
}
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ContextMultiDelete:
Gui, Main:Default
Gui, +OwnDialogs
Row := 0
Entries := []
While (Row := LV_GetNext(Row)) {
   LV_GetText(EntryIndex, Row, 1)
   LV_GetText(EntryName, Row, 2)
   Entries[EntryIndex] := EntryName
}
If !ABAObj.DeleteEntries(Entries*) {
   MsgBox, 16, Error!, At least one of the passed entries does not exist!`nEntry: %ErrorLevel%
   Return
}
ReloadListView(HABALV, ABAObj, True)
Return
; ==================================================================================================================================
; Add string GUI
; ==================================================================================================================================
AddStrGui:
Gui, Main:+Disabled
Gui, AddStr:New, +LastFound +ToolWindow +OwnerMain
Gui, Margin, 10, 10
Gui, Add, Text, vT +0x0200, String entry name:
GuiControlGet, T, Pos
W := 600 - TW - 10
Gui, Add, Edit, x+m yp w%W% vEntryName
GuiControlGet, E, Pos, EntryName
GuiControl, Move, T, h%EH%
Gui, Add, Edit, xm w600 r10 vEntryStr
Gui, Add, CheckBox, xm vEncode, Encode
Gui, Add, Button, xm w200 gAddStrGuiOK, OK
Gui, Add, Button, x410 yp wp gAddStrGuiCancel Default, Cancel
Gui, Show, , Add String
WinWaitClose
Return
; ----------------------------------------------------------------------------------------------------------------------------------
AddStrGuiOK:
Gui, +OwnDialogs
Gui, Submit, NoHide
EntryName := Trim(EntryName)
If (EntryName = "") {
   GuiControl, , EntryName
   GuiControl, Focus, EntryName
   MsgBox, 16, Error!, You must specify a name for the entry!
   Return
}
If (EntryStr = "") {
   GuiControl, Focus, EntryStr
   MsgBox, 16, Error!, You must specify the new string for the entry!
   Return
}
Gosub, AddStrGuiClose
Return
; ----------------------------------------------------------------------------------------------------------------------------------
AddStrGuiCancel:
EntryName := EntryStr := "", Encode := False
; ----------------------------------------------------------------------------------------------------------------------------------
AddStrGuiClose:
Gui, Main:-Disabled
Gui, Destroy
Return
; ==================================================================================================================================
; Replace string GUI
; ==================================================================================================================================
ReplStrGui:
Gui, Main:+Disabled
Gui, AddStr:New, +LastFound +ToolWindow +OwnerMain
Gui, Margin, 10, 10
Gui, Add, Text, , Current string:
Gui, Add, Edit, xm y+5 w0 h0
Gui, Add, Edit, xp yp w600 r10 +ReadOnly +hwndHED
GuiControl, , %HED%, %EntryStr%
Gui, Add, Text, xm , New string:
Gui, Add, Edit, xm y+5 w600 r10 vNewEntryStr +hwndHED
GuiControl, , %HED%, %EntryStr%
Gui, Add, Checkbox, vEncode Checked%Encoded%, Encode
Gui, Add, Button, xm w200 gReplStrGuiOK, OK
Gui, Add, Button, x410 yp wp gReplStrGuiCancel Default, Cancel
Gui, Show, , Replace String - %EntryName%
WinWaitClose
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ReplStrGuiOK:
Gui, +OwnDialogs
Gui, Submit, NoHide
If (NewEntryStr = "") {
   GuiControl, Focus, NewEntryStr
   MsgBox, 16, Error!, You must specify the new string for the entry!
   Return
}
Gosub, AddStrGuiClose
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ReplStrGuiCancel:
NewEntryStr := ""
; ----------------------------------------------------------------------------------------------------------------------------------
ReplStrGuiClose:
Gui, Main:-Disabled
Gui, Destroy
Return
; ==================================================================================================================================
; Show picture GUI
; ==================================================================================================================================
ShowPicGui:
Gui, Main:+Disabled
Gui, ShowPic:New, +LastFound +ToolWindow +OwnerMain
Gui, Margin, 0, 0
Gui, Add, Pic, , HBITMAP:%HBITMAP%
Gui, Show, , Show picture - %EntryName% (%BitmapWidth% x %BitmapHeight%)
WinWaitClose
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ShowPicGuiClose:
Gui, Main:-Disabled
Gui, Destroy
Return
; ==================================================================================================================================
; Show string GUI
; ==================================================================================================================================
ShowStrGui:
Gui, Main:+Disabled
Gui, ShowStr:New, +LastFound +ToolWindow +OwnerMain
Gui, Margin, 10, 10
Gui, Add, Edit, w0 h0
Gui, Add, Edit, xp yp w600 r10 +ReadOnly +hwndHED
GuiControl, , %HED%, %EntryStr%
Gui, Show, , Show string - %EntryName%
WinWaitClose
Return
; ----------------------------------------------------------------------------------------------------------------------------------
ShowStrGuiClose:
Gui, Main:-Disabled
Gui, Destroy
Return
; ==================================================================================================================================
; Functions
; ==================================================================================================================================
AddFiles(HLV, ABAObj, FileNames) {
   GuiControl, -Redraw, %HLV%
   For Each, Filename In FileNames {
      If !(Index := ABAObj.AddFile(FileName)) {
         MsgBox, 36, Error!, Could not add %FileName%`nError: %ErrorLevel%`n`nDo you want to continue?
         IfMsgBox, Yes
            Continue
         Break
      }
      Entry := ABAObj.Entries[Index]
      LV_Modify(LV_Add("", Index, Entry.Name, Entry.Type, Entry.Size), "Vis")
   }
   Loop, 4
      LV_ModifyCol(A_Index, "AutoHdr")
   GuiControl, +Redraw, %HLV%
   SB_SetText("   Number of entries: " . ABAObj.EntryCount)
   Return True
}
; ----------------------------------------------------------------------------------------------------------------------------------
ReloadListView(HLV, ABAObj, SaveScrollPos := False) {
   If (SaveScrollPos) {
      VarSetCapacity(RC, 16, 0)
      DllCall("SendMessage", "Ptr", HLV, "UInt", 0x100E, "Ptr", 0, "Ptr", &RC) ; LVM_GETITEMRECT
      IH := NumGet(RC, 12, "Int") - NumGet(RC, 4, "Int")
      TI := DllCall("SendMessage", "Ptr", HLV, "UInt", 0x1027, "Ptr", 0, "Ptr", 0, "Ptr") ; LVM_GETTOPINDEX
   }
   GuiControl, -Redraw, %HLV%
   LV_Delete()
   For Index, Entry In ABAObj.Entries
      LV_Add("", Index, Entry.Name, Entry.Type, Entry.Size)
   Loop, 4
      LV_ModifyCol(A_Index, "AutoHdr")
   GuiControl, +Redraw, %HLV%
   If (SaveScrollPos)
      DllCall("PostMessage", "Ptr", HLV, "UInt", 0x1014, "Ptr", 0, "Ptr", TI * IH) ; LVM_SCROLL
   SB_SetText("   Number of entries: " . ABAObj.EntryCount)
   Return True
}
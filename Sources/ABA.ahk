; ==================================================================================================================================
; ABA object format:
;     Public properties:
;        EntryCount  number of data entries in the ABA file
;     Public methods:
;        __New()     creates a new ABA obect from the specified file.
;        GetData()   retrieves the entry's raw data.
;        GetPtr()    retrieves a pointer to the entry's data.
;        GetSize()   retrieves the size of the entry's data.
;        GetStr()    retrieves the entry's string.
;        GetBitmap() creates a GDI+ or GDI bitmap from the entry's data, if possible.
; ----------------------------------------------------------------------------------------------------------------------------------
; Functions:
;     ABA_Create()   standard lib compatible wrapper for New ABA.
; ==================================================================================================================================
Class ABA {
   ; ===============================================================================================================================
   ; Public class properties
   ; ===============================================================================================================================
   EntryCount[] {
      Get {
         Return This.HasKey("&") ? NumGet(This["&"] + 44, "UInt") : 0
      }
      Set {
         Return ABA.EntryCount
   }  }
   ; ===============================================================================================================================
   ; Public methods
   ; ===============================================================================================================================
   ; Creates a new ABA instance.
   ; Parameters:
   ;     FileName    The name of the ABA file or resource.
   ;     UseGDIP     If set to True, the Gdiplus.dll will be loaded and initialized automatically.
   ;                 It's needed for GetBitmap() but will also be done internally there, if the Gdiplus.dll isn't already loaded.
   ;     IsResource  If set to true, the file is expected to have been included as a RCDATA resource.
   ; Returns False (0) on failure and sets ErrorLevel to one of the following values:
   ;     1  :  tried to instantiate an ABA instance.
   ;     2  :  could not open / find the ABA file / resource.
   ;     3  :  invalid file / resource format.
   ;     4  :  invalid data entry.
   ; ===============================================================================================================================
   __New(FileName, UseGDIP := False, IsResource := False) {
      Static ES := 16, HS := 48, MC := 557924929
      If (IsObject(This.Base.Base))
         Return !(ErrorLevel := 1)
      If (UseGDIP)
         This.UseGDIP()
      If (IsResource) {
         If !(A_IsCompiled)
         || !(HRSC := DllCall("FindResourceEx", "Ptr", 0, "Str", "#10", "Str", FileName, "UShort", 0, "UPtr"))
         || !(HRES := DllCall("LoadResource", "Ptr", 0, "Ptr", HRSC, "UPtr"))
         || !(PRES := DllCall("LockResource", "Ptr", HRES, "UPtr"))
            Return !(ErrorLevel := 2)
         FS := DllCall("SizeofResource", "Ptr", 0, "Ptr", HRSC, "UInt")
         If (FS < (HS + ES))
            Return !(ErrorLevel := 3)
         This["&"] := PRES
      }
      Else {
      	If !(File := FileOpen(FileName, "r"))
            Return !(ErrorLevel := 2)
         FS := File.Length
         If (File.Pos <> 0) || (FS < (HS + ES))
            Return !(ErrorLevel := 3)
         This.SetCapacity("", FS)
         This["&"] := This.GetAddress("")
         File.RawRead(This["&"], FS)
         File.CLose()
      }
      BA := This["&"]
      M1 := NumGet(BA + 0, "UInt"), M2 := NumGet(BA + 4, "UInt")
      If (M1 <> 0) || (M2 <> MC) ; it's not an ABA file
         Return !(ErrorLevel := 3)
      DO := NumGet(BA + 20, "UInt"), DS := NumGet(BA + 24, "UInt")
      SO := NumGet(BA + 32, "UInt"), SS := NumGet(BA + 36, "UInt")
      EC := NumGet(BA + 44, "UInt")
      If (EC < 1) || (DO <> (HS + (ES * EC))) || (SO <> (DO + DS)) || (FS <> (SO + SS))
         Return !(ErrorLevel := 3)
      NA := [], EA := BA + HS, EM := BA + DO, SA := BA + SO
      Loop, % EC {
         If (EA < EM) && ((SP := NumGet(EA + 0, "UInt")) < SS)
            NA[StrGet(SA + SP, "UTF-8")] := A_Index
         Else
            Return !(ErrorLevel := 4)
         EA += ES
      }
      This["."] := NA
   }
   ; ===============================================================================================================================
   ; Returns the size of the data stored in the buffer in bytes on success, otherwise False (0).
   ; ===============================================================================================================================
   GetData(NameOrIndex, ByRef Buffer) {
      Buffer := ""
      If !(DP := This.GetPtr(NameOrIndex, DS))
         Return False
      VarSetCapacity(Buffer, DS, 0)
      DllCall("RtlMoveMemory", "Ptr", &Buffer, "Ptr", DP, "Ptr", DS)
      Return DS
   }
   ; ===============================================================================================================================
   ; Returns a pointer to the entry's data on success, otherwise False (0).
   ; ===============================================================================================================================
   GetPtr(NameOrIndex, ByRef Size := "") {
      Static ES := 16, HS := 48
      Size := 0
      IX := This["."].HasKey(NameOrIndex) ? This["." , NameOrIndex] : NameOrIndex
      If !This.IsValidIX(IX)
         Return False
      BA := This["&"], DO := NumGet(BA + 20, "UInt"), EA := BA + HS + ((IX - 1) * ES), OF := NumGet(EA + 8, "UInt")
      Size := NumGet(EA + 12, "UInt")
      Return (BA + DO + OF)
   }
   ; ===============================================================================================================================
   ; Returns the size of the entry's data on success, otherwise False (0).
   ; ===============================================================================================================================
   GetSize(NameOrIndex) {
      Static ES := 16, HS := 48
      IX := This["."].HasKey(NameOrIndex) ? This["." , NameOrIndex] : NameOrIndex
      If !This.IsValidIX(IX)
         Return False
      EA := This["&"] + HS + ((IX - 1) * ES)
      Return NumGet(EA + 12, "UInt")
   }
   ; ===============================================================================================================================
   ; Returns the entry's string on success, otherwise False (0).
   ; ===============================================================================================================================
   GetStr(NameOrIndex) {
      Static ES := 16, HS := 48
      Size := 0
      IX := This["."].HasKey(NameOrIndex) ? This["." , NameOrIndex] : NameOrIndex
      If !This.IsValidIX(IX)
         Return False
      BA := This["&"], DO := NumGet(BA + 20, "UInt"), EA := BA + HS + ((IX - 1) * ES)
      If (NumGet(EA + 4, "UShort") <> 2)
         Return False
      EN := NumGet(EA + 6, "UShort"), OF := NumGet(EA + 8, "UInt"), SA := BA + DO + OF
      ErrorLevel :=
      Return (EN ? This.DS(SA) : StrGet(SA + 0, "UTF-8"))
   }
   ; ===============================================================================================================================
   ; Returns a GDI+ or GDI bitmap handle on success, otherwise False (0).
   ; ===============================================================================================================================
   GetBitmap(NameOrIndex, ByRef Width := 0, ByRef Height := 0, HBITMAP := False) {
      Static ShlwAPI := DllCall("LoadLibrary", "Str", "Shlwapi.dll", "UPtr")
      Static XP := (DllCall("GetVersion", "UChar") < 6)
      Static CreateStream := DllCall("GetProcAddress", "Ptr", ShlwAPI, XP ? "Ptr" : "AStr", XP ? 12 : "SHCreateMemStream", "UPtr")
      GdiBitmap := GdipBitmap := Width := Height := 0
      If !(DP := This.GetPtr(NameOrIndex, DS))
         Return False
      If !DllCall("GetModuleHandle", "Str", "Gdiplus.dll", "UPtr")
         This.UseGDIP()
      If !(Stream := DllCall(CreateStream, "Ptr", DP, "UInt", DS, "UPtr"))
         Return False
      DllCall("Gdiplus.dll\GdipCreateBitmapFromStream", "Ptr", Stream, "PtrP", GdipBitmap)
      DllCall("Gdiplus.dll\GdipGetImageWidth", "Ptr", GdipBitmap, "UIntP", Width)
      DllCall("Gdiplus.dll\GdipGetImageHeight", "Ptr", GdipBitmap, "UIntP", Height)
      If (HBITMAP) {
         DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "Ptr", GdipBitmap, "PtrP", GdiBitmap, "UInt", 0xFFFFFFFF)
         DllCall("Gdiplus.dll\GdipDisposeImage", "Ptr", GdipBitmap)
      }
      ObjRelease(Stream)
      If (HBITMAP && (GdiBitmap = 0)) || (!HBITMAP && (GdipBitmap = 0))
         Return False
      Return (HBITMAP ? GdiBitmap : GdipBitmap)
   }
   ; ===============================================================================================================================
   ; Private methods
   ; ===============================================================================================================================
   DS(P) {
      C := NumGet(P + 0, "Int64"), H := NumGet(P + 8, "Int64"), VarSetCapacity(D, C * 8, 0), O := 16, A := &D
      Loop, % C
         A := NumPut(NumGet(P + O, "Int64") ^ H, A + 0, "Int64"), O += 8
      Return StrGet(&D, "UTF-8")
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   IsValidIX(IX) {
      Static Integer := "Integer"
      If IX Is Integer
         Return ((IX >= 1) && (IX <= This.EntryCount))
      Return False
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   UseGDIP(Params*) { ; loads and initializes the Gdiplus.dll
      Static GdipObject := {}, GdipModule := "", GdipToken  := ""
      If (GdipModule = "") {
         If !(GdipModule := DllCall("LoadLibrary", "Str", "Gdiplus.dll", "UPtr"))
            Throw Exception("The Gdiplus.dll could not be loaded!")
         Else {
            VarSetCapacity(SI, 24, 0), NumPut(1, SI, 0, "UInt") ; size of 64-bit structure
            If DllCall("Gdiplus.dll\GdiplusStartup", "PtrP", GdipToken, "Ptr", &SI, "Ptr", 0)
               Throw Exception("GDI+ could not be startet!")
            GdipObject := {Base: {__Delete: ObjBindMethod(This, "UseGDIP", GdipModule, GdipToken)}}
         }
      }
      Else If (Params[1] = GdipModule) && (Params[2] = GdipToken) {
         DllCall("Gdiplus.dll\GdiplusShutdown", "Ptr", GdipToken)
         DllCall("FreeLibrary", "Ptr", GdipModule)
      }
   }
}
; ==================================================================================================================================
; Creates a new ABA object (standard lib compatible wrapper for New ABA).
; For details see ABA.__New().
; ==================================================================================================================================
ABA_Create(FileName, UseGDIP := False, IsResource := False) { ;
   Return New ABA(FileName, UseGDIP, IsResource)
}
; ==================================================================================================================================
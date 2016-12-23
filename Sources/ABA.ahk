; ==================================================================================================================================
Class ABA {
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; Public
   ; -------------------------------------------------------------------------------------------------------------------------------
   EC[] { ; number of entries
      Get {
         Return This.HasKey("&") ? NumGet(This["&"] + 44, "UInt") : 0
      }
      Set {
         Return ABA.EC
   }  }
   ; -------------------------------------------------------------------------------------------------------------------------------
   __New(FileName, UseGDIP := False, Source := "") {
      Static ES := 16, HS := 48, MC := 557924929
      If (IsObject(This.Base.Base))
         Return !(ErrorLevel := 1)
      If (UseGDIP)
         This.UseGDIP()
      If IsObject(Source)
         This["&"] := Source.Addr, FS := Source.SIze
      Else If (Source = "RES") {
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
         This.SetCapacity("", FS), This["&"] := This.GetAddress("")
         File.RawRead(This["&"], FS)
         File.CLose()
      }
      BA := This["&"]
      M1 := NumGet(BA + 0, "UInt"), M2 := NumGet(BA + 4, "UInt")
      If (M1 <> 0) || (M2 <> MC)
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
   ; -------------------------------------------------------------------------------------------------------------------------------
   Data(NI, ByRef Buffer) { ; stores the entry's data in Buffer and returns the size of the data in bytes.
      Static ES := 16, HS := 48
      Buffer := ""
      If !(IX := This.NI2IX(NI))
         Return 0
      BA := This["&"], DO := NumGet(BA + 20, "UInt"), EA := BA + HS + ((IX - 1) * ES)
      OF := NumGet(EA + 8, "UInt"), DS := NumGet(EA + 12, "UInt"), DA := BA + DO + OF
      If (NumGet(EA + 4, "UInt") = 2)
         Buffer := StrGet(DA + 0, DS, "UTF-8")
      Else
         VarSetCapacity(Buffer, DS, 0), DllCall("RtlMoveMemory", "Ptr", &Buffer, "Ptr", DA, "Ptr", DS)
      Return DS
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   Ptr(NI, ByRef Size := "") { ; retrieves a pointer to the entry's data and stores the size of the data in Size.
      Static ES := 16, HS := 48
      Size := 0
      If !(IX := This.NI2IX(NI))
         Return 0
      BA := This["&"], DO := NumGet(BA + 20, "UInt"), EA := BA + HS + ((IX - 1) * ES), OF := NumGet(EA + 8, "UInt")
      Size := NumGet(EA + 12, "UInt")
      Return (BA + DO + OF)
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   Size(NI) { ; retrieves the size of the entry's data in bytes.
      Static ES := 16, HS := 48
      If !(IX := This.NI2IX(NI))
         Return 0
      EA := This["&"] + HS + ((IX - 1) * ES)
      Return NumGet(EA + 12, "UInt")
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   Bitmap(NI, ByRef Width := 0, ByRef Height := 0, HBITMAP := False) { ; retrieves a GDIP or GDI bitmap
      Static API := DllCall("LoadLibrary", "Str", "ShlwAPI.dll", "UPtr")
      Static XP := (DllCall("GetVersion", "UChar") < 6)
      Static CS := DllCall("GetProcAddress", "Ptr", API, XP ? "Ptr" : "AStr", XP ? 12 : "SHCreateMemStream", "UPtr")
      HBM := PBM := Width := Height := 0
      If !(DP := This.Ptr(NI, DS))
         Return 0
      If !DllCall("GetModuleHandle", "Str", "Gdiplus.dll", "UPtr")
         This.UseGDIP()
      If !(Stream := DllCall(CS, "Ptr", DP, "UInt", DS, "UPtr"))
         Return 0
      DllCall("Gdiplus.dll\GdipCreateBitmapFromStream", "Ptr", Stream, "PtrP", PBM)
      DllCall("Gdiplus.dll\GdipGetImageWidth", "Ptr", PBM, "UIntP", Width)
      DllCall("Gdiplus.dll\GdipGetImageHeight", "Ptr", PBM, "UIntP", Height)
      If (HBITMAP) {
         DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "Ptr", PBM, "PtrP", HBM, "UInt", 0xFFFFFFFF)
         DllCall("Gdiplus.dll\GdipDisposeImage", "Ptr", PBM)
      }
      ObjRelease(Stream)
      If (HBITMAP && (HBM = 0)) || (!HBITMAP && (PBM = 0))
         Return 0
      Return (HBITMAP ? HBM : PBM)
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   ; Private
   ; -------------------------------------------------------------------------------------------------------------------------------
   NI2IX(NI) {
      Static Integer := "Integer"
      IX := This["."].HasKey(NI) ? This["." , NI] : NI
      If IX Is Integer
         If ((IX >= 1) && (IX <= This.EC))
            Return IX
      Return 0
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   UseGDIP(P*) {
      Static GO := {}, GM := "", GT  := ""
      If (GM = "") {
         If !(GM := DllCall("LoadLibrary", "Str", "Gdiplus.dll", "UPtr"))
            Throw Exception("The Gdiplus.dll could not be loaded!")
         Else {
            VarSetCapacity(SI, 24, 0), NumPut(1, SI, 0, "UInt") ; size of 64-bit structure
            If DllCall("Gdiplus.dll\GdiplusStartup", "PtrP", GT, "Ptr", &SI, "Ptr", 0)
               Throw Exception("GDI+ could not be startet!")
            GO := {Base: {__Delete: ObjBindMethod(This, "UseGDIP", GM, GT)}}
         }
      }
      Else If (P[1] = GM) && (P[2] = GT) {
         DllCall("Gdiplus.dll\GdiplusShutdown", "Ptr", GT)
         DllCall("FreeLibrary", "Ptr", GM)
      }
   }
}
; ==================================================================================================================================
; ABA file format:
;  -  File header (offset: 0, size: ABAED.HeaderSize):
;     Offset      Type        Contents
;     0           UInt        NULL
;     4           Char[4]     "ABA!" (CP0)
;     8           UShort      major version
;     10          UShort      minor version
;     12          UInt64      creation date (YYYYMMDDHHMISS)
;     20          UInt        offset of the data area
;     24          UInt        size of the data area
;     28          UInt        reserved
;     32          UInt        offset of the string area (entry names)
;     36          UInt        size of the string area
;     40          UInt        reserved
;     44          UInt        number of entries
;  -  Data entries (offset: ABAED.HeaderSize, one entry per file, size per entry: ABAED.EntrySize):
;     Offset      Type        Contents
;     0           UInt        offset of the entry name within the string area
;     4           UInt        type of the entry
;     8           UInt        offset of the entry data within the data area
;     12          UInt        size of the data stored in the data area
;  -  Data area (offset and size: defined in the header):
;     Raw data.
;  -  String area (offset and size: defined in the header):
;     Entry names as zero-terminated UTF-8 strings.
; ----------------------------------------------------------------------------------------------------------------------------------
; ABAED object format:
;  -  Properties:       !!! You must not change any of the properties manually !!!
;     FilePath          path of the ABA file.
;     Version           ABA version which created the file (format: "n.nn").
;     Created           creation date and time  (format: YYYYMMDDHHMISS).
;     DataSize          total size of raw data.
;     EntryCount        number of entries.
;     Arrays:
;     -  Entries:       simple array of entry objects:
;                       Name:    the entry name.
;                       Type:    the type of the entry (1 = file, 2 = string, 3 = binary data).
;                       Size:    the size of the raw data.
;                       Data:    the raw data.
;                       Addr:    the address of the raw data.
;     -  Names:         associative array of entry names associated with the index of the entry in the Entries array.
;  -  Methods:
;     __New()           creates a new ABAED object from the specified file.
;     AddData()         adds binary data to the ABAED object.
;     AddFile()         adds a file to the ABAED object.
;     AddString()       adds a string to the ABAED object.
;     DeleteEntries()   deletes the specified entry from the ABAED object.
;     ExtractFile()     writes the specified file entry from the ABAED object to disc.
;     GetBitmap()       creates a GDI+ or GDI bitmap from the raw data of the specified entry in the ABAED object.
;     GetData()         retrieves the raw data of the specified entry.
;     GetPointer()      retrieves the pointer to the raw data of the specified entry.
;     GetString()       retrieves the string of the specified string entry.
;     ReplaceData()     replaces the binary data of the specified data entry within the ABAED object.
;     ReplaceFile()     replaces the file contents of the specified file entry within the ABAED object.
;     ReplaceString()   replaces the string of the specified string entry within the ABAED object.
;     Save()            stores the current contents of the ABAED object on disc.
;     UseGDIP()         loads and initializes the Gdiplus.dll.
; ==================================================================================================================================
Class ABAED {
   ; Instance variables ============================================================================================================
   FilePath := ""
   Version := ABAED.ClassVersion
   Created := A_Now
   DataSize := 0
   EntryCount := 0
   Entries := []
   Names := []
   ; Class properties ==============================================================================================================
   ClassVersion[] {
      Get {
         Return "1.00"
      }
      Set {
         Return ABAED.ClassVersion
      }
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   Magic[] { ; ABA file ID: ABA!
      Get {
         Return 557924929
      }
      Set {
         Return ABAED.Magic
      }
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   MajorVersion[] {
      Get {
         Return StrSplit(ABAED.Classversion, ".").1
      }
      Set {
         Return ABAED.MajorVersion
      }
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   MinorVersion[] {
      Get {
         Return (StrSplit(ABAED.Classversion, ".").2 + 0)
      }
      Set {
         Return ABAED.MinorVersion
      }
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   EntrySize[] { ; size of one entry
      Get {
         Return 16
      }
      Set {
         Return ABAED.EntrySize
      }
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   HeaderSize[] { ; size of the file header
      Get {
         Return 48
      }
      Set {
         Return ABAED.HeaderSize
      }
   }
   ; -------------------------------------------------------------------------------------------------------------------------------
   MaxPath[] { ; maximum length of a file path
      Get {
         Return 260
      }
      Set {
         Return ABAED.MaxPath
      }
   }
   ; ===============================================================================================================================
   ; Creates a new ABAED instance
   ; Parameters:
   ;     FileName    The name of the ABA file.
   ;     UseGDIP     If set to True, the Gdiplus.dll will be loaded and initialized automatically.
   ;                 It's needed for GetBitmap() but will also be done internally there, if the Gdiplus.dll isn't already loaded.
   ; Returns False (0) on failure - ErrorLevel is set to one of the following values:
   ;     1  :  tried to instantiate an ABAED instance.
   ;     ABA files:
   ;     2  :  could not open the ABA file.
   ;     3  :  invalid file format.
   ;     4  :  invalid file entry.
   ;     BRA files:
   ;     2  :  the specified BRA file doesn't exist.
   ;     3  :  the extension of specified BRA is invalid.
   ;     4  :  could not open the BRA file.
   ;     5  :  invalid BRA file header.
   ;     6  :  invalid BRA file length.
   ;     7  :  invalid BRA file count.
   ;     8  :  invalid BRA file entry.
   ; ===============================================================================================================================
   __New(FileName, UseGDIP := False) {
      If (IsObject(This.Base.Base))
         Return !(ErrorLevel := 1)
      If (UseGDIP)
         This.UseGDIP()
      SplitPath, FileName, , Dir, Ext, NameNoExt
      If FileExist(FileName) {
         If (Ext = "BRA") {
            If !This.CreateFromBRA(FileName)
               Return False
         }
         Else {
         	If !(File := FileOpen(FileName, "r"))
               Return !(ErrorLevel := 2)
            ; Check the file encoding and size
            If (File.Pos <> 0) || (File.Length < ABAED.HeaderSize)
               Return !(ErrorLevel := 3)
            ; Read the file an close it
            File.RawRead(Buffer, File.Length)
            File.CLose()
            ; Check the header
            Magic1 := NumGet(Buffer, 0, "UInt")
            Magic2 := NumGet(Buffer, 4, "UInt")
            If (Magic1 <> 0) || (Magic2 <> ABAED.Magic) { ; it's not an ABA file
               VarSetCapacity(Buffer, 0)
               Return !(ErrorLevel := 3)
            }
            ; Get the values from the header
            Version := NumGet(Buffer, 8, "UShort") . "." . NumGet(Buffer, 10, "UShort")
            Created := NumGet(Buffer, 12, "UInt64")
            DataOffset := NumGet(Buffer, 20, "UInt")
            DataSize := NumGet(Buffer, 24, "UInt")
            Reserved := NumGet(Buffer, 28, "UInt")
            StrOffset := NumGet(Buffer, 32, "UInt")
            StrSize := NumGet(Buffer, 36, "UInt")
            Reserved := NumGet(Buffer, 40, "UInt")
            EntryCount := NumGet(Buffer, 44, "UInt")
            ; Create the TOC
            Entries := []
            Names := []
            EntryAddr := &Buffer + ABAED.HeaderSize
            DataAddr := &Buffer + DataOffset
            StringAddr := &Buffer + StrOffset
            TOCMax := &Buffer + ABAED.HeaderSize + (ABAED.EntrySize * EntryCount)
            Loop, % EntryCount {
               If (EntryAddr < TOCMax) && ((StrPtr := NumGet(EntryAddr + 0, "UInt")) < StrSize) {
                  Name := StrGet(StringAddr + StrPtr, "UTF-8")
                  Type := NumGet(EntryAddr + 4, "UInt")
                  Offset:= NumGet(EntryAddr + 8, "UInt")
                  Size := NumGet(EntryAddr +12, "UInt")
                  Entry := {}
                  Entry.Name := Name
                  Entry.Type := Type
                  Entry.Size := Size
                  Entry.SetCapacity("Data", Size)
                  Entry.Addr := Entry.GetAddress("Data")
                  DllCall("RtlMoveMemory", "Ptr", Entry.Addr, "Ptr", DataAddr + Offset, "Ptr", Size)
                  Entries[A_Index] := Entry
                  Names[Name] := A_Index
                  EntryAddr += ABAED.EntrySize
               }
               Else {
                  VarSetCapacity(Buffer, 0)
                  Return !(ErrorLevel := 4)
               }
            }
            ; Update the instance variables
            This.FilePath := FileName
            This.Version := Version
            This.Created := Created
            This.DataSize := DataSize
            This.EntryCount := EntryCount
            This.Entries := Entries
            This.Names := Names
            ; Free the buffer
            VarSetCapacity(Buffer, 0)
         }
      }
      Else {
         If (FileName = "")
            This.FilePath := "NewABA.bin"
         Else {
            MsgBox, 36, %A_ThisFunc%, The file %FileName% does nor exist.`nDo you want to create a new empty ABA object?
            IfMsgBox, Yes
               This.FilePath := FileName
            Else
               Return 0
         }
      }
   }
   ; ===============================================================================================================================
   ; Adds the specified data entry to the ABAED object.
   ; Return values:
   ;     On success: The index of the added entry.
   ;     On failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 1  :  invalid entry name.
   ;                 2  :  the specified entry name is already included.
   ;                 3  :  invalid size.
   ; ===============================================================================================================================
   AddData(EntryName, ByRef DataBuffer, DataSize) {
      If !IsObject(This.Base)
         Return ""
      EntryName := Trim(EntryName)
      If (EntryName = "")
         Return !(ErrorLevel := 1)
      If This.Names.HasKey(EntryName)
         Return !(ErrorLevel := 2)
      If (VarSetCapacity(DataBuffer) < DataSize)
         Return !(ErrorLevel := 3)
      Entry := {}
      Entry.Name := EntryName
      Entry.Type := 3
      Entry.Size := DataSize
      Entry.SetCapacity("Data", DataSize)
      Entry.Addr := Entry.GetAddress("Data")
      DllCall("RtlMoveMemory", "Ptr", Entry.Addr, "Ptr", &DataBuffer, "Ptr", DataSize)
      Index := This.Entries.Push(Entry)
      This.Names[FileName] := Index
      This.DataSize += DataSize
      This.EntryCount += 1
      Return ((ErrorLevel := 0) + Index)
   }
   ; ===============================================================================================================================
   ; Adds the specified file entry to the ABAED object.
   ; Return values:
   ;     On success: The index of the added entry.
   ;     On failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 2  :  the specified entry name already exists.
   ;                 2  :  could not open the specified file.
   ;                 3  :  invalid file.
   ; ===============================================================================================================================
   AddFile(FileName) {
      If !IsObject(This.Base)
         Return ""
      SplitPath, FileName, EntryName
      If This.Names.HasKey(EntryName)
         Return !(ErrorLevel := 1)
      If !(File := FileOpen(FileName, "r"))
         Return !(ErrorLevel := 2)
      If !(FileSize := File.Length)
         Return !(ErrorLevel := 3)
      Entry := {}
      Entry.Name := EntryName
      Entry.Type := 1
      Entry.Size := FileSize
      Entry.SetCapacity("Data", FileSize)
      Entry.Addr := Entry.GetAddress("Data")
      File.Pos := 0
      File.RawRead(Entry.Addr + 0, FileSize)
      Index := This.Entries.Push(Entry)
      This.Names[EntryName] := Index
      This.DataSize += FileSize
      This.EntryCount += 1
      File.Close()
      Return ((ErrorLevel := 0) + Index)
   }
   ; ===============================================================================================================================
   ; Adds the specified string entry to the ABAED object.
   ; Return values:
   ;     On success: The index of the added entry.
   ;     On failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 1  :  invalid entry name.
   ;                 2  :  the specified entry name already exists.
   ;                 3  :  invalid string.
   ; ===============================================================================================================================
   AddString(EntryName, ByRef EntryStr) {
      If !IsObject(This.Base)
         Return ""
      EntryName := Trim(EntryName)
      If (EntryName = "")
         Return !(ErrorLevel := 1)
      If This.Names.HasKey(EntryName)
         Return !(ErrorLevel := 2)
      If !StrLen(EntryStr)
         Return !(ErrorLevel := 3)
      EntrySize := StrPut(EntryStr, "UTF-8")
      Entry := {}
      Entry.Name := EntryName
      Entry.Type := 2
      Entry.Size := EntrySize
      Entry.SetCapacity("Data", EntrySize)
      Entry.Addr := Entry.GetAddress("Data")
      StrPut(EntryStr, Entry.Addr + 0, "UTF-8")
      Index := This.Entries.Push(Entry)
      This.Names[FileName] := Index
      This.DataSize += EntrySize
      This.EntryCount += 1
      Return ((ErrorLevel := 0) + Index)
   }
   ; ===============================================================================================================================
   ; Deletes the specified data entries from the ABAED object.
   ; Returns False (0) on failure - ErrorLevel is set to one of the following values:
   ;     x  :  the data entry specified by x does not exist.
   ; ===============================================================================================================================
   DeleteEntries(NameOrIndex*) {
      DeleteEntries := []
      For Each, Entry In NameOrIndex {
         Index := This.Names.HasKey(Entry) ? This.Names[Entry] : Entry
         If !This.Entries.Haskey(Index)
            Return !(ErrorLevel := Entry)
         DeleteEntries[Index] := True
      }
      For Index In DeleteEntries {
         Entry := This.Entries.RemoveAt(Index - (A_Index - 1))
         This.DataSize -= Entry.Size
         This.EntryCount -= 1
      }
      This.Names := []
      For Index, Entry In This.Entries
         This.Names[Entry.Name] := Index
      Return !(ErrorLevel := 0)
   }
   ; ===============================================================================================================================
   ; Writes the specified file entry from the ABAED object to disc.
   ; Returns False (0) on failure - ErrorLevel is set to one of the following values:
   ;     1  :  could not find the specified entry.
   ;     2  :  the specified entry is not a file entry.
   ;     3  :  the specified file already exists and OverWrite is False.
   ;     4  :  could not open the specified file for writing.
   ; ===============================================================================================================================
   ExtractFile(NameOrIndex, FileName := "", OverWrite := True) {
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !This.Entries.Haskey(Index)
         Return !(ErrorLevel := 1)
      Entry := This.Entries[Index]
      If (Entry.Type <> 1)
         Return !(ErrorLevel := 2)
      FileName := FileName ? FileName : Entry.Name
      If FileExist(FileName) && !(OverWrite)
         Return !(ErrorLevel := 3)
      If !(File := FileOpen(FileName, "w", "CP0"))
         Return !(ErrorLevvel := 4)
      File.RawWrite(Entry.Addr + 0, Entry.Size)
      File.Close()
      Return !(ErrorLevel := 0)
   }
   ; ===============================================================================================================================
   ; Creates a GDI+ or GDI bitmap from the raw data of the specified data entry in the ABAED object.
   ; Return values:
   ;     On success: A GDI+ or GDI bitmap handle.
   ;     On Failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 1  :  could not find the specified data entry.
   ;                 2  :  SHCreateMemStream() failed to create a stream from the data.
   ;                 3  :  could not create a bitmap from the data.
   ; ===============================================================================================================================
   GetBitmap(NameOrIndex, ByRef Width := 0, ByRef Height := 0, HBITMAP := False) {
      Static ShlwAPI := DllCall("LoadLibrary", "Str", "Shlwapi.dll", "UPtr")
      Static CreateStream := DllCall("GetProcAddress", "Ptr", ShlwAPI, "AStr", "SHCreateMemStream", "UPtr")
      GdiBitmap := GdipBitmap := Width := Height := 0
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !This.Entries.Haskey(Index)
         Return !(ErrorLevel := 1)
      Addr := This.Entries[Index, "Addr"]
      Size := This.Entries[Index, "Size"]
      If !DllCall("GetModuleHandle", "Str", "Gdiplus.dll", "UPtr")
         This.UseGDIP()
      If !(Stream := DllCall(CreateStream, "Ptr", Addr, "UInt", Size, "UPtr"))
         Return !(ErrorLevel := 2)
      DllCall("Gdiplus.dll\GdipCreateBitmapFromStream", "Ptr", Stream, "PtrP", GdipBitmap)
      DllCall("Gdiplus.dll\GdipGetImageWidth", "Ptr", GdipBitmap, "UIntP", Width)
      DllCall("Gdiplus.dll\GdipGetImageHeight", "Ptr", GdipBitmap, "UIntP", Height)
      If (HBITMAP) {
         DllCall("Gdiplus.dll\GdipCreateHBITMAPFromBitmap", "Ptr", GdipBitmap, "PtrP", GdiBitmap, "UInt", 0xFFFFFFFF)
         DllCall("Gdiplus.dll\GdipDisposeImage", "Ptr", GdipBitmap)
      }
      ObjRelease(Stream)
      If (GdiBitmap = 0) && (GdipBitmap = 0)
         Return !(ErrorLevel := 3)
      Return ((ErrorLevel := 0) + (HBITMAP ? GdiBitmap : GdipBitmap))
   }
   ; ===============================================================================================================================
   ; Retrieves the raw data of the specified data entry from the ABAED object.
   ; Return values:
   ;     On success: The size of the data stored in the buffer in bytes.
   ;     On Failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 1  :  could not find the specified data entry.
   ; ===============================================================================================================================
   GetData(NameOrIndex, ByRef Buffer) {
      Buffer := "", Size := 0
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !This.Entries.Haskey(Index)
         Return !(ErrorLevel := 1)
      Addr := This.Entries[Index, "Addr"]
      Size := This.Entries[Index, "Size"]
      VarSetCapacity(Buffer, Size, 0)
      DllCall("RtlMoveMemory", "Ptr", &Buffer, "Ptr", Addr, "Ptr", Size)
      Return ((ErrorLevel := 0) + Size)
   }
   ; ===============================================================================================================================
   ; Retrieves the raw data of the specified data entry from the ABAED object.
   ; Return values:
   ;     On success: The size of the data stored in the buffer in bytes.
   ;     On Failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 1  :  could not find the specified data entry.
   ; ===============================================================================================================================
   GetPointer(NameOrIndex, ByRef DataPtr) {
      DataPtr := 0, Size := 0
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !This.Entries.Haskey(Index)
         Return !(ErrorLevel := 1)
      DataPtr := This.Entries[Index, "Addr"]
      Size := This.Entries[Index, "Size"]
      Return ((ErrorLevel := 0) + Size)
   }
   ; ===============================================================================================================================
   ; Retrieves the string of the specified string entry from the ABAED object.
   ; Return values:
   ;     On success: The size of the data stored in the buffer in bytes.
   ;     On Failure: False (0) - ErrorLevel is set to one of the following values:
   ;                 1  :  could not find the specified data entry.
   ;                 2  :  the specified data entry is not a string entry.
   ; ===============================================================================================================================
   GetString(NameOrIndex) {
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !This.Entries.Haskey(Index)
         Return !(ErrorLevel := 1)
      Entry := This.Entries[Index]
      If (Entry.Type <> 2)
         Return !(ErrorLevel := 2)
      ErrorLevel := 0
      Return StrGet(Entry.Addr + 0, Entry.Size, "UTF-8")
   }
   ; ===============================================================================================================================
   ; Replaces the data of the specified data entry with the data passed in DataBuffer.
   ; Returns False (0) on failure - ErrorLevel is set to one of the following values:
   ;     1  :  the specified data entry does not exist.
   ;     2  :  the specified data entry is not a string entry.
   ;     3  :  invalid Newstr parameter.
   ; ===============================================================================================================================
   ReplaceData(NameOrIndex, ByRef DataBuffer, DataSize) {
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !(Entry := This.Entries[Index])
         Return !(ErrorLevel := 1)
      If (Entry.Type <> 3)
         Return !(ErrorLevel := 2)
      If (VarSetCapacity(DataBuffer) < DataSize)
         Return !(ErrorLevel := 3)
      OldSize := Entry.Size
      Entry.Size := Size
      Entry.SetCapacity("Data", DataSize)
      Entry.Addr := Entry.GetAddress("Data")
      DllCall("RtlMoveMemory", "Ptr", Entry.Addr, "Ptr", &DataBuffer, "Ptr", DataSize)
      This.DataSize += DataSize - OldSize
      Return !(ErrorLevel := 0)
   }
   ; ===============================================================================================================================
   ; Replaces the specified file entry with the current file contents or the contents of the file specified in FileName.
   ; Returns False (0) on failure - ErrorLevel is set to one of the following values:
   ;     1  :  the specified file entry does not exist.
   ;     2  :  the specified entry is not a file entry.
   ;     3  :  the file specified in NewFileName is already included.
   ;     4  :  the file specified in NewFileName does not exist.
   ;     5  :  could not open the file.
   ;     6  :  invalid file.
   ; ===============================================================================================================================
   ReplaceFile(NameOrIndex, FileName := "" ) {
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !(Entry := This.Entries[Index])
         Return !(ErrorLevel := 1)
      OldName := Entry.Name
      OldSize := Entry.Size
      If (Entry.Type <> 1)
         Return !(ErrorLevel := 2)
      If (FileName) {
         SplitPath, FileName, NewName
         If (NewName <> OldName) && This.Names.HasKey(NewName)
            Return !(ErrorLevel := 3)
      }
      Else
         FileName := NewName := Entry.Name
      If !FileExist(FileName)
         Return !(ErrorLevel := 4)
      If !(File := FileOpen(FileName, "r"))
         Return !(ErrorLevel := 5)
      If !(FileSize := File.Length)
         Return !(ErrorLevel := 6)
      Entry.Size := FileSize
      Entry.SetCapacity("Data", FileSize)
      Entry.Addr := Entry.GetAddress("Data")
      File.Pos := 0
      File.RawRead(Entry.Addr + 0, FileSize)
      File.Close()
      If (NewName <> OldName) {
         Entry.Name := NewName
         This.Names[NewName] := Index
         This.Names.Delete(OldName)
      }
      This.DataSize += FileSize - OldSize
      Return !(ErrorLevel := 0)
   }
   ; ===============================================================================================================================
   ; Replaces the string contained in the specified entry with the string passed in NewStr.
   ; Returns False (0) on failure - ErrorLevel is set to one of the following values:
   ;     1  :  the specified data entry does not exist.
   ;     2  :  the specified data entry is not a string entry.
   ;     3  :  invalid Newstr parameter.
   ; ===============================================================================================================================
   ReplaceString(NameOrIndex, NewStr) {
      Index := This.Names.HasKey(NameOrIndex) ? This.Names[NameOrIndex] : NameOrIndex
      If !(Entry := This.Entries[Index])
         Return !(ErrorLevel := 1)
      If (Entry.Type <> 2)
         Return !(ErrorLevel := 2)
      If !StrLen(NewStr)
         Return !(ErrorLevel := 3)
      EntrySize := StrPut(NewStr, "UTF-8")
      OldSize := Entry.Size
      Entry.Size := EntrySize
      Entry.SetCapacity("Data", EntrySize)
      Entry.Addr := Entry.GetAddress("Data")
      StrPut(NewStr, Entry.Addr + 0, "UTF-8")
      This.DataSize += EntrySize - OldSize
      Return !(ErrorLevel := 0)
   }
   ; ===============================================================================================================================
   ; Saves the content of the ABAED object to disc.
   ; Returns False on failure and sets ErrorLevel to one of the following values:
   ;     1  :  the ABAED object does not contain any entries.
   ;     2  :  the specified file already exists and OverWrite is False.
   ;     3  :  could not open the specified file for writing.
   ; ===============================================================================================================================
   Save(FileName := "", OverWrite := True) {
      If (This.EntryCount < 1)
         Return !(ErrorLevel := 1)
      If (FileName = "")
         FileName := This.FilePath
      If FileExist(FileName) && !(OverWrite)
         Return !(ErrorLevel := 2)
      If !(File := FileOpen(FileName, "w", "CP0"))
         Return !(ErrorLevel := 3)
      ; Create the TOC, the data buffer, and the string buffer
      TOCSize := ABAED.EntrySize * This.EntryCount
      StrBufferSize := This.EntryCount * ABAED.MaxPath
      VarSetCapacity(TOCBuffer, TOCSize, 0)
      VarSetCapacity(StrBuffer, StrBufferSize, 0)
      VarSetCapacity(DataBuffer, This.DataSize, 0)
      StrOffset := 0
      DataOffset := 0
      TOCAddr := &TOCBuffer
      For Index, Entry In This.Entries {
         TOCAddr := NumPut(StrOffset, TOCAddr + 0, "UInt")
         StrOffset += StrPut(Entry.Name, &StrBuffer + StrOffset, "UTF-8")
         TOCAddr := NumPut(Entry.Type, TOCAddr + 0, "UInt")
         TOCAddr := NumPut(DataOffset, TOCAddr + 0, "UInt")
         TOCAddr := NumPut(Entry.Size, TOCAddr + 0, "UInt")
         DllCall("RtlMoveMemory", "Ptr", &DataBuffer + DataOffset, "Ptr", Entry.Addr, "Ptr", Entry.Size)
         DataOffset += Entry.Size
      }
      ; Create the header
      VarSetCapacity(HdrBuffer, ABAED.HeaderSize, 0)
      Addr := &HdrBuffer
      Addr := NumPut(ABAED.Magic, Addr + 4, "UInt") ; magic
      Addr := NumPut(ABAED.MajorVersion, Addr + 0, "UShort") ; major version
      Addr := NumPut(ABAED.MinorVersion, Addr + 0, "UShort") ; minor version
      Addr := NumPut(A_Now, Addr + 0, "Int64") ; created
      Addr := NumPut(ABAED.HeaderSize + TOCSize, Addr + 0, "UInt") ; data offset
      Addr := NumPut(This.DataSize, Addr + 0, "UInt") ; data size
      Addr := NumPut(0, Addr + 0, "UInt") ; reserved
      Addr := NumPut(ABAED.HeaderSize + TOCSize + This.DataSize, Addr + 0, "UInt") ; string offset
      Addr := NumPut(StrOffset, Addr + 0, "UInt") ; string size
      Addr := NumPut(0, Addr + 0, "UInt") ; reserved
      Addr := NumPut(This.EntryCount, Addr + 0, "UInt") ; file count
      ; Write the file
      File.RawWrite(&HdrBuffer, ABAED.HeaderSize)
      File.RawWrite(&TOCBuffer, TOCSize)
      File.RawWrite(&DataBuffer, This.DataSize)
      File.RawWrite(&StrBuffer, StrOffset)
      File.Close()
      This.FilePath := FileName
      Return !(Errorlevel := 0)
   }
   ; ===============================================================================================================================
   ; Creates the ABAED object from a BRA file - !!! For internal use only !!!.
   ; Returns False on failure and sets ErrorLevel to one of the following values:
   ;     1  :  the ABAED object does not contain file entries.
   ;     2  :  the specified file already exists and OverWrite is False.
   ;     3  :  could not open the specified file for writing.
   ; ===============================================================================================================================
   CreateFromBRA(BRAFileName) {
      If !FileExist(BRAFileName)
         Return !(ErrorLevel := 2)
      SplitPath, BRAFileName, , Dir, Ext, NameNoExt
      If (Ext <> "BRA")
         Return !(ErrorLevel := 3)
      ABAFileName := (Dir ? Dir . "\" : "") . NameNoExt . ".bin"
      If !(File := FileOpen(BRAFileName, "r", "CP0"))
         Return !(ErrorLevel := 4)
      Hdr1 := StrSplit(RTrim(File.ReadLine(), "`n"), "|")
      If (Hdr1.Length() <> 4) || (Hdr1.2 <> "BRA!")
         Return !(ErrorLevel := 5)
      Hdr2 := StrSplit(RTrim(File.ReadLine(), "`n"), "|")
      If (Hdr2.Length() <> 3) || (File.Length <> (Hdr2.2 + Hdr2.3))
         Return !(ErrorLevel := 6)
      ; Read the BRA TOC
      EntryCount := Hdr2.1
      DataOffset := Hdr2.2
      DataSize := Hdr2.3
      BRATOC := StrSplit(File.Read(DataOffset - File.Pos - 1), "`n")
      If (BRATOC.Length() <> EntryCount)
         Return !(ErrorLevel := 7)
      ; Read the BRA data
      VarSetCapacity(DataBuffer, DataSize, 0)
      File.Pos := DataOffset
      File.RawRead(&DataBuffer, DataSize)
      File.CLose()
      ; Create the ABA arrays
      Entries := []
      Names := []
      For Index, FileEntry In BRATOC {
         Split := StrSplit(FileEntry, "|")
         If (Split.Length() = 4) {
            Offset := Split.3
            Size := Split.4
            Entry := {}
            Entry.Name := Split.2
            Entry.Type := 1
            Entry.Size := Size
            Entry.SetCapacity("Data", Size)
            Entry.Addr := Entry.GetAddress("Data")
            DllCall("RtlMoveMemory", "Ptr", Entry.Addr, "Ptr", &DataBuffer + Offset, "Ptr", Size)
            Entries[A_Index] := Entry
            Names[Name] := A_Index
         }
         Else {
            VarSetCapacity(DataBuffer, 0)
            Return !(ErrorLevel := 8)
         }
      }
      This.DataSize := DataSize
      This.Entries := Entries
      This.EntryCount := EntryCount
      This.FilePath := ABAFileName
      This.Names := Names
      VarSetCapacity(DataBuffer, 0)
      Return !(ErrorLevel := 0)
   }
   ; ===============================================================================================================================
   ; Private methods
   ; ===============================================================================================================================
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
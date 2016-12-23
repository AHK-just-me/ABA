# ABA File Format
## File Header (offset: 0, size: 48)
Offset|Type|Contents
------|----|--------
0|UInt|NULL
4|Char[4]|"ABA!" (CP0)
8|UShort|major version
10|UShort|minor version
12|UInt64|creation date (YYYYMMDDHHMISS)
20|UInt|offset of the data area
24|UInt|size of the data area
28|UInt|reserved
32|UInt|offset of the string area (entry names)
36|UInt|size of the string area
40|UInt|reserved
44|UInt|number of entries
##Data Entry TOC (offset: 48, size per entry: 16)
Offset|Type|Contents
------|----|--------
0|UInt|offset of the entry name within the string area
4|UInt|type of the entry
8|UInt|offset of the entry data within the data area
12|UInt|size of the data stored in the data area
##Data Section
Data.
##String Section
Entry names.

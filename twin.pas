program TWIN;
{
TWIN - Two-panel file manager for TP 3.0A and CP/M-80
Copyright (c) 2026 Ralf Kammel
SPDX-License-Identifier: MIT
See LICENSE for the full license text.
}
const
MaxFiles = 240;
Rows = 18;
BufRecs = 8;
ESC = #27;
type
FileName = string[12];
FileSpec = string[16];
FreeString = string[16];
DateString = string[8];
var
Files: array[1..2, 1..MaxFiles] of FileName;
FileSizes: array[1..2, 1..MaxFiles] of Integer;
DateLow: array[1..2, 1..MaxFiles] of Byte;
DateHigh: array[1..2, 1..MaxFiles] of Byte;
CachedDates: array[1..2, 1..MaxFiles] of DateString;
DateReady: array[1..2, 1..MaxFiles] of Boolean;
FileCount: array[1..2] of Integer;
DriveNo: array[1..2] of Integer;
Selected: array[1..2] of Integer;
FirstLine: array[1..2] of Integer;
Truncated: array[1..2] of Boolean;
SearchFCB: array[0..35] of Byte;
RenameFCB: array[0..35] of Byte;
DateFCB: array[0..35] of Byte;
DirDMA: array[0..127] of Byte;
Active: Integer;
Key, Key2, Key3: Char;
StatusText: string[78];
Quit: Boolean;
CPM3: Boolean;
Redraw: Boolean;
ShowDate: Boolean;
ParamIndex: Integer;
function DriveLetter(D: Integer): Char;
begin
DriveLetter := Chr(Ord('A') + D - 1)
end;
function MakeName(Slot: Integer): FileName;
var
BaseName, ExtName: string[8];
ResultName: FileName;
PosDMA, I, C: Integer;
begin
BaseName := '';
ExtName := '';
PosDMA := Slot * 32;
for I := 1 to 8 do
begin
C := DirDMA[PosDMA + I] and $7F;
if C <> Ord(' ') then
BaseName := BaseName + Chr(C)
end;
for I := 9 to 11 do
begin
C := DirDMA[PosDMA + I] and $7F;
if C <> Ord(' ') then
ExtName := ExtName + Chr(C)
end;
ResultName := BaseName;
if Length(ExtName) > 0 then
ResultName := ResultName + '.' + ExtName;
MakeName := ResultName
end;
function EntrySizeKB(Slot: Integer): Integer;
var
PosDMA: Integer;
ExtentNo: Real;
Records, SizeKB: Real;
begin
PosDMA := Slot * 32;
ExtentNo := (DirDMA[PosDMA + 14] and $3F) * 32 +
DirDMA[PosDMA + 12];
Records := ExtentNo * 128.0 + DirDMA[PosDMA + 15];
SizeKB := Records / 8.0;
if CPM3 and (DirDMA[PosDMA + 13] > 0) and (Records > 0) then
SizeKB := SizeKB - (128 - DirDMA[PosDMA + 13]) / 1024.0;
if SizeKB > 32767.0 then
EntrySizeKB := -1
else
EntrySizeKB := Round(SizeKB)
end;
function IsLeapYear(Year: Integer): Boolean;
begin
IsLeapYear := ((Year mod 4) = 0) and
(((Year mod 100) <> 0) or ((Year mod 400) = 0))
end;
procedure LoadFileDate(P, N: Integer);
var
I, PosName, Err: Integer;
NameText: FileName;
begin
DateLow[P, N] := 0;
DateHigh[P, N] := 0;
if CPM3 then
begin
for I := 0 to 35 do
DateFCB[I] := 0;
DateFCB[0] := DriveNo[P];
for I := 1 to 11 do
DateFCB[I] := Ord(' ');
PosName := 1;
NameText := Files[P, N];
for I := 1 to Length(Files[P, N]) do
begin
if NameText[I] = '.' then
begin
PosName := 9
end
else
begin
DateFCB[PosName] := Ord(NameText[I]);
PosName := PosName + 1
end
end;
Err := Bdos(102, Addr(DateFCB));
if Err < 0 then
Err := Err + 256;
if Err = 0 then
begin
DateLow[P, N] := DateFCB[28];
DateHigh[P, N] := DateFCB[29];
if (DateLow[P, N] = 0) and (DateHigh[P, N] = 0) then
begin
DateLow[P, N] := DateFCB[24];
DateHigh[P, N] := DateFCB[25]
end
end
end
end;
function DisplayDate(P, N: Integer): DateString;
var
DaysLeft: Real;
Year, Month, Day, MonthDays: Integer;
YearText: string[2];
MonthText, DayText: string[2];
Found: Boolean;
begin
if (DateLow[P, N] = 0) and (DateHigh[P, N] = 0) then
DisplayDate := '--------'
else
begin
DaysLeft := DateLow[P, N] + DateHigh[P, N] * 256.0 - 1.0;
Year := 1978;
Found := False;
while not Found do
begin
if IsLeapYear(Year) then
MonthDays := 366
else
MonthDays := 365;
if DaysLeft >= MonthDays then
begin
DaysLeft := DaysLeft - MonthDays;
Year := Year + 1
end
else
Found := True
end;
Month := 1;
Found := False;
while (Month <= 12) and (not Found) do
begin
if (Month = 4) or (Month = 6) or (Month = 9) or (Month = 11) then
MonthDays := 30
else if Month = 2 then
begin
if IsLeapYear(Year) then
MonthDays := 29
else
MonthDays := 28
end
else
MonthDays := 31;
if DaysLeft < MonthDays then
Found := True
else
begin
DaysLeft := DaysLeft - MonthDays;
Month := Month + 1
end
end;
Day := Trunc(DaysLeft) + 1;
Str(Year mod 100, YearText);
if (Year mod 100) < 10 then
YearText := '0' + YearText;
Str(Month:2, MonthText);
Str(Day:2, DayText);
if Month < 10 then
MonthText[1] := '0';
if Day < 10 then
DayText[1] := '0';
DisplayDate := YearText + '-' + MonthText + '-' + DayText
end
end;
function GetDisplayDate(P, N: Integer): DateString;
begin
if not DateReady[P, N] then
begin
CachedDates[P, N] := DisplayDate(P, N);
DateReady[P, N] := True
end;
GetDisplayDate := CachedDates[P, N]
end;
procedure LoadDirectory(P: Integer);
var
N, Slot, K, I, Index: Integer;
ThisName: FileName;
ThisSize: Integer;
begin
FileCount[P] := 0;
Truncated[P] := False;
for K := 0 to 35 do
SearchFCB[K] := 0;
SearchFCB[0] := DriveNo[P];
for K := 1 to 11 do
SearchFCB[K] := Ord('?');
Bdos(26, Addr(DirDMA));
N := Bdos(17, Addr(SearchFCB));
if N < 0 then
N := N + 256;
while (N <> 255) and (FileCount[P] < MaxFiles) do
begin
Slot := N;
ThisName := MakeName(Slot);
ThisSize := EntrySizeKB(Slot);
Index := 0;
for I := 1 to FileCount[P] do
if Files[P, I] = ThisName then
Index := I;
if Index = 0 then
begin
FileCount[P] := FileCount[P] + 1;
Index := FileCount[P];
Files[P, Index] := ThisName;
FileSizes[P, Index] := ThisSize;
if not ShowDate then
begin
DateLow[P, Index] := 0;
DateHigh[P, Index] := 0
end
else
LoadFileDate(P, Index);
DateReady[P, Index] := False
end
else if (FileSizes[P, Index] >= 0) and
((ThisSize < 0) or (ThisSize > FileSizes[P, Index])) then
FileSizes[P, Index] := ThisSize;
N := Bdos(18);
if N < 0 then
N := N + 256
end;
if (FileCount[P] = MaxFiles) and (N <> 255) then
Truncated[P] := True;
if FileCount[P] = 0 then
begin
Selected[P] := 0;
FirstLine[P] := 1
end
else
begin
if Selected[P] < 1 then
Selected[P] := 1;
if Selected[P] > FileCount[P] then
Selected[P] := FileCount[P];
FirstLine[P] := 1
end
end;
procedure EnsureVisible(P: Integer);
var
MaxFirst: Integer;
begin
if FileCount[P] = 0 then
begin
FirstLine[P] := 1;
Selected[P] := 0
end
else
begin
if Selected[P] < 1 then
Selected[P] := 1;
if Selected[P] > FileCount[P] then
Selected[P] := FileCount[P];
if Selected[P] < FirstLine[P] then
FirstLine[P] := Selected[P];
if Selected[P] >= FirstLine[P] + Rows then
FirstLine[P] := Selected[P] - Rows + 1;
MaxFirst := FileCount[P] - Rows + 1;
if MaxFirst < 1 then
MaxFirst := 1;
if FirstLine[P] > MaxFirst then
FirstLine[P] := MaxFirst
end
end;
procedure GetFreeSpace(P: Integer; var Text: FreeString);
var
Err: Integer;
FreeKB: Real;
begin
Text := '';
Bdos(26, Addr(DirDMA));
Err := Bdos(46, DriveNo[P] - 1);
if Err < 0 then
Err := Err + 256;
if Err = 0 then
begin
FreeKB := DirDMA[2] * 8192.0 +
DirDMA[1] * 32.0 + DirDMA[0] / 8.0;
Str(FreeKB:7:0, Text);
while (Length(Text) > 0) and (Text[1] = ' ') do
Text := Copy(Text, 2, Length(Text) - 1)
end
else
Text := 'n/a'
end;
procedure DrawPanel(P: Integer);
var
X, Y, N, K, TitleLen: Integer;
FreeText: FreeString;
RowText: string[38];
SizeText: string[8];
NameText: FileName;
DateText: DateString;
begin
if P = 1 then
X := 1
else
X := 41;
Write(ESC,'[0m',ESC,'[37;44m');
GotoXY(X, 1);
if P = 1 then
begin
Write('+=============== ');
Write(ESC,'[1;37;44m','TWIN');
Write(ESC,'[0m',ESC,'[37;44m');
Write(' =================+')
end
else
begin
Write('+======== ');
Write(ESC,'[1;37;44m','(C) Ralf Kammel 2026');
Write(ESC,'[0m',ESC,'[37;44m');
Write(' ========+')
end;
for Y := 2 to 21 do
begin
GotoXY(X, Y);
Write('|');
for K := 1 to 38 do
Write(' ');
Write('|')
end;
GotoXY(X, 22);
Write('+======================================+');
GotoXY(X + 1, 2);
Write(ESC,'[0m');
if P = Active then
Write(ESC,'[1;37;42m')
else
Write(ESC,'[1;37;43m');
if P = Active then
Write('>')
else
Write(' ');
Write(DriveLetter(DriveNo[P]), ': ');
Write(FileCount[P]:3);
Write(' Files');
TitleLen := 13;
if CPM3 then
begin
GetFreeSpace(P, FreeText);
Write(' ', FreeText, ' KB free');
TitleLen := TitleLen + 1 + Length(FreeText) + 8
end;
if Truncated[P] then
begin
Write('+');
TitleLen := TitleLen + 1
end;
for K := TitleLen + 1 to 38 do
Write(' ');
Write(ESC,'[0m',ESC,'[37;44m');
GotoXY(X + 1, 3);
RowText := '';
for K := 1 to 38 do
RowText := RowText + ' ';
RowText[1] := 'N';
RowText[2] := 'a';
RowText[3] := 'm';
RowText[4] := 'e';
RowText[14] := '|';
RowText[16] := 'S';
RowText[17] := 'i';
RowText[18] := 'z';
RowText[19] := 'e';
if ShowDate then
begin
RowText[28] := '|';
RowText[31] := 'D';
RowText[32] := 'a';
RowText[33] := 't';
RowText[34] := 'e'
end;
Write(ESC,'[1;33;44m');
Write(RowText);
Write(ESC,'[0m',ESC,'[37;44m');
for Y := 1 to Rows do
begin
N := FirstLine[P] + Y - 1;
GotoXY(X + 1, Y + 3);
if (N <= FileCount[P]) and (N >= 1) then
begin
Write(ESC,'[1;37;44m');
if (P = Active) and (N = Selected[P]) then
Write(ESC,'[7m');
RowText := '';
for K := 1 to 38 do
RowText := RowText + ' ';
RowText[14] := '|';
if ShowDate then
RowText[28] := '|';
NameText := Files[P, N];
for K := 1 to Length(NameText) do
RowText[K] := NameText[K];
if FileSizes[P, N] < 0 then
SizeText := '>32767KB'
else
begin
Str(FileSizes[P, N]:5, FreeText);
SizeText := Copy(FreeText, 1, 5) + ' KB'
end;
for K := 1 to 8 do
RowText[15 + K] := SizeText[K];
if ShowDate then
begin
DateText := GetDisplayDate(P, N);
for K := 1 to 8 do
RowText[30 + K] := DateText[K]
end;
Write(RowText);
Write(ESC,'[0m',ESC,'[37;44m')
end
else
begin
for K := 1 to 38 do
Write(' ')
end
end
end;
procedure DrawCommandLine;
var
FooterText: string[80];
K: Integer;
begin
FooterText := 'Arrows Move | TAB Switch | C Copy | D Del | ' +
'R Rename | S Show | L Drive | Q Quit';
GotoXY(1, 24);
Write(ESC,'[1;30;47m');
Write(FooterText);
for K := Length(FooterText) + 1 to 80 do
Write(' ');
Write(ESC,'[0m',ESC,'[37;40m')
end;
procedure DrawScreen;
begin
NormVideo;
Write(ESC,'[0m',ESC,'[37;44m');
ClrScr;
GotoXY(1, 23);
Write(ESC,'[0m',ESC,'[37;40m');
Write(StatusText);
ClrEol;
DrawCommandLine;
DrawPanel(1);
DrawPanel(2)
end;
procedure DrawFileRow(P, N: Integer);
var
X, Y, I: Integer;
RowText: string[38];
NameText: FileName;
SizeText: string[8];
SizeBuffer: FreeString;
DateText: DateString;
begin
if (N >= FirstLine[P]) and (N < FirstLine[P] + Rows) then
begin
if P = 1 then
X := 1
else
X := 41;
Y := N - FirstLine[P] + 4;
RowText := '';
for I := 1 to 38 do
RowText := RowText + ' ';
RowText[14] := '|';
if ShowDate then
RowText[28] := '|';
if (N >= 1) and (N <= FileCount[P]) then
begin
NameText := Files[P, N];
for I := 1 to Length(NameText) do
RowText[I] := NameText[I];
if FileSizes[P, N] < 0 then
SizeText := '>32767KB'
else
begin
Str(FileSizes[P, N]:5, SizeBuffer);
SizeText := Copy(SizeBuffer, 1, 5) + ' KB'
end;
for I := 1 to 8 do
RowText[15 + I] := SizeText[I];
if ShowDate then
begin
DateText := GetDisplayDate(P, N);
for I := 1 to 8 do
RowText[30 + I] := DateText[I]
end
end;
GotoXY(X + 1, Y);
Write(ESC,'[1;37;44m');
if (P = Active) and (N = Selected[P]) then
Write(ESC,'[7m');
Write(RowText);
Write(ESC,'[0m',ESC,'[37;44m')
end
end;
procedure MoveSelection(P, Direction: Integer);
var
OldSelected, OldFirst: Integer;
begin
OldSelected := Selected[P];
OldFirst := FirstLine[P];
if FileCount[P] > 0 then
begin
if Selected[P] = 0 then
Selected[P] := 1
else
Selected[P] := Selected[P] + Direction;
if Selected[P] < 1 then
Selected[P] := 1;
if Selected[P] > FileCount[P] then
Selected[P] := FileCount[P];
EnsureVisible(P);
if FirstLine[P] <> OldFirst then
DrawPanel(P)
else
begin
if OldSelected > 0 then
DrawFileRow(P, OldSelected);
DrawFileRow(P, Selected[P])
end
end;
GotoXY(1, 23);
Write(ESC,'[37;40m');
ClrEol
end;
procedure ChangeDrive(P: Integer);
var
Ch: Char;
D: Integer;
begin
GotoXY(1, 23);
Write(ESC,'[1;32;40m');
Write('Drive A-P (ESC cancels): ');
ClrEol;
Read(Kbd, Ch);
Write(ESC,'[0m',ESC,'[37;40m');
if (Ch >= 'a') and (Ch <= 'z') then
Ch := Chr(Ord(Ch) - Ord('a') + Ord('A'));
if (Ch >= 'A') and (Ch <= 'P') then
begin
D := Ord(Ch) - Ord('A') + 1;
DriveNo[P] := D;
Selected[P] := 1;
LoadDirectory(P);
StatusText := 'Drive ' + DriveLetter(D) + ': loaded.'
end
else
StatusText := 'Drive change cancelled.'
end;
procedure ShowCopyNotice(SrcName, DstName: FileSpec);
var
I: Integer;
begin
Write(ESC,'[1;37;44m');
GotoXY(17, 9);
Write('+==============================================+');
GotoXY(17, 10);
Write('|               Copy starts next               |');
GotoXY(17, 11);
Write('| From: ', SrcName);
for I := 1 to 39 - Length(SrcName) do
Write(' ');
Write('|');
GotoXY(17, 12);
Write('| To:   ', DstName);
for I := 1 to 39 - Length(DstName) do
Write(' ');
Write('|');
GotoXY(17, 13);
Write('|               Copying next...                |');
GotoXY(17, 14);
Write('+==============================================+');
Write(ESC,'[0m',ESC,'[37;40m')
end;
procedure CopySelected;
var
SrcPanel, DstPanel, I, RecsRead, Err: Integer;
SrcName, DstName: FileSpec;
SourceFile, DestFile: file;
Buffer: array[0..1023] of Byte;
Ch: Char;
SourceOpen, DestOpen, Proceed, CopyOK: Boolean;
begin
SourceOpen := False;
DestOpen := False;
Proceed := False;
CopyOK := False;
if FileCount[Active] = 0 then
StatusText := 'No file selected in active panel.'
else
begin
SrcPanel := Active;
if SrcPanel = 1 then
DstPanel := 2
else
DstPanel := 1;
SrcName := DriveLetter(DriveNo[SrcPanel]) + ':' +
Files[SrcPanel, Selected[SrcPanel]];
DstName := DriveLetter(DriveNo[DstPanel]) + ':' +
Files[SrcPanel, Selected[SrcPanel]];
if SrcName = DstName then
StatusText := 'Source and destination are identical.'
else
begin
ShowCopyNotice(SrcName, DstName);
Assign(SourceFile, SrcName);
{$I-}
Reset(SourceFile);
{$I+}
Err := IOresult;
if Err <> 0 then
StatusText := 'Cannot open source file.'
else
begin
SourceOpen := True;
Assign(DestFile, DstName);
{$I-}
Reset(DestFile);
{$I+}
Err := IOresult;
if Err = 0 then
begin
{$I-}
Close(DestFile);
{$I+}
Err := IOresult;
if Err <> 0 then
StatusText := 'Cannot check destination file.'
else
begin
GotoXY(1, 23);
Write(ESC,'[1;32;40m');
Write('Destination exists. Overwrite (Y/N)? ');
ClrEol;
Read(Kbd, Ch);
Write(ESC,'[0m',ESC,'[37;40m');
GotoXY(1, 23);
ClrEol;
if (Ch = 'Y') or (Ch = 'y') then
Proceed := True
else
StatusText := 'Copy cancelled.'
end
end
else
Proceed := True;
if Proceed then
begin
Assign(DestFile, DstName);
{$I-}
Rewrite(DestFile);
{$I+}
Err := IOresult;
if Err <> 0 then
StatusText := 'Cannot create destination file.'
else
begin
DestOpen := True;
CopyOK := True;
repeat
RecsRead := 0;
{$I-}
BlockRead(SourceFile, Buffer, BufRecs, RecsRead);
{$I+}
Err := IOresult;
if Err <> 0 then
begin
CopyOK := False;
StatusText := 'Error reading source file.'
end
else if RecsRead > 0 then
begin
{$I-}
BlockWrite(DestFile, Buffer, RecsRead);
{$I+}
Err := IOresult;
if Err <> 0 then
begin
CopyOK := False;
StatusText := 'Error writing destination file.'
end
end
until (not CopyOK) or (RecsRead < BufRecs)
end
end
end
end;
if SourceOpen then
begin
{$I-}
Close(SourceFile);
{$I+}
Err := IOresult;
if Err <> 0 then
begin
CopyOK := False;
StatusText := 'Error closing source file.'
end
end;
if DestOpen then
begin
{$I-}
Close(DestFile);
{$I+}
Err := IOresult;
if Err <> 0 then
begin
CopyOK := False;
StatusText := 'Error closing destination file.'
end
end;
if CopyOK then
begin
LoadDirectory(DstPanel);
for I := 1 to FileCount[DstPanel] do
if Files[DstPanel, I] = Files[SrcPanel, Selected[SrcPanel]] then
Selected[DstPanel] := I;
EnsureVisible(DstPanel);
StatusText := 'File copied to ' + DriveLetter(DriveNo[DstPanel]) +
':.'
end
end
end;
procedure DeleteSelected;
var
P, OldIndex, Err: Integer;
DeleteName: FileName;
DeleteSpec: string[16];
DeleteFile: file;
Ch: Char;
begin
if FileCount[Active] = 0 then
StatusText := 'No file selected in active panel.'
else
begin
P := Active;
OldIndex := Selected[P];
DeleteName := Files[P, OldIndex];
DeleteSpec := DriveLetter(DriveNo[P]) + ':' + DeleteName;
GotoXY(1, 23);
Write(ESC,'[1;32;40m');
Write('Delete file ', DeleteName, ' (Y/N)? ');
ClrEol;
Read(Kbd, Ch);
Write(ESC,'[0m',ESC,'[37;40m');
if (Ch = 'Y') or (Ch = 'y') then
begin
Assign(DeleteFile, DeleteSpec);
{$I-}
Erase(DeleteFile);
{$I+}
Err := IOresult;
if Err <> 0 then
StatusText := 'Cannot delete file.'
else
begin
LoadDirectory(P);
if FileCount[P] > 0 then
begin
if OldIndex > FileCount[P] then
OldIndex := FileCount[P];
Selected[P] := OldIndex;
EnsureVisible(P)
end;
StatusText := 'Deleted: ' + DeleteName
end
end
else
StatusText := 'Delete cancelled.'
end
end;
procedure DrawViewerPage(Name: FileName);
begin
ClrScr;
GotoXY(1, 1);
Write(ESC,'[7m','File: ',Name);
ClrEol;
Write(ESC,'[0m',ESC,'[37;44m');
GotoXY(1, 23);
Write(ESC,'[1;32;40m');
Write('Any key: next page  Q or ESC: quit');
ClrEol;
Write(ESC,'[0m',ESC,'[37;40m');
DrawCommandLine
end;
procedure AdvanceViewerLine(var Row, Col: Integer;
var StopView: Boolean; Name: FileName);
begin
Row := Row + 1;
Col := 1;
if Row > 22 then
begin
GotoXY(1, 23);
Write(ESC,'[1;32;40m');
Write('Any key: next page  Q or ESC: quit');
ClrEol;
Read(Kbd, Key);
Write(ESC,'[0m',ESC,'[37;40m');
if (Key = 'q') or (Key = 'Q') or (Key = ESC) then
StopView := True
else
begin
DrawViewerPage(Name);
Row := 2;
Col := 1
end
end
end;
procedure ShowSelected;
var
P, I, Err, RecsRead, Code, Row, Col: Integer;
Name, ViewSpec: FileName;
ViewFile: file;
ViewBuffer: array[0..127] of Byte;
StopView, ReadError, LastCR: Boolean;
begin
if FileCount[Active] = 0 then
StatusText := 'No file selected in active panel.'
else
begin
P := Active;
Name := Files[P, Selected[P]];
if (Length(Name) >= 4) and
(Copy(Name, Length(Name) - 3, 4) = '.COM') then
StatusText := 'COM files cannot be displayed.'
else
begin
ViewSpec := DriveLetter(DriveNo[P]) + ':' + Name;
Assign(ViewFile, ViewSpec);
{$I-}
Reset(ViewFile);
{$I+}
Err := IOresult;
if Err <> 0 then
StatusText := 'Cannot open file.'
else
begin
StopView := False;
ReadError := False;
LastCR := False;
Row := 2;
Col := 1;
DrawViewerPage(Name);
repeat
RecsRead := 0;
{$I-}
BlockRead(ViewFile, ViewBuffer, 1, RecsRead);
{$I+}
Err := IOresult;
if Err <> 0 then
begin
ReadError := True;
StopView := True
end
else if RecsRead > 0 then
begin
for I := 0 to 127 do
begin
Code := ViewBuffer[I];
if Code = 26 then
StopView := True
else if Code = 13 then
begin
LastCR := True;
AdvanceViewerLine(Row, Col, StopView, Name)
end
else if Code = 10 then
begin
if not LastCR then
AdvanceViewerLine(Row, Col, StopView, Name);
LastCR := False
end
else
begin
LastCR := False;
if Col > 80 then
AdvanceViewerLine(Row, Col, StopView, Name);
if not StopView then
begin
GotoXY(Col, Row);
if (Code >= 32) and (Code <> 127) then
Write(Chr(Code))
else if Code = 9 then
Write(' ')
else
Write('.');
Col := Col + 1
end
end
end
end
until (RecsRead = 0) or StopView;
{$I-}
Close(ViewFile);
{$I+}
Err := IOresult;
if ReadError then
StatusText := 'Error reading file.'
else if Err <> 0 then
StatusText := 'Error closing file.'
else
StatusText := 'View finished.'
end
end
end
end;
procedure PutFCBName(Offset: Integer; Name: FileName);
var
I, BasePos, ExtPos: Integer;
InExtension: Boolean;
begin
for I := 1 to 11 do
RenameFCB[Offset + I] := Ord(' ');
BasePos := 1;
ExtPos := 9;
InExtension := False;
for I := 1 to Length(Name) do
begin
if Name[I] = '.' then
InExtension := True
else if InExtension then
begin
RenameFCB[Offset + ExtPos] := Ord(Name[I]);
ExtPos := ExtPos + 1
end
else
begin
RenameFCB[Offset + BasePos] := Ord(Name[I]);
BasePos := BasePos + 1
end
end
end;
procedure RenameSelected;
var
P, I, Err, BaseLen, ExtLen: Integer;
NewName: FileName;
Ch: Char;
Cancelled, InExtension, ValidName: Boolean;
begin
if FileCount[Active] = 0 then
StatusText := 'No file selected in active panel.'
else
begin
P := Active;
NewName := '';
Cancelled := False;
GotoXY(1, 23);
Write(ESC,'[1;32;40m');
Write('New name 8.3, ESC cancels: ');
ClrEol;
Write(ESC,'[0m',ESC,'[37;40m');
repeat
Read(Kbd, Ch);
if Ch = ESC then
Cancelled := True
else if Ch = #13 then
begin
end
else if (Ch = #8) or (Ch = #127) then
begin
if Length(NewName) > 0 then
begin
NewName := Copy(NewName, 1, Length(NewName) - 1);
Write(#8, ' ', #8)
end
end
else if Length(NewName) < 12 then
begin
if (Ch >= 'a') and (Ch <= 'z') then
Ch := Chr(Ord(Ch) - Ord('a') + Ord('A'));
NewName := NewName + Ch;
Write(Ch)
end
until (Ch = #13) or Cancelled;
if Cancelled then
StatusText := 'Rename cancelled.'
else if Length(NewName) = 0 then
StatusText := 'No new name entered.'
else
begin
BaseLen := 0;
ExtLen := 0;
InExtension := False;
ValidName := True;
for I := 1 to Length(NewName) do
begin
Ch := NewName[I];
if Ch = '.' then
begin
if InExtension or (BaseLen = 0) then
ValidName := False;
InExtension := True
end
else
begin
if (Ch <= ' ') or (Ch = ':') or (Ch = '*') or
(Ch = '?') or (Ch = ';') or (Ch = ',') or
(Ch = '=') or (Ch = '[') or (Ch = ']') or
(Ch = '<') or (Ch = '>') or (Ch = '/') or
(Ch = '\') or (Ch = '|') then
ValidName := False;
if InExtension then
ExtLen := ExtLen + 1
else
BaseLen := BaseLen + 1
end
end;
if (BaseLen > 8) or (ExtLen > 3) then
ValidName := False;
if InExtension and (ExtLen = 0) then
ValidName := False;
if not ValidName then
StatusText := 'Invalid file name (8.3).'
else if NewName = Files[P, Selected[P]] then
StatusText := 'The name is unchanged.'
else
begin
for I := 0 to 35 do
RenameFCB[I] := 0;
RenameFCB[0] := DriveNo[P];
RenameFCB[16] := DriveNo[P];
PutFCBName(0, Files[P, Selected[P]]);
PutFCBName(16, NewName);
Err := Bdos(23, Addr(RenameFCB));
if Err < 0 then
Err := Err + 256;
if Err <> 0 then
StatusText := 'Rename failed.'
else
begin
LoadDirectory(P);
for I := 1 to FileCount[P] do
if Files[P, I] = NewName then
Selected[P] := I;
EnsureVisible(P);
StatusText := 'Renamed to ' + NewName
end
end
end
end
end;
begin
Active := 1;
Quit := False;
ShowDate := False;
for ParamIndex := 1 to ParamCount do
if (ParamStr(ParamIndex) = '/o') or
(ParamStr(ParamIndex) = '/O') then
ShowDate := True;
CPM3 := BdosHL(12) >= $0030;
if CPM3 then
Bdos(45, 255);
DriveNo[1] := 1;
DriveNo[2] := 2;
FileCount[1] := 0;
FileCount[2] := 0;
Selected[1] := 0;
Selected[2] := 0;
FirstLine[1] := 1;
FirstLine[2] := 1;
Truncated[1] := False;
Truncated[2] := False;
StatusText := 'Loading drive A...';
DrawScreen;
LoadDirectory(1);
StatusText := 'Loading drive B...';
DrawScreen;
LoadDirectory(2);
StatusText := 'Arrow keys move selection.';
DrawScreen;
repeat
Read(Kbd, Key);
StatusText := '';
Redraw := True;
if Key = #27 then
begin
Read(Kbd, Key2);
if (Key2 = '[') or (Key2 = 'O') then
Read(Kbd, Key3)
else
Key3 := Key2;
if Key3 = 'A' then
begin
MoveSelection(Active, -1);
Redraw := False
end;
if Key3 = 'B' then
begin
MoveSelection(Active, 1);
Redraw := False
end
end
else if Key = #9 then
begin
if Active = 1 then
Active := 2
else
Active := 1
end
else if (Key = 'l') or (Key = 'L') then
ChangeDrive(Active)
else if (Key = 'c') or (Key = 'C') then
CopySelected
else if (Key = 'd') or (Key = 'D') then
DeleteSelected
else if (Key = 'r') or (Key = 'R') then
RenameSelected
else if (Key = 's') or (Key = 'S') then
ShowSelected
else if (Key = 'q') or (Key = 'Q') then
Quit := True;
if not Quit and Redraw then
DrawScreen
until Quit;
Bdos(26, $0080);
if CPM3 then
Bdos(45, 0);
Write(ESC,'[0m');
NormVideo;
ClrScr
end.

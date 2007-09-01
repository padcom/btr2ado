program test_keys;

{$APPTYPE CONSOLE}

uses
  ActiveX, ComObj, Classes, SysUtils, Variants, PxADODb, PxSettings,
  BtrClass, BtrConst,
  DatabaseDefinitions in '..\common\DatabaseDefinitions.pas',
  Operations in '..\common\Operations.pas';

type
   PCODERecordType = ^CODERecordType;
   CODERecordType = packed record 
     HistoryTag      : byte;
     AbsoluteId      : string[6];
     RecordStatus    : string[1];
     LastDateModified: string[7];
     LastTimeModified: string[4];
     LastUserToModify: string[4];
     CompanyCode     : string[3];
     CodeType        : string[8];
     Identifier      : string[12];
     CodeLength      : string[2];
     AlternateCode   : string[12];
     InternalCode    : string[2];
     Description     : string[40];
     RecordType      : string[1];
   end;

function GetCODEKey(RecordStatus, CompanyCode, CodeType, Code: String; HistoryTag: Byte): String;
var
  Void: CODERecordType;
begin
  FillChar(Void, SizeOf(Void), 0);
  Result := Format('%s%s%s%s%s', [
    Copy(RecordStatus + '              ', 1, SizeOf(Void.RecordStatus) - 1),
    Copy(CompanyCode + '              ', 1, SizeOf(Void.CompanyCode) - 1),
    Copy(CodeType + '              ', 1, SizeOf(Void.CodeType) - 1),
    Copy(Code + '              ', 1, SizeOf(Void.Identifier) - 1),
    Char(HistoryTag)
  ]);
end;

var
  Data: CODERecordType;
  Key: ShortString;
  PosBlock: array[0..1024] of Byte;
  DataLen: Word;
  Status: Integer;

begin
  SetIniFileName('btr2ado.ini');
  
  Key := ExpandFileName('..\data-importer\data\CODE.DAT') + #0;
  DataLen := SizeOf(Data);
  Status := BTRV(B_OPEN, PosBlock, Data, DataLen, Key, 1);
  Assert(Status = 0);
  Key := GetCODEKey(' ', 'LOT', 'COMMDRVR', '', 0);
  Status := BTRV(B_GET_GE, PosBlock, Data, DataLen, Key, 1);
  Assert(Status = 0);
  Status := BTRV(B_GET_FIRST, PosBlock, Data, DataLen, Key, 1);
  while Status = 0 do
  begin
    Writeln(Key);
    Status := BTRV(B_GET_NEXT, PosBlock, Data, DataLen, Key, 1);
  end;
  BTRV(B_CLOSE, PosBlock, Data, DataLen, Key, 1);
end.


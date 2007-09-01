program test_keys;

{$APPTYPE CONSOLE}

uses
  ActiveX, ComObj, Classes, SysUtils, Variants, PxADODb,
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
  I: Integer;
  Key: String;
  Void: CODERecordType;
begin
  FillChar(Void, SizeOf(Void), 0);
  Key := Format('%s%s%s%s%s', [
    Copy(RecordStatus + '              ', 1, SizeOf(Void.RecordStatus) - 1),
    Copy(CompanyCode + '              ', 1, SizeOf(Void.CompanyCode) - 1),
    Copy(CodeType + '              ', 1, SizeOf(Void.CodeType) - 1),
    Copy(Code + '              ', 1, SizeOf(Void.Identifier) - 1),
    Char(HistoryTag)
  ]);
  Result := '';
  for I := 1 to Length(Key) do
    Result := Result + IntToHex(Byte(Key[I]), 2);
end;

// TODO: move into FCB block. HINT: there should be one connection object per FCB (meaning per open table) to stay consistent with BTRV ways
var
  C: Connection;
  R: Recordset;
  RO: OleVariant;
  Table: TTable;

function BTRV1(Operation: Word; var PosBlock; var DataBuffer; var DataLen: Word; var KeyBuffer; KeyNumber: SmallInt): SmallInt;
  procedure UpdateKey;
  var
    Key: String;
  begin
    Key := R.Fields[Table.Indices[KeyNumber - 1].Name].Value;
    Move(Key[1], PChar(KeyBuffer)^, Length(Key));
  end;
  procedure GatherData;
  begin
    if not R.EOF then
    begin
      Table.MarshallFromFields(R.Fields, @DataBuffer);
      UpdateKey;
      Result := 0;
    end
    else
      Result := B_KEY_VALUE_NOT_FOUND;
  end;
var
  I: Integer;
  Query, Fields: String;
begin
  case Operation of
    B_OPEN:
    begin
      Fields := Table.Indices[KeyNumber - 1].Name + ', ';
      for I := 0 to Table.Fields.Count - 1 do
      begin
        Fields := Fields + Table.Fields[I].Name;
        if I < Table.Fields.Count - 1 then
          Fields := Fields + ', ';
      end;
      Query := 'SELECT ' + Fields + ' FROM ' + Table.Name;
      R.Open(Format('%s ORDER BY %s', [Query, Table.Indices[KeyNumber - 1].Name]), C, adOpenDynamic, adLockOptimistic, adCmdText);
    end;
    B_GET_EQUAL:
    begin
      if R = nil then
        Result := B_FILE_NOT_OPEN
      else
      begin
        R.Find(Format('%s = ''%s''', [Table.Indices[KeyNumber - 1].Name, PChar(KeyBuffer)]), 0, adSearchForward, 0);
        if R.EOF then
          Result := B_KEY_VALUE_NOT_FOUND
        else
        begin
          Result := B_NO_ERROR;
          GatherData;
        end;
      end;
    end;
    B_GET_NEXT:
    begin
      Assert(Assigned(R), 'Error: no previous query found');
      R.MoveNext;
      GatherData;
    end;
    B_GET_PREVIOUS:
    begin
      Assert(Assigned(R), 'Error: no previous query found');
      R.MovePrevious;
      GatherData;
    end;
    B_GET_LAST:
    begin
      Assert(Assigned(R), 'Error: no previous query found');
      R.MoveLast;
      GatherData;
    end;
    B_GET_FIRST:
    begin
      Assert(Assigned(R), 'Error: no previous query found');
      R.MoveFirst;
      GatherData;
    end;
    B_GET_GT:
    begin
      Query := Query + Format(' WHERE %s > ''%s'' ORDER BY %s', [
        Table.Indices[KeyNumber - 1].Name,
        PChar(KeyBuffer),
        Table.Indices[KeyNumber - 1].Name
      ]);
      R := C.Execute(Query, RO, 0);
      GatherData;
    end;
    B_GET_GE:
    begin
      Query := Query + Format(' WHERE %s >= ''%s'' ORDER BY %s', [
        Table.Indices[KeyNumber - 1].Name,
        PChar(KeyBuffer),
        Table.Indices[KeyNumber - 1].Name
      ]);
      R := C.Execute(Query, RO, 0);
      GatherData;
    end;
    B_GET_LT:
    begin
      Query := Query + Format(' WHERE %s < ''%s'' ORDER BY %s DESC', [
        Table.Indices[KeyNumber - 1].Name,
        PChar(KeyBuffer),
        Table.Indices[KeyNumber - 1].Name
      ]);
      R := C.Execute(Query, RO, 0);
      GatherData;
    end;
    B_GET_LE:
    begin
      Query := Query + Format(' WHERE %s <= ''%s'' ORDER BY %s', [
        Table.Indices[KeyNumber - 1].Name,
        PChar(KeyBuffer),
        Table.Indices[KeyNumber - 1].Name
      ]);
      R := C.Execute(Query, RO, 0);
      GatherData;
    end;
  end;
end;

var
  Data: CODERecordType;
  DataSize: Word;
  DDF: TDatabaseDefinition;
  Key: String;
  PosBlock: array[0..1024] of Byte;
  DataLen: Word;
  Status: Integer;

begin
  Key := ExpandFileName('..\data-importer\data\CODE.DAT');
  DataLen := SizeOf(Data);
  Status := BTRV(B_OPEN, PosBlock, Data, DataLen, Key, 1);
  Assert(Status = 0);
  Status := BTRV(B_GET_FIRST, PosBlock, Data, DataLen, Key, 1);
  while Status = 0 do
    Status := BTRV(B_GET_NEXT, PosBlock, Data, DataLen, Key, 1);
  BTRV(B_CLOSE, PosBlock, Data, DataLen, Key, 1);
  Exit;

  OleInitialize(nil);
  C := CreateCOMObject(CLASS_Connection) as Connection;
  C.Open('Provider=PostgreSQL.1;User ID=postgres;Password=qwe123;Location=test', 'postgres', 'qwe123', 0);
//  C.Open('DSN=TEST;UID=postgres;PWD=qwe123;Database=test', 'postgres', 'qwe123', 0);

  R := CreateComObject(CLASS_Recordset) as Recordset;

  R.Open('select * from CODE order by code_key_1', C, adOpenDynamic, adLockOptimistic, adCmdText);

  Key := GetCODEKey(' ', 'LOT', 'COMMDRVR', '', 0);
  Writeln(VarToStr(R.Fields[0].Value));
  Writeln(R.Fields[1].Value);
  // less than
  R.Find('code_key_1>='''+Key+'''', 0, 1, adSearchForward);
  R.MovePrevious;
  Writeln(R.Fields[0].Value);
  Writeln(R.Fields[1].Value);
  Writeln(R.Fields[2].Value);
  Writeln(R.Fields[3].Value);
  Writeln(R.Fields[4].Value);
  Writeln(R.Fields[5].Value);
  Writeln(R.Fields[6].Value);
  Writeln(R.Fields[8].Value);
  Writeln(R.Fields[9].Value);
  Writeln(R.Fields[10].Value);
  Writeln(R.Fields[11].Value);

  // less than or equal
  R.MoveFirst;
  R.Find('code_key_1>'''+Key+'''', 0, 1, adSearchForward);
  R.MovePrevious;
  Writeln(R.Fields[0].Value);
  Writeln(R.Fields[1].Value);
  Writeln(R.Fields[2].Value);
  Writeln(R.Fields[3].Value);
  Writeln(R.Fields[4].Value);
  Writeln(R.Fields[5].Value);
  Writeln(R.Fields[6].Value);
  Writeln(R.Fields[8].Value);
  Writeln(R.Fields[9].Value);
  Writeln(R.Fields[10].Value);
  Writeln(R.Fields[11].Value);

  DDF := TDatabaseDefinition.Create;
  DDF.LoadXml('..\data-importer\data\description.xml');
  Table := DDF.Tables.TableByName['code'];

  Key := GetCODEKey(' ', 'LOT', 'COMMDRVR', '', 0);
  DataSize := SizeOf(Data);

  BTRV(B_GET_GE, Key, Data, DataSize, Key, 1);
  Writeln(Key);
  while not R.EOF do
  begin
//    Writeln(R.Fields['companycode'].Value, ':', Data.CompanyCode);
//    Writeln(R.Fields['CODETYPE'].Value, ':', Data.CodeType);
//    Writeln(R.Fields['Identifier'].Value, ':', Data.Identifier);
//    Writeln(R.Fields['AlternateCode'].Value, ':', Data.AlternateCode);
//    Writeln(R.Fields['Description'].Value, ':', Data.Description);
//    Writeln('::------------------------------------::');

    BTRV(B_GET_NEXT, Key, Data, DataSize, Key, 1);
    Writeln(Key);
  end;

  C.Close;
end.


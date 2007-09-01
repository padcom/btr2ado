unit Operations;

interface

uses
  ActiveX, ComObj, Classes, SysUtils,
  PxADODb, PxSettings, BtrConst,
  DatabaseDefinitions;

const
  MAX_OPERATION               = 1024;
  B_OPERATION_NOT_IMPLEMENTED = 32767;

type
  TPosBlock = class (TObject)
    DBConnection: Connection;
    Dataset: Recordset;
    Table: TTable;
    CurrentKeyIndex: Integer;
    procedure ReloadTable;
  end;

  TKey = array[0..MAX_KEY_SIZE * 2] of Char;

  TBTRCALL = class;

  TOperation = class (TObject)
  private
    FBTRCALL: TBTRCALL;
    FConvertKey: Boolean;
  protected
    procedure UpdateKey(Table: TTable; KeyField: Field; var KeyBuffer: TKey);
    procedure GatherData(Table: TTable; Fields: Fields; var DataBuffer);
    property BTRCALL: TBTRCALL read FBTRCALL;
  public
    constructor Create(ABTRCALL: TBTRCALL);
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; virtual; abstract;
    property ConvertKey: Boolean read FConvertKey;
  end;

  TOpenOperation = class (TOperation)
  private
    function ExtractTable(var KeyBuffer: TKey): TTable;
    class function CreateQuery(Table: TTable; KeyNumber: Integer): String;
  public
    constructor Create(ABTRCALL: TBTRCALL);
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TCloseOperation = class (TOperation)
  public
    constructor Create(ABTRCALL: TBTRCALL);
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetFirstOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetNextOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetPreviousOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetLastOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetEqualOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetGreaterOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetGreaterEqualOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetLessOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TGetLessEqualOperation = class (TOperation)
  public
    function Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt; override;
  end;

  TBTRCALL = class (TObject)
  private
    FOperations: array[0..MAX_OPERATION] of TOperation;
    FDataDefinition: TDatabaseDefinition;
    function KeyBufferToSQL(KeyBuffer: PChar; KeyLength: Integer): TKey;
    function KeyBufferFromSQL(KeyBuffer: TKey; KeyLength: Integer): TKey;
  protected
    class procedure Initialize;
    class procedure Finalize;
  public
    class function Instance: TBTRCALL;
    constructor Create;
    destructor Destroy; override;
    function Execute(Operation: Word; var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
    property DataDefinition: TDatabaseDefinition read FDataDefinition;
  end;

function BTRV(Operation: Word; var PosBlock; var DataBuffer; var DataLength: Word; var KeyBuffer: ShortString; KeyNumber: SmallInt): SmallInt;

implementation

{ TPosBlock }

procedure TPosBlock.ReloadTable;
var
  Query: String;
begin
  Query := TOpenOperation.CreateQuery(Table, CurrentKeyIndex);
  Dataset.Close;
  Dataset.Open(Query, DBConnection, adOpenDynamic, adLockOptimistic, adCmdText);
end;

{ TOperation }

{ Protected declarations }

procedure TOperation.UpdateKey(Table: TTable; KeyField: Field; var KeyBuffer: TKey);
var
  Key: String;
begin
  Key := KeyField.Value;
  Move(Key[1], KeyBuffer, Length(Key));
end;

procedure TOperation.GatherData(Table: TTable; Fields: Fields; var DataBuffer);
begin
  Table.MarshallFromFields(Fields, @DataBuffer);
end;

{ Public declarations }

constructor TOperation.Create(ABTRCALL: TBTRCALL);
begin
  inherited Create;
  FBTRCALL := ABTRCALL;
  FConvertKey := True;
end;

{ TOpenOperation }

{ Private declarations }

function TOpenOperation.ExtractTable(var KeyBuffer: TKey): TTable;
var
  FileName, FileExtension, TableName: String;
begin
  FileName := ExtractFileName(PChar(@KeyBuffer));
  FileExtension := ExtractFileExt(FileName);
  TableName := Copy(FileName, 1, Length(FileName) - Length(FileExtension));
  Result := BTRCALL.DataDefinition.Tables.TableByName[TableName];
end;

class function TOpenOperation.CreateQuery(Table: TTable; KeyNumber: Integer): String;
var
  I: Integer;
  Fields: String;
begin
  Fields := Table.Indices[KeyNumber].Name + ', ';
  for I := 0 to Table.Fields.Count - 1 do
  begin
    Fields := Fields + Table.Fields[I].Name;
    if I < Table.Fields.Count - 1 then
      Fields := Fields + ', ';
  end;
  Result := 'SELECT ' + Fields + ' FROM ' + Table.Name;
  Result := Format('%s ORDER BY %s', [Result, Table.Indices[KeyNumber].Name]);
end;

{ Public declarations }

constructor TOpenOperation.Create(ABTRCALL: TBTRCALL);
begin
  inherited Create(ABTRCALL);
  FConvertKey := False;
end;

function TOpenOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  try
    OleInitialize(nil);
    TObject(PosBlock) := TPosBlock.Create;
    with TPosBlock(PosBlock) do
    begin
      Table := ExtractTable(KeyBuffer);
      DBConnection := CreateComObject(CLASS_Connection) as Connection;
      try
        DBConnection.Open(IniFile.ReadString('settings', 'connection-string', ''), '', '', 0);
//        DBConnection.Open('DSN=TEST;UID=postgres;PWD=qwe123;Database=test', 'postgres', 'qwe123', 0);
      except
        Result := B_FILE_NOT_FOUND;
        Exit;
      end;
      Dataset := CreateComObject(CLASS_Recordset) as Recordset;
      Dataset.Open(
        CreateQuery(Table, KeyNumber),
        DBConnection,
        adOpenDynamic,
        adLockOptimistic,
        adCmdText
      );
      Result := B_NO_ERROR;
    end;
  except
    TObject(PosBlock).Free;
    Result := B_OS_ERROR;
  end;
end;

{ TCloseOperation }

{ Public declarations }

constructor TCloseOperation.Create(ABTRCALL: TBTRCALL);
begin
  inherited Create(ABTRCALL);
  FConvertKey := False;
end;

function TCloseOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  if TObject(PosBlock) <> nil then
  begin
    FreeAndNil(TObject(PosBlock));
    OleUninitialize;
    Result := B_NO_ERROR;
  end
  else
    Result := B_FILE_NOT_OPEN;
end;

{ TGetFirstOperation }

{ Public declarations }

function TGetFirstOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.MoveFirst;
    if (Dataset.BOF and Dataset.EOF) then
      Result := B_END_OF_FILE
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetNextOperation }

{ Public declarations }

function TGetNextOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.MoveNext;
    if Dataset.EOF then
      Result := B_END_OF_FILE
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetNextOperation }

{ Public declarations }

function TGetPreviousOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.MovePrevious;
    if Dataset.BOF then
      Result := B_END_OF_FILE
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetLastOperation }

{ Public declarations }

function TGetLastOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.MoveLast;
    if Dataset.EOF then
      Result := B_END_OF_FILE
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetEqualOperation }

{ Public declarations }

function TGetEqualOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
var
  KeyToFind: String;
begin
  with TPosBlock(PosBlock) do
  begin
    if CurrentKeyIndex <> KeyNumber then
    begin
      CurrentKeyIndex := KeyNumber;
      ReloadTable;
    end;
    KeyToFind := Copy(PChar(@KeyBuffer), 1, Table.Indices[KeyNumber].Length);
    Dataset.Find(Format('%s = ''%s''', [Table.Indices[KeyNumber].Name, KeyToFind]), 0, adSearchForward, 0);
    if Dataset.EOF then
      Result := B_KEY_VALUE_NOT_FOUND
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetGreaterOperation }

{ Public declarations }

function TGetGreaterOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.Find(Format('%s > ''%s''', [Table.Indices[KeyNumber].Name, PChar(@KeyBuffer)]), 0, adSearchForward, 0);
    if Dataset.EOF then
      Result := B_KEY_VALUE_NOT_FOUND
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetGreaterEqualOperation }

{ Public declaratinos }

function TGetGreaterEqualOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
var
  Tmp: String;
begin
  with TPosBlock(PosBlock) do
  begin
    Tmp := Format('%s >= ''%s''', [Table.Indices[KeyNumber].Name, KeyBuffer]);
    Dataset.Find(Tmp, 0, adSearchForward, 0);
    if Dataset.EOF then
      Result := B_KEY_VALUE_NOT_FOUND
    else
    begin
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetLessOperation }

{ Public declarations }

function TGetLessOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.Find(Format('%s >= ''%s''', [Table.Indices[KeyNumber].Name, PChar(@KeyBuffer)]), 0, adSearchForward, 0);
    if (Dataset.EOF or Dataset.BOF) then
      Result := B_KEY_VALUE_NOT_FOUND
    else
    begin
      Dataset.MovePrevious;
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TGetLessEqualOperation }

{ Public declarations }

function TGetLessEqualOperation.Execute(var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer: TKey; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
begin
  with TPosBlock(PosBlock) do
  begin
    Dataset.Find(Format('%s > ''%s''', [Table.Indices[KeyNumber].Name, PChar(@KeyBuffer)]), 0, adSearchForward, 0);
    if (Dataset.EOF or Dataset.BOF) then
      Result := B_KEY_VALUE_NOT_FOUND
    else
    begin
      Dataset.MovePrevious;
      GatherData(Table, Dataset.Fields, DataBuffer);
      UpdateKey(Table, Dataset.Fields[Table.Indices[KeyNumber].Name], KeyBuffer);
      Result := B_NO_ERROR;
    end;
  end;
end;

{ TBTRCALL }

{ Private declarations }

function TBTRCALL.KeyBufferToSQL(KeyBuffer: PChar; KeyLength: Integer): TKey;
const
  HEX_NUMBERS = '0123456789ABCDEF';
var
  I: Integer;
begin
  FillChar(Result, SizeOf(Result), 0);
  for I := 0 to KeyLength - 1 do
  begin
    Result[I * 2] := HEX_NUMBERS[(PByte(KeyBuffer+I)^ and 240 + 1) shr 4 + 1];
    Result[I * 2 + 1] := HEX_NUMBERS[PByte(KeyBuffer+I)^ and 15 + 1];
  end;
end;

function TBTRCALL.KeyBufferFromSQL(KeyBuffer: TKey; KeyLength: Integer): TKey;
const
  HEX_VALUES: array['0'..'F'] of Byte = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0, $A, $B, $C, $D, $E, $F);
var
  I: Integer;
  L, H: Byte;
begin
  FillChar(Result, SizeOf(Result), 0);
  for I := 0 to KeyLength - 1 do
  begin
    H := HEX_VALUES[KeyBuffer[I * 2]] * 16;
    L := HEX_VALUES[KeyBuffer[I * 2 + 1]];
    Result[I] := Char(L + H);
  end;
end;

{ Protected declarations }

var
  _Instance: TBTRCALL = nil;

class procedure TBTRCALL.Initialize;
begin
  SetIniFileName('btr2ado.ini');
  Assert(not Assigned(_Instance), 'Error: TBTRCALL instance already initialized');
  _Instance := TBTRCALL.Create;
  _Instance.FDataDefinition := TDatabaseDefinition.Create;
  _Instance.DataDefinition.LoadXml(IniFile.ReadString('settings', 'database-definition', ''));
end;

class procedure TBTRCALL.Finalize;
begin
  FreeAndNil(_Instance.FDataDefinition);
  FreeAndNil(_Instance);
end;

{ Public declarations }

class function TBTRCALL.Instance: TBTRCALL;
begin
  Assert(Assigned(_Instance), 'Error: TBTRCALL instance not initialized');
  Result := _Instance;
end;

constructor TBTRCALL.Create;
begin
  Assert(not Assigned(_Instance), 'Error: TBTRCALL instance already initialized');

  inherited Create;
  FOperations[B_OPEN] := TOpenOperation.Create(Self);
  FOperations[B_CLOSE] := TCloseOperation.Create(Self);
  FOperations[B_GET_FIRST] := TGetFirstOperation.Create(Self);
  FOperations[B_GET_NEXT] := TGetNextOperation.Create(Self);
  FOperations[B_GET_PREVIOUS] := TGetPreviousOperation.Create(Self);
  FOperations[B_GET_LAST] := TGetLastOperation.Create(Self);
  FOperations[B_GET_EQUAL] := TGetEqualOperation.Create(Self);
  FOperations[B_GET_GT] := TGetGreaterOperation.Create(Self);
  FOperations[B_GET_GE] := TGetGreaterEqualOperation.Create(Self);
  FOperations[B_GET_LT] := TGetLessOperation.Create(Self);
  FOperations[B_GET_LE] := TGetLessEqualOperation.Create(Self);
end;

destructor TBTRCALL.Destroy;
var
  I: Integer;
begin
  for I := Low(FOperations) to High(FOperations) do
    FreeAndNil(FOperations[I]);
  inherited Destroy;
end;

function TBTRCALL.Execute(Operation: Word; var PosBlock; var DataBuffer; var DataLen: Integer; var KeyBuffer; KeyLength: Integer; KeyNumber: ShortInt): SmallInt;
var
  Key: TKey;
begin
  if Assigned(FOperations[Operation]) then
  begin
    if FOperations[Operation].ConvertKey then
    begin
      KeyLength := TPosBlock(PosBlock).Table.Indices[KeyNumber].Length div 2;
      Key := KeyBufferToSQL(@KeyBuffer, KeyLength);
      KeyLength := KeyLength * 2;
    end
    else
      Move(KeyBuffer, Key, KeyLength);
    Result := FOperations[Operation].Execute(PosBlock, DataBuffer, DataLen, Key, KeyLength, KeyNumber);
    if FOperations[Operation].ConvertKey then
    begin
      KeyLength := KeyLength div 2;
      Key := KeyBufferFromSQL(Key, KeyLength);
      Move(Key, KeyBuffer, KeyLength);
    end;
  end
  else
    Result := B_OPERATION_NOT_IMPLEMENTED;
end;

{ *** }

function BTRV(Operation: Word; var PosBlock; var DataBuffer; var DataLength: Word; var KeyBuffer: ShortString; KeyNumber: SmallInt): SmallInt;
var
  Key: TKey;
  KeyLength: Integer;
  DataLenParam: LongInt;
begin
  KeyLength := Length(KeyBuffer); // maximum key length
  FillChar(Key, SizeOf(Key), 255);
  Move(KeyBuffer[1], Key, Length(KeyBuffer));
  DataLenParam := DataLength;
  Result := TBTRCALL.Instance.Execute(Operation, PosBlock, DataBuffer, DataLenParam, Key, KeyLength, KeyNumber);
  KeyLength := 0;
  while Key[KeyLength] <> #255 do
    Inc(KeyLength);
  Move(Key, KeyBuffer[1], KeyLength);
  KeyBuffer[0] := Char(KeyLength);
  DataLength := DataLenParam;
end;

initialization
  TBTRCALL.Initialize;

finalization
  TBTRCALL.Finalize;

end.


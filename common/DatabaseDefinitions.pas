unit DatabaseDefinitions;

interface

uses
  Variants, ComObj, Classes, SysUtils, Contnrs,
  PxADODb, PxXmlFile;

type
  ENotImplemented = class (Exception);

  TTable = class;

  TField = class (TObject)
  private
    FTable: TTable;
    FName: String;
    FSize: Integer;
    function GetFieldOffset: Integer;
  protected
    function GetDataSize: Integer; virtual;
    function GetSQLDefinition: String; virtual; abstract;
    function GetAdoFieldType: OleVariant; virtual; abstract;
  public
    constructor Create(ATable: TTable);
    function ExtractValueForKey(Buffer: Pointer): String; virtual; abstract;
    function ExtractValue(Buffer: Pointer): Variant; virtual; abstract;
    procedure InsertValue(Data: Variant; Buffer: Pointer); virtual; abstract;
    property Table: TTable read FTable;
    property Name: String read FName write FName;
    property Size: Integer read FSize write FSize;
    property DataSize: Integer read GetDataSize;
    property FieldOffset: Integer read GetFieldOffset;
    property SQLDefinition: String read GetSQLDefinition;
    property AdoFieldType: OleVariant read GetAdoFieldType;
  end;

  TIntegerField = class (TField)
  protected
    function GetSQLDefinition: String; override;
    function GetAdoFieldType: OleVariant; override;
  public
    function ExtractValueForKey(Buffer: Pointer): String; override;
    function ExtractValue(Buffer: Pointer): Variant; override;
    procedure InsertValue(Data: Variant; Buffer: Pointer); override;
  end;

  TBooleanField = class (TField)
  protected
    function GetSQLDefinition: String; override;
    function GetAdoFieldType: OleVariant; override;
  public
    function ExtractValueForKey(Buffer: Pointer): String; override;
    function ExtractValue(Buffer: Pointer): Variant; override;
    procedure InsertValue(Data: Variant; Buffer: Pointer); override;
  end;

  TDateTimeField = class (TField)
  protected
    function GetSQLDefinition: String; override;
    function GetAdoFieldType: OleVariant; override;
  public
    function ExtractValueForKey(Buffer: Pointer): String; override;
    function ExtractValue(Buffer: Pointer): Variant; override;
    procedure InsertValue(Data: Variant; Buffer: Pointer); override;
  end;

  TBinaryField = class (TField)
  protected
    function GetDataSize: Integer; override;
    function GetSQLDefinition: String; override;
    function GetAdoFieldType: OleVariant; override;
  public
    function ExtractValueForKey(Buffer: Pointer): String; override;
    function ExtractValue(Buffer: Pointer): Variant; override;
    procedure InsertValue(Data: Variant; Buffer: Pointer); override;
  end;

  TStringField = class (TField)
  protected
    function GetDataSize: Integer; override;
    function GetSQLDefinition: String; override;
    function GetAdoFieldType: OleVariant; override;
  public
    function ExtractValueForKey(Buffer: Pointer): String; override;
    function ExtractValue(Buffer: Pointer): Variant; override;
    procedure InsertValue(Data: Variant; Buffer: Pointer); override;
  end;

  TFieldFactory = class
    class function CreateField(Name: String; Table: TTable): TField;
  end;

  TFieldList = class (TObjectList)
  private
    function GetItem(Index: Integer): TField;
    function GetFieldByName(FieldName: String): TField;
  public
    property Items[Index: Integer]: TField read GetItem; default;
    property FieldByName[FieldName: String]: TField read GetFieldByName;
  end;

  TIndex = class (TObject)
  private
    FTable: TTable;
    FId: Integer;
    FFields: TFieldList;
    function GetName: String;
    function GetLength: Integer;
  public
    constructor Create(ATable: TTable);
    destructor Destroy; override;
    function CalculateKey(Buffer: Pointer): String;
    property Table: TTable read FTable;
    property Id: Integer read FId write FId;
    property Name: String read GetName;
    property Fields: TFieldList read FFields;
    property Length: Integer read GetLength;
  end;

  TIndexList = class (TObjectList)
  private
    function GetItem(Index: Integer): TIndex;
  public
    property Items[Index: Integer]: TIndex read GetItem; default;
  end;

  TTable = class (TObject)
  private
    FName: String;
    FFields: TFieldList;
    FIndices: TIndexList;
    function GetSize: Integer;
  public
    constructor Create;
    destructor Destroy; override;
    function CreateInsertCommand(Buffer: Pointer): Command;
    procedure MarshallFromFields(TableFields: Fields; Buffer: Pointer);
    property Name: String read FName write FName;
    property Fields: TFieldList read FFields;
    property Indices: TIndexList read FIndices;
    property Size: Integer read GetSize;
  end;

  TTableList = class (TObjectList)
  private
    function GetItem(Index: Integer): TTable;
    function GetTableByName(TableName: String): TTable;
  public
    property Items[Index: Integer]: TTable read GetItem; default;
    property TableByName[TableName: String]: TTable read GetTableByName;
  end;

  TDatabaseDefinition = class (TObject)
  private
    FTables: TTableList;
  public
    constructor Create;
    destructor Destroy; override;
    procedure LoadXml(FileName: String);
    property Tables: TTableList read FTables;
  end;

implementation

{ TField }

{ Private declarations }

function TField.GetFieldOffset: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Table.Fields.Count - 1 do
    if Table.Fields[I] = Self then
      Break
    else
      Result := Result + Table.Fields[I].Size;
end;

function TField.GetDataSize: Integer;
begin
  Result := Size;
end;

{ Public declarations }

constructor TField.Create(ATable: TTable);
begin
  inherited Create;
  FTable := ATable;
end;

{ TIntegerField }

{ Protected declarations }

function TIntegerField.GetSQLDefinition: String;
begin
  Result := Format('%s int', [Name]);
end;

function TIntegerField.GetAdoFieldType: OleVariant;
begin
  Result := adInteger;
end;

{ Public declarations }

function TIntegerField.ExtractValueForKey(Buffer: Pointer): String;
begin
  SetLength(Result, Size);
  Move(Pointer(PChar(Buffer) + FieldOffset)^, Result[1], Size);
end;

function TIntegerField.ExtractValue(Buffer: Pointer): Variant;
var
  Value: Integer;
begin
  Value := 0;
  Move(Pointer(PChar(Buffer) + FieldOffset)^, Value, Size);
  Result := Value;
end;

procedure TIntegerField.InsertValue(Data: Variant; Buffer: Pointer);
var
  Value: Integer;
begin
  if Data = null then
    Value := 0
  else
    Value := Data;
  Move(Value, Pointer(PChar(Buffer) + FieldOffset)^, Size);
end;

{ TBooleanField }

{ Protected declarations }

function TBooleanField.GetSQLDefinition: String;
begin
  Result := Format('%s bool', [Name]);
end;

function TBooleanField.GetAdoFieldType: OleVariant;
begin
  Result := adBoolean;
end;

{ Public declarations }

function TBooleanField.ExtractValueForKey(Buffer: Pointer): String;
begin
  raise ENotImplemented.Create('Error: TBooleanField.ExtractValueForKey not yet implemented');
end;

function TBooleanField.ExtractValue(Buffer: Pointer): Variant;
var
  Value: Boolean;
begin
  Move(Pointer(PChar(Buffer) + FieldOffset)^, Value, Size);
  Result := Value;
end;

procedure TBooleanField.InsertValue(Data: Variant; Buffer: Pointer);
var
  Value: Boolean;
begin
  if Data = null then
    Value := False
  else
    Value := Data;
  Move(Value, Pointer(PChar(Buffer) + FieldOffset)^, Size);
end;

{ TDateTimeField }

{ Protected declarations }

function TDateTimeField.GetSQLDefinition: String;
begin
  Result := Format('%s timestamp', [Name]);
end;

function TDateTimeField.GetAdoFieldType: OleVariant;
begin
  Result := adDBTimeStamp;
end;

{ Public declarations }

function TDateTimeField.ExtractValueForKey(Buffer: Pointer): String;
begin
  raise ENotImplemented.Create('Error: TDateTimeField.ExtractValueForKey not yet implemented');
end;

function TDateTimeField.ExtractValue(Buffer: Pointer): Variant;
var
  Value: TDateTime;
begin
  Move(Pointer(PChar(Buffer) + FieldOffset)^, Value, Size);
  Result := Value;
end;

procedure TDateTimeField.InsertValue(Data: Variant; Buffer: Pointer);
var
  Value: TDateTime;
begin
  if Data = null then
    Value := 9
  else
    Value := Data;
  Move(Value, Pointer(PChar(Buffer) + FieldOffset)^, Size);
end;

{ TStringField }

{ Protected declarations }

function TStringField.GetDataSize: Integer;
begin
  Result := Size - 1;
end;

function TStringField.GetSQLDefinition: String;
begin
  Result := Format('%s char(%d)', [Name, Size - 1]);
end;

function TStringField.GetAdoFieldType: OleVariant;
begin
  Result := adChar;
end;

{ Public declarations }

function TStringField.ExtractValueForKey(Buffer: Pointer): String;
begin
  SetLength(Result, Size - 1);
  Move(Pointer(PChar(Buffer) + FieldOffset + 1)^, Result[1], Size - 1);
end;

function TStringField.ExtractValue(Buffer: Pointer): Variant;
var
  Value: String;
begin
  SetLength(Value, Size - 1);
  Move(Pointer(PChar(Buffer) + FieldOffset + 1)^, Value[1], Size - 1);
  Result := Value;
end;

procedure TStringField.InsertValue(Data: Variant; Buffer: Pointer);
var
  Value: String;
begin
  Value := VarToStr(Data);
  PByte(PChar(Buffer) + FieldOffset)^ := Length(Value);
  Move(Value[1], Pointer(PChar(Buffer) + FieldOffset + 1)^, Size - 1);
end;

{ TBinaryField }

{ Protected declarations }

function TBinaryField.GetDataSize: Integer;
begin
  Result := Size * 2;
end;

function TBinaryField.GetSQLDefinition: String;
begin
  Result := Format('%s char(%d)', [Name, Size * 2]);
end;

function TBinaryField.GetAdoFieldType: OleVariant;
begin
  Result := adChar;
end;

{ Public declarations }

const
  HEX_NUMBERS: String = '0123456789ABCDEF';

function BinaryToString(Buffer: Pointer; BufferSize: Integer): String;
var
  I: Integer;
  B: PByte;
begin
  SetLength(Result, BufferSize * 2);
  FillChar(Result[1], BufferSize * 2, 20);
  for I := 0 to BufferSize - 1 do
  begin
    B := PByte(PChar(Buffer) + I);
    Result[I * 2 + 1] := HEX_NUMBERS[(B^ and 240 + 1) shr 4 + 1];
    Result[I * 2 + 2] := HEX_NUMBERS[B^ and 15 + 1];
  end;
end;

procedure StringToBinary(S: String; Buffer: Pointer);
const
  HEX_VALUES: array['0'..'F'] of Byte = (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 0, 0, 0, 0, 0, 0, 0, $A, $B, $C, $D, $E, $F);
var
  I: Integer;
  L, H: Byte;
begin
  for I := 0 to Length(S) div 2 - 1 do
  begin
    H := HEX_VALUES[S[I * 2 + 1]] * 16;
    L := HEX_VALUES[S[I * 2 + 2]];
    PByte(PChar(Buffer) + I)^ := L + H;
  end;
end;

function TBinaryField.ExtractValueForKey(Buffer: Pointer): String;
begin
  SetLength(Result, Size - 1);
  Move(Pointer(PChar(Buffer) + FieldOffset + 1)^, Result[1], Size - 1);
end;

function TBinaryField.ExtractValue(Buffer: Pointer): Variant;
begin
  Result := BinaryToString(PChar(Buffer) + FieldOffset, Size);
end;

procedure TBinaryField.InsertValue(Data: Variant; Buffer: Pointer);
var
  Value: String;
begin
  Value := Data;
  StringToBinary(Value, PChar(Buffer) + FieldOffset);
//  PByte(PChar(Buffer) + FieldOffset)^ := Length(Value) div 2;
end;

{ TFieldFactory }

class function TFieldFactory.CreateField(Name: String; Table: TTable): TField;
begin
  if AnsiSameText('Byte', Name) then
  begin
    Result := TIntegerField.Create(Table);
    Result.Size := 1;
  end
  else if AnsiSameText('ShortInt', Name) then
  begin
    Result := TIntegerField.Create(Table);
    Result.Size := 1;
  end
  else if AnsiSameText('Integer', Name) then
  begin
    Result := TIntegerField.Create(Table);
    Result.Size := 4;
  end
  else if AnsiSameText('LongWord', Name) then
  begin
    Result := TIntegerField.Create(Table);
    Result.Size := 4;
  end
  else if AnsiSameText('String', Name) then
    Result := TStringField.Create(Table)
  else if AnsiSameText('Boolean', Name) then
    Result := TBooleanField.Create(Table)
  else if AnsiSameText('DateTime', Name) then
    Result := TDateTimeField.Create(Table)
  else if AnsiSameText('Binary', Name) then
    Result := TBinaryField.Create(Table)
  else
    raise Exception.CreateFmt('Error: unknown field type %s', [Name]);
end;

{ TFieldList }

{ Private declarations }

function TFieldList.GetItem(Index: Integer): TField;
begin
  Result := TObject(Get(Index)) as TField;
end;

function TFieldList.GetFieldByName(FieldName: String): TField;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if AnsiSameText(Items[I].Name, FieldName) then
    begin
      Result := Items[I];
      Break;
    end;
end;

{ TIndex }

{ Private declaration }

function TIndex.GetName: String;
begin
  Result := Format('%s_KEY_%d', [Table.Name, Id]);
end;

function TIndex.GetLength: Integer;
var
  Buffer: Pointer;
begin
  GetMem(Buffer, Table.Size);
  try
    Result := System.Length(CalculateKey(Buffer));
  finally
    FreeMem(Buffer);
  end;
end;

{ Public declarations }

constructor TIndex.Create(ATable: TTable);
begin
  inherited Create;
  FTable := ATable;
  FFields := TFieldList.Create(False);
end;

destructor TIndex.Destroy;
begin
  FreeAndNil(FFields);
  inherited Destroy;
end;

function TIndex.CalculateKey(Buffer: Pointer): String;
var
  I: Integer;
  Key: String;
begin
  Key := '';
  for I := 0 to Fields.Count - 1 do
    Key := Key + Fields[I].ExtractValueForKey(Buffer);
  Result := '';
  for I := 1 to System.Length(Key) do
    Result := Result + IntToHex(Byte(Key[I]), 2);
end;

{ TIndexList }

function TIndexList.GetItem(Index: Integer): TIndex;
begin
  Result := TObject(Get(Index)) as TIndex;
end;

{ TTable }

{ Private declarations }

function TTable.GetSize: Integer;
var
  I: Integer;
begin
  Result := 0;
  for I := 0 to Fields.Count - 1 do
    Result := Result + Fields[I].Size;
end;

{ Public declarations }

constructor TTable.Create;
begin
  inherited Create;
  FFields := TFieldList.Create(True);
  FIndices := TIndexList.Create(True);
end;

destructor TTable.Destroy;
begin
  FreeAndNil(FIndices);
  FreeAndNil(FFields);
  inherited Destroy;
end;

procedure TTable.MarshallFromFields(TableFields: Fields; Buffer: Pointer);
var
  I: Integer;
  Field: TField;
begin
  for I := 0 to TableFields.Count - 1 do
  begin
    Field := Fields.FieldByName[TableFields[I].Name];
    if not Assigned(Field) then
      Continue;
    Field.InsertValue(TableFields[I].Value, Buffer);
  end;
end;

// TODO: Split into logical blocks, maybe into a class
function TTable.CreateInsertCommand(Buffer: Pointer): Command;
var
  I: Integer;
begin
  Result := CreateComObject(CLASS_Command) as Command;
  Result.CommandText := 'INSERT INTO ' + Name + ' (';

  for I := 0 to Indices.Count - 1 do
    Result.CommandText := Result.CommandText + Indices[I].Name + ', ';

  for I := 0 to Fields.Count - 1 do
  begin
    Result.CommandText := Result.CommandText + Fields[I].Name;
    if I < Fields.Count - 1 then
      Result.CommandText := Result.CommandText + ',';
  end;

  Result.CommandText := Result.CommandText + ') VALUES (';

  for I := 0 to Indices.Count - 1 do
    Result.CommandText := Result.CommandText + '?,';

  for I := 0 to Fields.Count - 1 do
  begin
    Result.CommandText := Result.CommandText + '?';
    if I < Fields.Count - 1 then
      Result.CommandText := Result.CommandText + ',';
  end;

  Result.CommandText := Result.CommandText + ')';

  for I := 0 to Indices.Count - 1 do
  begin
    Result.Parameters.Append(
      Result.CreateParameter(
        Indices[I].Name,
        adChar,
        adParamInput,
        Indices[I].Length,
        Indices[I].CalculateKey(Buffer)
      )
    );
  end;

  for I := 0 to Fields.Count - 1 do
    Result.Parameters.Append(
      Result.CreateParameter(
        Fields[I].Name,
        Fields[I].AdoFieldType,
        adParamInput,
        Fields[I].DataSize,
        Fields[I].ExtractValue(Buffer)
      )
    );
end;

{ TTableList }

{ Private declarations }

function TTableList.GetItem(Index: Integer): TTable;
begin
  Result := TObject(Get(Index)) as TTable;
end;

function TTableList.GetTableByName(TableName: String): TTable;
var
  I: Integer;
begin
  Result := nil;
  for I := 0 to Count - 1 do
    if AnsiSameText(Items[I].Name, TableName) then
    begin
      Result := Items[I];
      Break;
    end;
end;

{ TDatabaseDefinition }

{ Public declarations }

constructor TDatabaseDefinition.Create;
begin
  inherited Create;
  FTables := TTableList.Create(True);
end;

destructor TDatabaseDefinition.Destroy;
begin
  FreeAndNil(FTables);
  inherited Destroy;
end;

// TODO: move content to respective classes !!!
procedure TDatabaseDefinition.LoadXml(FileName: String);
var
  I, J, K, L, M, N: Integer;
  XmlReader: TPxXmlFile;
  TablesRoot: TPxXmlItem;
  TableRoot: TPxXmlItem;
  FieldsRoot: TPxXmlItem;
  IndicesRoot: TPxXmlItem;
  FieldRoot: TPxXmlItem;
  IndexRoot: TPxXmlItem;
  IndexFieldsRoot: TPxXmlItem;
  Table: TTable;
  Field: TField;
  Index: TIndex;
begin
  XmlReader := TPxXmlFile.Create;
  try
    XmlReader.ReadFile(FileName);
    TablesRoot := XmlReader.XmlItem.GetItemByName('tables');
    for I := 0 to TablesRoot.ItemCount - 1 do
      if TablesRoot.Items[I].Name = 'table' then
      begin
        TableRoot := TablesRoot.Items[I];
        Table := TTable.Create;
        Tables.Add(Table);
        
        Table.Name := TableRoot.GetParamByNameS('name');
        for J := 0 to TableRoot.ItemCount - 1 do
          if TableRoot.Items[J].Name = 'fields' then
          begin
            FieldsRoot := TableRoot.Items[J];
            for K := 0 to FieldsRoot.ItemCount - 1 do
              if FieldsRoot.Items[K].Name = 'field' then
              begin
                FieldRoot := FieldsRoot.Items[K];
                Field := TFieldFactory.CreateField(FieldRoot.GetParamByNameS('type'), Table);
                Field.Name := FieldRoot.GetParamByNameS('name');
                Field.Size := FieldRoot.GetParamByName('size').AsInteger;
                Table.Fields.Add(Field);
              end;
          end
          else if TableRoot.Items[J].Name = 'indices' then
          begin
            IndicesRoot := TableRoot.Items[J];
            for K := 0 to IndicesRoot.ItemCount - 1 do
              if IndicesRoot.Items[K].Name = 'index' then
              begin
                IndexRoot := IndicesRoot.Items[K];

                Index := TIndex.Create(Table);
                Table.Indices.Add(Index);

                Index.Id := IndexRoot.GetParamByName('id').AsInteger;
                for L := 0 to IndexRoot.ItemCount - 1 do
                  if IndexRoot.Items[L].Name = 'fields' then
                  begin
                    IndexFieldsRoot := IndexRoot.Items[L];
                    for M := 0 to IndexFieldsRoot.ItemCount - 1 do
                      if IndexFieldsRoot.Items[M].Name = 'field' then
                      begin
                        Field := nil;
                        for N := 0 to Table.Fields.Count - 1 do
                          if Table.Fields[N].Name = IndexFieldsRoot.Items[M].GetParamByNameS('name') then
                          begin
                            Field := Table.Fields[N];
                            Break;
                          end;
                        Assert(Assigned(Field), Format('Error: field %s not defined', [IndexFieldsRoot.Items[M].GetParamByNameS('name')]));
                        Index.Fields.Add(Field);
                      end;
                  end;
              end;
          end;
      end;
  finally
    XmlReader.Free;
  end;
end;

end.


unit DatabaseDefinitions;

interface

uses
  ComObj, Classes, SysUtils, Contnrs,
  PxADODb, PxXmlFile;

type
  TTable = class;

  TField = class (TObject)
  private
    FTable: TTable;
    FName: String;
    FSize: Integer;
    function GetFieldOffset: Integer;
  protected
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

  TStringField = class (TField)
  protected
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
  Value := Data;
  Move(Value, Pointer(PChar(Buffer) + FieldOffset)^, Size);
end;

{ TStringField }

{ Protected declarations }

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
  Value := Data;
  PByte(PChar(Buffer) + FieldOffset)^ := Length(Value);
  Move(Value[1], Pointer(PChar(Buffer) + FieldOffset + 1)^, Size - 1);
end;

{ TFieldFactory }

class function TFieldFactory.CreateField(Name: String; Table: TTable): TField;
begin
  if AnsiSameText('Byte', Name) then
  begin
    Result := TIntegerField.Create(Table);
    Result.Size := 1;
  end
  else if AnsiSameText('Integer', Name) then
  begin
    Result := TIntegerField.Create(Table);
    Result.Size := 4;
  end
  else if AnsiSameText('String', Name) then
    Result := TStringField.Create(Table)
  else
    Result := nil;
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
      Result.CommandText := Result.CommandText + ', ';
  end;

  Result.CommandText := Result.CommandText + ') VALUES (';

  for I := 0 to Indices.Count - 1 do
    Result.CommandText := Result.CommandText + '?, ';

  for I := 0 to Fields.Count - 1 do
  begin
    Result.CommandText := Result.CommandText + '?';
    if I < Fields.Count - 1 then
      Result.CommandText := Result.CommandText + ', ';
  end;

  Result.CommandText := Result.CommandText + ')';

  for I := 0 to Indices.Count - 1 do
    Result.Parameters.Append(
      Result.CreateParameter(
        Fields[I].Name,
        adChar,
        adParamInput,
        50,
        Indices[I].CalculateKey(Buffer)
      )
    );

  for I := 0 to Fields.Count - 1 do
    Result.Parameters.Append(
      Result.CreateParameter(
        Fields[I].Name,
        Fields[I].AdoFieldType,
        adParamInput,
        Fields[I].Size,
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


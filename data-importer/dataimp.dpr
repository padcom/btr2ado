program dataimp;

{$APPTYPE CONSOLE}

uses
  ActiveX, ComObj, Classes, SysUtils, Variants, PxADODb,
  BtrClass, BtrConst,
  Options in 'cui\Options.pas',
  DatabaseDefinitions in '..\common\DatabaseDefinitions.pas';

function CreateTableQuery(Table: TTable): String;
var
  I: Integer;
begin
  Result := Format('CREATE TABLE %s (RecordId serial PRIMARY KEY,', [Table.Name]);
  for I := 0 to Table.Indices.Count - 1 do
    Result := Result + Format('%s char(%d),', [Table.Indices[I].Name, Table.Indices[I].Length]);
  for I := 0 to Table.Fields.Count - 1 do
  begin
    Result := Result + Table.Fields[I].SQLDefinition;
    if I < Table.Fields.Count - 1 then
      Result := Result + ',';
  end;
  Result := Result + ')';
end;

function CreateTableIndex(Index: TIndex): String;
begin
  Result := Format('CREATE INDEX %s ON %s USING btree (%s)', [
    Index.Name,
    Index.Table.Name,
    Index.Name
  ]);
end;

var
  DescrFile: TDatabaseDefinition;
  Table: TTable;
  C: Connection;
  Cmd, RO: OleVariant;
  Buffer: Pointer;
  BFile: TBtrvFile;
  I: Integer;

begin
  OleInitialize(nil);
  DescrFile := TDatabaseDefinition.Create;
  try
    DescrFile.LoadXml(TOptions.Instance.DataDescriptionFile);
    Table := DescrFile.Tables.TableByName[TOptions.Instance.TableName];

    GetMem(Buffer, Table.Size);
    BFile := TBtrvFile.Create;
    try
      BFile.SetFilePath(ExpandFileName(TOptions.Instance.InputFile));
      BFile.SetDataBuffer(Buffer);
      BFile.SetDataLength(Table.Size);
      BFile.Open;

      C := CreateComObject(CLASS_Connection) as Connection;
      C.Open(TOptions.Instance.ConnectionString, '', '', 0);
      try
        C.Execute(Format('DROP TABLE %S CASCADE ', [Table.Name]), RO, 0);
      except
        // silently skip an exception because it's an information that the table does not exist
      end;
      C.Execute(CreateTableQuery(Table), RO, 0);

      for I := 0 to Table.Indices.Count - 1 do
        C.Execute(CreateTableIndex(Table.Indices[I]), RO, 0);

      BFile.StepFirst;
      while BFile.GetLastStatus = B_NO_ERROR do
      begin
        Cmd := Table.CreateInsertCommand(Buffer);
        Cmd.ActiveConnection := C;
        Cmd.Execute;
        BFile.StepNext;
      end;
    finally
      BFile.Free;
    end;

  finally
    DescrFile.Free;
  end;
end.


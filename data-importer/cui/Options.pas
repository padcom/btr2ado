unit Options;

interface

uses
  Classes, SysUtils,
  PxCommandLine, PxSettings;

type
  TOptions = class (TPxCommandLineParser)
  private
    function GetHelp: Boolean;
    function GetQuiet: Boolean;
    function GetInputFile: String;
    function GetDataDescriptionFile: String;
    function GetConnectionString: String;
    function GetTableName: String;
  protected
    class procedure Initialize;
    class procedure Finalize;
    procedure CreateOptions; override;
    procedure AfterParseOptions; override;
  public
    class function Instance: TOptions;
    constructor Create;
    property Help: Boolean read GetHelp;
    property Quiet: Boolean read GetQuiet;
    property InputFile: String read GetInputFile;
    property DataDescriptionFile: String read GetDataDescriptionFile;
    property ConnectionString: String read GetConnectionString;
    property TableName: String read GetTableName;
  end;

implementation

{ TOptions }

{ Private declarations }

function TOptions.GetHelp: Boolean;
begin
  Result := ByName['help'].Value;
end;

function TOptions.GetQuiet: Boolean;
begin
  Result := ByName['quiet'].Value;
end;

function TOptions.GetInputFile: String;
begin
  Result := ByName['input-file'].Value;
end;

function TOptions.GetDataDescriptionFile: String;
begin
  Result := ByName['data-description-file'].Value;
end;

function TOptions.GetConnectionString: String;
begin
  Result := ByName['connection-string'].Value;
end;

function TOptions.GetTableName: String;
begin
  Result := ByName['table'].Value;
end;

{ Protected declarations }

var
  _Instance: TOptions = nil;

class procedure TOptions.Initialize;
begin
  _Instance := TOptions.Create;
  _Instance.Parse;
end;

class procedure TOptions.Finalize;
begin
  FreeAndNil(_Instance);
end;

procedure TOptions.CreateOptions;
begin
  with AddOption(TPxBoolOption.Create('h', 'help')) do
    Explanation := 'Show help';
  with AddOption(TPxBoolOption.Create('q', 'quiet')) do
    Explanation := 'Be quiet';
  with AddOption(TPxStringOption.Create('i', 'input-file')) do
  begin
    Explanation := 'Input file (BTrieve data file)';
    Value := IniFile.ReadString('settings', LongForm, '');
  end;
  with AddOption(TPxStringOption.Create('d', 'data-description-file')) do
  begin
    Explanation := 'Xml representation of data structure and indices';
    Value := IniFile.ReadString('settings', LongForm, '');
  end;
  with AddOption(TPxStringOption.Create('c', 'connection-string')) do
  begin
    Explanation := 'Connection string to connect to the database';
    Value := IniFile.ReadString('settings', LongForm, '');
  end;
  with AddOption(TPxStringOption.Create('t', 'table')) do
  begin
    Explanation := 'Table to import the data into';
    Value := IniFile.ReadString('settings', LongForm, '');
  end;
end;

procedure TOptions.AfterParseOptions;
begin
  if not Quiet then
  begin
    Writeln(ExtractFileName(ParamStr(0)), ' - BTrieve to SQL data converter');
    Writeln('Copyright (c) 2007 Matthias Hryniszak');
    Writeln;
  end;

  if Help then
  begin
    WriteExplanations;
    Halt(0);
  end;

  if (InputFile = '') or (not FileExists(InputFile)) then
  begin
    Writeln('Error: input file not specified or does not exists');
    Halt(1);
  end;

  if (DataDescriptionFile = '') or (not FileExists(DataDescriptionFile)) then
  begin
    Writeln('Error: data description file not specified or does not exists');
    Halt(2);
  end;

  if ConnectionString = '' then
  begin
    Writeln('Error: no connection string specified');
    Halt(3);
  end;

  if TableName = '' then
  begin
    Writeln('Error: no table specified');
    Halt(4);
  end;
end;

{ Public declarations }

class function TOptions.Instance: TOptions;
begin
  Assert(Assigned(_Instance), 'Error: TOptions.Instance not initialized');
  Result := _Instance;
end;

constructor TOptions.Create;
begin
  Assert(not Assigned(_Instance), 'Error: TOptions.Instance already initialized');
  inherited Create;
end;

initialization
  TOptions.Initialize;

finalization
  TOptions.Finalize;

end.


library btr2ado;

uses
  DatabaseDefinitions in '..\common\DatabaseDefinitions.pas',
  Operations in '..\common\Operations.pas';

function BTRCALL(Operation: Word; var PosBlock; var DataBuffer; var DataLen: LongInt;
  var KeyBuffer; KeyLength: BYTE; KeyNum: ShortInt): SmallInt; far; stdcall;
begin
  Result := TBTRCALL.Instance.Execute(Operation, PosBlock, DataBuffer, DataLen, KeyBuffer, KeyLength, KeyNum);
end;

function BTRCALLID(Operation: Word; var PosBlock; var DataBuffer; var DataLen: LongInt;
  var KeyBuffer; KeyLength: BYTE; KeyNum: ShortInt; var ClientId): SmallInt; far; stdcall;
begin
  Result := TBTRCALL.Instance.Execute(Operation, PosBlock, DataBuffer, DataLen, KeyBuffer, KeyLength, KeyNum);
end;

exports
  BTRCALL,
  BTRCALLID;

end.
  

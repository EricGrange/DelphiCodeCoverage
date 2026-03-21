unit UnitNameHelper;

interface

uses
  System.Classes;

function StripDelphiExtension(const AFileName: string): string;
function MatchesAnyMask(const AString: string; AMasks: TStrings): Boolean;

implementation

uses
  System.SysUtils,
  System.Masks;

function StripDelphiExtension(const AFileName: string): string;
var
  Ext: string;
begin
  Ext := ExtractFileExt(AFileName);
  if SameText(Ext, '.pas') or SameText(Ext, '.pp') or SameText(Ext, '.dpr') or SameText(Ext, '.dpk') or SameText(Ext, '.inc') then
    Result := Copy(AFileName, 1, Length(AFileName) - Length(Ext))
  else
    Result := AFileName;
end;

function MatchesAnyMask(const AString: string; AMasks: TStrings): Boolean;
var
  Mask: string;
begin
  Result := False;
  if not Assigned(AMasks) then
    Exit;

  for Mask in AMasks do
  begin
    if MatchesMask(AString, Mask) then
    begin
      Result := True;
      Break;
    end;
  end;
end;

end.

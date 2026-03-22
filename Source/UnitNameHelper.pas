unit UnitNameHelper;

interface

uses
  System.Classes;

function StripDelphiExtension(const AFileName: string): string;
function MatchesAnyMask(const AString: string; AMasks: TStrings): Boolean;
function FindSourceFile(const AFileName: string; const ASourcePaths: TStrings): string;

implementation

uses
  System.SysUtils,
  System.IOUtils,
  System.Masks,
  JclFileUtils;

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

function FindSourceFile(const AFileName: string; const ASourcePaths: TStrings): string;
var
  SourcePath: string;
  FoundFiles: TArray<string>;
begin
  Result := AFileName;
  if (AFileName = '') or not Assigned(ASourcePaths) then
    Exit;

  // 1. Direct check in each source path
  for SourcePath in ASourcePaths do
  begin
    if SourcePath = '' then
      Result := AFileName
    else
      Result := PathAppend(SourcePath, AFileName);

    if FileExists(Result) then
    begin
      Result := TPath.GetFullPath(Result);
      Exit;
    end;
  end;

  // 2. Recursive search in each source path
  for SourcePath in ASourcePaths do
  begin
    if (SourcePath <> '') and DirectoryExists(SourcePath) then
    begin
      try
        FoundFiles := TDirectory.GetFiles(SourcePath, AFileName, TSearchOption.soAllDirectories);
        if Length(FoundFiles) > 0 then
        begin
          Result := TPath.GetFullPath(FoundFiles[0]);
          Exit;
        end;
      except
        // Ignore directory access errors
      end;
    end;
  end;

  // 3. Fallback to original filename
  Result := AFileName;
end;

end.

(***********************************************************************)
(* Delphi Code Coverage                                                *)
(*                                                                     *)
(* A quick hack of a Code Coverage Tool for Delphi                     *)
(* by Christer Fahlgren and Nick Ring                                  *)
(*                                                                     *) 
(* This Source Code Form is subject to the terms of the Mozilla Public *)
(* License, v. 2.0. If a copy of the MPL was not distributed with this *)
(* file, You can obtain one at http://mozilla.org/MPL/2.0/.            *)

unit CCGCoverageReport;

interface

uses
  System.Classes,
  System.SysUtils,
  System.Generics.Collections,
  I_Report,
  I_CoverageStats,
  I_CoverageConfiguration,
  ClassInfoUnit,
  I_LogManager;

type
  TCCGCoverageReport = class(TInterfacedObject, IReport)
  strict private
    FCoverageConfiguration: ICoverageConfiguration;
    function CompressGaps(const AGaps: TList<Integer>): string;
  public
    constructor Create(const ACoverageConfiguration: ICoverageConfiguration);

    procedure Generate(
      const ACoverage: ICoverageStats;
      const AModuleInfoList: TModuleList;
      const ALogManager: ILogManager);
  end;

implementation

uses
  System.Math,
  JclFileUtils,
  CoverageStats,
  uConsoleOutput,
  UnitNameHelper;

constructor TCCGCoverageReport.Create(const ACoverageConfiguration: ICoverageConfiguration);
begin
  inherited Create;
  FCoverageConfiguration := ACoverageConfiguration;
end;

function TCCGCoverageReport.CompressGaps(const AGaps: TList<Integer>): string;
var
  I, StartLine, LastLine: Integer;
begin
  Result := '';
  if AGaps.Count = 0 then
    Exit;

  AGaps.Sort;
  
  I := 0;
  while I < AGaps.Count do
  begin
    StartLine := AGaps[I];
    LastLine := StartLine;
    
    while (I + 1 < AGaps.Count) and (AGaps[I + 1] = LastLine + 1) do
    begin
      Inc(I);
      LastLine := AGaps[I];
    end;
    
    if Result <> '' then
      Result := Result + ', ';
      
    if StartLine = LastLine then
      Result := Result + IntToStr(StartLine)
    else
      Result := Result + IntToStr(StartLine) + '-' + IntToStr(LastLine);
      
    Inc(I);
  end;
end;

procedure TCCGCoverageReport.Generate(
  const ACoverage: ICoverageStats;
  const AModuleInfoList: TModuleList;
  const ALogManager: ILogManager);
var
  CCGFile: TStringList;
  ModuleInfo: TModuleInfo;
  ClassInfo: TClassInfo;
  ProcInfo: TProcedureInfo;
  Gaps: TList<Integer>;
  LineNo: Integer;
  MinLine, MaxLine: Integer;
  TotalLines, CoveredLines: Integer;
  ProjectName: string;
  SourcePath: string;
begin
  ProjectName := ExtractFileName(FCoverageConfiguration.ExeFileName);
  if ProjectName = '' then
    ProjectName := ExtractFileName(FCoverageConfiguration.MapFileName);
  ProjectName := ChangeFileExt(ProjectName, '');

  CCGFile := TStringList.Create;
  Gaps := TList<Integer>.Create;
  try
    // Part A: Global Header
    CCGFile.Add('PROJECT: ' + ProjectName);
    CCGFile.Add('TIMESTAMP: ' + FormatDateTime('yyyy-mm-dd"T"hh:nn:ss"Z"', Now));
    CCGFile.Add('TOTAL_COVERAGE: ' + FormatFloat('0.00', ACoverage.PercentCovered) + '%');
    CCGFile.Add('GLOBAL_STATS: ' + IntToStr(ACoverage.CoveredLineCount) + '/' + IntToStr(ACoverage.LineCount));
    CCGFile.Add('');

    // Part B: Per-Unit Gaps
    for ModuleInfo in AModuleInfoList do
    begin
      TotalLines := ModuleInfo.LineCount;
      CoveredLines := ModuleInfo.CoveredLineCount;
      
      // Omit units with 100% coverage
      if CoveredLines < TotalLines then
      begin
        SourcePath := FindSourceFile(ModuleInfo.ModuleFileName, FCoverageConfiguration.SourcePaths);
        CCGFile.Add('UNIT: ' + ModuleInfo.ModuleName + ' | ' + SourcePath);
        CCGFile.Add('  COVERAGE: ' + FloatToStrF(CoveredLines * 100 / TotalLines, ffFixed, 7, 1) + '% (' + IntToStr(CoveredLines) + '/' + IntToStr(TotalLines) + ' lines)');
        CCGFile.Add('');
        
        for ClassInfo in ModuleInfo do
        begin
          for ProcInfo in ClassInfo do
          begin
            // Omit methods with 100% coverage
            if ProcInfo.CoveredLineCount < ProcInfo.LineCount then
            begin
              Gaps.Clear;
              MinLine := MaxInt;
              MaxLine := 0;
              
              for LineNo in ProcInfo do
              begin
                MinLine := Min(MinLine, LineNo);
                MaxLine := Max(MaxLine, LineNo);
                
                if not ProcInfo.IsLineCovered(LineNo) then
                  Gaps.Add(LineNo);
              end;
              
              if Gaps.Count > 0 then
              begin
                // Use METH: for class methods, FUNC: for standalone functions.
                // We treat it as a standalone function if it's in 'Global' or if ClassName == ProcName (with 1 method).
                if (ClassInfo.TheClassName <> '') and (ClassInfo.TheClassName <> 'Global') and 
                   ((ClassInfo.TheClassName <> ProcInfo.Name) or (ClassInfo.ProcedureCount > 1)) then
                  CCGFile.Add('  METH: ' + IntToStr(MinLine) + '-' + IntToStr(MaxLine) + ' ' + ClassInfo.TheClassName + '.' + ProcInfo.Name)
                else
                  CCGFile.Add('  FUNC: ' + IntToStr(MinLine) + '-' + IntToStr(MaxLine) + ' ' + ProcInfo.Name);
                CCGFile.Add('    GAPS: ' + CompressGaps(Gaps));
              end;
            end;
          end;
        end;
        CCGFile.Add('');
      end;
    end;

    CCGFile.SaveToFile(PathAppend(FCoverageConfiguration.OutputDir, 'CodeCoverage_Gaps.ccg'));
  finally
    Gaps.Free;
    CCGFile.Free;
  end;
end;

end.

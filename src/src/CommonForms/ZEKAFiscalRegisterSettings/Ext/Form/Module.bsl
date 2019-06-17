
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("SelfTest") Then
		Return;
	EndIf;
	
	Parameters.Property("ID", ID);
	Title = NStr("en = 'FR'") + " """ + String(ID) + """";
	Parameters.Property("PathFprwin", PathFprwin);
	If IsBlankString(PathFprwin) Then
		PathFprwin = "C:\SaleEquipmentDrivers\fprwin_en.bat";
	EndIf;
	Parameters.Property("PathXReport", PathXReport);
	If IsBlankString(PathXReport) Then
		PathXReport = "C:\SaleEquipmentDrivers\X.bat";
	EndIf;
	Parameters.Property("PathZReport", PathZReport);
	If IsBlankString(PathZReport) Then
		PathZReport = "C:\SaleEquipmentDrivers\Z.bat";
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

// 
//
// Parameters:
//  
//
&AtClient
Procedure WriteAndCloseExecute()
	
	Parameters.SettingParameters.Add(PathFprwin, "PathFprwin");
	Parameters.SettingParameters.Add(PathXReport, "PathXReport");
	Parameters.SettingParameters.Add(PathZReport, "PathZReport");
	PathSimpleBon = StrReplace(PathFprwin, "fprwin_en.bat", "simple.bon");
	Parameters.SettingParameters.Add(PathSimpleBon, "PathSimpleBon");
	ClearMessages();
	Close(DialogReturnCode.OK);
	
EndProcedure

&AtClient
Procedure DeviceTest(Presentation)

	TestResult = Undefined;
	StructureOfFiles = New Structure;
	StructureOfFiles.Insert("Fprwin",  PathFprwin);
	StructureOfFiles.Insert("XReport", PathXReport);
	StructureOfFiles.Insert("ZReport", PathZReport);
	
	For Each TestFile In StructureOfFiles Do
		File = New File(TestFile.Value);
		
		If Not File.Exist() Then
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'File %1 does not exist. Ensure the file path is correct.'"),
				TestFile.Key);
			CommonUseClientServer.MessageToUser(TextMessage,, "Path" + TestFile.Key);			
			
			Return;
			
		EndIf;
	EndDo;
	
	TextMessage = NStr("en = 'Success. All files exist.'");
	ShowMessageBox(, TextMessage);
	
EndProcedure

#Region ItemsEventHandlers

&AtClient
Procedure PathFprwinStartChoice(Item, ChoiceData, StandardProcessing)
	
	PathFprwin = OpenFileDialog(PathFprwin, "fprwin_en.bat");
	
EndProcedure

&AtClient
Procedure PathXReportStartChoice(Item, ChoiceData, StandardProcessing)
	
	PathXReport = OpenFileDialog(PathXReport, "X.bat");
	
EndProcedure

&AtClient
Procedure PathZReportStartChoice(Item, ChoiceData, StandardProcessing)
	
	PathZReport = OpenFileDialog(PathZReport, "Z.bat");
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtClient
Function OpenFileDialog(Path, FileName)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	FileDialog.Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Path to file ""%1""'"),
		FileName);
	FileDialog.Filter = StringFunctionsClientServer.SubstituteParametersInString("%1|%1|All files|*.*", FileName);
	FileDialog.Multiselect = False;
	FileDialog.FullFileName = Path;
	If FileDialog.Choose() Then
		Return FileDialog.SelectedFiles[0];
	Else
		Return Path;
	EndIf;
	
EndFunction

#EndRegion

#EndRegion

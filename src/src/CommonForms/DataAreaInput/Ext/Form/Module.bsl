#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventsHandlers

&AtClient
Procedure OnOpen(Cancel)
	RefreshInterface = False;
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure LogOnDataArea(Command)
	
	If LoggedInDataArea() Then
		
		LogOffDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
		
		AttachIdleHandler("EnterInDataAreaAfterExit", 0.1, True);
	Else
		EnterInDataAreaAfterExit();
	EndIf;
	
EndProcedure

&AtClient
Procedure LogOffDataArea(Command)
	
	If LoggedInDataArea() Then	
		RefreshInterface();
		AttachIdleHandler("ExitContinuationFromDataAreaAfterActionsBeforeSystemWorkEnd", 0.1, True);		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure RefreshInterfaceIfNecessary()
	
	If RefreshInterface Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure EnterInDataAreaAfterExit()
	
	If Not IsFilledDataArea(DataArea) Then
		NotifyDescription = New NotifyDescription("EnterInDataAreaAfterExit2", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'The selected data area is not used, continue logon?'"),
			QuestionDialogMode.YesNo, , DialogReturnCode.No);
		Return;
	EndIf;
	
	EnterInDataAreaAfterExit2();
	
EndProcedure

&AtClient
Procedure EnterInDataAreaAfterExit2(Response = Undefined, AdditionalParameters = Undefined) Export
	
	If Response = DialogReturnCode.No Then
		RefreshInterfaceIfNecessary();
		Return;
	EndIf;
	
	LogOnDataAreaAtServer(DataArea);
	
	RefreshInterface = True;
	
	CompletionProcessing = New NotifyDescription(
		"EnterContinuationInDataAreaAfterActionsBeforeSystemWorkStart", ThisObject);
	
	StandardSubsystemsClient.BeforeStart(CompletionProcessing);
	
EndProcedure

&AtClient
Procedure EnterContinuationInDataAreaAfterActionsBeforeSystemWorkStart(Result, NotSpecified) Export
	
	If Result.Cancel Then
		LogOffDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
		RefreshInterfaceIfNecessary();
		Activate();
	Else
		CompletionProcessing = New NotifyDescription(
			"EnterContinuationInDataAreaAfterActionsAtSystemWorkStart", ThisObject);
		
		StandardSubsystemsClient.OnStart(CompletionProcessing);
	EndIf;
	
EndProcedure

&AtClient
Procedure EnterContinuationInDataAreaAfterActionsAtSystemWorkStart(Result, NotSpecified) Export
	
	If Result.Cancel Then
		LogOffDataAreaAtServer();
		RefreshInterface = True;
		StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	EndIf;
	
	RefreshInterfaceIfNecessary();
	Activate();
	
EndProcedure

&AtClient
Procedure ExitContinuationFromDataAreaAfterActionsBeforeSystemWorkEnd() Export
	
	LogOffDataAreaAtServer();
	RefreshInterface();
	StandardSubsystemsClient.SetAdvancedApplicationCaption(True);
	
	Activate();
	
EndProcedure

&AtServerNoContext
Function IsFilledDataArea(Val DataArea)
	
	SetPrivilegedMode(True);
	
	Block = New DataLock;
	LockItem = Block.Add("InformationRegister.DataAreas");
	LockItem.SetValue("DataAreaAuxiliaryData", DataArea);
	LockItem.Mode = DataLockMode.Shared;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DataAreas.Status AS Status
	|FROM
	|	InformationRegister.DataAreas AS DataAreas
	|WHERE
	|	DataAreas.DataAreaAuxiliaryData = &DataArea";
	Query.SetParameter("DataArea", DataArea);
	
	BeginTransaction();
	Try
		Block.Lock();
		Result = Query.Execute();
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
	If Result.IsEmpty() Then
		Return False;
	Else
		Selection = Result.Select();
		Selection.Next();
		Return Selection.Status = Enums.DataAreaStatuses.Used
	EndIf;
	
EndFunction

&AtServerNoContext
Procedure LogOnDataAreaAtServer(Val DataArea)
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(True, DataArea);
	
	BeginTransaction();
	
	Try
		
		AreaKey = SaaSOperations.CreateAuxiliaryDataRecordKeyOfInformationRegister(
			InformationRegisters.DataAreas,
			New Structure(SaaSOperations.SupportDataSplitter(), DataArea));
		LockDataForEdit(AreaKey);
		
		Block = New DataLock;
		Item = Block.Add("InformationRegister.DataAreas");
		Item.SetValue("DataAreaAuxiliaryData", DataArea);
		Item.Mode = DataLockMode.Shared;
		Block.Lock();
		
		RecordManager = InformationRegisters.DataAreas.CreateRecordManager();
		RecordManager.DataAreaAuxiliaryData = DataArea;
		RecordManager.Read();
		If Not RecordManager.Selected() Then
			RecordManager.DataAreaAuxiliaryData = DataArea;
			RecordManager.Status = Enums.DataAreaStatuses.Used;
			RecordManager.Write();
		EndIf;
		UnlockDataForEdit(AreaKey);
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Raise;
	EndTry;
	
EndProcedure

&AtServer
Procedure LogOffDataAreaAtServer()
	
	SetPrivilegedMode(True);
	
	CommonUse.SetSessionSeparation(False);
	
EndProcedure

&AtServerNoContext
Function LoggedInDataArea()
	
	SetPrivilegedMode(True);
	Return CommonUse.UseSessionSeparator();
	
EndFunction

#EndRegion

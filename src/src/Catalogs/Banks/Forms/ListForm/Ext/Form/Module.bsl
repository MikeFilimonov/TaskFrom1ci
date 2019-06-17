#Region Variables

&AtClient
Var IdleHandlerParameters;
&AtClient
Var LongOperationForm;

#EndRegion

&AtServerNoContext
Function JobCompleted(JobID)
	
	Return LongActions.JobCompleted(JobID);
	
EndFunction

&AtClient
Procedure Attachable_CheckJobExecution()
	
	Try
		If JobCompleted(JobID) Then
			LongActionsClient.CloseLongOperationForm(LongOperationForm);
			StructureDataAtClient = ImportPreparedData();
			ImportPreparedDataAtClient(StructureDataAtClient);
		Else
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckJobExecution", 
				IdleHandlerParameters.CurrentInterval, 
				True);
		EndIf;
	Except
		LongActionsClient.CloseLongOperationForm(LongOperationForm);
		Raise DetailErrorDescription(ErrorInfo());
	EndTry;
	
EndProcedure

&AtServerNoContext
Function BankClassifierHasItems()
	
	Query = New Query;
	Query.Text = 
		"SELECT TOP 1
		|	BankClassifier.Ref AS Ref
		|FROM
		|	Catalog.BankClassifier AS BankClassifier
		|WHERE
		|	NOT BankClassifier.DeletionMark";
	
	Return Not Query.Execute().IsEmpty(); 
	
EndFunction

&AtClient
Procedure ImportPreparedDataAtClient(DataStructure)
	
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return;
	EndIf;
	
	If DataStructure.Property("SuccessfullyUpdated") Then
		
		NotificationText = NStr("en = 'Banks are updated from classifier'");
		ShowUserNotification("Update",, NotificationText);
		
	EndIf;
	
	Notify("RefreshAfterAdd");
	
EndProcedure

&AtServer
Function ImportPreparedData()
	
	StructureDataAtClient = New Structure();
	
	DataStructure = GetFromTempStorage(StorageAddress);
	If TypeOf(DataStructure) <> Type("Structure") Then
		Return Undefined;
	EndIf;
	
	If DataStructure.Property("SuccessfullyUpdated") Then
		StructureDataAtClient.Insert("SuccessfullyUpdated", DataStructure.SuccessfullyUpdated);
	EndIf;
	
	Return StructureDataAtClient;
	
EndFunction

&AtServer
Function RunOnServer(FileInfobase)
	
	ParametersStructure = New Structure();
	
	If FileInfobase Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		Catalogs.Banks.RefreshBanksFromClassifier(ParametersStructure, StorageAddress);
		Result = New Structure("JobCompleted", True);
	Else
		BackgroundJobDescription = NStr("en = 'Update of the banks from classifier'");
		Result = LongActions.ExecuteInBackground(
			UUID, 
			"Catalogs.Banks.RefreshBanksFromClassifier", 
			ParametersStructure, 
			BackgroundJobDescription);
			
		StorageAddress       = Result.StorageAddress;
		JobID = Result.JobID;
	EndIf;
	
	If Result.JobCompleted Then
		Result.Insert("StructureDataClient", ImportPreparedData());
	EndIf;
	
	Return Result;
	
EndFunction

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "RefreshAfterAdd" Then
		Items.List.Refresh();
	EndIf;
	
EndProcedure

&AtClient
Procedure PickFromClassifier(Command)
	
	FormParameters = New Structure("CloseOnChoice, Multiselect", False, True);
	OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);

EndProcedure

&AtClient
Procedure UpdateFromClassifier(Command)
	
	If Not BanksHaveBeenUpdatedFromClassifier Then
		
		QuestionText = NStr("en = 'All records except manually created will be updated from the bank classfifier. 
		                    |In order to disable automatic updates for a given record, click ""Enable editing"" on the bank item form.
		                    |Do you want to continue?'");
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("UpdateFromClassifierEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0 , DialogReturnCode.No);
        Return;
		
	EndIf;
	
	UpdateFromClassifierFragment();
EndProcedure

&AtClient
Procedure UpdateFromClassifierEnd(Result1, AdditionalParameters) Export
    
    Response = Result1;
    If Response = DialogReturnCode.No Then
        
        Return;
        
    EndIf;
    
    
    UpdateFromClassifierFragment();

EndProcedure

&AtClient
Procedure UpdateFromClassifierFragment()
    
    Var FileInfobase, ConnectTimeoutHandler, Result;
    
    FileInfobase = StandardSubsystemsClientReUse.ClientWorkParameters().FileInfobase;
    Result  = RunOnServer(FileInfobase);
    
    If Not Result.JobCompleted Then
        
        // Handler will be connected until the background job is completed
        ConnectTimeoutHandler = Not FileInfobase AND ValueIsFilled(JobID);
        If ConnectTimeoutHandler Then
            LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
            AttachIdleHandler("Attachable_CheckJobExecution", 1, True);
            LongOperationForm = LongActionsClient.OpenLongOperationForm(ThisForm, JobID);
        EndIf;
        
    Else
        ImportPreparedDataAtClient(Result.StructureDataClient);
    EndIf;

EndProcedure

&AtClient
Procedure ChangeSelected(Command)
	
	GroupObjectsChangeClient.ChangeSelected(Items.List);

EndProcedure

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Query = New Query("SELECT TOP 1 * FROM Catalog.Banks AS Banks WHERE Banks.ManualChanging <> 2");
	QueryExecutionResult = Query.Execute();
	
	BanksHaveBeenUpdatedFromClassifier = Not QueryExecutionResult.IsEmpty();
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the prompt result about selecting the bank from classifier
//
//
Procedure DetermineBankPickNeedFromClassifier(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		FormParameters = New Structure("ChoiceMode, CloseOnChoice, Multiselect", True, True, True);
		OpenForm("Catalog.BankClassifier.ChoiceForm", FormParameters, ThisForm);
		
	ElsIf ClosingResult = DialogReturnCode.No Then
		
		If AdditionalParameters.IsFolder Then
			OpenForm("Catalog.Banks.FolderForm", New Structure("IsFolder",True), ThisObject);
		Else
			OpenForm("Catalog.Banks.ObjectForm");
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If BankClassifierHasItems() Then
	
		Cancel = True;
		
		QuestionText = NStr("en = 'Select the creation option'");
		
		AdditionalParameters = New Structure;
		AdditionalParameters.Insert("IsFolder", Group);
		NotifyDescription = New NotifyDescription("DetermineBankPickNeedFromClassifier", ThisObject, AdditionalParameters);
		
		Buttons = New ValueList;
		Buttons.Add(DialogReturnCode.No, NStr("en = 'Create from scratch'"));
		Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Select from classifier'"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		ShowQueryBox(NotifyDescription, QuestionText, Buttons, , DialogReturnCode.No, Nstr("en = 'Creation option'"));
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

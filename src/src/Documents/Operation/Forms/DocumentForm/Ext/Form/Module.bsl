#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the ContractOnChange procedure.
//
Function GetCompanyDataOnChange(Company)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"Counterparty",
		DriveServer.GetCompany(Company)
	);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// Receives data set from server for the AccountOnChange procedure.
//
// Parameters:
//  Account         - AccountsChart, account according to which you should receive structure.
//
// Returns:
//  Account structure.
// 
Function GetDataAccountOnChange(Account) Export
	
	StructureData = New Structure();
	
	StructureData.Insert("Currency", Account.Currency);
	
	Return StructureData;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
	,
	Parameters.CopyingValue,
	Parameters.Basis,
	PostingIsAllowed,
	Parameters.FillingValues);
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

#Region EventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
Procedure CompanyOnChange(Item)
	
	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

#Region TabularSectionAttributeEventHandlers

&AtClient
// Procedure - event handler OnChange of the input field AccountDr.
// Transactions tabular section.
//
Procedure AccountingRecordsAccountDrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyDr = Undefined;
		CurrentRow.AmountCurDr = 0;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field CurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field CurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyDrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyDr = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field AmountCurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurDrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field AmountCurrencyDr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurDrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountDr);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCurDr = 0;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountDr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field AccountCr.
// Transactions tabular section.
//
Procedure AccountingRecordsAccountCrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyCr = Undefined;
		CurrentRow.AmountCurCr = 0;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field CurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field CurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsCurrencyCrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		CurrentRow.CurrencyCr = Undefined;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler SelectionStart of the input field AmountCurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurCrStartChoice(Item, ChoiceData, StandardProcessing)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the input field AmountCurrencyCr.
// Transactions tabular section.
//
Procedure AccountingRecordsAmountCurCrOnChange(Item)
	
	CurrentRow = Items.AccountingRecords.CurrentData;
	StructureData = GetDataAccountOnChange(CurrentRow.AccountCr);
	
	If Not StructureData.Currency Then
		CurrentRow.AmountCurCr = 0;
		StandardProcessing = False;
		If ValueIsFilled(CurrentRow.AccountCr) Then
			ShowMessageBox(Undefined,NStr("en = 'Current GL account does not support multi-currency records.'"));
		Else
			ShowMessageBox(Undefined,NStr("en = 'Specify the GL account first.'"));
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion

#EndRegion

#EndRegion

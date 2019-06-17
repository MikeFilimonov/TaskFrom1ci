#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DocumentAmount = Expenses.Total("Amount");
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowsExpenses In Expenses Do
			
			If RowsExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData); 
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.OtherExpenses.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OtherSettlementsAccounting Then
		If Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.AccountsReceivable
			AND Correspondence.TypeOfAccount <> Enums.GLAccountsTypes.AccountsPayable Then
			
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
			DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
			
		EndIf;
		
		For Each CurrentRowExpenses In Expenses Do
			If CurrentRowExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.AccountsReceivable 
				Or CurrentRowExpenses.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.AccountsPayable Then
				
				If CurrentRowExpenses.Counterparty.IsEmpty() Then
					MessageText = NStr("en = 'Specify the counterparty in the line %LineNumber% of the list ""Expenses""'");
					MessageText = StrReplace(MessageText, "%LineNumber%", CurrentRowExpenses.LineNumber);
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Expenses",
						CurrentRowExpenses.LineNumber,
						"Counterparty",
						Cancel
					);
				ElsIf CurrentRowExpenses.Counterparty.DoOperationsByContracts AND CurrentRowExpenses.Contract.IsEmpty() Then
					MessageText = NStr("en = 'Specify the contract in the line %LineNumber% of the list ""Expenses""'");
					MessageText = StrReplace(MessageText, "%LineNumber%", CurrentRowExpenses.LineNumber);
					DriveServer.ShowMessageAboutError(
						ThisObject,
						MessageText,
						"Expenses",
						CurrentRowExpenses.LineNumber,
						"Contract",
						Cancel
					);
					
				EndIf;
			EndIf;
		EndDo;
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Counterparty");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
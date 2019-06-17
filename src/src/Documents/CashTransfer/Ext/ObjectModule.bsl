#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of filling the document on the basis.
//
// Parameters:
//  FillingData - Structure - Data on filling the document.
//	
Procedure FillByCashTransferPlan(BasisDocument)
	
	If BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.NotApproved Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'");
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Ref", BasisDocument);

	// Fill document header data.
	Query.Text =
	"SELECT
	|	&Ref AS BasisDocument,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.CashFlowItem AS Item,
	|	DocumentTable.DocumentCurrency AS CashCurrency,
	|	DocumentTable.PettyCash AS PettyCash,
	|	DocumentTable.DocumentAmount AS DocumentAmount,
	|	DocumentTable.BankAccount AS BankAccount,
	|	DocumentTable.CashAssetsType AS CashAssetsType,
	|	DocumentTable.CashAssetsTypePayee AS CashAssetsTypePayee,
	|	DocumentTable.BankAccountPayee AS BankAccountPayee,
	|	DocumentTable.PettyCashPayee AS PettyCashPayee
	|FROM
	|	Document.CashTransferPlan AS DocumentTable
	|WHERE
	|	DocumentTable.Ref = &Ref";
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		
		Selection = QueryResult.Select();
		Selection.Next();
		FillPropertyValues(ThisObject, Selection);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	// Deletion checked attributes from structure depending
	// on money type.
	If CashAssetsType = Enums.CashAssetTypes.Cash Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
	EndIf;
	
	If CashAssetsTypePayee = Enums.CashAssetTypes.Cash Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccountPayee");
	Else
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCashPayee");
	EndIf;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.CashTransferPlan") Then
		FillByCashTransferPlan(FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.CashTransfer.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CashTransfer.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo the posting of a document.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.CashTransfer.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#EndIf
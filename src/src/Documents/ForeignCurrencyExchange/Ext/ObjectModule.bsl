#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	DoNotCheckER = NOT BankCharge.ChargeType = Enums.ChargeMethod.SpecialExchangeRate;
	
	If DoNotCheckER OR FromAccountCurrency = PresentationCurrency Then 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "FromAccountExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "FromAccountMultiplicity");
	EndIf;
	
	If DoNotCheckER OR ToAccountCurrency = PresentationCurrency Then 
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ToAccountExchangeRate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "ToAccountMultiplicity");
	EndIf;
	
	If FromAccountCurrency = ToAccountCurrency Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Please, select accounts of different currencies'"),
			Ref,
			"ToAccount",
			"Object",
			Cancel);
	EndIf;
	
	If Not GetFunctionalOption("UseBankCharges") Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankCharge");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankChargeItem");
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	AdditionalProperties.Insert("CalculatedData", Documents.ForeignCurrencyExchange.GetCalculatedData(ThisObject));
	If GetFunctionalOption("UseSeveralDepartments") Then 
		AdditionalProperties.ForPosting.Insert("StructuralUnit", StructuralUnit);
	Else 
		AdditionalProperties.ForPosting.Insert("StructuralUnit", Catalogs.BusinessUnits.MainDepartment);
	EndIf;
	
	// Initialization of document data
	Documents.ForeignCurrencyExchange.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.ForeignCurrencyExchange.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.ForeignCurrencyExchange.RunControl(Ref, AdditionalProperties, Cancel);
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If IsNew() Then
		
		If Not ValueIsFilled(FromAccount) Then
			FromAccount = Company.BankAccountByDefault;
		EndIf;
		
		If Not ValueIsFilled(ToAccount) Then
			ToAccount = Company.BankAccountByDefault;
		EndIf;
		
		Item = Catalogs.CashFlowItems.Other;
		
	EndIf;
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	
EndProcedure

#EndRegion

#EndIf

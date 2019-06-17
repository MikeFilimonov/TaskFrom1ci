#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	If Not Constants.ForeignExchangeAccounting.Get() Then
		For Each TabularSectionRow In AccountingRecords Do
			If TabularSectionRow.AccountDr.Currency Then
				TabularSectionRow.CurrencyDr = Constants.FunctionalCurrency.Get();
				TabularSectionRow.AmountCurDr = TabularSectionRow.Amount;
			EndIf;
			If TabularSectionRow.AccountCr.Currency Then
				TabularSectionRow.CurrencyCr = Constants.FunctionalCurrency.Get();
				TabularSectionRow.AmountCurCr = TabularSectionRow.Amount;
			EndIf;
		EndDo;
	EndIf;
	
	DocumentAmount = AccountingRecords.Total("Amount");
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	For Each TSRow In AccountingRecords Do
		If TSRow.AccountDr.Currency
		AND Not ValueIsFilled(TSRow.CurrencyDr) Then
			MessageText = StrTemplate(NStr("en = 'The ""Currency Dr"" column is not populated for the currency account in the %1 line of the ""Postings"" list.'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"CurrencyDr",
				Cancel
			);
		EndIf;
		If TSRow.AccountDr.Currency
		AND Not ValueIsFilled(TSRow.AmountCurDr) Then
			MessageText = StrTemplate(NStr("en = 'The ""Amount (cur.) Dr"" column is not populated for currency account in the %1 line of the ""Postings"" list.'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"AmountCurDr",
				Cancel
			);
		EndIf;
		If TSRow.AccountCr.Currency
		AND Not ValueIsFilled(TSRow.CurrencyCr) Then
			MessageText = StrTemplate(NStr("en = 'Column ""Currency Kt"" is not filled for currency account in string %1 of list ""Posting"".'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"CurrencyCr",
				Cancel
			);
		EndIf;
		If TSRow.AccountCr.Currency
		AND Not ValueIsFilled(TSRow.AmountCurCr) Then
			MessageText = StrTemplate(NStr("en = 'Column ""Currency Kt"" is not filled for currency account in string %1 of list ""Posting"".'"), String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"AccountingRecords",
				TSRow.LineNumber,
				"AmountCurCr",
				Cancel
			);
		EndIf;
	EndDo;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.Operation.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
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

#EndRegion

#EndIf
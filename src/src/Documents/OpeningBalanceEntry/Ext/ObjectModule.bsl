#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions
// Procedure of the document filling based on the sales invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SalesInvoice - sales invoice 
// FillingData - Structure - Document filling data
//	
Procedure FillByStocktaking(FillingData)
	
	// Filling out a document header.
	BasisDocument = FillingData.Ref;
	Company = FillingData.Company;
	AccountingSection = "Inventory";
	
	// Filling document tabular section.
	For Each TabularSectionRow In FillingData.Inventory Do
		
		If TabularSectionRow.Quantity > 0 Then
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, TabularSectionRow);
			NewRow.StructuralUnit = FillingData.StructuralUnit;
			NewRow.Cell = FillingData.Cell;
		EndIf;	
		
	EndDo;
		
EndProcedure

// Procedure gets the default VAT rate.
//
Function GetVATRateDefault(VATTaxation)
	
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	ElsIf VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
		DefaultVATRate = Catalogs.VATRates.Exempt;
	Else
		DefaultVATRate = Catalogs.VATRates.ZeroRate;
	EndIf;
	
	Return DefaultVATRate;
	
EndFunction

#EndRegion

#Region EventHandlers

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowFixedAssets In FixedAssets Do
			
			If RowFixedAssets.GLExpenseAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowFixedAssets.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each TSRow In AccountsReceivable Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	For Each TSRow In AccountsPayable Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler OnWrite.
// Documents are generated during autofilling.
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load
  OR Not Autogeneration Then
		Return;
	EndIf;
	
	WereMadeChanges = False;
	
	// Generating the documents for the AccountsReceivable tabular section.
	For Each String In AccountsReceivable Do
		If Not ValueIsFilled(String.Document)
			  AND String.Counterparty.DoOperationsByDocuments Then
			  
			If String.AdvanceFlag Then
				  
				NewDocument = Documents.CashReceipt.CreateDocument();
				NewDocument.OperationKind	= Enums.OperationTypesCashReceipt.FromCustomer;
				NewDocument.Item			= Catalogs.CashFlowItems.PaymentFromCustomers;
				NewDocument.PettyCash		= Company.PettyCashByDefault;
				NewDocument.CashCurrency	= String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount	= String.AmountCur;
				NewDocument.VATTaxation		= DriveServer.VATTaxation(NewDocument.Company, Date);
				
				NewRow = NewDocument.PaymentDetails.Add();
				NewRow.Contract = String.Contract;
				ContractCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(
					Date,
					New Structure("Currency", NewRow.Contract.SettlementsCurrency));
				DocumentCurrencyCourseRepetition = InformationRegisters.ExchangeRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.CashCurrency));
				NewRow.ExchangeRate = ?(
					ContractCurrencyRateRepetition.ExchangeRate = 0,
					1,
					ContractCurrencyRateRepetition.ExchangeRate);
				NewRow.Multiplicity = ?(
					ContractCurrencyRateRepetition.Multiplicity = 0,
					1,
					ContractCurrencyRateRepetition.Multiplicity);
				NewRow.AdvanceFlag = True;
				NewRow.PaymentAmount = NewDocument.DocumentAmount;
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					NewRow.PaymentAmount,
					DocumentCurrencyCourseRepetition.ExchangeRate,
					NewRow.ExchangeRate,
					DocumentCurrencyCourseRepetition.Multiplicity,
					NewRow.Multiplicity);
					
				NewRow.VATRate = GetVATRateDefault(NewDocument.VATTaxation);
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
				
			Else
				NewDocument = Documents.SalesInvoice.CreateDocument();
				NewDocument.VATTaxation = DriveServer.VATTaxation(NewDocument.Company, Date);
				
				If ValueIsFilled(String.Contract) Then
					NewDocument.Contract = String.Contract;
				Else
					NewDocument.Contract = String.Counterparty.ContractByDefault;
				EndIf;
				
				NewDocument.DocumentCurrency = NewDocument.Contract.SettlementsCurrency;
				DocumentCurrencyCourseRepetition = InformationRegisters.ExchangeRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.DocumentCurrency)
				);
				NewDocument.ExchangeRate = ?(
					DocumentCurrencyCourseRepetition.ExchangeRate = 0,
					1,
					DocumentCurrencyCourseRepetition.ExchangeRate
				);
				NewDocument.Multiplicity = ?(
					DocumentCurrencyCourseRepetition.Multiplicity = 0,
					1,
					DocumentCurrencyCourseRepetition.Multiplicity
				);
				NewDocument.StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
			EndIf;
			
			NewDocument.Date = Date;
			NewDocument.Company = Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en = 'It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
			WereMadeChanges = True;
		EndIf;
	EndDo;
	
	// Generating the documents for the AccountsPayable tabular section.
	For Each String In AccountsPayable Do
		If Not ValueIsFilled(String.Document)
			  AND String.Counterparty.DoOperationsByDocuments Then
			If String.AdvanceFlag Then
				NewDocument = Documents.CashVoucher.CreateDocument();
				NewDocument.OperationKind = Enums.OperationTypesCashVoucher.Vendor;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Company.PettyCashByDefault;
				NewDocument.CashCurrency = String.Contract.SettlementsCurrency;
				NewDocument.DocumentAmount = String.AmountCur;
				NewDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
				NewRow = NewDocument.PaymentDetails.Add();
				NewRow.Contract = String.Contract;
				ContractCurrencyRateRepetition = InformationRegisters.ExchangeRates.GetLast(
					Date,
					New Structure("Currency", NewRow.Contract.SettlementsCurrency)
				);
				DocumentCurrencyCourseRepetition = InformationRegisters.ExchangeRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.CashCurrency)
				);
				NewRow.ExchangeRate = ?(
					ContractCurrencyRateRepetition.ExchangeRate = 0,
					1,
					ContractCurrencyRateRepetition.ExchangeRate
				);
				NewRow.Multiplicity = ?(
					ContractCurrencyRateRepetition.Multiplicity = 0,
					1,
					ContractCurrencyRateRepetition.Multiplicity
				);
				NewRow.PaymentAmount = NewDocument.DocumentAmount;
				NewRow.AdvanceFlag = True;
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					NewRow.PaymentAmount,
					DocumentCurrencyCourseRepetition.ExchangeRate,
					NewRow.ExchangeRate,
					DocumentCurrencyCourseRepetition.Multiplicity,
					NewRow.Multiplicity
				);
				NewRow.VATRate = GetVATRateDefault(NewDocument.VATTaxation);
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((NewRow.VATRate.Rate + 100) / 100);
			Else
				NewDocument = Documents.SupplierInvoice.CreateDocument();
				NewDocument.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT;
				If ValueIsFilled(String.Contract) Then
					NewDocument.Contract = String.Contract;
				Else
					NewDocument.Contract = String.Counterparty.ContractByDefault;
				EndIf;
				NewDocument.DocumentCurrency = NewDocument.Contract.SettlementsCurrency;
				DocumentCurrencyCourseRepetition = InformationRegisters.ExchangeRates.GetLast(
					Date,
					New Structure("Currency", NewDocument.DocumentCurrency)
				);
				NewDocument.ExchangeRate = ?(
					DocumentCurrencyCourseRepetition.ExchangeRate = 0,
					1,
					DocumentCurrencyCourseRepetition.ExchangeRate
				);
				NewDocument.Multiplicity = ?(
					DocumentCurrencyCourseRepetition.Multiplicity = 0,
					1,
					DocumentCurrencyCourseRepetition.Multiplicity
				);
				NewDocument.StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
			EndIf;
			NewDocument.Date = Date;
			NewDocument.Company = Company;
			NewDocument.Counterparty = String.Counterparty;
			
			StringComment = NStr("en = 'It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
			WereMadeChanges = True;
		EndIf;
	EndDo;
	
	// Generating the documents for the AdvanceHolders tabular section.
	For Each String In AdvanceHolders Do
		If Not ValueIsFilled(String.Document) Then
			If String.Overrun Then
				NewDocument = Documents.ExpenseReport.CreateDocument();
				NewDocument.Employee = String.Employee;
				NewDocument.DocumentCurrency = String.Currency;
			Else
				NewDocument = Documents.CashVoucher.CreateDocument();
				NewDocument.OperationKind = Enums.OperationTypesCashVoucher.ToAdvanceHolder;
				NewDocument.Item = Catalogs.CashFlowItems.PaymentToVendor;
				NewDocument.PettyCash = Company.PettyCashByDefault;
				NewDocument.AdvanceHolder = String.Employee;
				NewDocument.CashCurrency = String.Currency;
				NewDocument.DocumentAmount = String.AmountCur;
			EndIf;
			NewDocument.Date = Date;
			NewDocument.Company = Company;
			
			StringComment = NStr("en = 'It is generated automatically by the ""Entering the opening balances"" document #%Number% dated %Date%'");
			StringComment = StrReplace(StringComment, "%Number%", String(Number));
			StringComment = StrReplace(StringComment, "%Date%", String(Date));
			NewDocument.Comment = StringComment;
			
			NewDocument.Write();
			
			String.Document = NewDocument.Ref;
			WereMadeChanges = True;
		EndIf;
	EndDo;
		
	If WereMadeChanges Then
		Write();
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If Autogeneration Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "AdvanceHolders.Document");
	EndIf;
	
	For Each TSRow In OtherSections Do
		If TSRow.Account.Currency
		AND Not ValueIsFilled(TSRow.Currency) Then
			MessageText = NStr("en = 'The ""Currency"" column is not filled in for the currency account in row No. %LineNumber% of the ""Other sections"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"OtherSections",
				TSRow.LineNumber,
				"Currency",
				Cancel
			);
		EndIf;
		If TSRow.Account.Currency
		AND Not ValueIsFilled(TSRow.AmountCur) Then
			MessageText = NStr("en = 'The ""Amount (cur.)"" column is not populated for the currency account in the %LineNumber% line of the ""Other sections"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"OtherSections",
				TSRow.LineNumber,
				"AmountCur",
				Cancel
			);
		EndIf;
	EndDo;
	
	For Each TSRow In AccountsReceivable Do
		If TSRow.Counterparty.DoOperationsByDocuments
		AND Not Autogeneration
		AND Not ValueIsFilled(TSRow.Document) Then
			MessageText = NStr("en = 'The ""Settlement document"" column is not populated in the %LineNumber% line of the ""Accounts receivable"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Payments",
				TSRow.LineNumber,
				"Document",
				Cancel
			);
		EndIf;
	EndDo;
	
	For Each TSRow In AccountsPayable Do
		If TSRow.Counterparty.DoOperationsByDocuments
		AND Not Autogeneration
		AND Not ValueIsFilled(TSRow.Document) Then
			MessageText = NStr("en = 'The ""Settlement document"" column is not populated in the %LineNumber% line of the ""Accounts receivable"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(TSRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Payments",
				TSRow.LineNumber,
				"Document",
				Cancel
			);
		EndIf;
	EndDo;
	
	
	// Serial numbers
	InventoryWarehouses = Inventory.Unload(,"StructuralUnit");
	InventoryWarehouses.GroupBy("StructuralUnit","");
	For Each InventoryWarehouse In InventoryWarehouses Do
		WarehouseFilter = New Structure("StructuralUnit", InventoryWarehouse.StructuralUnit);
		RowByWarehouse = Inventory.FindRows(WarehouseFilter);
		For Each InventoryRow In RowByWarehouse Do
			WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, RowByWarehouse, SerialNumbers, InventoryWarehouse.StructuralUnit, ThisObject);
		EndDo;
	EndDo;
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Stocktaking") Then
		FillByStocktaking(FillingData);	
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.OpeningBalanceEntry.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryInWarehouses") Then
		DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventory") Then
		DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
		
		// Serial numbers
		If AdditionalProperties.TableForRegisterRecords.Property("TableSerialNumbersBalance") Then
			DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		If AdditionalProperties.TableForRegisterRecords.Property("TableSerialNumbersInWarranty") Then
			DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
		EndIf;
		// Serial numbers
		
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableCashAssets") Then
		DriveServer.ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountsReceivable") Then
		DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountsPayable") Then
		DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
		DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableTaxAccounting") Then
		DriveServer.ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TablePayroll") Then
		DriveServer.ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableSettlementsWithAdvanceHolders") Then
		DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetsStates") Then
		DriveServer.ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetParameters") Then
		DriveServer.ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssets") Then
		DriveServer.ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableFixedAssetUsage") Then
		DriveServer.ReflectFixedAssetUsage(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableInvoicesAndOrdersPayment") Then
		DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	If AdditionalProperties.TableForRegisterRecords.Property("TableAccountingJournalEntries") Then
		DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Offline registers
	If AdditionalProperties.TableForRegisterRecords.Property("TableInventoryCostLayer") Then
		DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	EndIf;
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.OpeningBalanceEntry.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.OpeningBalanceEntry.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

#EndRegion

#EndIf

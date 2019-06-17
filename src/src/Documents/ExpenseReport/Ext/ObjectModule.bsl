#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure of document filling on the basis of the cash payment.
//
// Parameters:
//  BasisDocument - DocumentRef.CashInflowForecast - Planned payment
//  FillingData - Structure - Document filling data
//	
Procedure FillByCashVoucher(FillingData)
	
	If FillingData.OperationKind <> Enums.OperationTypesCashVoucher.ToAdvanceHolder Then
		Raise NStr("en = 'Please select a cash voucher with ""To advance holder"" operation.'");
	EndIf;
	
	Company = FillingData.Company;
	BasisDocument = FillingData.Ref;
	Employee = FillingData.AdvanceHolder;
	DocumentCurrency = FillingData.CashCurrency;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	AdvancesPaid.Clear();
	NewRow = AdvancesPaid.Add();
	NewRow.Document = FillingData.Ref;
	NewRow.Amount = FillingData.DocumentAmount;
	
EndProcedure

// Procedure of document filling based on the payment expense.
//
// Parameters:
//  BasisDocument - DocumentRef.CashInflowForecast - Planned payment 
//  FillingData - Structure - Document filling data
//	
Procedure FillByPaymentExpense(FillingData)
	
	If FillingData.OperationKind <> Enums.OperationTypesPaymentExpense.ToAdvanceHolder Then
		Raise NStr("en = 'Please select a payment expense with ""To advance holder"" operation.'");
	EndIf;
	
	Company = FillingData.Company;
	BasisDocument = FillingData.Ref;
	Employee = FillingData.AdvanceHolder;
	DocumentCurrency = FillingData.CashCurrency;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", DocumentCurrency));
	ExchangeRate = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.ExchangeRate
	);
	Multiplicity = ?(
		StructureByCurrency.ExchangeRate = 0,
		1,
		StructureByCurrency.Multiplicity
	);
	
	AdvancesPaid.Clear();
	NewRow = AdvancesPaid.Add();
	NewRow.Document = FillingData.Ref;
	NewRow.Amount = FillingData.DocumentAmount;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.CashVoucher") Then
		FillByCashVoucher(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.PaymentExpense") Then
		FillByPaymentExpense(FillingData);
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TotalExpences = AdvancesPaid.Total("Amount");
	InventoryTotal = Inventory.Total("Total");
	ExpencesTotal = Expenses.Total("Total");
	PaymentsTotals = Payments.Total("PaymentAmount");
	
	If TotalExpences > InventoryTotal + ExpencesTotal + PaymentsTotals Then
		MessageText = NStr("en = 'Spent advance amount exceeds the amount of the document.'");
		DriveServer.ShowMessageAboutError(
			ThisObject,
			MessageText,
			"AdvancesPaid",
			1,
			"Amount",
			Cancel
		);
	EndIf;
	
	For Each PaymentRow In Payments Do
		If PaymentRow.Counterparty.DoOperationsByDocuments
		   AND Not PaymentRow.AdvanceFlag
		   AND Not ValueIsFilled(PaymentRow.Document) Then
			MessageText = NStr("en = 'The ""Settlement document"" column is not populated in the %LineNumber% line of the ""Payments"" list.'");
			MessageText = StrReplace(MessageText, "%LineNumber%", String(PaymentRow.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Payments",
				PaymentRow.LineNumber,
				"Document",
				Cancel
			);
		EndIf;
	EndDo;
	
	For Each RowsExpenses In Expenses Do
		
		If GetFunctionalOption("UseSeveralDepartments")
		   AND (RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
		 OR RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
		 OR RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Revenue
		 OR RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses)
		 AND Not ValueIsFilled(RowsExpenses.StructuralUnit) Then
			MessageText = NStr("en = 'The ""Department"" attribute must be filled in for the %Products%"" products in the %LineNumber% line of the ""Expenses"" list.'");
			MessageText = StrReplace(MessageText, "%Products%", TrimAll(String(RowsExpenses.Products))); 
			MessageText = StrReplace(MessageText, "%LineNumber%",String(RowsExpenses.LineNumber));
			DriveServer.ShowMessageAboutError(
				ThisObject,
				MessageText,
				"Expenses",
				RowsExpenses.LineNumber,
				"StructuralUnit",
				Cancel
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total") + Expenses.Total("Total") + Payments.Total("PaymentAmount");
	
	If Not Constants.UseSeveralLinesOfBusiness.Get() Then
		
		For Each RowsExpenses In Expenses Do
			
			If RowsExpenses.Products.ExpensesGLAccount.TypeOfAccount = Enums.GLAccountsTypes.Expenses Then
				
				RowsExpenses.BusinessLine = Catalogs.LinesOfBusiness.MainLine;
				
			Else
				
				RowsExpenses.BusinessLine = Undefined;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	For Each TSRow In Payments Do
		If ValueIsFilled(TSRow.Counterparty)
		AND Not TSRow.Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(TSRow.Contract) Then
			TSRow.Contract = TSRow.Counterparty.ContractByDefault;
		EndIf;
	EndDo;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.ExpenseReport.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// Offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ExpenseReport.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.ExpenseReport.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

#EndRegion

#EndIf

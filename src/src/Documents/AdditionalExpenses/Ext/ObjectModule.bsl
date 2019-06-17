#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure distributes expenses by quantity.
//
Procedure DistributeTabSectExpensesByQuantity() Export  
	
	SrcAmount					= 0;
	DistributionBaseQuantity	= Inventory.Total("Quantity");
	TotalExpenses				= Expenses.Total("Total");
	
	GCD	= DriveServer.GetGCDForArray(Inventory.UnloadColumn("Quantity"), 1000);
	
	If GCD = 0 Then
		Return;
	EndIf;
	
	If Not IncludeVATInPrice Тогда
		VATAmountExpense	= Expenses.Total("VATAmount");
		TotalExpenses		= TotalExpenses - VATAmountExpense;
	EndIf;
	
	For Each StringInventory In Inventory Do
		
		StringInventory.Factor = StringInventory.Quantity / GCD * 1000;
		StringInventory.AmountExpense = ?(DistributionBaseQuantity <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Quantity / DistributionBaseQuantity, 2, 1),0);
		DistributionBaseQuantity = DistributionBaseQuantity - StringInventory.Quantity;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

// Procedure distributes expenses by amount.
// 
Procedure DistributeTabSectExpensesByAmount() Export 	

	SrcAmount = 0;
	ReserveAmount = Inventory.Total("Amount");
	TotalExpenses = Expenses.Total("Total");
	
	GCD = DriveServer.GetGCDForArray(Inventory.UnloadColumn("Amount"), 100);
	
	If GCD = 0 Then
		Return;
	EndIf;
	
	If Not IncludeVATInPrice Тогда
		VATAmountExpense	= Expenses.Total("VATAmount");
		TotalExpenses		= TotalExpenses - VATAmountExpense;
	EndIf;

	
	For Each StringInventory In Inventory Do
		
		StringInventory.Factor = StringInventory.Amount / GCD * 100;
		StringInventory.AmountExpense = ?(ReserveAmount <> 0, Round((TotalExpenses - SrcAmount) * StringInventory.Amount / ReserveAmount, 2, 1), 0);
		ReserveAmount = ReserveAmount - StringInventory.Amount;
		SrcAmount = SrcAmount + StringInventory.AmountExpense;
		
	EndDo;
	
EndProcedure

#Region FillingTheDocument

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsVendorSettlements.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecordsVendorSettlements
	|	WHERE
	|		DocumentRegisterRecordsVendorSettlements.Recorder = &Ref
	|		AND DocumentRegisterRecordsVendorSettlements.Period <= &Period
	|		AND DocumentRegisterRecordsVendorSettlements.Company = &Company
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order IN (&Order)
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsPayableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsPayableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsPayableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (AccountsPayableBalances.SettlementsCurrencyExchangeRatesRate / AccountsPayableBalances.SettlementsCurrencyExchangeRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesRate AS DocumentCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesMultiplicity AS DocumentCurrencyExchangeRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) * SettlementsCurrencyExchangeRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyExchangeRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyExchangeRates.ExchangeRate AS SettlementsCurrencyExchangeRatesRate,
	|		SettlementsCurrencyExchangeRates.Multiplicity AS SettlementsCurrencyExchangeRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyExchangeRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyExchangeRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &PresentationCurrency) AS SettlementsCurrencyExchangeRates
	|			ON (TRUE)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency,
	|	AccountsPayableBalances.SettlementsCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.SettlementsCurrencyExchangeRatesMultiplicity,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsPayableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", ?(Counterparty.DoOperationsByOrders, PurchaseOrder, Documents.PurchaseOrder.EmptyRef()));
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	If Contract.SettlementsCurrency = DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	AmountLeftToDistribute = Expenses.Total("Total");
	AmountLeftToDistribute = DriveServer.RecalculateFromCurrencyToCurrency(
		AmountLeftToDistribute,
		?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
		ExchangeRate,
		?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
		Multiplicity
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While AmountLeftToDistribute > 0 Do
		
		If SelectionOfQueryResult.Next() Then
			
			If SelectionOfQueryResult.SettlementsAmount <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.SettlementsAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				NewRow.SettlementsAmount = AmountLeftToDistribute;
				NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					NewRow.SettlementsAmount,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.DocumentCurrencyExchangeRatesRate,
					SelectionOfQueryResult.Multiplicity,
					SelectionOfQueryResult.DocumentCurrencyExchangeRatesMultiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of filling the document on the basis of supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData - Structure - Document filling data
//	
Procedure FillBySupplierInvoice(FillingData) Export
	
	Company = FillingData.Company;
	Counterparty = FillingData.Counterparty;
	Contract = FillingData.Contract;
	StructuralUnit = FillingData.StructuralUnit;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	VATTaxation = FillingData.VATTaxation; 
	If DocumentCurrency = Constants.FunctionalCurrency.Get() Then
		ExchangeRate = FillingData.ExchangeRate;
		Multiplicity = FillingData.Multiplicity;
	Else
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Filling document tabular section.
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		NewRow.ReceiptDocument = FillingData.Ref;
		
		If TypeOf(TabularSectionRow.Order) = Type("DocumentRef.PurchaseOrder")
			AND GetFunctionalOption("UseInventoryReservation") Then
			NewRow.SalesOrder = TabularSectionRow.Order.SalesOrder;
		EndIf;
		
	EndDo;
	
	// Payment calendar
	PaymentCalendar.Clear();
	
	Query = New Query;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("BasisDocument", FillingData);
	Query.Text = 
	"SELECT
	|	DATEADD(&Date, DAY, DATEDIFF(Calendar.Ref.Date, Calendar.PaymentDate, DAY)) AS PaymentDate,
	|	Calendar.PaymentPercentage AS PaymentPercentage,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|FROM
	|	Document.SupplierInvoice.PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref = &BasisDocument";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewLine = PaymentCalendar.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
EndProcedure

// Procedure of filling the document on the basis of the expense report.
//
// Parameters:
//  BasisDocument - DocumentRef.ExpenseReport - The expense report
//  FillingData - Structure - Document filling data
//	
Procedure FillByExpenseReport(FillingData) Export
		
	Company = FillingData.Company;
	DocumentCurrency = FillingData.DocumentCurrency;
	AmountIncludesVAT = FillingData.AmountIncludesVAT;
	IncludeVATInPrice = FillingData.IncludeVATInPrice;
	ExchangeRate = FillingData.ExchangeRate;
	Multiplicity = FillingData.Multiplicity;
	VATTaxation = FillingData.VATTaxation; 
	
	// Filling document tabular section.	
	Inventory.Clear();
	For Each TabularSectionRow In FillingData.Inventory Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		NewRow.ReceiptDocument	= FillingData.Ref;
		
	EndDo;
		
EndProcedure

// Procedure of payment calendar filling based on contract.
//
Procedure FillPaymentCalendarFromContract() Export
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	TotalAmount = Expenses.Total("Amount");
	TotalVAT = Expenses.Total("VATAmount");
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SupplierInvoice")] = "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.ExpenseReport")]   = "FillByExpenseReport";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	VATExpenses = 0;
	If NOT IncludeVATInPrice Тогда	
		VATExpenses = Expenses.Total("VATAmount");
	EndIf;	 
 	
	If Inventory.Total("AmountExpense") <> Expenses.Total("Total") - VATExpenses Then  
		
		DriveServer.ShowMessageAboutError(, 
			NStr("en = 'Amount of services is not equal to the amount allocated by inventory.'"),
			Undefined,
			Undefined,
			Undefined,
			Cancel);
		
	EndIf;
	
	If NOT Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	//Payment calendar
	Amount = Expenses.Total("Amount");
	VATAmount = Expenses.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Expenses.Total("Total");
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.AdditionalExpenses.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Offline registers
	DriveServer.ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control of occurrence of a negative balance.
	Documents.AdditionalExpenses.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	// Control of occurrence of a negative balance.
	Documents.AdditionalExpenses.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

#EndRegion

#EndIf

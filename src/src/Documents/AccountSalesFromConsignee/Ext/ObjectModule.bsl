#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Preparation of the order table.
	OrdersTable = Inventory.Unload(, "SalesOrder, Total");
	OrdersTable.Columns.Add("TotalCalc");
	For Each CurRow In OrdersTable Do
		If Not Counterparty.DoOperationsByOrders Then
			CurRow.SalesOrder = Documents.SalesOrder.EmptyRef();
		EndIf;
		CurRow.TotalCalc = DriveServer.RecalculateFromCurrencyToCurrency(
			CurRow.Total,
			?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
			ExchangeRate,
			?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
			Multiplicity
		);
	EndDo;
	OrdersTable.GroupBy("SalesOrder", "Total, TotalCalc");
	OrdersTable.Sort("SalesOrder Asc");
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order IN (&Order)
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsAccountsReceivable.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|	WHERE
	|		DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|		AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|		AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|		AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order IN (&Order)
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsReceivableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsReceivableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsReceivableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsReceivableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsReceivableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (SettlementsCurrencyExchangeRatesRate / SettlementsCurrencyExchangeRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesRate AS DocumentCurrencyExchangeRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesMultiplicity AS DocumentCurrencyExchangeRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) * SettlementsCurrencyExchangeRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyExchangeRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyExchangeRates.ExchangeRate AS SettlementsCurrencyExchangeRatesRate,
	|		SettlementsCurrencyExchangeRates.Multiplicity AS SettlementsCurrencyExchangeRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyExchangeRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyExchangeRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &PresentationCurrency) AS SettlementsCurrencyExchangeRates
	|			ON (TRUE)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency,
	|	SettlementsCurrencyExchangeRatesRate,
	|	SettlementsCurrencyExchangeRatesMultiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Order", OrdersTable.UnloadColumn("SalesOrder"));
	
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
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While SelectionOfQueryResult.Next() Do
		
		FoundString = OrdersTable.Find(SelectionOfQueryResult.Order, "SalesOrder");
		
		If FoundString.TotalCalc = 0 Then
			Continue;
		EndIf;
		
		If SelectionOfQueryResult.SettlementsAmount <= FoundString.TotalCalc Then // balance amount is less or equal than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			FoundString.TotalCalc = FoundString.TotalCalc - SelectionOfQueryResult.SettlementsAmount;
			
		Else // Balance amount is greater than it is necessary to distribute
			
			NewRow = Prepayment.Add();
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			NewRow.SettlementsAmount = FoundString.TotalCalc;
			NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				NewRow.SettlementsAmount,
				SelectionOfQueryResult.ExchangeRate,
				SelectionOfQueryResult.DocumentCurrencyExchangeRatesRate,
				SelectionOfQueryResult.Multiplicity,
				SelectionOfQueryResult.DocumentCurrencyExchangeRatesMultiplicity
			);
			FoundString.TotalCalc = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure of the document filling based on the sales invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData   - Structure - Document filling data
//	
Procedure FillByGoodsIssue(FillingData)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract
	|INTO Header
	|FROM
	|	Document.GoodsIssue AS Header
	|WHERE
	|	Header.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Company AS Company,
	|	Header.Counterparty AS Counterparty,
	|	Header.Contract AS Contract,
	|	Contracts.SettlementsCurrency AS SettlementsCurrency,
	|	GIProducts.Products AS Products,
	|	GIProducts.Characteristic AS Characteristic,
	|	GIProducts.Batch AS Batch,
	|	GIProducts.Quantity AS Quantity,
	|	GIProducts.MeasurementUnit AS MeasurementUnit,
	|	GIProducts.Order AS SalesOrder,
	|	ISNULL(SalesOrderRef.SalesRep, Counterparties.SalesRep) AS SalesRep,
	|	0 AS ConnectionKey,
	|	GIProducts.ConnectionKey AS ConnectionKeySerialNumbes,
	|	Contracts.PaymentMethod AS PaymentMethod,
	|	Companies.BankAccountByDefault AS BankAccountByDefault,
	|	Companies.PettyCashByDefault AS PettyCashByDefault,
	|	Contracts.PriceKind AS PriceKind,
	|	ProductsCat.VATRate AS VATRate,
	|	GIProducts.InventoryTransferredGLAccount AS InventoryTransferredGLAccount,
	|	GIProducts.RevenueGLAccount AS RevenueGLAccount,
	|	GIProducts.COGSGLAccount AS COGSGLAccount
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.GoodsIssue.Products AS GIProducts
	|		ON Header.Ref = GIProducts.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS Contracts
	|		ON (GIProducts.Ref.Contract = Contracts.Ref)
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON (GIProducts.Ref.Company = Companies.Ref)
	|		LEFT JOIN Catalog.Products AS ProductsCat
	|		ON (GIProducts.Products = ProductsCat.Ref)
	|		LEFT JOIN Document.SalesOrder AS SalesOrderRef
	|		ON (GIProducts.Order = SalesOrderRef.Ref)
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON Header.Counterparty = Counterparties.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calendar.Term AS Term,
	|	Calendar.DuePeriod AS DuePeriod,
	|	Calendar.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Calendar
	|		INNER JOIN Header AS Header
	|		ON (Header.Contract = Calendar.Ref)";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	QueryResultFull = Query.ExecuteBatch();
	QueryResult = QueryResultFull[1];
	
	QueryResultSelection = QueryResult.Select();
	
	QueryResultSelection.Next();
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	If DocumentCurrency <> Constants.FunctionalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", QueryResultSelection.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	NewRow = Customers.Add();
	NewRow.Customer = QueryResultSelection.Counterparty;
	NewRow.ConnectionKey = QueryResultSelection.ConnectionKey;
	
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("StructuralUnit", Catalogs.BusinessUnits.EmptyRef());
	
	StructureData = New Structure;
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	QueryResultSelection.Reset();
	While QueryResultSelection.Next() Do
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, QueryResultSelection);
	EndDo;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	
	If GetFunctionalOption("UseSerialNumbers") Then
		SerialNumbers.Load(FillingData.SerialNumbers.Unload());
		For Each Str In Inventory Do
			Str.SerialNumbers = WorkWithSerialNumbersClientServer.StringPresentationOfSerialNumbersOfLine(SerialNumbers, Str.ConnectionKeySerialNumbers);
		EndDo;
	EndIf;
	
	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	
	QueryResult = QueryResultFull[2];
	SessionDate = CurrentSessionDate();
	
	CalendarSelection = QueryResult.Select();
	While CalendarSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		NewLine.PaymentPercentage = CalendarSelection.PaymentPercentage;
		
		If CalendarSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = SessionDate - CalendarSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = SessionDate + CalendarSelection.DuePeriod * 86400;
		EndIf;
		
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
	If SetPaymentTerms Then
		If QueryResultSelection.PaymentMethod = Enums.CashAssetTypes.Noncash Then
			BankAccount = QueryResultSelection.BankAccountByDefault;
		ElsIf QueryResultSelection = Enums.CashAssetTypes.Cash Then
			PettyCash = QueryResultSelection.PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	TableInventory = Inventory.Unload(, "SalesOrder, Total");
	TableInventory.GroupBy("SalesOrder", "Total");
	
	TablePrepayment = Prepayment.Unload(, "Order, PaymentAmount");
	TablePrepayment.GroupBy("Order", "PaymentAmount");
	
	QuantityInventory = Inventory.Count();
	
	For Each String In TablePrepayment Do
		
		FoundStringWorksAndServices = Undefined;
		
		If Counterparty.DoOperationsByOrders
		   AND String.Order <> Undefined
		   AND String.Order <> Documents.SalesOrder.EmptyRef() Then
			FoundStringInventory = Inventory.Find(String.Order, "SalesOrder");
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		ElsIf Counterparty.DoOperationsByOrders Then
			FoundStringInventory = TableInventory.Find(Undefined, "SalesOrder");
			FoundStringInventory = ?(FoundStringInventory = Undefined, TableInventory.Find(Documents.SalesOrder.EmptyRef(), "SalesOrder"), FoundStringInventory);
			Total = ?(FoundStringInventory = Undefined, 0, FoundStringInventory.Total);
		Else
			Total = Inventory.Total("Total");
		EndIf;
		
		If FoundStringInventory = Undefined
		   AND QuantityInventory > 0
		   AND Counterparty.DoOperationsByOrders Then
			MessageText = NStr("en = 'Cannot register the advance payment because the order to be paid is not listed on the Goods tab.'");
			DriveServer.ShowMessageAboutError(
				,
				MessageText,
				Undefined,
				Undefined,
				"PrepaymentTotalSettlementsAmountCurrency",
				Cancel
			);
		EndIf;
	EndDo;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	//Payment calendar
	If KeepBackComissionFee Then
		InventoryTotal = Inventory.Total("Total");
		VATAmount = Inventory.Total("VATAmount") - Inventory.Total("BrokerageVATAmount");
		Amount = Round(InventoryTotal - (CommissionFeePercent * InventoryTotal / 100) - VATAmount, 2);
	Else
		VATAmount = Inventory.Total("VATAmount");
		Amount = Inventory.Total("Amount");
	EndIf;
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.GoodsIssue") Then
		If FillingData.OperationType = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
			FillByGoodsIssue(FillingData);
		Else
			Raise NStr("en = 'Please select a sales invoice with ""Transfer to a third party"" operation.'");
		EndIf;
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.AccountSalesFromConsignee.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesFromConsignee.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.AccountSalesFromConsignee.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

#EndRegion

#EndIf

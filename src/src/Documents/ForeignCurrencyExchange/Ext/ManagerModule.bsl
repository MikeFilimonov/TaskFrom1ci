#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure InitializeDocumentData(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	Query.SetParameter("Ref",			DocumentRefForeignCurrencyExchange);
	Query.SetParameter("PointInTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company",		StructureAdditionalProperties.ForPosting.Company);
	
	Query.SetParameter("PresentationCurrency",		PresentationCurrency);
	Query.SetParameter("FromAccountCashCurrency",	DocumentRefForeignCurrencyExchange.FromAccountCurrency);
	Query.SetParameter("ToAccountCashCurrency",		DocumentRefForeignCurrencyExchange.ToAccountCurrency);
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	MainOperationContent = NStr("en = 'Foreign currency exchange'", MainLanguageCode);
	
	If DocumentRefForeignCurrencyExchange.ToAccountCurrency <> PresentationCurrency
		AND DocumentRefForeignCurrencyExchange.FromAccountCurrency <> PresentationCurrency Then 
		MainOperationContent = NStr("en = 'Foreign currency exchange'", MainLanguageCode);
	ElsIf DocumentRefForeignCurrencyExchange.ToAccountCurrency <> PresentationCurrency Then 
		MainOperationContent = NStr("en = 'Foreign currency acquision'", MainLanguageCode);
	ElsIf DocumentRefForeignCurrencyExchange.FromAccountCurrency <> PresentationCurrency Then 
		MainOperationContent = NStr("en = 'Foreign currency sale'", MainLanguageCode);
	EndIf;
	
	Query.SetParameter("MainOperationContent", MainOperationContent);
	Query.SetParameter("ContentBankComission", NStr("en = 'Bank fee'", MainLanguageCode));
	
	Query.SetParameter("TotalSending",				StructureAdditionalProperties.CalculatedData.TotalSending);
	Query.SetParameter("TotalSendingCurrency",		StructureAdditionalProperties.CalculatedData.TotalSendingCurrency);
	Query.SetParameter("SendingBankFee",			StructureAdditionalProperties.CalculatedData.SendingBankFee);
	Query.SetParameter("SendingBankFeeCurrency",	StructureAdditionalProperties.CalculatedData.SendingBankFeeCurrency);
	Query.SetParameter("ReceivingAmountCurrency",	StructureAdditionalProperties.CalculatedData.ReceivingAmountCurrency);
	Query.SetParameter("ReceivingBankFee",			StructureAdditionalProperties.CalculatedData.ReceivingBankFee);
	Query.SetParameter("ReceivingBankFeeCurrency",	StructureAdditionalProperties.CalculatedData.ReceivingBankFeeCurrency);
	
	Query.Text =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &FromAccountCashCurrency, &ToAccountCashCurrency)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ForeignCurrencyExchange.Ref AS ForeignCurrencyExchangeRef,
	|	1 AS LineNumber,
	|	ForeignCurrencyExchange.Date AS Date,
	|	&Company AS Company,
	|	ForeignCurrencyExchange.Item AS Item,
	|	ForeignCurrencyExchange.DocumentAmount AS DocumentAmount,
	|	ForeignCurrencyExchange.FromAccount AS FromAccount,
	|	ForeignCurrencyExchange.ToAccount AS ToAccount,
	|	BankAccountsFrom.GLAccount AS FromAccountGLAccount,
	|	BankAccountsTo.GLAccount AS ToAccountGLAccount,
	|	BankAccountsFrom.CashCurrency AS FromAccountCashCurrency,
	|	BankAccountsTo.CashCurrency AS ToAccountCashCurrency,
	|	BankCharges.GLAccount AS BankChargeGLAccount,
	|	BankCharges.GLExpenseAccount AS BankChargeGLExpenseAccount,
	|	&TotalSending AS TotalSending,
	|	&TotalSendingCurrency AS TotalSendingCurrency,
	|	&SendingBankFee AS SendingBankFee,
	|	&SendingBankFeeCurrency AS SendingBankFeeCurrency,
	|	&ReceivingAmountCurrency AS ReceivingAmountCurrency,
	|	&ReceivingBankFee AS ReceivingBankFee,
	|	&ReceivingBankFeeCurrency AS ReceivingBankFeeCurrency,
	|	FromAccountCentralBankExchangeRatesSliceLast.ExchangeRate / FromAccountCentralBankExchangeRatesSliceLast.Multiplicity AS FromAccountExchangeRate,
	|	ToAccountCentralBankExchangeRatesSliceLast.ExchangeRate / ToAccountCentralBankExchangeRatesSliceLast.Multiplicity AS ToAccountExchangeRate,
	|	ForeignCurrencyExchange.BankCharge AS BankCharge,
	|	ForeignCurrencyExchange.BankChargeItem AS BankChargeItem,
	|	&MainOperationContent AS MainOperationContent,
	|	&ContentBankComission AS ContentBankComission
	|INTO TemporaryTableHeader
	|FROM
	|	Document.ForeignCurrencyExchange AS ForeignCurrencyExchange
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS AccountingExchangeRates
	|		ON (AccountingExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS FromAccountCentralBankExchangeRatesSliceLast
	|		ON (FromAccountCentralBankExchangeRatesSliceLast.Currency = &FromAccountCashCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ToAccountCentralBankExchangeRatesSliceLast
	|		ON (ToAccountCentralBankExchangeRatesSliceLast.Currency = &ToAccountCashCurrency)
	|		LEFT JOIN Catalog.BankAccounts AS BankAccountsFrom
	|		ON ForeignCurrencyExchange.FromAccount = BankAccountsFrom.Ref
	|		LEFT JOIN Catalog.BankAccounts AS BankAccountsTo
	|		ON ForeignCurrencyExchange.ToAccount = BankAccountsTo.Ref
	|		LEFT JOIN Catalog.BankCharges AS BankCharges
	|		ON ForeignCurrencyExchange.BankCharge = BankCharges.Ref
	|WHERE
	|	ForeignCurrencyExchange.Ref = &Ref";
	
	Query.Execute();
	
	GenerateTableBankCharges(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableCashAssets(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableIncomeAndExpenses(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableIncomeAndExpensesCashMethod(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	GenerateTableAccountingJournalEntries(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties);
	
EndProcedure

Function GetCalculatedData(DocumentObject) Export 
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	DocumentAmount = DocumentObject.DocumentAmount;
	BankCharge = DocumentObject.BankCharge;
	
	FromAccountCurrency = DocumentObject.FromAccountCurrency;
	FromAccountCurrencyExchangeRates = DriveServer.GetExchangeRates(PresentationCurrency, FromAccountCurrency, DocumentObject.Date);
	CentralBankERSending = FromAccountCurrencyExchangeRates.ExchangeRate;
	CentralBankMulSending = FromAccountCurrencyExchangeRates.Multiplicity;
	CentralBankCoefSending = FromAccountCurrencyExchangeRates.ExchangeRate / FromAccountCurrencyExchangeRates.Multiplicity;
	
	ToAccountCurrency = DocumentObject.ToAccountCurrency;
	ToAccountCurrencyExchangeRates = DriveServer.GetExchangeRates(PresentationCurrency, ToAccountCurrency, DocumentObject.Date);
	CentralBankERReceiving = ToAccountCurrencyExchangeRates.ExchangeRate;
	CentralBankMulreceiving = ToAccountCurrencyExchangeRates.Multiplicity;
	CentralBankCoefReceiving = ToAccountCurrencyExchangeRates.ExchangeRate / ToAccountCurrencyExchangeRates.Multiplicity;
	
	If DocumentObject.FromAccountMultiplicity <> 0 Then
		FromAccountExchangeRateIncludingMultiplicity = DocumentObject.FromAccountExchangeRate / DocumentObject.FromAccountMultiplicity;
	Else
		FromAccountExchangeRateIncludingMultiplicity = DocumentObject.FromAccountExchangeRate;
	EndIf;
	
	If DocumentObject.ToAccountMultiplicity <> 0 Then
		ToAccountExchangeRateIncludingMultiplicity = DocumentObject.ToAccountExchangeRate / DocumentObject.ToAccountMultiplicity;
	Else
		ToAccountExchangeRateIncludingMultiplicity = DocumentObject.ToAccountExchangeRate;
	EndIf;
	
	TotalSending = 0;
	TotalSendingCurrency = 0;
	
	SendingAmount = 0;
	SendingBankFee = 0;
	SendingBankFeeCurrency = 0;
	
	TotalReceiving = 0;
	TotalReceivingCurrency = 0;
	ReceivingBankFee = 0;
	ReceivingBankFeeCurrency = 0;
	
	DoSendingOperations		= DocumentObject.ToAccountCurrency <> PresentationCurrency;
	DoReceivingOperations	= DocumentObject.FromAccountCurrency <> PresentationCurrency;
	DoBothOperations		= DoSendingOperations AND DoReceivingOperations;
	
	If BankCharge.ChargeType = Enums.ChargeMethod.SpecialExchangeRate Then 
		
		If DoBothOperations Then 
			
			SendingBankFee = DocumentAmount * (CentralBankCoefSending - FromAccountExchangeRateIncludingMultiplicity);
			SendingBankFeeCurrency = SendingBankFee / CentralBankCoefSending;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			TotalReceivingCurrency = Round(DocumentAmount * FromAccountExchangeRateIncludingMultiplicity / ToAccountExchangeRateIncludingMultiplicity, 2);

			TotalSending = TotalSendingCurrency * CentralBankCoefSending;
			TotalReceiving = TotalReceivingCurrency * CentralBankCoefReceiving;
		
			ReceivingBankFee = TotalSending - TotalReceiving;
			ReceivingBankFeeCurrency = ReceivingBankFee / CentralBankCoefReceiving;
			
		ElsIf DoSendingOperations Then 
			
			TotalSending = DocumentAmount / ToAccountExchangeRateIncludingMultiplicity * CentralBankCoefReceiving;
			SendingBankFee = DocumentAmount - TotalSending;
			SendingBankFeeCurrency = SendingBankFee;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			TotalReceivingCurrency = DocumentAmount / ToAccountExchangeRateIncludingMultiplicity;
			
		ElsIf DoReceivingOperations Then 
			
			TotalSending = DocumentAmount * FromAccountExchangeRateIncludingMultiplicity;
			TotalSendingCurrency = TotalSending / CentralBankCoefSending;
			
			SendingAmount = DocumentAmount * CentralBankCoefSending;
			
			SendingBankFee = SendingAmount - TotalSending;
			SendingBankFeeCurrency = DocumentAmount - TotalSendingCurrency;
			
			TotalReceivingCurrency = TotalSending;
			
		EndIf;
		
	ElsIf BankCharge.ChargeType = Enums.ChargeMethod.Percent Then 
		
		If DoBothOperations Then
			
			SendingBankFeeCurrency = DocumentAmount * DocumentObject.BankFeeValue / 100;
			SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			TotalSending = TotalSendingCurrency * CentralBankCoefSending;
			TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
			
		ElsIf DoSendingOperations Then
			
			SendingBankFee = DocumentAmount * DocumentObject.BankFeeValue / 100;
			SendingBankFeeCurrency = SendingBankFee;
			
			TotalSending = DocumentAmount - SendingBankFee;
			
			TotalSendingCurrency = TotalSending;
			TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
			
		ElsIf DoReceivingOperations Then
			
			SendingBankFeeCurrency = DocumentAmount * DocumentObject.BankFeeValue / 100;
			SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			TotalSending = TotalSendingCurrency * CentralBankCoefSending;
			TotalReceivingCurrency = TotalSending;
			
		EndIf;
		
	ElsIf BankCharge.ChargeType = Enums.ChargeMethod.Amount Then 
		
		If DoBothOperations Then 
			
			SendingBankFeeCurrency = DocumentObject.BankFeeValue;
			SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			TotalSending = TotalSendingCurrency * CentralBankCoefSending;
			TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
			
		ElsIf DoSendingOperations Then
			
			SendingBankFee = DocumentObject.BankFeeValue;
			SendingBankFeeCurrency = SendingBankFee;
			
			TotalSending = DocumentAmount - SendingBankFee;
			
			TotalSendingCurrency = TotalSending;
			TotalReceivingCurrency = TotalSending / CentralBankCoefReceiving;
			
		ElsIf DoReceivingOperations Then 
			
			SendingBankFeeCurrency = DocumentObject.BankFeeValue;
			SendingBankFee = SendingBankFeeCurrency * CentralBankCoefSending;
			
			TotalSendingCurrency = DocumentAmount - SendingBankFeeCurrency;
			TotalSending = TotalSendingCurrency * CentralBankCoefSending;
			TotalReceivingCurrency = TotalSending;
		
		EndIf;
		
	EndIf;
	
	SendingAmount = TotalSending + SendingBankFee;
	TotalReceiving = TotalSending - ReceivingBankFee;
	ReceivingAmountCurrency = TotalReceivingCurrency + ReceivingBankFeeCurrency;
	
	AmountFee = SendingBankFee + ReceivingBankFee;
	
	CalculatedData = New Structure();
	CalculatedData.Insert("TotalSending",				TotalSending);
	CalculatedData.Insert("SendingAmount",				SendingAmount);
	CalculatedData.Insert("TotalReceiving",				TotalReceiving);
	CalculatedData.Insert("ReceivingAmount",			TotalSending);
	CalculatedData.Insert("ReceivingAmountCurrency",	ReceivingAmountCurrency);
	CalculatedData.Insert("TotalSendingCurrency",		TotalSendingCurrency);
	CalculatedData.Insert("SendingBankFee",				SendingBankFee);
	CalculatedData.Insert("SendingBankFeeCurrency",		SendingBankFeeCurrency);
	CalculatedData.Insert("TotalReceivingCurrency",		TotalReceivingCurrency);
	CalculatedData.Insert("ReceivingBankFee",			ReceivingBankFee);
	CalculatedData.Insert("ReceivingBankFeeCurrency",	ReceivingBankFeeCurrency);
	CalculatedData.Insert("CentralBankERSending",		CentralBankERSending);
	CalculatedData.Insert("CentralBankMulSending",		CentralBankMulSending);
	CalculatedData.Insert("CentralBankERReceiving",		CentralBankERReceiving);
	CalculatedData.Insert("CentralBankMulreceiving",	CentralBankMulreceiving);
	CalculatedData.Insert("AmountFee",					AmountFee);
	
	Return CalculatedData;
	
EndFunction

Procedure RunControl(DocumentRef, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	If StructureTemporaryTables.RegisterRecordsCashAssetsChange Then
		
		Query = New Query(
		"SELECT
		|	RegisterRecordsCashAssetsChange.LineNumber AS LineNumber,
		|	RegisterRecordsCashAssetsChange.Company AS CompanyPresentation,
		|	RegisterRecordsCashAssetsChange.BankAccountPettyCash AS BankAccountCashPresentation,
		|	RegisterRecordsCashAssetsChange.Currency AS CurrencyPresentation,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsTypeRepresentation,
		|	RegisterRecordsCashAssetsChange.CashAssetsType AS CashAssetsType,
		|	ISNULL(CashAssetsBalances.AmountBalance, 0) AS AmountBalance,
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS AmountCurBalance,
		|	RegisterRecordsCashAssetsChange.SumCurChange + ISNULL(CashAssetsBalances.AmountCurBalance, 0) AS BalanceCashAssets,
		|	RegisterRecordsCashAssetsChange.SumBeforeWrite AS SumBeforeWrite,
		|	RegisterRecordsCashAssetsChange.AmountOnWrite AS AmountOnWrite,
		|	RegisterRecordsCashAssetsChange.AmountChange AS AmountChange,
		|	RegisterRecordsCashAssetsChange.AmountCurBeforeWrite AS AmountCurBeforeWrite,
		|	RegisterRecordsCashAssetsChange.SumCurOnWrite AS SumCurOnWrite,
		|	RegisterRecordsCashAssetsChange.SumCurChange AS SumCurChange
		|FROM
		|	RegisterRecordsCashAssetsChange AS RegisterRecordsCashAssetsChange
		|		LEFT JOIN AccumulationRegister.CashAssets.Balance(&ControlTime, ) AS CashAssetsBalances
		|		ON RegisterRecordsCashAssetsChange.Company = CashAssetsBalances.Company
		|			AND RegisterRecordsCashAssetsChange.CashAssetsType = CashAssetsBalances.CashAssetsType
		|			AND RegisterRecordsCashAssetsChange.BankAccountPettyCash = CashAssetsBalances.BankAccountPettyCash
		|			AND RegisterRecordsCashAssetsChange.Currency = CashAssetsBalances.Currency
		|WHERE
		|	ISNULL(CashAssetsBalances.AmountCurBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		QueryResult = Query.Execute();
		
		If Not QueryResult.IsEmpty() Then
			DocumentObject = DocumentRef.GetObject();
			QueryResultSelection = QueryResult.Select();
			DriveServer.ShowMessageAboutPostingToCashAssetsRegisterErrors(DocumentObject, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndRegion

#Region Private

#Region TableGeneration

Procedure GenerateTableBankCharges(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	TemporaryTableBankCharges.Period AS Period,
	|	TemporaryTableBankCharges.Company AS Company,
	|	TemporaryTableBankCharges.BankAccount AS BankAccount,
	|	TemporaryTableBankCharges.Currency AS Currency,
	|	TemporaryTableBankCharges.BankCharge AS BankCharge,
	|	TemporaryTableBankCharges.Item AS Item,
	|	TemporaryTableBankCharges.PostingContent AS PostingContent,
	|	TemporaryTableBankCharges.Amount AS Amount,
	|	TemporaryTableBankCharges.AmountCur AS AmountCur,
	|	TemporaryTableBankCharges.GLAccount AS GLAccount,
	|	TemporaryTableBankCharges.GLExpenseAccount AS GLExpenseAccount
	|INTO TemporaryTableBankCharges
	|FROM
	|	(SELECT
	|		DocumentTable.Date AS Period,
	|		DocumentTable.Company AS Company,
	|		DocumentTable.ToAccount AS BankAccount,
	|		DocumentTable.ToAccountCashCurrency AS Currency,
	|		DocumentTable.BankCharge AS BankCharge,
	|		DocumentTable.ContentBankComission AS PostingContent,
	|		DocumentTable.BankChargeItem AS Item,
	|		DocumentTable.BankChargeGLAccount AS GLAccount,
	|		DocumentTable.BankChargeGLExpenseAccount AS GLExpenseAccount,
	|		DocumentTable.ReceivingBankFee AS Amount,
	|		DocumentTable.ReceivingBankFeeCurrency AS AmountCur
	|	FROM
	|		TemporaryTableHeader AS DocumentTable
	|	WHERE
	|		(DocumentTable.ReceivingBankFee <> 0
	|				OR DocumentTable.ReceivingBankFeeCurrency <> 0)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentTable.Date,
	|		DocumentTable.Company,
	|		DocumentTable.FromAccount,
	|		DocumentTable.FromAccountCashCurrency,
	|		DocumentTable.BankCharge,
	|		DocumentTable.ContentBankComission,
	|		DocumentTable.BankChargeItem,
	|		DocumentTable.BankChargeGLAccount,
	|		DocumentTable.BankChargeGLExpenseAccount,
	|		DocumentTable.SendingBankFee,
	|		DocumentTable.SendingBankFeeCurrency
	|	FROM
	|		TemporaryTableHeader AS DocumentTable
	|	WHERE
	|		(DocumentTable.SendingBankFee <> 0
	|				OR DocumentTable.SendingBankFeeCurrency <> 0)) AS TemporaryTableBankCharges
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableBankCharges.Period AS Period,
	|	TemporaryTableBankCharges.Company AS Company,
	|	TemporaryTableBankCharges.BankAccount AS BankAccount,
	|	TemporaryTableBankCharges.Currency AS Currency,
	|	TemporaryTableBankCharges.BankCharge AS BankCharge,
	|	TemporaryTableBankCharges.Item AS Item,
	|	TemporaryTableBankCharges.PostingContent AS PostingContent,
	|	TemporaryTableBankCharges.Amount AS Amount,
	|	TemporaryTableBankCharges.AmountCur AS AmountCur
	|FROM
	|	TemporaryTableBankCharges AS TemporaryTableBankCharges";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBankCharges", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableCashAssets(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefForeignCurrencyExchange);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",			StructureAdditionalProperties.ForPosting.PointInTime.Date);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("CashExpense",			NStr("en = 'Bank payment'", MainLanguageCode));
	Query.SetParameter("ExchangeDifference",	NStr("en = 'Foreign currency exchange gains and losses'", MainLanguageCode));
	
	Query.Text =
	"SELECT
	|	1 AS LineNumber,
	|	DocumentTable.MainOperationContent AS ContentOfAccountingRecord,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	DocumentTable.Date AS Date,
	|	DocumentTable.Company AS Company,
	|	VALUE(Enum.CashAssetTypes.Noncash) AS CashAssetsType,
	|	DocumentTable.Item AS Item,
	|	DocumentTable.ToAccount AS BankAccountPettyCash,
	|	DocumentTable.ToAccountGLAccount AS GLAccount,
	|	DocumentTable.ToAccountCashCurrency AS Currency,
	|	DocumentTable.TotalSending AS Amount,
	|	DocumentTable.ReceivingAmountCurrency AS AmountCur,
	|	DocumentTable.TotalSending AS AmountForBalance,
	|	DocumentTable.ReceivingAmountCurrency AS AmountCurForBalance
	|INTO TemporaryTableCashAssets
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.MainOperationContent,
	|	VALUE(AccumulationRecordType.Expense),
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	DocumentTable.Item,
	|	DocumentTable.FromAccount,
	|	DocumentTable.FromAccountGLAccount,
	|	DocumentTable.FromAccountCashCurrency,
	|	DocumentTable.TotalSending,
	|	DocumentTable.TotalSendingCurrency,
	|	DocumentTable.TotalSending,
	|	DocumentTable.TotalSendingCurrency
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	TableBankCharges.PostingContent,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableBankCharges.Period,
	|	TableBankCharges.Company,
	|	VALUE(Enum.CashAssetTypes.Noncash),
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency,
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur),
	|	SUM(TableBankCharges.Amount),
	|	SUM(TableBankCharges.AmountCur)
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|
	|GROUP BY
	|	TableBankCharges.PostingContent,
	|	TableBankCharges.Company,
	|	TableBankCharges.Period,
	|	TableBankCharges.Item,
	|	TableBankCharges.BankAccount,
	|	TableBankCharges.GLAccount,
	|	TableBankCharges.Currency
	|
	|INDEX BY
	|	Company,
	|	CashAssetsType,
	|	BankAccountPettyCash,
	|	Currency,
	|	GLAccount";
	
	Query.Execute();
	
	// Setting of the exclusive lock of the cash funds controlled balances.
	Query.Text =
	"SELECT
	|	TemporaryTableCashAssets.Company AS Company,
	|	TemporaryTableCashAssets.CashAssetsType AS CashAssetsType,
	|	TemporaryTableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
	|	TemporaryTableCashAssets.Currency AS Currency
	|FROM
	|	TemporaryTableCashAssets";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.CashAssets");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	QueryNumber = 0;
	Query.Text = DriveServer.GetQueryTextExchangeRateDifferencesCashAssets(Query.TempTablesManager, QueryNumber);
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableCashAssets", ResultsArray[QueryNumber].Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpenses(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.SetParameter("StructuralUnit", StructureAdditionalProperties.ForPosting.StructuralUnit);
	
	Query.Text =
	"SELECT
	|	TableBankCharges.Period AS Period,
	|	TableBankCharges.Company AS Company,
	|	&StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS SalesOrder,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	TableBankCharges.GLExpenseAccount AS GLAccount,
	|	TableBankCharges.PostingContent AS ContentOfAccountingRecord,
	|	0 AS AmountIncome,
	|	TableBankCharges.Amount AS AmountExpense,
	|	TableBankCharges.Amount AS Amount
	|FROM
	|	TemporaryTableBankCharges AS TableBankCharges
	|WHERE
	|	TableBankCharges.Amount <> 0";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableAccountingJournalEntries(DocumentRefForeignCurrencyExchange, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	1 AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	DocumentTable.ToAccountGLAccount AS AccountDr,
	|	DocumentTable.FromAccountGLAccount AS AccountCr,
	|	DocumentTable.ToAccountCashCurrency AS CurrencyDr,
	|	DocumentTable.FromAccountCashCurrency AS CurrencyCr,
	|	DocumentTable.ReceivingAmountCurrency AS AmountCurDr,
	|	DocumentTable.TotalSendingCurrency AS AmountCurCr,
	|	DocumentTable.TotalSending AS Amount,
	|	DocumentTable.MainOperationContent AS Content
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankChargeGLExpenseAccount,
	|	DocumentTable.FromAccountGLAccount,
	|	UNDEFINED,
	|	DocumentTable.FromAccountCashCurrency,
	|	0,
	|	DocumentTable.SendingBankFeeCurrency,
	|	DocumentTable.SendingBankFee,
	|	DocumentTable.ContentBankComission
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.SendingBankFee <> 0
	|			OR DocumentTable.SendingBankFeeCurrency <> 0)
	|
	|UNION ALL
	|
	|SELECT
	|	3,
	|	1,
	|	DocumentTable.Date,
	|	DocumentTable.Company,
	|	VALUE(Catalog.PlanningPeriods.Actual),
	|	DocumentTable.BankChargeGLExpenseAccount,
	|	DocumentTable.ToAccountGLAccount,
	|	UNDEFINED,
	|	DocumentTable.ToAccountCashCurrency,
	|	0,
	|	DocumentTable.ReceivingBankFeeCurrency,
	|	DocumentTable.ReceivingBankFee,
	|	DocumentTable.ContentBankComission
	|FROM
	|	TemporaryTableHeader AS DocumentTable
	|WHERE
	|	(DocumentTable.ReceivingBankFee <> 0
	|			OR DocumentTable.ReceivingBankFeeCurrency <> 0)
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
		
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", QueryResult.Unload());
	
EndProcedure

Procedure GenerateTableIncomeAndExpensesCashMethod(DocumentRefPaymentReceipt, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.SetParameter("IncomeAndExpensesAccountingCashMethod", StructureAdditionalProperties.AccountingPolicy.IncomeAndExpensesAccountingCashMethod);
	
	Query.Text =
	"SELECT
	|	Table.Period AS Period,
	|	Table.Company AS Company,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	Table.Item AS Item,
	|	0 AS AmountIncome,
	|	Table.Amount AS AmountExpense
	|FROM
	|	TemporaryTableBankCharges AS Table
	|WHERE
	|	&IncomeAndExpensesAccountingCashMethod
	|	AND Table.Amount <> 0";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpensesCashMethod", QueryResult.Unload());
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

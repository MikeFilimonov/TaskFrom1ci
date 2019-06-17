﻿// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Period = Parameters.Date;
	ParentCompany = Parameters.ParentCompany;
	Counterparty = Parameters.Counterparty;
	CashCurrency = Parameters.CashCurrency;
	Ref = Parameters.Ref;
	OperationKind = Parameters.OperationKind;
	DocumentAmount = Parameters.DocumentAmount;
	
	Items.FilteredDebtsContract.Visible = Counterparty.DoOperationsByContracts;
	Items.FilteredDebtsDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.FilteredDebtsOrder.Visible = Counterparty.DoOperationsByOrders;
	
	Items.DebtsListContract.Visible = Counterparty.DoOperationsByContracts;
	Items.DebtsListDocument.Visible = Counterparty.DoOperationsByDocuments;
	Items.DebtsListOrder.Visible = Counterparty.DoOperationsByOrders;
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	AddressPaymentDetailsInStorage = Parameters.AddressPaymentDetailsInStorage;
	FilteredDebts.Load(GetFromTempStorage(AddressPaymentDetailsInStorage));
	
	// Removing the rows with no amount.
	RowToDeleteArray = New Array;
	For Each CurRow In FilteredDebts Do
		If CurRow.SettlementsAmount = 0 Then
			RowToDeleteArray.Add(CurRow);
		EndIf;
	EndDo;
	
	For Each CurItem In RowToDeleteArray Do
		FilteredDebts.Delete(CurItem);
	EndDo;
	
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	Items.DebtsListExchangeRate.Visible = ForeignExchangeAccounting;
	Items.DebtsListMultiplicity.Visible = ForeignExchangeAccounting;
	
	Items.Totals.Visible = Not ForeignExchangeAccounting;
	
	FillDebts();
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountTotal();
	
EndProcedure

// Procedure calculates the total amount.
//
&AtClient
Procedure CalculateAmountTotal()
	
	AmountTotal = 0;
	
	For Each CurRow In FilteredDebts Do
		AmountTotal = AmountTotal + CurRow.SettlementsAmount;
	EndDo;
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage()
	
	TableFilteredDebts = FilteredDebts.Unload();
	PutToTempStorage(TableFilteredDebts, AddressPaymentDetailsInStorage);
	
EndProcedure

// The procedure places selection results into pick
//
&AtClient
Procedure DebtsListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("DebtsListValueChoiceEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount", CurrentRow, SettlementsAmount)), SettlementsAmount, "Enter the amount", , );
		Return;
	EndIf;
	
	DebtsListValueChoiceFragment(SettlementsAmount, CurrentRow);
EndProcedure

&AtClient
Procedure DebtsListValueChoiceEnd(Result, AdditionalParameters) Export
    
    CurrentRow = AdditionalParameters.CurrentRow;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    DebtsListValueChoiceFragment(SettlementsAmount, CurrentRow);

EndProcedure

&AtClient
Procedure DebtsListValueChoiceFragment(Val SettlementsAmount, Val CurrentRow)
    
    Var NewRow, Rows, SearchStructure;
    
    CurrentRow.SettlementsAmount = SettlementsAmount;
    
    SearchStructure = New Structure("Contract, Document, Order", CurrentRow.Contract, CurrentRow.Document, CurrentRow.Order);
    Rows = FilteredDebts.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        NewRow.SettlementsAmount = NewRow.SettlementsAmount + SettlementsAmount;
    Else
        NewRow = FilteredDebts.Add();
        FillPropertyValues(NewRow, CurrentRow);
    EndIf;
    
    Items.FilteredDebts.CurrentRow = NewRow.GetID();
    
    CalculateAmountTotal();
    FillDebts();

EndProcedure

// Procedure - DragStart of list DebtsList event handler.
//
&AtClient
Procedure DebtsListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("Contract", CurrentData.Contract);
	If CurrentData.Property("ExchangeRate") Then
		Structure.Insert("ExchangeRate", CurrentData.ExchangeRate);
	EndIf;
	If CurrentData.Property("Multiplicity") Then
		Structure.Insert("Multiplicity", CurrentData.Multiplicity);
	EndIf;
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure

// Procedure - DragChek of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure

// Procedure - DragChek of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	
	ParametersStructure = DragParameters.Value;
	
	SettlementsAmount = ParametersStructure.SettlementsAmount;
	If AskAmount Then
		ShowInputNumber(New NotifyDescription("FilteredDebtsDragEnd", ThisObject, New Structure("StructureParameters,SettlementsAmount", ParametersStructure, SettlementsAmount)), SettlementsAmount, "Enter the amount", , );
        Return;
	EndIf;
	
	FilteredDebtsDragFragment(ParametersStructure, SettlementsAmount);
EndProcedure

&AtClient
Procedure FilteredDebtsDragEnd(Result, AdditionalParameters) Export
    
    ParametersStructure = AdditionalParameters.ParametersStructure;
    SettlementsAmount = ?(Result = Undefined, AdditionalParameters.SettlementsAmount, Result);
    
    
    If Not (Result <> Undefined) Then
        Return;
    EndIf;
    
    FilteredDebtsDragFragment(ParametersStructure, SettlementsAmount);

EndProcedure

&AtClient
Procedure FilteredDebtsDragFragment(Val ParametersStructure, Val SettlementsAmount)
    
    Var NewRow, Rows, SearchStructure;
    
    ParametersStructure.SettlementsAmount = SettlementsAmount;
    
    SearchStructure = New Structure("Contract, Document, Order", ParametersStructure.Contract, ParametersStructure.Document, ParametersStructure.Order);
    Rows = FilteredDebts.FindRows(SearchStructure);
    
    If Rows.Count() > 0 Then
        NewRow = Rows[0];
        NewRow.SettlementsAmount = NewRow.SettlementsAmount + SettlementsAmount;
    Else 
        NewRow = FilteredDebts.Add();
        FillPropertyValues(NewRow, ParametersStructure);
    EndIf;
    
    Items.FilteredDebts.CurrentRow = NewRow.GetID();
    
    CalculateAmountTotal();
    FillDebts();

EndProcedure

// Procedure - OK button click handler.
//
&AtClient
Procedure OK(Command)
	
	WritePickToStorage();
	Close(DialogReturnCode.OK);
	
EndProcedure

// Procedure - handler of clicking the Refresh button.
//
&AtClient
Procedure Refresh(Command)
	
	FillDebts();
	
EndProcedure

// Procedure - handler of clicking the AskAmount button.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure

// Procedure - OnChange of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsOnChange(Item)
	
	CalculateAmountTotal();
	FillDebts();
	
EndProcedure

// Procedure - OnStartEdit of list FilteredDebts event handler.
//
&AtClient
Procedure FilteredDebtsOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountTotal();
		FillDebts();
	EndIf;
	
EndProcedure

// Procedure is filling the payment details.
//
&AtServer
Procedure FillPaymentDetails()
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsReceivableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsReceivableBalances.AmountCurBalance * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Company AS Company,
	|		AccountsReceivableBalances.Counterparty AS Counterparty,
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Order AS Order,
	|		AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					// TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Company,
	|		DocumentRegisterRecordsAccountsReceivable.Counterparty,
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
	|		DocumentRegisterRecordsAccountsReceivable.SettlementsType,
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
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &Currency) AS ExchangeRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS SettlementsExchangeRates
	|		ON AccountsReceivableBalances.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	AccountsReceivableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsReceivableBalances.Company,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.SettlementsType,
	|	AccountsReceivableBalances.Document.Date,
	|	ExchangeRatesOfDocument.ExchangeRate,
	|	ExchangeRatesOfDocument.Multiplicity,
	|	SettlementsExchangeRates.ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Period);
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("Ref", Ref);
	
	NeedFilterByContracts = DriveReUse.CounterpartyContractsControlNeeded();
	ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind);
	If Counterparty.DoOperationsByContracts
	   AND NeedFilterByContracts Then
		Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "And Contract.ContractType IN (&ContractTypesList)");
		Query.SetParameter("ContractTypesList", Catalogs.CounterpartyContracts.GetContractKindsListForDocument(Ref, OperationKind));
	EndIf;
	
	ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
		Counterparty,
		Counterparty,
		ContractTypesList
	);
	
	StructureContractCurrencyRateByDefault = InformationRegisters.ExchangeRates.GetLast(
		Period,
		New Structure("Currency", ContractByDefault.SettlementsCurrency)
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	FilteredDebts.Clear();
	
	AmountLeftToDistribute = DocumentAmount;
	
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Period, New Structure("Currency", CashCurrency));
	
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
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = FilteredDebts.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			NewRow.Contract = ContractByDefault;
			NewRow.ExchangeRate = ?(
				StructureContractCurrencyRateByDefault.ExchangeRate = 0,
				1,
				StructureContractCurrencyRateByDefault.ExchangeRate
			);
			NewRow.Multiplicity = ?(
				StructureContractCurrencyRateByDefault.Multiplicity = 0,
				1,
				StructureContractCurrencyRateByDefault.Multiplicity
			);
			NewRow.SettlementsAmount = DriveServer.RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure - Handler of clicking the FillAutomatically button.
//
&AtClient
Procedure FillAutomatically(Command)
	
	FillPaymentDetails();
	CalculateAmountTotal();
	FillDebts();
	
EndProcedure

// Procedure fills the debt list.
//
&AtServer
Procedure FillDebts()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	&Company AS Company,
	|	FilteredDebts.Contract AS Contract,
	|	FilteredDebts.Document AS Document,
	|	FilteredDebts.Order AS Order,
	|	FilteredDebts.SettlementsAmount AS SettlementsAmount
	|INTO TableFilteredDebts
	|FROM
	|	&TableFilteredDebts AS FilteredDebts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.SettlementsType AS SettlementsType,
	|	AccountsReceivableBalances.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableTable
	|FROM
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company = &Company
	|				AND Counterparty = &Counterparty
	|				AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsReceivableBalances
	|
	|UNION ALL
	|
	|SELECT
	|	&Company,
	|	&Counterparty,
	|	FilteredDebts.Contract,
	|	FilteredDebts.Document,
	|	FilteredDebts.Order,
	|	VALUE(Enum.SettlementsTypes.Debt),
	|	-FilteredDebts.SettlementsAmount
	|FROM
	|	TableFilteredDebts AS FilteredDebts
	|
	|UNION ALL
	|
	|SELECT
	|	DocumentRegisterRecordsAccountsReceivable.Company,
	|	DocumentRegisterRecordsAccountsReceivable.Counterparty,
	|	DocumentRegisterRecordsAccountsReceivable.Contract,
	|	DocumentRegisterRecordsAccountsReceivable.Document,
	|	DocumentRegisterRecordsAccountsReceivable.Order,
	|	DocumentRegisterRecordsAccountsReceivable.SettlementsType,
	|	CASE
	|		WHEN DocumentRegisterRecordsAccountsReceivable.RecordType = VALUE(AccumulationRecordType.Receipt)
	|			THEN -DocumentRegisterRecordsAccountsReceivable.AmountCur
	|		ELSE DocumentRegisterRecordsAccountsReceivable.AmountCur
	|	END
	|FROM
	|	AccumulationRegister.AccountsReceivable AS DocumentRegisterRecordsAccountsReceivable
	|WHERE
	|	DocumentRegisterRecordsAccountsReceivable.Recorder = &Ref
	|	AND DocumentRegisterRecordsAccountsReceivable.Period <= &Period
	|	AND DocumentRegisterRecordsAccountsReceivable.Company = &Company
	|	AND DocumentRegisterRecordsAccountsReceivable.Counterparty = &Counterparty
	|	AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableTable.Company AS Company,
	|	AccountsReceivableTable.Contract AS Contract,
	|	CASE
	|		WHEN Counterparties.DoOperationsByDocuments
	|			THEN AccountsReceivableTable.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN Counterparties.DoOperationsByOrders
	|			THEN AccountsReceivableTable.Order
	|		ELSE UNDEFINED
	|	END AS Order,
	|	AccountsReceivableTable.AmountCurBalance AS AmountCurBalance
	|INTO AccountsReceivableCounterparty
	|FROM
	|	AccountsReceivableTable AS AccountsReceivableTable
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON AccountsReceivableTable.Counterparty = Counterparties.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountsReceivableCounterparty.Document AS Document
	|INTO DocumentTable
	|FROM
	|	AccountsReceivableCounterparty AS AccountsReceivableCounterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TRUE AS ExistsEPD,
	|	SalesInvoiceEarlyPaymentDiscounts.Ref AS SalesInvoice
	|INTO EarlePaymentDiscounts
	|FROM
	|	Document.SalesInvoice.EarlyPaymentDiscounts AS SalesInvoiceEarlyPaymentDiscounts
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON SalesInvoiceEarlyPaymentDiscounts.Ref = DocumentTable.Document
	|WHERE
	|	ENDOFPERIOD(SalesInvoiceEarlyPaymentDiscounts.DueDate, DAY) >= &Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.Period AS Period
	|INTO EntriesRecorderPeriod
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries
	|		INNER JOIN DocumentTable AS DocumentTable
	|		ON AccountingJournalEntries.Recorder = DocumentTable.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableCounterparty.Company AS Company,
	|	AccountsReceivableCounterparty.Contract AS Contract,
	|	AccountsReceivableCounterparty.Document AS Document,
	|	AccountsReceivableCounterparty.Order AS Order,
	|	AccountsReceivableCounterparty.AmountCurBalance AS AmountCurBalance,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	ISNULL(EarlePaymentDiscounts.ExistsEPD, FALSE) AS ExistsEPD,
	|	ISNULL(EntriesRecorderPeriod.Period, DATETIME(1, 1, 1)) AS DocumentDate
	|INTO AccountsReceivableContract
	|FROM
	|	AccountsReceivableCounterparty AS AccountsReceivableCounterparty
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON AccountsReceivableCounterparty.Contract = CounterpartyContracts.Ref
	|		LEFT JOIN EarlePaymentDiscounts AS EarlePaymentDiscounts
	|		ON AccountsReceivableCounterparty.Document = EarlePaymentDiscounts.SalesInvoice
	|		LEFT JOIN EntriesRecorderPeriod AS EntriesRecorderPeriod
	|		ON AccountsReceivableCounterparty.Document = EntriesRecorderPeriod.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableContract.Company AS Company,
	|	AccountsReceivableContract.Contract AS Contract,
	|	AccountsReceivableContract.Document AS Document,
	|	AccountsReceivableContract.DocumentDate AS DocumentDate,
	|	AccountsReceivableContract.Order AS Order,
	|	SUM(AccountsReceivableContract.AmountCurBalance) AS SettlementsAmount,
	|	MAX(SettlementsExchangeRates.ExchangeRate) AS ExchangeRate,
	|	MAX(SettlementsExchangeRates.Multiplicity) AS Multiplicity,
	|	AccountsReceivableContract.ExistsEPD AS ExistsEPD
	|INTO AccountsReceivableGrouped
	|FROM
	|	AccountsReceivableContract AS AccountsReceivableContract
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS SettlementsExchangeRates
	|		ON AccountsReceivableContract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|
	|GROUP BY
	|	AccountsReceivableContract.Company,
	|	AccountsReceivableContract.Contract,
	|	AccountsReceivableContract.Document,
	|	AccountsReceivableContract.DocumentDate,
	|	AccountsReceivableContract.Order,
	|	AccountsReceivableContract.ExistsEPD
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	AccountsReceivableGrouped.Company AS Company,
	|	AccountsReceivableGrouped.Contract AS Contract,
	|	AccountsReceivableGrouped.Document AS Document,
	|	AccountsReceivableGrouped.DocumentDate AS DocumentDate,
	|	AccountsReceivableGrouped.Order AS Order,
	|	AccountsReceivableGrouped.SettlementsAmount AS SettlementsAmount,
	|	AccountsReceivableGrouped.ExchangeRate AS ExchangeRate,
	|	AccountsReceivableGrouped.Multiplicity AS Multiplicity,
	|	AccountsReceivableGrouped.ExistsEPD AS ExistsEPD
	|FROM
	|	AccountsReceivableGrouped AS AccountsReceivableGrouped
	|WHERE
	|	AccountsReceivableGrouped.SettlementsAmount > 0
	|
	|ORDER BY
	|	AccountsReceivableGrouped.DocumentDate";
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Period);
	Query.SetParameter("Currency", CashCurrency);
	Query.SetParameter("TableFilteredDebts", FilteredDebts.Unload());
	Query.SetParameter("Ref", Ref);
	
	DebtsList.Load(Query.Execute().Unload());
	
EndProcedure

// Procedure - BeforeStartAdding of list FilteredDebts event  handler.
//
&AtClient
Procedure FilteredDebtsBeforeAddingStart(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

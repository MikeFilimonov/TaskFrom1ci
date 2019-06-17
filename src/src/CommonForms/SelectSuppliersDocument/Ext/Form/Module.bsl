
&AtClient
Procedure AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow)
	
	SearchStructure = New Structure("Document, Order", CurrentRow.Document, CurrentRow.Order);
	Rows = ListFilteredAdvancesAndDebts.FindRows(SearchStructure);
	
	If Rows.Count() > 0 Then
		NewRow = Rows[0];
		SettlementsAmount = SettlementsAmount + NewRow.SettlementsAmount;
	Else
		NewRow = ListFilteredAdvancesAndDebts.Add();
	EndIf;
	
	FillPropertyValues(NewRow, CurrentRow);
	
	NewRow.SettlementsAmount = SettlementsAmount;
	
	NewRow.ExchangeRate = ?(NewRow.ExchangeRate = 0, 1, NewRow.ExchangeRate);
	NewRow.Multiplicity = ?(NewRow.Multiplicity = 0, 1, NewRow.Multiplicity);
	
	NewRow.ExchangeRate = ?(
		NewRow.SettlementsAmount = 0,
		1,
		CurrentRow.AccountingAmount / CurrentRow.SettlementsAmount * RateAccountingCurrency
	);
	
	If Not ForeignExchangeAccounting Then
		NewRow.AccountingAmount = CurrentRow.SettlementsAmount;
	ElsIf AskAmount OR Rows.Count() > 0 Then
		NewRow.AccountingAmount = DriveClient.RecalculateFromCurrencyToCurrency(
			NewRow.SettlementsAmount,
			NewRow.ExchangeRate,
			RateAccountingCurrency,
			NewRow.Multiplicity,
			AccountingCurrencyMultiplicity
		);
	EndIf;
	
	Items.ListFilteredAdvancesAndDebts.CurrentRow = NewRow.GetID();
	
	CalculateAmountsTotal();
	
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowListFilteredAdvancesAndDebts In ListFilteredAdvancesAndDebts Do
		LineNumber = LineNumber + 1;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.ExchangeRate) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The exchange rate is empty in the line %1 of ""Selected documents"" section.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.Multiplicity) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The multiplier is empty in the line %1 of ""Selected documents"" section.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If Not ValueIsFilled(RowListFilteredAdvancesAndDebts.SettlementsAmount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The amount in contract currency is empty in the line %1 of ""Selected documents"" section.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
		If ForeignExchangeAccounting
		AND Not ValueIsFilled(RowListFilteredAdvancesAndDebts.AccountingAmount) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The amount in presentation currency is empty in the line %1 of ""Selected documents"" section.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure

// Procedure calculates the total amounts.
//
&AtClient
Procedure CalculateAmountsTotal()
	
	AccountingAmountTotal = 0;
	
	For Each CurRow In ListFilteredAdvancesAndDebts Do
		AccountingAmountTotal = AccountingAmountTotal + CurRow.AccountingAmount;
	EndDo;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Company			= Parameters.Company;
	Counterparty	= Parameters.Counterparty;
	Ref				= Parameters.Ref;
	Date			= Parameters.Date;
	ForeignExchangeAccounting = Constants.ForeignExchangeAccounting.Get();
	
	Items.AdvancesDebtsListDocument.Visible				= Counterparty.DoOperationsByDocuments;
	Items.AdvancesDebtsListOrder.Visible				= Counterparty.DoOperationsByOrders;
	Items.AdvancesDebtsListContract.Visible				= Counterparty.DoOperationsByContracts;
	Items.ListFilteredAdvancesAndDebtsDocument.Visible	= Counterparty.DoOperationsByDocuments;
	Items.ListFilteredAdvancesAndDebtsOrder.Visible		= Counterparty.DoOperationsByOrders;
	Items.ListFilteredAdvancesAndDebtsContract.Visible	= Counterparty.DoOperationsByContracts;
	
	AddressListFilteredAdvancesAndDebtsInStorage = Parameters.AddressDebitorInStorage;
	
	PresentationCurrency = Constants.PresentationCurrency.Get();
	StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", PresentationCurrency));
	RateAccountingCurrency = StructureByCurrency.ExchangeRate;
	AccountingCurrencyMultiplicity = StructureByCurrency.Multiplicity;
	
	RowOfColumns =
		"Contract,
		|Document,
		|Order,
		|AccountingAmount,
		|ExchangeRate,
		|Multiplicity,
		|SettlementsAmount,
		|AdvanceFlag";
	
	ListFilteredAdvancesAndDebts.Load(GetFromTempStorage(AddressListFilteredAdvancesAndDebtsInStorage));
	
	Items.AdvancesDebtsListAccountingAmount.Visible = ForeignExchangeAccounting;
	
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	CalculateAmountsTotal();
	
EndProcedure

// Procedure - OK button click handler.
//
&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WritePickToStorage();
		Close(DialogReturnCode.OK);
	EndIf;
	
EndProcedure

// Procedure - Handler of click Refresh.
//
&AtClient
Procedure Refresh(Command)
	
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure - Handler of click AskAmount.
//
&AtClient
Procedure AskAmount(Command)
	
	AskAmount = Not AskAmount;
	Items.AskAmount.Check = AskAmount;
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WritePickToStorage()
	
	ListFilteredAdvancesAndDebtsInStorage = ListFilteredAdvancesAndDebts.Unload(, RowOfColumns);
	PutToTempStorage(ListFilteredAdvancesAndDebtsInStorage, AddressListFilteredAdvancesAndDebtsInStorage);
	
EndProcedure

// It receives data set from the server for the ListFilteredAdvancesAndDebtsDocumentOnChange procedure.
//
&AtServerNoContext
Function GetDataDocumentOnChange(Document)
	
	StructureData = New Structure();
	
	StructureData.Insert("SettlementsAmount", Document.PaymentDetails.Total("SettlementsAmount"));
	
	Return StructureData;
	
EndFunction

// Adds a row into filtered.
//
&AtClient
Procedure AddRowIntoFiltered(CurrentRow)
	
	SettlementsAmount = CurrentRow.SettlementsAmount;
	If AskAmount Then
		
		NotifyDescription = New NotifyDescription("OpenPricesAndCurrencyFormEnd", ThisObject, New Structure("CurrentRow, SettlementsAmount", CurrentRow, SettlementsAmount));
		ShowInputNumber(NotifyDescription, SettlementsAmount, NStr("en = 'Enter the amount'"));
		
	Else
		
		AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow);
		
	EndIf;
	
EndProcedure

// Procedure puts fetch results in the selection.
//
&AtClient
Procedure AdvancesListValueChoice(Item, StandardProcessing, Value)
	
	StandardProcessing = False;
	CurrentRow = Item.CurrentData;
	AddRowIntoFiltered(CurrentRow);
	
EndProcedure

// Procedure - handler of event OnStartEdit of the ListFilteredAdvancesAndDebts tabular section.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsOnStartEdit(Item, NewRow, Copy)
	
	If Copy Then
		CalculateAmountsTotal();
		FillAdvancesAndDebts();
	EndIf;
	
EndProcedure

// Procedure - OnChange of input field SettlementsAmount of the
// ListFilteredAdvancesAndDebts part table event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsAccountsAmountOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange of input field Rate of
// the ListFilteredAdvancesAndDebts tabular section event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsRateOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// Procedure - OnChange of input field Repetition of
// the ListFilteredAdvancesAndDebts tabular section event handler. Calculates the amount of the payment.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsRepetitionOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// The OnChange event handler for the AccountingAmount field of the ListFilteredAdvancesAndDebts tabular section.
// It calculates the currency exchange rate and exchange rate multiplier.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsAccountingAmountOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	TabularSectionRow.ExchangeRate = ?(
		TabularSectionRow.ExchangeRate = 0,
		1,
		TabularSectionRow.ExchangeRate
	);
	
	TabularSectionRow.Multiplicity = 1;
	
	TabularSectionRow.ExchangeRate =
		?(TabularSectionRow.SettlementsAmount = 0,
			1,
			TabularSectionRow.AccountingAmount
		  / TabularSectionRow.SettlementsAmount
		  * RateAccountingCurrency
	);
	
EndProcedure

// Procedure - OnChange of input field Document of
// the ListFilteredAdvancesAndDebts tabular section event handler.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDocumentOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	If TypeOf(TabularSectionRow.Document) = Type("DocumentRef.CashVoucher")
	 OR TypeOf(TabularSectionRow.Document) = Type("DocumentRef.PaymentExpense") Then
		TabularSectionRow.AdvanceFlag = True;
	Else
		TabularSectionRow.AdvanceFlag = False;
	EndIf;
	
	If ValueIsFilled(TabularSectionRow.Document) Then
		StructureData = GetDataDocumentOnChange(TabularSectionRow.Document);
		TabularSectionRow.SettlementsAmount = StructureData.SettlementsAmount;
		CalculateAccountingSUM(TabularSectionRow);
	EndIf;
	
EndProcedure

// Procedure - handler of event StartDrag of list AdvancesList.
//
&AtClient
Procedure AdvancesListDragStart(Item, DragParameters, StandardProcessing)
	
	CurrentData = Item.CurrentData;
	Structure = New Structure;
	Structure.Insert("Contract", CurrentData.Contract);
	Structure.Insert("Document", CurrentData.Document);
	Structure.Insert("Order", CurrentData.Order);
	Structure.Insert("SettlementsAmount", CurrentData.SettlementsAmount);
	Structure.Insert("AdvanceFlag", CurrentData.AdvanceFlag);
	
	If CurrentData.Property("AccountingAmount") Then
		Structure.Insert("AccountingAmount", CurrentData.AccountingAmount);
	EndIf;
	
	DragParameters.Value = Structure;
	
	DragParameters.AllowedActions = DragAllowedActions.Copy;
	
EndProcedure

// Procedure - handler of event DragCheck of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDragCheck(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	DragParameters.Action = DragAction.Copy;
	
EndProcedure

// Procedure - handler of event Drag of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsDrag(Item, DragParameters, StandardProcessing, String, Field)
	
	StandardProcessing = False;
	CurrentRow = DragParameters.Value;
	AddRowIntoFiltered(CurrentRow);
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure - handler of event OnChange of list ListFilteredAdvancesAndDebts.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsOnChange(Item)
	
	CalculateAmountsTotal();
	FillAdvancesAndDebts();
	
EndProcedure

// Procedure - handler of event OnChange of list ListFilteredAdvancesAndDebtsContract.
//
&AtClient
Procedure ListFilteredAdvancesAndDebtsContractOnChange(Item)
	
	TabularSectionRow = Items.ListFilteredAdvancesAndDebts.CurrentData;
	
	StructureData = GetDataContractOnChange(
		Date,
		TabularSectionRow.Contract
	);
	
	If ValueIsFilled(TabularSectionRow.Contract) Then 
		TabularSectionRow.ExchangeRate      = ?(StructureData.CurrencyRateRepetition.ExchangeRate = 0, 1, StructureData.CurrencyRateRepetition.ExchangeRate);
		TabularSectionRow.Multiplicity = ?(StructureData.CurrencyRateRepetition.Multiplicity = 0, 1, StructureData.CurrencyRateRepetition.Multiplicity);
	EndIf;
	
	CalculateAccountingSUM(TabularSectionRow);
	
EndProcedure

// Procedure calculates the accounting amount.
//
&AtClient
Procedure CalculateAccountingSUM(TabularSectionRow)
	
	TabularSectionRow.ExchangeRate      = ?(TabularSectionRow.ExchangeRate      = 0, 1, TabularSectionRow.ExchangeRate);
	TabularSectionRow.Multiplicity = ?(TabularSectionRow.Multiplicity = 0, 1, TabularSectionRow.Multiplicity);
	
	TabularSectionRow.AccountingAmount = DriveClient.RecalculateFromCurrencyToCurrency(
		TabularSectionRow.SettlementsAmount,
		TabularSectionRow.ExchangeRate,
		RateAccountingCurrency,
		TabularSectionRow.Multiplicity,
		AccountingCurrencyMultiplicity
	);
	
EndProcedure

// It receives data set from the server for the CurrencyCashOnChange procedure.
//
&AtServerNoContext
Function GetDataContractOnChange(Date, Contract)
	
	StructureData = New Structure();
	
	StructureData.Insert(
		"CurrencyRateRepetition",
		InformationRegisters.ExchangeRates.GetLast(
			Date,
			New Structure("Currency", Contract.SettlementsCurrency)
		)
	);
	
	Return StructureData;
	
EndFunction

// Procedure fills the advance list.
//
&AtServer
Procedure FillAdvancesAndDebts()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	FilteredAdvancesAndDebts.AdvanceFlag,
	|	FilteredAdvancesAndDebts.Contract,
	|	FilteredAdvancesAndDebts.Document,
	|	CASE
	|		WHEN FilteredAdvancesAndDebts.Order = UNDEFINED
	|			THEN VALUE(Document.PurchaseOrder.EmptyRef)
	|		ELSE FilteredAdvancesAndDebts.Order
	|	END AS Order,
	|	FilteredAdvancesAndDebts.SettlementsAmount,
	|	FilteredAdvancesAndDebts.AccountingAmount
	|INTO TableFilteredAdvancesAndDebts
	|FROM
	|	&TableFilteredAdvancesAndDebts AS FilteredAdvancesAndDebts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Contract AS Contract,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.AdvanceFlag AS AdvanceFlag,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AccountingAmount,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS SettlementsAmount,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		CASE
	|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN TRUE
	|			ELSE FALSE
	|		END AS AdvanceFlag,
	|		CASE
	|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsPayableBalances.AmountBalance
	|			ELSE AccountsPayableBalances.AmountBalance
	|		END AS AmountBalance,
	|		CASE
	|			WHEN AccountsPayableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN -AccountsPayableBalances.AmountCurBalance
	|			ELSE AccountsPayableBalances.AmountCurBalance
	|		END AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		FilteredAdvancesAndDebts.Contract,
	|		FilteredAdvancesAndDebts.Document,
	|		FilteredAdvancesAndDebts.Order,
	|		FilteredAdvancesAndDebts.AdvanceFlag,
	|		-FilteredAdvancesAndDebts.AccountingAmount,
	|		-FilteredAdvancesAndDebts.SettlementsAmount
	|	FROM
	|		TableFilteredAdvancesAndDebts AS FilteredAdvancesAndDebts
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		CASE
	|			WHEN DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
	|				THEN TRUE
	|			ELSE FALSE
	|		END,
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
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS SettlementsExchangeRates
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.AdvanceFlag,
	|	AccountsPayableBalances.Document.Date,
	|	SettlementsExchangeRates.ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity
	|
	|HAVING
	|	(SUM(AccountsPayableBalances.AmountBalance) > 0
	|		OR SUM(AccountsPayableBalances.AmountCurBalance) > 0)
	|
	|ORDER BY
	|	DocumentDate";
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("TableFilteredAdvancesAndDebts", ListFilteredAdvancesAndDebts.Unload());
	
	AdvancesDebtsList.Load(Query.Execute().Unload());
	
EndProcedure

#Region InteractiveActionResultHandlers

&AtClient
// Procedure-handler of the result of entering the supplier advance offset amount.
//
Procedure OpenPricesAndCurrencyFormEnd(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = Undefined Then
		
		Return;
		
	EndIf;
	
	SettlementsAmount = ClosingResult;
	CurrentRow = AdditionalParameters.CurrentRow;
	
	AddAndCalculateAdvanceRow(SettlementsAmount, CurrentRow);	
	
EndProcedure

#EndRegion
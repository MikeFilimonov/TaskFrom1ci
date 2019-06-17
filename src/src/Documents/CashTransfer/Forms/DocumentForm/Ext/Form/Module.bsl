#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// Checks compliance of bank account cash assets currency and
// document currency in case of inconsistency, a default bank account (petty cash) is defined.
//
// Parameters:
// Company - CatalogRef.Companies - Document company 
// Currency - CatalogRef.Currencies - Document currency 
// BankAccount - CatalogRef.BankAccounts - Document bank account 
// Petty cash - CatalogRef.CashAccounts - Document petty cash
//
Function GetBankAccount(Company, Currency)
	
	Query = New Query(
	"SELECT
	|	CASE
	|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
	|			THEN Companies.BankAccountByDefault
	|		WHEN (NOT BankAccounts.BankAccount IS NULL )
	|			THEN BankAccounts.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccount
	|FROM
	|	Catalog.Companies AS Companies
	|		LEFT JOIN (SELECT
	|			BankAccounts.Ref AS BankAccount
	|		FROM
	|			Catalog.BankAccounts AS BankAccounts
	|		WHERE
	|			BankAccounts.CashCurrency = &CashCurrency
	|			AND BankAccounts.Owner = &Company) AS BankAccounts
	|		ON (TRUE)
	|WHERE
	|	Companies.Ref = &Company");
	
	Query.SetParameter("Company", Company);
	Query.SetParameter("CashCurrency", Currency);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	StructureData = New Structure();
	If Selection.Next() Then
		Return Selection.BankAccount;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

&AtServerNoContext
// Checks data with server for procedure CompanyOnChange.
//
Function GetCompanyDataOnChange(Company, Currency, BankAccount)

	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, Currency));
	
	Return StructureData;

EndFunction

&AtServerNoContext
// Checks data with server for procedure CashAssetsCurrencyOnChange.
//
Function GetDataCashAssetsCurrencyOnChange(Company, Currency, BankAccount, NewCurrency, DocumentAmount, Date)
	
	StructureData = New Structure();
	StructureData.Insert("BankAccount", GetBankAccount(Company, NewCurrency));
	
	Query = New Query(
	"SELECT
	|	CASE
	|		WHEN ExchangeRates.Multiplicity <> 0
	|				AND (NOT ExchangeRates.Multiplicity IS NULL )
	|				AND NewExchangeRates.ExchangeRate <> 0
	|				AND (NOT NewExchangeRates.ExchangeRate IS NULL )
	|			THEN &DocumentAmount * (ExchangeRates.ExchangeRate * NewExchangeRates.Multiplicity) / (ExchangeRates.Multiplicity * NewExchangeRates.ExchangeRate)
	|		ELSE 0
	|	END AS Amount
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&Date, Currency = &Currency) AS ExchangeRates
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Date, Currency = &NewCurrency) AS NewExchangeRates
	|		ON (TRUE)");
	 
	Query.SetParameter("Currency", Currency);
	Query.SetParameter("NewCurrency", NewCurrency);
	Query.SetParameter("DocumentAmount", DocumentAmount);
	Query.SetParameter("Date", Date);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	If Selection.Next() Then
		StructureData.Insert("Amount", Selection.Amount);
	Else
		StructureData.Insert("Amount", 0);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the ContractOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	DATEDIFF = DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange);
		
	StructureData = New Structure;
	
	StructureData.Insert(
		"DATEDIFF",
		DATEDIFF
	);
	
	Return StructureData;
	
EndFunction

// Checks whether document is approved or not.
//
&AtServerNoContext
Function DocumentApproved(BasisDocument)
	
	Return BasisDocument.PaymentConfirmationStatus = Enums.PaymentApprovalStatuses.Approved;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

&AtServer
// Sets the current page for the cash assets type.
//
// Parameters:
//  BusinessOperation - EnumRef.EconomicOperations - Economic operations
//
Procedure SetCurrentPage()
	
	If Object.CashAssetsType = Enums.CashAssetTypes.Noncash Then
		
		Items.BankAccount.Enabled = True;
		Items.BankAccount.Visible 	= True;
		Items.PettyCash.Visible 			= False;
		
	ElsIf Object.CashAssetsType = Enums.CashAssetTypes.Cash Then
		
		Items.PettyCash.Enabled 			= True;
		Items.BankAccount.Visible 	= False;
		Items.PettyCash.Visible 			= True;
		
	Else
		
		Items.BankAccount.Enabled = False;
		Items.PettyCash.Enabled 			= False;
		
	EndIf;
	
EndProcedure

&AtServer
// Sets the current page for the cash assets type.
//
// Parameters:
// BusinessOperation - EnumRef.EconomicOperations - Economic operations
//
Procedure SetRecipientCurrentPage()
	
	If Object.CashAssetsTypePayee = Enums.CashAssetTypes.Noncash Then
		
		Items.BankAccountPayee.Enabled 	= True;
		Items.BankAccountPayee.Visible 	= True;
		Items.PettyCashPayee.Visible 				= False;
		
	ElsIf Object.CashAssetsTypePayee = Enums.CashAssetTypes.Cash Then
		
		Items.PettyCashPayee.Enabled 			= True;
		Items.BankAccountPayee.Visible 	= False;
		Items.PettyCashPayee.Visible 				= True;
		
	Else
		
		Items.BankAccountPayee.Enabled 	= False;
		Items.PettyCashPayee.Enabled 			= False;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	If Not ValueIsFilled(Object.Ref)
	   AND Not ValueIsFilled(Parameters.CopyingValue) Then
		Query = New Query(
		"SELECT
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.CashCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			If Not ValueIsFilled(Object.BankAccount) Then
				Object.BankAccount = Selection.BankAccount;
			EndIf;
		EndIf;
		If Not ValueIsFilled(Object.BankAccountPayee) Then
			Object.BankAccountPayee = Object.BankAccount;
		EndIf;
		
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		EndIf;
		If Not ValueIsFilled(Object.PettyCashPayee) Then
			Object.PettyCashPayee = Object.PettyCash;
		EndIf;
	EndIf;
	
	Currency = Object.CashCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SetCurrentPage();
	SetRecipientCurrentPage();
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

&AtClient
// Procedure - form event handler "BeforeWrite".
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentCashTransfer");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtClient
// Procedure - "AfterWrite" event handler of the forms.
//
Procedure AfterWrite()
	
	Notify();
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

&AtClient
// Procedure - event handler OnChange of the Company input field.
//
Procedure CompanyOnChange(Item)
	
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(
		Object.Company,
		Object.CashCurrency,
		Object.BankAccount
	);
	Object.BankAccount = StructureData.BankAccount;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field CashAssetsCurrency.
//
Procedure CashAssetsCurrencyOnChange(Item)
	
	If Currency <> Object.CashCurrency Then
		
		StructureData = GetDataCashAssetsCurrencyOnChange(
			Object.Company,
			Currency,
			Object.BankAccount,
			Object.CashCurrency,
			Object.DocumentAmount,
			Object.Date);
		
		Object.BankAccount = StructureData.BankAccount;
		
		If Object.DocumentAmount <> 0 Then
			Mode = QuestionDialogMode.YesNo;
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CashAssetsCurrencyOnChangeEnd", ThisObject, New Structure("StructureData", StructureData)), NStr("en = 'Document currency is changed. Recalculate document amount?'"), Mode);
            Return;
		EndIf;
		CashAssetsCurrencyOnChangeFragment();

		
	EndIf;
	
EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeEnd(Result, AdditionalParameters) Export
    
    StructureData = AdditionalParameters.StructureData;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        Object.DocumentAmount = StructureData.Amount;
    EndIf;
    
    CashAssetsCurrencyOnChangeFragment();

EndProcedure

&AtClient
Procedure CashAssetsCurrencyOnChangeFragment()
    
    Currency = Object.CashCurrency;

EndProcedure

&AtClient
// Procedure - event handler OnChange input field CashAssetsType.
//
Procedure CashAssetsTypeOnChange(Item)
	
	SetCurrentPage();
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field CashAssetsTypePayee.
//
Procedure CashAssetsTypePayeeOnChange(Item)
	
	SetRecipientCurrentPage();
	
EndProcedure

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the PettyCash input field.
//
&AtClient
Procedure PettyCashOnChange(Item)
	
	SetAccountingCurrencyOnPettyCashChange(Object.PettyCash);
	
EndProcedure

// Procedure - event handler OnChange input field PettyCashPayee.
//
&AtClient
Procedure CashPayeeOnChange(Item)
	
	SetAccountingCurrencyOnPettyCashChange(Object.PettyCashPayee);
	
EndProcedure

// Procedure sets the currency default.
//
&AtClient
Procedure SetAccountingCurrencyOnPettyCashChange(PettyCash)
	
	Object.CashCurrency = ?(
		ValueIsFilled(Object.CashCurrency),
		Object.CashCurrency,
		GetPettyCashAccountingCurrencyAtServer(PettyCash)
	);
	
EndProcedure

// Procedure receives the default petty cash currency.
//
&AtServerNoContext
Function GetPettyCashAccountingCurrencyAtServer(PettyCash)
	
	Return PettyCash.CurrencyByDefault;
	
EndFunction

// Procedure - handler of clicking the button "Fill in by basis".
//
&AtClient
Procedure FillByBasis(Command)
	
	If Not ValueIsFilled(Object.BasisDocument) Then
		ShowMessageBox(Undefined,NStr("en = 'Please select a base document.'"));
		Return;
	EndIf;
	
	If TypeOf(Object.BasisDocument) = Type("DocumentRef.CashTransferPlan")
		AND Not DocumentApproved(Object.BasisDocument) Then
		Raise NStr("en = 'Please select an approved cash transfer plan.'");
	EndIf;
	
	Response = Undefined;
	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the cash transfer?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
	
	Response = Result;
	If Response = DialogReturnCode.Yes Then
		
		FillByDocument(Object.BasisDocument);
		
	EndIf;
	
EndProcedure

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Fill(BasisDocument);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
	If Not ValueIsFilled(Object.Ref) Then
		Query = New Query(
		"SELECT
		|	CASE
		|		WHEN Companies.BankAccountByDefault.CashCurrency = &CashCurrency
		|			THEN Companies.BankAccountByDefault
		|		ELSE UNDEFINED
		|	END AS BankAccount
		|FROM
		|	Catalog.Companies AS Companies
		|WHERE
		|	Companies.Ref = &Company");
		Query.SetParameter("Company", Object.Company);
		Query.SetParameter("CashCurrency", Object.CashCurrency);
		QueryResult = Query.Execute();
		Selection = QueryResult.Select();
		If Selection.Next() Then
			If Not ValueIsFilled(Object.BankAccount) Then
				Object.BankAccount = Selection.BankAccount;
			EndIf;
		EndIf;
		If Not ValueIsFilled(Object.BankAccountPayee) Then
			Object.BankAccountPayee = Object.BankAccount;
		EndIf;
		If Not ValueIsFilled(Object.PettyCash) Then
			Object.PettyCash = Catalogs.CashAccounts.GetPettyCashByDefault(Object.Company);
		EndIf;
		If Not ValueIsFilled(Object.PettyCashPayee) Then
			Object.PettyCashPayee = Object.PettyCash;
		EndIf;
	EndIf;
	
	Currency = Object.CashCurrency;
	
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	SetCurrentPage();
	SetRecipientCurrentPage();
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion

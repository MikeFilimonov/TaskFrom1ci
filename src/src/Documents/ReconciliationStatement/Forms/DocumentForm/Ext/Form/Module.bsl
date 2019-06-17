
#Region ServiceProceduresAndFunctions

&AtClient
// Procedure fills in the description of payment document in the tabular field string
//
Procedure FillInPaymentDocumentDescription(DataCurrentRows, ThisCompanyData)
	
	If DataCurrentRows <> Undefined Then
		
		StringDataStructure = New Structure;
		StringDataStructure.Insert("Contract", DataCurrentRows.Contract);
		StringDataStructure.Insert("AccountingDocument", DataCurrentRows.AccountingDocument);
		If ThisCompanyData Then
			
			StringDataStructure.Insert("DocumentNumber", DataCurrentRows.DocumentNumber);
			StringDataStructure.Insert("DocumentDate", DataCurrentRows.DocumentDate);
			
			// If you add it manually, consider that inc. number and data were specified by a user
			CompanyAccountingDocumentDescription(StringDataStructure);
			DataCurrentRows.ContractCurrency = ?(StringDataStructure.Property("DocumentCurrency"), StringDataStructure.DocumentCurrency, Object.DocumentCurrency);
			
		Else
			
			StringDataStructure.Insert("IncomingDocumentNumber", DataCurrentRows.IncomingDocumentNumber);
			StringDataStructure.Insert("IncomingDocumentDate", DataCurrentRows.IncomingDocumentDate);
			
			// If you add it manually, consider that inc. number and data were specified by a user
			CounterpartyAccountingDocumentDescription(StringDataStructure);
			DataCurrentRows.DocumentCurrency = ?(StringDataStructure.Property("DocumentCurrency"), StringDataStructure.DocumentCurrency, Object.DocumentCurrency);
			
		EndIf;
		
		DataCurrentRows.DocumentDescription = StringDataStructure.DocumentDescription;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure clears document tabular sections
//
Procedure ClearDocumentData()
	
	Object.BalanceBeginPeriod = 0;
	Object.CompanyData.Clear();
	Object.CounterpartyData.Clear();
	
EndProcedure

&AtClient
// The procedure fills in the ContractsSelectionDescription field title.
//
Procedure FillTitleBySelectedCatalogs()
	
	ArrayMarked = Object.CounterpartyContracts.FindRows(New Structure("Select", True));
	If Object.CounterpartyContracts.Count() = 0 Then
		
		LabelText = NStr("en = 'Contract list is empty'");
		
	ElsIf ArrayMarked.Count() = 1 Then
		
		LabelText = String(ArrayMarked[0].Contract);
		
	ElsIf ArrayMarked.Count() = 0 Then
		
		LabelText = NStr("en = 'Contracts are not selected'");
		
	Else
		
		LabelText = String(ArrayMarked[0].Contract) + ", " + String(ArrayMarked[1].Contract) + ?(ArrayMarked.Count() > 2, "...", "");
		
	EndIf;
	
	Object.DescriptionContractsSelection = LabelText;
	
EndProcedure

&AtClient
// The procedure of the "Company data" tabular section filling by the accounting data
//
Procedure FillByBalance()
	
	CalculateInitialBalance();
	FillByBalancesServer();
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// The procedure of the "Counterparty data" tabular section filling by the accounting data
//
Procedure FillCounterpartyInformationByCompanyData()
	
	FillByCompanyDataAtServer();
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// The procedure prepares the contracts array according to which an initial balance is calculated
//
Procedure CalculateInitialBalance()
	
	ContractsArray = New Array;
	For Each StringContract In Object.CounterpartyContracts Do
		
		If StringContract.Select Then
			
			ContractsArray.Add(StringContract.Contract);
			
		EndIf;
		
	EndDo;
	
	PrimaryBalanceByContracts(Object.Company, Object.BeginOfPeriod, ContractsArray, Object.DocumentCurrency, Object.BalanceBeginPeriod);
	
EndProcedure

&AtServer
// Calls the procedure of filling the counterparty empty dates on server
//
Procedure FillInDateInCounterpartyArisingFromSettlementDocuments()
	
	For Each DataRow In Object.CounterpartyData Do
		
		If ValueIsFilled(DataRow.IncomingDocumentDate) 
			OR Not ValueIsFilled(DataRow.AccountingDocument) Then
			
			Continue;
			
		EndIf;
		
		DataRow.IncomingDocumentDate	= DataRow.AccountingDocument.Date;
		DataRow.DocumentDescription		= Documents.ReconciliationStatement.CounterpartyAccountingDocumentDescription(
			DataRow.AccountingDocument,
			DataRow.IncomingDocumentNumber,
			DataRow.IncomingDocumentDate);
		
	EndDo;
	
EndProcedure

&AtServer
// The procedure generates structure with the document data
//
Function GetDocumentData(DocumentRef = Undefined)
	
	DocumentData = New Structure;
	DocumentData.Insert("Date",					Object.Date);
	DocumentData.Insert("BeginOfPeriod",			Object.BeginOfPeriod);
	DocumentData.Insert("EndOfPeriod", 			Object.EndOfPeriod);
	DocumentData.Insert("Company",				DriveServer.GetCompany(Object.Company));
	DocumentData.Insert("Ref",					DocumentRef);
	DocumentData.Insert("SortByContracts",	Object.SortByContracts);
	DocumentData.Insert("DocumentCurrency",			Object.DocumentCurrency);
	DocumentData.Insert("CompanyToPresentation",Object.AddCompanyInDocumentPresentation);
	
	RowArray = Object.CounterpartyContracts.FindRows(New Structure("Select", True));
	DocumentData.Insert("CounterpartyContracts",	Object.CounterpartyContracts.Unload(RowArray));
	
	Return DocumentData;
	
EndFunction

&AtServer
// The procedure of the "Company data" tabular section filling
//
Procedure FillByBalancesServer()
	
	Documents.ReconciliationStatement.FillDataByCompany(GetDocumentData(), Object.CompanyData);
	
EndProcedure

&AtServer
// The procedure of the "Counterparty data" tabular section filling by the accounting data
//
Procedure FillByCompanyDataAtServer()
	
	Documents.ReconciliationStatement.FillCounterpartyInformationByCompanyData(Object.CompanyData, Object.CounterpartyData, Object.AddCompanyInDocumentPresentation);
	
EndProcedure

&AtServerNoContext
// Fills in the description of the payment document and the contract currency in the CompanyData tabular section
//
// Parameters:
//    DocumentRef - DocumentRef - Ref to accounting document;
//    DocumentDescription - String - Variable to which the payment document description will be passed;
//    SettlementsCurrency - CatalogRef.Currencies - Variable to which the contract currency value will be passed
//
Function CompanyAccountingDocumentDescription(StringDataStructure)
	
	DocumentDescription = 
		Documents.ReconciliationStatement.CompanyAccountingDocumentDescription(StringDataStructure.AccountingDocument, StringDataStructure.DocumentNumber, StringDataStructure.DocumentDate);
	
	StringDataStructure.Insert("DocumentDescription", DocumentDescription);
	
	If ValueIsFilled(StringDataStructure.Contract) Then
		
		StringDataStructure.Insert("DocumentCurrency", StringDataStructure.Contract.SettlementsCurrency);
		
	EndIf;
	
EndFunction

&AtServerNoContext
// Fills in the payment document description and the contract currency in the CounterpartyData tabular section
//
// Parameters:
//    DocumentRef - DocumentRef - Ref to accounting document;
//    DocumentDescription - String - Variable to which the payment document description will be passed;
//    SettlementsCurrency - CatalogRef.Currencies - Variable to which the contract currency value will be passed
//
Function CounterpartyAccountingDocumentDescription(StringDataStructure)
	
	DocumentDescription = 
		Documents.ReconciliationStatement.CounterpartyAccountingDocumentDescription(StringDataStructure.AccountingDocument, StringDataStructure.IncomingDocumentNumber, StringDataStructure.IncomingDocumentDate);
	
	StringDataStructure.Insert("DocumentDescription", DocumentDescription);
	
	If ValueIsFilled(StringDataStructure.Contract) Then
		
		StringDataStructure.Insert("DocumentCurrency", StringDataStructure.Contract.SettlementsCurrency);
		
	EndIf;
	
EndFunction

&AtServerNoContext
// The procedure calculates the initial balance by the specified counterparty contracts
//
// Company (Object.Company) - company according to which the
// initial balance is calculated CounterpartyContracts (Object.CounterpartyContracts) - document tabular section
//
Procedure PrimaryBalanceByContracts(Company, Val BeginOfPeriod, CounterpartyContracts, DocumentCurrency, BalanceBeginPeriod)
	
	If Not ValueIsFilled(BeginOfPeriod) Then
		
		BeginOfPeriod = Date(1980, 01, 01);
		
	EndIf;
	
	BalanceBeginPeriod = 0;
	
	Query = New Query;
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("BeginOfPeriod", BeginOfPeriod);
	Query.SetParameter("CounterpartyContracts", CounterpartyContracts);
	
	Query.Text = 
	"SELECT
	|	CounterpartyContracts.Ref AS Contract
	|INTO CounterpartyContracts
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Ref IN(&CounterpartyContracts)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CASE
	|		WHEN AccountsPayableBalances.AmountCurBalance > 0
	|				AND AccountsReceivableBalances.AmountCurBalance < 0
	|			THEN -1 * AccountsReceivableBalances.AmountCurBalance + AccountsPayableBalances.AmountCurBalance
	|		WHEN AccountsPayableBalances.AmountCurBalance > 0
	|			THEN AccountsPayableBalances.AmountCurBalance
	|		WHEN AccountsReceivableBalances.AmountCurBalance < 0
	|			THEN -AccountsReceivableBalances.AmountCurBalance
	|		ELSE 0
	|	END - CASE
	|		WHEN AccountsPayableBalances.AmountCurBalance < 0
	|				AND AccountsReceivableBalances.AmountCurBalance > 0
	|			THEN -1 * AccountsPayableBalances.AmountCurBalance + AccountsReceivableBalances.AmountCurBalance
	|		WHEN AccountsPayableBalances.AmountCurBalance < 0
	|			THEN -AccountsPayableBalances.AmountCurBalance
	|		WHEN AccountsReceivableBalances.AmountCurBalance > 0
	|			THEN AccountsReceivableBalances.AmountCurBalance
	|		ELSE 0
	|	END AS Balance,
	|	CounterpartyContracts.Contract.SettlementsCurrency AS SettlementCurrencies
	|FROM
	|	CounterpartyContracts AS CounterpartyContracts
	|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(&BeginOfPeriod, Company = &Company) AS AccountsReceivableBalances
	|		ON CounterpartyContracts.Contract = AccountsReceivableBalances.Contract
	|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(&BeginOfPeriod, Company = &Company) AS AccountsPayableBalances
	|		ON CounterpartyContracts.Contract = AccountsPayableBalances.Contract";
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do 
		
		BalanceByContract = 0;
		
		If Selection.SettlementCurrencies <> DocumentCurrency Then
			
			SettlementsCurrencyRate = WorkWithExchangeRates.GetCurrencyRate(Selection.SettlementCurrencies, BeginOfPeriod);
			DocumentCurrencyRate = WorkWithExchangeRates.GetCurrencyRate(DocumentCurrency, BeginOfPeriod);
			
			If Selection.Balance <> 0 Then
				
				BalanceByContract = WorkWithExchangeRatesClientServer.RecalculateFromCurrencyToCurrency(Selection.Balance, Selection.SettlementCurrencies, DocumentCurrency, SettlementsCurrencyRate.ExchangeRate, DocumentCurrencyRate.ExchangeRate, SettlementsCurrencyRate.Multiplicity, DocumentCurrencyRate.Multiplicity);
				
			EndIf;
			
		Else
			
			BalanceByContract = Selection.Balance;
			
		EndIf;
		
		BalanceBeginPeriod = BalanceBeginPeriod + BalanceByContract;
		
	EndDo;
	
EndProcedure

&AtServer
// Sets the form items availability depending on the document status
//
Procedure SetEnabledOfItems()
	
	// Attributes are available only for the Created status
	CreatedStatus = (Object.Status = Enums.ReconciliationStatementStatus.Created);
	
	CommonUseClientServer.SetFormItemProperty(Items, "Company", "Enabled", CreatedStatus);
	CommonUseClientServer.SetFormItemProperty(Items, "PeriodGroupMatching", "Enabled", CreatedStatus);
	CommonUseClientServer.SetFormItemProperty(Items, "DocumentCurrency", "Enabled", CreatedStatus);
	CommonUseClientServer.SetFormItemProperty(Items, "Counterparty", "Enabled", CreatedStatus);
	CommonUseClientServer.SetFormItemProperty(Items, "Group1", "Enabled", CreatedStatus);
	CommonUseClientServer.SetFormItemProperty(Items, "FillAccordingToAccounting", "Enabled", CreatedStatus);
	
	// Attributes are available for the Created and OnServer statuses
	StatusVerified = (Object.Status = Enums.ReconciliationStatementStatus.Verified);
	
	CommonUseClientServer.SetFormItemProperty(Items, "GroupBalanceCurrency", "Enabled", Not StatusVerified);
	CommonUseClientServer.SetFormItemProperty(Items, "CounterpartyDataFillByAccountingDocumentsDates", "Enabled", Not StatusVerified);
	CommonUseClientServer.SetFormItemProperty(Items, "FillAccordingToCompanies", "Enabled", Not StatusVerified);
	CommonUseClientServer.SetFormItemProperty(Items, "CounterpartyHeadNameAndSurname", "Enabled", Not StatusVerified);
	
	// Tabular sections are not included in the general rule.
	// To copy presentations, always leave them as available but do not allow editing (manage the property ViewOnly)
	CommonUseClientServer.SetFormItemProperty(Items, "CompanyData",	"ReadOnly", Not CreatedStatus);
	CommonUseClientServer.SetFormItemProperty(Items, "Documents", "ReadOnly", StatusVerified);
	
EndProcedure

&AtServer
// The procedure of receiving counterparty data
//
Procedure GetCounterpartyData(CounterpartyData)
	
	CounterpartyData = New Structure("ContactPerson");
	
	// If the counterparty is changed, refill the contracts
	FillData = True;
	If Object.CounterpartyContracts.Count() > 0 Then
		
		If Object.CounterpartyContracts[0].Contract.Owner = Object.Counterparty Then
			
			FillData = False;
			
		Else
			
			Object.CounterpartyContracts.Clear();
			Object.CompanyData.Clear();
			Object.CounterpartyData.Clear();
			
		EndIf;
		
	EndIf;
	
	CounterpartyData.Insert("DoOperationsByContracts", Object.Counterparty.DoOperationsByContracts);
	CommonUseClientServer.SetFormItemProperty(Items, "DescriptionContractsSelection", "Enabled", Object.Counterparty.DoOperationsByContracts);
	
	If FillData Then
		
		Query = New Query;
		Query.SetParameter("Counterparty", Object.Counterparty);
		Query.Text = 
		"SELECT
		|	True AS Select,
		|	CatalogCounterpartyContracts.Ref AS Contract,
		|	CatalogCounterpartyContracts.SettlementsCurrency AS ContractCurrency
		|FROM
		|	Catalog.CounterpartyContracts AS CatalogCounterpartyContracts
		|WHERE
		|	CatalogCounterpartyContracts.Owner = &Counterparty";
		
		Object.CounterpartyContracts.Load(Query.Execute().Unload());
		Object.DescriptionContractsSelection = NStr("en = 'All counterparty contracts are selected'");
		
		ContactPersonsList = DriveServer.GetCounterpartyContactPersons(Object.Counterparty);
		If ContactPersonsList.Count() > 0 Then
			
			CounterpartyData.ContactPerson = ContactPersonsList[0].Value;
			
		EndIf;
		
		CounterpartyContracts = Object.CounterpartyContracts.Unload(,"Contract");
		PrimaryBalanceByContracts(Object.Company, Object.BeginOfPeriod, CounterpartyContracts, Object.DocumentCurrency, Object.BalanceBeginPeriod);
		
	EndIf;
	
EndProcedure

&AtServerNoContext
// The procedure of the received catalog data It is called after selecting a contract
// 
Procedure GetContractData(ContractData, Contract)
	
	ContractData.Insert("ContractCurrency", Contract.SettlementsCurrency);
	
EndProcedure

#EndRegion

#Region FormEventsHandlers

&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues
	);
	
	SetEnabledOfItems();
	
	If Not ValueIsFilled(Object.DocumentCurrency) Then
		
		Object.DocumentCurrency = Constants.FunctionalCurrency.Get();
		
	EndIf;
	
	AccountingBySubsidiaryCompany = Constants.AccountingBySubsidiaryCompany.Get();
	If AccountingBySubsidiaryCompany Then
		
		// If you keep records on the company as a whole, it is required to delete the connection of selection by company
		LinkSelectParameters = New ChoiceParameterLink("Filter.Counterparty", "Object.Counterparty");
		NewArray = New Array;
		NewArray.Add(LinkSelectParameters);
		
		Items.CompanyDataAccountDocument.ChoiceParameterLinks = New FixedArray(NewArray);
		Items.CounterpartyDataCurrentDocument.ChoiceParameterLinks = New FixedArray(NewArray);
		
		If Not ValueIsFilled(Object.Company) Then
			
			Object.Company = Constants.ParentCompany.Get();
			
		EndIf;
		
	EndIf;
	
	DoOperationsByContracts = ?(ValueIsFilled(Object.Counterparty), Object.Counterparty.DoOperationsByContracts, False);
	CommonUseClientServer.SetFormItemProperty(Items, "DescriptionContractsSelection", "Enabled", DoOperationsByContracts);
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
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

&AtClient
// "OnOpen" event handler procedure of the document form
//
Procedure OnOpen(Cancel)
	
	If Not Object.Ref = Undefined Then
		
		CalculateSummaryDataDiscrepancy();
		
	EndIf;
	
	FillTitleBySelectedCatalogs();
	
EndProcedure

&AtClient
// "BeforeClosing" event handler procedure of the document form
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	// StandardSubsystems.FileOperations
	FileOperationsClient.ShowFormClosingConfirmationWithFiles(ThisObject, Cancel, Exit, Object.Ref);
	// End StandardSubsystems.FileOperations
	
EndProcedure

#EndRegion

#Region FormItemEventsHandlers

&AtClient
// Procedure - OnChange event handler of the "DocumentCurrency" attribute
//
Procedure DocumentCurrencyOnChange(Item)
	
	ClearDocumentData();
	FillByBalance();
	
	//
	// Do not fill in counterparty data automatically as TS could have been filled in manually.
	//
	
EndProcedure

&AtClient
// Procedure - "Opening" event handler of the "CompanyDataDocumentDescription" field.
//
Procedure CompanyDataDetailsDocumentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	DataCurrentRows = Items.CompanyData.CurrentData;
	If Not DataCurrentRows = Undefined Then
		
		If ValueIsFilled(DataCurrentRows.AccountingDocument) Then
			
			ShowValue(, DataCurrentRows.AccountingDocument);
			
		Else
			
			MessageText = NStr("en = 'The string is not bound to the payment document. 
			                   |To bind it, it is required to enable the visible of the corresponding column and specify a document.'");
				
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - "Opening" event handler of the "CounterpartyDataDocumentDescription" field.
//
Procedure CounterpartyDataDetailsDocumentOpen(Item, StandardProcessing)
	
	StandardProcessing = False;
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	
	If Not DataCurrentRows = Undefined Then
		
		If ValueIsFilled(DataCurrentRows.AccountingDocument) Then
			
			ShowValue(, DataCurrentRows.AccountingDocument);
			
		Else
			
			MessageText = NStr("en = 'The string is not bound to the payment document. 
			                   |To bind it, it is required to enable the visible of the corresponding column and specify a document.'");
				
			CommonUseClientServer.MessageToUser(MessageText);
			
		EndIf;
		
	EndIf;

EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "CompanyDataContract" field.
//
Procedure CompanyDataContractOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	
	If DataCurrentRows <> Undefined 
		AND ValueIsFilled(DataCurrentRows.Contract) Then
		
		ContractData = New Structure;
		GetContractData(ContractData, DataCurrentRows.Contract);
		DataCurrentRows.ContractCurrency = ContractData.ContractCurrency;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "Status" field.
//
Procedure StatusOnChange(Item)
	
	SetEnabledOfItems()
	
EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "PaymentDocument" field of the "CounterpartyData" table.
//
Procedure CounterpartyDataAccountingDocumentOnChange(Item)
	
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, False);
	
EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "Contract" field of the "CounterpartyData" table.
//
Procedure CounterpartyDataContractOnChange(Item)
	
	CurrentData = Items.CounterpartyData.CurrentData;
	If CurrentData <> Undefined Then
		
		RowData = New Structure;
		RowData.Insert("Contract", CurrentData.Contract);
		RowData.Insert("AccountingDocument", CurrentData.AccountingDocument);
		RowData.Insert("IncomingDocumentNumber", CurrentData.IncomingDocumentNumber);
		RowData.Insert("IncomingDocumentDate", CurrentData.IncomingDocumentDate);
		
		// During manual adding, assume that inc. number and data were specified by a user
		CounterpartyAccountingDocumentDescription(RowData);
		
		CurrentData.DocumentCurrency = RowData.DocumentCurrency;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ByCounterpartyData tabular section.
//
Procedure CounterpartyDataOnChange(Item)
	
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// Procedure - "OnChange" event handler of the "PaymentDocument" field of the "CompanyData" table.
//
Procedure CompanyDataAccountingDocumentOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, True);
	
EndProcedure

&AtClient
// Procedure - event handler  of the reconciliation status change
//
Procedure StatusChoiceProcessing(Item, ValueSelected, StandardProcessing)
	Var Errors, Cancel;
	
	If ValueSelected = PredefinedValue("Enum.ReconciliationStatementStatus.Verified") Then
		
		If Not ValueIsFilled(Object.Responsible) Then
			
			MessageText = NStr("en = 'Company responsible person is filled in incorrectly.'");
			CommonUseClientServer.AddUserError(Errors, "Object.Responsible", MessageText, Undefined);
			
		EndIf;
		
		If Not ValueIsFilled(Object.CounterpartyRepresentative) Then
			
			MessageText = NStr("en = 'Counterparty representative is filled in incorrectly.'");
			CommonUseClientServer.AddUserError(Errors, "Object.CounterpartyRepresentative", MessageText, Undefined);
			
		EndIf;
		
	EndIf;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the counterparty field
//
Procedure CounterpartyOnChange(Item)
	Var CounterpartyData;
	
	ClearDocumentData();
	
	If ValueIsFilled(Object.Counterparty) Then
		
		GetCounterpartyData(CounterpartyData);
		Object.CounterpartyRepresentative = CounterpartyData.ContactPerson;
		DoOperationsByContracts = CounterpartyData.DoOperationsByContracts;
		
	Else
		
		Object.CounterpartyContracts.Clear();
		Object.DescriptionContractsSelection = NStr("en = 'Contract list is empty'");
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ByCompanyData tabular section.
//
Procedure CompanyDataOnChange(Item)
	
	CalculateSummaryDataDiscrepancy();
	
EndProcedure

&AtClient
// Procedure - event handler Attribute click ContractsSelectionDescription
//
Procedure ContractsSelectionDescriptionClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	DocumentParameters = New Structure;
	DocumentParameters.Insert("Company", Object.Company);
	DocumentParameters.Insert("Counterparty", Object.Counterparty);
	DocumentParameters.Insert("CounterpartyContracts", Object.CounterpartyContracts);
	
	NotifyDescription = New NotifyDescription("AfterSelectingCounterpartyContracts", ThisObject);
	
	OpenForm("Document.ReconciliationStatement.Form.CounterpartyContractsForm", DocumentParameters, ThisForm, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the Company attribute
//
Procedure CompanyOnChange(Item)
	
	ClearDocumentData();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the PeriodStart attribute
//
Procedure BeginOfPeriodOnChange(Item)
	
	ClearDocumentData();
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the PeriodStart attribute
//
Procedure EndOfPeriodOnChange(Item)
	
	ClearDocumentData();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

&AtClient
Procedure CounterpartyDataIncDateOnChange(Item)
	
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, False);
	
EndProcedure

&AtClient
Procedure CounterpartyDataIncNumberOnChange(Item)
	
	DataCurrentRows = Items.CounterpartyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, False);
	
EndProcedure

&AtClient
Procedure CompanyDataDocumentDateOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, True);
	
EndProcedure

&AtClient
Procedure CompanyDataDocumentNumberOnChange(Item)
	
	DataCurrentRows = Items.CompanyData.CurrentData;
	FillInPaymentDocumentDescription(DataCurrentRows, True);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
// Calls the initialization procedure of the empty incoming dates with the payment document dates
//
Procedure FillByAccountingDocumentsDates(Command)
	
	If Object.CounterpartyData.Count() < 1 Then
		
		MessageText = NStr("en = 'Tabular section of counterparty reconciliation data is empty.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	FillInDateInCounterpartyArisingFromSettlementDocuments();
	
EndProcedure

&AtClient
// Procedure - "FillInByBalanceCommand" command handler.
//
Procedure FillAccordingToAccounting(Command)
	
	CallProcedureToFillTableParts = True;
	
	If Not ValueIsFilled(Object.EndOfPeriod) Then
		
		MessageText	= NStr("en = 'The period end date is filled in incorrectly.'");
		MessageField	= "Object.EndOfPeriod";
		
		CommonUseClientServer.MessageToUser(MessageText, , MessageField);
		
		CallProcedureToFillTableParts = False;
		
	EndIf;
	
	
	If CallProcedureToFillTableParts Then
		
		If Object.CompanyData.Count() > 0 Then
			
			QuestionText	= NStr("en = 'Tabular section will be cleared and filled in again. Continue?'");
			NotifyDescription = New NotifyDescription("HandlerAfterQuestionAboutCleaning", ThisObject, "CompanyData");
			ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			FillByBalance();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure fills in the Counterparty data tabular field by the company data
//
//
Procedure TransferFromCompanyData(Command)
	
	If Object.CompanyData.Count() < 1 Then
		
		MessageText = NStr("en = 'Tabular section with company data is not filled in.'");
		CommonUseClientServer.MessageToUser(MessageText);
		Return;
		
	EndIf;
	
	If Object.CounterpartyData.Count() > 0 Then
		
		QuestionText	= NStr("en = 'Tabular section will be cleared and filled in again. Continue?'");
		NotifyDescription = New NotifyDescription("HandlerAfterQuestionAboutCleaning", ThisObject, "CounterpartyData");
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.YesNo, 0);
		
	Else
		
		FillCounterpartyInformationByCompanyData();
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure calculates the data variance and fills in the required attributes
//
Procedure CalculateSummaryDataDiscrepancy()
	
	BalanceByCompanyData	= Object.CompanyData.Total("ClientDebtAmount") - Object.CompanyData.Total("CompanyDebtAmount");
	BalanceByCounterpartyData	= Object.CounterpartyData.Total("CompanyDebtAmount") - Object.CounterpartyData.Total("ClientDebtAmount");
	
	Discrepancy					= BalanceByCompanyData - BalanceByCounterpartyData;
	
EndProcedure

&AtClient
// Procedure - command handler "SetInterval".
//
Procedure SetInterval(Command)
	
	Dialog = New StandardPeriodEditDialog();
	Dialog.Period.StartDate = Object.BeginOfPeriod;
	Dialog.Period.EndDate = Object.EndOfPeriod;
	
	NotifyDescription = New NotifyDescription("AfterSelectingFillingPeriod", ThisObject);
	Dialog.Show(NotifyDescription);
	
EndProcedure

&AtClient
// Procedure - CalculateInitialBalance command handler
//
Procedure InitialBalance(Command)
	
	CalculateInitialBalance();
	
EndProcedure

#EndRegion

#Region InteractiveActionResultHandlers

&AtClient
// The procedure processes the result of question on TS clearing 
//
Procedure HandlerAfterQuestionAboutCleaning(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult = DialogReturnCode.Yes Then
		
		If AdditionalParameters = "CompanyData" Then
			
			FillByBalance();
			
		ElsIf AdditionalParameters = "CounterpartyData" Then
			
			FillCounterpartyInformationByCompanyData()
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure processes the counterparty contracts selection result
//
Procedure AfterSelectingCounterpartyContracts(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult <> Undefined Then
		
		HasChanges = False;
		HasChanges = Not (ClosingResult.CounterpartyContracts.Count() = Object.CounterpartyContracts.Count());
		If Not HasChanges Then
			
			ListSize = ClosingResult.CounterpartyContracts.Count();
			While ListSize > 0 Do
				
				ItemIndex = ListSize - 1;
				If ClosingResult.CounterpartyContracts[ItemIndex].Contract <> Object.CounterpartyContracts[ItemIndex].Contract 
					OR ClosingResult.CounterpartyContracts[ItemIndex].Select <> Object.CounterpartyContracts[ItemIndex].Select Then
					
					HasChanges = True;
					Break;
					
				EndIf;
				
				ListSize = ListSize - 1;
				
			EndDo;
			
		EndIf;
		
		If HasChanges Then
			
			Object.CounterpartyContracts.Clear();
			Object.CompanyData.Clear();
			Object.CounterpartyData.Clear();
			
			For Each CollectionItem In ClosingResult.CounterpartyContracts Do
				
				NewRow = Object.CounterpartyContracts.Add();
				FillPropertyValues(NewRow, CollectionItem);
				
			EndDo;
			
			FillTitleBySelectedCatalogs();
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// The procedure processes the period selection result of the current document filling
//
Procedure AfterSelectingFillingPeriod(ClosingResult, AdditionalParameters) Export
	
	If ClosingResult <> Undefined Then
		
		ClearDocumentData();
		If Object.BeginOfPeriod <> ClosingResult.StartDate Then
			
			Object.BeginOfPeriod = ClosingResult.StartDate;
			CalculateInitialBalance();
			
		EndIf;
		
		Object.EndOfPeriod = ClosingResult.EndDate;
		
	EndIf;
	
EndProcedure

#EndRegion

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

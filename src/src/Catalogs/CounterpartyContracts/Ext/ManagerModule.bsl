#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Function returns the list of the "key" attributes names.
//
Function GetObjectAttributesBeingLocked() Export
	
	Result = New Array;
	Result.Add("Owner");
	Result.Add("SettlementsCurrency");
	
	Return Result;
	
EndFunction

// Receives the counterparty contract by default according to the filter conditions. Default or the only contract
// returns or an empty reference.
//
// Parameters
//  Counterparty	-	<CatalogRef.Counterparty> 
// 						counterparty, contract of which
//  is	needed	to 
// 						get Company - <CatalogRef.Companies> Company,
//  contract	of	which is needed to get ContractKindsList - <Array> 
// 						or <ValuesList> consisting values of the type <EnumRef.ContractType> Desired contract kinds
//
// Returns:
//   <CatalogRef.CounterpartyContracts> - found contract or empty ref
//
Function GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractKindsList = Undefined) Export
	
	CounterpartyMainContract = Counterparty.ContractByDefault;
	
	If ContractKindsList = Undefined
		OR (ContractKindsList.FindByValue(CounterpartyMainContract.ContractKind) <> Undefined
		AND CounterpartyMainContract.Company = Company) Then
		
		Return CounterpartyMainContract;
	EndIf;
	
	Query = New Query;
	QueryText = 
	"SELECT ALLOWED
	|	CounterpartyContracts.Ref
	|FROM
	|	Catalog.CounterpartyContracts AS CounterpartyContracts
	|WHERE
	|	CounterpartyContracts.Owner = &Counterparty
	|	AND CounterpartyContracts.Company = &Company
	|	AND CounterpartyContracts.DeletionMark = FALSE"
	+?(ContractKindsList <> Undefined,"
	|	And CounterpartyContracts.ContractKind IN (&ContractKindsList)","");
	
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Company", Company);
	Query.SetParameter("ContractKindsList", ContractKindsList);
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Result.IsEmpty() Then
		Return Catalogs.CounterpartyContracts.EmptyRef();
	EndIf;
	
	Selection = Result.Select();
	
	Selection.Next();
	Return Selection.Ref;

EndFunction

// Checks the counterparty contract on the map to passed parameters.
//
// Parameters
// MessageText - <String> - error message
// about	errors	Contract - <CatalogRef.CounterpartyContracts> - checked
// contract	Company	- <CatalogRef.Company> - company
// document	Counterparty	- <CatalogRef.Counterparty> - document
// counterparty	ContractKindsList	- <ValuesList> consisting values of the type <EnumRef.ContractType>. 
// 						Desired contract kinds.
//
// Returns:
// <Boolean> -True if checking is completed successfully.
//
Function ContractMeetsDocumentTerms(MessageText, Contract, Company, Counterparty, ContractKindsList) Export
	
	MessageText = "";
	
	If Not Counterparty.DoOperationsByContracts Then
		Return True;
	EndIf;
	
	DoesNotMatchCompany = False;
	DoesNotMatchContractKind = False;
	
	If Contract.Company <> Company Then
		DoesNotMatchCompany = True;
	EndIf;
		
	If ContractKindsList.FindByValue(Contract.ContractKind) = Undefined Then
		DoesNotMatchContractKind = True;
	EndIf;
	
	If (DoesNotMatchCompany OR DoesNotMatchContractKind) = False Then
		Return True;
	EndIf;
	
	MessageText = NStr("en = 'The following contract fields do not match the document fields:'");
	
	If DoesNotMatchCompany Then
		MessageText = MessageText + "
									|- " + NStr("en = 'Company'");
	EndIf;
	
	If DoesNotMatchContractKind Then
		MessageText = MessageText + "
									|- " + NStr("en = 'Counterparty role'");
	EndIf;
	
	Return False;
	
EndFunction

// Returns a list of available contract kinds for the document.
//
// Parameters
// Document  - any document providing counterparty
// contract OperationKind  - document operation kind.
//
// Returns:
// <ValuesList>   - list of contract kinds which are available for the document.
//
Function GetContractKindsListForDocument(Document, OperationKind = Undefined, TabularSectionName = "") Export
	
	ContractKindsList = New ValueList;
	
	If TypeOf(Document) = Type("DocumentRef.OpeningBalanceEntry") Then
		
		If TabularSectionName = "AccountsPayable" Then
			
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			
		ElsIf TabularSectionName = "AccountsReceivable" Then
			
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.ArApAdjustments") Then
		
		If TabularSectionName = "Debitor" Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
		ElsIf TabularSectionName = "Creditor" Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		Else
			If OperationKind = Enums.OperationTypesArApAdjustments.CustomerDebtAssignment Then
				ContractKindsList.Add(Enums.ContractType.WithCustomer);
				ContractKindsList.Add(Enums.ContractType.WithAgent);
			Else
				ContractKindsList.Add(Enums.ContractType.WithVendor);
				ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.LetterOfAuthority") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AdditionalExpenses") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SalesOrder") Then
		
		If OperationKind = Enums.OperationTypesSalesOrder.OrderForSale Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.WorkOrder") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.PurchaseOrder") Then
		
		If OperationKind = Enums.OperationTypesPurchaseOrder.OrderForPurchase Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AccountSalesFromConsignee") Then
		
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.AccountSalesToConsignor") Then
		
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SubcontractorReportIssued") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SubcontractorReport") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CashReceipt") 
		OR TypeOf(Document) = Type("DocumentRef.PaymentReceipt") Then
		
		If OperationKind = Enums.OperationTypesCashReceipt.FromVendor
			OR OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierInvoice") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.GoodsReceipt") Then
		
		If OperationKind = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		Else
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CashVoucher")
		OR TypeOf(Document) = Type("DocumentRef.PaymentExpense") Then
		
		If OperationKind = Enums.OperationTypesCashVoucher.Vendor 
			OR OperationKind = Enums.OperationTypesPaymentExpense.Vendor Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
			ContractKindsList.Add(Enums.ContractType.WithAgent);
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SalesInvoice")
		OR TypeOf(Document) = Type("DocumentRef.GoodsIssue") Then
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.GoodsIssue") Then

		If OperationKind = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
			ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		ElsIf OperationKind = Enums.OperationTypesGoodsIssue.TransferToAThirdParty Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
			ContractKindsList.Add(Enums.ContractType.WithAgent)
		Else
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.Quote") Then
		
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.SupplierQuote") Then
		
		ContractKindsList.Add(Enums.ContractType.WithVendor);
		ContractKindsList.Add(Enums.ContractType.WithAgent);
		ContractKindsList.Add(Enums.ContractType.FromPrincipal);
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CreditNote") Then
		ContractKindsList.Add(Enums.ContractType.WithCustomer);
	ElsIf TypeOf(Document) = Type("DocumentRef.DebitNote") Then
		ContractKindsList.Add(Enums.ContractType.WithVendor);
	ElsIf TypeOf(Document) = Type("DocumentRef.GoodsReturn") Then
		
		If OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer Then
			ContractKindsList.Add(Enums.ContractType.WithCustomer);
		ElsIf OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier Then
			ContractKindsList.Add(Enums.ContractType.WithVendor);
		EndIf;
		
	ElsIf TypeOf(Document) = Type("DocumentRef.CustomsDeclaration") Then
		
		ContractKindsList.Add(Enums.ContractType.Other);
		
	EndIf;
	
	Return ContractKindsList;
	
EndFunction

#Region PrintInterface

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Contract
	PrintCommand = PrintCommands.Add();
	PrintCommand.Handler		= "DriveClient.PrintCounterpartyContract";
	PrintCommand.ID				= "ContractForm";
	PrintCommand.Presentation	= NStr("en = 'Contract form'");
	PrintCommand.FormsList		= "ItemForm, ListForm, ChoiceForm, ChoiceFormWithCounterparty";
	PrintCommand.Order			= 1;
	
EndProcedure

#EndRegion

#EndIf
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(DateOfSupply, Company, Cancel);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(DateOfSupply, Company, Cancel);
	EndIf;
	BasisDocumentsFillCheck(Cancel);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;

	DriveServer.SetPostingMode(ThisObject, WriteMode, PostingMode);
	
	AdditionalProperties.Insert("IsNew",    IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
		
	If WriteMode = DocumentWriteMode.Posting Then
		CheckTaxInvoiceForDublicates(Cancel);
	EndIf;
			
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	Documents.TaxInvoiceReceived.InitializeDocumentData(Ref, AdditionalProperties);	
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.TaxInvoiceReceived.RunControl(Ref, AdditionalProperties, Cancel);
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.SupplierInvoice")
		AND Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(FillingData.Date, FillingData.Company) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Company %1 doesn''t use tax invoices at %2 (specify this option in accounting policy)'"),
				FillingData.Company,
				Format(FillingData.Date, "DLF=D"))
		
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SupplierInvoice")]	= "FillBySupplierInvoice";
	FillingStrategy[Type("DocumentRef.DebitNote")]			= "FillByDebitNote";
	FillingStrategy[Type("DocumentRef.CashVoucher")]		= "FillByCashVoucher";
	FillingStrategy[Type("DocumentRef.PaymentExpense")]		= "FillByPaymentExpense";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.WriteRecordSets(ThisObject);
	
	Documents.TaxInvoiceReceived.RunControl(Ref, AdditionalProperties, Cancel, True);

EndProcedure

#EndRegion

#Region ServiceFunctionsAndProcedures

#Region InitialazingAndFilling

Procedure FillByStructure(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		If FillingData.Property("BasisDocument") Then
			FillFromBasisDocument(FillingData);
		EndIf;	
	EndIf;
	
	InitializeDocument(FillingData);	
	
EndProcedure

Procedure FillByDebitNote(FillingData) Export
	
	If Not ValueIsFilled(FillingData)
		Or Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	Currency		= FillingData.DocumentCurrency;
	
	BasisDocuments.Clear();	
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	If FillingData.OperationKind = Enums.OperationTypesDebitNote.PurchaseReturn Then
		OperationKind	= Enums.OperationTypesTaxInvoiceReceived.PurchaseReturn;
	ElsIf FillingData.OperationKind = Enums.OperationTypesDebitNote.DiscountReceived Then
		OperationKind	= Enums.OperationTypesTaxInvoiceReceived.DiscountReceived;
	Else
		OperationKind	= Enums.OperationTypesTaxInvoiceReceived.Adjustments;
	EndIf;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillBySupplierInvoice(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Date, Number");
	
	Currency		= FillingData.DocumentCurrency;
	OperationKind	= Enums.OperationTypesTaxInvoiceReceived.Purchase;
	
	BasisDocuments.Clear();	
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillFromBasisDocument(FillingData)
	
	If TypeOf(FillingData.BasisDocument) = Type("Array") Then
		
		BasisArray = FillingData.BasisDocument;
		For each BasisForFilling In BasisArray Do
			BasisRow = BasisDocuments.Add();
			BasisRow.BasisDocument = BasisForFilling;
		EndDo;
		FillingData.BasisDocument = BasisArray[0];
		
	Else
		BasisRow = BasisDocuments.Add();
		BasisRow.BasisDocument = FillingData.BasisDocument;
	EndIf;
	
	TaxInvoiceParameters = GetBasisTaxInvoiceParameters();
	
	If Not TaxInvoiceParameters.Company = Undefined Then
		FillingData.Insert("Company", TaxInvoiceParameters.Company);
	EndIf;
	
	If Not TaxInvoiceParameters.Department = Undefined Then
		FillingData.Insert("Department", TaxInvoiceParameters.Department);
	EndIf;
	
	If Not TaxInvoiceParameters.Counterparty = Undefined Then
		FillingData.Insert("Counterparty",     TaxInvoiceParameters.Counterparty);
	EndIf;
				
EndProcedure

Procedure FillByCashVoucher(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

Procedure FillByPaymentExpense(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

Procedure FillAdvancePayment(FillingData)
	
	If Not ValueIsFilled(FillingData)
		Or Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT DISTINCT
	|	VATIncurred.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|WHERE
	|	VATIncurred.ShipmentDocument IN(&Documents)
	|	AND VATIncurred.RecordType = VALUE(AccumulationRecordType.Expense)
	|	AND VALUETYPE(VATIncurred.Recorder) = TYPE(Document.SupplierInvoice)");
	
	Query.SetParameter("Documents", FillingData);
	
	Cancel = False;
	Errors = Undefined;
	
	Selection = Query.Execute().Select();
	
	ErrorText = NStr("en = 'The advance amount posted by this payment document is already set off by the %1.
	                 |There is no need to recognize advance VAT. If you still want to input Advance payment invoice,
	                 |revert Supplier invoice in the saved state, input advance payment invoice, and then post supplier invoice again.'");
	
	While Selection.Next() Do
		
		ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, Selection.Recorder);
		CommonUseClientServer.AddUserError(Errors, , ErrorText, Undefined);
		
	EndDo;
	
	CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
	
	If Not Cancel Then
		FillPropertyValues(ThisObject, FillingData,, "Number, Date");
		
		Currency = FillingData.CashCurrency;
		OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment;
		
		BasisDocuments.Clear();
		NewRow = BasisDocuments.Add();
		NewRow.BasisDocument = FillingData;
		
		FillDocumentAmounts(NewRow);
	EndIf;
	
EndProcedure

Procedure InitializeDocument(FillingData = Undefined)
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Company") Then
		Company = Company = DriveServer.GetCompany(Company);
	EndIf;
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Currency") Then
		Currency = DriveReUse.GetNationalCurrency();
	EndIf;
		
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("DateOfSupply") Then
		DateOfSupply = CurrentSessionDate();
	EndIf;
	
EndProcedure

Function GetBasisTaxInvoiceParameters()
	
	SetPrivilegedMode(True);
	
	Result = New Structure("Company, Counterparty, Currency,
		|BasisAttributes, Department");
	
	BasisAttributes = New ValueTable;
	Columns = BasisAttributes.Columns;
	Columns.Add("BasisDocument");
	
	Result.BasisAttributes = BasisAttributes;
	
	DocumentsArray = BasisDocuments.UnloadColumn("BasisDocument");
	
	BasisTypes = DriveServer.ArrangeListByTypesOfObjects(DocumentsArray);
	BasisTypes = Undefined;
	
	Query = New Query;
	QueryBasisText = "";
	QueryInitialDataText = "";
	
	For each BasisType In BasisTypes Do
		
		ObjectType			= BasisType.Value;
		DocumentsMetadata	= ObjectType[0].Metadata();
		ObjectName			= DocumentsMetadata.Name;
		
		Query.Parameters.Insert("BasisDocument_" + ObjectName, ObjectType);
		
		If Not IsBlankString(QueryBasisText) Then
			QueryBasisText = QueryBasisText + "
			|
			|UNION ALL
			|
			|";
		EndIf;
	
		QueryBasisText = QueryBasisText + 
		"SELECT
		|	Table.Company AS Company,
		|	Table.Counterparty  AS Counterparty,
		|	Table.Currency        AS Currency,
		|	Table.Department AS Department
		|FROM
		|	Document." + ObjectName + " AS Table
		|WHERE
		|	Table.Ref IN (&BasisDocument_" + ObjectName + ")";

				
	EndDo;
	
	BasisSelection = Undefined;
	InitialDataSelection = Undefined;
	
	If IsBlankString(QueryInitialDataText) Then
		Query.Text = QueryBasisText;
		BasisSelection = Query.Execute().Select();
	Else
		Query.Text = QueryBasisText + "
		|;
		|
		|" + QueryInitialDataText;
		
		Query.SetParameter("TaxInvoice", Ref);
		QueryResult = Query.ExecuteBatch();
		BasisSelection = QueryResult[0].Select();
		QueryCount = QueryResult.Count();
		InitialDataSelection = QueryResult[QueryCount-1].Select(QueryResultIteration.ByGroups);
	EndIf;
	
	FirstRow					= True;
	DifferentCompanies			= False;
	DifferentCounterparties		= False;
	DifferentCurrencies			= False;
	
	While BasisSelection.Next() Do
		If FirstRow Then
			FirstRow = False;
			FillPropertyValues(Result, BasisSelection);
		Else
			DifferentCompanies		= DifferentCompanies Or Result.Company <> BasisSelection.Company;
			DifferentCounterparties	= DifferentCounterparties Or Result.Counterparty <> BasisSelection.Counterparty;
			DifferentCurrencies		= DifferentCurrencies Or Result.Currency <> BasisSelection.Currency;
		EndIf;
	EndDo;
	
	If DifferentCompanies OR DifferentCounterparties OR DifferentCurrencies Then
			
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The following fields of the tax invoice''s base documents do not match: %1%2%3'"),
			?(DifferentCompanies, Chars.LF + NStr("en = '- company'"), ""),
			?(DifferentCounterparties, Chars.LF + NStr("en = '- counterparty'"), ""),
			?(DifferentCurrencies, Chars.LF + NStr("en = '- currency'"), ""));
		
		CommonUseClientServer.MessageToUser(MessageText);
		
		If DifferentCompanies Then
			Result.Company = Undefined;
		EndIf;
		
		If DifferentCounterparties Then
			Result.Counterparty = Undefined;
		EndIf;
		
		If DifferentCurrencies Then
			Result.Currency = Undefined;
		EndIf;
		
	EndIf;
			
	Return Result;
	
EndFunction

#EndRegion

#Region Other

Procedure BasisDocumentsFillCheck(Cancel)
	
	BasisArray				= New Array;
	PurchaseFromSupplier	= Undefined;
	BasisType				= Undefined;
	
	For each BasisRow In BasisDocuments Do 
		
		If TypeOf(BasisRow.BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
		 
			If PurchaseFromSupplier = Undefined Then
				PurchaseFromSupplier = True;
			ElsIf NOT PurchaseFromSupplier Then
				BasisTypesErrorMessage(BasisRow.LineNumber, Cancel);
			EndIf;
			
		ElsIf BasisType = Undefined Then			
			BasisType = TypeOf(BasisRow.BasisDocument);		
		ElsIf BasisType <> Undefined AND BasisType <> TypeOf(BasisRow.BasisDocument) Then		
			BasisTypesErrorMessage(BasisRow.LineNumber, Cancel);			
		EndIf;
		
		If BasisArray.Find(BasisRow.BasisDocument) <> Undefined Then
			BasisDublicatesErrorMessage(BasisRow.LineNumber, BasisRow.BasisDocument, Cancel);
		EndIf; 
		
		BasisArray.Add(BasisRow.BasisDocument);
		
		If ValueIsFilled(BasisRow.BasisDocument)
			AND	NOT CommonUse.GetAttributeValue(BasisRow.BasisDocument, "Posted") Then
				BasisPostingStatusErrorMessage(BasisRow.LineNumber, Cancel);
		EndIf;
		
		If OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
			CurrencyName = "CashCurrency";
		Else 
			CurrencyName = "DocumentCurrency";
		EndIf;
		
		If Currency <> CommonUse.GetAttributeValue(BasisRow.BasisDocument, CurrencyName) Then
			BasisCurrencyErrorMessage(BasisRow.LineNumber, Cancel);
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure BasisTypesErrorMessage(LineNumber, Cancel)
	
	MessageText = NStr("en = 'All documents included into tax invoice must have the same type'");
	Field = CommonUseClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonUseClientServer.MessageToUser(MessageText,, Field, "Object", Cancel);
	
EndProcedure

Procedure BasisDublicatesErrorMessage(LineNumber, Basis, Cancel)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Duplicate document %2 in line #%1.'"),
		LineNumber,
		Basis);
	Field = CommonUseClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonUseClientServer.MessageToUser(MessageText,,Field,"Object",Cancel);
	
EndProcedure

Procedure BasisPostingStatusErrorMessage(LineNumber, Cancel)
	
	MessageText = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Please select a posted document in line #%1. A tax invoice can be based on posted documents only.'"),
		LineNumber);
	Field = CommonUseClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonUseClientServer.MessageToUser(MessageText,,Field,"Object",Cancel);
	
EndProcedure

Procedure BasisCurrencyErrorMessage(LineNumber, Cancel)
	
	MessageText = NStr("en = 'All documents included into tax invoice must have the same currency.'");
	Field = CommonUseClientServer.PathToTabularSection("BasisDocuments", LineNumber, "BasisDocument");
	CommonUseClientServer.MessageToUser(MessageText,,Field,"Object",Cancel);
	
EndProcedure

Procedure CheckTaxInvoiceForDublicates(Cancel)
		
	SetPrivilegedMode(True);
	
	Query = New Query("
	|SELECT DISTINCT
	|	BasisTable.BasisDocument AS BasisDocument
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS BasisTable
	|WHERE
	|	BasisTable.Ref <> &Ref
	|	AND BasisTable.BasisDocument IN(&BasisList)
	|	AND BasisTable.Ref.Posted
	|");
	
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("BasisList", BasisDocuments.UnloadColumn("BasisDocument"));
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	While Selection.Next() Do
		
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'For document %1 tax invoice already exists'"),
			Selection.BasisDocument);
			
		CommonUseClientServer.MessageToUser(
			Text,
			ThisObject,
			"BasisDocuments",
			,
			Cancel);
		
	EndDo;
	
EndProcedure

Procedure FillDocumentAmounts(NewRow) Export
	
	Query = New Query;
	
	If OperationKind = Enums.OperationTypesTaxInvoiceReceived.Purchase Then
		Query.Text = 
		"SELECT
		|	SupplierInvoiceInventory.Ref AS BasisDocument,
		|	SupplierInvoiceInventory.VATAmount AS VATAmount,
		|	SupplierInvoiceInventory.Total AS Amount
		|INTO DocumentData
		|FROM
		|	Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
		|WHERE
		|	SupplierInvoiceInventory.Ref IN(&Documents)
		|
		|UNION ALL
		|
		|SELECT
		|	SupplierInvoiceExpenses.Ref,
		|	SupplierInvoiceExpenses.VATAmount,
		|	SupplierInvoiceExpenses.Total
		|FROM
		|	Document.SupplierInvoice.Expenses AS SupplierInvoiceExpenses
		|WHERE
		|	SupplierInvoiceExpenses.Ref IN(&Documents)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentData.BasisDocument,
		|	SUM(DocumentData.VATAmount) AS VATAmount,
		|	SUM(DocumentData.Amount) AS Amount
		|FROM
		|	DocumentData AS DocumentData
		|
		|GROUP BY
		|	DocumentData.BasisDocument";
	ElsIf OperationKind = Enums.OperationTypesTaxInvoiceReceived.AdvancePayment Then
		Query.Text = 
		"SELECT
		|	AdvancePayment.Ref AS BasisDocument,
		|	SUM(AdvancePayment.VATAmount) AS VATAmount,
		|	SUM(AdvancePayment.PaymentAmount) AS Amount
		|FROM
		|	Document.CashVoucher.PaymentDetails AS AdvancePayment
		|WHERE
		|	AdvancePayment.Ref IN(&Documents)
		|
		|GROUP BY
		|	AdvancePayment.Ref
		|
		|UNION ALL
		|
		|SELECT
		|	PaymentReceipt.Ref,
		|	SUM(PaymentReceipt.VATAmount),
		|	SUM(PaymentReceipt.PaymentAmount)
		|FROM
		|	Document.PaymentExpense.PaymentDetails AS PaymentReceipt
		|WHERE
		|	PaymentReceipt.Ref IN(&Documents)
		|
		|GROUP BY
		|	PaymentReceipt.Ref";
	Else
		Query.Text = 
		"SELECT
		|	DebitNote.VATAmount AS VATAmount,
		|	DebitNote.DocumentAmount AS Amount
		|FROM
		|	Document.DebitNote AS DebitNote
		|WHERE
		|	DebitNote.Ref IN(&Documents)";
	EndIf;
	
	Query.SetParameter("Documents", NewRow.BasisDocument);
	QueryResult = Query.Execute();
	
	Selection = QueryResult.Select();
	
	While Selection.Next() Do
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure Filling(FillingData, StandardProcessing)
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesInvoice") Then
		
		If Not WorkWithVAT.GetUseTaxInvoiceForPostingVAT(FillingData.Date, FillingData.Company) Then
			
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Company %1 doesn''t use tax invoices at %2 (specify this option in accounting policy)'"),
				FillingData.Company,
				Format(FillingData.Date, "DLF=D"))
			
		EndIf;
		
	EndIf;
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]					= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]	= "FillBySalesInvoice";
	FillingStrategy[Type("DocumentRef.CreditNote")]		= "FillByCreditNote";
	FillingStrategy[Type("DocumentRef.CashReceipt")]	= "FillByCashReceipt";
	FillingStrategy[Type("DocumentRef.PaymentReceipt")]	= "FillByPaymentReceipt";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	DriveServer.SetPostingMode(ThisObject, WriteMode, PostingMode);
	
	AdditionalProperties.Insert("IsNew",    IsNew());
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
	GenerateBasisArrayForChecking();
		
	If Not DeletionMark Then
		CheckTaxInvoiceForDublicates(Cancel);
	EndIf;
	
	If IsNew() AND Not ValueIsFilled(Number) Then
		SetNewNumber();
	EndIf;
		
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);

	Documents.TaxInvoiceIssued.InitializeDocumentData(Ref, AdditionalProperties);

	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);

	DriveServer.WriteRecordSets(ThisObject);

EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	CheckDate = ?(ValueIsFilled(DateOfSupply), DateOfSupply, Date);
	If OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		WorkWithVATServerCall.CheckForAdvancePaymentInvoiceUse(CheckDate, Company, Cancel);
	Else
		WorkWithVATServerCall.CheckForTaxInvoiceUse(CheckDate, Company, Cancel);
	EndIf;
	
	BasisCount = BasisDocuments.Count();
	
	If BasisCount = 0 Then
		MessageText = NStr("en = 'No base documents are available.'");
		CommonUseClientServer.MessageToUser(MessageText, , "BasisDocuments", , Cancel);
	EndIf;
	
	DocumentsNotPosted = False;
	
	If BasisDocuments.Count() > 0 Then
		
		Query = New Query("SELECT
		|	BasisDocuments.BasisDocument.Posted AS BasisDocumentPosted
		|FROM
		|	Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|WHERE
		|	BasisDocuments.Ref = &Ref
		|");
		Query.SetParameter("Ref", Ref);
		SetPrivilegedMode(True);
		ResultSelection = Query.Execute().Select();
		SetPrivilegedMode(False);
		
		While ResultSelection.Next() Do
			
			If Not ResultSelection.BasisDocumentPosted Then
				DocumentsNotPosted = True;
			EndIf;
						
		EndDo;
		
	EndIf;
	
	If DocumentsNotPosted Then
		If BasisCount > 1 Then
			MessageText = NStr("en = 'Please post all of the base documents of the tax invoice.'");
		Else
			MessageText = NStr("en = 'Please post the base document of the tax invoice.'");
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText, , "BasisDocuments", , Cancel);
	EndIf;
		
EndProcedure

Procedure UndoPosting(Cancel)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);

	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#Region ServiceFunctionsAndProcedures

#Region InitializationAndFilling

Procedure FillByStructure(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") Then
		
		If FillingData.Property("BasisDocument") Then
			FillFromBasisDocument(FillingData);
		EndIf;
		
		If Not FillingData.Property("DateOfSupply") Then
			FillingData.Insert("DateOfSupply", CurrentSessionDate());
		EndIf;
		
	EndIf;
	
	InitializeDocument(FillingData);	
	
EndProcedure

Procedure FillByCreditNote(FillingData) Export
	
	If Not ValueIsFilled(FillingData)
		Or Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	Currency		= FillingData.DocumentCurrency;
	
	BasisDocuments.Clear();	
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	If FillingData.OperationKind = Enums.OperationTypesCreditNote.SalesReturn Then
		OperationKind	= Enums.OperationTypesTaxInvoiceIssued.SalesReturn;
	ElsIf FillingData.OperationKind = Enums.OperationTypesCreditNote.DiscountAllowed Then
		OperationKind	= Enums.OperationTypesTaxInvoiceIssued.DiscountAllowed;
	Else
		OperationKind	= Enums.OperationTypesTaxInvoiceIssued.Adjustments;
	EndIf;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure FillByCashReceipt(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

Procedure FillBySalesInvoice(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date, Responsible");
	Currency		= FillingData.DocumentCurrency;
	OperationKind	= Enums.OperationTypesTaxInvoiceIssued.Sale;
	Date = CurrentSessionDate();
	If WorkWithVAT.GetIssueAutomaticallyAgainstSales(CurrentSessionDate(), Company) Then
		DateOfSupply = CurrentSessionDate();
	EndIf;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	FillDocumentAmounts(NewRow);
	
EndProcedure

Procedure InitializeDocument(FillingData = Undefined)
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Company") Then
		Company = DriveServer.GetCompany(Company);
	EndIf;
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Currency") Then
		Currency = DriveReUse.GetNationalCurrency();
	EndIf;
	
	If TypeOf(FillingData) <> Type("Structure") Or Not FillingData.Property("Counterparty") Then
		Counterparty = Catalogs.Counterparties.EmptyRef();
	EndIf;
		
EndProcedure

Procedure FillTaxInvoiceParametersByBasis(SelectedTexInvoice = Undefined) Export
	
	If BasisDocuments.Count() = 0
		Or Not ValueIsFilled(BasisDocuments[0].BasisDocument) Then
			Return;
	EndIf;
	
	BasisDocument = BasisDocuments[0].BasisDocument;
	
	TaxInvoiceParameters = GetTaxInvoiceParametersByBasis();
	BasisAttributes = TaxInvoiceParameters.BasisAttributes;
	
	If Not TaxInvoiceParameters.Company = Undefined AND Not TaxInvoiceParameters.Company = Company Then
		Number = "";
		Company = TaxInvoiceParameters.Company;
	EndIf;
	
	If Not TaxInvoiceParameters.Counterparty = Undefined AND Not TaxInvoiceParameters.Counterparty = Counterparty Then
		Counterparty = TaxInvoiceParameters.Counterparty;
	EndIf;
	
	If Not TaxInvoiceParameters.Currency = Undefined
		AND Currency <> TaxInvoiceParameters.Currency Then
			Currency = TaxInvoiceParameters.Currency;
	EndIf;
				
	If Not TaxInvoiceParameters.Department = Undefined AND Not TaxInvoiceParameters.Department = Department Then
		Department = TaxInvoiceParameters.Department;
	EndIf;
		
	If BasisAttributes.Count() > 0 Then
		BasisDocuments.Load(BasisAttributes);
	EndIf;
	
EndProcedure

Procedure FillFromBasisDocument(FillingData)
	
	If TypeOf(FillingData.BasisDocument) = Type("Array") Then
		
		BasisArray = FillingData.BasisDocument;
		For Each BasisForFilling In BasisArray Do
			BasisRow = BasisDocuments.Add();
			BasisRow.BasisDocument = BasisForFilling;
		EndDo;
		
		If BasisArray.Count() > 0 Then
			FillingData.BasisDocument = BasisArray[0];
		EndIf;
	Else
		BasisRow = BasisDocuments.Add();
		BasisRow.BasisDocument = FillingData.BasisDocument;
	EndIf;
	
	TaxInvoiceParameters = GetTaxInvoiceParametersByBasis();
	
	If Not TaxInvoiceParameters.Company = Undefined Then
		FillingData.Insert("Company", TaxInvoiceParameters.Company);
	EndIf;
	
	If Not TaxInvoiceParameters.Department = Undefined Then
		FillingData.Insert("Department", TaxInvoiceParameters.Department);
	EndIf;
	
	If Not TaxInvoiceParameters.Counterparty = Undefined Then
		FillingData.Insert("Counterparty", TaxInvoiceParameters.Counterparty);
	EndIf;
		
	BasisAttributes = TaxInvoiceParameters.BasisAttributes;
		
EndProcedure

Procedure FillByPaymentReceipt(FillingData) Export
	
	FillAdvancePayment(FillingData);
	
EndProcedure

#EndRegion

#Region Other

// Defines the attributes of the tax invoice based on the selected basis documents 
//
// Returns:
//	Structure - attributes of tax invoice.
//
Function GetTaxInvoiceParametersByBasis()
	
	SetPrivilegedMode(True);
	
	Result = New Structure("Company, Counterparty, Currency, BasisAttributes, Department");
	
	BasisAttributes = New ValueTable;
	Columns = BasisAttributes.Columns;
	Columns.Add("BasisDocument");
	
	Result.BasisAttributes = BasisAttributes;
	
	DocumentsArray = BasisDocuments.UnloadColumn("BasisDocument");
	BasisTypes = DriveServer.ArrangeListByTypesOfObjects(DocumentsArray);
	
	Query = New Query;
	QueryBasisText = "";
	QueryBasisText = "";
	
	For Each BasisType In BasisTypes Do
		
		ObjectsTypes		= BasisType.Value;
		DocumentsMetadata	= ObjectsTypes[0].Metadata();
		ObjectName			= DocumentsMetadata.Name;
		
		Query.Parameters.Insert("BasisDocument_" + ObjectName, ObjectsTypes);
		
		If Not IsBlankString(QueryBasisText) Then
			QueryBasisText = QueryBasisText + "
			|
			|UNION ALL
			|
			|";
		EndIf;
		
		QueryBasisText = QueryBasisText + 
			"SELECT
			|	Table.Company   AS Company,
			|	Table.Counterparty    AS Counterparty,
			|	Table.Department AS Department,
			|	Table.Currency   AS Currency
			|FROM
			|	Document." + ObjectName + " AS Table
			|WHERE
			|	Table.Ref IN (&BasisDocument_" + ObjectName + ")";
			
	EndDo;
	
	BasisSelection = Undefined;
	InitialDataSelection = Undefined;
	
	If IsBlankString(QueryBasisText) Then
	
		Query.Text = QueryBasisText;
		BasisSelection = Query.Execute().Select();
	
	Else
		
		Query.Text = QueryBasisText + "
		|;
		|
		|" + QueryBasisText;
		
		Query.SetParameter("TaxInvoice", Ref);
		QueryResult = Query.ExecuteBatch();
		BasisSelection = QueryResult[0].Select();
		QueryCount = QueryResult.Count();
		InitialDataSelection = QueryResult[QueryCount-1].Select(QueryResultIteration.ByGroups);
		
	EndIf;
	
	FirstRow				= True;
	DifferentCompanies		= False;
	DifferentCounterparties	= False;
	DifferentCurrencies		= False;
	DifferentDepartments	= False;
	
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
		
		MessageText = NStr("en = 'The following fields of the tax invoice''s base documents do not match:'")
			+ ?(DifferentCompanies, Chars.LF + NStr("en = '- company'"), "")
			+ ?(DifferentCounterparties, Chars.LF + NStr("en = '- counterparty'"), "")
			+ ?(DifferentCurrencies, Chars.LF + NStr("en = '- currency'"), "");
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

Procedure CheckTaxInvoiceForDublicates(Cancel)
	
	SetPrivilegedMode(True);
	
	Query = New Query("SELECT
	|	DocumentData.Ref AS Ref,
	|	DocumentData.BasisDocument AS BasisDocument
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS DocumentData
	|WHERE
	|	DocumentData.Ref <> &Ref
	|	AND DocumentData.BasisDocument IN(&BasisArray)
	|	AND DocumentData.Ref.Posted
	|	AND NOT DocumentData.Ref.DeletionMark
	|	AND DocumentData.Ref.OperationKind = &OperationKind");
	
	Query.SetParameter("Ref", 			Ref);
	Query.SetParameter("BasisArray",	BasisDocuments.UnloadColumn("BasisDocument"));
	Query.SetParameter("OperationKind",	OperationKind);
	
	Result = Query.Execute();
	ResultSelection = Result.Select();
	
	While ResultSelection.Next() Do
		
		Text = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '%2 for document %1 already exists'"),
			ResultSelection.BasisDocument,
			ResultSelection.Ref);
			
		CommonUseClientServer.MessageToUser(Text, ThisObject,,, Cancel);
		
	EndDo;
	
EndProcedure

Procedure GenerateBasisArrayForChecking()
	
	BasisArray = New Array;
	
	If Not AdditionalProperties.IsNew Then
		
		Query = New Query(
		"SELECT
		|	BasisDocuments.BasisDocument AS BasisDocument
		|FROM
		|	Document.TaxInvoiceIssued.BasisDocuments AS BasisDocuments
		|WHERE
		|	BasisDocuments.Ref = &Ref");
		
		Query.SetParameter("Ref", Ref);
		
		Result = Query.Execute();
		BasisArray = Result.Unload().UnloadColumn("BasisDocument");
		
	EndIf;
	
	If AdditionalProperties.WriteMode = DocumentWriteMode.Posting Then
		DocumentBasesArray = BasisDocuments.UnloadColumn("BasisDocument");
		CommonUseClientServer.SupplementArray(BasisArray, DocumentBasesArray, True);
	EndIf;
	
	AdditionalProperties.Insert("BasisArrayForChecking", New FixedArray(BasisArray));
	
EndProcedure

Procedure FillDocumentAmounts(NewRow) Export

	Query = New Query;
	
	If OperationKind = Enums.OperationTypesTaxInvoiceIssued.Sale Then
		Query.Text = 
		"SELECT
		|	SalesInvoiceInventory.Ref AS BasisDocument,
		|	SUM(SalesInvoiceInventory.VATAmount) AS VATAmount,
		|	SUM(SalesInvoiceInventory.Total) AS Amount
		|FROM
		|	Document.SalesInvoice.Inventory AS SalesInvoiceInventory
		|WHERE
		|	SalesInvoiceInventory.Ref IN(&Documents)
		|
		|GROUP BY
		|	SalesInvoiceInventory.Ref";
	ElsIf OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment Then
		Query.Text = 
		"SELECT
		|	AdvancePayment.Ref AS Ref,
		|	SUM(AdvancePayment.VATAmount) AS VATAmount,
		|	SUM(AdvancePayment.PaymentAmount) AS Amount
		|FROM
		|	Document.CashReceipt.PaymentDetails AS AdvancePayment
		|WHERE
		|	AdvancePayment.Ref IN(&Documents)
		|	AND AdvancePayment.AdvanceFlag
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
		|	Document.PaymentReceipt.PaymentDetails AS PaymentReceipt
		|WHERE
		|	PaymentReceipt.Ref IN(&Documents)
		|	AND PaymentReceipt.AdvanceFlag
		|
		|GROUP BY
		|	PaymentReceipt.Ref";
	Else
		Query.Text = 
		"SELECT
		|	CreditNote.VATAmount AS VATAmount,
		|	CreditNote.DocumentAmount AS Amount
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Ref IN(&Documents)";
	EndIf;
	
	Query.SetParameter("Documents", NewRow.BasisDocument);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		FillPropertyValues(NewRow, Selection);
	EndDo;
	
EndProcedure

Procedure FillAdvancePayment(FillingData)
	
	If Not ValueIsFilled(FillingData)
		OR Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	FillPropertyValues(ThisObject, FillingData,, "Number, Date");
	
	Currency = FillingData.CashCurrency;
	OperationKind = Enums.OperationTypesTaxInvoiceIssued.AdvancePayment;
	
	BasisDocuments.Clear();
	NewRow = BasisDocuments.Add();
	NewRow.BasisDocument = FillingData;
	
	FillDocumentAmounts(NewRow);
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

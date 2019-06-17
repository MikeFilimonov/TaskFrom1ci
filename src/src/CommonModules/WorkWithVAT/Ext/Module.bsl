#Region ServiceProceduresAndFunctions

// Check usage the option "Post VAT entries by source documents".
//
// Parameters:
//	Date - Date - Date for check
//	Company - CatalogRef.Companies - Company for check
//
// Returned value:
//	Boolean - shows the option value
//
Function GetUseTaxInvoiceForPostingVAT(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return NOT Policy.PostVATEntriesBySourceDocuments;
	
EndFunction

// Check usage the option "Post advance payments by source documents".
//
// Parameters:
//	Date - Date - Date for check
//	Company - CatalogRef.Companies - Company for check
//
// Returned value:
//	Boolean - shows the option value
//
Function GetPostAdvancePaymentsBySourceDocuments(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy.PostAdvancePaymentsBySourceDocuments;
	
EndFunction

// Check usage the option "Issue automatically against sales".
//
// Parameters:
//	Date - Date - Date for check
//	Company - CatalogRef.Companies - Company for check
//
// Returned value:
//	Boolean - shows the option value
//
Function GetIssueAutomaticallyAgainstSales(Date, Company) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return Policy.IssueAutomaticallyAgainstSales;
	
EndFunction

Function GetVATPreparationQueryText() Export
	
	Return 
	"SELECT
	|	UnionTable.Document,
	|	UnionTable.VATRate,
	|	UnionTable.Period,
	|	UnionTable.Company,
	|	UnionTable.ProductsType,
	|	UnionTable.Counterparty,
	|	SUM(UnionTable.VATAmount) AS VATAmount,
	|	SUM(UnionTable.AmountExcludesVAT) AS AmountExcludesVAT
	|INTO TTVATPreparation
	|FROM
	|	(SELECT
	|		TemporaryTableInventory.VATRate AS VATRate,
	|		TemporaryTableInventory.VATAmountCur * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity AS VATAmount,
	|		(TemporaryTableInventory.AmountCur - TemporaryTableInventory.VATAmountCur) * TemporaryTableInventory.ExchangeRate / TemporaryTableInventory.Multiplicity AS AmountExcludesVAT,
	|		TemporaryTableInventory.Document AS Document,
	|		TemporaryTableInventory.Period AS Period,
	|		TemporaryTableInventory.Company AS Company,
	|		TemporaryTableInventory.ProductsType AS ProductsType,
	|		TemporaryTableInventory.Counterparty AS Counterparty
	|	FROM
	|		TemporaryTableInventory AS TemporaryTableInventory
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TemporaryTableExpenses.VATRate,
	|		TemporaryTableExpenses.VATAmountCur * TemporaryTableExpenses.ExchangeRate / TemporaryTableExpenses.Multiplicity,
	|		(TemporaryTableExpenses.AmountCur - TemporaryTableExpenses.VATAmountCur) * TemporaryTableExpenses.ExchangeRate / TemporaryTableExpenses.Multiplicity,
	|		TemporaryTableExpenses.Document,
	|		TemporaryTableExpenses.Period,
	|		TemporaryTableExpenses.Company,
	|		TemporaryTableExpenses.ProductsType AS ProductsType,
	|		TemporaryTableExpenses.Counterparty
	|	FROM
	|		TemporaryTableExpenses AS TemporaryTableExpenses) AS UnionTable
	|
	|GROUP BY
	|	UnionTable.VATRate,
	|	UnionTable.Document,
	|	UnionTable.Period,
	|	UnionTable.Company,
	|	UnionTable.ProductsType,
	|	UnionTable.Counterparty" + DriveClientServer.GetQueryDelimeter();
	
EndFunction

Procedure ForbidReverseChargeTaxationTypeDocumentGeneration(DocumentObject) Export
	
	If DocumentObject.VATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT Then
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Reverse charge is not applicable for ""%1"".'"),
			DocumentObject.Metadata().Presentation());
		
		Raise MessageText;
		
	EndIf;
	
EndProcedure

Function VATTaxationTypeIsValid(VATTaxationType, RegisteredForVAT, ReverseChargeNotApplicable) Export
	
	Return Not (VATTaxationType = Enums.VATTaxationTypes.SubjectToVAT And Not RegisteredForVAT
				Or VATTaxationType = Enums.VATTaxationTypes.ReverseChargeVAT And ReverseChargeNotApplicable);
	
EndFunction

#Region TaxInvoiceMethods

// Posting cancellation procedure of the subordinate sales invoice note
//
Procedure SubordinatedTaxInvoiceControl(WriteMode, Ref, DeletionMark) Export
	
	TaxInvoiceStructure = GetSubordinateTaxInvoice(Ref, TypeOf(Ref) = Type("DocumentRef.DebitNote") 
														OR TypeOf(Ref) = Type("DocumentRef.SupplierInvoice"));
	
	If Not TaxInvoiceStructure = Undefined Then
		MessageText = "";
		TaxInvoice = TaxInvoiceStructure.Ref;
		TaxInvoiceObject = TaxInvoice.GetObject();
		
		NeedToWrite = (WriteMode = DocumentWriteMode.Posting) AND TaxInvoice.BasisDocuments.Count() = 1;
		
		If WriteMode = DocumentWriteMode.Posting Then
			FoundRow = TaxInvoiceObject.BasisDocuments.Find(Ref, "BasisDocument");
			If FoundRow <> Undefined Then
				TaxInvoiceObject.FillDocumentAmounts(FoundRow); 
			EndIf;
		EndIf;
		
		Parameters = New Structure;
		Parameters.Insert("Ref", 				Ref);
		Parameters.Insert("TaxInvoiceObject",	TaxInvoiceObject);
		Parameters.Insert("WriteMode",			WriteMode);
		
		If WriteMode = DocumentWriteMode.UndoPosting AND TaxInvoice.Posted Then
			MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 posting has been cancelled.'"),
				WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceStructure.Date, TaxInvoiceStructure.Number));
			NeedToWrite = True;
		EndIf;
		
		If WriteMode = DocumentWriteMode.Posting 
			AND Not TaxInvoice.Posted
			AND TaxInvoice.BasisDocuments.Count() = 1 Then 
				MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 has been posted.'"),
					WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceStructure.Date, TaxInvoiceStructure.Number));
		EndIf;
			
		If DeletionMark <> TaxInvoice.DeletionMark 
			AND TaxInvoice.BasisDocuments.Count() = 1 Then 
				MessageText = MessageText + StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 was %2 for deletion.'"),
					WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceStructure.Date, TaxInvoiceStructure.Number), 
						?(DeletionMark,  NStr("en = 'marked'"), NStr("en = 'unmarked'")));
					Parameters.Insert("DeletionMark", 	DeletionMark);
				NeedToWrite = True;
		EndIf;
		
		Parameters.Insert("MessageText", MessageText);
		
		If NeedToWrite Then
			WriteTaxInvoiceAndMessageToUser(Parameters);
		EndIf;
	EndIf;
	
EndProcedure

// Create and postint the Tax invoice
//
Procedure CreateTaxInvoice(WriteMode, Ref, DeletionMark) Export
	
	TaxInvoiceStructure = GetSubordinateTaxInvoice(Ref);
	
	If TaxInvoiceStructure = Undefined Then
		
		TaxInvoiceIssued = Documents.TaxInvoiceIssued.CreateDocument();
		TaxInvoiceIssued.FillBySalesInvoice(Ref);
		TaxInvoiceIssued.Write(DocumentWriteMode.Posting);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The document %1 have been created automatically.'"),
			WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceIssued.Date, TaxInvoiceIssued.Number));
			
		CommonUseClientServer.MessageToUser(MessageText)
	EndIf;
	
EndProcedure

Procedure WriteTaxInvoiceAndMessageToUser(Parameters)
	
	If ValueIsFilled(Parameters.MessageText) Then
		CommonUseClientServer.MessageToUser(Parameters.MessageText);
	EndIf;
	
	If Parameters.Property("DeletionMark") Then
		Parameters.TaxInvoiceObject.SetDeletionMark(Parameters.DeletionMark);
	Else
		Parameters.TaxInvoiceObject.Write(Parameters.WriteMode);
	EndIf;
	
EndProcedure

// Function returns reference to the subordinate tax invoice
//
Function GetSubordinateTaxInvoice(BasisDocument, Received = False, Advance = False) Export
	
	If NOT ValueIsFilled(BasisDocument) Then
		Return Undefined;
	ElsIf NOT Advance AND NOT GetUseTaxInvoiceForPostingVAT(BasisDocument.Date, BasisDocument.Company) Then
		Return Undefined;
	ElsIf Advance AND GetPostAdvancePaymentsBySourceDocuments(BasisDocument.Date, BasisDocument.Company) Then
		Return Undefined;
	EndIf;
	
	If Received Then
		
		QueryText = 
		"SELECT
		|	TaxInvoiceBasisDocuments.Ref AS Ref
		|INTO TaxInvoiceBasisDocuments
		|FROM
		|	Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoiceBasisDocuments
		|WHERE
		|	TaxInvoiceBasisDocuments.BasisDocument = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Header.Ref AS Ref,
		|	Header.Number AS Number,
		|	Header.Date AS Date
		|FROM
		|	TaxInvoiceBasisDocuments AS TaxInvoiceBasisDocuments
		|		INNER JOIN Document.TaxInvoiceReceived AS Header
		|		ON TaxInvoiceBasisDocuments.Ref = Header.Ref
		|WHERE
		|	NOT Header.DeletionMark"
		
	Else
		
		QueryText = 
		"SELECT
		|	TaxInvoiceBasisDocuments.Ref AS Ref
		|INTO TaxInvoiceBasisDocuments
		|FROM
		|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceBasisDocuments
		|WHERE
		|	TaxInvoiceBasisDocuments.BasisDocument = &BasisDocument
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	Header.Ref AS Ref,
		|	Header.Number AS Number,
		|	Header.Date AS Date
		|FROM
		|	TaxInvoiceBasisDocuments AS TaxInvoiceBasisDocuments
		|		INNER JOIN Document.TaxInvoiceIssued AS Header
		|		ON TaxInvoiceBasisDocuments.Ref = Header.Ref
		|WHERE
		|	NOT Header.DeletionMark"
		
	EndIf;
	
	Query = New Query(QueryText);
	Query.SetParameter("BasisDocument", BasisDocument);
	
	Result = Undefined;
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Result = New Structure("Ref, Number, Date");
		FillPropertyValues(Result, Selection);
	EndIf;
	
	Return Result;
EndFunction

// While changing the base document correct
// the subordinate Sales invoice note Parameters:
// BasisDocument - base document for which you should search and correct sales invoice note
Procedure ChangeSubordinateTaxInvoice(BasisDocument, Received = False) Export
	
	TaxInvoiceIssued = GetSubordinateTaxInvoice(BasisDocument, Received);
	TaxInvoiceObject = TaxInvoiceIssued.Ref.GetObject();
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]						= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]	= "FillBySalesInvoice";
	
	ObjectFillingDrive.FillDocument(TaxInvoiceObject, BasisDocument, FillingStrategy);
	
	TaxInvoiceObject.Write();
	
EndProcedure

// Sets hyperlink label "Tax invoice"
//
Procedure SetTextAboutTaxInvoiceReceived(DocumentForm) Export
	SetTextAboutTaxInvoice(DocumentForm, True)
EndProcedure

// Sets hyperlink label "Tax invoice"
//
Procedure SetTextAboutTaxInvoiceIssued(DocumentForm) Export
	SetTextAboutTaxInvoice(DocumentForm)
EndProcedure

// Sets hyperlink label "Advance Payment Invoice"
//
Procedure SetTextAboutAdvancePaymentInvoiceIssued(DocumentForm) Export
	SetTextAboutAdvancePaymentInvoice(DocumentForm)
EndProcedure

// Sets hyperlink label "Advance Payment Invoice"
//
Procedure SetTextAboutAdvancePaymentInvoiceReceived(DocumentForm) Export
	SetTextAboutAdvancePaymentInvoice(DocumentForm, True)
EndProcedure

// Sets hyperlink label for Advance Payment Invoice note
//
Procedure SetTextAboutAdvancePaymentInvoice(DocumentForm, Received = False)

	AdvancePaymentInvoiceFound = GetSubordinateTaxInvoice(DocumentForm.Object.Ref, Received, True);
	
	If ValueIsFilled(AdvancePaymentInvoiceFound) Then
		DocumentForm.TaxInvoiceText = WorkWithVATClientServer.AdvancePaymentInvoicePresentation(AdvancePaymentInvoiceFound.Date, AdvancePaymentInvoiceFound.Number);
	Else
		DocumentForm.TaxInvoiceText = NStr("en = 'Create Advance payment invoice'");
	EndIf;

EndProcedure

// Sets hyperlink label for Sales invoice note
//
Procedure SetTextAboutTaxInvoice(DocumentForm, Received = False)

	TaxInvoiceFound = GetSubordinateTaxInvoice(DocumentForm.Object.Ref, Received);
	
	If ValueIsFilled(TaxInvoiceFound) Then
		DocumentForm.TaxInvoiceText = WorkWithVATClientServer.TaxInvoicePresentation(TaxInvoiceFound.Date, TaxInvoiceFound.Number);	
	Else
		DocumentForm.TaxInvoiceText = NStr("en = 'Create tax invoice'");
	EndIf;

EndProcedure

// Method fills the Prepayment VAT table in object.
//
// Parameters:
//	Object - DocumentObject - Document which have a table "Prepayment VAT"
//
Procedure FillPrepaymentVATFromVATInput(Object) Export
	
	TextQuery = 
	"SELECT
	|	MIN(AccountsPayable.Period) AS Period,
	|	AccountsPayable.Recorder AS Recorder
	|INTO PrepaymentDocumentDates
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable
	|WHERE
	|	AccountsPayable.Recorder IN(&PrepaymentDocument)
	|
	|GROUP BY
	|	AccountsPayable.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentDocuments.Recorder AS Recorder,
	|	MAX(ExchangeRates.Period) AS Period
	|INTO PrepaymentDocumentCurrencyDates
	|FROM
	|	PrepaymentDocumentDates AS PrepaymentDocuments
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (ExchangeRates.Period <= PrepaymentDocuments.Period)
	|			AND (ExchangeRates.Currency IN (&PresentationCurrency, &CurrencyNational))
	|
	|GROUP BY
	|	PrepaymentDocuments.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentDocuments.Recorder AS Recorder,
	|	ExchangeRates.Currency AS Currency,
	|	ExchangeRates.ExchangeRate AS ExchangeRate,
	|	ExchangeRates.Multiplicity AS Multiplicity
	|INTO PrepaymentDocumentExchangeRates
	|FROM
	|	PrepaymentDocumentCurrencyDates AS PrepaymentDocuments
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (ExchangeRates.Period = PrepaymentDocuments.Period)
	|			AND (ExchangeRates.Currency IN (&PresentationCurrency, &CurrencyNational))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TaxInvoice.Ref AS Ref
	|INTO TaxInvoice
	|FROM
	|	Document.TaxInvoiceReceived.BasisDocuments AS TaxInvoice
	|WHERE
	|	TaxInvoice.BasisDocument = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInput.Company AS Company,
	|	VATInput.Supplier AS Customer,
	|	VATInput.ShipmentDocument AS ShipmentDocument,
	|	VATInput.VATRate AS VATRate,
	|	SUM(VATInput.AmountExcludesVATTurnover) AS AmountExcludesVAT,
	|	SUM(VATInput.VATAmountTurnover) AS VATAmount
	|INTO VATInputBalanceNoGroup
	|FROM
	|	AccumulationRegister.VATInput.Turnovers(
	|			,
	|			&DocumentDate,
	|			Recorder,
	|			ShipmentDocument IN (&PrepaymentDocument)
	|				AND Company = &Company
	|				AND Supplier = &Customer) AS VATInput
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate,
	|	-SUM(VATInput.AmountExcludesVAT),
	|	-SUM(VATInput.VATAmount)
	|FROM
	|	TaxInvoice AS TaxInvoice
	|		INNER JOIN AccumulationRegister.VATInput AS VATInput
	|		ON TaxInvoice.Ref = VATInput.Recorder
	|WHERE
	|	VATInput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATInput.Company = &Company
	|	AND VATInput.Supplier = &Customer
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate,
	|	-SUM(VATInput.AmountExcludesVAT),
	|	-SUM(VATInput.VATAmount)
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|WHERE
	|	VATInput.Recorder = &Ref
	|	AND VATInput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATInput.Company = &Company
	|	AND VATInput.Supplier = &Customer
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Supplier,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATIncurred.Company,
	|	VATIncurred.Supplier,
	|	VATIncurred.ShipmentDocument,
	|	VATIncurred.VATRate,
	|	VATIncurred.AmountExcludesVATBalance,
	|	VATIncurred.VATAmountBalance
	|FROM
	|	AccumulationRegister.VATIncurred.Balance(
	|			&PointInTime,
	|			ShipmentDocument IN (&PrepaymentDocument)
	|				AND Company = &Company
	|				AND Supplier = &Customer) AS VATIncurred
	|
	|UNION ALL
	|
	|SELECT
	|	VATIncurred.Company,
	|	VATIncurred.Supplier,
	|	VATIncurred.ShipmentDocument,
	|	VATIncurred.VATRate,
	|	VATIncurred.AmountExcludesVAT,
	|	VATIncurred.VATAmount
	|FROM
	|	TaxInvoice AS TaxInvoice
	|		INNER JOIN AccumulationRegister.VATIncurred AS VATIncurred
	|		ON TaxInvoice.Ref = VATIncurred.Recorder
	|WHERE
	|	VATIncurred.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATIncurred.Company = &Company
	|	AND VATIncurred.Supplier = &Customer
	|
	|UNION ALL
	|
	|SELECT
	|	VATIncurred.Company,
	|	VATIncurred.Supplier,
	|	VATIncurred.ShipmentDocument,
	|	VATIncurred.VATRate,
	|	VATIncurred.AmountExcludesVAT,
	|	VATIncurred.VATAmount
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|WHERE
	|	VATIncurred.Recorder = &Ref
	|	AND VATIncurred.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATIncurred.Company = &Company
	|	AND VATIncurred.Supplier = &Customer
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInput.Company AS Company,
	|	VATInput.Customer AS Customer,
	|	VATInput.ShipmentDocument AS ShipmentDocument,
	|	VATInput.VATRate AS VATRate,
	|	SUM(VATInput.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(VATInput.VATAmount) AS VATAmount
	|INTO VATInputBalance
	|FROM
	|	VATInputBalanceNoGroup AS VATInput
	|WHERE
	|	VATInput.AmountExcludesVAT > 0
	|
	|GROUP BY
	|	VATInput.Company,
	|	VATInput.Customer,
	|	VATInput.ShipmentDocument,
	|	VATInput.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.PaymentAmount AS PaymentAmount
	|INTO Prepayment
	|FROM
	|	&PrepaymentTab AS Prepayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATInput.Company AS Company,
	|	VATInput.Customer AS Customer,
	|	VATInput.ShipmentDocument AS Document,
	|	VATInput.VATRate AS VATRate,
	|	VATInput.AmountExcludesVAT AS AmountExcludesVAT,
	|	VATInput.VATAmount AS VATAmount,
	|	VATInput.AmountExcludesVAT + VATInput.VATAmount AS PaymentAmount,
	|	ISNULL(PresentationCurrency.Multiplicity, 1) AS AccountingCurrencyMultiplicity,
	|	ISNULL(PresentationCurrency.ExchangeRate, 1) AS AccountingCurrencyExchangeRate,
	|	ISNULL(CurrencyNational.Multiplicity, 1) AS CurrencyNationalMultiplicity,
	|	ISNULL(CurrencyNational.ExchangeRate, 1) AS CurrencyNationalExchangeRate,
	|	Prepayment.PaymentAmount AS DocumentPaymentAmount
	|FROM
	|	VATInputBalance AS VATInput
	|		INNER JOIN Prepayment AS Prepayment
	|		ON VATInput.ShipmentDocument = Prepayment.ShipmentDocument
	|		LEFT JOIN PrepaymentDocumentExchangeRates AS PresentationCurrency
	|		ON (PresentationCurrency.Currency = &PresentationCurrency)
	|			AND (PresentationCurrency.Recorder = VATInput.ShipmentDocument)
	|		LEFT JOIN PrepaymentDocumentExchangeRates AS CurrencyNational
	|		ON (CurrencyNational.Currency = &CurrencyNational)
	|			AND (CurrencyNational.Recorder = VATInput.ShipmentDocument)
	|WHERE
	|	VATInput.AmountExcludesVAT > 0";
	
	FillPrepaymentVAT(Object, TextQuery);
	
EndProcedure

// Method fills the Prepayment VAT table in object.
//
// Parameters:
//	Object - DocumentObject - Document which have a table "Prepayment VAT"
//
Procedure FillPrepaymentVATFromVATOutput(Object) Export
	
	TextQuery = 
	"SELECT
	|	MIN(AccountsReceivable.Period) AS Period,
	|	AccountsReceivable.Recorder AS Recorder
	|INTO PrepaymentDocumentDates
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	AccountsReceivable.Recorder IN(&PrepaymentDocument)
	|
	|GROUP BY
	|	AccountsReceivable.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentDocuments.Recorder AS Recorder,
	|	MAX(ExchangeRates.Period) AS Period
	|INTO PrepaymentDocumentCurrencyDates
	|FROM
	|	PrepaymentDocumentDates AS PrepaymentDocuments
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (ExchangeRates.Period <= PrepaymentDocuments.Period)
	|			AND (ExchangeRates.Currency IN (&PresentationCurrency, &CurrencyNational))
	|
	|GROUP BY
	|	PrepaymentDocuments.Recorder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PrepaymentDocuments.Recorder AS Recorder,
	|	ExchangeRates.Currency AS Currency,
	|	ExchangeRates.ExchangeRate AS ExchangeRate,
	|	ExchangeRates.Multiplicity AS Multiplicity
	|INTO PrepaymentDocumentExchangeRates
	|FROM
	|	PrepaymentDocumentCurrencyDates AS PrepaymentDocuments
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (ExchangeRates.Period = PrepaymentDocuments.Period)
	|			AND (ExchangeRates.Currency IN (&PresentationCurrency, &CurrencyNational))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TaxInvoice.Ref AS Ref
	|INTO TaxInvoice
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoice
	|WHERE
	|	TaxInvoice.BasisDocument = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATOutput.Company AS Company,
	|	VATOutput.Customer AS Customer,
	|	VATOutput.ShipmentDocument AS ShipmentDocument,
	|	VATOutput.VATRate AS VATRate,
	|	SUM(VATOutput.AmountExcludesVATTurnover) AS AmountExcludesVAT,
	|	SUM(VATOutput.VATAmountTurnover) AS VATAmount
	|INTO VATOutputBalanceNoGroup
	|FROM
	|	AccumulationRegister.VATOutput.Turnovers(
	|			,
	|			&DocumentDate,
	|			Recorder,
	|			ShipmentDocument IN (&PrepaymentDocument)
	|				AND Company = &Company
	|				AND Customer = &Customer) AS VATOutput
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate,
	|	-SUM(VATOutput.AmountExcludesVAT),
	|	-SUM(VATOutput.VATAmount)
	|FROM
	|	TaxInvoice AS TaxInvoice
	|		INNER JOIN AccumulationRegister.VATOutput AS VATOutput
	|		ON TaxInvoice.Ref = VATOutput.Recorder
	|WHERE
	|	VATOutput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATOutput.Company = &Company
	|	AND VATOutput.Customer = &Customer
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|
	|UNION ALL
	|
	|SELECT
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate,
	|	-SUM(VATOutput.AmountExcludesVAT),
	|	-SUM(VATOutput.VATAmount)
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|
	|WHERE
	|	VATOutput.Recorder = &Ref
	|	AND VATOutput.ShipmentDocument IN(&PrepaymentDocument)
	|	AND VATOutput.Company = &Company
	|	AND VATOutput.Customer = &Customer
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATOutput.Company AS Company,
	|	VATOutput.Customer AS Customer,
	|	VATOutput.ShipmentDocument AS ShipmentDocument,
	|	VATOutput.VATRate AS VATRate,
	|	SUM(VATOutput.AmountExcludesVAT) AS AmountExcludesVAT,
	|	SUM(VATOutput.VATAmount) AS VATAmount
	|INTO VATOutputBalance
	|FROM
	|	VATOutputBalanceNoGroup AS VATOutput
	|WHERE
	|	VATOutput.AmountExcludesVAT > 0
	|
	|GROUP BY
	|	VATOutput.Company,
	|	VATOutput.Customer,
	|	VATOutput.ShipmentDocument,
	|	VATOutput.VATRate
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Prepayment.Document AS ShipmentDocument,
	|	Prepayment.PaymentAmount AS PaymentAmount
	|INTO Prepayment
	|FROM
	|	&PrepaymentTab AS Prepayment
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VATOutput.Company AS Company,
	|	VATOutput.Customer AS Customer,
	|	VATOutput.ShipmentDocument AS Document,
	|	VATOutput.VATRate AS VATRate,
	|	VATOutput.AmountExcludesVAT AS AmountExcludesVAT,
	|	VATOutput.VATAmount AS VATAmount,
	|	VATOutput.AmountExcludesVAT + VATOutput.VATAmount AS PaymentAmount,
	|	ISNULL(PresentationCurrency.Multiplicity, 1) AS AccountingCurrencyMultiplicity,
	|	ISNULL(PresentationCurrency.ExchangeRate, 1) AS AccountingCurrencyExchangeRate,
	|	ISNULL(CurrencyNational.Multiplicity, 1) AS CurrencyNationalMultiplicity,
	|	ISNULL(CurrencyNational.ExchangeRate, 1) AS CurrencyNationalExchangeRate,
	|	Prepayment.PaymentAmount AS DocumentPaymentAmount
	|FROM
	|	VATOutputBalance AS VATOutput
	|		INNER JOIN Prepayment AS Prepayment
	|		ON VATOutput.ShipmentDocument = Prepayment.ShipmentDocument
	|		LEFT JOIN PrepaymentDocumentExchangeRates AS PresentationCurrency
	|		ON (PresentationCurrency.Currency = &PresentationCurrency)
	|			AND (PresentationCurrency.Recorder = VATOutput.ShipmentDocument)
	|		LEFT JOIN PrepaymentDocumentExchangeRates AS CurrencyNational
	|		ON (CurrencyNational.Currency = &CurrencyNational)
	|			AND (CurrencyNational.Recorder = VATOutput.ShipmentDocument)
	|WHERE
	|	VATOutput.AmountExcludesVAT > 0";
	
	FillPrepaymentVAT(Object, TextQuery);
	
EndProcedure

// Method fills the Prepayment VAT table in object.
//
// Parameters:
//	Object - DocumentObject - Document which have a table "Prepayment VAT"
//	TextQuery - String - Text query
//
Procedure FillPrepaymentVAT(Object, TextQuery)
	
	Object.PrepaymentVAT.Clear();
	
	PrepaymentTab = Object.Prepayment.Unload(,"Document,PaymentAmount");
	
	Query = New Query(TextQuery);
	Query.SetParameter("DocumentDate", Object.Date);
	Query.SetParameter("PrepaymentDocument", PrepaymentTab.UnloadColumn("Document"));
	Query.SetParameter("PrepaymentTab", PrepaymentTab);
	Query.SetParameter("Company", Object.Company);
	Query.SetParameter("Customer", Object.Counterparty);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational", Constants.FunctionalCurrency.Get());
	Query.SetParameter("DocumentDate", Object.Date);
	Query.SetParameter("PointInTime", New PointInTime(Object.Date, Object.Ref));
	Query.SetParameter("Ref", Object.Ref);
	
	VATOutput = Query.Execute().Select();
	While VATOutput.Next() Do
		
		NewLine = Object.PrepaymentVAT.Add();
		
		PaymentAmountForFill = VATOutput.DocumentPaymentAmount * VATOutput.AccountingCurrencyExchangeRate
			* VATOutput.CurrencyNationalMultiplicity / (VATOutput.CurrencyNationalExchangeRate * VATOutput.AccountingCurrencyMultiplicity);
		
		If PaymentAmountForFill >= VATOutput.PaymentAmount Then
			
			FillPropertyValues(NewLine, VATOutput);
			
		Else
			
			NewLine.Document = VATOutput.Document;
			NewLine.VATRate = VATOutput.VATRate;
			
			NewLine.AmountExcludesVAT = Round(PaymentAmountForFill * VATOutput.AmountExcludesVAT / VATOutput.PaymentAmount, 2);
			NewLine.VATAmount = Round(PaymentAmountForFill * VATOutput.VATAmount / VATOutput.PaymentAmount, 2);
			
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion
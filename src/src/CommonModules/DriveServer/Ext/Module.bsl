
#Region ServiceProgrammingInterface

// Procedure initializes the IsFirstLaunch session parameters.
//
Procedure SessionParametersSetting(Val ParameterName, SpecifiedParameters) Export
	
	
	
EndProcedure

// Defines whether the passed object is a document
//
Function IsMetadataKindDocument(ObjectName)
	
	Return Not Metadata.Documents.Find(ObjectName) = Undefined;
	
EndFunction

// Used in the first start assistant
//
// Called:
// InfobaseUpdateClientOverridable.OpenFirstStartAssistant();
//
Function GetActivityKind() Export
	
	ActivityKind = Constants.ActivityKind.Get();
	
	If Catalogs.Companies.MainCompany.Description <> NStr("en = 'Our company, LLC'")
	AND Not IsBlankString(Catalogs.Companies.MainCompany.Description)
	AND Not ValueIsFilled(ActivityKind) Then
		SetPrivilegedMode(True);
		ActivityKind = Enums.CompanyActivityKinds.TradeServicesProduction;
		Constants.ActivityKind.Set(ActivityKind);
		Constants.UsePayrollSubsystem.Set(True);
		Constants.UseWorkOrders.Set(True);
		Constants.UseProductionSubsystem.Set(True);
		SetPrivilegedMode(False);
		ActivityKindSelected = True;
	EndIf;
	
	Return ActivityKind;
	
EndFunction

// Function converts row to the plural
//
// Parameters: 
//  Word1 - word form in singular
//  ("box") Word2 - word form for numeral
//  2-4 ("box") Word3 - word form for numeral 5-10
//  ("boxes") IntegerNumber - integer number
//
// Returns:
//  string - one of the rows depending on the IntegerNumber parameter
//
// Definition:
//  Designed to generate "correct" signature to numerals
//
Function FormOfMultipleNumbers(Word1, Word2, Word3, Val IntegerNumber) Export
	
	// Change integer sign, otherwise, negative numbers will be converted incorrectly.
	If IntegerNumber < 0 Then
		IntegerNumber = -1 * IntegerNumber;
	EndIf;
	
	If IntegerNumber <> Int(IntegerNumber) Then 
		// for nonintegral numbers - always the second form
		Return Word2;
	EndIf;
	
	// Balance
	Balance = IntegerNumber%10;
	If (IntegerNumber >10) AND (IntegerNumber<20) Then
		// for the second dozen - always the third form
		Return Word3;
	ElsIf Balance=1 Then
		Return Word1;
	ElsIf (Balance>1) AND (Balance<5) Then
		Return Word2;
	Else
		Return Word3;
	EndIf;

EndFunction

Procedure UpdateDocumentStatuses(ExportParameters = Undefined, ResultAddress = Undefined) Export
	
	CommonUse.OnStartExecutingScheduledJob();
	
	EventName = NStr("en = 'Update document statuses'",
		CommonUseClientServer.MainLanguageCode());
	
	WriteLogEvent(EventName, EventLogLevel.Information, , ,
		NStr("en = 'Document status update is started'"));
	
	ResultArray = GetDocumentStatusesTables();
	DocumentStatusesTable = ResultArray[9].Unload();
	PreviousDocumentStatusesTable = ResultArray[10].Unload();
	
	SearchStructure = New Structure("Document, Status");
	
	For Each TableRow In DocumentStatusesTable Do
		
		FillPropertyValues(SearchStructure, TableRow);
		CurrentStatusesArray = PreviousDocumentStatusesTable.FindRows(SearchStructure);
		
		StatusIsChanged = Not Boolean(CurrentStatusesArray.Count());
		If StatusIsChanged Then
			RecordSet = InformationRegisters[TableRow.RegisterName].CreateRecordSet();
			RecordSet.Filter.Document.Set(TableRow.Document);
			
			If TableRow.Status <> Undefined Then
				RecordSetRow = RecordSet.Add();
				FillPropertyValues(RecordSetRow, TableRow);
			EndIf;
			RecordSet.Write(True);
				
			If TableRow.Delete Then
				RecordSetForUpdating = InformationRegisters.TasksForUpdatingStatuses.CreateRecordSet();
				RecordSetForUpdating.Filter.Document.Set(TableRow.Document);
				RecordSetForUpdating.Write(True);
			EndIf;
			
		EndIf;
	EndDo;
	
EndProcedure

Function GetDocumentStatusesTables()

	Query = New Query;
	Query.Text = 
	"SELECT
	|	TasksForUpdatingStatuses.Document AS Document
	|INTO DocumentsForUpdatingStatuses
	|FROM
	|	InformationRegister.TasksForUpdatingStatuses AS TasksForUpdatingStatuses
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsForUpdatingStatuses.Document AS Quotation,
	|	Quote.ValidUntil AS ValidUntil,
	|	Quote.Posted AS QuotationPosted
	|INTO Quotations
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN Document.Quote AS Quote
	|		ON DocumentsForUpdatingStatuses.Document = Quote.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsForUpdatingStatuses.Document AS Document
	|INTO GoodsDocuments
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|WHERE
	|	(VALUETYPE(DocumentsForUpdatingStatuses.Document) = TYPE(Document.GoodsIssue)
	|			OR VALUETYPE(DocumentsForUpdatingStatuses.Document) = TYPE(Document.GoodsReceipt))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Quotations.Quotation AS Ref,
	|	Quotations.ValidUntil AS ValidUntil,
	|	Quotations.QuotationPosted AS QuotationPosted,
	|	ISNULL(SalesOrder.Posted, FALSE) AS SalesDocumentPosted
	|INTO QuotationsWithDocuments
	|FROM
	|	Quotations AS Quotations
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON Quotations.Quotation = SalesOrder.BasisDocument
	|
	|UNION ALL
	|
	|SELECT
	|	Quotations.Quotation,
	|	Quotations.ValidUntil,
	|	Quotations.QuotationPosted,
	|	ISNULL(SalesInvoice.Posted, FALSE)
	|FROM
	|	Quotations AS Quotations
	|		LEFT JOIN Document.SalesInvoice AS SalesInvoice
	|		ON Quotations.Quotation = SalesInvoice.BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuotationsWithDocuments.Ref AS Quotation,
	|	QuotationsWithDocuments.ValidUntil AS ValidUntil,
	|	QuotationsWithDocuments.QuotationPosted AS QuotationPosted,
	|	MAX(QuotationsWithDocuments.SalesDocumentPosted) AS SalesDocumentPosted
	|INTO GroupedQuotations
	|FROM
	|	QuotationsWithDocuments AS QuotationsWithDocuments
	|
	|GROUP BY
	|	QuotationsWithDocuments.Ref,
	|	QuotationsWithDocuments.QuotationPosted,
	|	QuotationsWithDocuments.ValidUntil
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceivedNotInvoiced.GoodsReceipt AS GoodsDocument,
	|	COUNT(DISTINCT GoodsReceivedNotInvoiced.Recorder) AS CountOfRecorders,
	|	FALSE AS HasGoodsInvoicedInAdvance
	|INTO GoodsNotInvoiced
	|FROM
	|	GoodsDocuments AS GoodsDocuments
	|		INNER JOIN AccumulationRegister.GoodsReceivedNotInvoiced AS GoodsReceivedNotInvoiced
	|		ON GoodsDocuments.Document = GoodsReceivedNotInvoiced.GoodsReceipt
	|
	|GROUP BY
	|	GoodsReceivedNotInvoiced.GoodsReceipt
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsShippedNotInvoiced.GoodsIssue,
	|	COUNT(DISTINCT GoodsShippedNotInvoiced.Recorder),
	|	MIN(NOT GoodsInvoicedNotShipped.Recorder IS NULL)
	|FROM
	|	GoodsDocuments AS GoodsDocuments
	|		INNER JOIN AccumulationRegister.GoodsShippedNotInvoiced AS GoodsShippedNotInvoiced
	|		ON GoodsDocuments.Document = GoodsShippedNotInvoiced.GoodsIssue
	|		LEFT JOIN AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
	|		ON GoodsDocuments.Document = GoodsInvoicedNotShipped.Recorder
	|			AND (GoodsInvoicedNotShipped.LineNumber = 1)
	|
	|GROUP BY
	|	GoodsShippedNotInvoiced.GoodsIssue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GoodsReceivedNotInvoicedBalance.GoodsReceipt AS GoodsDocument,
	|	GoodsReceivedNotInvoicedBalance.QuantityBalance AS QuantityBalance
	|INTO GoodsNotInvoicedBalance
	|FROM
	|	AccumulationRegister.GoodsReceivedNotInvoiced.Balance(
	|			,
	|			GoodsReceipt IN
	|				(SELECT
	|					DocumentsForUpdatingStatuses.Document AS Document
	|				FROM
	|					DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses)) AS GoodsReceivedNotInvoicedBalance
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsShippedNotInvoicedBalance.GoodsIssue,
	|	GoodsShippedNotInvoicedBalance.QuantityBalance
	|FROM
	|	AccumulationRegister.GoodsShippedNotInvoiced.Balance(
	|			,
	|			GoodsIssue IN
	|				(SELECT
	|					DocumentsForUpdatingStatuses.Document AS Document
	|				FROM
	|					DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses)) AS GoodsShippedNotInvoicedBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsForUpdatingStatuses.Document AS SalesInvoice,
	|	SalesInvoice.DocumentAmount AS SalesInvoiceAmount,
	|	SalesInvoice.Posted AS SalesInvoicePosted,
	|	MAX(ISNULL(SalesInvoicePaymentCalendar.PaymentDate, DATETIME(1, 1, 1))) AS PaymentDate
	|INTO SalesInvoices
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|		INNER JOIN DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		ON SalesInvoice.Ref = DocumentsForUpdatingStatuses.Document
	|		LEFT JOIN Document.SalesInvoice.PaymentCalendar AS SalesInvoicePaymentCalendar
	|		ON SalesInvoice.Ref = SalesInvoicePaymentCalendar.Ref
	|
	|GROUP BY
	|	DocumentsForUpdatingStatuses.Document,
	|	SalesInvoice.DocumentAmount,
	|	SalesInvoice.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsForUpdatingStatuses.Document AS SupplierInvoice,
	|	SupplierInvoice.DocumentAmount AS SupplierInvoiceAmount,
	|	SupplierInvoice.Posted AS SupplierInvoicePosted,
	|	MAX(ISNULL(SupplierInvoicePaymentCalendar.PaymentDate, DATETIME(1, 1, 1))) AS PaymentDate
	|INTO SupplierInvoices
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|		INNER JOIN DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		ON SupplierInvoice.Ref = DocumentsForUpdatingStatuses.Document
	|		LEFT JOIN Document.SupplierInvoice.PaymentCalendar AS SupplierInvoicePaymentCalendar
	|		ON SupplierInvoice.Ref = SupplierInvoicePaymentCalendar.Ref
	|
	|GROUP BY
	|	DocumentsForUpdatingStatuses.Document,
	|	SupplierInvoice.DocumentAmount,
	|	SupplierInvoice.Posted
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	GroupedQuotations.Quotation AS Document,
	|	CASE
	|		WHEN GroupedQuotations.SalesDocumentPosted
	|			THEN VALUE(Enum.QuotationStatuses.Completed)
	|		WHEN GroupedQuotations.ValidUntil <> DATETIME(1, 1, 1)
	|				AND GroupedQuotations.ValidUntil < &CurrentDate
	|			THEN VALUE(Enum.QuotationStatuses.Expired)
	|		ELSE VALUE(Enum.QuotationStatuses.Sent)
	|	END AS Status,
	|	CASE
	|		WHEN NOT GroupedQuotations.QuotationPosted
	|				OR GroupedQuotations.ValidUntil = DATETIME(1, 1, 1)
	|			THEN TRUE
	|		ELSE &CurrentDate > GroupedQuotations.ValidUntil
	|	END AS Delete,
	|	""QuotationStatuses"" AS RegisterName
	|FROM
	|	GroupedQuotations AS GroupedQuotations
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsDocuments.Document,
	|	CASE
	|		WHEN GoodsNotInvoiced.CountOfRecorders = 1
	|				AND NOT GoodsNotInvoiced.HasGoodsInvoicedInAdvance
	|			THEN VALUE(Enum.GoodsDocumentStatuses.NotInvoiced)
	|		WHEN ISNULL(GoodsNotInvoicedBalance.QuantityBalance, 0) = 0
	|			THEN VALUE(Enum.GoodsDocumentStatuses.Invoiced)
	|		WHEN GoodsNotInvoicedBalance.QuantityBalance > 0
	|			THEN VALUE(Enum.GoodsDocumentStatuses.PartiallyInvoiced)
	|	END,
	|	TRUE,
	|	""GoodsDocumentsStatuses""
	|FROM
	|	GoodsDocuments AS GoodsDocuments
	|		LEFT JOIN GoodsNotInvoiced AS GoodsNotInvoiced
	|		ON GoodsDocuments.Document = GoodsNotInvoiced.GoodsDocument
	|		LEFT JOIN GoodsNotInvoicedBalance AS GoodsNotInvoicedBalance
	|		ON GoodsDocuments.Document = GoodsNotInvoicedBalance.GoodsDocument
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoices.SalesInvoice,
	|	CASE
	|		WHEN ISNULL(AccountsReceivableBalance.AmountCurBalance, 0) <= 0
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInFull)
	|		WHEN SalesInvoices.PaymentDate <> DATETIME(1, 1, 1)
	|				AND &BegOfCurrentDate > SalesInvoices.PaymentDate
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.Overdue)
	|		WHEN ISNULL(AccountsReceivableBalance.AmountCurBalance, 0) < SalesInvoices.SalesInvoiceAmount
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInPart)
	|		ELSE VALUE(Enum.InvoicesPaymentStatuses.Unpaid)
	|	END,
	|	NOT SalesInvoices.SalesInvoicePosted,
	|	""InvoicesPaymentStatuses""
	|FROM
	|	SalesInvoices AS SalesInvoices
	|		LEFT JOIN AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Document IN
	|					(SELECT
	|						SalesInvoices.SalesInvoice AS SalesInvoice
	|					FROM
	|						SalesInvoices AS SalesInvoices)) AS AccountsReceivableBalance
	|		ON SalesInvoices.SalesInvoice = AccountsReceivableBalance.Document
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoices.SupplierInvoice,
	|	CASE
	|		WHEN ISNULL(AccountsPayableBalance.AmountCurBalance, 0) <= 0
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInFull)
	|		WHEN SupplierInvoices.PaymentDate <> DATETIME(1, 1, 1)
	|				AND &BegOfCurrentDate > SupplierInvoices.PaymentDate
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.Overdue)
	|		WHEN ISNULL(AccountsPayableBalance.AmountCurBalance, 0) < SupplierInvoices.SupplierInvoiceAmount
	|			THEN VALUE(Enum.InvoicesPaymentStatuses.PaidInPart)
	|		ELSE VALUE(Enum.InvoicesPaymentStatuses.Unpaid)
	|	END,
	|	NOT SupplierInvoices.SupplierInvoicePosted,
	|	""InvoicesPaymentStatuses""
	|FROM
	|	SupplierInvoices AS SupplierInvoices
	|		LEFT JOIN AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Document IN
	|					(SELECT
	|						SupplierInvoices.SupplierInvoice AS SupplierInvoice
	|					FROM
	|						SupplierInvoices AS SupplierInvoices)) AS AccountsPayableBalance
	|		ON SupplierInvoices.SupplierInvoice = AccountsPayableBalance.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	QuotationStatuses.Document AS Document,
	|	QuotationStatuses.Status AS Status
	|FROM
	|	Quotations AS Quotations
	|		INNER JOIN InformationRegister.QuotationStatuses AS QuotationStatuses
	|		ON (QuotationStatuses.Document = Quotations.Quotation)
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsDocumentsStatuses.Document,
	|	GoodsDocumentsStatuses.Status
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN InformationRegister.GoodsDocumentsStatuses AS GoodsDocumentsStatuses
	|		ON DocumentsForUpdatingStatuses.Document = GoodsDocumentsStatuses.Document
	|
	|UNION ALL
	|
	|SELECT
	|	InvoicesPaymentStatuses.Document,
	|	InvoicesPaymentStatuses.Status
	|FROM
	|	DocumentsForUpdatingStatuses AS DocumentsForUpdatingStatuses
	|		INNER JOIN InformationRegister.InvoicesPaymentStatuses AS InvoicesPaymentStatuses
	|		ON DocumentsForUpdatingStatuses.Document = InvoicesPaymentStatuses.Document";
	
	Query.SetParameter("CurrentDate", CurrentDate());
	Query.SetParameter("BegOfCurrentDate", BegOfDay(CurrentDate()));
	
	Return Query.ExecuteBatch();

EndFunction

#EndRegion

#Region ProceduresAndFunctionsOfDocumentHeaderFilling

// Procedure is designed to fill in
// the documents general attributes. It is called in the OnCreateAtServer event handlers in the form modules of all documents.
//
// Parameters:
//  DocumentObject					- object of the edited document;
//  OperationKind						- optional, operation kind row ("Purchase"
// 									or "Sell") if it is not passed, the attributes that depend on the operation type are not filled in
//
//  ParameterCopiedObject		- REF in document copying either structure with
//  data copying BasisParameter				- ref to base document or a structure with copying data
//
Procedure FillDocumentHeader(Object,
	OperationKind = "",
	ParameterCopyingValue = Undefined,
	BasisParameter = Undefined,
	PostingIsAllowed,
	FillingValues = Undefined) Export
	
	User 		= Users.CurrentUser();
	DocumentMetadata = Object.Ref.Metadata();
	PostingIsAllowed = DocumentMetadata.Posting = Metadata.ObjectProperties.Posting.Allow;
	
	If ValueIsFilled(BasisParameter)
		AND Not TypeOf(BasisParameter) = Type("Structure") Then
		
		BasisDocumentMetadata = BasisParameter.Metadata();
		
	EndIf;
	
	If ValueIsFilled(ParameterCopyingValue) 
		AND Not TypeOf(ParameterCopyingValue) = Type("Structure") Then
		
		CopyingDocumentMetadata =  ParameterCopyingValue.Metadata();
		
	EndIf;
	
	If Not ValueIsFilled(Object.Ref) Then
		
		Object.Author				= User;
		
		If Not ValueIsFilled(ParameterCopyingValue)
		   AND IsDocumentAttribute("DocumentCurrency", Object.Ref.Metadata()) Then
			
			If Not ValueIsFilled(Object.DocumentCurrency) Then
				
				Object.DocumentCurrency = Constants.FunctionalCurrency.Get();
				
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(ParameterCopyingValue)
		   AND IsDocumentAttribute("CashCurrency", Object.Ref.Metadata()) Then
			
			If Not ValueIsFilled(Object.CashCurrency) Then
				
				Object.CashCurrency = Constants.FunctionalCurrency.Get();
				
			EndIf;
			
		EndIf;
		
		If IsDocumentAttribute("SettlementsCurrency", Object.Ref.Metadata()) Then
			
			If Not ValueIsFilled(Object.SettlementsCurrency) Then
				
				Object.SettlementsCurrency = Constants.FunctionalCurrency.Get();
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	//  Exceptions
	If DocumentMetadata.Name = "SalesSlip"
	OR DocumentMetadata.Name = "ProductReturn" Then
	
		If Not ValueIsFilled(Object.Ref)
			AND IsDocumentAttribute("Responsible", DocumentMetadata)
			AND Not (FillingValues <> Undefined 
				AND FillingValues.Property("Responsible") 
				AND ValueIsFilled(FillingValues.Responsible))
			AND Not ValueIsFilled(Object.Responsible) Then
			
			Object.Responsible = 
				DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
			
		EndIf;
		
		Return;
		
	EndIf;
	
	//  Filling
	If Not ValueIsFilled(Object.Ref) Then
		
		If IsDocumentAttribute("AmountIncludesVAT", DocumentMetadata) Then 					// Document has the AmountIncludesVAT attribute
			
			If ValueIsFilled(BasisParameter) 												// Fill in if the base parameter is filled in
				AND Not TypeOf(BasisParameter) = Type("Structure")									// (in some cases, a structure is passed instead of a document ref)
				AND IsMetadataKindDocument(BasisDocumentMetadata.Name) 						// and base is a document and not, for example, a catalog
				AND IsDocumentAttribute("AmountIncludesVAT", BasisDocumentMetadata) Then 	// that has the similar attribute "AmountIncludesVAT"
				
				Object.AmountIncludesVAT = BasisParameter.AmountIncludesVAT;
				
			ElsIf ValueIsFilled(ParameterCopyingValue) 								// Fill in if the copying parameter is filled in.
				AND Not TypeOf(ParameterCopyingValue) = Type("Structure")							// (in some cases, a structure is passed instead of a document ref)
				AND IsMetadataKindDocument(CopyingDocumentMetadata.Name)						// and is a document 
				AND IsDocumentAttribute("AmountIncludesVAT", CopyingDocumentMetadata) Then	// that has the similar attribute "AmountIncludesVAT"
				
				Object.AmountIncludesVAT = ParameterCopyingValue.AmountIncludesVAT;
				
			EndIf;
			
		EndIf;
		
		If Not ValueIsFilled(ParameterCopyingValue) Then
			
			If DocumentMetadata.Name = "ShiftClosure" Then
				If IsDocumentAttribute("PositionAssignee", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "PositionAssignee");
					If ValueIsFilled(SettingValue) Then
						If Object.PositionAssignee <> SettingValue Then
							Object.PositionAssignee = SettingValue;
						EndIf;
					Else
						Object.PositionAssignee = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
				If IsDocumentAttribute("PositionResponsible", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "PositionResponsible");
					If ValueIsFilled(SettingValue) Then
						If Object.PositionResponsible <> SettingValue Then
							Object.PositionResponsible = SettingValue;
						EndIf;
					Else
						Object.PositionResponsible = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
				Return;
			EndIf;
			
			If IsDocumentAttribute("Company", DocumentMetadata) 
				AND Not (FillingValues <> Undefined AND FillingValues.Property("Company") AND ValueIsFilled(FillingValues.Company))
				AND Not (ValueIsFilled(BasisParameter)
				AND ValueIsFilled(Object.Company)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainCompany");
				If ValueIsFilled(SettingValue) Then
					If Object.Company <> SettingValue Then
						Object.Company = SettingValue;
					EndIf;
				Else
					Object.Company = GetPredefinedCompany();
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("SalesStructuralUnit", DocumentMetadata) 
				AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.SalesStructuralUnit)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				
				If ValueIsFilled(SettingValue) Then
					If Object.SalesStructuralUnit <> SettingValue Then
						Object.SalesStructuralUnit = SettingValue;
					EndIf;
				Else
					Object.SalesStructuralUnit = Catalogs.BusinessUnits.MainDepartment;	
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("Department", DocumentMetadata) 
				AND Not (FillingValues <> Undefined AND FillingValues.Property("Department") AND ValueIsFilled(FillingValues.Department))
				AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.Department)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				If ValueIsFilled(SettingValue) Then
					If Object.Department <> SettingValue Then
						Object.Department = SettingValue;
					EndIf;
				Else
					Object.Department = Catalogs.BusinessUnits.MainDepartment;
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("DocumentCurrency", DocumentMetadata)
				AND Not ValueIsFilled(Object.DocumentCurrency)
				AND Not (FillingValues <> Undefined
				    AND FillingValues.Property("DocumentCurrency")
				    AND ValueIsFilled(FillingValues.DocumentCurrency)) Then
				Object.DocumentCurrency = Constants.FunctionalCurrency.Get();
			EndIf;
			
			If DocumentMetadata.Name = "ObsoleteWorkOrder"
			 OR DocumentMetadata.Name = "PurchaseOrder"
			 OR DocumentMetadata.Name = "Payroll"
			 OR DocumentMetadata.Name = "SalesTarget"
			 OR DocumentMetadata.Name = "PayrollSheet"
			 OR DocumentMetadata.Name = "OtherExpenses"
			 OR DocumentMetadata.Name = "CostAllocation"
			 OR DocumentMetadata.Name = "JobSheet"
			 OR DocumentMetadata.Name = "Timesheet"
			 OR DocumentMetadata.Name = "WeeklyTimesheet"
			 Then
				If IsDocumentAttribute("StructuralUnit", DocumentMetadata) 
					AND Not (FillingValues <> Undefined AND FillingValues.Property("StructuralUnit") AND ValueIsFilled(FillingValues.StructuralUnit))
					AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.StructuralUnit)) Then
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
					If ValueIsFilled(SettingValue) 
						AND StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = Catalogs.BusinessUnits.MainDepartment;	
					EndIf;
						
				EndIf;
			EndIf;
				
			If IsDocumentAttribute("StructuralUnitReserve", DocumentMetadata) 
				AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.StructuralUnitReserve)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
				If ValueIsFilled(SettingValue) 
					AND StructuralUnitTypeToChoiceParameters("StructuralUnitReserve", DocumentMetadata, SettingValue) Then
					If Object.StructuralUnitReserve <> SettingValue Then
						Object.StructuralUnitReserve = SettingValue;
					EndIf;
				Else
					Object.StructuralUnitReserve = Catalogs.BusinessUnits.MainWarehouse;	
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "AdditionalExpenses"
			 OR DocumentMetadata.Name = "Stocktaking"
			 OR DocumentMetadata.Name = "InventoryIncrease"
			 OR DocumentMetadata.Name = "SubcontractorReportIssued"
			 OR DocumentMetadata.Name = "SubcontractorReport"
			 OR DocumentMetadata.Name = "IntraWarehouseTransfer"
			 OR DocumentMetadata.Name = "FixedAssetRecognition"
			 OR DocumentMetadata.Name = "SupplierInvoice"
			 OR DocumentMetadata.Name = "SalesInvoice"
			 OR DocumentMetadata.Name = "InventoryWriteOff"
			 Then
				If IsDocumentAttribute("StructuralUnit", DocumentMetadata) 
					AND Not (FillingValues <> Undefined AND FillingValues.Property("StructuralUnit") AND ValueIsFilled(FillingValues.StructuralUnit))
					AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.StructuralUnit)) Then
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
					If ValueIsFilled(SettingValue) 
						AND StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "Production" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				If Not (FillingValues <> Undefined AND FillingValues.Property("StructuralUnit") AND ValueIsFilled(FillingValues.StructuralUnit))
					AND Not (ValueIsFilled(BasisParameter)
					AND ValueIsFilled(Object.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						AND StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = Catalogs.BusinessUnits.MainDepartment;	
					EndIf;
				EndIf;
				
				// business unit of products.
				If Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.ProductsStructuralUnit)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferRecipient)
						AND (Object.StructuralUnit.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
							OR Object.StructuralUnit.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Department) Then
						Object.ProductsStructuralUnit = Object.StructuralUnit.TransferRecipient;
						Object.ProductsCell = Object.StructuralUnit.TransferRecipientCell;
					Else
						Object.ProductsStructuralUnit = Object.StructuralUnit;
					EndIf;
				EndIf;
						
				// Inventory business unit.
				If Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.InventoryStructuralUnit)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferSource)
						AND (Object.StructuralUnit.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
							OR Object.StructuralUnit.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department) Then
						Object.InventoryStructuralUnit = Object.StructuralUnit.TransferSource;
						Object.CellInventory = Object.StructuralUnit.TransferSourceCell;
					Else
						Object.InventoryStructuralUnit = Object.StructuralUnit;
					EndIf;
				EndIf;
				
				// business unit of waste.
				If Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.DisposalsStructuralUnit)) Then
					If ValueIsFilled(Object.StructuralUnit.RecipientOfWastes) Then
						Object.DisposalsStructuralUnit = Object.StructuralUnit.RecipientOfWastes;
						Object.DisposalsCell = Object.StructuralUnit.DisposalsRecipientCell;
					Else
						Object.DisposalsStructuralUnit = Object.StructuralUnit;
					EndIf;
				EndIf;
				
			EndIf;
			
			If DocumentMetadata.Name = "InventoryTransfer" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
				If Not (FillingValues <> Undefined AND FillingValues.Property("StructuralUnit") AND ValueIsFilled(FillingValues.StructuralUnit))
					AND Not (ValueIsFilled(BasisParameter) 
					AND ValueIsFilled(Object.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						AND StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
					EndIf;
				EndIf;
				
				// business unit receiver.
				If Not (FillingValues <> Undefined AND FillingValues.Property("StructuralUnitPayee") AND ValueIsFilled(FillingValues.StructuralUnitPayee))
					AND Not (ValueIsFilled(BasisParameter) 
					AND ValueIsFilled(Object.StructuralUnitPayee)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferRecipient) Then
						Object.StructuralUnitPayee = Object.StructuralUnit.TransferRecipient;
						Object.CellPayee = Object.StructuralUnit.TransferRecipientCell;
					EndIf;
				EndIf;
				
			EndIf;
			
			If DocumentMetadata.Name = "ProductionOrder" Then
				
				// business unit.
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
				If Not (ValueIsFilled(BasisParameter) 
					AND ValueIsFilled(Object.StructuralUnit))
					AND Not (FillingValues <> Undefined AND FillingValues.Property("StructuralUnit") AND ValueIsFilled(FillingValues.StructuralUnit)) Then
					If ValueIsFilled(SettingValue) 
						AND StructuralUnitTypeToChoiceParameters("StructuralUnit", DocumentMetadata, SettingValue) Then
						If Object.StructuralUnit <> SettingValue Then
							Object.StructuralUnit = SettingValue;
						EndIf;
					Else
						Object.StructuralUnit = Catalogs.BusinessUnits.MainDepartment;	
					EndIf;
				EndIf;
				
				// business unit of reserve.
				If Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.StructuralUnitReserve)) Then
					If ValueIsFilled(Object.StructuralUnit.TransferSource) Then
						Object.StructuralUnitReserve = Object.StructuralUnit.TransferSource;
					EndIf;
				EndIf;
				
			EndIf;
			
			If IsDocumentAttribute("Responsible", DocumentMetadata)
				AND Not (FillingValues <> Undefined AND FillingValues.Property("Responsible") AND ValueIsFilled(FillingValues.Responsible))
				AND Not ValueIsFilled(Object.Responsible) Then
				Object.Responsible = DriveReUse.GetValueByDefaultUser(User, "MainResponsible");
			EndIf;
			
			If IsDocumentAttribute("PriceKind", DocumentMetadata)
			   AND DocumentMetadata.Name <> "ShiftClosure"
			   AND DocumentMetadata.Name <> "SalesSlip"
			   AND DocumentMetadata.Name <> "ProductReturn" 
			   AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.PriceKind)) Then
				SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainPriceTypesales");
				If ValueIsFilled(SettingValue) Then
					If Object.PriceKind <> SettingValue Then
						Object.PriceKind = SettingValue;
					EndIf;
				Else
					Object.PriceKind = Catalogs.PriceTypes.Wholesale;
				EndIf;
			EndIf;
			
			If IsDocumentAttribute("PriceKind", DocumentMetadata)
			   AND ValueIsFilled(Object.PriceKind) 
			   AND Not ValueIsFilled(BasisParameter) Then
				If IsDocumentAttribute("AmountIncludesVAT", DocumentMetadata) Then
					Object.AmountIncludesVAT = Object.PriceKind.PriceIncludesVAT;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "ProductionOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					AND Not (FillingValues <> Undefined AND FillingValues.Property("OrderState") AND ValueIsFilled(FillingValues.OrderState))
					AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.OrderState)) Then
					If Constants.UseProductionOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewProductionOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.ProductionOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.ProductionOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "PurchaseOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					AND Not (FillingValues <> Undefined AND FillingValues.Property("OrderState") AND ValueIsFilled(FillingValues.OrderState))
					AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.OrderState)) Then
					If Constants.UsePurchaseOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewPurchaseOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.PurchaseOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.PurchaseOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SalesOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					AND Not (FillingValues <> Undefined AND FillingValues.Property("OrderState") AND ValueIsFilled(FillingValues.OrderState))
					AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.OrderState)) Then
					If Constants.UseSalesOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSalesOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.SalesOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.SalesOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "PurchaseOrder" Then
				If IsDocumentAttribute("ReceiptDatePosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "ReceiptDatePositionInPurchaseOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.ReceiptDatePosition <> SettingValue Then
							Object.ReceiptDatePosition = SettingValue;
						EndIf;
					Else
						Object.ReceiptDatePosition = Enums.AttributeStationing.InHeader;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "ObsoleteWorkOrder" Then
				If IsDocumentAttribute("WorkKindPosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "WorkKindPositionInWorkTask");
					If ValueIsFilled(SettingValue) Then
						If Object.WorkKindPosition <> SettingValue Then
							Object.WorkKindPosition = SettingValue;
						EndIf;
					Else
						Object.WorkKindPosition = Enums.AttributeStationing.InHeader;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SalesOrder" Then
				If IsDocumentAttribute("ShipmentDatePosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "ShipmentDatePositionInSalesOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.ShipmentDatePosition <> SettingValue Then
							Object.ShipmentDatePosition = SettingValue;
						EndIf;
					Else
						Object.ShipmentDatePosition = Enums.AttributeStationing.InHeader;	
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "SupplierInvoice" Then
				If IsDocumentAttribute("PurchaseOrderPosition", DocumentMetadata)
					
					AND Not (FillingValues <> Undefined
					AND FillingValues.Property("PurchaseOrderPosition")
					AND ValueIsFilled(FillingValues.PurchaseOrderPosition))
					
					AND Not (ValueIsFilled(BasisParameter) 
					AND ValueIsFilled(Object.PurchaseOrderPosition)
					AND Object.PurchaseOrderPosition = Enums.AttributeStationing.InTabularSection) Then
					
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "PurchaseOrderPositionInReceiptDocuments");
					If ValueIsFilled(SettingValue) Then
						If Object.PurchaseOrderPosition <> SettingValue Then
							Object.PurchaseOrderPosition = SettingValue;
						EndIf;
					Else
						Object.PurchaseOrderPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "InventoryTransfer" Then
				If IsDocumentAttribute("SalesOrderPosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "SalesOrderPositionInInventoryTransfer");
					If ValueIsFilled(SettingValue) Then
						If Object.SalesOrderPosition <> SettingValue Then
							Object.SalesOrderPosition = SettingValue;
						EndIf;
					Else
						Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "ProductionOrder" Then
				If IsDocumentAttribute("UseCompanyResources", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseCompanyResourcesInProductionOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseCompanyResources <> SettingValue Then
							Object.UseCompanyResources = SettingValue;
						EndIf;
					Else
						Object.UseCompanyResources = True;
					EndIf;
				EndIf;
			EndIf;
			
			If DocumentMetadata.Name = "WorkOrder" Then
				If IsDocumentAttribute("OrderState", DocumentMetadata) 
					AND Not (FillingValues <> Undefined AND FillingValues.Property("OrderState") AND ValueIsFilled(FillingValues.OrderState))
					AND Not (ValueIsFilled(BasisParameter) AND ValueIsFilled(Object.OrderState)) Then
					If Constants.UseSalesOrderStatuses.Get() Then
						SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewWorkOrder");
						If ValueIsFilled(SettingValue) Then
							If Object.OrderState <> SettingValue Then
								Object.OrderState = SettingValue;
							EndIf;
						Else
							Object.OrderState = Catalogs.WorkOrderStatuses.Open;
						EndIf;
					Else
						Object.OrderState = Constants.WorkOrdersInProgressStatus.Get();
					EndIf;
				EndIf;
				If IsDocumentAttribute("WorkKindPosition", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "WorkKindPositionInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.WorkKindPosition <> SettingValue Then
							Object.WorkKindPosition = SettingValue;
						EndIf;
					Else
						Object.WorkKindPosition = Enums.AttributeStationing.InHeader;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseProducts", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseProductsInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseProducts <> SettingValue Then
							Object.UseProducts = SettingValue;
						EndIf;
					Else
						Object.UseProducts = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseCompanyResources", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseCompanyResourcesInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseCompanyResources <> SettingValue Then
							Object.UseCompanyResources = SettingValue;
						EndIf;
					Else
						Object.UseCompanyResources = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseConsumerMaterials", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseConsumerMaterialsInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseConsumerMaterials <> SettingValue Then
							Object.UseConsumerMaterials = SettingValue;
						EndIf;
					Else
						Object.UseConsumerMaterials = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UseMaterials", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UseMaterialsInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UseMaterials <> SettingValue Then
							Object.UseMaterials = SettingValue;
						EndIf;
					Else
						Object.UseMaterials = True;
					EndIf;
				EndIf;
				If IsDocumentAttribute("UsePerformerSalaries", DocumentMetadata) Then 
					SettingValue = DriveReUse.GetValueByDefaultUser(User, "UsePerformerSalariesInWorkOrder");
					If ValueIsFilled(SettingValue) Then
						If Object.UsePerformerSalaries <> SettingValue Then
							Object.UsePerformerSalaries = SettingValue;
						EndIf;
					Else
						Object.UsePerformerSalaries = True;
					EndIf;
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	
EndProcedure

// Function returns predefined company.
//
Function GetPredefinedCompany() Export
	
	Query = New Query;
	Query.Text =
	"SELECT ALLOWED
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies
	|WHERE
	|	Companies.Predefined";
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		Return Selection.Company;
	Else	
		Return Catalogs.Companies.EmptyRef();
	EndIf;	
	
EndFunction

// The function returns a default specification for products, characteristics.
//
Function GetDefaultSpecification(Products, Characteristic = Undefined) Export
	
	DefaultSpecification = Products.Specification;
	
	If ValueIsFilled(DefaultSpecification) Then
		If GetFunctionalOption("UseCharacteristics") Then
			ProductCharacteristic = ?(ValueIsFilled(Characteristic), Characteristic, Catalogs.ProductsCharacteristics.EmptyRef());
			If DefaultSpecification.ProductCharacteristic = ProductCharacteristic Then
				Return DefaultSpecification;
			EndIf;
		Else
			Return DefaultSpecification;
		EndIf;
	EndIf;
	
	Return Catalogs.BillsOfMaterials.EmptyRef();
	
EndFunction

// Gets the default contract depending on the account details.
//
Function GetContractByDefault(Document, Counterparty, Company, OperationKind) Export
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationKind);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

#EndRegion

#Region ExportProceduresAndFunctions

Procedure CheckAvailabilityOfGoodsReturn(GoodsReturn, Cancel = False) Export
	
	AccountingPolicy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(GoodsReturn.Date, GoodsReturn.Company);
	UseGoodsReturnFromCustomer = AccountingPolicy.UseGoodsReturnFromCustomer;
	UseGoodsReturnToSupplier = AccountingPolicy.UseGoodsReturnToSupplier;
	
	If GoodsReturn.OperationKind = Enums.OperationTypesGoodsReturn.FromCustomer
		AND Not UseGoodsReturnFromCustomer Then
		MessageText = NStr("en = '""Use Goods returns from customer"" option is turned off for this company at this period.
		                   |To create a new setting please go to Company - Accounting policy.'");
	ElsIf GoodsReturn.OperationKind = Enums.OperationTypesGoodsReturn.ToSupplier
		AND Not UseGoodsReturnToSupplier Then
		MessageText = NStr("en = '""Use Goods returns to supplier"" option is turned off for this company at this period.
		                   |To create a new setting please go to Company - Accounting policy.'");
	EndIf;
	
	If ValueIsFilled(MessageText) Then
		CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
EndProcedure

Procedure CheckBasis(DataStructure, BasisDocument, Cancel) Export
	
	MessageText = "";
	Ref = DataStructure.Ref;
	
	If TypeOf(Ref) = Type("DocumentRef.CreditNote") Then
		
		If TypeOf(BasisDocument) = Type("DocumentRef.SalesInvoice") Then
			If DataStructure.Inventory.Count() = 0 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'All goods from %1 have been claimed for return.'"),
					BasisDocument);
			EndIf;
		EndIf;
		
	ElsIf TypeOf(Ref) = Type("DocumentRef.DebitNote") Then
		
		If TypeOf(BasisDocument) = Type("DocumentRef.SupplierInvoice") Then
			If DataStructure.Inventory.Count() = 0 Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'All goods from %1 have been claimed for return.'"),
					BasisDocument);
			EndIf;
		EndIf;
		
	EndIf;
	
	If ValueIsFilled(MessageText) Then
		CommonUseClientServer.MessageToUser(MessageText,,,,Cancel);
	EndIf;
	
EndProcedure

// Displays a message on filling error.
//
Procedure ShowMessageAboutError(ErrorObject, MessageText, TabularSectionName = Undefined, LineNumber = Undefined, Field = Undefined, Cancel = False) Export
	
	Message = New UserMessage();
	Message.Text = MessageText;
	
	If TabularSectionName <> Undefined Then
		Message.Field = TabularSectionName + "[" + (LineNumber - 1) + "]." + Field;
	ElsIf ValueIsFilled(Field) Then
		Message.Field = Field;
	EndIf;
	
	Message.SetData(ErrorObject);
	
	Message.Message();
	
	Cancel = True;
	
EndProcedure

// Allows to determine whether there is attribute
// with the passed name among the document header attributes.
//
// Parameters: 
//  AttributeName - desired attribute row
// name, DocumentMetadata - document metadata description object among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function IsDocumentAttribute(AttributeName, DocumentMetadata) Export

	Return Not (DocumentMetadata.Attributes.Find(AttributeName) = Undefined);

EndFunction

// Allows to determine whether there is attribute
// with the passed name among the document header attributes.
//
// Parameters: 
//  AttributeName - desired attribute row
// name, DocumentMetadata - document metadata description object among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function DocumentAttributeExistsOnLink(AttributeName, DocumentRef) Export

	DocumentMetadata = DocumentRef.Metadata();
	Return Not (DocumentMetadata.Attributes.Find(AttributeName) = Undefined);

EndFunction

// Checks if row contains list separator or receives it from constant.
//
// Parameters: 
//  CheckString - String - String for check.
//
// Returns:
//  String - Character that separates list lines.
//
Function GetListSeparator(CheckString = "") Export
	
	If ValueIsFilled(CheckString) Then
		FormattedString = StringFunctionsClientServer.ReplaceSomeCharactersWithAnothers(" ", Lower(CheckString), "");
		
		If StrStartsWith(FormattedString, "sep=") Then
			ListSeparator =  Mid(FormattedString, 5, 1);
		Else
			ListSeparator = Constants.ListSeparator.Get();
		EndIf;
	Else
		ListSeparator = Constants.ListSeparator.Get();
	EndIf;
	
	Return ListSeparator;
	
EndFunction

// Checks whether business unit meets selection
// parameters of attribute with the passed name.
//
// Parameters: 
//  AttributeName - desired attribute row
// name, DocumentMetadata - document metadata description object among attributes of which the search is executed.
//
// Returns:
//  True - if you find attribute with the same name, False - did not find.
//
Function StructuralUnitTypeToChoiceParameters(AttributeName, DocumentMetadata, SettingValue)

	ChoiceParameters = DocumentMetadata.Attributes[AttributeName].ChoiceParameters;
	StructuralUnitType = SettingValue.StructuralUnitType;
	For Each ChoiceParameter In ChoiceParameters Do
		If ChoiceParameter.Name = "Filter.StructuralUnitType" Then
			If TypeOf(ChoiceParameter.Value) = Type("FixedArray") Then
				For Each ParameterValue In ChoiceParameter.Value Do
					If StructuralUnitType = ParameterValue Then
						Return True;
					EndIf; 
				EndDo;
			ElsIf TypeOf(ChoiceParameter.Value) = Type("EnumRef.BusinessUnitsTypes") 
				AND StructuralUnitType = ChoiceParameter.Value Then
				Return True;
			EndIf; 
		EndIf; 
	EndDo;
	  
	Return False;	  

EndFunction

// The procedure deletes a checked attribute from the array of checked attributes.
Procedure DeleteAttributeBeingChecked(CheckedAttributes, CheckedAttribute) Export
	
	FoundAttribute = CheckedAttributes.Find(CheckedAttribute);
	If ValueIsFilled(FoundAttribute) Then
		CheckedAttributes.Delete(FoundAttribute);
	EndIf;
	
EndProcedure

// Procedure creates a new key of links for tables.
//
// Parameters:
//  DocumentForm - ManagedForm, contains a
//                 document form whose attributes are processed by the procedure.
//
Function CreateNewLinkKey(DocumentForm) Export

	ValueList = New ValueList;
	
	TabularSection = DocumentForm.Object[DocumentForm.TabularSectionName];
	For Each TSRow In TabularSection Do
        ValueList.Add(TSRow.ConnectionKey);
	EndDo;

    If ValueList.Count() = 0 Then
		ConnectionKey = 1;
	Else
		ValueList.SortByValue();
		ConnectionKey = ValueList.Get(ValueList.Count() - 1).Value + 1;
	EndIf;

	Return ConnectionKey;

EndFunction

// Procedure writes user new setting.
//
Procedure SetUserSetting(SettingValue, SettingName, User = Undefined) Export
	
	If Not ValueIsFilled(User) Then
		
		User = Users.AuthorizedUser();
		
	EndIf;
	
	RecordSet = InformationRegisters.UserSettings.CreateRecordSet();

	RecordSet.Filter.User.Use	= True;
	RecordSet.Filter.User.Value		= User;
	RecordSet.Filter.Setting.Use		= True;
	RecordSet.Filter.Setting.Value			= ChartsOfCharacteristicTypes.UserSettings[SettingName];

	Record = RecordSet.Add();

	Record.User	= User;
	Record.Setting	= ChartsOfCharacteristicTypes.UserSettings[SettingName];
	Record.Value		= ChartsOfCharacteristicTypes.UserSettings[SettingName].ValueType.AdjustValue(SettingValue);
	
	RecordSet.Write();
	
	RefreshReusableValues();
	
EndProcedure

// Function returns the related User employees for the passed record
//
// User - (Catalog.Users) User for whom a value table with records is received
//
Function GetUserEmployees(User) Export
	
	Query = New Query("SELECT TOP 1 * FROM InformationRegister.UserEmployees AS UserEmployees WHERE UserEmployees.User = &User");
	Query.SetParameter("User", User);
	QueryResult = Query.Execute();
	
	Return ?(QueryResult.IsEmpty(), New ValueTable, QueryResult.Unload());
	
EndFunction

// Procedure sets conditional design.
//
Procedure MarkMainItemWithBold(SelectedItem, List, SettingName = "MainItem") Export
	
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = SettingName Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	If Not ValueIsFilled(SelectedItem) Then
		Return;
	EndIf;
	
	ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
	
	FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
	
	FilterItem.LeftValue = New DataCompositionField("Ref");
	FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
	FilterItem.RightValue = SelectedItem;
	
	ConditionalAppearanceItem.Appearance.SetParameterValue("Font", New Font(, , True));
	ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
	ConditionalAppearanceItem.UserSettingID = SettingName;
	ConditionalAppearanceItem.Presentation = "Selection of main item";
	
EndProcedure

// Function receives greatest common denominator of two numbers.
//
Function GetGCD(a, b)
	
	Return ?(b = 0, a, GetGCD(b, a % b));
	
EndFunction

// Function receives greatest common denominator for array.
//
Function GetGCDForArray(NumbersArray, Multiplicity) Export
	
	If NumbersArray.Count() = 0 Then
		Return 0;
	EndIf;
	
	GCD = NumbersArray[0] * Multiplicity;
	
	For Each Ct In NumbersArray Do
		GCD = GetGCD(GCD, Ct * Multiplicity);
	EndDo;
	
	Return GCD;
	
EndFunction

// Function checks whether profile is set for user.
//
Function ProfileSetForUser(User = Undefined, ProfileId = "", Profile = Undefined) Export
	
	If User = Undefined Then
		User = Users.CurrentUser();
	EndIf;

	If Profile = Undefined Then
		Profile = Catalogs.AccessGroupsProfiles.GetRef(New UUID(ProfileId));
	EndIf;
	
	Query = New Query;
	Query.SetParameter("User", User);
	Query.SetParameter("Profile", Profile);
	
	Query.Text =
	"SELECT
	|	AccessGroupsUsers.User
	|FROM
	|	Catalog.AccessGroups.Users AS AccessGroupsUsers
	|WHERE
	|	(NOT AccessGroupsUsers.Ref.DeletionMark)
	|	AND AccessGroupsUsers.User = &User
	|	AND (AccessGroupsUsers.Ref.Profile = &Profile
	|			OR AccessGroupsUsers.Ref.Profile = VALUE(Catalog.AccessGroupsProfiles.Administrator))";
	
	SetPrivilegedMode(True);
	Result = Query.Execute().Select();
	SetPrivilegedMode(False);
	
	If Result.Next() Then
		Return True;
	Else
		Return False;
	EndIf;
	
EndFunction

// Function checks users’ administrative rights
//
//
Function InfobaseUserWithFullAccess(User = Undefined,
                                    CheckSystemAdministrationRights = False,
                                    ForPrivilegedMode = True) Export
	// Used as replacement:
	// DriveServer.ProfileSetForUser(, , PredefinedValue("Catalog.AccessGroupsProfiles.Administrator"))
	
	Return Users.InfobaseUserWithFullAccess(User, CheckSystemAdministrationRights, ForPrivilegedMode);
	
EndFunction

// Procedure adds structure values to the values list
//
// ValueList - values list to which structure values will be added;
// StructureWithValues - structure values of which will be added to the values list;
// AddDuplicates - check box that adjusts adding 
//
Procedure StructureValuesToValuesList(ValueList, StructureWithValues, AddDuplicates = False) Export
	
	For Each StructureItem In StructureWithValues Do
		
		If Not ValueIsFilled(StructureItem.Value) OR 
			(NOT AddDuplicates AND Not ValueList.FindByValue(StructureItem.Value) = Undefined) Then
			
			Continue;
			
		EndIf;
		
		ValueList.Add(StructureItem.Value, StructureItem.Key);
		
	EndDo;
	
EndProcedure

// Receives contact persons of a counterparty by the counterparty
//
Function GetCounterpartyContactPersons(Counterparty) Export
	
	ContactPersonsList = New ValueList;
	
	Query = New Query("SELECT * FROM Catalog.ContactPersons AS ContactPersons WHERE ContactPersons.Owner = &Counterparty");
	Query.SetParameter("Counterparty", Counterparty);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		
		ContactPersonsList.Add(Selection.Ref);
		
	EndDo;
	
	Return ContactPersonsList;
	
EndFunction

// Subscription to events during document copying.
//
Procedure OnCopyObject(Source) Export
	
	If Not IsBlankString(Source.Comment) Then
		Source.Comment = "";
	EndIf;
	
EndProcedure

// Receives TS row presentation for display in the Content field.
//
Function GetContentText(Products, Characteristic = Undefined) Export
	
	ContentTemplate = GetProductsPresentationForPrinting(
						?(ValueIsFilled(Products.DescriptionFull), Products.DescriptionFull, Products.Description),
						Characteristic, Products.SKU);
	
	Return ContentTemplate;
	
EndFunction

// Function - Reference to binary file data.
//
// Parameters:
//  AttachedFile - CatalogRef - reference to catalog with name "*AttachedFiles".
//  FormID - UUID - Form ID, which is used in the preparation of binary file data.
// 
// Returned value:
//   - String - address in temporary storage; 
//   - Undefined, if you can not get the data.
//
Function ReferenceToBinaryFileData(AttachedFile, FormID) Export
	
	SetPrivilegedMode(True);
	Try
		Return AttachedFiles.GetFileData(AttachedFile, FormID).FileBinaryDataRef;
	Except
		Return Undefined;
	EndTry;
	
EndFunction

Function CalculateSubtotal(Table, AmountIncludesVAT, CountFreightServices = True) Export
	
	DocumentSubtotal	= 0;
	DocumentFreight		= 0;
	DocumentDiscount	= 0;
	DocumentVATAmount	= 0;
	DocumentTotal		= 0;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Table.Products AS Products,
	|	Table.Price * Table.Quantity AS Amount,
	|	Table.VATRate AS VATRate,
	|	Table.VATAmount AS VATAmount,
	|	Table.Total AS Total
	|INTO Inventory
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Inventory.Amount) AS Amount,
	|	ProductsCat.IsFreightService AS IsFreightService,
	|	SUM(CASE
	|			WHEN &AmountIncludesVAT
	|				THEN Inventory.Amount - Inventory.Amount / ((VATRates.Rate + 100) / 100)
	|			ELSE 0
	|		END) AS TrueVATAmount,
	|	SUM(Inventory.VATAmount) AS VATAmount,
	|	SUM(Inventory.Total) AS Total
	|INTO Calculation
	|FROM
	|	Inventory AS Inventory
	|		INNER JOIN Catalog.Products AS ProductsCat
	|		ON Inventory.Products = ProductsCat.Ref
	|		INNER JOIN Catalog.VATRates AS VATRates
	|		ON Inventory.VATRate = VATRates.Ref
	|
	|GROUP BY
	|	ProductsCat.IsFreightService
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Calculation.Amount - Calculation.TrueVATAmount AS Subtotal,
	|	Calculation.IsFreightService AS IsFreightService,
	|	Calculation.Total AS Total,
	|	Calculation.VATAmount AS VATAmount
	|FROM
	|	Calculation AS Calculation";
	
	Query.SetParameter("Table", Table);
	Query.SetParameter("AmountIncludesVAT", AmountIncludesVAT);
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		
		If Selection.IsFreightService AND CountFreightServices Then
			DocumentFreight = DocumentFreight + Selection.Subtotal;
		Else
			DocumentSubtotal = DocumentSubtotal + Selection.Subtotal;
		EndIf;
		
		DocumentDiscount = DocumentDiscount + Selection.Subtotal + Selection.VATAmount - Selection.Total;
		
		DocumentVATAmount	= DocumentVATAmount + Selection.VATAmount;
		DocumentTotal		= DocumentTotal + Selection.Total;
		
	EndDo;
	
	TotalsStructure = New Structure;
	TotalsStructure.Insert("DocumentSubtotal",	DocumentSubtotal);
	TotalsStructure.Insert("DocumentFreight",	DocumentFreight);
	TotalsStructure.Insert("DocumentDiscount",	DocumentDiscount);
	TotalsStructure.Insert("DocumentVATAmount",	DocumentVATAmount);
	TotalsStructure.Insert("DocumentTotal",		DocumentTotal);
	
	Return TotalsStructure;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctions

// Function receives table from the temporary table.
//
Function TableFromTemporaryTable(TempTablesManager, Table) Export
	
	Query = New Query(
	"SELECT *
	|	FROM " + Table + " AS Table");
	Query.TempTablesManager = TempTablesManager;
	
	Return Query.Execute().Unload();
	
EndFunction

// Function dependinding on the accounting flag
// by the company of company-organization or document organization.
//
// Parameters:
// Company - CatalogRef.Companies.
//
// Returns:
//  CatalogRef.Company - ref to the company.
//
Function GetCompany(Company) Export
	
	Return ?(Constants.AccountingBySubsidiaryCompany.Get(), Constants.ParentCompany.Get(), Company);
	
EndFunction

// The procedure defines the following: if when editing
// a document date, the document numbering period changes,
// the document is assigned a new unique number.
//
// Parameters:
//  DocumentRef - ref to a document from
// which procedure DocumentNewDate is called - new date of
// the DocumentInitialDate document - initial document date 
//
// Returns:
//  Number - dates difference.
//
Function CheckDocumentNumber(DocumentRef, NewDocumentDate, InitialDateOfDocument) Export
	
	// Define number change periodicity assigned for the current documents kind
	NumberChangePeriod = DocumentRef.Metadata().NumberPeriodicity;
	
	// Depending on the set numbers change
	// periodicity define the difference of an old and a new document version dates.
	If NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Year Then
		DATEDIFF = BegOfYear(InitialDateOfDocument) - BegOfYear(NewDocumentDate);
	ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Quarter Then
		DATEDIFF = BegOfQuarter(InitialDateOfDocument) - BegOfQuarter(NewDocumentDate);
	ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Month Then
		DATEDIFF = BegOfMonth(InitialDateOfDocument) - BegOfMonth(NewDocumentDate);
	ElsIf NumberChangePeriod = Metadata.ObjectProperties.DocumentNumberPeriodicity.Day Then
		DATEDIFF = InitialDateOfDocument - NewDocumentDate;
	Else
		Return 0;
	EndIf;
	
	Return DATEDIFF;
	
EndFunction

// Function defines product sale taxation type with VAT.
//
// Parameters:
// Company - CatalogRef.Companies - Company for which Warehouse
// taxation system is defined. - CatalogRef.Warehouses - Retail warehouse for which
// Date taxation system is defined - Date of taxation system definition
//
Function VATTaxation(Company, Date) Export
	
	Policy = InformationRegisters.AccountingPolicy.GetAccountingPolicy(Date, Company);
	
	Return ?(Policy.RegisteredForVAT, Enums.VATTaxationTypes.SubjectToVAT, Enums.VATTaxationTypes.NotSubjectToVAT);
	
EndFunction

Function CounterpartyVATTaxation(Counterparty, CompanyVATTaxation) Export
	
	If ValueIsFilled(Counterparty) Then
		
		CounterpartyVATTaxation = CommonUse.ObjectAttributeValue(Counterparty, "VATTaxation");
		
		If ValueIsFilled(CounterpartyVATTaxation)
			And (Not CompanyVATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT
				Or CounterpartyVATTaxation = Enums.VATTaxationTypes.ReverseChargeVAT
				Or CounterpartyVATTaxation = Enums.VATTaxationTypes.ForExport) Then
			
			Return CounterpartyVATTaxation;
			
		EndIf;
		
	EndIf;
	
	Return CompanyVATTaxation;
	
EndFunction

#EndRegion

#Region InformationPanel

// Receives required data for output to the list information panel.
//
Function InfoPanelGetData(CICurrentAttribute, InfPanelParameters) Export
	
	CIFieldList = "";
	QueryText = "";
	
	Query = New Query;
	QueryOrder = 0;
	If InfPanelParameters.Property("Counterparty") Then
		
		CIFieldList = "Phone,E_mail,Fax,RealAddress,LegAddress,MailAddress,ShippingAddress,OtherInformation";
		GenerateQueryTextCounterpartiesInfoPanel(QueryText);
		
		QueryOrder = QueryOrder + 1;
		InfPanelParameters.Counterparty = QueryOrder;
		
		Query.SetParameter("Counterparty", CICurrentAttribute);
		
		If InfPanelParameters.Property("StatementOfAccount") Then
			
			CIFieldList = CIFieldList + ",Debt,OurDebt";
			GenerateQueryTextStatementOfAccountInfoPanel(QueryText);
			
			QueryOrder = QueryOrder + 1;
			InfPanelParameters.StatementOfAccount = QueryOrder;
			
			StatementOfAccountParameters = InformationPanelGetParametersOfStatementOfAccount();
			Query.SetParameter("CompaniesList", StatementOfAccountParameters.CompaniesList);
			Query.SetParameter("ListTypesOfCalculations", StatementOfAccountParameters.ListTypesOfCalculations);
			
		EndIf;
		
		If InfPanelParameters.Property("DiscountCard") Then
			CIFieldList = CIFieldList + ",DiscountPercentByDiscountCard,SalesAmountOnDiscountCard,PeriodPresentation";
		EndIf;
		
	EndIf;
	
	If InfPanelParameters.Property("ContactPerson") Then
		
		CIFieldList = ?(IsBlankString(CIFieldList), "CLPhone,ClEmail", CIFieldList + ",CLPhone,ClEmail");
		GenerateQueryTextContactsInfoPanel(QueryText);
		
		QueryOrder = QueryOrder + 1;
		InfPanelParameters.ContactPerson = QueryOrder;
		
		If TypeOf(CICurrentAttribute) = Type("CatalogRef.Counterparties") Then
			Query.SetParameter("ContactPerson", CommonUse.GetAttributeValue(CICurrentAttribute, "ContactPerson"));
		Else
			Query.SetParameter("ContactPerson", CICurrentAttribute);
		EndIf;
		
	EndIf;
	
	Query.Text = QueryText;
	
	IPData = New Structure(CIFieldList);
	
	Result = Query.ExecuteBatch();
	
	If InfPanelParameters.Property("Counterparty") Then
		
		CISelection = Result[InfPanelParameters.Counterparty - 1].Select();
		IPData = GetDataCounterpartyInfoPanel(CISelection, IPData);
		
		If InfPanelParameters.Property("StatementOfAccount") Then
			
			DebtsSelection = Result[InfPanelParameters.StatementOfAccount - 1].Select();
			IPData = GetFillDataSettlementsInfoPanel(DebtsSelection, IPData);
			
		EndIf;
		
		If InfPanelParameters.Property("DiscountCard") Then
			
			AdditionalParameters = New Structure("GetSalesAmount, Amount, PeriodPresentation", True, 0, "");
			DiscountPercentByDiscountCard = CalculateDiscountPercentByDiscountCard(CurrentDate(), InfPanelParameters.DiscountCard, AdditionalParameters);
			IPData = GetFillDataDiscountPercentByDiscountCardInfPanel(DiscountPercentByDiscountCard, AdditionalParameters.Amount, AdditionalParameters.PeriodPresentation, IPData);
			
		EndIf;
		
	EndIf;
	
	If InfPanelParameters.Property("ContactPerson") Then
		CISelection = Result[InfPanelParameters.ContactPerson - 1].Select();
		IPData = GetDataContactPersonInfoPanel(CISelection, IPData);
	EndIf;
	
	Return IPData;
	
EndFunction

// Procedure generates query text by counterparty CI.
//
Procedure GenerateQueryTextCounterpartiesInfoPanel(QueryText)
	
	QueryText = QueryText +
	"SELECT
	|	CIKinds.Ref AS CIKind,
	|	ISNULL(CICounterparty.Presentation, """") AS CIPresentation
	|FROM
	|	Catalog.ContactInformationTypes AS CIKinds
	|		LEFT JOIN Catalog.Counterparties.ContactInformation AS CICounterparty
	|		ON (CICounterparty.Ref = &Counterparty)
	|			AND CIKinds.Ref = CICounterparty.Kind
	|WHERE
	|	CIKinds.Parent = VALUE(Catalog.ContactInformationTypes.CatalogCounterparties)
	|	AND CIKinds.Predefined
	|
	|ORDER BY
	|	CICounterparty.LineNumber";
	
EndProcedure

// Procedure generates query text by contact person CI.
//
Procedure GenerateQueryTextContactsInfoPanel(QueryText)
	
	If Not IsBlankString(QueryText) Then
		QueryText = QueryText +
		";
		|////////////////////////////////////////////////////////////////////////////////
		|";
	EndIf;
	
	QueryText = QueryText +
	"SELECT
	|	CIKinds.Ref AS CIKind,
	|	ISNULL(CIContactPersons.Presentation, """") AS CIPresentation
	|FROM
	|	Catalog.ContactInformationTypes AS CIKinds
	|		LEFT JOIN Catalog.ContactPersons.ContactInformation AS CIContactPersons
	|		ON (CIContactPersons.Ref = &ContactPerson)
	|			AND CIKinds.Ref = CIContactPersons.Kind
	|WHERE
	|	CIKinds.Parent = VALUE(Catalog.ContactInformationTypes.CatalogContactPersons)
	|	AND CIKinds.Predefined";
	
EndProcedure

// Procedure generates query text by the counterparty ArApAdjustments.
//
Procedure GenerateQueryTextStatementOfAccountInfoPanel(QueryText)
	
	QueryText = QueryText +
	";
	|////////////////////////////////////////////////////////////////////////////////
	|";
	
	QueryText = QueryText +
	"SELECT
	|	CASE
	|		WHEN AccountsPayableBalances.AmountBalance < 0
	|				AND AccountsReceivableBalances.AmountBalance > 0
	|			THEN -1 * BankAccountsPayableBalances.AmountBalance + AccountsReceivableBalances.AmountBalance
	|		WHEN AccountsPayableBalances.AmountBalance < 0
	|			THEN -AccountsPayableBalances.AmountBalance
	|		WHEN AccountsReceivableBalances.AmountBalance > 0
	|			THEN AccountsReceivableBalances.AmountBalance
	|		ELSE 0
	|	END AS CounterpartyDebt,
	|	CASE
	|		WHEN AccountsPayableBalances.AmountBalance > 0
	|				AND AccountsReceivableBalances.AmountBalance < 0
	|			THEN -1 * BankAccountsReceivableBalances.AmountBalance + AccountsPayableBalances.AmountBalance
	|		WHEN AccountsPayableBalances.AmountBalance > 0
	|			THEN AccountsPayableBalances.AmountBalance
	|		WHEN AccountsReceivableBalances.AmountBalance < 0
	|			THEN -AccountsReceivableBalances.AmountBalance
	|		ELSE 0
	|	END AS OurDebt
	|FROM
	|	AccumulationRegister.AccountsPayable.Balance(
	|			,
	|			Company IN (&CompaniesList)
	|				AND SettlementsType IN (&ListTypesOfCalculations)
	|				AND Counterparty = &Counterparty) AS AccountsPayableBalances,
	|	AccumulationRegister.AccountsReceivable.Balance(
	|			,
	|			Company IN (&CompaniesList)
	|				AND SettlementsType IN (&ListTypesOfCalculations)
	|				AND Counterparty = &Counterparty) AS AccountsReceivableBalances";
	
EndProcedure

// Function returns required parameters for ArApAdjustments calculation in inf. panels.
//
Function InformationPanelGetParametersOfStatementOfAccount()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Companies.Ref AS Company
	|FROM
	|	Catalog.Companies AS Companies";
	
	QueryResult = Query.Execute().Unload();
	CompaniesArray = QueryResult.UnloadColumn("Company");
	
	CalculationsTypesArray = New Array;
	CalculationsTypesArray.Add(Enums.SettlementsTypes.Advance);
	CalculationsTypesArray.Add(Enums.SettlementsTypes.Debt);
	
	Return New Structure("CompaniesList,CalculationsTypesList", CompaniesArray, CalculationsTypesArray);
	
EndFunction

// Receives required data about counterparty CI.
//
Function GetDataCounterpartyInfoPanel(CISelection, IPData)
	
	While CISelection.Next() Do
		
		CIPresentation = TrimAll(CISelection.CIPresentation);
		If CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyPhone") Then
			IPData.Phone = ?(IsBlankString(IPData.Phone), CIPresentation, IPData.Phone + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyEmail") Then
			IPData.E_mail = ?(IsBlankString(IPData.E_mail), CIPresentation, IPData.E_mail + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyFax") Then
			IPData.Fax = ?(IsBlankString(IPData.Fax), CIPresentation, IPData.Fax + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyActualAddress") Then
			IPData.RealAddress = ?(IsBlankString(IPData.RealAddress), CIPresentation, IPData.RealAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyLegalAddress") Then
			IPData.LegAddress = ?(IsBlankString(IPData.LegAddress), CIPresentation, IPData.LegAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyPostalAddress") Then
			IPData.MailAddress = ?(IsBlankString(IPData.MailAddress), CIPresentation, IPData.MailAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyDeliveryAddress") Then
			IPData.ShippingAddress = ?(IsBlankString(IPData.ShippingAddress), CIPresentation, IPData.ShippingAddress + Chars.LF + CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.CounterpartyOtherInformation") Then
			IPData.OtherInformation = ?(IsBlankString(IPData.OtherInformation), CIPresentation, IPData.OtherInformation + Chars.LF + CIPresentation);
		EndIf;
		
	EndDo;
	
	Return IPData;
	
EndFunction

// Receives required data about contact person CI.
//
Function GetDataContactPersonInfoPanel(CISelection, IPData)
	
	While CISelection.Next() Do
		
		CIPresentation = TrimAll(CISelection.CIPresentation);
		If CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.ContactPersonPhone") Then
			IPData.CLPhone = ?(IsBlankString(IPData.CLPhone), CIPresentation, IPData.CLPhone + ", "+ CIPresentation);
		ElsIf CISelection.CIKind = PredefinedValue("Catalog.ContactInformationTypes.ContactPersonEmail") Then
			IPData.ClEmail = ?(IsBlankString(IPData.ClEmail), CIPresentation, IPData.ClEmail + ", "+ CIPresentation);
		EndIf;
		
	EndDo;
	
	Return IPData;
	
EndFunction

// Receives necessary data about counterparty ArApAdjustments.
//
Function GetFillDataSettlementsInfoPanel(DebtsSelection, IPData)
	
	DebtsSelection.Next();
	
	IPData.Debt = DebtsSelection.CounterpartyDebt;
	IPData.OurDebt = DebtsSelection.OurDebt;
	
	Return IPData;
	
EndFunction

// Receives required data on the discount percentage by a counterparty discount card.
//
Function GetFillDataDiscountPercentByDiscountCardInfPanel(DiscountPercentByDiscountCard, SalesAmountOnDiscountCard, PeriodPresentation, IPData)
	
	IPData.DiscountPercentByDiscountCard = DiscountPercentByDiscountCard;
	IPData.SalesAmountOnDiscountCard = SalesAmountOnDiscountCard;
	IPData.PeriodPresentation = PeriodPresentation;
		
	Return IPData;
	
EndFunction

#EndRegion

#Region PostingManagement

// Fill posting mode.
//
// Parameters:
//  DocumentObject		- DocumentObject		- document object.
//  WriteMode			- DocumentWriteMode		- value of write mode.
//  PostingMode			- DocumentPostingMode	- value of posting mode.
//
Procedure SetPostingMode(DocumentObject, WriteMode, PostingMode) Export

	If DocumentObject.Posted AND WriteMode = DocumentWriteMode.Posting Then
		PostingMode = DocumentPostingMode.Regular;
	EndIf;

EndProcedure

// Initializes additional properties to post a document.
//
Procedure InitializeAdditionalPropertiesForPosting(DocumentRef, StructureAdditionalProperties) Export
	
	// IN the "AdditionalProperties" structure, properties are created with the "TablesForMovements" "ForPosting"
	// "AccountingPolicy" keys.
	
	// "TablesForMovements" - structure that will contain values table with data for movings execution.
	StructureAdditionalProperties.Insert("TableForRegisterRecords", New Structure);
	
	// "ForPosting" - structure that contains the document properties and attributes required for posting.
	StructureAdditionalProperties.Insert("ForPosting", New Structure);
	
	// Structure containing the key with the "TemporaryTablesManager" name in which value temporary tables manager is stored.
	// Contains key for each temporary table (temporary table name) and value (shows that there are records in the
	// temporary table).
	StructureAdditionalProperties.ForPosting.Insert("StructureTemporaryTables", New Structure("TempTablesManager", New TempTablesManager));
	StructureAdditionalProperties.ForPosting.Insert("DocumentMetadata", DocumentRef.Metadata());
	
	// "AccountingPolicy" - structure that contains all values of the
	// accounting policy parameters for the document time and by the organization selected in the document or by a company
	// (if accounts are kept by a company).
	StructureAdditionalProperties.Insert("AccountingPolicy", New Structure);
	
	// Query that receives document data.
	Query = New Query(
	"SELECT
	|	_Document_.Ref AS Ref,
	|	_Document_.Number AS Number,
	|	_Document_.Date AS Date,
	|   " + ?(StructureAdditionalProperties.ForPosting.DocumentMetadata.Attributes.Find("Company") <> Undefined, "_Document_.Company" , "VALUE(Catalog.Companies.EmptyRef)") + " AS Company,
	|	_Document_.PointInTime AS PointInTime,
	|	_Document_.Presentation AS Presentation
	|FROM
	|	Document." + StructureAdditionalProperties.ForPosting.DocumentMetadata.Name + " AS
	|_Document_
	|	WHERE _Document_.Ref = &DocumentRef");
	
	Query.SetParameter("DocumentRef", DocumentRef);
	
	QueryResult = Query.Execute();
	
	// Generate keys containing document data.
	For Each Column In QueryResult.Columns Do
		
		StructureAdditionalProperties.ForPosting.Insert(Column.Name);
		
	EndDo;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// Fill in values for keys containing document data.
	FillPropertyValues(StructureAdditionalProperties.ForPosting, QueryResultSelection);
	
	// Define and set point value for which document control should be executed.
	StructureAdditionalProperties.ForPosting.Insert("ControlTime", Date('00010101'));
	StructureAdditionalProperties.ForPosting.Insert("ControlPeriod", Date("39991231"));
		
	// Company setting in case of entering accounting by the company.
	StructureAdditionalProperties.ForPosting.Company = GetCompany(StructureAdditionalProperties.ForPosting.Company);
	
	// Query receiving accounting policy data.
	Query = New Query(
	"SELECT
	|	Constants.UseProjects AS UseProjects,
	|	Constants.UseStorageBins AS UseStorageBins,
	|	Constants.UseBatches AS UseBatches,
	|	Constants.UseCharacteristics AS UseCharacteristics,
	|	Constants.UseOperationsManagement AS UseOperationsManagement,
	|	Constants.UseSerialNumbers AS UseSerialNumbers,
	|	Constants.UseSerialNumbersAsInventoryRecordDetails AS SerialNumbersBalance,
	|	Constants.UseFIFO AS UseFIFO,
	|	ISNULL(AccountingPolicySliceLast.RegisteredForVAT, FALSE) AS RegisteredForVAT,
	|	ISNULL(AccountingPolicySliceLast.CashMethodOfAccounting, FALSE) AS IncomeAndExpensesAccountingCashMethod,
	|	ISNULL(AccountingPolicySliceLast.PostAdvancePaymentsBySourceDocuments, FALSE) AS PostAdvancePaymentsBySourceDocuments,
	|	ISNULL(AccountingPolicySliceLast.PostVATEntriesBySourceDocuments, TRUE) AS PostVATEntriesBySourceDocuments,
	|	ISNULL(AccountingPolicySliceLast.IssueAutomaticallyAgainstSales, FALSE) AS IssueAutomaticallyAgainstSales,
	|	ISNULL(AccountingPolicySliceLast.UseGoodsReturnFromCustomer, 0) AS UseGoodsReturnFromCustomer,
	|	ISNULL(AccountingPolicySliceLast.UseGoodsReturnToSupplier, 0) AS UseGoodsReturnToSupplier,
	|	ISNULL(AccountingPolicySliceLast.InventoryValuationMethod, 0) AS InventoryValuationMethod
	|FROM
	|	Constants AS Constants
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast(&Date, Company = &Company) AS AccountingPolicySliceLast
	|		ON (TRUE)");
	Query.SetParameter("Company",	DocumentRef.Company);
	Query.SetParameter("Date",		DocumentRef.Date);
	
	QueryResult = Query.Execute();
	
	// Generate keys containing accounting policy data.
	For Each Column In QueryResult.Columns Do
		StructureAdditionalProperties.AccountingPolicy.Insert(Column.Name);
	EndDo;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	// Fill out values of the keys that contain the accounting policy data.
	FillPropertyValues(StructureAdditionalProperties.AccountingPolicy, QueryResultSelection);
	
EndProcedure

// Checks table existance in query texts
//
// Parameters:
//  TableName		- String		- table name
//  QueryTexts		- ValueList		- value list, values is table names
//
// Returned value:
//  Boolean - True, if text exist.
//
Function IsTableInQuery(TableName, QueryTexts) Export

	If QueryTexts = Undefined Then
		Return True;
	EndIf; 
	
	For each QueryText In QueryTexts Do
		If Upper(QueryText.Presentation) = Upper(TableName) Then
			Return True;
		EndIf; 
	EndDo; 
	
	Return False;

EndFunction

// Generates register names array on which there are document movements.
//
Function GetNamesArrayOfUsedRegisters(Recorder, DocumentMetadata, ExcludedRegisters = Undefined)
	
	RegisterArray = New Array;
	QueryText = "";
	TableCounter = 0;
	DoCounter = 0;
	RegistersTotalAmount = DocumentMetadata.RegisterRecords.Count();
	
	For Each RegisterRecord In DocumentMetadata.RegisterRecords Do
		
		DoCounter = DoCounter + 1;
		
		SkipRegister = ExcludedRegisters <> Undefined
			AND ExcludedRegisters.Find(RegisterRecord.Name) <> Undefined;
			
		If Not SkipRegister Then
		
			If TableCounter > 0 Then
				
				QueryText = QueryText + "
				|UNION ALL
				|";
				
			EndIf;
		
			TableCounter = TableCounter + 1;
		
			QueryText = QueryText + 
			"SELECT TOP 1
			|""" + RegisterRecord.Name + """ AS RegisterName
			|
			|FROM " + RegisterRecord.FullName() + "
			|
			|WHERE Recorder = &Recorder
			|";
			
		EndIf;
		
		If TableCounter = 256 OR DoCounter = RegistersTotalAmount Then
			
			Query = New Query(QueryText);
			Query.SetParameter("Recorder", Recorder);
			
			QueryText  = "";
			TableCounter = 0;
			
			If RegisterArray.Count() = 0 Then
				RegisterArray = Query.Execute().Unload().UnloadColumn("RegisterName");
			Else
				
				Selection = Query.Execute().Select();
				While Selection.Next() Do
					RegisterArray.Add(Selection.RegisterName);
				EndDo;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Return RegisterArray;
	
EndFunction

// Prepares document records sets.
//
Procedure PrepareRecordSetsForRecording(ObjectStructure) Export
	
	Var IsNewDocument;
	
	AdditionalProperties = ObjectStructure.AdditionalProperties;
	
	If Not AdditionalProperties.Property("IsNew", IsNewDocument) Then
		IsNewDocument = False;
	EndIf;
	
	For Each RecordSet In ObjectStructure.RegisterRecords Do
		If TypeOf(RecordSet) = Type("KeyAndValue") Then
			RecordSet = RecordSet.Value;
		EndIf;
		If RecordSet.Count() > 0 Then
			RecordSet.Clear();
		EndIf;
	EndDo;
	
	ExcludedRegisters = Undefined;
	If AdditionalProperties.Property("WriteMode")
		And Not AdditionalProperties.WriteMode = DocumentWriteMode.UndoPosting Then
		ExcludedRegisters = New Array;
		ExcludedRegisters.Add("InventoryCostLayer");
		ExcludedRegisters.Add("LandedCosts");
	EndIf;
	
	ArrayOfNamesOfRegisters = GetNamesArrayOfUsedRegisters(
		ObjectStructure.Ref,
		AdditionalProperties.ForPosting.DocumentMetadata,
		ExcludedRegisters);
	
	For Each RegisterName In ArrayOfNamesOfRegisters Do
		ObjectStructure.RegisterRecords[RegisterName].Write = True;
	EndDo;
	
EndProcedure

// Writes document records sets.
//
Procedure WriteRecordSets(ObjectStructure) Export
	
	For Each RecordSet In ObjectStructure.RegisterRecords Do
		
		If TypeOf(RecordSet) = Type("KeyAndValue") Then
			
			RecordSet = RecordSet.Value;
			
		EndIf;
		
		If RecordSet.Write Then
			
			If Not RecordSet.AdditionalProperties.Property("ForPosting") Then
				
				RecordSet.AdditionalProperties.Insert("ForPosting", New Structure);
				
			EndIf;
			
			If Not RecordSet.AdditionalProperties.ForPosting.Property("StructureTemporaryTables") Then
				
				RecordSet.AdditionalProperties.ForPosting.Insert("StructureTemporaryTables", ObjectStructure.AdditionalProperties.ForPosting.StructureTemporaryTables);
				
			EndIf;
			
			RecordSet.Write();
			RecordSet.Write = False;
			
		Else
			
			RecordSetMetadata = RecordSet.Metadata();
			If CommonUse.ThisIsAccumulationRegister(RecordSetMetadata)
				AND ThereAreProcedureCreateAnEmptyTemporaryTableUpdate(RecordSetMetadata.FullName()) Then
				
				ObjectManager = CommonUse.ObjectManagerByFullName(RecordSetMetadata.FullName());
				ObjectManager.CreateEmptyTemporaryTableChange(ObjectStructure.AdditionalProperties);
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Function ThereAreProcedureCreateAnEmptyTemporaryTableUpdate(FullNameOfRegister)
	
	RegistersWithTheProcedure = New Array;
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.FixedAssets.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.CashAssets.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.CashInCashRegisters.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.UnallocatedExpenses.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.IncomeAndExpensesRetained.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.ProductionOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SalesOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsShippedNotInvoiced.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsInvoicedNotShipped.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsReceivedNotInvoiced.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.PurchaseOrders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.Inventory.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.InventoryInWarehouses.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.StockTransferredToThirdParties.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.StockReceivedFromThirdParties.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.InventoryDemand.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.Backorders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.TaxPayable.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.Payroll.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.AdvanceHolders.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.AccountsReceivable.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.AccountsPayable.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.POSSummary.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.SerialNumbers.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.VATIncurred.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.GoodsAwaitingCustomsClearance.FullName());
	RegistersWithTheProcedure.Add(Metadata.AccumulationRegisters.WorkOrders.FullName());
	
	Return RegistersWithTheProcedure.Find(FullNameOfRegister) <> Undefined;
	
EndFunction

// Checks whether it is possible to clear the UseSerialNumbers option.
//
Function CancelRemoveFunctionalOptionUseSerialNumbers() Export
	
	ErrorText = "";
	AreRecords = False;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SerialNumbers.SerialNumber
	|FROM
	|	AccumulationRegister.SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	QueryResult = Query.Execute();
	If NOT QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'Serial numbers functionality has been already used. To turn it off, please, make sure there are no records in the Serial numbers accumulation register.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

#Region OfflineRegisters

// Reflect document in information registers "Tasks..."
Procedure CreateRecordsInTasksRegisters(DocumentObject, Cancel = False) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	FIFO.ReflectTasks(DocumentObject, DocumentObject.AdditionalProperties);
	
EndProcedure

// Moves accumulation register InventoryCostLayer.
//
Procedure ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryCostLayer = AdditionalProperties.TableForRegisterRecords.TableInventoryCostLayer;
	
	If Cancel
	 OR TableInventoryCostLayer.Count() = 0 Then
		Return;
	EndIf;
	
	InventoryCostLayerRegistering = RegisterRecords.InventoryCostLayer;
	InventoryCostLayerRegistering.Write = True;
	InventoryCostLayerRegistering.Load(TableInventoryCostLayer);
	
EndProcedure

// Moves accumulation register LandedCosts.
//
Procedure ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableLandedCosts = AdditionalProperties.TableForRegisterRecords.TableLandedCosts;
	
	If Cancel OR TableLandedCosts.Count() = 0 Then
		Return;
	EndIf;
	
	LandedCostsRegistering = RegisterRecords.LandedCosts;
	LandedCostsRegistering.Write = True;
	LandedCostsRegistering.Load(TableLandedCosts);
	
EndProcedure

#EndRegion

#EndRegion

#Region RegistersMovementsGeneratingProcedures

// Function returns the ControlBalancesDuringOnPosting constant value.
// 
Function RunBalanceControl() Export
	
	Return Constants.CheckStockBalanceOnPosting.Get();
	
EndFunction

#Region OtherSettlements

// Moves accumulation register MiscellaneousPayable.
//
Procedure ReflectMiscellaneousPayable(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableMiscellaneousPayable = AdditionalProperties.TableForRegisterRecords.TableMiscellaneousPayable;
	
	If Cancel
	 OR TableMiscellaneousPayable.Count() = 0 Then
		Return;
	EndIf;
	
	MiscellaneousPayableRegistering = RegisterRecords.MiscellaneousPayable;
	MiscellaneousPayableRegistering.Write = True;
	MiscellaneousPayableRegistering.Load(TableMiscellaneousPayable);
	
EndProcedure

// Generates records of the LoanSettlements accumulation register.
//
Procedure ReflectLoanSettlements(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableLoanSettlements = AdditionalProperties.TableForRegisterRecords.TableLoanSettlements;
	
	If Cancel
	 OR TableLoanSettlements.Count() = 0 Then
		Return;
	EndIf;
	
	RecordsLoanSettlements = RegisterRecords.LoanSettlements;
	RecordsLoanSettlements.Write = True;
	RecordsLoanSettlements.Load(TableLoanSettlements);
	
EndProcedure

// Generates records of the LoanRepaymentSchedule information register.
//
Procedure RecordLoanRepaymentSchedule(AdditionalProperties, Records, Cancel) Export
	
	TableLoanRepaymentSchedule = AdditionalProperties.TableForRegisterRecords.TableLoanRepaymentSchedule;
	
	If Cancel
	 OR TableLoanRepaymentSchedule.Count() = 0 Then
		Return;
	EndIf;
	
	RecordsLoanRepaymentSchedule = Records.LoanRepaymentSchedule;
	RecordsLoanRepaymentSchedule.Write = True;
	RecordsLoanRepaymentSchedule.Load(TableLoanRepaymentSchedule);
	
EndProcedure

Function GetQueryTextExchangeRateDifferencesAccountingForOtherOperations(TempTablesManager, QueryNumber) Export
	
	QueryNumber = 2;
	
	QueryText =
	"SELECT
	|	AcccountsBalances.Company AS Company,
	|	AcccountsBalances.Counterparty AS Counterparty,
	|	AcccountsBalances.Contract AS Contract,
	|	AcccountsBalances.GLAccount AS GLAccount,
	|	SUM(AcccountsBalances.AmountBalance) AS AmountBalance,
	|	SUM(AcccountsBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableBalancesAfterPosting
	|FROM
	|	(SELECT
	|		TemporaryTable.Company AS Company,
	|		TemporaryTable.Counterparty AS Counterparty,
	|		TemporaryTable.Contract AS Contract,
	|		TemporaryTable.GLAccount AS GLAccount,
	|		TemporaryTable.AmountForBalance AS AmountBalance,
	|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
	|	FROM
	|		TemporaryTableOtherSettlements AS TemporaryTable
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableBalances.Company,
	|		TableBalances.Counterparty,
	|		TableBalances.Contract,
	|		TableBalances.GLAccount,
	|		ISNULL(TableBalances.AmountBalance, 0),
	|		ISNULL(TableBalances.AmountCurBalance, 0)
	|	FROM
	|		AccumulationRegister.MiscellaneousPayable.Balance(
	|				&PointInTime,
	|				(Company, Counterparty, Contract, GLAccount) IN
	|					(SELECT DISTINCT
	|						TemporaryTableOtherSettlements.Company,
	|						TemporaryTableOtherSettlements.Counterparty,
	|						TemporaryTableOtherSettlements.Contract,
	|						TemporaryTableOtherSettlements.GLAccount
	|					FROM
	|						TemporaryTableOtherSettlements)) AS TableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecords.Company,
	|		DocumentRegisterRecords.Counterparty,
	|		DocumentRegisterRecords.Contract,
	|		DocumentRegisterRecords.GLAccount,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
	|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
	|		END
	|	FROM
	|		AccumulationRegister.MiscellaneousPayable AS DocumentRegisterRecords
	|	WHERE
	|		DocumentRegisterRecords.Recorder = &Ref
	|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AcccountsBalances
	|
	|GROUP BY
	|	AcccountsBalances.Company,
	|	AcccountsBalances.Counterparty,
	|	AcccountsBalances.Contract,
	|	AcccountsBalances.GLAccount
	|
	|INDEX BY
	|	Company,
	|	Counterparty,
	|	Contract,
	|	GLAccount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	1 AS LineNumber,
	|	&ControlPeriod AS Date,
	|	TableAccounts.Company AS Company,
	|	TableAccounts.Counterparty AS Counterparty,
	|	TableAccounts.Contract AS Contract,
	|	TableAccounts.GLAccount AS GLAccount,
	|	ISNULL(TableBalances.AmountCurBalance, 0) * ExchangeRatesAccountsSliceLast.ExchangeRate * ExchangeRatesSliceLast.Multiplicity / (ExchangeRatesSliceLast.ExchangeRate * ExchangeRatesAccountsSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS ExchangeRateDifferenceAmount,
	|	TableAccounts.Currency AS Currency
	|INTO ExchangeDifferencesTemporaryTableOtherSettlements
	|FROM
	|	TemporaryTableOtherSettlements AS TableAccounts
	|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
	|		ON TableAccounts.Company = TableBalances.Company
	|			AND TableAccounts.Counterparty = TableBalances.Counterparty
	|			AND TableAccounts.Contract = TableBalances.Contract
	|			AND TableAccounts.GLAccount = TableBalances.GLAccount
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantDefaultCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantDefaultCurrency)) AS ExchangeRatesSliceLast
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT DISTINCT
	|						TemporaryTableOtherSettlements.Currency
	|					FROM
	|						TemporaryTableOtherSettlements)) AS ExchangeRatesAccountsSliceLast
	|		ON TableAccounts.Contract.SettlementsCurrency = ExchangeRatesAccountsSliceLast.Currency
	|WHERE
	|	(ISNULL(TableBalances.AmountCurBalance, 0) * ExchangeRatesAccountsSliceLast.ExchangeRate * ExchangeRatesSliceLast.Multiplicity / (ExchangeRatesSliceLast.ExchangeRate * ExchangeRatesAccountsSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
	|			OR ISNULL(TableBalances.AmountCurBalance, 0) * ExchangeRatesAccountsSliceLast.ExchangeRate * ExchangeRatesSliceLast.Multiplicity / (ExchangeRatesSliceLast.ExchangeRate * ExchangeRatesAccountsSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	1 AS Order,
	|	DocumentTable.LineNumber AS LineNumber,
	|	DocumentTable.Date AS Period,
	|	DocumentTable.RecordType AS RecordType,
	|	DocumentTable.Company AS Company,
	|	DocumentTable.Counterparty AS Counterparty,
	|	DocumentTable.Contract AS Contract,
	|	DocumentTable.GLAccount AS GLAccount,
	|	DocumentTable.Amount AS Amount,
	|	DocumentTable.AmountCur AS AmountCur,
	|	DocumentTable.Currency,
	|	DocumentTable.PostingContent,
	|	DocumentTable.Comment
	|FROM
	|	TemporaryTableOtherSettlements AS DocumentTable
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	DocumentTable.LineNumber,
	|	DocumentTable.Date,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN VALUE(AccumulationRecordType.Receipt)
	|		ELSE VALUE(AccumulationRecordType.Expense)
	|	END,
	|	DocumentTable.Company,
	|	DocumentTable.Counterparty,
	|	DocumentTable.Contract,
	|	DocumentTable.GLAccount,
	|	CASE
	|		WHEN DocumentTable.ExchangeRateDifferenceAmount > 0
	|			THEN DocumentTable.ExchangeRateDifferenceAmount
	|		ELSE -DocumentTable.ExchangeRateDifferenceAmount
	|	END,
	|	0,
	|	DocumentTable.Currency,
	|	&ExchangeRateDifference,
	|	""""
	|FROM
	|	ExchangeDifferencesTemporaryTableOtherSettlements AS DocumentTable
	|
	|ORDER BY
	|	Order,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTableBalancesAfterPosting";
		
	Return QueryText;
	
EndFunction

// Function returns query text to calculate exchange rate differences.
//
Function GetQueryTextExchangeRateDifferencesLoanSettlements(TemporaryTableManager, QueryNumber, IsBusinessUnit = False) Export
	
	CalculateExchangeRateDifferences = GetNeedToCalculateExchangeDifferences(TemporaryTableManager, "TemporaryTableLoanSettlements");
	
	If CalculateExchangeRateDifferences Then
		
		QueryNumber = 3;
		
		QueryText = 
		"SELECT
		|	SettlementsBalance.LoanKind AS LoanKind,
		|	SettlementsBalance.Counterparty AS Counterparty,
		|	SettlementsBalance.Company AS Company,
		|	SettlementsBalance.LoanContract AS LoanContract,
		|	SUM(SettlementsBalance.PrincipalDebtBalance) AS PrincipalDebtBalance,
		|	SUM(SettlementsBalance.PrincipalDebtCurBalance) AS PrincipalDebtCurBalance,
		|	SUM(SettlementsBalance.InterestBalance) AS InterestBalance,
		|	SUM(SettlementsBalance.InterestCurBalance) AS InterestCurBalance,
		|	SUM(SettlementsBalance.CommissionBalance) AS CommissionBalance,
		|	SUM(SettlementsBalance.CommissionCurBalance) AS CommissionCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.LoanKind AS LoanKind,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.LoanContract AS LoanContract,
		|		TemporaryTable.PrincipalDebtForBalance AS PrincipalDebtBalance,
		|		TemporaryTable.PrincipalDebtCurForBalance AS PrincipalDebtCurBalance,
		|		TemporaryTable.InterestForBalance AS InterestBalance,
		|		TemporaryTable.InterestCurForBalance AS InterestCurBalance,
		|		TemporaryTable.CommissionForBalance AS CommissionBalance,
		|		TemporaryTable.CommissionCurForBalance AS CommissionCurBalance
		|	FROM
		|		TemporaryTableLoanSettlements AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalance.LoanKind,
		|		TableBalance.Counterparty,
		|		TableBalance.Company,
		|		TableBalance.LoanContract,
		|		ISNULL(TableBalance.PrincipalDebtBalance, 0),
		|		ISNULL(TableBalance.PrincipalDebtCurBalance, 0),
		|		ISNULL(TableBalance.InterestBalance, 0),
		|		ISNULL(TableBalance.InterestCurBalance, 0),
		|		ISNULL(TableBalance.CommissionBalance, 0),
		|		ISNULL(TableBalance.CommissionCurBalance, 0)
		|	FROM
		|		AccumulationRegister.LoanSettlements.Balance(
		|				&PointInTime,
		|				(Company, Counterparty, LoanContract, LoanKind) IN
		|					(SELECT DISTINCT
		|						TemporaryTableLoanSettlements.Company,
		|						TemporaryTableLoanSettlements.Counterparty,
		|						TemporaryTableLoanSettlements.LoanContract,
		|						TemporaryTableLoanSettlements.LoanKind
		|					FROM
		|						TemporaryTableLoanSettlements)) AS TableBalance
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRecords.LoanKind,
		|		DocumentRecords.Counterparty,
		|		DocumentRecords.Company,
		|		DocumentRecords.LoanContract,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.PrincipalDebt, 0)
		|			ELSE ISNULL(DocumentRecords.PrincipalDebt, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.PrincipalDebtCur, 0)
		|			ELSE ISNULL(DocumentRecords.PrincipalDebtCur, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.Interest, 0)
		|			ELSE ISNULL(DocumentRecords.Interest, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.InterestCur, 0)
		|			ELSE ISNULL(DocumentRecords.InterestCur, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.Commission, 0)
		|			ELSE ISNULL(DocumentRecords.Commission, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRecords.CommissionCur, 0)
		|			ELSE ISNULL(DocumentRecords.CommissionCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.LoanSettlements AS DocumentRecords
		|	WHERE
		|		DocumentRecords.Recorder = &Ref
		|		AND DocumentRecords.Period <= &ControlPeriod) AS SettlementsBalance
		|
		|GROUP BY
		|	SettlementsBalance.Company,
		|	SettlementsBalance.Counterparty,
		|	SettlementsBalance.LoanKind,
		|	SettlementsBalance.LoanContract
		|
		|INDEX BY
		|	Company,
		|	Counterparty,
		|	LoanKind,
		|	LoanContract
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableSettlements.Company AS Company,
		|	TableSettlements.Counterparty AS Counterparty,
		|	TableSettlements.LoanKind AS LoanKind,
		|	TableSettlements.Currency AS Currency,
		|	CAST(TableSettlements.LoanContract AS Document.LoanContract) AS LoanContract,
		|	TableSettlements.GLAccount AS GLAccount,
		|	ISNULL(TableBalance.PrincipalDebtCurBalance, 0) * SettlementExchangeRatesLastSlice.ExchangeRate * AccountingExchangeRatesLastSlice.Multiplicity / (AccountingExchangeRatesLastSlice.ExchangeRate * SettlementExchangeRatesLastSlice.Multiplicity) - ISNULL(TableBalance.PrincipalDebtBalance, 0) AS ExchangeRateDifferenceAmountPrincipalDebt,
		|	ISNULL(TableBalance.InterestCurBalance, 0) * SettlementExchangeRatesLastSlice.ExchangeRate * AccountingExchangeRatesLastSlice.Multiplicity / (AccountingExchangeRatesLastSlice.ExchangeRate * SettlementExchangeRatesLastSlice.Multiplicity) - ISNULL(TableBalance.InterestBalance, 0) AS ExchangeRateDifferenceAmountInterest,
		|	ISNULL(TableBalance.CommissionCurBalance, 0) * SettlementExchangeRatesLastSlice.ExchangeRate * AccountingExchangeRatesLastSlice.Multiplicity / (AccountingExchangeRatesLastSlice.ExchangeRate * SettlementExchangeRatesLastSlice.Multiplicity) - ISNULL(TableBalance.CommissionBalance, 0) AS ExchangeRateDifferenceAmountCommission
		|INTO TemporaryTableOfExchangeRateDifferences
		|FROM
		|	TemporaryTableLoanSettlements AS TableSettlements
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalance
		|		ON TableSettlements.Company = TableBalance.Company
		|			AND TableSettlements.Counterparty = TableBalance.Counterparty
		|			AND TableSettlements.LoanKind = TableBalance.LoanKind
		|			AND TableSettlements.LoanContract = TableBalance.LoanContract
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesLastSlice
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTableLoanSettlements.Currency
		|					FROM
		|						TemporaryTableLoanSettlements)) AS SettlementExchangeRatesLastSlice
		|		ON TableSettlements.LoanContract.SettlementsCurrency = SettlementExchangeRatesLastSlice.Currency
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	TemporaryTableOfExchangeRateDifferences.LineNumber AS LineNumber,
		|	TemporaryTableOfExchangeRateDifferences.Date AS Date,
		|	TemporaryTableOfExchangeRateDifferences.Company AS Company,
		|	TemporaryTableOfExchangeRateDifferences.Counterparty AS Counterparty,
		|	TemporaryTableOfExchangeRateDifferences.LoanKind AS LoanKind,
		|	TemporaryTableOfExchangeRateDifferences.Currency AS Currency,
		|	TemporaryTableOfExchangeRateDifferences.LoanContract AS LoanContract,
		|	TemporaryTableOfExchangeRateDifferences.GLAccount AS GLAccount,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt AS ExchangeRateDifferenceAmountPrincipalDebt,
		|	0 AS ExchangeRateDifferenceAmountInterest,
		|	0 AS ExchangeRateDifferenceAmountCommission,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt AS ExchangeRateDifferenceAmount
		|INTO TemporaryTableExchangeRateDifferencesLoanSettlements
		|FROM
		|	TemporaryTableOfExchangeRateDifferences AS TemporaryTableOfExchangeRateDifferences
		|WHERE
		|	(TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt >= 0.005
		|			OR TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountPrincipalDebt <= -0.005)
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableOfExchangeRateDifferences.LineNumber,
		|	TemporaryTableOfExchangeRateDifferences.Date,
		|	TemporaryTableOfExchangeRateDifferences.Company,
		|	TemporaryTableOfExchangeRateDifferences.Counterparty,
		|	TemporaryTableOfExchangeRateDifferences.LoanKind,
		|	TemporaryTableOfExchangeRateDifferences.Currency,
		|	TemporaryTableOfExchangeRateDifferences.LoanContract,
		|	TemporaryTableOfExchangeRateDifferences.GLAccount,
		|	0,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest,
		|	0,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest
		|FROM
		|	TemporaryTableOfExchangeRateDifferences AS TemporaryTableOfExchangeRateDifferences
		|WHERE
		|	(TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest >= 0.005
		|			OR TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountInterest <= -0.005)
		|
		|UNION ALL
		|
		|SELECT
		|	TemporaryTableOfExchangeRateDifferences.LineNumber,
		|	TemporaryTableOfExchangeRateDifferences.Date,
		|	TemporaryTableOfExchangeRateDifferences.Company,
		|	TemporaryTableOfExchangeRateDifferences.Counterparty,
		|	TemporaryTableOfExchangeRateDifferences.LoanKind,
		|	TemporaryTableOfExchangeRateDifferences.Currency,
		|	TemporaryTableOfExchangeRateDifferences.LoanContract,
		|	TemporaryTableOfExchangeRateDifferences.GLAccount,
		|	0,
		|	0,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission,
		|	TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission
		|FROM
		|	TemporaryTableOfExchangeRateDifferences AS TemporaryTableOfExchangeRateDifferences
		|WHERE
		|	(TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission >= 0.005
		|			OR TemporaryTableOfExchangeRateDifferences.ExchangeRateDifferenceAmountCommission <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order1,
		|	1 AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.LoanContract AS LoanContract,
		|	DocumentTable.LoanKind AS LoanKind,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.LoanContract.SettlementsCurrency AS Currency,
		|	DocumentTable.PrincipalCharged AS PrincipalCharged,
		|	DocumentTable.PrincipalChargedCur AS PrincipalChargedCur,
		|	DocumentTable.Interest AS Interest,
		|	DocumentTable.InterestCur AS InterestCur,
		|	DocumentTable.Commission AS Commission,
		|	DocumentTable.CommissionCur AS CommissionCur,
		|	DocumentTable.PrincipalCharged + DocumentTable.Interest + DocumentTable.Commission AS Amount,
		|	DocumentTable.PrincipalChargedCur + DocumentTable.InterestCur + DocumentTable.CommissionCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	CAST(DocumentTable.PostingContent AS STRING(100)) AS PostingContent,
		|	DocumentTable.DeductedFromSalary AS DeductedFromSalary,
		|	"""" AS BusinessUnit
		|FROM
		|	TemporaryTableLoanSettlements AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	1,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt > 0
		|				OR DocumentTable.ExchangeRateDifferenceAmountInterest > 0
		|				OR DocumentTable.ExchangeRateDifferenceAmountCommission > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.LoanContract,
		|	DocumentTable.LoanKind,
		|	DocumentTable.Counterparty,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.LoanContract.SettlementsCurrency,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|	END,
		|	0,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountInterest > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountInterest
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountInterest
		|	END,
		|	0,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountCommission > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountCommission
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountCommission
		|	END,
		|	0,
		|	CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountPrincipalDebt
		|	END + CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountInterest > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountInterest
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountInterest
		|	END + CASE
		|		WHEN DocumentTable.ExchangeRateDifferenceAmountCommission > 0
		|			THEN DocumentTable.ExchangeRateDifferenceAmountCommission
		|		ELSE -DocumentTable.ExchangeRateDifferenceAmountCommission
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	&ExchangeRateDifference,
		|	FALSE,
		|	UNDEFINED
		|FROM
		|	TemporaryTableExchangeRateDifferencesLoanSettlements AS DocumentTable
		|
		|ORDER BY
		|	Order1,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText = 
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableSettlements.Company AS Company,
		|	TableSettlements.Counterparty AS Counterparty,
		|	TableSettlements.LoanKind AS LoanKind,
		|	TableSettlements.LoanContract AS LoanContract,
		|	0 AS ExchangeRateDifferenceAmount,
		|	TableSettlements.Currency AS Currency,
		|	TableSettlements.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesLoanSettlements
		|FROM
		|	TemporaryTableLoanSettlements AS TableSettlements
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order1,
		|	1 AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.LoanContract AS LoanContract,
		|	DocumentTable.LoanKind AS LoanKind,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.PrincipalDebt AS PrincipalDebt,
		|	DocumentTable.PrincipalDebtCur AS PrincipalDebtCur,
		|	DocumentTable.Interest AS Interest,
		|	DocumentTable.InterestCur AS InterestCur,
		|	DocumentTable.Commission AS Commission,
		|	DocumentTable.CommissionCur AS CommissionCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.PostingContent AS PostingContent,
		|	DocumentTable.DeductedFromSalary AS DeductedFromSalary,
		|	DocumentTable.PrincipalDebtCur + DocumentTable.InterestCur + DocumentTable.CommissionCur AS AmountCur,
		|	DocumentTable.PrincipalDebt + DocumentTable.Interest + DocumentTable.Commission AS Amount,
		|	"""" AS BusinessArea
		|FROM
		|	TemporaryTableLoanSettlements AS DocumentTable
		|
		|ORDER BY
		|	Order1,
		|	LineNumber";
		
	EndIf;
	
	If IsBusinessUnit
		Then QueryText = StrReplace(QueryText, """"" AS BusinessUnit", "DocumentTable.BusinessUnit AS BusinessUnit");
	EndIf;
	
	Return QueryText;
	
EndFunction

#EndRegion

// Moves accumulation register CashAssets.
//
Procedure ReflectCashAssets(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCashAssets = AdditionalProperties.TableForRegisterRecords.TableCashAssets;
	
	If Cancel
	 OR TableCashAssets.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsCashAssets = RegisterRecords.CashAssets;
	RegisterRecordsCashAssets.Write = True;
	RegisterRecordsCashAssets.Load(TableCashAssets);
	
EndProcedure

// Moves accumulation register AdvanceHoldersPayments.
//
Procedure ReflectAdvanceHolders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSettlementsWithAdvanceHolders = AdditionalProperties.TableForRegisterRecords.TableSettlementsWithAdvanceHolders;
	
	If Cancel
	 OR TableSettlementsWithAdvanceHolders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsAdvanceHolders = RegisterRecords.AdvanceHolders;
	RegisterRecordsAdvanceHolders.Write = True;
	RegisterRecordsAdvanceHolders.Load(TableSettlementsWithAdvanceHolders);
	
EndProcedure

// Moves accumulation register CounterpartiesSettlements.
//
Procedure ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountsReceivable = AdditionalProperties.TableForRegisterRecords.TableAccountsReceivable;
	
	If Cancel
	 OR TableAccountsReceivable.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsAccountsReceivable = RegisterRecords.AccountsReceivable;
	RegisterRecordsAccountsReceivable.Write = True;
	RegisterRecordsAccountsReceivable.Load(TableAccountsReceivable);
	
EndProcedure

// Moves accumulation register CounterpartiesSettlements.
//
Procedure ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountsPayable = AdditionalProperties.TableForRegisterRecords.TableAccountsPayable;
	
	If Cancel
	 OR TableAccountsPayable.Count() = 0 Then
		Return;
	EndIf;
	
	VendorsPaymentsRegistration = RegisterRecords.AccountsPayable;
	VendorsPaymentsRegistration.Write = True;
	VendorsPaymentsRegistration.Load(TableAccountsPayable);
	
EndProcedure

// Moves accumulation register Payment schedule.
//
// Parameters:
//  DocumentObject - Current
//  document Denial - Boolean - Check box of canceling document posting.
//
Procedure ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePaymentCalendar = AdditionalProperties.TableForRegisterRecords.TablePaymentCalendar;
	
	If Cancel
	 OR TablePaymentCalendar.Count() = 0 Then
		Return;
	EndIf;
	
	PaymentCalendarRegistration = RegisterRecords.PaymentCalendar;
	PaymentCalendarRegistration.Write = True;
	PaymentCalendarRegistration.Load(TablePaymentCalendar);
	
EndProcedure

// Moves accumulation register Accounts payment.
//
// Parameters:
//  DocumentObject - Current
//  document Denial - Boolean - Check box of canceling document posting.
//
Procedure ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInvoicesAndOrdersPayment = AdditionalProperties.TableForRegisterRecords.TableInvoicesAndOrdersPayment;
	
	If Cancel
	 OR TableInvoicesAndOrdersPayment.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsInvoicesAndOrdersPayment = RegisterRecords.InvoicesAndOrdersPayment;
	RegisterRecordsInvoicesAndOrdersPayment.Write = True;
	RegisterRecordsInvoicesAndOrdersPayment.Load(TableInvoicesAndOrdersPayment);
	
EndProcedure

// Procedure moves IncomingsAndExpensesPettyCashMethodaccumulation register.
//
// Parameters:
// DocumentObject - Current
// document Denial - Boolean - Shows that you cancelled document posting.
//
Procedure ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpensesCashMethod = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesCashMethod;
	
	If Cancel
	 OR TableIncomeAndExpensesCashMethod.Count() = 0 Then
		Return;
	EndIf;
	
	IncomeAndExpensesCashMethod = RegisterRecords.IncomeAndExpensesCashMethod;
	IncomeAndExpensesCashMethod.Write = True;
	IncomeAndExpensesCashMethod.Load(TableIncomeAndExpensesCashMethod);
	
EndProcedure

// Procedure moves the UnallocatedExpenses accumulation register.
//
// Parameters:
// DocumentObject - Current
// document Denial - Boolean - Shows that you cancelled document posting.
//
Procedure ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableUnallocatedExpenses = AdditionalProperties.TableForRegisterRecords.TableUnallocatedExpenses;
	
	If Cancel
	 OR TableUnallocatedExpenses.Count() = 0 Then
		Return;
	EndIf;
	
	UnallocatedExpenses = RegisterRecords.UnallocatedExpenses;
	UnallocatedExpenses.Write = True;
	UnallocatedExpenses.Load(TableUnallocatedExpenses);
	
EndProcedure

// Procedure moves IncomeAndExpensesDelayed accumulation register.
//
// Parameters:
// DocumentObject - Current
// document Denial - Boolean - Shows that you cancelled document posting.
//
Procedure ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpensesRetained = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesRetained;
	
	If Cancel
	 OR TableIncomeAndExpensesRetained.Count() = 0 Then
		Return;
	EndIf;
	
	IncomeAndExpensesRetained = RegisterRecords.IncomeAndExpensesRetained;
	IncomeAndExpensesRetained.Write = True;
	IncomeAndExpensesRetained.Load(TableIncomeAndExpensesRetained);
	
EndProcedure

// Moves accumulation register DeductionsAndEarning.
//
Procedure ReflectEarningsAndDeductions(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableEarningsAndDeductions = AdditionalProperties.TableForRegisterRecords.TableEarningsAndDeductions;
	
	If Cancel
	 OR TableEarningsAndDeductions.Count() = 0 Then
		Return;
	EndIf;
	
	RegistrationEarningsAndDeductions = RegisterRecords.EarningsAndDeductions;
	RegistrationEarningsAndDeductions.Write = True;
	RegistrationEarningsAndDeductions.Load(TableEarningsAndDeductions);
	
EndProcedure

// Moves accumulation register Payroll.
//
Procedure ReflectPayroll(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePayroll = AdditionalProperties.TableForRegisterRecords.TablePayroll;
	
	If Cancel
	 OR TablePayroll.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPayroll = RegisterRecords.Payroll;
	RegisterRecordsPayroll.Write = True;
	RegisterRecordsPayroll.Load(TablePayroll);
	
EndProcedure

// Moves information register PlannedEarningsAndDeductions.
//
Procedure ReflectCompensationPlan(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCompensationPlan = AdditionalProperties.TableForRegisterRecords.TableCompensationPlan;
	
	If Cancel
	 OR TableCompensationPlan.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPlannedEarningsAndDeductions = RegisterRecords.CompensationPlan;
	RegisterRecordsPlannedEarningsAndDeductions.Write = True;
	RegisterRecordsPlannedEarningsAndDeductions.Load(TableCompensationPlan);
	
EndProcedure

// Moves information register Employees.
//
Procedure ReflectEmployees(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableEmployees = AdditionalProperties.TableForRegisterRecords.TableEmployees;
	
	If Cancel
	 OR TableEmployees.Count() = 0 Then
		Return;
	EndIf;
	
	EmployeeRecords = RegisterRecords.Employees;
	EmployeeRecords.Write = True;
	EmployeeRecords.Load(TableEmployees);
	
EndProcedure

// Moves accumulation register Time sheet.
//
Procedure ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancel) Export
	
	ScheduleTable = AdditionalProperties.TableForRegisterRecords.ScheduleTable;
	
	If Cancel
	 OR ScheduleTable.Count() = 0 Then
		Return;
	EndIf;
	
	ScheduleRecords = RegisterRecords.Timesheet;
	ScheduleRecords.Write = True;
	ScheduleRecords.Load(ScheduleTable);
	
EndProcedure

// Returns empty value table
Function EmptyIncomeAndExpensesTable() Export
	
	Query = New Query("SELECT TOP 0
	|	IncomeAndExpenses.Period AS Period,
	|	IncomeAndExpenses.Recorder AS Recorder,
	|	IncomeAndExpenses.LineNumber AS LineNumber,
	|	IncomeAndExpenses.Active AS Active,
	|	IncomeAndExpenses.Company AS Company,
	|	IncomeAndExpenses.StructuralUnit AS StructuralUnit,
	|	IncomeAndExpenses.BusinessLine AS BusinessLine,
	|	IncomeAndExpenses.SalesOrder AS SalesOrder,
	|	IncomeAndExpenses.GLAccount AS GLAccount,
	|	IncomeAndExpenses.AmountIncome AS AmountIncome,
	|	IncomeAndExpenses.AmountExpense AS AmountExpense,
	|	IncomeAndExpenses.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	IncomeAndExpenses.OfflineRecord AS OfflineRecord
	|FROM
	|	AccumulationRegister.IncomeAndExpenses AS IncomeAndExpenses");
	
	Return Query.Execute().Unload();
	
EndFunction

// Moves accumulation register IncomingsAndExpenses.
//
Procedure ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpenses = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpenses;
	
	If Cancel
	 OR TableIncomeAndExpenses.Count() = 0 Then
		Return;
	EndIf;
	
	IncomeAndExpencesRegistering = RegisterRecords.IncomeAndExpenses;
	IncomeAndExpencesRegistering.Write = True;
	IncomeAndExpencesRegistering.Load(TableIncomeAndExpenses);
	
EndProcedure

// Moves accumulation register AmountAccountingInRetail.
//
Procedure ReflectPOSSummary(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePOSSummary = AdditionalProperties.TableForRegisterRecords.TablePOSSummary;
	
	If Cancel
	 OR TablePOSSummary.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPOSSummary = RegisterRecords.POSSummary;
	RegisterRecordsPOSSummary.Write = True;
	RegisterRecordsPOSSummary.Load(TablePOSSummary);
	
EndProcedure

// Moves accumulation register CalculationsOnTaxes.
//
Procedure ReflectTaxesSettlements(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableTaxAccounting = AdditionalProperties.TableForRegisterRecords.TableTaxAccounting;
	
	If Cancel
	 OR TableTaxAccounting.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsTaxesSettlements = RegisterRecords.TaxPayable;
	RegisterRecordsTaxesSettlements.Write = True;
	RegisterRecordsTaxesSettlements.Load(TableTaxAccounting);
	
EndProcedure

// Moves accumulation register InventoryOnWarehouses.
//
Procedure ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryInWarehouses = AdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses;
	
	If Cancel
	 OR TableInventoryInWarehouses.Count() = 0 Then
		Return;
	EndIf;
	
	WarehouseInventoryRegistering = RegisterRecords.InventoryInWarehouses;
	WarehouseInventoryRegistering.Write = True;
	WarehouseInventoryRegistering.Load(TableInventoryInWarehouses);
	
EndProcedure

Procedure ReflectGoodsAwaitingCustomsClearance(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsAwaitingCustomsClearance = AdditionalProperties.TableForRegisterRecords.TableGoodsAwaitingCustomsClearance;
	
	If Cancel
	 OR TableGoodsAwaitingCustomsClearance.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsAwaitingCustomsClearance = RegisterRecords.GoodsAwaitingCustomsClearance;
	RegisterRecordsGoodsAwaitingCustomsClearance.Write = True;
	RegisterRecordsGoodsAwaitingCustomsClearance.Load(TableGoodsAwaitingCustomsClearance);
	
EndProcedure

// Moves accumulation register CashAssetsInCRRReceipt.
//
Procedure ReflectCashAssetsInCashRegisters(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCashInCashRegisters = AdditionalProperties.TableForRegisterRecords.TableCashInCashRegisters;
	
	If Cancel
	 OR TableCashInCashRegisters.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsCashInCashRegisters = RegisterRecords.CashInCashRegisters;
	RegisterRecordsCashInCashRegisters.Write = True;
	RegisterRecordsCashInCashRegisters.Load(TableCashInCashRegisters);
	
EndProcedure

// Moves accumulation register Inventory.
//
Procedure ReflectInventory(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventory = AdditionalProperties.TableForRegisterRecords.TableInventory;
	
	If Cancel
	 OR TableInventory.Count() = 0 Then
		Return;
	EndIf;
	
	InventoryRecords = RegisterRecords.Inventory;
	InventoryRecords.Write = True;
	InventoryRecords.Load(TableInventory);
	
EndProcedure

// Moves on the register Sales targets.
//
Procedure ReflectSalesTarget(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSalesTarget = AdditionalProperties.TableForRegisterRecords.TableSalesTarget;
	
	If Cancel
	 OR TableSalesTarget.Count() = 0 Then
		Return;
	EndIf;
	
	SalesTargetRecords = RegisterRecords.SalesTarget;
	SalesTargetRecords.Write = True;
	SalesTargetRecords.Load(TableSalesTarget);
	
EndProcedure

// Moves on the register CashBudget.
//
Procedure ReflectCashBudget(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableCashBudget = AdditionalProperties.TableForRegisterRecords.TableCashBudget;
	
	If Cancel
	 OR TableCashBudget.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsBudgetCashBudget = RegisterRecords.CashBudget;
	RegisterRecordsBudgetCashBudget.Write = True;
	RegisterRecordsBudgetCashBudget.Load(TableCashBudget);
	
EndProcedure

// Moves accumulation register IncomeAndExpensesBudget.
//
Procedure ReflectIncomeAndExpensesBudget(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableIncomeAndExpensesBudget = AdditionalProperties.TableForRegisterRecords.TableIncomeAndExpensesBudget;
	
	If Cancel
	 OR TableIncomeAndExpensesBudget.Count() = 0 Then
		Return;
	EndIf;
	
	RegesteringIncomeAndExpencesForecast = RegisterRecords.IncomeAndExpensesBudget;
	RegesteringIncomeAndExpencesForecast.Write = True;
	RegesteringIncomeAndExpencesForecast.Load(TableIncomeAndExpensesBudget);
	
EndProcedure

// Moves on the register FinancialResultForecast.
//
Procedure ReflectFinancialResultForecast(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFinancialResultForecast = AdditionalProperties.TableForRegisterRecords.TableFinancialResultForecast;
	
	If Cancel
	 OR TableFinancialResultForecast.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFinancialResultForecast = RegisterRecords.FinancialResultForecast;
	RegisterRecordsFinancialResultForecast.Write = True;
	RegisterRecordsFinancialResultForecast.Load(TableFinancialResultForecast);
	
EndProcedure

// Moves on the register Purchases.
//
Procedure ReflectPurchases(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePurchases = AdditionalProperties.TableForRegisterRecords.TablePurchases;
	
	If Cancel
	 OR TablePurchases.Count() = 0 Then
		Return;
	EndIf;
	
	PurchaseRecord = RegisterRecords.Purchases;
	PurchaseRecord.Write = True;
	PurchaseRecord.Load(TablePurchases);
	
EndProcedure

// Moves on the register StockTransferredToThirdParties.
//
Procedure ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableStockTransferredToThirdParties = AdditionalProperties.TableForRegisterRecords.TableStockTransferredToThirdParties;
	
	If Cancel
	 OR TableStockTransferredToThirdParties.Count() = 0 Then
		Return;
	EndIf;
	
	StockTransferredToThirdPartiesRegestering = RegisterRecords.StockTransferredToThirdParties;
	StockTransferredToThirdPartiesRegestering.Write = True;
	StockTransferredToThirdPartiesRegestering.Load(TableStockTransferredToThirdParties);
	
EndProcedure

// Moves on the register Inventory received.
//
Procedure ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableStockReceivedFromThirdParties = AdditionalProperties.TableForRegisterRecords.TableStockReceivedFromThirdParties;
	
	If Cancel
	 OR TableStockReceivedFromThirdParties.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsStockReceivedFromThirdParties = RegisterRecords.StockReceivedFromThirdParties;
	RegisterRecordsStockReceivedFromThirdParties.Write = True;
	RegisterRecordsStockReceivedFromThirdParties.Load(TableStockReceivedFromThirdParties);
	
EndProcedure

// Moves on register Orders placement.
//
Procedure ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableBackorders = AdditionalProperties.TableForRegisterRecords.TableBackorders;
	
	If Cancel
	 OR TableBackorders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsBackorders = RegisterRecords.Backorders;
	RegisterRecordsBackorders.Write = True;
	RegisterRecordsBackorders.Load(TableBackorders);
	
EndProcedure

// Moves on the register Sales.
//
Procedure ReflectSales(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSales = AdditionalProperties.TableForRegisterRecords.TableSales;
	
	If Cancel
	 OR TableSales.Count() = 0 Then
		Return;
	EndIf;
	
	SalesRecord = RegisterRecords.Sales;
	SalesRecord.Write = True;
	SalesRecord.Load(TableSales);
	
EndProcedure

// Moves on the register Sales orders.
//
Procedure ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSalesOrders = AdditionalProperties.TableForRegisterRecords.TableSalesOrders;
	
	If Cancel
	 OR TableSalesOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSalesOrders = RegisterRecords.SalesOrders;
	RegisterRecordsSalesOrders.Write = True;
	RegisterRecordsSalesOrders.Load(TableSalesOrders);
	
EndProcedure

// Moves on the register Work orders.
//
Procedure ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableWorkOrders = AdditionalProperties.TableForRegisterRecords.TableWorkOrders;
	
	If Cancel
		OR TableWorkOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsWorkOrders = RegisterRecords.WorkOrders;
	RegisterRecordsWorkOrders.Write = True;
	RegisterRecordsWorkOrders.Load(TableWorkOrders);
	
EndProcedure

Procedure ReflectGoodsShippedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsShippedNotInvoiced = AdditionalProperties.TableForRegisterRecords.TableGoodsShippedNotInvoiced;
	
	If Cancel
	 OR TableGoodsShippedNotInvoiced.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsShippedNotInvoiced = RegisterRecords.GoodsShippedNotInvoiced;
	RegisterRecordsGoodsShippedNotInvoiced.Write = True;
	RegisterRecordsGoodsShippedNotInvoiced.Load(TableGoodsShippedNotInvoiced);
	
EndProcedure

Procedure ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsInvoicedNotShipped = AdditionalProperties.TableForRegisterRecords.TableGoodsInvoicedNotShipped;
	
	If Cancel
	 OR TableGoodsInvoicedNotShipped.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsInvoicedNotShipped = RegisterRecords.GoodsInvoicedNotShipped;
	RegisterRecordsGoodsInvoicedNotShipped.Write = True;
	RegisterRecordsGoodsInvoicedNotShipped.Load(TableGoodsInvoicedNotShipped);
	
EndProcedure

Procedure ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableGoodsReceivedNotInvoiced = AdditionalProperties.TableForRegisterRecords.TableGoodsReceivedNotInvoiced;
	
	If Cancel
		OR TableGoodsReceivedNotInvoiced.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsGoodsReceivedNotInvoiced = RegisterRecords.GoodsReceivedNotInvoiced;
	RegisterRecordsGoodsReceivedNotInvoiced.Write = True;
	RegisterRecordsGoodsReceivedNotInvoiced.Load(TableGoodsReceivedNotInvoiced);
	
EndProcedure

// Moves on the register InventoryFlowCalendar.
//
Procedure ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryFlowCalendar = AdditionalProperties.TableForRegisterRecords.TableInventoryFlowCalendar;
	
	If Cancel
	 OR TableInventoryFlowCalendar.Count() = 0 Then
		Return;
	EndIf;
	
	RegesteringSchedeuleInventoryMovement = RegisterRecords.InventoryFlowCalendar;
	RegesteringSchedeuleInventoryMovement.Write = True;
	RegesteringSchedeuleInventoryMovement.Load(TableInventoryFlowCalendar);
	
EndProcedure

// Moves on the register ProductionOrders.
//
Procedure ReflectProductionOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableProductionOrders = AdditionalProperties.TableForRegisterRecords.TableProductionOrders;
	
	If Cancel 
	 OR TableProductionOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsProductionOrders = RegisterRecords.ProductionOrders;
	RegisterRecordsProductionOrders.Write = True;
	RegisterRecordsProductionOrders.Load(TableProductionOrders);
	
EndProcedure

// Moves on the register InventoryDemand.
//
Procedure ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableInventoryDemand = AdditionalProperties.TableForRegisterRecords.TableInventoryDemand;
	
	If Cancel 
	 OR TableInventoryDemand.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsInventoryDemand = RegisterRecords.InventoryDemand;
	RegisterRecordsInventoryDemand.Write = True;
	RegisterRecordsInventoryDemand.Load(TableInventoryDemand);
	
EndProcedure

// Moves on the register Purchase orders statement.
//
Procedure ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TablePurchaseOrders = AdditionalProperties.TableForRegisterRecords.TablePurchaseOrders;
	
	If Cancel
	 OR TablePurchaseOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsPurchaseOrders = RegisterRecords.PurchaseOrders;
	RegisterRecordsPurchaseOrders.Write = True;
	RegisterRecordsPurchaseOrders.Load(TablePurchaseOrders);
	
EndProcedure

// Moves on the register Purchase orders statement.
//
Procedure ReflectFixedAssetUsage(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssetUsage = AdditionalProperties.TableForRegisterRecords.TableFixedAssetUsage;
	
	If Cancel
	 OR TableFixedAssetUsage.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFixedAssetsProduction = RegisterRecords.FixedAssetUsage;
	RegisterRecordsFixedAssetsProduction.Write = True;
	RegisterRecordsFixedAssetsProduction.Load(TableFixedAssetUsage);
	
EndProcedure

// Moves information register FixedAssetStatus.
//
Procedure ReflectFixedAssetStatuses(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssetsStates = AdditionalProperties.TableForRegisterRecords.TableFixedAssetsStates;
	
	If Cancel
	 OR TableFixedAssetsStates.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsStateOfFixedAssets = RegisterRecords.FixedAssetStatus;
	RegisterRecordsStateOfFixedAssets.Write = True;
	RegisterRecordsStateOfFixedAssets.Load(TableFixedAssetsStates);
	
EndProcedure

// Moves the InitialInformationDepreciationParameters information register.
//
Procedure ReflectFixedAssetParameters(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssetParameters = AdditionalProperties.TableForRegisterRecords.TableFixedAssetParameters;
	
	If Cancel
	 OR TableFixedAssetParameters.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFixedAssetParameters = RegisterRecords.FixedAssetParameters;
	RegisterRecordsFixedAssetParameters.Write = True;
	RegisterRecordsFixedAssetParameters.Load(TableFixedAssetParameters);
	
EndProcedure

// Moves information register MonthClosingError.
//
Procedure ReflectMonthEndErrors(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableMonthEndErrors = AdditionalProperties.TableForRegisterRecords.TableMonthEndErrors;
	
	If Cancel
	 OR TableMonthEndErrors.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsMonthEndErrors = RegisterRecords.MonthEndErrors;
	RegisterRecordsMonthEndErrors.Write = True;
	RegisterRecordsMonthEndErrors.Load(TableMonthEndErrors);
	
EndProcedure

// Moves accumulation register CapitalAssetsDepreciation
//
Procedure ReflectFixedAssets(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableFixedAssets = AdditionalProperties.TableForRegisterRecords.TableFixedAssets;
	
	If Cancel
	 OR TableFixedAssets.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsFixedAssets = RegisterRecords.FixedAssets;
	RegisterRecordsFixedAssets.Write = True;
	RegisterRecordsFixedAssets.Load(TableFixedAssets);
	
EndProcedure

// Moves on the register ObsoleteWorkOrders.
//
Procedure ReflectObsoleteWorkOrders(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableObsoleteWorkOrders = AdditionalProperties.TableForRegisterRecords.TableObsoleteWorkOrders;
	
	If Cancel OR TableObsoleteWorkOrders.Count() = 0 Then
		Return;
	EndIf;
	
	RegisteringsObsoleteWorkOrders = RegisterRecords.ObsoleteWorkOrders;
	RegisteringsObsoleteWorkOrders.Write = True;
	RegisteringsObsoleteWorkOrders.Load(TableObsoleteWorkOrders);
	
EndProcedure

// Moves on the register Workload.
//
Procedure ReflectWorkload(AdditionalProperties, RegisterRecords, Cancel) Export
	
	jobSheetTable = AdditionalProperties.TableForRegisterRecords.jobSheetTable;
	
	If Cancel
	 OR jobSheetTable.Count() = 0 Then
		Return;
	EndIf;
	
	RegisteringJobSheet = RegisterRecords.Workload;
	RegisteringJobSheet.Write = True;
	RegisteringJobSheet.Load(jobSheetTable);
	
EndProcedure

// Moves on the register ProductRelease.
//
Procedure ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableProductRelease = AdditionalProperties.TableForRegisterRecords.TableProductRelease;
	
	If Cancel
	 OR TableProductRelease.Count() = 0 Then
		Return;
	EndIf;
	
	RegistersProductionTurnout = RegisterRecords.ProductRelease;
	RegistersProductionTurnout.Write = True;
	RegistersProductionTurnout.Load(TableProductRelease);
	
EndProcedure

// Moves accumulation register BankCharges.
//
Procedure ReflectBankCharges(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableBankCharges = AdditionalProperties.TableForRegisterRecords.TableBankCharges;
	
	If Cancel
	 OR TableBankCharges.Count() = 0 Then
		Return;
	EndIf;
	
	BankChargesRegistering = RegisterRecords.BankCharges;
	BankChargesRegistering.Write = True;
	BankChargesRegistering.Load(TableBankCharges);
	
EndProcedure

// Moves accounting register.
//
Procedure ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAccountingJournalEntries = AdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries;
	
	If Cancel
	 OR TableAccountingJournalEntries.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterAdministratives = RegisterRecords.AccountingJournalEntries;
	RegisterAdministratives.Write = True;
	
	For Each RowTableAccountingJournalEntries In TableAccountingJournalEntries Do
		RegisterAdministrative = RegisterAdministratives.Add();
		FillPropertyValues(RegisterAdministrative, RowTableAccountingJournalEntries);
	EndDo;
	
EndProcedure

// Moves accumulation register VATInput
//
Procedure ReflectVATIncurred(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableVATIncurred = AdditionalProperties.TableForRegisterRecords.TableVATIncurred;
	
	If Cancel
	 OR TableVATIncurred.Count() = 0 Then
		Return;
	EndIf;
	
	VATIncurredRecord = RegisterRecords.VATIncurred;
	VATIncurredRecord.Write = True;
	VATIncurredRecord.Load(TableVATIncurred);
	
EndProcedure

// Moves accumulation register VATInput
//
Procedure ReflectVATInput(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableVATInput = AdditionalProperties.TableForRegisterRecords.TableVATInput;
	
	If Cancel
	 OR TableVATInput.Count() = 0 Then
		Return;
	EndIf;
	
	VATInputRecord = RegisterRecords.VATInput;
	VATInputRecord.Write = True;
	VATInputRecord.Load(TableVATInput);
	
EndProcedure

// Moves accumulation register VATOutput
//
Procedure ReflectVATOutput(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableVATOutput = AdditionalProperties.TableForRegisterRecords.TableVATOutput;
	
	If Cancel
	 OR TableVATOutput.Count() = 0 Then
		Return;
	EndIf;
	
	VATOutputRecord = RegisterRecords.VATOutput;
	VATOutputRecord.Write = True;
	VATOutputRecord.Load(TableVATOutput);
	
EndProcedure

Procedure ReflectTasksForUpdatingStatuses(Document, Cancel = False) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	Query = New Query;
	Query.SetParameter("Document", Document);
	
	Query.Text =
	"SELECT
	|	SalesInvoice.Ref AS Ref,
	|	SalesInvoice.BasisDocument AS BasisDocument
	|INTO SalesInovice
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SupplierInvoice.Ref AS Ref,
	|	SupplierInvoice.BasisDocument AS BasisDocument
	|INTO SupplierInovice
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Quote.Ref AS Document
	|INTO DocumentForUpdating
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SalesOrder.BasisDocument
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &Document
	|	AND VALUETYPE(SalesOrder.BasisDocument) = TYPE(Document.Quote)
	|	AND SalesOrder.BasisDocument <> VALUE(Document.Quote.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.BasisDocument
	|FROM
	|	SalesInovice AS SalesInvoice
	|WHERE
	|	VALUETYPE(SalesInvoice.BasisDocument) = TYPE(Document.Quote)
	|	AND SalesInvoice.BasisDocument <> VALUE(Document.Quote.EmptyRef)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SalesInvoiceInventory.GoodsIssue
	|FROM
	|	SalesInovice AS SalesInvoice
	|		INNER JOIN Document.SalesInvoice.Inventory AS SalesInvoiceInventory
	|		ON SalesInvoice.Ref = SalesInvoiceInventory.Ref
	|			AND (SalesInvoiceInventory.GoodsIssue <> VALUE(Document.GoodsIssue.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	SupplierInvoiceInventory.GoodsReceipt
	|FROM
	|	SupplierInovice AS SupplierInovice
	|		INNER JOIN Document.SupplierInvoice.Inventory AS SupplierInvoiceInventory
	|		ON SupplierInovice.Ref = SupplierInvoiceInventory.Ref
	|			AND (SupplierInvoiceInventory.GoodsReceipt <> VALUE(Document.GoodsReceipt.EmptyRef))
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsIssue.Ref
	|FROM
	|	Document.GoodsIssue AS GoodsIssue
	|WHERE
	|	GoodsIssue.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	GoodsReceipt.Ref
	|FROM
	|	Document.GoodsReceipt AS GoodsReceipt
	|WHERE
	|	GoodsReceipt.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref = &Document
	|
	|UNION ALL
	|
	|SELECT
	|	SupplierInvoice.Ref
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoice
	|WHERE
	|	SupplierInvoice.Ref = &Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentForUpdating.Document AS Document
	|FROM
	|	DocumentForUpdating AS DocumentForUpdating
	|
	|GROUP BY
	|	DocumentForUpdating.Document
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	TasksForUpdatingStatuses.Document AS Document
	|FROM
	|	InformationRegister.TasksForUpdatingStatuses AS TasksForUpdatingStatuses
	|WHERE
	|	TasksForUpdatingStatuses.Document = &Document";
	
	ResultArray = Query.ExecuteBatch();
	
	If ResultArray[3].IsEmpty() Then
		Return;
	EndIf;
	
	DocumentsInRegister = ResultArray[4].Unload();
	SelectionDocument = ResultArray[3].Select();
	
	While SelectionDocument.Next() Do
		If DocumentsInRegister.Find(SelectionDocument.Document, "Document") = Undefined Then
			RecordManager = InformationRegisters.TasksForUpdatingStatuses.CreateRecordManager();
			RecordManager.Document = SelectionDocument.Document;
			RecordManager.Write();
		EndIf;
	EndDo;
	
EndProcedure

Procedure ReflectUsingPaymentTermsInDocuments(Document, Cancel = False) Export
	
	If Cancel Then
		Return;
	EndIf;
	
	RecordManager = InformationRegisters.UsingPaymentTermsInDocuments.CreateRecordManager();
	RecordManager.Document = Document;
	RecordManager.UsingPaymentTerms = Document.SetPaymentTerms;
	RecordManager.Write();

EndProcedure

// Moves accounting register.
//
Procedure ReflectQuotations(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableQuotations = AdditionalProperties.TableForRegisterRecords.TableQuotations;
	
	If Cancel
		OR TableQuotations.Count() = 0 Then
		Return;
	EndIf;
	
	QuotationsRecord = RegisterRecords.Quotations;
	QuotationsRecord.Write = True;
	QuotationsRecord.Load(TableQuotations);
	
EndProcedure

#Region DiscountCards

// Moves on the register SalesWithCardBasedDiscounts.
//
Procedure ReflectSalesByDiscountCard(AdditionalProperties, RegisterRecords, Cancel) Export
	
	SaleByDiscountCardTable = AdditionalProperties.TableForRegisterRecords.SaleByDiscountCardTable;
	
	If Cancel
	 OR SaleByDiscountCardTable.Count() = 0 Then
		Return;
	EndIf;
	
	SalesByDiscountCardMovements = RegisterRecords.SalesWithCardBasedDiscounts;
	SalesByDiscountCardMovements.Write = True;
	SalesByDiscountCardMovements.Load(SaleByDiscountCardTable);
	
EndProcedure

#EndRegion

#Region AutomaticDiscounts

// Moves on the register ProvidedAutomaticDiscounts.
//
Procedure FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableAutomaticDiscountsApplied = AdditionalProperties.TableForRegisterRecords.TableAutomaticDiscountsApplied;
	
	If Cancel
	 OR TableAutomaticDiscountsApplied.Count() = 0 Then
		Return;
	EndIf;
	
	MovementsProvidedAutomaticDiscounts = RegisterRecords.AutomaticDiscountsApplied;
	MovementsProvidedAutomaticDiscounts.Write = True;
	MovementsProvidedAutomaticDiscounts.Load(TableAutomaticDiscountsApplied);
	
EndProcedure

#EndRegion

#Region WorkWithSerialNumbers

Procedure ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSerialNumbersInWarranty = AdditionalProperties.TableForRegisterRecords.TableSerialNumbersInWarranty;
	
	If Cancel
	 OR TableSerialNumbersInWarranty.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSerialNumbersInWarranty = RegisterRecords.SerialNumbersInWarranty;
	RegisterRecordsSerialNumbersInWarranty.Write = True;
	RegisterRecordsSerialNumbersInWarranty.Load(TableSerialNumbersInWarranty);
	
EndProcedure

Procedure ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel) Export
	
	TableSerialNumbersBalance = AdditionalProperties.TableForRegisterRecords.TableSerialNumbersBalance;
	
	If Cancel
	 OR TableSerialNumbersBalance.Count() = 0 Then
		Return;
	EndIf;
	
	RegisterRecordsSerialNumbersBalance = RegisterRecords.SerialNumbers;
	RegisterRecordsSerialNumbersBalance.Write = True;
	RegisterRecordsSerialNumbersBalance.Load(TableSerialNumbersBalance);
	
EndProcedure

#EndRegion

#Region AccountingRegisters

// Returns table with online and offline records.
// Online records created by source document, offline created by Month-end closing.
//
// Paremeters:
//	AccountingRecords - AccountingRegister.AccountingJournalEntries.Records - online records
//	DocumentRef - Document.Ref - Source document
//
// Returned value:
//	AccountingRegister.AccountingJournalEntries.Records
//
Function AddOfflineAccountingJournalEntriesRecords(AccountingRecords, DocumentRef) Export
	
	Query = New Query(
	"SELECT
	|	Table.AccountDr AS AccountDr,
	|	Table.AccountCr AS AccountCr,
	|	Table.Company AS Company,
	|	Table.PlanningPeriod AS PlanningPeriod,
	|	Table.CurrencyDr AS CurrencyDr,
	|	Table.CurrencyCr AS CurrencyCr,
	|	Table.Amount AS Amount,
	|	Table.AmountCurDr AS AmountCurDr,
	|	Table.AmountCurCr AS AmountCurCr,
	|	Table.Content AS Content,
	|	FALSE AS OfflineRecord,
	|	Table.Period AS Period
	|INTO NewRecords
	|FROM
	|	&Table AS Table
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	NewRecords.Period AS Period,
	|	NewRecords.AccountDr AS AccountDr,
	|	NewRecords.AccountCr AS AccountCr,
	|	NewRecords.Company AS Company,
	|	NewRecords.PlanningPeriod AS PlanningPeriod,
	|	NewRecords.CurrencyDr AS CurrencyDr,
	|	NewRecords.CurrencyCr AS CurrencyCr,
	|	NewRecords.Amount AS Amount,
	|	NewRecords.AmountCurDr AS AmountCurDr,
	|	NewRecords.AmountCurCr AS AmountCurCr,
	|	NewRecords.Content AS Content,
	|	NewRecords.OfflineRecord AS OfflineRecord
	|FROM
	|	NewRecords AS NewRecords
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord");
	
	Query.SetParameter("Table", AccountingRecords);
	Query.SetParameter("Ref", DocumentRef);
	
	Return Query.Execute().Unload();
	
EndFunction

// Returns empty value table
Function EmptyAccountingJournalEntriesTable() Export
	
	Query = New Query("
	|SELECT TOP 0
	|	AccountingJournalEntries.Period AS Period,
	|	AccountingJournalEntries.Recorder AS Recorder,
	|	AccountingJournalEntries.LineNumber AS LineNumber,
	|	AccountingJournalEntries.Active AS Active,
	|	AccountingJournalEntries.AccountDr AS AccountDr,
	|	AccountingJournalEntries.AccountCr AS AccountCr,
	|	AccountingJournalEntries.Company AS Company,
	|	AccountingJournalEntries.PlanningPeriod AS PlanningPeriod,
	|	AccountingJournalEntries.CurrencyDr AS CurrencyDr,
	|	AccountingJournalEntries.CurrencyCr AS CurrencyCr,
	|	AccountingJournalEntries.Amount AS Amount,
	|	AccountingJournalEntries.AmountCurDr AS AmountCurDr,
	|	AccountingJournalEntries.AmountCurCr AS AmountCurCr,
	|	AccountingJournalEntries.Content AS Content,
	|	AccountingJournalEntries.OfflineRecord AS OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS AccountingJournalEntries");
	
	Return Query.Execute().Unload();
	
EndFunction

#EndRegion

#EndRegion

#Region PricingSubsystemProceduresAndFunctions

// Returns currencies rates to date.
//
// Parameters:
//  Currency       - CatalogRef.Currencies - Currency (catalog item
//  "Currencies") CourseDate    - Date - date for which a rate should be received.
//
// Returns: 
//  Structure, contains:
//   ExchangeRate - Number - the exchange rate.
//   Multiplicity - Number - the exchange rate multiplier.
//
Function GetExchangeRates(CurrencyBeg, CurrencyEnd, ExchangeRateDate) Export
	
	StructureBeg = InformationRegisters.ExchangeRates.GetLast(ExchangeRateDate, New Structure("Currency", CurrencyBeg));
	StructureEnd = InformationRegisters.ExchangeRates.GetLast(ExchangeRateDate, New Structure("Currency", CurrencyEnd));
	
	StructureEnd.ExchangeRate = ?(
		StructureEnd.ExchangeRate = 0,
		1,
		StructureEnd.ExchangeRate
	);
	StructureEnd.Multiplicity = ?(
		StructureEnd.Multiplicity = 0,
		1,
		StructureEnd.Multiplicity
	);
	StructureEnd.Insert("InitRate", ?(StructureBeg.ExchangeRate      = 0, 1, StructureBeg.ExchangeRate));
	StructureEnd.Insert("RepetitionBeg", ?(StructureBeg.Multiplicity = 0, 1, StructureBeg.Multiplicity));
	
	Return StructureEnd;
	
EndFunction

Function RecalculateFromCurrencyToAccountingCurrency(AmountCur, CurrencyContract, ExchangeRateDate) Export
	
	Amount = 0;
	
	If ValueIsFilled(CurrencyContract) Then
		
		Currency = ?(TypeOf(CurrencyContract) = Type("CatalogRef.CounterpartyContracts"), CurrencyContract.SettlementsCurrency, CurrencyContract);
		PresentationCurrency = Constants.PresentationCurrency.Get();
		ExchangeRatesStructure = GetExchangeRates(Currency, PresentationCurrency, ExchangeRateDate);
		
		Amount = RecalculateFromCurrencyToCurrency(
					AmountCur,
					ExchangeRatesStructure.InitRate,
					ExchangeRatesStructure.ExchangeRate,
					ExchangeRatesStructure.RepetitionBeg,
					ExchangeRatesStructure.Multiplicity);
		
	EndIf;
	
	Return Amount;
	
EndFunction

// Function recalculates the amount from one currency to another
//
// Parameters:      
//  Amount        - Number - the amount to be converted.
// 	InitRate      - Number - the source currency exchange rate.
// 	FinRate       - Number - the target currency exchange rate.
// 	RepetitionBeg - Number - the exchange rate multiplier of the source currency.
//                           The default value is 1.
// 	RepetitionEnd - Number - the exchange rate multiplier of the target currency.
//                           The default value is 1.
//
// Returns: 
//  Number - amount recalculated to another currency.
//
Function RecalculateFromCurrencyToCurrency(Amount, InitRate, FinRate, RepetitionBeg = 1, RepetitionEnd = 1) Export
	
	If InitRate = FinRate AND RepetitionBeg = RepetitionEnd Then
		Return Amount;
	EndIf;
	
	If InitRate = 0
		OR FinRate = 0
		OR RepetitionBeg = 0
		OR RepetitionEnd = 0 Then
		CommonUseClientServer.MessageToUser(
			NStr("en = 'Zero exchange rate is found. Conversion is not executed.'"));
		Return Amount;
	EndIf;
	
	RecalculatedSumm = Round((Amount * InitRate * RepetitionEnd) / (FinRate * RepetitionBeg), 2);
	
	Return RecalculatedSumm;
	
EndFunction

// Calculates VAT amount on the basis of amount and taxation check boxes.
//
// Parameters:
//  Amount        - Number - VAT
//  amount AmountIncludesVAT - Boolean - shows that VAT is
//  included in the VATRate amount.    - CatalogRef.VATRates - ref to VAT rate.
//
// Returns:
//  Number        - recalculated VAT amount.
//
Function RecalculateAmountOnVATFlagsChange(Amount, AmountIncludesVAT, VATRate) Export
	
	Rate = VATRate.Rate;
	
	If AmountIncludesVAT Then
		
		Amount = (Amount * (100 + Rate)) / 100;
		
	Else
		
		Amount = (Amount * 100) / (100 + Rate);
		
	EndIf;
	
	Return Amount;
	
EndFunction

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary
//  when recalculation DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection) Export
	
	// Discounts.
	If DataStructure.Property("DiscountMarkupKind") 
		AND ValueIsFilled(DataStructure.DiscountMarkupKind) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupKind.Percent;
		
	EndIf;	
	
	// Discount card.
	If DataStructure.Property("DiscountPercentByDiscountCard") 
		AND ValueIsFilled(DataStructure.DiscountPercentByDiscountCard) Then
		
		DataStructure.DiscountMarkupPercent = DataStructure.DiscountMarkupPercent + DataStructure.DiscountPercentByDiscountCard;
		
	EndIf;
	
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	// Products.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Products", TypeDescription);
	
	// Characteristic.
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("VATRate", TypeDescription);	
	
	// MeasurementUnit.
	Array.Add(Type("CatalogRef.UOM"));
	Array.Add(Type("CatalogRef.UOMClassifier"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("MeasurementUnit", TypeDescription);	
	
	// Ratio.
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Factor", TypeDescription);
	
	For Each TSRow In DocumentTabularSection Do
		
		NewRow = ProductsTable.Add();
		NewRow.Products	 = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		NewRow.MeasurementUnit = TSRow.MeasurementUnit;
		If TypeOf(TSRow) = Type("Structure")
		   AND TSRow.Property("VATRate") Then
			NewRow.VATRate		 = TSRow.VATRate;
		EndIf;
		
		If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
			NewRow.Factor = 1;
		Else
			NewRow.Factor = TSRow.MeasurementUnit.Factor;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.VATRate,
	|	ProductsTable.Factor
	|INTO TemporaryProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable";
	
	Query.SetParameter("ProductsTable", ProductsTable);
	Query.Execute();
	
	// 2. We will fill prices.
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
		RoundingOrder = DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;	
	EndIf;	
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.VATRate AS VATRate,
	|	PricesSliceLast.PriceKind.PriceCurrency AS PricesCurrency,
	|	PricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	PricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	PricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(PricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsTable.Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON ProductsTable.Products = PricesSliceLast.Products
	|			AND ProductsTable.Characteristic = PricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON (PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	PricesSliceLast.Actuality";
		
	Query.SetParameter("ProcessingDate",	 DataStructure.Date);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	Query.SetParameter("DocumentCurrency", DataStructure.DocumentCurrency);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		If TypeOf(TSRow) = Type("Structure")
		   AND TabularSectionRow.Property("VATRate") Then
			SearchStructure.Insert("VATRate", TabularSectionRow.VATRate);
		EndIf;
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Dynamically calculate the price
				If DynamicPriceKind Then
					
					Price = Price * (1 + Markup / 100);
					
				Else	
					
					RoundingOrder = SearchResult[0].RoundingOrder;
					RoundUp = SearchResult[0].RoundUp;
					
				EndIf; 
				
				If DataStructure.Property("AmountIncludesVAT") 
				   AND ((DataStructure.AmountIncludesVAT AND Not SearchResult[0].PriceIncludesVAT) 
				   OR (NOT DataStructure.AmountIncludesVAT AND SearchResult[0].PriceIncludesVAT)) Then
					Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
					
				TabularSectionRow.Price = DriveClientServer.RoundPrice(Price, RoundingOrder, RoundUp);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
//
// Parameters:
//  AttributesStructure - Attribute structure, which necessary
//  when recalculation DocumentTabularSection - FormDataStructure, it
//                 contains the tabular document part.
//
Procedure GetPricesTabularSectionBySupplierPriceTypes(DataStructure, DocumentTabularSection) Export
	
	// 1. Generate document table.
	TempTablesManager = New TempTablesManager;
	
	ProductsTable = New ValueTable;
	
	Array = New Array;
	
	// Products.
	Array.Add(Type("CatalogRef.Products"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Products", TypeDescription);
	
	// Characteristic.
	Array.Add(Type("CatalogRef.ProductsCharacteristics"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Characteristic", TypeDescription);
	
	// VATRates.
	Array.Add(Type("CatalogRef.VATRates"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("VATRate", TypeDescription);	
	
	// MeasurementUnit.
	Array.Add(Type("CatalogRef.UOM"));
	Array.Add(Type("CatalogRef.UOMClassifier"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("MeasurementUnit", TypeDescription);	
	
	// Ratio.
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	
	ProductsTable.Columns.Add("Factor", TypeDescription);
	
	For Each TSRow In DocumentTabularSection Do
		
		NewRow = ProductsTable.Add();
		NewRow.Products	 = TSRow.Products;
		NewRow.Characteristic	 = TSRow.Characteristic;
		NewRow.MeasurementUnit = TSRow.MeasurementUnit;
		NewRow.VATRate		 = TSRow.VATRate;
		
		If TypeOf(TSRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier")
			Or Not ValueIsFilled(TSRow.MeasurementUnit) Then
			NewRow.Factor = 1;
		Else
			NewRow.Factor = TSRow.MeasurementUnit.Factor;
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text =
	"SELECT
	|	ProductsTable.Products,
	|	ProductsTable.Characteristic,
	|	ProductsTable.MeasurementUnit,
	|	ProductsTable.VATRate,
	|	ProductsTable.Factor
	|INTO TemporaryProductsTable
	|FROM
	|	&ProductsTable AS ProductsTable";
	
	Query.SetParameter("ProductsTable", ProductsTable);
	Query.Execute();
	
	// 2. We will fill prices.
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	ProductsTable.Products AS Products,
	|	ProductsTable.Characteristic AS Characteristic,
	|	ProductsTable.MeasurementUnit AS MeasurementUnit,
	|	ProductsTable.VATRate AS VATRate,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency AS PricesCurrency,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(CounterpartyPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(ProductsTable.Factor, 1) / ISNULL(CounterpartyPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	TemporaryProductsTable AS ProductsTable
	|		LEFT JOIN InformationRegister.CounterpartyPrices.SliceLast(&ProcessingDate, SupplierPriceTypes = &SupplierPriceTypes) AS CounterpartyPricesSliceLast
	|		ON ProductsTable.Products = CounterpartyPricesSliceLast.Products
	|			AND ProductsTable.Characteristic = CounterpartyPricesSliceLast.Characteristic
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON (CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	CounterpartyPricesSliceLast.Actuality";
		
	Query.SetParameter("ProcessingDate", 		DataStructure.Date);
	Query.SetParameter("SupplierPriceTypes",	DataStructure.SupplierPriceTypes);
	Query.SetParameter("DocumentCurrency", 	DataStructure.DocumentCurrency);
	
	PricesTable = Query.Execute().Unload();
	For Each TabularSectionRow In DocumentTabularSection Do
		
		SearchStructure = New Structure;
		SearchStructure.Insert("Products",	 TabularSectionRow.Products);
		SearchStructure.Insert("Characteristic",	 TabularSectionRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		SearchStructure.Insert("VATRate",		 TabularSectionRow.VATRate);
		
		SearchResult = PricesTable.FindRows(SearchStructure);
		If SearchResult.Count() > 0 Then
			
			Price = SearchResult[0].Price;
			If Price = 0 Then
				TabularSectionRow.Price = Price;
			Else
				
				// Consider: amount includes VAT.
				If (DataStructure.AmountIncludesVAT AND Not SearchResult[0].PriceIncludesVAT) 
					OR (NOT DataStructure.AmountIncludesVAT AND SearchResult[0].PriceIncludesVAT) Then
					Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, TabularSectionRow.VATRate);
				EndIf;
				
				TabularSectionRow.Price = Price;
				
			EndIf;
		EndIf;
		
	EndDo;
	
	TempTablesManager.Close();
	
EndProcedure

// Recalculates document after changes in "Prices and currency" form.
//
// Returns:
//  Number        - Obtained price of products by the pricelist.
//
Function GetProductsPriceByPriceKind(DataStructure) Export
	
	If DataStructure.PriceKind.CalculatesDynamically Then
		DynamicPriceKind = True;
		PriceKindParameter = DataStructure.PriceKind.PricesBaseKind;
		Markup = DataStructure.PriceKind.Percent;
		RoundingOrder = DataStructure.PriceKind.RoundingOrder;
		RoundUp = DataStructure.PriceKind.RoundUp;
	Else
		DynamicPriceKind = False;
		PriceKindParameter = DataStructure.PriceKind;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PricesSliceLast.PriceKind.PriceCurrency AS PricesCurrency,
	|	PricesSliceLast.PriceKind.PriceIncludesVAT AS PriceIncludesVAT,
	|	PricesSliceLast.PriceKind.RoundingOrder AS RoundingOrder,
	|	PricesSliceLast.PriceKind.RoundUp AS RoundUp,
	|	ISNULL(PricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(&Factor, 1) / ISNULL(PricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	InformationRegister.Prices.SliceLast(
	|			&ProcessingDate,
	|			Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND PriceKind = &PriceKind) AS PricesSliceLast
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON PricesSliceLast.PriceKind.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	PricesSliceLast.Actuality";
	
	Query.SetParameter("ProcessingDate",	 DataStructure.ProcessingDate);
	Query.SetParameter("Products",	 DataStructure.Products);
	Query.SetParameter("Characteristic",  DataStructure.Characteristic);
	Query.SetParameter("Factor",	 DataStructure.Factor);
	Query.SetParameter("DocumentCurrency", DataStructure.DocumentCurrency);
	Query.SetParameter("PriceKind",			 PriceKindParameter);
	
	Selection = Query.Execute().Select();
	
	Price = 0;
	While Selection.Next() Do
		
		Price = Selection.Price;
		
		// Dynamically calculate the price
		If DynamicPriceKind Then
			
			Price = Price * (1 + Markup / 100);
			
		Else
			
			RoundingOrder = Selection.RoundingOrder;
			RoundUp = Selection.RoundUp;
			
		EndIf;
		
		If DataStructure.Property("AmountIncludesVAT") AND DataStructure.Property("VATRate")
			AND ((DataStructure.AmountIncludesVAT AND Not Selection.PriceIncludesVAT)
			OR (NOT DataStructure.AmountIncludesVAT AND Selection.PriceIncludesVAT)) Then
			Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
		EndIf;
		
		Price = DriveClientServer.RoundPrice(Price, RoundingOrder, RoundUp);
		
	EndDo;
	
	Return Price;
	
EndFunction

// Recalculates document after changes in "Prices and currency" form.
//
// Returns:
//  Number        - Obtained price of products by the pricelist.
//
Function GetPriceProductsBySupplierPriceTypes(DataStructure) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency AS PricesCurrency,
	|	CounterpartyPricesSliceLast.SupplierPriceTypes.PriceIncludesVAT AS PriceIncludesVAT,
	|	ISNULL(CounterpartyPricesSliceLast.Price * RateCurrencyTypePrices.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * RateCurrencyTypePrices.Multiplicity) * ISNULL(&Factor, 1) / ISNULL(CounterpartyPricesSliceLast.MeasurementUnit.Factor, 1), 0) AS Price
	|FROM
	|	InformationRegister.CounterpartyPrices.SliceLast(
	|			&ProcessingDate,
	|			Products = &Products
	|				AND Characteristic = &Characteristic
	|				AND SupplierPriceTypes = &SupplierPriceTypes) AS CounterpartyPricesSliceLast
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, ) AS RateCurrencyTypePrices
	|		ON CounterpartyPricesSliceLast.SupplierPriceTypes.PriceCurrency = RateCurrencyTypePrices.Currency,
	|	InformationRegister.ExchangeRates.SliceLast(&ProcessingDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|WHERE
	|	CounterpartyPricesSliceLast.Actuality";
	
	Query.SetParameter("ProcessingDate",	 	DataStructure.ProcessingDate);
	Query.SetParameter("Products",	 	DataStructure.Products);
	Query.SetParameter("Characteristic",  	DataStructure.Characteristic);
	Query.SetParameter("Factor",	 	DataStructure.Factor);
	Query.SetParameter("DocumentCurrency", 	DataStructure.DocumentCurrency);
	Query.SetParameter("SupplierPriceTypes",	DataStructure.SupplierPriceTypes);
	
	Selection = Query.Execute().Select();
	
	Price = 0;
	While Selection.Next() Do
		
		Price = Selection.Price;
		
		// Consider: amount includes VAT.
		If (DataStructure.AmountIncludesVAT AND Not Selection.PriceIncludesVAT)
		 OR (NOT DataStructure.AmountIncludesVAT AND Selection.PriceIncludesVAT) Then
			Price = RecalculateAmountOnVATFlagsChange(Price, DataStructure.AmountIncludesVAT, DataStructure.VATRate);
		EndIf;
		
	EndDo;
	
	Return Price;
	
EndFunction

// Get working time standard.
//
// Returns:
//  Number        - Obtained price of products by the pricelist.
//
Function GetWorkTimeRate(DataStructure) Export
	
	Query = New Query("SELECT
	|	SliceLastTimeStandards.Norm AS Norm
	|FROM
	|	InformationRegister.StandardTime.SliceLast(
	|			&ProcessingDate,
	|			Products = &Products
	|				AND Characteristic = &Characteristic) AS SliceLastTimeStandards");
	
	Query.SetParameter("Products", DataStructure.Products);
	Query.SetParameter("Characteristic", DataStructure.Characteristic);
	Query.SetParameter("ProcessingDate", DataStructure.ProcessingDate);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		Return Selection.Norm;		
	EndDo;
	
	Return 1;
	
EndFunction

// Receives data set: Amount, VAT amount.
//
Function GetTabularSectionRowSum(DataStructure) Export
	
	If DataStructure.Property("Quantity") And DataStructure.Property("Price") Then
		
		DataStructure.Amount = DataStructure.Quantity * DataStructure.Price;
		
	EndIf;
	
	If DataStructure.Property("DiscountMarkupPercent") Then
		
		If DataStructure.DiscountMarkupPercent = 100 Then
			
			DataStructure.Amount = 0;
			
		ElsIf DataStructure.DiscountMarkupPercent <> 0 Then
			
			DataStructure.Amount = DataStructure.Amount * (1 - DataStructure.DiscountMarkupPercent / 100);
			
		EndIf;
		
	EndIf;
	
	If DataStructure.Property("VATAmount") Then
		
		VATRate = DriveReUse.GetVATRateValue(DataStructure.VATRate);
		DataStructure.VATAmount = ?(DataStructure.AmountIncludesVAT, DataStructure.Amount - (DataStructure.Amount) / ((VATRate + 100) / 100), DataStructure.Amount * VATRate / 100);
		DataStructure.Total = DataStructure.Amount + ?(DataStructure.AmountIncludesVAT, 0, DataStructure.VATAmount);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function TableRoundingOrders() Export
	
	Result = New ValueTable;
	Result.Columns.Add("Order", New TypeDescription("EnumRef.RoundingMethods"));
	Result.Columns.Add("Value", New TypeDescription("Number", New NumberQualifiers(15, 2)));
	
	For Each Value In Metadata.Enums.RoundingMethods.EnumValues Do
		Row = Result.Add();
		Row.Order = Enums.RoundingMethods[Value.Name];
		Row.Value = DriveClientServer.NumberByRoundingOrder(Row.Order);
	EndDo;
	
	Return Result;
	
EndFunction

#Region DiscountCards

// Function returns a structure with the start date and accumulation period
// end by discount card and also the period text presentation.
//
Function GetProgressiveDiscountsCalculationPeriodByDiscountCard(DiscountDate, DiscountCard) Export

	If Not ValueIsFilled(DiscountDate) Then
		DiscountDate = CurrentDate();
	EndIf;
	
	PeriodPresentation = "";
	If DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.EntirePeriod Then
		BeginOfPeriod = '00010101';
		EndOfPeriod = '00010101';
		PeriodPresentation = "for all time";
	ElsIf DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.Current Then
		If DiscountCard.Owner.Periodicity = Enums.Periodicity.Year Then
			BeginOfPeriod = BegOfYear(DiscountDate);
			PeriodPresentation = "for the current year";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Quarter Then
			BeginOfPeriod = BegOfQuarter(DiscountDate);
			PeriodPresentation = "for the current quarter";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Month Then
			BeginOfPeriod = BegOfMonth(DiscountDate);
			PeriodPresentation = "for the current month";
		EndIf;
		EndOfPeriod = EndOfDay(DiscountDate);
	ElsIf DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.Past Then
		If DiscountCard.Owner.Periodicity = Enums.Periodicity.Year Then
			DatePrePeriod = AddMonth(DiscountDate, -12);
			BeginOfPeriod = BegOfYear(DatePrePeriod);
			EndOfPeriod = EndOfYear(DatePrePeriod);
			PeriodPresentation = "for the past year";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Quarter Then
			DatePrePeriod = AddMonth(DiscountDate, -3);
			BeginOfPeriod = BegOfQuarter(DatePrePeriod);
			EndOfPeriod = EndOfQuarter(DatePrePeriod);
			PeriodPresentation = "for the past year quarter";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Month Then
			DatePrePeriod = AddMonth(DiscountDate, -1);
			BeginOfPeriod = BegOfMonth(DatePrePeriod);
			EndOfPeriod = EndOfMonth(DatePrePeriod);
			PeriodPresentation = "for the past month";
		EndIf;
	ElsIf DiscountCard.Owner.PeriodKind = Enums.PeriodTypeForCumulativeDiscounts.Last Then
		If DiscountCard.Owner.Periodicity = Enums.Periodicity.Year Then
			DatePrePeriod = AddMonth(DiscountDate, -12);
			PeriodPresentation = "for the past year";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Quarter Then
			DatePrePeriod = AddMonth(DiscountDate, -3);
			PeriodPresentation = "for the last quarter";
		ElsIf DiscountCard.Owner.Periodicity = Enums.Periodicity.Month Then
			DatePrePeriod = AddMonth(DiscountDate, -1);
			PeriodPresentation = "for the last month";
		EndIf;		
		BeginOfPeriod = BegOfDay(DatePrePeriod);
		EndOfPeriod = BegOfDay(DiscountDate) - 1; // Previous day end.
	Else
		BeginOfPeriod = '00010101';
		EndOfPeriod = '00010101';
		PeriodPresentation = "";
	EndIf;
	
	Return New Structure("BeginOfPeriod, EndOfPeriod, PeriodPresentation", BeginOfPeriod, EndOfPeriod, PeriodPresentation);

EndFunction

// Returns the discount percent by discount card.
//
// Parameters:
//  DiscountCard - CatalogRef.DiscountCards - Ref on discount card.
//
// Returns: 
//   Number - discount percent.
//
Function CalculateDiscountPercentByDiscountCard(Val DiscountDate, DiscountCard, AdditionalParameters = Undefined) Export
	
	Var BeginOfPeriod, EndOfPeriod;
	
	If Not ValueIsFilled(DiscountDate) Then
		DiscountDate = CurrentDate();
	EndIf;
	
	If DiscountCard.Owner.DiscountKindForDiscountCards = Enums.DiscountTypeForDiscountCards.FixedDiscount Then
		
		If AdditionalParameters <> Undefined AND AdditionalParameters.GetSalesAmount Then
			AccumulationPeriod = GetProgressiveDiscountsCalculationPeriodByDiscountCard(DiscountDate, DiscountCard.Ref);

			AdditionalParameters.Insert("PeriodPresentation", AccumulationPeriod.PeriodPresentation);
			
			Query = New Query("SELECT
			                      |	ISNULL(SUM(RegSales.AmountTurnover), 0) AS AmountTurnover
			                      |FROM
			                      |	AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS RegSales");

			Query.SetParameter("DateBeg", AccumulationPeriod.BeginOfPeriod);
			Query.SetParameter("DateEnd", AccumulationPeriod.EndOfPeriod);
			Query.SetParameter("DiscountCard", DiscountCard.Ref);
	        
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				AdditionalParameters.Amount = Selection.AmountTurnover;
			Else
				AdditionalParameters.Amount = 0;
			EndIf;		
		
		EndIf;
		
		Return DiscountCard.Owner.Discount;
		
	Else
		
		AccumulationPeriod = GetProgressiveDiscountsCalculationPeriodByDiscountCard(DiscountDate, DiscountCard.Ref);
		
		Query = New Query("SELECT ALLOWED
		                      |	Thresholds.Discount AS Discount,
		                      |	Thresholds.LowerBound AS LowerBound
		                      |INTO TU_Thresholds
		                      |FROM
		                      |	Catalog.DiscountCardTypes.ProgressiveDiscountLimits AS Thresholds
		                      |WHERE
		                      |	Thresholds.Ref = &KindDiscountCard
		                      |;
		                      |
		                      |////////////////////////////////////////////////////////////////////////////////
		                      |SELECT ALLOWED
		                      |	RegThresholds.Discount AS Discount
		                      |FROM
		                      |	(SELECT
		                      |		ISNULL(SUM(RegSales.AmountTurnover), 0) AS AmountTurnover
		                      |	FROM
		                      |		AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS RegSales) AS RegSales
		                      |		INNER JOIN (SELECT
		                      |			Thresholds.LowerBound AS LowerBound,
		                      |			Thresholds.Discount AS Discount
		                      |		FROM
		                      |			TU_Thresholds AS Thresholds) AS RegThresholds
		                      |		ON (RegThresholds.LowerBound <= RegSales.AmountTurnover)
		                      |		INNER JOIN (SELECT
		                      |			MAX(RegThresholds.LowerBound) AS LowerBound
		                      |		FROM
		                      |			(SELECT
		                      |				ISNULL(SUM(RegSales.AmountTurnover), 0) AS AmountTurnover
		                      |			FROM
		                      |				AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS RegSales) AS RegSales
		                      |				INNER JOIN (SELECT
		                      |					Thresholds.LowerBound AS LowerBound
		                      |				FROM
		                      |					TU_Thresholds AS Thresholds) AS RegThresholds
		                      |				ON (RegThresholds.LowerBound <= RegSales.AmountTurnover)) AS RegMaxThresholds
		                      |		ON (RegMaxThresholds.LowerBound = RegThresholds.LowerBound)");

		Query.SetParameter("DateBeg", AccumulationPeriod.BeginOfPeriod);
		Query.SetParameter("DateEnd", AccumulationPeriod.EndOfPeriod);
		Query.SetParameter("DiscountCard", DiscountCard.Ref);
        Query.SetParameter("KindDiscountCard", DiscountCard.Owner);

		If AdditionalParameters <> Undefined AND AdditionalParameters.GetSalesAmount Then
			AdditionalParameters.Insert("PeriodPresentation", AccumulationPeriod.PeriodPresentation);
			
			Query.Text = Query.Text + ";
			                              |////////////////////////////////////////////////////////////////////////////////
			                              |SELECT
			                              |	SalesWithCardBasedDiscountsTurnovers.AmountTurnover
			                              |FROM
			                              |	AccumulationRegister.SalesWithCardBasedDiscounts.Turnovers(&DateBeg, &DateEnd, , DiscountCard = &DiscountCard) AS SalesWithCardBasedDiscountsTurnovers";
			MResults = Query.ExecuteBatch();
			
			Selection = MResults[1].Select();
			If Selection.Next() Then
				CumulativeDiscountPercent = Selection.Discount;
			Else
				CumulativeDiscountPercent = 0;
			EndIf;		
			
			SelectionByAmountOfSales = MResults[2].Select();
			If SelectionByAmountOfSales.Next() Then
				AdditionalParameters.Amount = SelectionByAmountOfSales.AmountTurnover;
			Else
				AdditionalParameters.Amount = 0;
			EndIf;
			
			Return CumulativeDiscountPercent;

		Else
			Selection = Query.Execute().Select();
			If Selection.Next() Then
				CumulativeDiscountPercent = Selection.Discount;
			Else
				CumulativeDiscountPercent = 0;
			EndIf;		
				
			Return CumulativeDiscountPercent;
		EndIf;
		
	EndIf;
	
EndFunction

// Returns the discount percentage by discount type.
//
// Parameters:
//  DataStructure - Structure - Structure of attributes required during recalculation
//
// Returns: 
//   Number - discount percent.
//
Function GetDiscountPercentByDiscountMarkupKind(DiscountMarkupKind) Export
	
	Return DiscountMarkupKind.Percent;
	
EndFunction

#EndRegion

#EndRegion

#Region ProceduresAndFunctionsGeneratingMessagesTextsOnPostingErrors

// Generates petty cash presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - characteristic presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function CashBankAccountPresentation(BankAccountCashPresentation,
										   CashAssetsTypeRepresentation = "",
										   CurrencyPresentation = "") Export
	
	PresentationString = TrimAll(BankAccountCashPresentation);
	
	If ValueIsFilled(CashAssetsTypeRepresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CashAssetsTypeRepresentation);
	EndIf;
	
	If ValueIsFilled(CurrencyPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CurrencyPresentation);
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates a string of products presentation considering characteristics and series.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  CharacteristicPresentation - String - characteristic presentation.
//  BatchPresentation - String - batch presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function PresentationOfProducts(ProductsPresentation,
	                              CharacteristicPresentation  = "",
	                              BatchPresentation          = "",
								  SalesOrderPresentation = "") Export
	
	PresentationString = TrimAll(ProductsPresentation);
	
	If ValueIsFilled(CharacteristicPresentation)Then
		PresentationString = PresentationString + " / " + TrimAll(CharacteristicPresentation);
	EndIf;
	
	If  ValueIsFilled(BatchPresentation) Then
		PresentationString = PresentationString + " / " + TrimAll(BatchPresentation);
	EndIf;
	
	If ValueIsFilled(SalesOrderPresentation) Then
		PresentationString = PresentationString + " / " + TrimAll(SalesOrderPresentation);
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates counterparty presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - characteristic presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function CounterpartyPresentation(CounterpartyPresentation,
	                             ContractPresentation = "",
	                             DocumentPresentation = "",
	                             OrderPresentation = "",
	                             CalculationTypesPresentation = "") Export
	
	PresentationString = TrimAll(CounterpartyPresentation);
	
	If ValueIsFilled(ContractPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(ContractPresentation);
	EndIf;
	
	If ValueIsFilled(DocumentPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(DocumentPresentation);
	EndIf;
	
	If ValueIsFilled(OrderPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(OrderPresentation);
	EndIf;
	
	If ValueIsFilled(CalculationTypesPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CalculationTypesPresentation);
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates a business unit presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - characteristic presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function PresentationOfStructuralUnit(StructuralUnitPresentation,
	                             PresentationCell = "") Export
	
	PresentationString = TrimAll(StructuralUnitPresentation);
	
	If ValueIsFilled(PresentationCell) Then
		PresentationString = PresentationString + " (" + PresentationCell + ")";
	EndIf;
	
	Return PresentationString;
	
EndFunction

// Generates petty cash presentation row.
//
// Parameters:
//  ProductsPresentation - String - Products presentation.
//  ProductAccountingKindPresentation - String - kind of Products presentation.
//  CharacteristicPresentation - String - characteristic presentation.
//  SeriesPresentation - String - series presentation.
//  StagePresentation - String - call presentation.
//
// Returns:
//  String - ref with the products presentation.
//
Function PresentationOfAccountablePerson(AdvanceHolderPresentation,
	                       			  CurrencyPresentation = "",
									  DocumentPresentation = "") Export
	
	PresentationString = TrimAll(AdvanceHolderPresentation);
	
	If ValueIsFilled(CurrencyPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(CurrencyPresentation);
	EndIf;
	
	If ValueIsFilled(DocumentPresentation)Then
		PresentationString = PresentationString + ", " + TrimAll(DocumentPresentation);
	EndIf;    
	
	Return PresentationString;
	
EndFunction

// The function returns individual passport details
// as a string used in print forms.
//
// Parameters
//  DataStructure - Structure - ref to Ind and date
//                 
// Returns:
//   Row      - String containing passport data
//
Function GetPassportDataAsString(DataStructure) Export

	If Not ValueIsFilled(DataStructure.Ind) Then
		Return NStr("en = 'There is no data on the identity card.'");
	EndIf; 
	
	Query = New Query("SELECT
	                  |	LegalDocuments.DocumentKind,
	                  |	LegalDocuments.Number,
	                  |	LegalDocuments.IssueDate,
	                  |	LegalDocuments.Authority
	                  |FROM
	                  |	Catalog.LegalDocuments AS LegalDocuments
	                  |WHERE
	                  |	LegalDocuments.Owner = &Owner
	                  |
	                  |ORDER BY
	                  |	LegalDocuments.IssueDate DESC");
	
	Query.SetParameter("Owner", DataStructure.Ind);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return NStr("en = 'There is no data on the identity card.'");
	Else
		PassportData	= QueryResult.Unload()[0];
		DocumentKind	= PassportData.DocumentKind;
		Number			= PassportData.Number;
		IssueDate		= PassportData.IssueDate;
		Authority		= PassportData.Authority;
		
		If Not (NOT ValueIsFilled(IssueDate)
			AND Not ValueIsFilled(DocumentKind)
			AND Not ValueIsFilled(Number + Authority)) Then

			PersonalDataList = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 #%2, Issued: %3, %4'"),
			?(DocumentKind.IsEmpty(),"","" + DocumentKind + ", "), Number, Format(IssueDate,"DLF=DD"), Authority);
			
			Return PersonalDataList;

		Else
			Return NStr("en = 'There is no data on the identity card.'");
		EndIf;
	EndIf;

EndFunction

// Function returns structural units type presentation.
//
Function GetStructuralUnitTypePresentation(StructuralUnitType)
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		StructuralUnitTypePresentation = "to department";
	ElsIf StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		StructuralUnitTypePresentation = "in retail warehouse";
	Else
		StructuralUnitTypePresentation = "at warehouse";
	EndIf;
	
	Return StructuralUnitTypePresentation
	
EndFunction

#EndRegion

#Region ProcedureOfPostingErrorsMessagesIssuing

// The procedure informs of errors that occurred when posting by register Inventory in warehouses.
//
Procedure ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'There is not enough inventory %StructuralUnitType% %StructuralUnitPresentation%'");
	
	MessagePattern = NStr("en = 'Product: %1, available %2 %3, not enough %4 %3'");
		
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If (NOT UseSeveralWarehouses AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
				OR (NOT UseSeveralDepartments AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
				PresentationOfStructuralUnit = "";
			Else
				PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
			EndIf;
			MessageTitleText = StrReplace(MessageTitleTemplate, "%StructuralUnitPresentation%", PresentationOfStructuralUnit);
			MessageTitleText = StrReplace(MessageTitleText, "%StructuralUnitType%", GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, PresentationOfProducts, String(RecordsSelection.BalanceInventoryInWarehouses),
						TrimAll(RecordsSelection.MeasurementUnitPresentation), String(-RecordsSelection.QuantityBalanceInventoryInWarehouses));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsAwaitingCustomsClearanceRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The entry results in negative inventory in the ""Goods awaiting customs clearance"" register'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance %2 %3, not enough %4 %3'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic, RecordsSelection.Batch);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.QuantityBalanceBeforeChange),
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors occurred while posting by the
// Inventory on warehouses register for the structural units list.
//
Procedure ShowMessageAboutPostingToInventoryInWarehousesRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient inventory'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1,
	                      |%2 %3
	                      |available %4 %5,
	                      |not enough %6 %5'");
	
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If (NOT UseSeveralWarehouses AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
			OR (NOT UseSeveralDepartments AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
			PresentationOfStructuralUnit = "";
		Else
			PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, 
																				RecordsSelection.CharacteristicPresentation,
																				RecordsSelection.BatchPresentation);
																				
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, PresentationOfProducts,
																				GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType),
																				PresentationOfStructuralUnit,
																				String(RecordsSelection.BalanceInventoryInWarehouses),
																				TrimAll(RecordsSelection.MeasurementUnitPresentation),
																				String(-RecordsSelection.QuantityBalanceInventoryInWarehouses),
																				TrimAll(RecordsSelection.MeasurementUnitPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory.
//
Procedure ShowMessageAboutPostingToInventoryRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'There is not enough balance on inventory and expenses %StructuralUnitType% %StructuralUnitPresentation%'");
	
	MessagePattern = NStr("en = 'Product: %ProductsCharacteristicsBatch%,
	                      |available %BalanceQuantity% %MeasurementUnit%,
	                      |not enough %QuantityAndReserve% %MeasurementUnit%'");
	
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If (NOT UseSeveralWarehouses AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
				OR (NOT UseSeveralDepartments AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
				PresentationOfStructuralUnit = "";
			Else
				PresentationOfStructuralUnit = TrimAll(RecordsSelection.StructuralUnitPresentation);
			EndIf;
			MessageTitleText = StrReplace(MessageTitleTemplate, "%StructuralUnitPresentation%", PresentationOfStructuralUnit);
			MessageTitleText = StrReplace(MessageTitleText, "%StructuralUnitType%", GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		If IsBlankString(RecordsSelection.SalesOrderPresentation) Then
			MessageText = StrReplace(MessageText, "%BalanceQuantity%", String(RecordsSelection.BalanceInventory));
			MessageText = StrReplace(MessageText, "%QuantityAndReserve%", String(-RecordsSelection.QuantityBalanceInventory));
		Else
			MessageText = StrReplace(MessageText, "%BalanceQuantity%", "reserve " + String(RecordsSelection.BalanceInventory));
			MessageText = StrReplace(MessageText, "%QuantityAndReserve%", "reserve " + String(-RecordsSelection.QuantityBalanceInventory));
		EndIf;
		
		MessageText = StrReplace(MessageText, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of posting errors
// by the Reserves register for a business unit list.
//
Procedure ShowMessageAboutPostingToInventoryRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'No enough balances in the inventory accumulation register'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %ProductsCharacteristicsBatch%,
	                      |%StructuralUnitType% %StructuralUnitPresentation%,
	                      |available %BalanceQuantity% %MeasurementUnit%,
	                      |not enough %QuantityAndReserve% %MeasurementUnit%'");
		
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	UseSeveralDepartments = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If (NOT UseSeveralWarehouses AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
			OR (NOT UseSeveralDepartments AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
			PresentationOfStructuralUnit = "";
		Else
			PresentationOfStructuralUnit = TrimAll(RecordsSelection.StructuralUnitPresentation);
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%StructuralUnitPresentation%", PresentationOfStructuralUnit);
		MessageText = StrReplace(MessageText, "%StructuralUnitType%", GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType));
		
		If IsBlankString(RecordsSelection.SalesOrderPresentation) Then
			MessageText = StrReplace(MessageText, "%BalanceQuantity%", String(RecordsSelection.BalanceInventory));
			MessageText = StrReplace(MessageText, "%QuantityAndReserve%", String(-RecordsSelection.QuantityBalanceInventory));
		Else
			MessageText = StrReplace(MessageText, "%BalanceQuantity%", "reserve " + String(RecordsSelection.BalanceInventory));
			MessageText = StrReplace(MessageText, "%QuantityAndReserve%", "reserve " + String(-RecordsSelection.QuantityBalanceInventory));
		EndIf;
		
		MessageText = StrReplace(MessageText, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory transferred.
//
Procedure ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'There is not enough inventory transferred to %CounterpartyPresentation%'");
	MessagePattern = NStr("en = 'Product: %ProductsCharacteristicsBatch%,'");
	
	TitleInDetailsShow = True;
	PresentationCurrency = Constants.PresentationCurrency.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			MessageTitleText = StrReplace(MessageTitleTemplate, "%CounterpartyPresentation%", TrimAll(RecordsSelection.CounterpartyPresentation));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		If RecordsSelection.QuantityBalanceStockTransferredToThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'available %BalanceQuantity% %MeasurementUnit%,
			                             |not enough %Quantity% %MeasurementUnit%'");
			
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%BalanceQuantity%", String(RecordsSelection.BalanceStockTransferredToThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%Quantity%", String(-RecordsSelection.QuantityBalanceStockTransferredToThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors occurred while posting by
// the Inventory register passed for the third party counterparties list.
//
Procedure ShowMessageAboutPostingToStockTransferredToThirdPartiesRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'No enough balances of the inventory transferred to the counterparty.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %ProductsCharacteristicsBatch%,
	                      |counterparty %CounterpartyPresentation%'");
	PresentationCurrency = Constants.PresentationCurrency.Get();
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", TrimAll(RecordsSelection.CounterpartyPresentation));
		
		If RecordsSelection.QuantityBalanceStockTransferredToThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'available %BalanceQuantity% %MeasurementUnit%,
			                             |not enough %Quantity% %MeasurementUnit%'");
			
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%BalanceQuantity%", String(RecordsSelection.BalanceStockTransferredToThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%Quantity%", String(-RecordsSelection.QuantityBalanceStockTransferredToThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory received.
//
Procedure ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'There is not enough inventory received from %CounterpartyPresentation%'");
	MessagePattern = NStr("en = 'Product: %ProductsCharacteristicsBatch%,'");
	
	TitleInDetailsShow = True;
	PresentationCurrency = Constants.PresentationCurrency.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			MessageTitleText = StrReplace(MessageTitleTemplate, "%CounterpartyPresentation%", TrimAll(RecordsSelection.CounterpartyPresentation));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		If RecordsSelection.QuantityBalanceStockReceivedFromThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'available %BalanceQuantity% %MeasurementUnit%,
			                             |not enough %Quantity% %MeasurementUnit%'");
			
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%BalanceQuantity%", String(RecordsSelection.BalanceStockReceivedFromThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%Quantity%", String(-RecordsSelection.QuantityBalanceStockReceivedFromThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory received.
//
Procedure ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrorsAsList(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient inventory received from the counterparty'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	MessagePattern = NStr("en = 'Product: %ProductsCharacteristicsBatch%, 
	                      |counterparty %CounterpartyPresentation%'");
		
	PresentationCurrency = Constants.PresentationCurrency.Get();
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%CounterpartyPresentation%", TrimAll(RecordsSelection.CounterpartyPresentation));
		
		If RecordsSelection.QuantityBalanceStockReceivedFromThirdParties <> 0 Then
			
			TextOfMessageQuantity = NStr("en = 'balance %BalanceQuantity% %MeasurementUnit%,
			                             |not enough %Quantity% %MeasurementUnit%'");
			
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%BalanceQuantity%", String(RecordsSelection.BalanceStockReceivedFromThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%Quantity%", String(-RecordsSelection.QuantityBalanceStockReceivedFromThirdParties));
			TextOfMessageQuantity = StrReplace(TextOfMessageQuantity, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
			
			MessageText = MessageText + Chars.LF + TextOfMessageQuantity;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Sales orders.
//
Procedure ShowMessageAboutPostingToSalesOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the sales order'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %ProductsCharacteristicsBatch%,
	                      |balance by order %BalanceQuantity% %MeasurementUnit%, 
	                      |exceeds by %Quantity% %MeasurementUnit%. %SalesOrder%'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%BalanceQuantity%", String(RecordsSelection.BalanceSalesOrders));
		MessageText = StrReplace(MessageText, "%Quantity%", String(-RecordsSelection.QuantityBalanceSalesOrders));
		MessageText = StrReplace(MessageText, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
		MessageText = StrReplace(MessageText, "%SalesOrder%", TrimAll(RecordsSelection.OrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Work orders.
//
Procedure ShowMessageAboutPostingToWorkOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the work order'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %1,
						|balance by order %2 %3, 
						|exceeds by %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessagePattern,
			PresentationOfProducts,
			RecordsSelection.BalanceSalesOrders,
			TrimAll(RecordsSelection.MeasurementUnitPresentation),
			-RecordsSelection.QuantityBalanceSalesOrders,
			TrimAll(RecordsSelection.OrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Purchase orders statement.
//
Procedure ShowMessageAboutPostingToPurchaseOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are receiving more than specified in the purchase order'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	MessagePattern = NStr("en = 'Products: %ProductsCharacteristicsBatch%,
	                      |balance by order %BalanceQuantity% %MeasurementUnit%, 
	                      |exceeds by %Quantity% %MeasurementUnit%
	                      |%PurchaseOrder%'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%BalanceQuantity%", String(RecordsSelection.BalancePurchaseOrders));
		MessageText = StrReplace(MessageText, "%Quantity%", String(-RecordsSelection.QuantityBalancePurchaseOrders));
		MessageText = StrReplace(MessageText, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
		MessageText = StrReplace(MessageText, "%PurchaseOrder%", TrimAll(RecordsSelection.PurchaseOrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Production order.
//
Procedure ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ShowMessageAboutError(DocObject,
		NStr("en = 'Error:
		     |You are producing more than specified in the production order'"),,,,
		Cancel);
		
	MessagePattern = NStr("en = 'Product: %1,
	                      |balance by order %2 %3, 
	                      |exceeded %4 %3
	                      |%5'");
	
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		
		ShowMessageAboutError(DocObject, 
			StringFunctionsClientServer.SubstituteParametersInString(
				MessagePattern, 
				PresentationOfProducts,
				String(RecordsSelection.BalanceProductionOrders),
				TrimAll(RecordsSelection.MeasurementUnitPresentation), 
				String(-RecordsSelection.QuantityBalanceProductionOrders), 
				TrimAll(RecordsSelection.ProductionOrderPresentation)),,,, 
			Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Inventory demand.
//
Procedure ShowMessageAboutPostingToInventoryDemandRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Registered more than the inventory demand'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Products: %ProductsCharacteristicsBatch%,
	                      |demand %BalanceQuantity% %MeasurementUnit%,
	                      |exceeds by %Quantity% %MeasurementUnit%
	                      |%SalesOrder%'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%BalanceQuantity%", String(RecordsSelection.BalanceInventoryDemand));
		MessageText = StrReplace(MessageText, "%Quantity%", String(-RecordsSelection.QuantityBalanceInventoryDemand));
		MessageText = StrReplace(MessageText, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
		MessageText = StrReplace(MessageText, "%SalesOrder%", TrimAll(RecordsSelection.SalesOrderPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Orders placement.
//
Procedure ShowMessageAboutPostingToBackordersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Registered more than the inventory allocated in the orders'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	MessagePattern = NStr("en = 'Product: %ProductsCharacteristicsBatch%,
	                      |allocated %BalanceQuantity% %MeasurementUnit%
	                      |in %SupplySource%,
	                      |exceeds %Quantity% %MeasurementUnit%
	                      |by %SalesOrder%'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", PresentationOfProducts);
		
		MessageText = StrReplace(MessageText, "%BalanceQuantity%", String(RecordsSelection.BalanceBackorders));
		MessageText = StrReplace(MessageText, "%Quantity%", String(-RecordsSelection.QuantityBalanceBackorders));
		MessageText = StrReplace(MessageText, "%MeasurementUnit%", TrimAll(RecordsSelection.MeasurementUnitPresentation));
		MessageText = StrReplace(MessageText, "%SalesOrder%", TrimAll(RecordsSelection.SalesOrderPresentation));
		MessageText = StrReplace(MessageText, "%ProcurementSource%", TrimAll(RecordsSelection.SupplySourcePresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Cash assets.
//
Procedure ShowMessageAboutPostingToCashAssetsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient funds'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = '%PettyCashAccount%: %PettyCashAccountPresentation%,
	                      |balance %AmountBalance% %Currency%,
	                      |not enough %Amount% %Currency%'");
		
	While RecordsSelection.Next() Do
		
		PettyCashAccountPresentation = CashBankAccountPresentation(RecordsSelection.BankAccountCashPresentation);
		MessageText = StrReplace(MessagePattern, "%PettyCashAccountPresentation%", PettyCashAccountPresentation);
		
		If RecordsSelection.CashAssetsType = Enums.CashAssetTypes.Noncash Then
			
			MessageText = StrReplace(MessageText, "%PettyCashAccount%", "Account");
			
		Else
			
			MessageText = StrReplace(MessageText, "%PettyCashAccount%", "PettyCash");
			
		EndIf;
		
		MessageText = StrReplace(MessageText, "%AmountBalance%", String(RecordsSelection.BalanceCashAssets));
		MessageText = StrReplace(MessageText, "%Amount%", String(-RecordsSelection.AmountCurBalance));
		MessageText = StrReplace(MessageText, "%Currency%", TrimAll(RecordsSelection.CurrencyPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Cash in cash registers.
//
Procedure ErrorMessageOfPostingOnRegisterOfCashAtCashRegisters(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'Insufficient funds in the cash register'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Cash register: %1,
		|balance %2 %3,
		|not enough %4 %3'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						MessagePattern,
						CashBankAccountPresentation(RecordsSelection.CashCRDescription),
						String(RecordsSelection.BalanceCashAssets),
						TrimAll(RecordsSelection.CurrencyPresentation),
						String(-RecordsSelection.AmountCurBalance));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Advance holder payments.
//
Procedure ShowMessageAboutPostingToAdvanceHoldersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The transaction causes a negative balance of the advance holder debt.'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = '%AdvanceHolderPresentation%,
	                      |Accountable funds balance: %AdvanceHolderBalance% %CurrencyPresentation%'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfAccountablePerson = PresentationOfAccountablePerson(RecordsSelection.EmployeePresentation, RecordsSelection.CurrencyPresentation, RecordsSelection.DocumentPresentation);
		MessageText = StrReplace(MessagePattern, "%AdvanceHolderPresentation%", PresentationOfAccountablePerson);
		
		MessageText = StrReplace(MessageText, "%AdvanceHolderBalance%", String(RecordsSelection.AccountablePersonBalance));
		MessageText = StrReplace(MessageText, "%CurrencyPresentation%", TrimAll(RecordsSelection.CurrencyPresentation));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Accounts payable.
//
Procedure ShowMessageAboutPostingToAccountsPayableRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	While RecordsSelection.Next() Do
		
		CounterpartyPresentation = CounterpartyPresentation(RecordsSelection.CounterpartyPresentation, 
															RecordsSelection.ContractPresentation,
															RecordsSelection.DocumentPresentation,
															RecordsSelection.OrderPresentation,
															RecordsSelection.CalculationsTypesPresentation);
		CurrencyPresentation = TrimAll(RecordsSelection.CurrencyPresentation);

		
		If RecordsSelection.RegisterRecordsOfCashDocuments Then
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Invoice payable amount is less than entered. Details: %1.
					     |Entered: %3 %2
					     |Invoice payable:%4 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.SumCurOnWrite),
					String(RecordsSelection.DebtBalanceAmount));
			EndIf;
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				If RecordsSelection.AmountOfOutstandingAdvances = 0 Then
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The advance payment has been cleared in full by invoices. Details: %1.'"),
						CounterpartyPresentation);
				Else
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'The advance payment has been cleared in part by invoices. Details: %1.
						     |Advance balance: %3 %2'"),
						CounterpartyPresentation,
						CurrencyPresentation,
						String(RecordsSelection.AmountOfOutstandingAdvances));
				EndIf;
			EndIf;
			
		Else
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				If RecordsSelection.AmountOfOutstandingDebt = 0 Then
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The invoice has been paid in full. Details: %1.'"),
					CounterpartyPresentation);
				Else
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The invoice has been paid in part. Details: %1.
					     |Unpaid: %3 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.AmountOfOutstandingDebt));
				EndIf;
			EndIf;
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'You cannot clear a larger amount than the advance payment is. Details: %1.
				     |Entered amount:%3 %2
				     |Advance balance: %4 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.SumCurOnWrite),
					String(RecordsSelection.AdvanceAmountsPaid));
			EndIf;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Accounts receivable.
//
Procedure ShowMessageAboutPostingToAccountsReceivableRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
		
	While RecordsSelection.Next() Do
		
		CounterpartyPresentation = CounterpartyPresentation(RecordsSelection.CounterpartyPresentation, 
															RecordsSelection.ContractPresentation,
															RecordsSelection.DocumentPresentation,
															RecordsSelection.OrderPresentation,
															RecordsSelection.CalculationsTypesPresentation);
		CurrencyPresentation = TrimAll(RecordsSelection.CurrencyPresentation);
		
		If RecordsSelection.RegisterRecordsOfCashDocuments Then
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Invoice receivable amount is less than entered. Details: %1.
				     |Entered amount: %3 %2
				     |Invoice receivable amount: %4 %2'"),
				CounterpartyPresentation,
				CurrencyPresentation,
				String(RecordsSelection.SumCurOnWrite),
				String(RecordsSelection.DebtBalanceAmount));
			EndIf;
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				If RecordsSelection.AmountOfOutstandingAdvances = 0 Then
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The advance payment has been cleared by invoices. Details: %1.'"),
					CounterpartyPresentation);
				Else
					MessageText = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The invoice has been paid in part. Details: %1.
					     |Advance balance: %3 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.AmountOfOutstandingAdvances));
				EndIf;
			EndIf;
			
		Else
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Debt Then
				If RecordsSelection.AmountOfOutstandingDebt = 0 Then
					MessageText =StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The invoice has been paid in full. Details: %1.'"),
					CounterpartyPresentation);
				Else
					MessageText =StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The invoice has been paid in part. Details: %1.
					     |Unpaid: %3 %2'"),
					CounterpartyPresentation,
					CurrencyPresentation,
					String(RecordsSelection.AmountOfOutstandingDebt));
				EndIf;
			EndIf;
			
			If RecordsSelection.SettlementsType = Enums.SettlementsTypes.Advance Then
				MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'You cannot clear a larger amount than the advance payment is. Details: %1.
				     |Entered amount: %3 %2 
				     |Advance balance: %4 %2'"),
				CounterpartyPresentation,
				CurrencyPresentation,
				String(RecordsSelection.SumCurOnWrite),
				String(RecordsSelection.AdvanceAmountsReceived));
			EndIf;
			
		EndIf;
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Fixed assets.
//
Procedure ShowMessageAboutPostingToFixedAssetsRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The fixed asset might has been written off or transferred'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
		
	MessagePattern = NStr("en = 'Fixed asset: %ProductsCharacteristicsBatch%,
	                      |depreciated cost: %Cost%'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicsBatch%", TrimAll(RecordsSelection.FixedAssetPresentation));
		
		MessageText = StrReplace(MessageText, "%Cost%", String(RecordsSelection.DepreciatedCost));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// The procedure informs of errors that occurred when posting by register Retail amount accounting.
//
Procedure ShowMessageAboutPostingToPOSSummaryRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'The debt of the POS %StructuralUnitPresentation% has been paid in full'");
	
	MessagePattern = NStr("en = 'Debt balance: %BalanceInRetail% %CurrencyPresentation%'");
	
	TitleInDetailsShow = True;
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			MessageTitleText = StrReplace(MessageTitleTemplate, "%StructuralUnitPresentation%", TrimAll(RecordsSelection.StructuralUnitPresentation));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		MessageText = StrReplace(MessagePattern, "%BalanceInRetail%", String(RecordsSelection.BalanceInRetail)); 
		MessageText = StrReplace(MessageText, "%CurrencyPresentation%", TrimAll(RecordsSelection.CurrencyPresentation)); 
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

// Procedure reports errors by the register Serial numbers.
//
Procedure ShowMessageAboutPostingSerialNumbersRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleTemplate = ErrorTitle + Chars.LF + NStr("en = 'Not enough serial numbers %StructuralUnitType% %StructuralUnitPresentation%'");
	
	MessagePattern = NStr("en = 'Product:
	                      |%ProductsCharacteristicBatch%, serial number %SerialNumber%'");
		
	TitleInDetailsShow = True;
	UseSeveralWarehouses = Constants.UseSeveralWarehouses.Get();
	AccountingBySeveralDivisions = Constants.UseSeveralDepartments.Get();
	While RecordsSelection.Next() Do
		
		If TitleInDetailsShow Then
			If (NOT UseSeveralWarehouses AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse)
				OR (NOT AccountingBySeveralDivisions AND RecordsSelection.StructuralUnitType = Enums.BusinessUnitsTypes.Department)Then
				PresentationOfStructuralUnit = "";
			Else
				If WorkWithProductsClientServer.IsObjectAttribute("PresentationCell" , RecordsSelection) Then
					PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation, RecordsSelection.PresentationCell);
				Else
					PresentationOfStructuralUnit = PresentationOfStructuralUnit(RecordsSelection.StructuralUnitPresentation);
				EndIf; 
				
			EndIf;
			MessageTitleText = StrReplace(MessageTitleTemplate, "%StructuralUnitPresentation%", PresentationOfStructuralUnit);
			MessageTitleText = StrReplace(MessageTitleText, "%StructuralUnitType%", GetStructuralUnitTypePresentation(RecordsSelection.StructuralUnitType));
			ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
			TitleInDetailsShow = False;
		EndIf;
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation, RecordsSelection.BatchPresentation);
		MessageText = StrReplace(MessagePattern, "%ProductsCharacteristicBatch%", PresentationOfProducts);
		MessageText = StrReplace(MessageText, "%SerialNumber%", String(RecordsSelection.SerialNumberPresentation));
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsShippedNotInvoicedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are invoicing more than specified in the goods issue'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance in goods issue %2 %3, exceeds %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						MessagePattern,
						PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation),
						RecordsSelection.BalanceGoodsShippedNotInvoiced,
						TrimAll(RecordsSelection.MeasurementUnitPresentation),
						-RecordsSelection.QuantityBalanceGoodsShippedNotInvoiced,
						TrimAll(RecordsSelection.GoodsIssuePresentation));
						
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsReceivedNotInvoicedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are invoicing more than specified in the goods receipt'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance in goods receipt %2 %3, exceeds by %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						MessagePattern,
						PresentationOfProducts(RecordsSelection.ProductsPresentation, RecordsSelection.CharacteristicPresentation),
						RecordsSelection.BalanceGoodsReceivedNotInvoiced,
						TrimAll(RecordsSelection.MeasurementUnitPresentation),
						-RecordsSelection.QuantityBalanceGoodsReceivedNotInvoiced,
						TrimAll(RecordsSelection.GoodsReceiptPresentation));
						
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToGoodsInvoicedNotShippedRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'You are shipping more than specified in the sales invoice'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr("en = 'Product: %1, balance %2 %3, not enough %4 %3. %5'");
		
	While RecordsSelection.Next() Do
		
		PresentationOfProducts = PresentationOfProducts(RecordsSelection.Products, RecordsSelection.Characteristic, RecordsSelection.Batch);
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			MessagePattern,
			PresentationOfProducts,
			String(RecordsSelection.QuantityBalanceBeforeChange),
			TrimAll(RecordsSelection.MeasurementUnit),
			String(-RecordsSelection.QuantityBalance),
			TrimAll(RecordsSelection.SalesInvoice));
		
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

Procedure ShowMessageAboutPostingToVATIncurredRegisterErrors(DocObject, RecordsSelection, Cancel) Export
	
	ErrorTitle = NStr("en = 'Error:'");
	MessageTitleText = ErrorTitle + Chars.LF + NStr("en = 'The entry results in negative inventory in the ""VAT incurred"" register'");
	ShowMessageAboutError(DocObject, MessageTitleText, , , , Cancel);
	
	MessagePattern = NStr(
		"en = 'Shipping document: %1, VAT rate: %2
	                        		|	Amount:	%3; exceeds: %4
	                        		|	VAT amount:			%5; exceeds: %6'");
		
	While RecordsSelection.Next() Do
		
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
						MessagePattern,
						TrimAll(RecordsSelection.ShipmentDocument),
						TrimAll(RecordsSelection.VATRate),
						RecordsSelection.AmountExcludesVAT,
						-RecordsSelection.AmountExcludesVATBalance,
						RecordsSelection.VATAmount,
						-RecordsSelection.VATAmountBalance);
						
		ShowMessageAboutError(DocObject, MessageText, , , , Cancel);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region SsmSubsystemsProceduresAndFunctions

// Procedure adds formula parameters to the structure.
//
Procedure AddParametersToStructure(FormulaString, ParametersStructure, Cancel = False) Export

	Formula = FormulaString;
	
	OperandStart = Find(Formula, "[");
	OperandEnd = Find(Formula, "]");
     
	IsOperand = True;
	While IsOperand Do
     
		If OperandStart <> 0 AND OperandEnd <> 0 Then
			
            ID = TrimAll(Mid(Formula, OperandStart+1, OperandEnd - OperandStart - 1));
            Formula = Right(Formula, StrLen(Formula) - OperandEnd);   
			
			Try
				If Not ParametersStructure.Property(ID) Then
					ParametersStructure.Insert(ID);
				EndIf;
			Except
			    Break;
				Cancel = True;
			EndTry 
			 
		EndIf;     
          
		OperandStart = Find(Formula, "[");
		OperandEnd = Find(Formula, "]");
          
		If Not (OperandStart <> 0 AND OperandEnd <> 0) Then
			IsOperand = False;
        EndIf;     
               
	EndDo;	

EndProcedure

// Function returns parameter value
//
Function CalculateParameterValue(ParametersStructure, CalculationParameter, ErrorText = "") Export
	
	// 1. Create query
	Query = New Query;
	Query.Text = CalculationParameter.Query;
	
	// 2. Control of all query parameters filling
	For Each QueryParameter In CalculationParameter.QueryParameters Do
		
		If ValueIsFilled(QueryParameter.Value) Then
			
			Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), QueryParameter.Value);
			
		Else
			
			If ParametersStructure.Property(StrReplace(QueryParameter.Name, ".", "")) Then
				
				PeriodString = CalculationParameter.DataFilterPeriods.Find(StrReplace(QueryParameter.Name, ".", ""), "BoundaryDateName");
				If PeriodString <> Undefined  Then
					
					If PeriodString.PeriodShift <> 0 Then
						NewPeriod = AddInterval(ParametersStructure[StrReplace(QueryParameter.Name, ".", "")], PeriodString.ShiftPeriod, PeriodString.PeriodShift);
						Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), NewPeriod);
					Else
						Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), ParametersStructure[StrReplace(QueryParameter.Name, ".", "")]);
					EndIf;
					
				Else
					
					Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), ParametersStructure[StrReplace(QueryParameter.Name, ".", "")]);
					
				EndIf; 
				
			ElsIf ValueIsFilled(TypeOf(QueryParameter.Value)) Then
				
				Query.SetParameter(StrReplace(QueryParameter.Name, ".", ""), QueryParameter.Value);
				
			Else
				
				Message = New UserMessage();
				Message.Text = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Value for parameter %1 is not specified.'"),
					QueryParameter.Name) 
					+ ErrorText;
				Message.Message();
				
				Return 0;
			EndIf;
			
		EndIf; 
		
	EndDo; 
	
	// 4. Query execution
	QueryResult = Query.Execute().Unload();
	If QueryResult.Count() = 0 Then
		
		Return 0;
		
	Else
		
		Return QueryResult[0][0];
		
	EndIf;
	
EndFunction

// Function adds interval to date
//
// Parameters:
//     Periodicity (Enum.Periodicity)     - planning periodicity by script.
//     DateInPeriod (Date)                                   - custom
//     date Shift (number)                                   - defines the direction and quantity of periods where date
//     is moved
//
// Returns:
//     Date remote from the original by the specified periods quantity 
//
Function AddInterval(PeriodDate, Periodicity, Shift) Export

     If Shift = 0 Then
          NewPeriodData = PeriodDate;
          
     ElsIf Periodicity = Enums.Periodicity.Day Then
          NewPeriodData = BegOfDay(PeriodDate + Shift * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicity.Week Then
          NewPeriodData = BegOfWeek(PeriodDate + Shift * 7 * 24 * 3600);
          
     ElsIf Periodicity = Enums.Periodicity.Month Then
          NewPeriodData = AddMonth(PeriodDate, Shift);
          
     ElsIf Periodicity = Enums.Periodicity.Quarter Then
          NewPeriodData = AddMonth(PeriodDate, Shift * 3);
          
     ElsIf Periodicity = Enums.Periodicity.Year Then
          NewPeriodData = AddMonth(PeriodDate, Shift * 12);
          
     Else
          NewPeriodData=BegOfDay(PeriodDate) + Shift * 24 * 3600;
          
     EndIf;

     Return NewPeriodData;

EndFunction

// Receives default expenses invoice of Earning type.
//
// Parameters:
//  DataStructure - Structure containing object attributes
//                 that should be received and filled in
//                 with attributes that are required for receipt.
//
Procedure GetEarningKindGLExpenseAccount(DataStructure) Export
	
	EarningAndDeductionType = DataStructure.EarningAndDeductionType;
	GLExpenseAccount = EarningAndDeductionType.GLExpenseAccount;
	
	If EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Tax Then
		
		GLExpenseAccount = EarningAndDeductionType.TaxKind.GLAccount;
		
		If GLExpenseAccount.TypeOfAccount <> Enums.GLAccountsTypes.AccountsPayable Then			
			GLExpenseAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();			
		EndIf;
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Earning Then
		
		If ValueIsFilled(DataStructure.StructuralUnit) Then
			
			TypeOfAccount = GLExpenseAccount.TypeOfAccount;
			If DataStructure.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Department
				AND Not (TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
					OR TypeOfAccount = Enums.GLAccountsTypes.Expenses
					OR TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets
					OR TypeOfAccount = Enums.GLAccountsTypes.IndirectExpenses
					OR TypeOfAccount = Enums.GLAccountsTypes.WorkInProcess
					OR TypeOfAccount = Enums.GLAccountsTypes.OtherCurrentAssets) Then
				
				GLExpenseAccount = ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
				
			EndIf;
			
		EndIf;
		
	ElsIf EarningAndDeductionType.Type = Enums.EarningAndDeductionTypes.Deduction Then		
		GLExpenseAccount = Catalogs.DefaultGLAccounts.GetDefaultGLAccount("OtherIncome");	
	EndIf;
	
	DataStructure.GLExpenseAccount	= GLExpenseAccount;
	DataStructure.TypeOfAccount		= GLExpenseAccount.TypeOfAccount;
	
EndProcedure

// Function generates a last name, name and patronymic as a string.
//
// Parameters
//  Surname      - last name of ind. bodies
//  Name          - name ind. bodies
//  Patronymic     - patronymic ind. bodies
//  DescriptionFullShort    - Boolean - If True (by default), then
//                 the individual presentation includes a last name and initials if False - surname
//                 or name and patronymic.
//
// Return value
// Surname, name, patronymic as one string.
//
Function GetSurnameNamePatronymic(Surname = " ", Name = " ", Patronymic = " ", NameAndSurnameShort = True) Export
	
	If NameAndSurnameShort Then
		Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name)," " + Left(Name,1) + "." + 
				?(NOT IsBlankString(Patronymic) , 
				Left(Patronymic,1)+".", ""), ""), "");
	Else
		Return ?(NOT IsBlankString(Surname), Surname + ?(NOT IsBlankString(Name)," " + Name + 
				?(NOT IsBlankString(Patronymic) , " " + Patronymic, ""), ""), "");
	EndIf;

EndFunction

// Function defines whether calculation method or Earning kind was input earlier
//
// IdentifierValue (Row) - Identifier attribute value of the CalculationParameters catalog item
//
Function SettlementsParameterExist(IdentifierValue) Export
	
	If IsBlankString(IdentifierValue)Then
		
		Return False;
		
	EndIf;
	
	Return Not Catalogs.EarningsCalculationParameters.FindByAttribute("ID", IdentifierValue) = Catalogs.EarningsCalculationParameters.EmptyRef();
	
EndFunction

// Function determines whether the initial filling of the EarningAndDeductionTypes catalog is executed
//
//
Function EarningAndDeductionTypesInitialFillingPerformed() Export
	
	Query = New Query("SELECT * FROM Catalog.EarningAndDeductionTypes AS AAndDKinds WHERE NOT AAndDKinds.Predefined");
	
	QueryResult = Query.Execute();
	Return Not QueryResult.IsEmpty();
	
EndFunction

#EndRegion

#Region TransactionsMirrorProceduresAndFunctions

// Generates transactions table structure.
//
Procedure GenerateTransactionsTable(DocumentRef, StructureAdditionalProperties) Export
	
	TableAccountingJournalEntries = New ValueTable;
	
	TableAccountingJournalEntries.Columns.Add("LineNumber");
	TableAccountingJournalEntries.Columns.Add("Period");
	TableAccountingJournalEntries.Columns.Add("Company");
	TableAccountingJournalEntries.Columns.Add("PlanningPeriod");
	TableAccountingJournalEntries.Columns.Add("AccountDr");
	TableAccountingJournalEntries.Columns.Add("CurrencyDr");
	TableAccountingJournalEntries.Columns.Add("AmountCurDr");
	TableAccountingJournalEntries.Columns.Add("AccountCr");
	TableAccountingJournalEntries.Columns.Add("CurrencyCr");
	TableAccountingJournalEntries.Columns.Add("AmountCurCr");
	TableAccountingJournalEntries.Columns.Add("Amount");
	TableAccountingJournalEntries.Columns.Add("Content");
	TableAccountingJournalEntries.Columns.Add("OfflineRecord");
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", TableAccountingJournalEntries);
	
EndProcedure

#EndRegion

#Region ExplosionProceduresAndFunctions

// Generate structure with definite fields content for explosion.
//
// Parameters:
//  No.
//
// Returns:
//  Structure - structure with defined fields content
// for explosion.
//
Function GenerateContentStructure() Export
	
	Structure = New Structure();
	
	// Current node description fields.
	Structure.Insert("Products");
	Structure.Insert("Characteristic");
	Structure.Insert("MeasurementUnit");
	Structure.Insert("Quantity");
	Structure.Insert("AccountingPrice");
	Structure.Insert("Cost");
	Structure.Insert("ProductsQuantity");
	Structure.Insert("Specification");
	
	Structure.Insert("ContentRowType");
	Structure.Insert("TableOperations");
	
	// Auxiliary data.
	Structure.Insert("Object");
	Structure.Insert("ProcessingDate", '00010101');
	Structure.Insert("Level");
	Structure.Insert("PriceKind");
	
	Return Structure;
	
EndFunction

// Function returns operations table.
//
// Parameters:
//  ContentStructure - Content structure
//
// Returns:
//  Values table with operations.
//
Function GetSpecificationOperations(ContentStructure)
	
	Query = New Query; 
	Query.Text =
	"SELECT
	|	OperationSpecification.Operation AS Operation,
	|	OperationSpecification.TimeNorm / OperationSpecification.ProductsQuantity AS TimeNorm,
	|	OperationSpecification.TimeNorm / OperationSpecification.ProductsQuantity * &Quantity AS Duration,
	|	ISNULL(PricesSliceLast.Price, 0) AS AccountingPrice,
	|	ISNULL(PricesSliceLast.Price, 0) * (1 / OperationSpecification.ProductsQuantity) * &Quantity AS Cost
	|FROM
	|	Catalog.BillsOfMaterials.Operations AS OperationSpecification
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON OperationSpecification.Operation = PricesSliceLast.Products
	|WHERE
	|	OperationSpecification.Ref = &Specification
	|	AND Not OperationSpecification.Ref.DeletionMark";
		
	Query.SetParameter("Specification",  ContentStructure.Specification);
	Query.SetParameter("Quantity",	   ContentStructure.Quantity);
	Query.SetParameter("ProcessingDate", ContentStructure.ProcessingDate);
	Query.SetParameter("PriceKind",        ContentStructure.PriceKind);
	
	Return Query.Execute().Unload();
	
EndFunction

// Function returns operations table with norms.
//
// Parameters:
//  ContentStructure - TTManager
//  content structure - TempTablesManager - temporary
// 			   tables by the document
//
// Returns:
//  QueryResultSelection.
//
Function GetSpecificationContent(ContentStructure)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	BillsOfMaterialsContent.ContentRowType AS ContentRowType,
	|	BillsOfMaterialsContent.Products AS Products,
	|	BillsOfMaterialsContent.Characteristic AS Characteristic,
	|	BillsOfMaterialsContent.MeasurementUnit AS MeasurementUnit,
	|	BillsOfMaterialsContent.Specification AS Specification,
	|	ISNULL(BillsOfMaterialsContent.Quantity, 0) * &Quantity AS Quantity,
	|	ISNULL(BillsOfMaterialsContent.ProductsQuantity, 0) AS ProductsQuantity,
	|	ISNULL(PricesSliceLast.Price, 0) AS AccountingPrice,
	|	0 AS Cost
	|FROM
	|	Catalog.BillsOfMaterials.Content AS BillsOfMaterialsContent
	|		LEFT JOIN InformationRegister.Prices.SliceLast(&ProcessingDate, PriceKind = &PriceKind) AS PricesSliceLast
	|		ON BillsOfMaterialsContent.Products = PricesSliceLast.Products
	|			AND BillsOfMaterialsContent.Characteristic = PricesSliceLast.Characteristic
	|WHERE
	|	BillsOfMaterialsContent.Ref = &Specification
	|	AND (NOT BillsOfMaterialsContent.Ref.DeletionMark)";
	
	Query.SetParameter("Specification",  ContentStructure.Specification);
	Query.SetParameter("Quantity",	   ContentStructure.Quantity);
	Query.SetParameter("ProcessingDate", ContentStructure.ProcessingDate);
	Query.SetParameter("PriceKind",        ContentStructure.PriceKind);
		
	Return Query.Execute().Select();
	
EndFunction

// Procedure adds new node to products stack for explosion.
//
// Parameters:
//  ContentStructure - Structure
// of the Products content - ValuesTable
// products stack StackProductsStackLogins - ValuesTable NewRowStack
// products logons stack - ValueTableRow - String
// stack CurRow     - ValueTableRow - current row.
//
Procedure AddNode(ContentStructure, StackProducts, StackProductsStackEntries, NewRowStack, CurRow)
	
	NewRowStack = StackProducts.Add();
	NewRowStack.Products	= CurRow.Products;
	NewRowStack.Characteristic = CurRow.Characteristic;
	NewRowStack.Specification	= CurRow.Specification;
	NewRowStack.Level		= CurRow.Level;
	
	// Inserted stack initialization.
	StackProductsStackEntries = StackProductsStackEntries.CopyColumns();
	NewRowStack.StackEntries = StackProductsStackEntries;
	
	// Fill out the content structure.
	ContentStructure.ContentRowType		= CurRow.ContentRowType;
	ContentStructure.Products			= CurRow.Products;
	ContentStructure.Characteristic			= CurRow.Characteristic;
	ContentStructure.MeasurementUnit		= CurRow.MeasurementUnit;
	ContentStructure.Quantity				= CurRow.Quantity / ?(CurRow.ProductsQuantity <> 0, CurRow.ProductsQuantity, 1);
	ContentStructure.ProductsQuantity	= CurRow.ProductsQuantity;
	ContentStructure.Level				= NewRowStack.Level;
	ContentStructure.AccountingPrice			= CurRow.AccountingPrice;
	ContentStructure.Cost				= ContentStructure.Quantity * CurRow.AccountingPrice;
		
	If CurRow.Specification.DeletionMark Then
		ContentStructure.Specification = Catalogs.BillsOfMaterials.EmptyRef();
	Else
		ContentStructure.Specification = CurRow.Specification;
	EndIf;
		
	ContentStructure.TableOperations = GetSpecificationOperations(ContentStructure);
	
EndProcedure

// Explodes the node.
//
// Parameters:
//  ContentStructure - Structure that describes
// processed node ContentTable - ValuesList
// of the OpertionsTable content - ValueTable of operations.
//  
Procedure RunDenoding(ContentStructure, ContentTable, TableOfOperations) Export
	
	CompositionNewString = ContentTable.Add();
	CompositionNewString.Products		= ContentStructure.Products;
	CompositionNewString.Characteristic	= ContentStructure.Characteristic;
	CompositionNewString.MeasurementUnit	= ContentStructure.MeasurementUnit;
	CompositionNewString.Quantity		= ContentStructure.Quantity;
	CompositionNewString.Level			= ContentStructure.Level;
	CompositionNewString.Node				= False;
	CompositionNewString.AccountingPrice		= ContentStructure.AccountingPrice;
	CompositionNewString.Cost		= ContentStructure.Cost;
	
	If ContentStructure.ContentRowType = Enums.BOMLineType.Node
	 OR ContentStructure.ContentRowType = Enums.BOMLineType.Assembly
	 OR ContentStructure.Level = 0 Then
			
		CompositionNewString.Node			= True;
	 
	 	OperationsString = TableOfOperations.Add();
		OperationsString.Products		= ContentStructure.Products;
		OperationsString.Characteristic	= ContentStructure.Characteristic;
		OperationsString.TimeNorm		= ContentStructure.Quantity;
		OperationsString.Level			= ContentStructure.Level;
		OperationsString.Node				= True;
		
	EndIf;
		
	For Each TSRow In ContentStructure.TableOperations Do
			
		OperationsString = TableOfOperations.Add();
		OperationsString.Products	= TSRow.Operation;
		OperationsString.TimeNorm = TSRow.TimeNorm;
		OperationsString.Level		= ContentStructure.Level + 1;
		OperationsString.Duration = TSRow.Duration;
		OperationsString.AccountingPrice	= TSRow.AccountingPrice;
		OperationsString.Cost	= TSRow.Cost;
		OperationsString.Node			= False;
	
	EndDo;
		
EndProcedure

// Explosion procedure.
//
// Parameters:
//  ContentStructure - Structure that describes
// processed
// node Object ContentTable - ValuesList
// of the OpertionsTable content - ValueTable of operations.
//  
Procedure Denoding(ContentStructure, ContentTable, TableOfOperations) Export
	
	// Initialization of products stack.
	StackProducts = New ValueTable();
	StackProducts.Columns.Add("Products");
	StackProducts.Columns.Add("Characteristic");
	StackProducts.Columns.Add("Specification");
	StackProducts.Columns.Add("Level");
	
	StackProducts.Columns.Add("StackEntries");
	
	StackProducts.Indexes.Add("Products, Characteristic, Specification");
	
	// Entries table initialization.
	StackProductsStackEntries = New ValueTable();
	StackProductsStackEntries.Columns.Add("ContentRowType");
	StackProductsStackEntries.Columns.Add("Products");
	StackProductsStackEntries.Columns.Add("Characteristic");
	StackProductsStackEntries.Columns.Add("MeasurementUnit");
	StackProductsStackEntries.Columns.Add("Quantity");
	StackProductsStackEntries.Columns.Add("ProductsQuantity");
	StackProductsStackEntries.Columns.Add("Specification");
	StackProductsStackEntries.Columns.Add("Level");
	StackProductsStackEntries.Columns.Add("AccountingPrice");
	StackProductsStackEntries.Columns.Add("Cost");
	
	ContentStructure.TableOperations = GetSpecificationOperations(ContentStructure);
	
	ContentStructure.Level = 0;
	
	// Initial filling of the stack.
	NewRowStack = StackProducts.Add();
	NewRowStack.Products	= ContentStructure.Products;
	NewRowStack.Characteristic	= ContentStructure.Characteristic;
	NewRowStack.Specification	= ContentStructure.Specification;
	NewRowStack.Level		= ContentStructure.Level;
	
	NewRowStack.StackEntries		= StackProductsStackEntries;
	
	RunDenoding(ContentStructure, ContentTable, TableOfOperations);
	
	// Until we have what to explode.
	While StackProducts.Count() <> 0 Do
		
		ProductsSelection = GetSpecificationContent(ContentStructure);
		
		While ProductsSelection.Next() Do
			
			If Not ValueIsFilled(ProductsSelection.Products) Then
				Continue;
			EndIf;
			
			// Check the recursive input.
			SearchStructure = New Structure;
			SearchStructure.Insert("Products",	ProductsSelection.Products);
			SearchStructure.Insert("Characteristic",	ProductsSelection.Characteristic);
			SearchStructure.Insert("Specification",	ProductsSelection.Specification);
			
			RecursiveEntryStrings = StackProducts.FindRows(SearchStructure);
			
			If RecursiveEntryStrings.Count() <> 0 Then
				
				For Each EntAttributeString In RecursiveEntryStrings Do
					
					MessageText = NStr("en = 'BOM is recursive.'")+" "+ProductsSelection.Products+" "+NStr("en = 'to item'")+" "+ContentStructure.Products+".";
					ShowMessageAboutError(ContentStructure.Object, MessageText);
					
				EndDo;
				
				Continue;
				
			EndIf;
			
			// Adding new nodes.
			NewStringEnter = StackProductsStackEntries.Add();
			NewStringEnter.ContentRowType	= ProductsSelection.ContentRowType;
			NewStringEnter.Products		= ProductsSelection.Products;
			NewStringEnter.Characteristic		= ProductsSelection.Characteristic;
			NewStringEnter.MeasurementUnit	= ProductsSelection.MeasurementUnit;
			
			RateUnitDimensions			= ?(TypeOf(ContentStructure.MeasurementUnit) = Type("CatalogRef.UOM"),
														ContentStructure.MeasurementUnit.Factor,
														1);
														
			NewStringEnter.Quantity			= ProductsSelection.Quantity * RateUnitDimensions;
			NewStringEnter.ProductsQuantity = ProductsSelection.ProductsQuantity;
			NewStringEnter.Specification		= ProductsSelection.Specification;
			NewStringEnter.Level				= NewRowStack.Level + 1;
			NewStringEnter.AccountingPrice			= Number(ProductsSelection.AccountingPrice);
			NewStringEnter.Cost			= Number(ProductsSelection.Cost) * RateUnitDimensions;
			
		EndDo; // ProductsSelection
		
		// Branch end or not?
		If StackProductsStackEntries.Count() = 0 Then
			
			// Delete products that do not contain continuation from stack.
			StackProducts.Delete(NewRowStack);
			
			ReadinessFlag = True;
			While StackProducts.Count() <> 0 AND ReadinessFlag Do
				
				// Receive the previous products stack row.
				PreStringProductsStack = StackProducts.Get(StackProducts.Count() - 1);
				
				// Delete entries from the stack.
				PreStringProductsStack.StackEntries.Delete(0);
					
				If PreStringProductsStack.StackEntries.Count() = 0 Then
					
					// If login stack is empty, delete row from products stack.
					StackProducts.Delete(PreStringProductsStack);
					
				Else // explode the following products from the logins stack.
					
					ReadinessFlag = False;
					
					CurRow = PreStringProductsStack.StackEntries.Get(0);
					
					AddNode(ContentStructure, StackProducts, StackProductsStackEntries, NewRowStack, CurRow);
					RunDenoding(ContentStructure, ContentTable, TableOfOperations);
					
				EndIf;
				
			EndDo;
			
		Else // add nodes
			
			CurRow = StackProductsStackEntries.Get(0);
			
			AddNode(ContentStructure, StackProducts, StackProductsStackEntries, NewRowStack, CurRow);
			RunDenoding(ContentStructure, ContentTable, TableOfOperations);
			
		EndIf;
		
	EndDo; // StackProducts
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsOfPrintingFormsGenerating

// Procedure fills in full name by the employee name.
//
Procedure SurnameInitialsByName(Initials, Description) Export
	
	If IsBlankString(Description) Then
		
		Return;
		
	EndIf;
	
	SubstringArray = StringFunctionsClientServer.DecomposeStringIntoSubstringsArray(Description, " ");
	Surname		= SubstringArray[0];
	Name 		= ?(SubstringArray.Count() > 1, SubstringArray[1], "");
	Patronymic	= ?(SubstringArray.Count() > 2, SubstringArray[2], "");
	
	Initials = GetSurnameNamePatronymic(Surname, Name, Patronymic, True);
	
EndProcedure

// Function returns products presentation for printing.
//
Function GetProductsPresentationForPrinting(Products, Characteristic = Undefined, SKU = "", SerialNumbers = "")  Export

	AddCharacteristics = "";
	If Constants.UseCharacteristics.Get() AND ValueIsFilled(Characteristic) Then
		AddCharacteristics = AddCharacteristics + " (" + TrimAll(Characteristic) + ")";
	EndIf;
	
	AddItemNumberToProductDescriptionOnPrinting = Constants.AddItemNumberToProductDescriptionOnPrinting.Get();
	If AddItemNumberToProductDescriptionOnPrinting Then
		
		StringSKU = TrimAll(SKU);
		If ValueIsFilled(StringSKU) Then
			
			StringSKU = ", " + StringSKU;
			
		EndIf;
		
	Else
		
		StringSKU = "";
		
	EndIf;
	
	TextInBrackets = "";
	If AddCharacteristics <> "" AND SerialNumbers <> "" Then
		TextInBrackets =  " (" + AddCharacteristics + " " + SerialNumbers + ")";
	ElsIf AddCharacteristics <> "" Then
		TextInBrackets =  " (" + AddCharacteristics + ")";
	ElsIf SerialNumbers <> "" Then
		TextInBrackets = " (" + SerialNumbers + ")";
	EndIf;
	
	If TextInBrackets <> "" OR ValueIsFilled(StringSKU) Then
		Return TrimAll(Products) + TextInBrackets + StringSKU;
	Else
		Return TrimAll(Products);
	EndIf;

EndFunction

// The function returns a set of data about an individual as a structure, The set of data includes full name, position
// in the organization, passport data etc..
//
// Parameters:
//  Company  - CatalogRef.Companies - company
//                 by which a position and
//  department of the employee is determined Individual      - CatalogRef.Individuals - individual
//                 on which CutoffDate data set
//  is returned    - Date - date on which
//  the DescriptionFullNameShort data is read    - Boolean - If True (by default), then
//                 the individual presentation includes a last name and initials if False - surname
//                 or name and patronymic.
//
// Returns:
//  Structure    - Structure with data set about individual:
//                 "LastName",
//                 "Name"
//                 "Patronymic"
//                 "Presentation (Full name)"
//                 "Department"
//                 "DocumentKind"
//                 "DocumentSeries"
//                 "DocumentNumber"
//                 "DocumentDateIssued"
//                 "DocumentIssuedBy"
//                 "DocumentDepartmentCode".
//
Function IndData(Company, Ind, CutoffDate, NameAndSurnameShort = True) Export
	
	PersonalQuery = New Query();
	PersonalQuery.SetParameter("CutoffDate", CutoffDate);
	PersonalQuery.SetParameter("Company", GetCompany(Company));
	PersonalQuery.SetParameter("Ind", Ind);
	PersonalQuery.Text =
	"SELECT
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic,
	|	Employees.Department,
	|	Employees.EmployeeCode,
	|	Employees.Position,
	|	LegalDocuments.DocumentKind AS DocumentKind,
	|	LegalDocuments.Number AS DocumentNumber,
	|	LegalDocuments.IssueDate AS DocumentIssueDate,
	|	LegalDocuments.Authority AS DocumentWhoIssued
	|FROM
	|	(SELECT
	|		Individuals.Ref AS Ind
	|	FROM
	|		Catalog.Individuals AS Individuals
	|	WHERE
	|		Individuals.Ref = &Ind) AS NatPerson
	|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&CutoffDate, Ind = &Ind) AS ChangeHistoryOfIndividualNamesSliceLast
	|		ON NatPerson.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
	|		LEFT JOIN (SELECT TOP 1
	|			Employees.Employee.Code AS EmployeeCode,
	|			Employees.Employee.Ind AS Ind,
	|			Employees.Position AS Position,
	|			Employees.StructuralUnit AS Department
	|		FROM
	|			InformationRegister.Employees.SliceLast(
	|					&CutoffDate,
	|					Employee.Ind = &Ind
	|						AND Company = &Company) AS Employees
	|		WHERE
	|			Employees.StructuralUnit <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|		
	|		ORDER BY
	|			Employees.Employee.EmploymentContractType.Order DESC) AS Employees
	|		ON NatPerson.Ind = Employees.Ind
	|		LEFT JOIN Catalog.LegalDocuments AS LegalDocuments
	|		ON NatPerson.Ind = LegalDocuments.Owner";
	
	Data = PersonalQuery.Execute().Select();
	Data.Next();
	
	Result = New Structure("Surname, Name, Patronymic, Presentation, EmployeeCode, Position, Department, DocumentKind,
							|DocumentNumber, DocumentIssueDate, DocumentWhoIssued, DocumentPresentation");

	FillPropertyValues(Result, Data);

	Result.Presentation = GetSurnameNamePatronymic(Data.Surname, Data.Name, Data.Patronymic, NameAndSurnameShort);
	Result.DocumentPresentation = GetNatPersonDocumentPresentation(Data);
	
	Return Result;
	
EndFunction

// The function returns info on the company responsible
// employees and their positions.
//
// Parameters:
//  Company - Compound
//                 type: CatalogRef.Companies,
//                 CatalogRef.CashAccounts, CatalogRef.StoragePlaces  organizational unit
//                 for which it is
//  reqired to get information about responsible people CutoffDate    - Date - date on which data is read.
//
// Returns:
//  Structure    - Structure with info on the
//                 business unit individuals.
//
Function OrganizationalUnitsResponsiblePersons(OrganizationalUnit, CutoffDate) Export
	
	Result = New Structure("ManagerDescriptionFull, ChiefAccountantDescriptionFull, CashierDescriptionFull, WarehouseSupervisorDescriptionFull");
	
	// Refs
	Result.Insert("Head");
	Result.Insert("ChiefAccountant");
	Result.Insert("Cashier");
	Result.Insert("WarehouseSupervisor");
	
	// Full name presentation
	Result.Insert("HeadDescriptionFull");
	Result.Insert("ChiefAccountantNameAndSurname");
	Result.Insert("CashierNameAndSurname");
	Result.Insert("WarehouseSupervisorSNP");
	
	// Positions presentation (ref)
	Result.Insert("HeadPositionRefs");
	Result.Insert("ChiefAccountantPositionRef");
	Result.Insert("CashierPositionRefs");
	Result.Insert("WarehouseSupervisorPositionRef");
	
	// Position presentation
	Result.Insert("HeadPosition");
	Result.Insert("ChiefAccountantPosition");
	Result.Insert("CashierPosition");
	Result.Insert("WarehouseSupervisor_Position");
	
	If OrganizationalUnit <> Undefined Then
	
		Query = New Query;
		Query.SetParameter("CutoffDate", CutoffDate);
		Query.SetParameter("OrganizationalUnit", OrganizationalUnit);
		
		Query.Text = 
		"SELECT
		|	ResponsiblePersonsSliceLast.Company AS OrganizationalUnit,
		|	ResponsiblePersonsSliceLast.ResponsiblePersonType AS ResponsiblePersonType,
		|	ResponsiblePersonsSliceLast.Employee AS Employee,
		|	CASE
		|		WHEN ChangeHistoryOfIndividualNamesSliceLast.Ind IS NULL 
		|			THEN ResponsiblePersonsSliceLast.Employee.Description
		|		ELSE ChangeHistoryOfIndividualNamesSliceLast.Surname + "" "" + SubString(ChangeHistoryOfIndividualNamesSliceLast.Name, 1, 1) + "". "" + SubString(ChangeHistoryOfIndividualNamesSliceLast.Patronymic, 1, 1) + "".""
		|	END AS Individual,
		|	ResponsiblePersonsSliceLast.Position AS Position,
		|	ResponsiblePersonsSliceLast.Position.Description AS AppointmentName
		|FROM
		|	InformationRegister.ResponsiblePersons.SliceLast(&CutoffDate, Company = &OrganizationalUnit) AS ResponsiblePersonsSliceLast
		|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast AS ChangeHistoryOfIndividualNamesSliceLast
		|		ON ResponsiblePersonsSliceLast.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind";
		
		Selection = Query.Execute().Select();
		
		While Selection.Next() Do
			
			If Selection.ResponsiblePersonType 	= Enums.ResponsiblePersonTypes.ChiefExecutiveOfficer Then
				
				Result.Head					= Selection.Employee;
				Result.HeadDescriptionFull	= Selection.Individual;
				Result.HeadPositionRefs		= Selection.Position;
				Result.HeadPosition			= Selection.AppointmentName;
				
			ElsIf Selection.ResponsiblePersonType = Enums.ResponsiblePersonTypes.ChiefAccountant Then
				
				Result.ChiefAccountant					= Selection.Employee;
				Result.ChiefAccountantNameAndSurname 	= Selection.Individual;
				Result.ChiefAccountantPositionRef 		= Selection.Position;
				Result.ChiefAccountantPosition			= Selection.AppointmentName;
				
			ElsIf Selection.ResponsiblePersonType = Enums.ResponsiblePersonTypes.Cashier Then
				
				Result.Cashier					= Selection.Employee;
				Result.CashierNameAndSurname	= Selection.Individual;
				Result.CashierPositionRefs 		= Selection.Position;
				Result.CashierPosition			= Selection.AppointmentName;
				
			ElsIf Selection.ResponsiblePersonType = Enums.ResponsiblePersonTypes.WarehouseSupervisor Then
				
				Result.WarehouseSupervisor				= Selection.Employee;
				Result.WarehouseSupervisorSNP			= Selection.Individual;
				Result.WarehouseSupervisorPositionRef	= Selection.Position;
				Result.WarehouseSupervisor_Position		= Selection.AppointmentName;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	Return Result
	
EndFunction

// Receive a presentation of the identity document.
//
// Parameters
//  IndData - Collection of bodies data. bodies (structure, table row
//                 ...) containing values: DokumentKind,
//                 DokumentSeries, DokumentNumber, IssuedateDokument, DocumentWhoIssued.  
//
// Returns:
//   String      - Identity papers presentation.
//
Function GetNatPersonDocumentPresentation(IndData) Export

	Return StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 nubmer %2, issued on %3 by %4'"),
		String(IndData.DocumentKind),
		IndData.DocumentNumber,
		Format(IndData.DocumentIssueDate, "DLF=D"),
		IndData.DocumentWhoIssued);

EndFunction

// Procedure is designed to convert document number.
//
// Parameters:
//  Document     - (DocumentRef), document which number
//                 should be received for printing.
//
// Return value.
//  String       - document number for printing
//
Function GetNumberForPrinting(DocumentNumber, Prefix) Export

	If Not ValueIsFilled(DocumentNumber) Then 
		Return 0;
	EndIf;

	Number = TrimAll(DocumentNumber);
	
	// delete prefix from the document number
	If Find(Number, Prefix)=1 Then 
		Number = Mid(Number, StrLen(Prefix)+1);
	EndIf;
	
	ExchangePrefix = "";
			
	If GetFunctionalOption("UseDataSync")
		AND ValueIsFilled(Constants.GlobalNumerationPrefix.Get()) Then		
		ExchangePrefix = TrimAll(Constants.GlobalNumerationPrefix.Get());		
	EndIf;
	
	// delete prefix from the document number
	If Find(Number, ExchangePrefix)=1 Then 
		Number = Mid(Number, StrLen(ExchangePrefix)+1);
	EndIf;
	
	// also "minus" may be in front
	If Left(Number, 1) = "-" Then
		Number = Mid(Number, 2);
	EndIf;
	
	// delete leading nulls
	While Left(Number, 1)="0" Do
		Number = Mid(Number, 2);
	EndDo;

	Return Number;

EndFunction

Function GetNumberForPrintingConsideringDocumentDate(DocumentDate, DocumentNumber, Prefix) Export
	
	If DocumentDate < Date('20110101') Then
		
		Return GetNumberForPrinting(DocumentNumber, Prefix);
		
	Else
		
		Return ObjectPrefixationClientServer.GetNumberForPrinting(DocumentNumber, True, True);
		
	EndIf;
	
EndFunction

// Returns the data structure with the consolidated counterparty description.
//
// Parameters: 
//  ListInformation - values list with parameters values
//   of InformationList company is
//  generated by the InfoAboutLegalEntityIndividual function List         - company desired parameters
//  list WithPrefix     - Shows whether to output company parameter prefix or not
//
// Returns:
//  String - company specifier / counterparty / individuals.
//
Function CompaniesDescriptionFull(ListInformation, List = "", WithPrefix = True) Export

	If IsBlankString(List) Then
		List = "FullDescr,TIN,LegalAddress,PostalAddress,PhoneNumbers,Fax,AccountNo,IBAN,Bank,SWIFT";
	EndIf; 

	Result = "";

	AccordanceOfParameters = New Map();
	AccordanceOfParameters.Insert("FullDescr",			" ");
	AccordanceOfParameters.Insert("TIN",				" " + NStr("en = 'TIN'") + " ");
	AccordanceOfParameters.Insert("RegistrationNumber",	" ");
	AccordanceOfParameters.Insert("LegalAddress",		" ");
	AccordanceOfParameters.Insert("PostalAddress",		" ");
	AccordanceOfParameters.Insert("PhoneNumbers",		" " + NStr("en = 'phone'") + ": ");
	AccordanceOfParameters.Insert("Fax",				" " + NStr("en = 'fax'") + ": ");
	AccordanceOfParameters.Insert("AccountNo",			" " + NStr("en = 'account number'") + " ");
	AccordanceOfParameters.Insert("IBAN",				" IBAN ");
	AccordanceOfParameters.Insert("Bank",				" " + NStr("en = 'in the bank'") + " ");
	AccordanceOfParameters.Insert("SWIFT",				" SWIFT ");

	List = List + ?(Right(List, 1) = ",", "", ",");
	NumberOfParameters = StrOccurrenceCount(List, ",");

	For Counter = 1 To NumberOfParameters Do

		CommaPos = Find(List, ",");

		If CommaPos > 0  Then
			ParameterName = Left(List, CommaPos - 1);
			List = Mid(List, CommaPos + 1, StrLen(List));
			
			Try
				AdditionString = "";
				ListInformation.Property(ParameterName, AdditionString);
				
				If IsBlankString(AdditionString) Then
					Continue;
				EndIf;
				
				Prefix = AccordanceOfParameters[TrimAll(ParameterName)];
				If Not IsBlankString(Result)  Then
					Result = Result + ", ";
				EndIf; 

				Result = Result + ?(WithPrefix = True, Prefix, "") + AdditionString;

			Except
				CommonUseClientServer.MessageToUser(StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Failed to define value for parameter %1.'"),
					ParameterName));
			EndTry;

		EndIf; 

	EndDo;

	Return TrimAll(Result);

EndFunction

// Standard formatting function of quantity writing.
//
// Parameters:
//  Count   - number that you want to format.
//
// Returns:
//  Properly formatted string presentation of the quantity.
//
Function QuantityInWords(Count) Export

	IntegralPart   = Int(Count);
	FractionalPart = Round(Count - IntegralPart, 3);

	If FractionalPart = Round(FractionalPart,0) Then
		ProtocolParameters = ", , , , , , , , 0";
   	ElsIf FractionalPart = Round(FractionalPart, 1) Then
		ProtocolParameters = "integer, integer, integer, F, tenth, tenth, tenth, M, 1";
   	ElsIf FractionalPart = Round(FractionalPart, 2) Then
		ProtocolParameters = "integer, integer, integer, F, hundredth, hundredth, hundredth, M, 2";
   	Else
		ProtocolParameters = "integer, integer, integer, F, thousandth, thousandth, thousandth, M, 3";
    EndIf;

	Return NumberInWords(Count, ,ProtocolParameters);

EndFunction

// Function generates information about the specified LegEntInd. Details include -
// name, address, phone number, bank connection.
//
// Parameters: 
//  LegalEntityIndividual    - company or individual for
//                 whom
//  info is collected PeriodDate  - date on which information about
//  LegEntInd ForIndividualOnlyInitials is selected - For ind. bodies output only name and
//                 patonymic initials
//
// Returns:
//  Information - collected info.
//
Function InfoAboutLegalEntityIndividual(LegalEntityIndividual, PeriodDate, ForIndividualOnlyInitials = True, BankAccount = Undefined) Export
	
	Information = New Structure;
	Information.Insert("Presentation");
	Information.Insert("FullDescr");
	Information.Insert("TIN");
	Information.Insert("RegistrationNumber");
	Information.Insert("PhoneNumbers");
	Information.Insert("Fax");
	Information.Insert("LegalAddress");
	Information.Insert("Bank");
	Information.Insert("SWIFT");
	Information.Insert("CorrespondentText");
	Information.Insert("AccountNo");
	Information.Insert("IBAN");
	Information.Insert("BankAddress");
	Information.Insert("Email");
	Information.Insert("VATnumber");
	Information.Insert("DeliveryAddress");
	Information.Insert("ResponsibleEmployee");
	Information.Insert("FullDescrShipTo");
	
	Query	= New Query;
	Data	= Undefined;
	
	If Not ValueIsFilled(LegalEntityIndividual) Then
		Return Information;
	EndIf;
	
	CatalogName = "";
	
	If TypeOf(LegalEntityIndividual) = Type("CatalogRef.Companies") Then
		CatalogName = "Companies";
	ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Counterparties") Then
		CatalogName = "Counterparties";
	ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.BusinessUnits") Then
		CatalogName = "BusinessUnits";
	ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Individuals") Then
		CatalogName = "Individuals";
	EndIf;
	
	If CatalogName = "Companies" OR CatalogName = "Counterparties" Then
		
		If BankAccount = Undefined OR BankAccount.IsEmpty() Then
			CurrentBankAccount = LegalEntityIndividual.BankAccountByDefault;
		Else
			CurrentBankAccount = BankAccount;
		EndIf;
		
		// Select main information about counterparty LegalEntityIndividual.MainBankAccount.Empty
		If CurrentBankAccount.AccountsBank.IsEmpty() Then
			BankAttributeName = "Bank";
		Else
			BankAttributeName = "AccountsBank";
		EndIf;
		
		Query.SetParameter("ParLegEntInd",		LegalEntityIndividual);
		Query.SetParameter("ParBankAccount",	CurrentBankAccount);
		
		Query.Text = 
		"SELECT
		|	Companies.Presentation AS Description,
		|	Companies.DescriptionFull AS FullDescr,
		|	Companies.TIN,
		|	Companies.VATNumber,
		|	Companies.RegistrationNumber,";
		
		If Not ValueIsFilled(CurrentBankAccount) Then
			
			Query.Text = Query.Text + "
			|	""""	AS AccountNo,
			|	""""	AS IBAN,
			|	""""	AS CorrespondentText,
			|	""""	AS Bank,
			|	""""	AS SWIFT,
			|	""""	AS BankAddress
			|FROM
			|	Catalog." + CatalogName + " AS Companies
			|WHERE Companies.Ref = &ParLegEntInd";
			
		Else
			
			Query.Text = Query.Text + "
			|	BankAccounts.AccountNo							AS AccountNo,
			|	BankAccounts.IBAN								AS IBAN,
			|	BankAccounts.CorrespondentText					AS CorrespondentText,
			|	BankAccounts." + BankAttributeName + "				AS Bank,
			|	BankAccounts." + BankAttributeName + ".Code			AS SWIFT,
			|	BankAccounts." + BankAttributeName + ".Address		AS BankAddress
			|FROM 
			|	Catalog." + CatalogName + " AS Companies,
			|	Catalog.BankAccounts AS BankAccounts
			|
			|WHERE
			|	Companies.Ref			= &ParLegEntInd
			|	AND BankAccounts.Ref	= &ParBankAccount";
			
		EndIf;
		
		Data = Query.Execute().Select();
		Data.Next();
		
		Information.Insert("FullDescr",			Data.FullDescr);
		Information.Insert("FullDescrShipTo",	Data.FullDescr);
		
		If Data <> Undefined Then
			
			EmptyContactInformationKind = Catalogs.ContactInformationTypes.EmptyRef();
			
			If TypeOf(LegalEntityIndividual) = Type("CatalogRef.Companies") Then
				
				Phone			= Catalogs.ContactInformationTypes.CompanyPhone;
				Fax				= Catalogs.ContactInformationTypes.CompanyFax;
				LegAddress		= Catalogs.ContactInformationTypes.CompanyLegalAddress;
				RealAddress		= Catalogs.ContactInformationTypes.CompanyActualAddress;
				PostAddress		= Catalogs.ContactInformationTypes.CompanyPostalAddress;
				DeliveryAddress	= RealAddress;
				Email			= Catalogs.ContactInformationTypes.CompanyEmail;
				Webpage			= Catalogs.ContactInformationTypes.CompanyWebpage;
				
			ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Individuals") Then
				
				Phone			= Catalogs.ContactInformationTypes.IndividualPhone;
				Fax				= EmptyContactInformationKind;
				LegAddress		= Catalogs.ContactInformationTypes.IndividualPostalAddress;
				RealAddress		= Catalogs.ContactInformationTypes.IndividualActualAddress;
				PostAddress		= RealAddress;
				DeliveryAddress	= RealAddress;
				Email			= Catalogs.ContactInformationTypes.IndividualEmail;
				Webpage			= EmptyContactInformationKind;
				
			ElsIf TypeOf(LegalEntityIndividual) = Type("CatalogRef.Counterparties") Then
				
				Phone			= Catalogs.ContactInformationTypes.CounterpartyPhone;
				Fax				= Catalogs.ContactInformationTypes.CounterpartyFax;
				LegAddress		= Catalogs.ContactInformationTypes.CounterpartyLegalAddress;
				RealAddress		= Catalogs.ContactInformationTypes.CounterpartyActualAddress;
				PostAddress		= Catalogs.ContactInformationTypes.CounterpartyPostalAddress;
				DeliveryAddress	= Catalogs.ContactInformationTypes.CounterpartyDeliveryAddress;
				Email			= Catalogs.ContactInformationTypes.CounterpartyEmail;
				Webpage			= Catalogs.ContactInformationTypes.CounterpartyWebpage;
				
			Else
				
				Phone			= EmptyContactInformationKind;
				Fax				= EmptyContactInformationKind;
				LegAddress		= EmptyContactInformationKind;
				RealAddress		= EmptyContactInformationKind;
				PostAddress		= EmptyContactInformationKind;
				DeliveryAddress	= EmptyContactInformationKind;
				Email			= Undefined;
				Webpage			= EmptyContactInformationKind;
				
			EndIf;
			
			Information.Insert("Presentation",			Data.Description);
			Information.Insert("TIN",					Data.TIN);
			Information.Insert("VATNumber",				Data.VATNumber);
			Information.Insert("RegistrationNumber",	Data.RegistrationNumber);
			Information.Insert("PhoneNumbers",			GetContactInformation(LegalEntityIndividual, Phone));
			Information.Insert("Fax",					GetContactInformation(LegalEntityIndividual, Fax));
			Information.Insert("AccountNo",				Data.AccountNo);
			Information.Insert("IBAN",					Data.IBAN);
			Information.Insert("Bank",					Data.Bank);
			Information.Insert("SWIFT",					Data.SWIFT);
			Information.Insert("BankAddress",			Data.BankAddress);
			Information.Insert("CorrespondentText",		Data.CorrespondentText);
			Information.Insert("LegalAddress",			GetContactInformation(LegalEntityIndividual, LegAddress));
			Information.Insert("ActualAddress",			GetContactInformation(LegalEntityIndividual, RealAddress));
			Information.Insert("PostalAddress",			GetContactInformation(LegalEntityIndividual, PostAddress));
			Information.Insert("DeliveryAddress",		GetContactInformation(LegalEntityIndividual, DeliveryAddress));
			Information.Insert("Webpage",				GetContactInformation(LegalEntityIndividual, Webpage));
			
			If ValueIsFilled(Email) Then
				Information.Insert("Email", GetContactInformation(LegalEntityIndividual, Email));
			EndIf;
			
			If Not ValueIsFilled(Information.FullDescr) Then
				Information.FullDescr		= Information.Presentation;
				Information.FullDescrShipTo	= Information.Presentation;
			EndIf;
			
		EndIf;
		
	ElsIf CatalogName = "BusinessUnits" Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	BusinessUnits.Presentation AS Description,
		|	BusinessUnits.FRP AS FRP
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.Ref = &LegalEntityIndividual"; 
		
		Query.SetParameter("LegalEntityIndividual", LegalEntityIndividual);
		
		Data = Query.Execute().Select();
		Data.Next();
		
		If Data <> Undefined Then
			
			ObjectArray = New Array;
			ObjectArray.Add(LegalEntityIndividual);
			
			Information.Insert("FullDescr",			Data.Description);
			Information.Insert("FullDescrShipTo",	Data.Description);
			Information.Insert("Presentation",		Data.Description);
			PhoneArray = New Array;
			PhoneArray.Add(Enums.ContactInformationTypes.Phone);
			PhoneContactInformation = ContactInformationManagement.ObjectsContactInformation(ObjectArray, PhoneArray);
			If PhoneContactInformation.Count() > 0 Then
				Information.Insert("PhoneNumbers", PhoneContactInformation[0].Presentation);
			EndIf;
			
			AddressArray = New Array;
			AddressArray.Add(Enums.ContactInformationTypes.Address);
			AddressContactInformation = ContactInformationManagement.ObjectsContactInformation(ObjectArray, AddressArray);
			If AddressContactInformation.Count() > 0 Then
				Information.Insert("DeliveryAddress", AddressContactInformation[0].Presentation);
			EndIf;
			
			Information.Insert("ResponsibleEmployee", Data.FRP);
			
		EndIf;
		
	ElsIf CatalogName = "Individuals" Then
		
		Query = New Query;
		Query.Text =
		"SELECT
		|	Individuals.Presentation AS Description
		|FROM
		|	Catalog.Individuals AS Individuals
		|WHERE
		|	Individuals.Ref = &LegalEntityIndividual";
		
		Query.SetParameter("LegalEntityIndividual", LegalEntityIndividual);
		
		Data = Query.Execute().Select();
		Data.Next();
		
		If Data <> Undefined Then
			ObjectArray = New Array;
			ObjectArray.Add(LegalEntityIndividual);
			Phone = Catalogs.ContactInformationTypes.IndividualPhone;

			Information.Insert("FullDescr",			Data.Description);
			Information.Insert("FullDescrShipTo",	Data.Description);
			Information.Insert("Presentation",		Data.Description);
			Information.Insert("PhoneNumbers",		GetContactInformation(LegalEntityIndividual, Phone));
		EndIf;
		
	EndIf;

	Return Information;

EndFunction

// Generates information about the specified ContactPerson. Details include -
// phone number, e-mail address.
//
// Parameters: 
//  ContactPerson - CatalogRef.ContactPersons - contact person for whom info is collected
//
// Returns:
//  Information - collected info.
//
Function InfoAboutContactPerson(ContactPerson) Export
	
	Information = New Structure;
	Information.Insert("PhoneNumbers", "");
	Information.Insert("Email", "");
	
	If NOT ValueIsFilled(ContactPerson) Then
		Return Information;
	EndIf;
	
	Phone = Catalogs.ContactInformationTypes.ContactPersonPhone;
	Email = Catalogs.ContactInformationTypes.ContactPersonEmail;
	
	Information.Insert("PhoneNumbers", GetContactInformation(ContactPerson, Phone));
	Information.Insert("Email", GetContactInformation(ContactPerson, Email));
	
	Return Information;

EndFunction

// Generates information about the specified ShippingAddress. Details include - address.
//
// Parameters: 
//  ShippingAddress - CatalogRef.ShippingAddresses - shipping address person for whom info is collected
//
// Returns:
//  Information - collected info.
//
Function InfoAboutShippingAddress(ShippingAddress) Export
	
	Information = New Structure;
	Information.Insert("DeliveryAddress", "");
	
	If TypeOf(ShippingAddress) = Type("CatalogRef.ShippingAddresses") Then
		Address = Catalogs.ContactInformationTypes.ShippingAddress;
		Information.Insert("DeliveryAddress", GetContactInformation(ShippingAddress, Address));
	EndIf;
	
	Return Information;

EndFunction

// The function finds an actual address value in contact information.
//
// Parameters:
//  Object       - CatalogRef, contact
//  information object AddressType    - contact information type.
//
// Returned
//  value String - found address presentation.
//                                          
Function GetContactInformation(ContactInformationObject, InformationKind) Export
	
	If TypeOf(ContactInformationObject) = Type("CatalogRef.Companies") Then
		
		SourceTable = "Companies";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.Individuals") Then
		
		SourceTable = "Individuals";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.Counterparties") Then
		
		SourceTable = "Counterparties";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.ContactPersons") Then
		
		SourceTable = "ContactPersons";
		
	ElsIf TypeOf(ContactInformationObject) = Type("CatalogRef.ShippingAddresses") Then
		
		SourceTable = "ShippingAddresses";
		
	Else 
		
		Return "";
		
	EndIf;
	
	Query = New Query;
	
	Query.SetParameter("Object", ContactInformationObject);
	Query.SetParameter("Kind",	InformationKind);
	
	Query.Text = "SELECT 
	|	ContactInformation.Presentation
	|FROM
	|	Catalog." + SourceTable + ".ContactInformation
	|AS
	|ContactInformation WHERE ContactInformation.Kind
	|	= &Kind And ContactInformation.Ref = &Object";

	QueryResult = Query.Execute();
	
	Return ?(QueryResult.IsEmpty(), "", QueryResult.Unload()[0].Presentation);

EndFunction

// Standard for this configuration function of amounts formatting
//
// Parameters: 
//  Amount        - number that should be
// formatted Currency       - reference to the item of currencies catalog, if
//                 set, then NZ currency presentation will
//  be added to the resulting string           - String that presents the
//  zero value of NGS number          - character-separator of groups of number integral part.
//
// Returns:
//  Properly formatted string representation of the amount.
//
Function AmountsFormat(Amount, Currency = Undefined, NZ = "", NGS = "") Export

	FormatString = "ND=15;NFD=2" +
					?(NOT ValueIsFilled(NZ), "", ";" + "NZ=" + NZ) +
					?(NOT ValueIsFilled(NGS),"", ";" + "NGS=" + NGS);

	ResultString = TrimL(Format(Amount, FormatString));
	
	If ValueIsFilled(Currency) Then
		ResultString = ResultString + " " + TrimR(Currency);
	EndIf;

	Return ResultString;

EndFunction

// Generates bank payment document amount.
//
// Parameters:
//  Amount        - Number - attribute that
//  should be formatted OutputAmountWithoutKopeks - Boolean - check box of amount presentation without kopeks.
//
// Return
//  value Formatted string.
//
Function FormatPaymentDocumentSUM(Amount, DisplayAmountWithoutCents = False) Export
	
	Result  = Amount;
	IntegralPart = Int(Amount);
	
	If Result = IntegralPart Then
		If DisplayAmountWithoutCents Then
			Result = Format(Result, "NFD=2; NDS='='; NG=0");
			Result = Left(Result, Find(Result, "="));
		Else
			Result = Format(Result, "NFD=2; NDS='-'; NG=0");
		EndIf;
	Else
		Result = Format(Result, "NFD=2; NDS='-'; NG=0");
	EndIf;
	
	Return Result;
	
EndFunction

// Formats amount in writing of banking payment document.
//
// Parameters:
//  Amount        - Number - attribute that should be
// presented in writing Currency       - CatalogRef.Currencies - currency in which
//                 amount
//  should be OutputAmoutWithoutKopek - Boolean - check box of amount presentation without kopeks.
//
// Return
//  value Formatted string.
//
Function FormatPaymentDocumentAmountInWords(Amount, SubjectParam, DisplayAmountWithoutCents = False, FormatString = "") Export
	
	Result = "";
	
	If IsBlankString(FormatString) Then
		FormatString = "L=en_EN; FS=False";
	EndIf;
	
	If Amount = Int(Amount) Then
		If DisplayAmountWithoutCents Then
			Result = NumberInWords(Amount, FormatString, SubjectParam);
			Result = Left(Result, Find(Result, "0") - 1);
		Else
			Result = NumberInWords(Amount, FormatString, SubjectParam);
		EndIf;
	Else
		Result = NumberInWords(Amount, FormatString, SubjectParam);
	EndIf;
	
	Return Result;
	
EndFunction

// Sets the Long operation state for an item form of the tabular document type
//
Procedure StateDocumentsTableLongOperation(FormItem, StatusText = "") Export
	
	StatePresentation = FormItem.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.Irrelevance;
	StatePresentation.Picture = PictureLib.LongOperation48;
	StatePresentation.Text = StatusText;
	
EndProcedure

// Sets the Long operation state for an item form of the tabular document type
//
Procedure NotActualSpreadsheetDocumentState(FormItem, StatusText = "") Export
	
	StatePresentation = FormItem.StatePresentation;
	StatePresentation.Visible = True;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Picture = New Picture;
	StatePresentation.Text = StatusText;
	
EndProcedure

// Sets the Long operation state for an item form of the tabular document type
//
Procedure SpreadsheetDocumentStateActual(FormItem) Export
	
	StatePresentation = FormItem.StatePresentation;
	StatePresentation.Visible = False;
	StatePresentation.AdditionalShowMode = AdditionalShowMode.DontUse;
	StatePresentation.Picture = New Picture;
	StatePresentation.Text = "";
	
EndProcedure

// Checks if the pass table documents fit in the printing page.
//
// Parameters
//  TabDocument       - Tabular
//  document DisplayedAreas - Array of checked tables or
//  tabular document ResultOnError - Which result to return if an error occurs
//
// Returns:
//   Boolean   - whether the sent documents fit in or not
//
Function SpreadsheetDocumentFitsPage(Spreadsheet, AreasToPut, ResultOnError = True)

	Try
		Return Spreadsheet.CheckPut(AreasToPut);
	Except
		ErrorDescription = ErrorInfo();
		WriteLogEvent(
			NStr("en = 'Cannot get information about the current printer (maybe, no printers are installed in the application)'",
				CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			ErrorDescription.Definition);
		Return ResultOnError;
	EndTry;

EndFunction

// Count sheets quantity in document
//
Function CheckAccountsInvoicePagePut(Spreadsheet, AreaCurRows, IsLastRow, Template, NumberWorksheet, InvoiceNumber) Export
	
	// Check whether it is possible to output tabular document
	RowWithFooter = New Array;
	RowWithFooter.Add(AreaCurRows);
	If IsLastRow Then
		// If it is the last string, then total and footer should fit
		RowWithFooter.Add(Template.GetArea("Total"));
		RowWithFooter.Add(Template.GetArea("Footer"));
	EndIf;
	
	CheckResult = SpreadsheetDocumentFitsPage(Spreadsheet, RowWithFooter);
	
	If Not CheckResult Then
		// Output separator and table title on the new page
		
		NumberWorksheet = NumberWorksheet + 1;
		
		AreaSheetsNumbering = Template.GetArea("NumberingOfSheets");
		AreaSheetsNumbering.Parameters.Number = InvoiceNumber;
		AreaSheetsNumbering.Parameters.NumberWorksheet = NumberWorksheet;
		
		Spreadsheet.PutHorizontalPageBreak();
		
		Spreadsheet.Put(AreaSheetsNumbering);
		Spreadsheet.Put(Template.GetArea("TableTitle"));
		
	EndIf;
	
	Return CheckResult;
	
EndFunction

// Function prepares data for printing labels and price tags.
//
// Returns:
//   Address   - data structure address in the temporary storage
//
Function PreparePriceTagsAndLabelsPrintingFromDocumentsDataStructure(DocumentArray, IsPriceTags) Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ReceiptOfProductsServicesProducts.Products AS Products,
	|	ReceiptOfProductsServicesProducts.Characteristic AS Characteristic,
	|	ReceiptOfProductsServicesProducts.Batch AS Batch,
	|	SUM(ReceiptOfProductsServicesProducts.Quantity) AS Quantity
	|FROM
	|	Document.SupplierInvoice.Inventory AS ReceiptOfProductsServicesProducts
	|WHERE
	|	ReceiptOfProductsServicesProducts.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	ReceiptOfProductsServicesProducts.Products,
	|	ReceiptOfProductsServicesProducts.Characteristic,
	|	ReceiptOfProductsServicesProducts.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	InventoryTransferInventory.Products,
	|	InventoryTransferInventory.Characteristic,
	|	InventoryTransferInventory.Batch,
	|	SUM(InventoryTransferInventory.Quantity)
	|FROM
	|	Document.InventoryTransfer.Inventory AS InventoryTransferInventory
	|WHERE
	|	InventoryTransferInventory.Ref IN(&DocumentArray)
	|
	|GROUP BY
	|	InventoryTransferInventory.Products,
	|	InventoryTransferInventory.Characteristic,
	|	InventoryTransferInventory.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	ReceiptOfGoodsAndServices.Company AS Company,
	|	ReceiptOfGoodsAndServices.StructuralUnit AS StructuralUnit,
	|	ReceiptOfGoodsAndServices.StructuralUnit.RetailPriceKind AS PriceKind
	|FROM
	|	Document.SupplierInvoice AS ReceiptOfGoodsAndServices
	|WHERE
	|	ReceiptOfGoodsAndServices.Ref IN(&DocumentArray)
	|
	|UNION ALL
	|
	|SELECT DISTINCT
	|	InventoryTransfer.Company,
	|	InventoryTransfer.StructuralUnitPayee,
	|	InventoryTransfer.StructuralUnitPayee.RetailPriceKind
	|FROM
	|	Document.InventoryTransfer AS InventoryTransfer
	|WHERE
	|	InventoryTransfer.Ref IN(&DocumentArray)";
	
	Query.SetParameter("DocumentArray", DocumentArray);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableAttributesDocuments	= ResultsArray[1].Unload();
	CompaniesArray			= DataProcessors.PrintLabelsAndTags.GroupValueTableByAttribute(TableAttributesDocuments, "Company").UnloadColumn(0);
	WarehousesArray				= DataProcessors.PrintLabelsAndTags.GroupValueTableByAttribute(TableAttributesDocuments, "StructuralUnit").UnloadColumn(0);
	PriceTypesArray				= DataProcessors.PrintLabelsAndTags.GroupValueTableByAttribute(TableAttributesDocuments, "PriceKind").UnloadColumn(0);
	
	// Prepare actions structure for labels and price tags printing processor
	ActionsStructure = New Structure;
	ActionsStructure.Insert("FillCompany", ?(CompaniesArray.Count() = 1,CompaniesArray[0], Undefined));
	ActionsStructure.Insert("FillWarehouse", ?(WarehousesArray.Count() = 1,WarehousesArray[0], WarehousesArray));
	ActionsStructure.Insert("FillKindPrices", ?(PriceTypesArray.Count() = 1,PriceTypesArray[0], Undefined));
	ActionsStructure.Insert("ShowColumnNumberOfDocument", True);
	ActionsStructure.Insert("SetPrintModeFromDocument");
	If IsPriceTags Then
		
		ActionsStructure.Insert("SetMode", "TagsPrinting");
		ActionsStructure.Insert("FillOutPriceTagsQuantityOnDocument");
		
	Else
		
		ActionsStructure.Insert("SetMode", "LabelsPrinting");
		ActionsStructure.Insert("FillLabelsQuantityByDocument");
		
	EndIf;
	ActionsStructure.Insert("FillProductsTable");
	
	// Data preparation for filling tabular section of labels and price tags printing processor
	ResultStructure = New Structure;
	ResultStructure.Insert("Inventory", ResultsArray[0].Unload());
	ResultStructure.Insert("ActionsStructure", ActionsStructure);
	
	Return PutToTempStorage(ResultStructure);
	
EndFunction

// Function returns passed document contract.
//
Function GetContractDocument(Document) Export
	
	Return Document.Contract;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForWorkWithWorkCalendar

// Function returns row number in the
//  tabular document field for Events output by its date (beginning or end)
//
// Parameters
//  Hours - String,
//  hours dates Minutes - String, minutes
//  dates Date - Date, date current value
//  for definition Start - Boolean, shows that period has
//  begun or ended ComparisonDate - Date, date that is compared to the source date value
//
// Returns:
//   Number - String number in the tabular document field
//
Function ReturnLineNumber(Hours, Minutes, Date, Begin, DateComparison) Export
	
	If IsBlankString(Hours) Then
		Hours = 0;
	Else
		Hours = Number(Hours);
	EndIf; 
	
	If IsBlankString(Minutes) Then
		Minutes = 0;
	Else
		Minutes = Number(Minutes);
	EndIf; 
	
	If Begin Then
		If Date < BegOfDay(DateComparison) Then
			Return 1;
		Else
			If Minutes < 30 Then
				If Minutes = 0 Then
					If Hours = 0 Then
						Return 1;
					Else
						Return (Hours * 2 + 1);
					EndIf; 
				Else
					Return (Hours * 2 + 1);
				EndIf; 
			Else
				If Hours = 23 Then
					Return 48;
				Else
					Return (Hours * 2 + 2);
				EndIf; 
			EndIf;
		EndIf; 
	Else
		If Date > EndOfDay(DateComparison) Then
			Return 48;
		Else
			If Minutes = 0 Then
				If Hours = 0 Then
					Return 1;
				Else
					Return (Hours * 2);
				EndIf; 
			ElsIf Minutes <= 30 Then
				Return (Hours * 2 + 1);
			Else
				If Hours = 23 Then
					Return 48;
				Else
					Return (Hours * 2 + 2);
				EndIf; 
			EndIf;
		EndIf; 
	EndIf;
	
EndFunction

// Function returns weekday name by its number
//
// Parameters
//  WeekDayNumber - Day, number of the week day
//
// Returns:
//   String, weekday name
//
Function DefineWeekday(WeekDayNumber) Export
	
	If WeekDayNumber = 1 Then
		Return "Mo";
	ElsIf WeekDayNumber = 2 Then
		Return "Tu";
	ElsIf WeekDayNumber = 3 Then
		Return "We";
	ElsIf WeekDayNumber = 4 Then
		Return "Th";
	ElsIf WeekDayNumber = 5 Then
		Return "Fr";
	ElsIf WeekDayNumber = 6 Then
		Return "Sa";
	Else
		Return "Su";
	EndIf;
	
EndFunction

// Function defines the next date after the current
//  one depending on the set number of days in the week for displaying in the calendar
//
// Parameters
//  CurrentDate - Date, current date
//
// Returns:
//   Date - next date
//
Function DefineNextDate(CurrentDate, NumberOfWeekDays) Export
	
	If NumberOfWeekDays = "7" Then
		Return CurrentDate + 60*60*24;
	ElsIf NumberOfWeekDays = "6" Then
		If WeekDay(CurrentDate) = 6 Then
			Return CurrentDate + 60*60*24*2;
		Else
			Return CurrentDate + 60*60*24;
		EndIf; 
	ElsIf NumberOfWeekDays = "5" Then
		If WeekDay(CurrentDate) = 5 Then
			Return CurrentDate + 60*60*24*3;
		ElsIf WeekDay(CurrentDate) = 6 Then
			Return CurrentDate + 60*60*24*2;
		Else
			Return CurrentDate + 60*60*24;
		EndIf; 
	EndIf; 
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForWorkWithSelection

// The procedure sets (resets) filter settings for the specified user
// 
Procedure SetStandardFilterSettings(CurrentUser) Export
	
	If Not ValueIsFilled(CurrentUser) Then
		
		CommonUseClientServer.MessageToUser(
		NStr("en = 'User for whom default selection settings are set is not specified.'")
		);
		
		Return;
		
	EndIf;
	
	PickSettingsByDefault = PickSettingsByDefault();
	
	For Each Setting In PickSettingsByDefault Do
		
		SetUserSetting(Setting.Value, Setting.Key, CurrentUser);
		
	EndDo;
	
EndProcedure

// Returns default settings match.
//
Function PickSettingsByDefault()
	
	PickSettingsByDefault = New Map;
	
	PickSettingsByDefault.Insert("FilterGroup", 				Catalogs.Products.EmptyRef());
	PickSettingsByDefault.Insert("KeepCurrentHierarchy", 	False);
	PickSettingsByDefault.Insert("RequestQuantityAndPrice",	False);
	PickSettingsByDefault.Insert("ShowBalance", 			True);
	PickSettingsByDefault.Insert("ShowReserve", 			False);
	PickSettingsByDefault.Insert("ShowAvailableBalance",	False);
	PickSettingsByDefault.Insert("ShowPrices", 				True);
	PickSettingsByDefault.Insert("OutputBalancesMethod", 		Enums.BalancesOutputMethodInSelection.InTable);
	PickSettingsByDefault.Insert("OutputAdviceGoBackToProducts", True);
	PickSettingsByDefault.Insert("CouncilServicesOutputInReceiptDocuments", True);
	
	Return PickSettingsByDefault;
	
EndFunction

// Procedure initializes the setting
// of custom selection settings Relevant for new users
//
Procedure SettingUserPickSettingsOnWrite(Source, Cancel) Export
	
	If Source.DataExchange.Load = True Then
		
		Return;
		
	EndIf;
	
	UserRef = Source.Ref;
	
	If Not ValueIsFilled(UserRef) Then
		
		UserRef = Source.GetNewObjectRef();
		
		If Not ValueIsFilled(UserRef) Then 
			
			UserRef = Catalogs.Users.GetRef();
			Source.SetNewObjectRef(UserRef);
			
		EndIf;
		
	EndIf;
	
	SetStandardFilterSettings(UserRef);
	
EndProcedure

#EndRegion

#Region EmailsSendingProceduresAndFunctions

// The procedure fills out email sending parameters when printing documents.
// Parameters match parameters passed to procedure Printing of documents managers modules.
Procedure FillSendingParameters(SendingParameters, ObjectsArray, PrintFormsCollection) Export
	
	If TypeOf(ObjectsArray) = Type("Array") Then
		
		Recipients = New ValueList;
		MetadataTypesContainingPartnersEmails = DriveContactInformationServer.GetTypesOfMetadataContainingAffiliateEmail();
		
		For Each ArrayObject In ObjectsArray Do
			
			If Not ValueIsFilled(ArrayObject) Then 
				
				Continue; 
				
			ElsIf TypeOf(ArrayObject) = Type("CatalogRef.Counterparties") Then 
				
				// It is for printing from catalogs, for example, price lists from Catalogs.Counterparties
				StructureValuesToValuesList(Recipients, New Structure("Counterparty", ArrayObject));
				Continue;
				
			EndIf;
			
			ObjectMetadata = ArrayObject.Metadata();
			
			AttributesNamesContainedEmail = New Array;
			
			// Check all attributes of the passed object.
			For Each MetadataItem In ObjectMetadata.Attributes Do
				
				ObjectContainsEmail(MetadataItem, MetadataTypesContainingPartnersEmails, AttributesNamesContainedEmail);
				
			EndDo;
			
			If AttributesNamesContainedEmail.Count() > 0 Then
				
				StructureValuesToValuesList(
					Recipients,
					CommonUse.ObjectAttributesValues(ArrayObject, AttributesNamesContainedEmail)
					);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
	SendingParameters.Recipient = DriveContactInformationServer.PrepareRecipientsEmailAddresses(Recipients, True);
	
	AvailableAccounts = EmailOperations.AvailableAccounts(True);
	SendingParameters.Insert("Sender", ?(AvailableAccounts.Count() > 0, AvailableAccounts[0].Ref, Undefined));
	
	FillSubjectSendingText(SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Initiate receiving of available email
// accounts Parameters:
// ForSending - Boolean - If True is set, then only those records will be chosen from
// which you can send ForReceiving emails   - Boolean - If True is set, then only those records will be chosen by
// which you can receive emails EnableSystemAccount - Boolean - enable system account if it is available
//
// Returns:
// AvailableAccounts - ValueTable - With columns:
//    Ref       - CatalogRef.EmailAccounts - Ref to
//    the Name account - String - Name of
//    the Address account        - String - Email address
//
Function GetAvailableAccount(val ForSending = Undefined, val ForReceiving  = Undefined, val IncludingSystemEmailAccount = True) Export

	AvailableAccounts = EmailOperations.AvailableAccounts(ForSending, ForReceiving, IncludingSystemEmailAccount);
	
	Return ?(AvailableAccounts.Count() > 0, AvailableAccounts[0].Ref, Undefined);
	
EndFunction

// Adds metadata name containing email to array.
//
Procedure ObjectContainsEmail(AttributeObjectMetadata, MetadataTypesContainingPartnersEmails, AttributesNamesContainedEmail)
	
	If Not MetadataTypesContainingPartnersEmails.FindByValue(AttributeObjectMetadata.Type) = Undefined Then
		
		AttributesNamesContainedEmail.Add(AttributeObjectMetadata.Name);
		
	EndIf;
	
EndProcedure

// Procedure fills in theme and text of email sending parameters while printing documents.
// Parameters match parameters passed to procedure Printing of documents managers modules.
Procedure FillSubjectSendingText(SendingParameters, ObjectsArray, PrintFormsCollection)
	
	Subject  = "";
	Text = "";
	
	DocumentTitlePresentation = "";
	PresentationForWhom = "";
	PresentationFromWhom = "";
	
	PrintedDocuments = ObjectsArray.Count() > 0 AND CommonUse.ObjectKindByRef(ObjectsArray[0]) = "Document";
	
	If PrintedDocuments Then
		If ObjectsArray.Count() = 1 Then
			DocumentTitlePresentation = GenerateDocumentTitle(ObjectsArray[0]);
		Else
			DocumentTitlePresentation = "Documents: ";
			For Each ObjectForPrinting In ObjectsArray Do
				DocumentTitlePresentation = DocumentTitlePresentation + ?(DocumentTitlePresentation = "Documents: ", "", "; ")
					+ GenerateDocumentTitle(ObjectForPrinting);
			EndDo;
		EndIf;
	EndIf;
	
	TypesStructurePrintObjects = ArrangeListByTypesOfObjects(ObjectsArray);
	
	CompanyByLetter = GetGeneralAttributeValue(TypesStructurePrintObjects, "Company", TypeDescriptionFromRow("Companies"));
	CounterpartyByEmail  = GetGeneralAttributeValue(TypesStructurePrintObjects, "Counterparty",  TypeDescriptionFromRow("Counterparties"));
	
	If ValueIsFilled(CounterpartyByEmail) Then
		PresentationForWhom = "for " + GetParticipantPresentation(CounterpartyByEmail);
	EndIf;
	
	If ValueIsFilled(CompanyByLetter) Then
		PresentationFromWhom = "from " + GetParticipantPresentation(CompanyByLetter);
	EndIf;
	
	AllowedSubjectLength = Metadata.Documents.Event.Attributes.Subject.Type.StringQualifiers.Length;
	If StrLen(DocumentTitlePresentation + PresentationForWhom + PresentationFromWhom) > AllowedSubjectLength Then
		PresentationFromWhom = "";
	EndIf;
	If StrLen(DocumentTitlePresentation + PresentationForWhom + PresentationFromWhom) > AllowedSubjectLength Then
		PresentationForWhom = "";
	EndIf;
	If StrLen(DocumentTitlePresentation + PresentationForWhom + PresentationFromWhom) > AllowedSubjectLength Then
		DocumentTitlePresentation = "";
		If PrintedDocuments Then
			DocumentTitlePresentation = "Documents: ";
			For Each KeyAndValue In TypesStructurePrintObjects Do
				DocumentTitlePresentation = DocumentTitlePresentation + ?(DocumentTitlePresentation = "Documents: ", "", "; ")
					+ ?(IsBlankString(KeyAndValue.Key.ListPresentation), KeyAndValue.Key.Synonym, KeyAndValue.Key.ListPresentation);
			EndDo;
		EndIf;
	EndIf;
	
	Subject = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = '%1 %2 %3'"),
		DocumentTitlePresentation,
		PresentationForWhom,
		PresentationFromWhom
		);
		
	If Not (SendingParameters.Property("Subject") AND ValueIsFilled(SendingParameters.Subject)) Then
		SendingParameters.Insert("Subject", CutDoubleSpaces(Subject));
	EndIf;
	
	If Not (SendingParameters.Property("Text") AND ValueIsFilled(SendingParameters.Text)) Then
		SendingParameters.Insert("Text", CutDoubleSpaces(Text));
	EndIf;
	
EndProcedure

// The function receives a value of the main print attribute for the email participants.
//
// Parameters:
//  Ref	 - CatalogRef.Counterparties, CatalogRef.Companies	 - Ref to a participant for whom
// it is required to get a presentation Return value:
//  String - presentation value
Function GetParticipantPresentation(Ref)
	
	If Not ValueIsFilled(Ref) Then
		Return "";
	EndIf;
	
	ObjectAttributesNames = New Map;
	
	ObjectAttributesNames.Insert(Type("CatalogRef.Counterparties"), "DescriptionFull");
	ObjectAttributesNames.Insert(Type("CatalogRef.Companies"), "Description");
	
	Return CommonUse.ObjectAttributeValue(Ref, ObjectAttributesNames[TypeOf(Ref)]);
	
EndFunction

// Function replaces double spaces with ordinary ones.
//
// Parameters:
//  SourceLine	 - String
// Return value:
//  String - String without double spaces
Function CutDoubleSpaces(SourceLine)

	While Find(SourceLine, "  ") > 0  Do
	
		SourceLine = StrReplace(SourceLine, "  ", " ");
	
	EndDo; 
	
	Return TrimR(SourceLine);

EndFunction

// Function generates document title presentation.
//
// Returns:
//  String - document presentation as number and date in brief format
Function GenerateDocumentTitle(DocumentRef)

	If Not ValueIsFilled(DocumentRef) Then
		Return "";
	Else
		Return DocumentRef.Metadata().Synonym + StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = '#%1 dated %2'"),
			ObjectPrefixationClientServer.GetNumberForPrinting(DocumentRef.Number, True, True),
			Format(DocumentRef.Date, "DLF=D"));
	EndIf;

EndFunction

// Function returns reference types description by the incoming row.
//
// Parameters:
//  DescriptionStringTypes	 - String	 - String with catalog names
// separated by commas Return value:
//  TypeDescription
Function TypeDescriptionFromRow(DescriptionStringTypes)

	StructureAvailableTypes 	= New Structure(DescriptionStringTypes);
	ArrayAvailableTypes 		= New Array;
	
	For Each StructureItem In StructureAvailableTypes Do
		
		ArrayAvailableTypes.Add(Type("CatalogRef."+StructureItem.Key));
		
	EndDo; 
	
	Return New TypeDescription(ArrayAvailableTypes);
	
EndFunction

// Function breaks values list into match by values types.
//
// Parameters:
//  ObjectsArray - <ValuesList> - objects list of the different kind
//
// Returns:
//   Map   - match where Key = type Metadata, Value = array of objects of this type
Function ArrangeListByTypesOfObjects(ObjectList) Export
	
	TypesStructure = New Map;
	
	For Each Object In ObjectList Do
		
		DocumentMetadata = Object.Metadata();
		
		If TypesStructure.Get(DocumentMetadata) = Undefined Then
			DocumentArray = New Array;
			TypesStructure.Insert(DocumentMetadata, DocumentArray);
		EndIf;
		
		TypesStructure[DocumentMetadata].Add(Object);
		
	EndDo;
	
	Return TypesStructure;
	
EndFunction

// Returns a reference to the attribute value that must be the same in all the list documents. 
// If an attribute value differs in the list documents, Undefined is returned
//
// Parameters:
//  PrintObjects  - <ValuesList> - documents list in which you should look for counterparty
//
// Returns:
//   <CatalogRef>, Undefined - ref-attribute value that is in all documents, Undefined - else
//
Function GetGeneralAttributeValue(TypesStructure, AttributeName, AllowedTypeDescription)
	Var QueryText;
	
	Query = New Query;
	
	TextQueryByDocument = "
	|	%DocumentName%.%AttributeName% AS %AttributeName%
	|FROM
	|	Document.%DocumentName% AS %DocumentName%
	|WHERE
	|	%DocumentName%.Ref IN(&DocumentsList%DocumentName%)";
	
	TextQueryByDocument = StrReplace(TextQueryByDocument, "%AttributeName%", AttributeName);
	
	For Each KeyAndValue In TypesStructure Do
		
		If IsDocumentAttribute(AttributeName, KeyAndValue.Key) Then
			
			DocumentName = KeyAndValue.Key.Name;
			
			If ValueIsFilled(QueryText) Then
				
				QueryText = QueryText+"
				|UNION
				|
				|SELECT DISTINCT";
				
			Else
				
				QueryText = "SELECT ALLOWED DISTINCT";
				
			EndIf;
			
			QueryText = QueryText + StrReplace(TextQueryByDocument, "%DocumentName%", DocumentName);
			
			Query.SetParameter("DocumentsList"+DocumentName, KeyAndValue.Value);
			
		EndIf; 
		
	EndDo; 
	
	If IsBlankString(QueryText) Then
	
		Return Undefined;
	
	EndIf; 
	
	Query.Text = QueryText;
	Result = Query.Execute();
	
	If Not Result.IsEmpty() Then
		
		Selection = Result.Select();
		
		If Selection.Count() = 1 Then
			
			If Selection.Next() Then
				Return AllowedTypeDescription.AdjustValue(Selection[AttributeName]);
			EndIf;
			
		EndIf;
		
	EndIf;
	
	Return Undefined;
	
EndFunction

//////////////////////////////////////////////////////////////////////////////// 
// General module CommonUse does not support "Server call" any more.
// Corrections and support of a new behavior
//

// Replaces
// call CommonUse.ObjectAttributeValue from the Add() procedure of the Price-list processor form
//
Function ReadAttributeValue_Owner(ObjectOrRef) Export
	
	Return CommonUse.ObjectAttributeValue(ObjectOrRef, "Owner");
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsExchangeRatesDifference

// Function returns a flag showing that rate differences are required.
//
Function GetNeedToCalculateExchangeDifferences(TempTablesManager, PaymentsTemporaryTableName)
	
	CalculateCurrencyDifference = Constants.ForeignExchangeAccounting.Get();
	
	If CalculateCurrencyDifference Then
		QueryText =
		"SELECT DISTINCT
		|	TableAccounts.Currency AS Currency
		|FROM
		|	%TemporaryTableSettlements% AS TableAccounts
		|WHERE
		|	TableAccounts.Currency <> &PresentationCurrency";
		QueryText = StrReplace(QueryText, "%TemporaryTableSettlements%", PaymentsTemporaryTableName);
		Query = New Query();
		Query.Text = QueryText;
		Query.TempTablesManager = TempTablesManager;
		Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
		CalculateCurrencyDifference = Not Query.Execute().IsEmpty();
	EndIf;
	
	If CalculateCurrencyDifference Then
		ForeignCurrencyRevaluationPeriodicity = Constants.ForeignCurrencyRevaluationPeriodicity.Get();
		If ForeignCurrencyRevaluationPeriodicity = Enums.ForeignCurrencyRevaluationPeriodicity.DuringOpertionExecution Then
			CalculateCurrencyDifference = True;
		Else
			CalculateCurrencyDifference = False;
		EndIf;
	EndIf;
	
	Return CalculateCurrencyDifference;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRatesDifferencesAccountsPayable(TempTablesManager, WithAdvanceOffset, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableAccountsPayable");
	
	If Not CalculateCurrencyDifference Then
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayable
		|FROM
		|	TemporaryTableAccountsPayable AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	DocumentTable.AmountForPayment AS AmountForPayment,
		|	DocumentTable.AmountForPaymentCur AS AmountForPaymentCur
		|FROM
		|	TemporaryTableAccountsPayable AS DocumentTable
		|
		|ORDER BY
		|	DocumentTable.ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType";
	
	ElsIf WithAdvanceOffset Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsPayable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsPayable.Balance(
		|				&PointInTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Company,
		|						TemporaryTableAccountsPayable.Counterparty,
		|						TemporaryTableAccountsPayable.Contract,
		|						TemporaryTableAccountsPayable.Document,
		|						TemporaryTableAccountsPayable.Order,
		|						TemporaryTableAccountsPayable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsPayable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary
		|FROM
		|	TemporaryTableAccountsPayable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Contract.SettlementsCurrency
		|					FROM
		|						TemporaryTableAccountsPayable)) AS CalculationExchangeRatesSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
		|WHERE
		|	(TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) = 0)
		|	AND (ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordTable.Period AS Period,
		|	RegisterRecordTable.RecordType AS RecordType,
		|	RegisterRecordTable.Company AS Company,
		|	RegisterRecordTable.Counterparty AS Counterparty,
		|	RegisterRecordTable.Contract AS Contract,
		|	RegisterRecordTable.Document AS Document,
		|	RegisterRecordTable.Order AS Order,
		|	RegisterRecordTable.SettlementsType AS SettlementsType,
		|	RegisterRecordTable.Currency AS Currency,
		|	SUM(RegisterRecordTable.Amount) AS Amount,
		|	SUM(RegisterRecordTable.AmountCur) AS AmountCur,
		|	RegisterRecordTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Period,
		|		DocumentTable.RecordType AS RecordType,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.Amount AS Amount,
		|		DocumentTable.AmountCur AS AmountCur,
		|		DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|	FROM
		|		TemporaryTableAccountsPayable AS DocumentTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Expense),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		CASE
		|			WHEN DocumentTable.DoOperationsByDocuments
		|				THEN &Ref
		|			ELSE UNDEFINED
		|		END,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		CASE
		|			WHEN DocumentTable.DoOperationsByDocuments
		|				THEN &Ref
		|			ELSE UNDEFINED
		|		END,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS RegisterRecordTable
		|
		|GROUP BY
		|	RegisterRecordTable.Period,
		|	RegisterRecordTable.Company,
		|	RegisterRecordTable.Counterparty,
		|	RegisterRecordTable.Contract,
		|	RegisterRecordTable.Document,
		|	RegisterRecordTable.Order,
		|	RegisterRecordTable.SettlementsType,
		|	RegisterRecordTable.Currency,
		|	RegisterRecordTable.ContentOfAccountingRecord,
		|	RegisterRecordTable.RecordType
		|
		|HAVING
		|	(SUM(RegisterRecordTable.Amount) >= 0.005
		|		OR SUM(RegisterRecordTable.Amount) <= -0.005
		|		OR SUM(RegisterRecordTable.AmountCur) >= 0.005
		|		OR SUM(RegisterRecordTable.AmountCur) <= -0.005)
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCurrencyDifferences.Company AS Company,
		|	TableCurrencyDifferences.Counterparty AS Counterparty,
		|	TableCurrencyDifferences.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	TableCurrencyDifferences.Contract AS Contract,
		|	TableCurrencyDifferences.Document AS Document,
		|	TableCurrencyDifferences.Order AS Order,
		|	TableCurrencyDifferences.SettlementsType AS SettlementsType,
		|	SUM(TableCurrencyDifferences.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences,
		|	TableCurrencyDifferences.Currency AS Currency,
		|	TableCurrencyDifferences.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayable
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Date,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.GLAccount AS GLAccount,
		|		DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.DoOperationsByDocuments,
		|		DocumentTable.Contract,
		|		CASE
		|			WHEN DocumentTable.DoOperationsByDocuments
		|				THEN &Ref
		|			ELSE UNDEFINED
		|		END,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.Counterparty.GLAccountVendorSettlements,
		|		DocumentTable.AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableCurrencyDifferences
		|
		|GROUP BY
		|	TableCurrencyDifferences.Company,
		|	TableCurrencyDifferences.Counterparty,
		|	TableCurrencyDifferences.DoOperationsByDocuments,
		|	TableCurrencyDifferences.Contract,
		|	TableCurrencyDifferences.Document,
		|	TableCurrencyDifferences.Order,
		|	TableCurrencyDifferences.SettlementsType,
		|	TableCurrencyDifferences.Currency,
		|	TableCurrencyDifferences.GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableOfExchangeRateDifferencesAccountsPayablePrelimenary";
		
	Else
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsPayable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsPayable.Balance(
		|				&PointInTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Company,
		|						TemporaryTableAccountsPayable.Counterparty,
		|						TemporaryTableAccountsPayable.Contract,
		|						TemporaryTableAccountsPayable.Document,
		|						TemporaryTableAccountsPayable.Order,
		|						TemporaryTableAccountsPayable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsPayable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsPayable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountVendorSettlements
		|		ELSE AccountsBalances.Counterparty.VendorAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableOfExchangeRateDifferencesAccountsPayable
		|FROM
		|	TemporaryTableAccountsPayable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsPayable.Currency
		|					FROM
		|						TemporaryTableAccountsPayable)) AS CalculationExchangeRatesSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
		|WHERE
		|	TableAccounts.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	AND (ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Priority,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	DocumentTable.ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAccountsPayable AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	DocumentTable.Date,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Company,
		|	DocumentTable.Counterparty,
		|	DocumentTable.Contract,
		|	DocumentTable.Document,
		|	DocumentTable.Order,
		|	DocumentTable.SettlementsType,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableOfExchangeRateDifferencesAccountsPayable AS DocumentTable
		|
		|ORDER BY
		|	Priority,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextCurrencyExchangeRateAccountsReceivable(TempTablesManager, WithAdvanceOffset, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableAccountsReceivable");
	
	If Not CalculateCurrencyDifference Then
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivable
		|FROM
		|	TemporaryTableAccountsReceivable AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.AmountForPayment AS AmountForPayment,
		|	DocumentTable.AmountForPaymentCur AS AmountForPaymentCur,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAccountsReceivable AS DocumentTable
		|
		|ORDER BY
		|	DocumentTable.ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType";
	
	ElsIf WithAdvanceOffset Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsReceivable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsReceivable.Balance(
		|				&PointInTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Company,
		|						TemporaryTableAccountsReceivable.Counterparty,
		|						TemporaryTableAccountsReceivable.Contract,
		|						TemporaryTableAccountsReceivable.Document,
		|						TemporaryTableAccountsReceivable.Order,
		|						TemporaryTableAccountsReceivable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary
		|FROM
		|	TemporaryTableAccountsReceivable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Contract.SettlementsCurrency
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS CalculationExchangeRatesSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
		|WHERE
		|	(TableBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) = 0)
		|	AND (ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordTable.Period AS Period,
		|	RegisterRecordTable.RecordType AS RecordType,
		|	RegisterRecordTable.Company AS Company,
		|	RegisterRecordTable.Counterparty AS Counterparty,
		|	RegisterRecordTable.Contract AS Contract,
		|	RegisterRecordTable.Document AS Document,
		|	RegisterRecordTable.Order AS Order,
		|	RegisterRecordTable.SettlementsType AS SettlementsType,
		|	RegisterRecordTable.Currency AS Currency,
		|	SUM(RegisterRecordTable.Amount) AS Amount,
		|	SUM(RegisterRecordTable.AmountCur) AS AmountCur,
		|	RegisterRecordTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Period,
		|		DocumentTable.RecordType AS RecordType,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.Amount AS Amount,
		|		DocumentTable.AmountCur AS AmountCur,
		|		DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|	FROM
		|		TemporaryTableAccountsReceivable AS DocumentTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		DocumentTable.Document,
		|		DocumentTable.Order,
		|		DocumentTable.SettlementsType,
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Expense),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		CASE
		|			WHEN DocumentTable.DoOperationsByDocuments
		|				THEN &Ref
		|			ELSE UNDEFINED
		|		END,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&AdvanceCredit AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		VALUE(AccumulationRecordType.Receipt),
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.Contract,
		|		CASE
		|			WHEN DocumentTable.DoOperationsByDocuments
		|				THEN &Ref
		|			ELSE UNDEFINED
		|		END,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.AmountOfExchangeDifferences,
		|		0,
		|		CAST(&ExchangeDifference AS String(100))
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS RegisterRecordTable
		|
		|GROUP BY
		|	RegisterRecordTable.Period,
		|	RegisterRecordTable.Company,
		|	RegisterRecordTable.Counterparty,
		|	RegisterRecordTable.Contract,
		|	RegisterRecordTable.Document,
		|	RegisterRecordTable.Order,
		|	RegisterRecordTable.SettlementsType,
		|	RegisterRecordTable.Currency,
		|	RegisterRecordTable.ContentOfAccountingRecord,
		|	RegisterRecordTable.RecordType
		|
		|HAVING
		|	(SUM(RegisterRecordTable.Amount) >= 0.005
		|		OR SUM(RegisterRecordTable.Amount) <= -0.005
		|		OR SUM(RegisterRecordTable.AmountCur) >= 0.005
		|		OR SUM(RegisterRecordTable.AmountCur) <= -0.005)
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	Document,
		|	Order,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCurrencyDifferences.Company AS Company,
		|	TableCurrencyDifferences.Counterparty AS Counterparty,
		|	TableCurrencyDifferences.DoOperationsByDocuments AS DoOperationsByDocuments,
		|	TableCurrencyDifferences.Contract AS Contract,
		|	TableCurrencyDifferences.Document AS Document,
		|	TableCurrencyDifferences.Order AS Order,
		|	TableCurrencyDifferences.SettlementsType AS SettlementsType,
		|	SUM(TableCurrencyDifferences.AmountOfExchangeDifferences) AS AmountOfExchangeDifferences,
		|	TableCurrencyDifferences.Currency AS Currency,
		|	TableCurrencyDifferences.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivable
		|FROM
		|	(SELECT
		|		DocumentTable.Date AS Date,
		|		DocumentTable.Company AS Company,
		|		DocumentTable.Counterparty AS Counterparty,
		|		DocumentTable.DoOperationsByDocuments AS DoOperationsByDocuments,
		|		DocumentTable.Contract AS Contract,
		|		DocumentTable.Document AS Document,
		|		DocumentTable.Order AS Order,
		|		DocumentTable.SettlementsType AS SettlementsType,
		|		DocumentTable.Currency AS Currency,
		|		DocumentTable.GLAccount AS GLAccount,
		|		DocumentTable.AmountOfExchangeDifferences AS AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentTable.Date,
		|		DocumentTable.Company,
		|		DocumentTable.Counterparty,
		|		DocumentTable.DoOperationsByDocuments,
		|		DocumentTable.Contract,
		|		CASE
		|			WHEN DocumentTable.DoOperationsByDocuments
		|				THEN &Ref
		|			ELSE UNDEFINED
		|		END,
		|		DocumentTable.Order,
		|		VALUE(Enum.SettlementsTypes.Debt),
		|		DocumentTable.Currency,
		|		DocumentTable.Counterparty.GLAccountCustomerSettlements,
		|		DocumentTable.AmountOfExchangeDifferences
		|	FROM
		|		TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary AS DocumentTable
		|	WHERE
		|		DocumentTable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS TableCurrencyDifferences
		|
		|GROUP BY
		|	TableCurrencyDifferences.Company,
		|	TableCurrencyDifferences.Counterparty,
		|	TableCurrencyDifferences.DoOperationsByDocuments,
		|	TableCurrencyDifferences.Contract,
		|	TableCurrencyDifferences.Document,
		|	TableCurrencyDifferences.Order,
		|	TableCurrencyDifferences.SettlementsType,
		|	TableCurrencyDifferences.Currency,
		|	TableCurrencyDifferences.GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableExchangeRateDifferencesAccountsReceivablePrelimenary";
		
	Else
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.Counterparty AS Counterparty,
		|	AccountsBalances.Contract AS Contract,
		|	AccountsBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Order AS Order,
		|	AccountsBalances.SettlementsType AS SettlementsType,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.Counterparty AS Counterparty,
		|		TemporaryTable.Contract AS Contract,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.Order AS Order,
		|		TemporaryTable.SettlementsType AS SettlementsType,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAccountsReceivable AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.Counterparty,
		|		TableBalances.Contract,
		|		TableBalances.Document,
		|		TableBalances.Order,
		|		TableBalances.SettlementsType,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AccountsReceivable.Balance(
		|				&PointInTime,
		|				(Company, Counterparty, Contract, Document, Order, SettlementsType) In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Company,
		|						TemporaryTableAccountsReceivable.Counterparty,
		|						TemporaryTableAccountsReceivable.Contract,
		|						TemporaryTableAccountsReceivable.Document,
		|						TemporaryTableAccountsReceivable.Order,
		|						TemporaryTableAccountsReceivable.SettlementsType
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.Counterparty,
		|		DocumentRegisterRecords.Contract,
		|		DocumentRegisterRecords.Document,
		|		DocumentRegisterRecords.Order,
		|		DocumentRegisterRecords.SettlementsType,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AccountsReceivable AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.Counterparty,
		|	AccountsBalances.Contract,
		|	AccountsBalances.Document,
		|	AccountsBalances.Order,
		|	AccountsBalances.SettlementsType,
		|	AccountsBalances.Contract.SettlementsCurrency,
		|	CASE
		|		WHEN AccountsBalances.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|			THEN AccountsBalances.Counterparty.GLAccountCustomerSettlements
		|		ELSE AccountsBalances.Counterparty.CustomerAdvancesGLAccount
		|	END
		|
		|INDEX BY
		|	Company,
		|	Counterparty,
		|	Contract,
		|	SettlementsCurrency,
		|	Document,
		|	Order,
		|	SettlementsType,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Counterparty AS Counterparty,
		|	TableAccounts.Contract AS Contract,
		|	TableAccounts.Document AS Document,
		|	TableAccounts.Order AS Order,
		|	TableAccounts.SettlementsType AS SettlementsType,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateDifferencesAccountsReceivable
		|FROM
		|	TemporaryTableAccountsReceivable AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.Counterparty = TableBalances.Counterparty
		|			AND TableAccounts.Contract = TableBalances.Contract
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.Order = TableBalances.Order
		|			AND TableAccounts.SettlementsType = TableBalances.SettlementsType
		|			AND TableAccounts.Currency = TableBalances.SettlementsCurrency
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAccountsReceivable.Currency
		|					FROM
		|						TemporaryTableAccountsReceivable)) AS CalculationExchangeRatesSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
		|WHERE
		|	TableAccounts.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)
		|	AND (ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Priority,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Counterparty AS Counterparty,
		|	DocumentTable.Contract AS Contract,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Order AS Order,
		|	DocumentTable.SettlementsType AS SettlementsType,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	DocumentTable.ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAccountsReceivable AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	DocumentTable.Date,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Company,
		|	DocumentTable.Counterparty,
		|	DocumentTable.Contract,
		|	DocumentTable.Document,
		|	DocumentTable.Order,
		|	DocumentTable.SettlementsType,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeRateDifferencesAccountsReceivable AS DocumentTable
		|
		|ORDER BY
		|	Priority,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesCashAssets(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableCashAssets");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	FundsBalance.Company AS Company,
		|	FundsBalance.CashAssetsType AS CashAssetsType,
		|	FundsBalance.BankAccountPettyCash AS BankAccountPettyCash,
		|	FundsBalance.Currency AS Currency,
		|	FundsBalance.BankAccountPettyCash.GLAccount AS GLAccount,
		|	SUM(FundsBalance.AmountBalance) AS AmountBalance,
		|	SUM(FundsBalance.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.CashAssetsType AS CashAssetsType,
		|		TemporaryTable.BankAccountPettyCash AS BankAccountPettyCash,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableCashAssets AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.CashAssetsType,
		|		TableBalances.BankAccountPettyCash,
		|		TableBalances.Currency,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.CashAssets.Balance(
		|				&PointInTime,
		|				(Company, CashAssetsType, BankAccountPettyCash, Currency) In
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssets.Company,
		|						TemporaryTableCashAssets.CashAssetsType,
		|						TemporaryTableCashAssets.BankAccountPettyCash,
		|						TemporaryTableCashAssets.Currency
		|					FROM
		|						TemporaryTableCashAssets)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.CashAssetsType,
		|		DocumentRegisterRecords.BankAccountPettyCash,
		|		DocumentRegisterRecords.Currency,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.CashAssets AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS FundsBalance
		|
		|GROUP BY
		|	FundsBalance.Company,
		|	FundsBalance.CashAssetsType,
		|	FundsBalance.BankAccountPettyCash,
		|	FundsBalance.Currency,
		|	FundsBalance.BankAccountPettyCash.GLAccount
		|
		|INDEX BY
		|	Company,
		|	CashAssetsType,
		|	BankAccountPettyCash,
		|	Currency,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.CashAssetsType AS CashAssetsType,
		|	TableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesBanking
		|FROM
		|	TemporaryTableCashAssets AS TableCashAssets
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableCashAssets.Company = TableBalances.Company
		|			AND TableCashAssets.CashAssetsType = TableBalances.CashAssetsType
		|			AND TableCashAssets.BankAccountPettyCash = TableBalances.BankAccountPettyCash
		|			AND TableCashAssets.Currency = TableBalances.Currency
		|			AND TableCashAssets.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssets.Currency
		|					FROM
		|						TemporaryTableCashAssets)) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
		|		ON TableCashAssets.Currency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
		|WHERE
		|	(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashAssetsType AS CashAssetsType,
		|	DocumentTable.Item AS Item,
		|	DocumentTable.BankAccountPettyCash AS BankAccountPettyCash,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssets AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.CashAssetsType,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(Catalog.CashFlowItems.PositiveExchangeDifference)
		|		ELSE VALUE(Catalog.CashFlowItems.NegativeExchangeDifference)
		|	END,
		|	DocumentTable.BankAccountPettyCash,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	DocumentTable.Currency,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeRateLossesBanking AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.CashAssetsType AS CashAssetsType,
		|	TableCashAssets.BankAccountPettyCash AS BankAccountPettyCash,
		|	0 AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesBanking
		|FROM
		|	TemporaryTableCashAssets AS TableCashAssets
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.CashAssetsType AS CashAssetsType,
		|	DocumentTable.Item AS Item,
		|	DocumentTable.BankAccountPettyCash AS BankAccountPettyCash,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssets AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType";
	
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesCashInCashRegisters(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableCashAssetsInRetailCashes");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	FundsBalance.Company AS Company,
		|	FundsBalance.CashCR AS CashCR,
		|	FundsBalance.CashCR.GLAccount AS GLAccount,
		|	FundsBalance.Currency AS Currency,
		|	SUM(FundsBalance.AmountBalance) AS AmountBalance,
		|	SUM(FundsBalance.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.CashCR AS CashCR,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableCashAssetsInRetailCashes AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.CashCR,
		|		TableBalances.CashCR.CashCurrency,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.CashInCashRegisters.Balance(
		|				&PointInTime,
		|				(Company, CashCR) In
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssetsInRetailCashes.Company,
		|						TemporaryTableCashAssetsInRetailCashes.CashCR
		|					FROM
		|						TemporaryTableCashAssetsInRetailCashes)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.CashCR,
		|		DocumentRegisterRecords.CashCR.CashCurrency,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.CashInCashRegisters AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS FundsBalance
		|
		|GROUP BY
		|	FundsBalance.Company,
		|	FundsBalance.CashCR,
		|	FundsBalance.Currency,
		|	FundsBalance.CashCR.GLAccount
		|
		|INDEX BY
		|	Company,
		|	CashCR,
		|	Currency,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.CashCR AS CashCR,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesCashAssetsInRetailCashes
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS TableCashAssets
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableCashAssets.Company = TableBalances.Company
		|			AND TableCashAssets.CashCR = TableBalances.CashCR
		|			AND TableCashAssets.Currency = TableBalances.Currency
		|			AND TableCashAssets.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableCashAssetsInRetailCashes.Currency
		|					FROM
		|						TemporaryTableCashAssetsInRetailCashes)) AS CurrencyExchangeRatesBankAccountPettyCashSliceLast
		|		ON TableCashAssets.Currency = CurrencyExchangeRatesBankAccountPettyCashSliceLast.Currency
		|WHERE
		|	(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRatesBankAccountPettyCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRatesBankAccountPettyCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.CashCR AS CashCR,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.Currency,
		|	DocumentTable.CashCR,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeRateLossesCashAssetsInRetailCashes AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
	
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableCashAssets.Company AS Company,
		|	TableCashAssets.CashCR AS CashCR,
		|	0 AS AmountOfExchangeDifferences,
		|	TableCashAssets.Currency AS Currency,
		|	TableCashAssets.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeRateLossesCashAssetsInRetailCashes
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS TableCashAssets
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.CashCR AS CashCR,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableCashAssetsInRetailCashes AS DocumentTable
		|
		|ORDER BY
		|	ContentOfAccountingRecord,
		|	RecordType";
	
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextCurrencyExchangeRateAdvanceHolders(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTableAdvanceHolders");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.Employee AS Employee,
		|	AccountsBalances.Currency AS Currency,
		|	AccountsBalances.Document AS Document,
		|	AccountsBalances.Employee.AdvanceHoldersGLAccount AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.Employee AS Employee,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.Document AS Document,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTableAdvanceHolders AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.Employee,
		|		TableBalances.Currency,
		|		TableBalances.Document,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.AdvanceHolders.Balance(
		|				&PointInTime,
		|				(Company, Employee, Currency, Document) In
		|					(SELECT DISTINCT
		|						TemporaryTableAdvanceHolders.Company,
		|						TemporaryTableAdvanceHolders.Employee,
		|						TemporaryTableAdvanceHolders.Currency,
		|						TemporaryTableAdvanceHolders.Document
		|					FROM
		|						TemporaryTableAdvanceHolders)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.Employee,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.Document,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.AdvanceHolders AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.Employee,
		|	AccountsBalances.Currency,
		|	AccountsBalances.Document,
		|	AccountsBalances.Employee.AdvanceHoldersGLAccount
		|
		|INDEX BY
		|	Company,
		|	Employee,
		|	Currency,
		|	Document,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.Document AS Document,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
		|FROM
		|	TemporaryTableAdvanceHolders AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.Employee = TableBalances.Employee
		|			AND TableAccounts.Currency = TableBalances.Currency
		|			AND TableAccounts.Document = TableBalances.Document
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTableAdvanceHolders.Currency
		|					FROM
		|						TemporaryTableAdvanceHolders)) AS CalculationExchangeRatesSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
		|WHERE
		|	(ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAdvanceHolders AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Document,
		|	DocumentTable.Employee,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.Currency,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.Document AS Document,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesCalculationWithAdvanceHolder
		|FROM
		|	TemporaryTableAdvanceHolders AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Document AS Document,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTableAdvanceHolders AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesPayroll(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTablePayroll");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	AccountsBalances.Company AS Company,
		|	AccountsBalances.StructuralUnit AS StructuralUnit,
		|	AccountsBalances.Employee AS Employee,
		|	AccountsBalances.Currency AS Currency,
		|	AccountsBalances.RegistrationPeriod AS RegistrationPeriod,
		|	AccountsBalances.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
		|	SUM(AccountsBalances.AmountBalance) AS AmountBalance,
		|	SUM(AccountsBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.StructuralUnit AS StructuralUnit,
		|		TemporaryTable.Employee AS Employee,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.RegistrationPeriod AS RegistrationPeriod,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTablePayroll AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.StructuralUnit,
		|		TableBalances.Employee,
		|		TableBalances.Currency,
		|		TableBalances.RegistrationPeriod,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.Payroll.Balance(
		|				&PointInTime,
		|				(Company, StructuralUnit, Employee, Currency, RegistrationPeriod) In
		|					(SELECT DISTINCT
		|						TemporaryTablePayroll.Company,
		|						TemporaryTablePayroll.StructuralUnit,
		|						TemporaryTablePayroll.Employee,
		|						TemporaryTablePayroll.Currency,
		|						TemporaryTablePayroll.RegistrationPeriod
		|					FROM
		|						TemporaryTablePayroll)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.StructuralUnit,
		|		DocumentRegisterRecords.Employee,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.RegistrationPeriod,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Payroll AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS AccountsBalances
		|
		|GROUP BY
		|	AccountsBalances.Company,
		|	AccountsBalances.StructuralUnit,
		|	AccountsBalances.Employee,
		|	AccountsBalances.Currency,
		|	AccountsBalances.RegistrationPeriod,
		|	AccountsBalances.Employee.SettlementsHumanResourcesGLAccount
		|
		|INDEX BY
		|	Company,
		|	StructuralUnit,
		|	Employee,
		|	Currency,
		|	RegistrationPeriod,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.StructuralUnit AS StructuralUnit,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.RegistrationPeriod AS RegistrationPeriod,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesPayroll
		|FROM
		|	TemporaryTablePayroll AS TableAccounts
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TableAccounts.Company = TableBalances.Company
		|			AND TableAccounts.StructuralUnit = TableBalances.StructuralUnit
		|			AND TableAccounts.Employee = TableBalances.Employee
		|			AND TableAccounts.Currency = TableBalances.Currency
		|			AND TableAccounts.RegistrationPeriod = TableBalances.RegistrationPeriod
		|			AND TableAccounts.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency In
		|					(SELECT DISTINCT
		|						TemporaryTablePayroll.Currency
		|					FROM
		|						TemporaryTablePayroll)) AS CalculationExchangeRatesSliceLast
		|		ON TableAccounts.Currency = CalculationExchangeRatesSliceLast.Currency
		|WHERE
		|	(ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CalculationExchangeRatesSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CalculationExchangeRatesSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.RegistrationPeriod AS RegistrationPeriod,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTablePayroll AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	DocumentTable.Date,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Company,
		|	DocumentTable.StructuralUnit,
		|	DocumentTable.Employee,
		|	DocumentTable.Currency,
		|	DocumentTable.RegistrationPeriod,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	DocumentTable.GLAccount,
		|	&ExchangeDifference
		|FROM
		|	TemporaryTableExchangeDifferencesPayroll AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
	
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TableAccounts.Company AS Company,
		|	TableAccounts.StructuralUnit AS StructuralUnit,
		|	TableAccounts.Employee AS Employee,
		|	TableAccounts.Currency AS Currency,
		|	TableAccounts.RegistrationPeriod AS RegistrationPeriod,
		|	0 AS AmountOfExchangeDifferences,
		|	TableAccounts.GLAccount AS GLAccount
		|INTO TemporaryTableExchangeDifferencesPayroll
		|FROM
		|	TemporaryTablePayroll AS TableAccounts
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Employee AS Employee,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.RegistrationPeriod AS RegistrationPeriod,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.GLAccount AS GLAccount,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord
		|FROM
		|	TemporaryTablePayroll AS DocumentTable
		|
		|ORDER BY
		|	Order,
		|	LineNumber";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

// Function returns query text for exchange rates differences calculation.
//
Function GetQueryTextExchangeRateDifferencesPOSSummary(TempTablesManager, QueryNumber) Export
	
	CalculateCurrencyDifference = GetNeedToCalculateExchangeDifferences(TempTablesManager, "TemporaryTablePOSSummary");
	
	If CalculateCurrencyDifference Then
		
		QueryNumber = 2;
		
		QueryText =
		"SELECT
		|	POSSummaryBalances.Company AS Company,
		|	POSSummaryBalances.StructuralUnit AS StructuralUnit,
		|	POSSummaryBalances.GLAccount AS GLAccount,
		|	POSSummaryBalances.Currency AS Currency,
		|	SUM(POSSummaryBalances.AmountBalance) AS AmountBalance,
		|	SUM(POSSummaryBalances.AmountCurBalance) AS AmountCurBalance
		|INTO TemporaryTableBalancesAfterPosting
		|FROM
		|	(SELECT
		|		TemporaryTable.Company AS Company,
		|		TemporaryTable.StructuralUnit AS StructuralUnit,
		|		TemporaryTable.Currency AS Currency,
		|		TemporaryTable.GLAccount AS GLAccount,
		|		TemporaryTable.AmountForBalance AS AmountBalance,
		|		TemporaryTable.AmountCurForBalance AS AmountCurBalance
		|	FROM
		|		TemporaryTablePOSSummary AS TemporaryTable
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		TableBalances.Company,
		|		TableBalances.StructuralUnit,
		|		TableBalances.Currency,
		|		TableBalances.StructuralUnit.GLAccountInRetail,
		|		ISNULL(TableBalances.AmountBalance, 0),
		|		ISNULL(TableBalances.AmountCurBalance, 0)
		|	FROM
		|		AccumulationRegister.POSSummary.Balance(
		|				&PointInTime,
		|				(Company, StructuralUnit, Currency) IN
		|					(SELECT DISTINCT
		|						TemporaryTablePOSSummary.Company,
		|						TemporaryTablePOSSummary.StructuralUnit,
		|						TemporaryTablePOSSummary.Currency
		|					FROM
		|						TemporaryTablePOSSummary)) AS TableBalances
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecords.Company,
		|		DocumentRegisterRecords.StructuralUnit,
		|		DocumentRegisterRecords.Currency,
		|		DocumentRegisterRecords.StructuralUnit.GLAccountInRetail,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.Amount, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.Amount, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecords.RecordType = VALUE(AccumulationRecordType.Receipt)
		|				THEN -ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|			ELSE ISNULL(DocumentRegisterRecords.AmountCur, 0)
		|		END
		|	FROM
		|		AccumulationRegister.POSSummary AS DocumentRegisterRecords
		|	WHERE
		|		DocumentRegisterRecords.Recorder = &Ref
		|		AND DocumentRegisterRecords.Period <= &ControlPeriod) AS POSSummaryBalances
		|
		|GROUP BY
		|	POSSummaryBalances.Company,
		|	POSSummaryBalances.StructuralUnit,
		|	POSSummaryBalances.Currency,
		|	POSSummaryBalances.GLAccount
		|
		|INDEX BY
		|	Company,
		|	StructuralUnit,
		|	Currency,
		|	GLAccount
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TablePOSSummary.Company AS Company,
		|	TablePOSSummary.StructuralUnit AS StructuralUnit,
		|	ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) AS AmountOfExchangeDifferences,
		|	TablePOSSummary.Currency AS Currency,
		|	TablePOSSummary.GLAccount AS GLAccount
		|INTO TemporaryTableCurrencyExchangeRateDifferencesPOSSummary
		|FROM
		|	TemporaryTablePOSSummary AS TablePOSSummary
		|		LEFT JOIN TemporaryTableBalancesAfterPosting AS TableBalances
		|		ON TablePOSSummary.Company = TableBalances.Company
		|			AND TablePOSSummary.StructuralUnit = TableBalances.StructuralUnit
		|			AND TablePOSSummary.Currency = TableBalances.Currency
		|			AND TablePOSSummary.GLAccount = TableBalances.GLAccount
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT
		|						ConstantAccountingCurrency.Value
		|					FROM
		|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
		|		ON (TRUE)
		|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
		|				&PointInTime,
		|				Currency IN
		|					(SELECT DISTINCT
		|						TemporaryTablePOSSummary.Currency
		|					FROM
		|						TemporaryTablePOSSummary)) AS CurrencyExchangeRateCashSliceLast
		|		ON TablePOSSummary.Currency = CurrencyExchangeRateCashSliceLast.Currency
		|WHERE
		|	(ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) >= 0.005
		|			OR ISNULL(TableBalances.AmountCurBalance, 0) * CurrencyExchangeRateCashSliceLast.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * CurrencyExchangeRateCashSliceLast.Multiplicity) - ISNULL(TableBalances.AmountBalance, 0) <= -0.005)
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.Cost AS Cost,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTablePOSSummary AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	DocumentTable.LineNumber,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN VALUE(AccumulationRecordType.Receipt)
		|		ELSE VALUE(AccumulationRecordType.Expense)
		|	END,
		|	DocumentTable.Date,
		|	DocumentTable.Company,
		|	DocumentTable.StructuralUnit,
		|	DocumentTable.Currency,
		|	CASE
		|		WHEN DocumentTable.AmountOfExchangeDifferences > 0
		|			THEN DocumentTable.AmountOfExchangeDifferences
		|		ELSE -DocumentTable.AmountOfExchangeDifferences
		|	END,
		|	0,
		|	0,
		|	&ExchangeDifference,
		|	FALSE
		|FROM
		|	TemporaryTableCurrencyExchangeRateDifferencesPOSSummary AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	3,
		|	OfflineRecords.LineNumber,
		|	OfflineRecords.RecordType,
		|	OfflineRecords.Period,
		|	OfflineRecords.Company,
		|	OfflineRecords.StructuralUnit,
		|	OfflineRecords.Currency,
		|	OfflineRecords.Amount,
		|	OfflineRecords.AmountCur,
		|	OfflineRecords.Cost,
		|	OfflineRecords.ContentOfAccountingRecord,
		|	OfflineRecords.OfflineRecord
		|FROM
		|	AccumulationRegister.POSSummary AS OfflineRecords
		|WHERE
		|	OfflineRecords.Recorder = &Ref
		|	AND OfflineRecords.OfflineRecord
		|
		|ORDER BY
		|	Order,
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|DROP TemporaryTableBalancesAfterPosting";
		
	Else
		
		QueryNumber = 1;
		
		QueryText =
		"SELECT DISTINCT
		|	1 AS LineNumber,
		|	&ControlPeriod AS Date,
		|	TablePOSSummary.Company AS Company,
		|	TablePOSSummary.StructuralUnit AS StructuralUnit,
		|	0 AS AmountOfExchangeDifferences,
		|	TablePOSSummary.Currency AS Currency,
		|	TablePOSSummary.GLAccount AS GLAccount
		|INTO TemporaryTableCurrencyExchangeRateDifferencesPOSSummary
		|FROM
		|	TemporaryTablePOSSummary AS TablePOSSummary
		|WHERE
		|	FALSE
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	1 AS Order,
		|	DocumentTable.LineNumber AS LineNumber,
		|	DocumentTable.RecordType AS RecordType,
		|	DocumentTable.Date AS Period,
		|	DocumentTable.Company AS Company,
		|	DocumentTable.StructuralUnit AS StructuralUnit,
		|	DocumentTable.Currency AS Currency,
		|	DocumentTable.Amount AS Amount,
		|	DocumentTable.AmountCur AS AmountCur,
		|	DocumentTable.Cost AS Cost,
		|	DocumentTable.ContentOfAccountingRecord AS ContentOfAccountingRecord,
		|	FALSE AS OfflineRecord
		|FROM
		|	TemporaryTablePOSSummary AS DocumentTable
		|
		|UNION ALL
		|
		|SELECT
		|	2,
		|	OfflineRecords.LineNumber,
		|	OfflineRecords.RecordType,
		|	OfflineRecords.Period,
		|	OfflineRecords.Company,
		|	OfflineRecords.StructuralUnit,
		|	OfflineRecords.Currency,
		|	OfflineRecords.Amount,
		|	OfflineRecords.AmountCur,
		|	OfflineRecords.Cost,
		|	OfflineRecords.ContentOfAccountingRecord,
		|	OfflineRecords.OfflineRecord
		|FROM
		|	AccumulationRegister.POSSummary AS OfflineRecords
		|WHERE
		|	OfflineRecords.Recorder = &Ref
		|	AND OfflineRecords.OfflineRecord
		|
		|ORDER BY
		|	Order,
		|	LineNumber";
		
	EndIf;
	
	Return QueryText;
	
EndFunction

#EndRegion

#Region SslSubsystemHelperProceduresAndFunctions

// Function clears separated data created during the first start.
// Used before the data import from service.
//
Function ClearDataInDatabase() Export
	
	If Not Users.InfobaseUserWithFullAccess(, True) Then
		Raise(NStr("en = 'Insufficient rights to perform the operation'"));
	EndIf;
	
	SetPrivilegedMode(True);
	
	Try
		CommonUse.LockInfobase();
	Except
		Message = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Cannot set the exclusive mode (%1)'"),
			BriefErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	BeginTransaction();
	Try
		
		CommonAttributeMD = Metadata.CommonAttributes.DataAreaBasicData;
		
		// Traverse all metadata
		
		// Constants
		For Each MetadataConstants In Metadata.Constants Do
			If Not CommonUse.IsSeparatedMetadataObject(MetadataConstants, CommonUseReUse.MainDataSeparator()) Then
				Continue;
			EndIf;
			
			ValueManager = Constants[MetadataConstants.Name].CreateValueManager();
			ValueManager.DataExchange.Load = True;
			ValueManager.Value = MetadataConstants.Type.AdjustValue();
			ValueManager.Write();
		EndDo;
		
		// Reference types
		
		ObjectKinds = New Array;
		ObjectKinds.Add("Catalogs");
		ObjectKinds.Add("Documents");
		ObjectKinds.Add("ChartsOfCharacteristicTypes");
		ObjectKinds.Add("ChartsOfAccounts");
		ObjectKinds.Add("ChartsOfCalculationTypes");
		ObjectKinds.Add("BusinessProcesses");
		ObjectKinds.Add("Tasks");
		
		For Each ObjectKind In ObjectKinds Do
			MetadataCollection = Metadata[ObjectKind];
			For Each ObjectMD In MetadataCollection Do
				If Not CommonUse.IsSeparatedMetadataObject(ObjectMD, CommonUseReUse.MainDataSeparator()) Then
					Continue;
				EndIf;
				
				Query = New Query;
				Query.Text =
				"SELECT
				|	_XMLExport_Table.Ref AS Ref
				|FROM
				|	" + ObjectMD.FullName() + " AS _XMLExport_Table";
				If ObjectKind = "Catalogs"
					OR ObjectKind = "ChartsOfCharacteristicTypes"
					OR ObjectKind = "ChartsOfAccounts"
					OR ObjectKind = "ChartsOfCalculationTypes" Then
					
					Query.Text = Query.Text + "
					|WHERE
					|	_XMLExport_Table.Predefined = FALSE";
				EndIf;
				
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				While Selection.Next() Do
					Delete = New ObjectDeletion(Selection.Ref);
					Delete.DataExchange.Load = True;
					Delete.Write();
				EndDo;
			EndDo;
		EndDo;
		
		// Registers in addition to the independent information and sequence registers
		TableKinds = New Array;
		TableKinds.Add("AccumulationRegisters");
		TableKinds.Add("CalculationRegisters");
		TableKinds.Add("AccountingRegisters");
		TableKinds.Add("InformationRegisters");
		TableKinds.Add("Sequences");
		For Each TableKind In TableKinds Do
			MetadataCollection = Metadata[TableKind];
			KindManager = Eval(TableKind);
			For Each RegisterMD In MetadataCollection Do
				
				If Not CommonUse.IsSeparatedMetadataObject(RegisterMD, CommonUseReUse.MainDataSeparator()) Then
					Continue;
				EndIf;
				
				If TableKind = "InformationRegisters"
					AND RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.Independent Then
					
					Continue;
				EndIf;
				
				TypeManager = KindManager[RegisterMD.Name];
				
				Query = New Query;
				Query.Text =
				"SELECT DISTINCT
				|	_XMLExport_Table.Recorder AS Recorder
				|FROM
				|	" + RegisterMD.FullName() + " AS _XMLExport_Table";
				QueryResult = Query.Execute();
				Selection = QueryResult.Select();
				While Selection.Next() Do
					RecordSet = TypeManager.CreateRecordSet();
					RecordSet.Filter.Recorder.Set(Selection.Recorder);
					RecordSet.DataExchange.Load = True;
					RecordSet.Write();
				EndDo;
			EndDo;
		EndDo;
		
		// Independent information registers
		For Each RegisterMD In Metadata.InformationRegisters Do
			
			If Not CommonUse.IsSeparatedMetadataObject(RegisterMD, CommonUseReUse.MainDataSeparator()) Then
				Continue;
			EndIf;
			
			If RegisterMD.WriteMode = Metadata.ObjectProperties.RegisterWriteMode.RecorderSubordinate Then
				
				Continue;
			EndIf;
			
			TypeManager = InformationRegisters[RegisterMD.Name];
			
			RecordSet = TypeManager.CreateRecordSet();
			RecordSet.DataExchange.Load = True;
			RecordSet.Write();
		EndDo;
		
		// Exchange plans
		
		For Each ExchangePlanMD In Metadata.ExchangePlans Do
			
			If Not CommonUse.IsSeparatedMetadataObject(ExchangePlanMD, CommonUseReUse.MainDataSeparator()) Then
				Continue;
			EndIf;
			
			TypeManager = ExchangePlans[ExchangePlanMD.Name];
			
			Query = New Query;
			Query.Text =
			"SELECT
			|	_XMLExport_Table.Ref AS Ref
			|FROM
			|	" + ExchangePlanMD.FullName() + " AS
			|_XMLExport_Table
			|	WHERE _XMLExport_Table.Ref <> &ThisNode";
			Query.SetParameter("ThisNode", TypeManager.ThisNode());
			QueryResult = Query.Execute();
			Selection = QueryResult.Select();
			While Selection.Next() Do
				Delete = New ObjectDeletion(Selection.Ref);
				Delete.DataExchange.Load = True;
				Delete.Write();
			EndDo;
		EndDo;
		
		CommitTransaction();
		
		CommonUse.UnlockInfobase();
		
	Except
		RollbackTransaction();
		WriteLogEvent(
			NStr("en = 'Data Deletion'",
				CommonUseClientServer.MainLanguageCode()),
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

#EndRegion

#Region ExchangeProceduresWithBanks

// Procedure fills in payment decryption for expense.
//
Procedure FillPaymentDetailsExpense(CurrentObject, ParentCompany = Undefined, DefaultVATRate = Undefined, ExchangeRate = Undefined, Multiplicity = Undefined, Contract = Undefined) Export
	
	If ParentCompany = Undefined Then
		ParentCompany = GetCompany(CurrentObject.Company);
	EndIf;
	
	If ExchangeRate = Undefined
	   AND Multiplicity = Undefined Then
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(CurrentObject.Date, New Structure("Currency", CurrentObject.CashCurrency));
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
	EndIf;
	
	If DefaultVATRate = Undefined Then
		If CurrentObject.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(CurrentObject.Date, CurrentObject.Company);
		ElsIf CurrentObject.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	EndIf;
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT
	|	AccountsPayableBalances.Company AS Company,
	|	AccountsPayableBalances.Counterparty AS Counterparty,
	|	AccountsPayableBalances.Contract AS Contract,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayableBalances.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END AS Order,
	|	AccountsPayableBalances.SettlementsType AS SettlementsType,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance,
	|	AccountsPayableBalances.Document.Date AS DocumentDate,
	|	SUM(CAST(AccountsPayableBalances.AmountCurBalance * SettlementsExchangeRates.ExchangeRate * ExchangeRatesOfDocument.Multiplicity / (ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity) AS NUMBER(15, 2))) AS AmountCurrDocument,
	|	ExchangeRatesOfDocument.ExchangeRate AS CashAssetsRate,
	|	ExchangeRatesOfDocument.Multiplicity AS CashMultiplicity,
	|	SettlementsExchangeRates.ExchangeRate AS ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity AS Multiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Company AS Company,
	|		AccountsPayableBalances.Counterparty AS Counterparty,
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Order AS Order,
	|		AccountsPayableBalances.SettlementsType AS SettlementsType,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					// TextOfContractSelection
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Company,
	|		DocumentRegisterRecordsVendorSettlements.Counterparty,
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Order,
	|		DocumentRegisterRecordsVendorSettlements.SettlementsType,
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
	|		AND DocumentRegisterRecordsVendorSettlements.Counterparty = &Counterparty
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Debt)) AS AccountsPayableBalances
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &Currency) AS ExchangeRatesOfDocument
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, ) AS SettlementsExchangeRates
	|		ON AccountsPayableBalances.Contract.SettlementsCurrency = SettlementsExchangeRates.Currency
	|WHERE
	|	AccountsPayableBalances.AmountCurBalance > 0
	|
	|GROUP BY
	|	AccountsPayableBalances.Company,
	|	AccountsPayableBalances.Counterparty,
	|	AccountsPayableBalances.Contract,
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.SettlementsType,
	|	AccountsPayableBalances.Document.Date,
	|	ExchangeRatesOfDocument.ExchangeRate,
	|	ExchangeRatesOfDocument.Multiplicity,
	|	SettlementsExchangeRates.ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsPayableBalances.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsPayableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsPayableBalances.Order
	|		ELSE VALUE(Document.PurchaseOrder.EmptyRef)
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", CurrentObject.Counterparty);
	Query.SetParameter("Period", CurrentObject.Date);
	Query.SetParameter("Currency", CurrentObject.CashCurrency);
	Query.SetParameter("Ref", CurrentObject.Ref);
	
	If ValueIsFilled(Contract)
		AND TypeOf(Contract) = Type("CatalogRef.CounterpartyContracts") Then
		Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "AND Contract = &Contract");
		Query.SetParameter("Contract", Contract);
		ContractByDefault = Contract; // if there is no debt, then advance will be assigned to this contract
	Else
		NeedFilterByContracts = DriveReUse.CounterpartyContractsControlNeeded();
		ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(CurrentObject.Ref, CurrentObject.OperationKind);
		If NeedFilterByContracts
		   AND CurrentObject.Counterparty.DoOperationsByContracts Then
			Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "And Contract.ContractType IN (&ContractTypesList)");
			Query.SetParameter("ContractTypesList", ContractTypesList);
		EndIf;
		ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
			CurrentObject.Counterparty,
			CurrentObject.Company,
			ContractTypesList
		); // if there is no debt, then advance will be assigned to this contract
	EndIf;
		
	StructureContractCurrencyRateByDefault = InformationRegisters.ExchangeRates.GetLast(
		CurrentObject.Date,
		New Structure("Currency", ContractByDefault.SettlementsCurrency)
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	CurrentObject.PaymentDetails.Clear();
	
	AmountLeftToDistribute = CurrentObject.DocumentAmount;
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = CurrentObject.PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurrDocument;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				NewRow.PaymentAmount = AmountLeftToDistribute;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
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
			NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			NewRow.PaymentAmount = AmountLeftToDistribute;
			NewRow.VATRate = DefaultVATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	If CurrentObject.PaymentDetails.Count() = 0 Then
		CurrentObject.PaymentDetails.Add();
		CurrentObject.PaymentDetails[0].PaymentAmount = CurrentObject.DocumentAmount;
	EndIf;
	
	PaymentAmount = CurrentObject.PaymentDetails.Total("PaymentAmount");
	
EndProcedure

// Procedure fills in payment decryption for receipt.
//
Procedure FillPaymentDetailsReceipt(CurrentObject, ParentCompany = Undefined, DefaultVATRate = Undefined, ExchangeRate = Undefined, Multiplicity = Undefined, Contract = Undefined) Export
	
	If ParentCompany = Undefined Then
		ParentCompany = GetCompany(CurrentObject.Company);
	EndIf;
	
	If ExchangeRate = Undefined
	   AND Multiplicity = Undefined Then
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(CurrentObject.Date, New Structure("Currency", CurrentObject.CashCurrency));
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
	EndIf;
	
	If DefaultVATRate = Undefined Then
		If CurrentObject.VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			DefaultVATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(CurrentObject.Date, CurrentObject.Company);
		ElsIf CurrentObject.VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			DefaultVATRate = Catalogs.VATRates.Exempt;
		Else
			DefaultVATRate = Catalogs.VATRates.ZeroRate;
		EndIf;
	EndIf;
	
	// Filling default payment details.
	Query = New Query;
	Query.Text =
	
	"SELECT
	|	AccountsReceivableBalances.Company AS Company,
	|	AccountsReceivableBalances.Counterparty AS Counterparty,
	|	AccountsReceivableBalances.Contract AS Contract,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivableBalances.Document
	|		ELSE UNDEFINED
	|	END AS Document,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END AS Order,
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
	|	AccountsReceivableBalances.Counterparty,
	|	AccountsReceivableBalances.Contract,
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.SettlementsType,
	|	AccountsReceivableBalances.Document.Date,
	|	ExchangeRatesOfDocument.ExchangeRate,
	|	ExchangeRatesOfDocument.Multiplicity,
	|	SettlementsExchangeRates.ExchangeRate,
	|	SettlementsExchangeRates.Multiplicity,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByDocuments
	|			THEN AccountsReceivableBalances.Document
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN AccountsReceivableBalances.Counterparty.DoOperationsByOrders
	|			THEN AccountsReceivableBalances.Order
	|		ELSE VALUE(Document.SalesOrder.EmptyRef)
	|	END
	|
	|ORDER BY
	|	DocumentDate";
		
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", CurrentObject.Counterparty);
	Query.SetParameter("Period", CurrentObject.Date);
	Query.SetParameter("Currency", CurrentObject.CashCurrency);
	Query.SetParameter("Ref", CurrentObject.Ref);
	
	If ValueIsFilled(Contract)
		AND TypeOf(Contract) = Type("CatalogRef.CounterpartyContracts") Then
		Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "AND Contract = &Contract");
		Query.SetParameter("Contract", Contract);
		ContractByDefault = Contract;
	Else
		NeedFilterByContracts = DriveReUse.CounterpartyContractsControlNeeded();
		ContractTypesList = Catalogs.CounterpartyContracts.GetContractKindsListForDocument(CurrentObject.Ref, CurrentObject.OperationKind);
		If NeedFilterByContracts
		   AND CurrentObject.Counterparty.DoOperationsByContracts Then
			Query.Text = StrReplace(Query.Text, "// TextOfContractSelection", "And Contract.ContractType IN (&ContractTypesList)");
			Query.SetParameter("ContractTypesList", ContractTypesList);
		EndIf;
		ContractByDefault = Catalogs.CounterpartyContracts.GetDefaultContractByCompanyContractKind(
			CurrentObject.Counterparty,
			CurrentObject.Company,
			ContractTypesList
		); // if there is no debt, then advance will be assigned to this contract
	EndIf;
	
	StructureContractCurrencyRateByDefault = InformationRegisters.ExchangeRates.GetLast(
		CurrentObject.Date,
		New Structure("Currency", ContractByDefault.SettlementsCurrency)
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	CurrentObject.PaymentDetails.Clear();
	
	AmountLeftToDistribute = CurrentObject.DocumentAmount;
	
	While AmountLeftToDistribute > 0 Do
		
		NewRow = CurrentObject.PaymentDetails.Add();
		
		If SelectionOfQueryResult.Next() Then
			
			FillPropertyValues(NewRow, SelectionOfQueryResult);
			
			If SelectionOfQueryResult.AmountCurrDocument <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow.SettlementsAmount = SelectionOfQueryResult.AmountCurBalance;
				NewRow.PaymentAmount = SelectionOfQueryResult.AmountCurrDocument;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.AmountCurrDocument;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
					AmountLeftToDistribute,
					SelectionOfQueryResult.CashAssetsRate,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.CashMultiplicity,
					SelectionOfQueryResult.Multiplicity
				);
				NewRow.PaymentAmount = AmountLeftToDistribute;
				NewRow.VATRate = DefaultVATRate;
				NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
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
			NewRow.SettlementsAmount = RecalculateFromCurrencyToCurrency(
				AmountLeftToDistribute,
				ExchangeRate,
				NewRow.ExchangeRate,
				Multiplicity,
				NewRow.Multiplicity
			);
			NewRow.AdvanceFlag = True;
			NewRow.PaymentAmount = AmountLeftToDistribute;
			NewRow.VATRate = DefaultVATRate;
			NewRow.VATAmount = NewRow.PaymentAmount - (NewRow.PaymentAmount) / ((DefaultVATRate.Rate + 100) / 100);
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
	If CurrentObject.PaymentDetails.Count() = 0 Then
		CurrentObject.PaymentDetails.Add();
		CurrentObject.PaymentDetails[0].PaymentAmount = CurrentObject.DocumentAmount;
	EndIf;
	
	PaymentAmount = CurrentObject.PaymentDetails.Total("PaymentAmount");
	
EndProcedure

#EndRegion

#Region BusinessCalendarsProceduresAndFunctions

// Function returns Calendars catalog item If item is not found, Undefined is returned.
// 
Function GetFiveDaysCalendar() Export
	
	BusinessCalendar = CalendarSchedules.FiveDaysBusinessCalendar();
	If BusinessCalendar = Undefined Then
		
		WriteLogEvent(
			NStr("en = 'Cannot fill in data for company work schedule.'",
				CommonUseClientServer.MainLanguageCode()), 
			EventLogLevel.Error,,,
			DetailErrorDescription(ErrorInfo()));
		
		Return Undefined;
		
	EndIf;
	
	Query = New Query(
	"SELECT
	|	Calendars.Ref AS Calendar
	|FROM
	|	Catalog.Calendars AS Calendars
	|WHERE
	|	Calendars.BusinessCalendar = &BusinessCalendar");
	
	Query.SetParameter("BusinessCalendar", BusinessCalendar);
	SelectionOfQueryResult = Query.Execute().Select();
	
	// Deliberately cancel recursion in case there is no work schedule
	Return ?(SelectionOfQueryResult.Next(),
					SelectionOfQueryResult.Calendar,
					Undefined);
	
EndFunction

// Old. Saved to support compatibility.
// Function reads calendar data from register
//
// Parameters
// Calendar		- Refs to the
// current catalog item YearNumber		- Year number for which it is required to read the calendar
//
// Return
// value Array		- array in which dates included in the calendar are stored
//
Function ReadScheduleDataFromRegister(Calendar, YearNumber) Export
	
	Query = New Query;
	Query.SetParameter("Calendar",	Calendar);
	Query.SetParameter("CurrentYear",	YearNumber);
	Query.Text =
	"SELECT
	|	CalendarSchedules.ScheduleDate AS CalendarDate
	|FROM
	|	InformationRegister.CalendarSchedules AS CalendarSchedules
	|WHERE
	|	CalendarSchedules.Calendar = &Calendar
	|	AND CalendarSchedules.Year = &CurrentYear
	|	AND CalendarSchedules.DayIncludedInSchedule";
	
	Return Query.Execute().Unload().UnloadColumn("CalendarDate");
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsOfCounterpartiesContactInformationPrinting

// The function returns a request result by contact info kinds that can be used for printing.
//
Function GetAvailableForPrintingCIKinds() Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	ContactInformationTypes.Ref AS CIKind,
		|	ContactInformationTypes.Description AS Description,
		|	ContactInformationTypes.ToolTip AS ToolTip,
		|	1 AS CIOwnerIndex,
		|	ContactInformationTypes.AdditionalOrderingAttribute AS AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Parent = &CICatalogCounterparties
		|	AND ContactInformationTypes.IsFolder = FALSE
		|	AND ContactInformationTypes.DeletionMark = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ContactInformationTypes.Ref,
		|	ContactInformationTypes.Description,
		|	ContactInformationTypes.ToolTip,
		|	2,
		|	ContactInformationTypes.AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Parent = &CICatalogContactPersons
		|	AND ContactInformationTypes.IsFolder = FALSE
		|	AND ContactInformationTypes.DeletionMark = FALSE
		|
		|UNION ALL
		|
		|SELECT
		|	ContactInformationTypes.Ref,
		|	ContactInformationTypes.Description,
		|	ContactInformationTypes.ToolTip,
		|	3,
		|	ContactInformationTypes.AdditionalOrderingAttribute
		|FROM
		|	Catalog.ContactInformationTypes AS ContactInformationTypes
		|WHERE
		|	ContactInformationTypes.Parent = &CICatalogIndividuals
		|	AND ContactInformationTypes.IsFolder = FALSE
		|	AND ContactInformationTypes.DeletionMark = FALSE
		|	AND ContactInformationTypes.Type = &TypePhone
		|
		|ORDER BY
		|	CIOwnerIndex,
		|	AdditionalOrderingAttribute";
	
	Query.SetParameter("CICatalogCounterparties", Catalogs.ContactInformationTypes.CatalogCounterparties);	
	Query.SetParameter("CICatalogContactPersons", Catalogs.ContactInformationTypes.CatalogContactPersons);	
	Query.SetParameter("CICatalogIndividuals", Catalogs.ContactInformationTypes.CatalogIndividuals);	
	Query.SetParameter("TypePhone", Enums.ContactInformationTypes.Phone);
	
	SetPrivilegedMode(True);
	QueryResult = Query.Execute();
	SetPrivilegedMode(False);
	
	Return QueryResult;
	
EndFunction

// The function sets an initial value of the contact information kind use.
//
// Parameters:
//  CIKind	 - Catalog.ContactInformationTypes	 - Check contact
// information kind Return value:
//  Boolean - Contact information kind is printed by default
Function SetPrintDefaultCIKind(CIKind) Export
	
	If CIKind = Catalogs.ContactInformationTypes.CounterpartyPostalAddress 
		Or CIKind = Catalogs.ContactInformationTypes.CounterpartyFax
		Or CIKind = Catalogs.ContactInformationTypes.CounterpartyOtherInformation
		Then
			Return False;
	EndIf;
	
	Return CIKind.Predefined;
	
EndFunction

#EndRegion

#Region ManagerMonitorProceduresAndFunctions

// Function creates report settings linker and overrides specified parameters and filters.
//
// Parameters:
//  ReportProperties			 - Structure	 - keys: "ReportName" - report name as specified in the configurator, "VariantKeys" (optional) - ParametersAndFilters
//  report option name	 - Array - structures array for specifying changing parameters and filters. Structure keys:
// 								"FieldName" (mandatory) - parameter name or data layout field by which
// 								the filter is set, "RightValue" (mandatory) - selected value of
// 								parameter or filter , "SettingKind" (optional) - defines a container for placing parameter or filter, options:
// 								"Settings" "FixedSettings", other structure keys are optional and they specify the filter item properties.
// Returns:
//  DataCompositionSettingsComposer - linker of settings with changed parameters and filters.
Function GetOverriddenSettingsComposer(ReportProperties, ParametersAndSelections) Export
	Var ReportName, VariantKey;
	
	ReportProperties.Property("ReportName", ReportName);
	ReportProperties.Property("VariantKey", VariantKey);
	
	DataCompositionSchema = Reports[ReportName].GetTemplate("MainDataCompositionSchema");
	
	If VariantKey <> Undefined AND Not IsBlankString(VariantKey) Then
		DesiredReportOption = DataCompositionSchema.SettingVariants.Find(VariantKey);
		If DesiredReportOption <> Undefined Then
			Settings = DesiredReportOption.Settings;
		EndIf;
	EndIf;
	
	If Settings = Undefined Then
		Settings = DataCompositionSchema.DefaultSettings;
	EndIf;
	
	DataCompositionSettingsComposer = New DataCompositionSettingsComposer;
	DataCompositionSettingsComposer.Initialize(New DataCompositionAvailableSettingsSource(DataCompositionSchema));
	DataCompositionSettingsComposer.LoadSettings(Settings);
	
	For Each ParameterFilter In ParametersAndSelections Do
		
		If ParameterFilter.Property("SettingKind") Then
			If ParameterFilter.SettingKind = "Settings" Then
				Container = DataCompositionSettingsComposer.Settings;
			ElsIf ParameterFilter.SettingKind = "FixedSettings" Then
				Container = DataCompositionSettingsComposer.FixedSettings;
			EndIf;
		Else
			Container = DataCompositionSettingsComposer.Settings;
		EndIf;
		
		FoundParameter = Container.DataParameters.FindParameterValue(New DataCompositionParameter(ParameterFilter.FieldName));
		If FoundParameter <> Undefined Then
			Container.DataParameters.SetParameterValue(FoundParameter.Parameter, ParameterFilter.RightValue);
		EndIf;
		
		FoundFilters = CommonUseClientServer.FindFilterItemsAndGroups(Container.Filter, ParameterFilter.FieldName);
		For Each FoundFilter In FoundFilters Do
			
			If TypeOf(FoundFilter) <> Type("DataCompositionFilterItem") Then
				Continue;
			EndIf;
			
			FillPropertyValues(FoundFilter, ParameterFilter);
			
			If Not ParameterFilter.Property("ComparisonType") Then
				FoundFilter.ComparisonType = DataCompositionComparisonType.Equal;
			EndIf;
			If Not ParameterFilter.Property("Use") Then
				FoundFilter.Use = True;
			EndIf;
			If Not ParameterFilter.Property("ViewMode") Then
				FoundFilter.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
			EndIf;
			
		EndDo;
		
		If FoundFilters.Count() = 0 AND FoundParameter = Undefined Then
			AddedItem = CommonUseClientServer.AddCompositionItem(Container.Filter, ParameterFilter.FieldName, DataCompositionComparisonType.Equal);
			FillPropertyValues(AddedItem, ParameterFilter);
		EndIf;
		
	EndDo;
	
	Return DataCompositionSettingsComposer;
	
EndFunction

// Function returns colors used for monitors.
//
// Parameters:
//  ColorName - String - Color name
Function ColorForMonitors(ColorName) Export
	
	Color = New Color();
	
	If ColorName = "Green" Then
		Color = New Color(25, 204, 25);
	ElsIf ColorName = "Dark-green" Then
		Color = New Color(29, 150, 66);
	ElsIf ColorName = "Yellow" Then
		Color = New Color(254, 225, 1);
	ElsIf ColorName = "Orange" Then
		Color = WebColors.Orange;
	ElsIf ColorName = "Coral" Then
		Color = WebColors.Coral;
	ElsIf ColorName = "Red" Then
		Color = New Color(208, 42, 53);
	ElsIf ColorName = "Magenta" Then
		Color = WebColors.Magenta;
	ElsIf ColorName = "Blue" Then
		Color = WebColors.DeepSkyBlue;
	ElsIf ColorName = "Light-gray" Then
		Color = WebColors.Gainsboro;
	ElsIf ColorName = "Gray" Then
		Color = WebColors.Gray;
	EndIf;
	
	Return Color;
	
EndFunction

// Function returns the resulting formatted string.
//
// Parameters:
//  RowItems - Structures array with the "Row" key
//    and the output row value, the other keys match the formatted row designer parameters
//
Function BuildFormattedString(RowItems) Export
	
	String = "";
	Font = Undefined;
	TextColor = Undefined;
	BackColor = Undefined;
	FormattedStringsArray = New Array;
	
	For Each Item In RowItems Do
		Item.Property("String", String);
		Item.Property("Font", Font);
		Item.Property("TextColor", TextColor);
		Item.Property("BackColor", BackColor);
		FormattedStringsArray.Add(New FormattedString(String, Font, TextColor, BackColor)); 
	EndDo;
	
	Return New FormattedString(FormattedStringsArray);
	
EndFunction

// The function creates a title as a formatted string for item widget headers.
//
// Parameters:
//  SourceAmount - Number - value from which
// title is generated Return value:
//  FormattedString - Title string
Function GenerateTitle(val SourceAmount) Export
	
	FormattedAmount = Format(SourceAmount, "NFD=2; NGS=' '; NZ=—; NG=3,0");
	Delimiter = Find(FormattedAmount, ",");
	RowPositionThousands = Left(FormattedAmount, Delimiter-4);
	RowDigitUnits = Mid(FormattedAmount, Delimiter-3);
	
	RowItems = New Array;
	RowItems.Add(New Structure("String, Font", RowPositionThousands, New Font(StyleFonts.ExtraLargeTextFont)));
	RowItems.Add(New Structure("String, Font", RowDigitUnits, New Font(StyleFonts.NormalTextFont)));
	
	Return BuildFormattedString(RowItems);
	
EndFunction

#EndRegion

#Region DesktopManagementProceduresAndFunctions

// Determines a default desktop depending on the user access rights.
//
Procedure ConfigureUserDesktop(SettingsModified = False) Export
	
	RunMode = CommonUseReUse.ApplicationRunningMode();
	If RunMode.SaaS
		AND RunMode.ThisIsSystemAdministrator Then
		Return;
	EndIf;
	
	HomePageSettings = CommonUse.SystemSettingsStorageImport("Common/HomePageSettings","");
	
	If HomePageSettings = Undefined Then
		
		HomePageSettings = New HomePageSettings;
		FormsContent = HomePageSettings.GetForms();
		
		If IsInRole("FullRights") Then
			
			FoundItem = FormsContent.LeftColumn.Find("CommonForm.GettingStarted");
			If FoundItem = Undefined
				OR Not (Constants.CompanyInformationIsFilled.Get()
					AND Constants.OpeningBalanceIsFilled.Get()) Then
				Return;
			EndIf;
			
			FormsContent.LeftColumn.Delete(FoundItem);
			FormsContent.LeftColumn.Add("DataProcessor.QuickActions.Form.QuickActions");
			FormsContent.LeftColumn.Add("DataProcessor.BusinessPulse.Form.BusinessPulse");
			FormsContent.RightColumn.Add("CommonForms.ToDoList");
		ElsIf IsInRole("UseAnalysisReports") Then
			FormsContent.LeftColumn.Add("DataProcessor.QuickActions.Form.QuickActions");
			FormsContent.LeftColumn.Add("DataProcessor.BusinessPulse.Form.BusinessPulse");
		ElsIf IsInRole("AddChangeSalesSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.SalesDocuments.ListForm");
		ElsIf IsInRole("AddChangePurchasesSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.PurchaseDocuments.ListForm");
		ElsIf IsInRole("AddChangeProductionSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.ProductionDocuments.ListForm");
		ElsIf IsInRole("AddChangePayrollSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.PayrollDocuments.ListForm");
		ElsIf IsInRole("AddChangeBankSubsystem") Then
			FormsContent.LeftColumn.Add("DocumentJournal.BankDocuments.ListForm");
		EndIf;
		
		HomePageSettings.SetForms(FormsContent);
		CommonUse.SystemSettingsStorageSave("Common/HomePageSettings","", HomePageSettings);
		
		SettingsModified = True;
	EndIf;
	
EndProcedure

#EndRegion

#Region WorkWithObjectQuerySchema

// Function - Find the field of query schema available table
//
// Parameters:
//  AvailableTable - AvailableTableQuerySchema	 - table where search
//  FieldName is executed			 - String - search field
//  name FieldType			 - Type - possible values "QuerySchemaAvailableField", "QuerySchemaAvailableInsertedTable".
//  					If parameter is specified, then search is executed only by
// fields of the specified Return value type:
//  QuerySchemaAvailableField,QuerySchemaAvailableNestedTable - found field
Function FindAvailableTableQuerySchemaField(AvailableTable, FieldName, FieldType = Undefined) Export
	
	Result = Undefined;
	
	For Each Field In AvailableTable.Fields Do
		If Field.Name = FieldName AND (FieldType = Undefined Or (TypeOf(Field) = FieldType)) Then
			Result = Field;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

// Function - Find query schema source
//
// Parameters:
//  Sources		 - SourcesQuerySchema 	 - sources where TableAlias
//  search is executed. - String	 - TableType
//  desired table alias		 - Type - possible values "QuerySchemaTable", "QuerySchemaInsertedQuery", "TemporaryQuerySchemaTableDescription".
//  					If the parameter is defined, then search is performed only
// by the sources of the specified type Return value:
//  QuerySchemaSource - source is found
Function FindQuerySchemaSource(Sources, TablePseudonym, TableType = Undefined) Export
	
	Result = Undefined;
	
	For Each Source In Sources Do
		If Source.Source.Alias = TablePseudonym AND (TableType = Undefined Or (TypeOf(Source.Source) = TableType)) Then
			Result = Source;
			Break;
		EndIf;
	EndDo;
	
	Return Result;
	
EndFunction

Function GetFunctionalOptionValue(Name) Export
	
	Return GetFunctionalOption(Name);
	
EndFunction

#Region GenerateCommands

Procedure OverrideStandartGenerateGoodsIssueCommand(Form) Export
	
	GenerateGoodsIssueCommand = Form.Commands.Add("GenerateGoodsIssue");
	GenerateGoodsIssueCommand.Action	= "Attachable_GenerateGoodsIssue";
	GenerateGoodsIssueCommand.Title		= NStr("en = 'Goods issue'");
	
	StandartGenerateGoodsIssueButton = Form.Items.FormDocumentGoodsIssueCreateBasedOn;
	StandartGenerateGoodsIssueButton.Visible = False;
	OverridenGenerateGoodsIssueButton = Form.Items.Insert("FormCreateBasedOnGenerateGoodsIssue",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateGoodsIssueButton);
	OverridenGenerateGoodsIssueButton.CommandName = "GenerateGoodsIssue";
	
EndProcedure

Procedure OverrideStandartGenerateGoodsReceiptCommand(Form) Export
	
	GenerateGoodsReceiptCommand = Form.Commands.Add("GenerateGoodsReceipt");
	GenerateGoodsReceiptCommand.Action	= "Attachable_GenerateGoodsReceipt";
	GenerateGoodsReceiptCommand.Title	= NStr("en = 'Goods receipt'");
	
	StandartGenerateGoodsReceiptButton = Form.Items.FormDocumentGoodsReceiptCreateBasedOn;
	StandartGenerateGoodsReceiptButton.Visible = False;
	OverridenGenerateGoodsReceiptButton = Form.Items.Insert("FormCreateBasedOnGenerateGoodsReceipt",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateGoodsReceiptButton);
	OverridenGenerateGoodsReceiptButton.CommandName = "GenerateGoodsReceipt";
	
EndProcedure

Procedure OverrideStandartGenerateSalesInvoiceCommand(Form) Export
	
	GenerateSalesInvoiceCommand = Form.Commands.Add("GenerateSalesInvoice");
	GenerateSalesInvoiceCommand.Action = "Attachable_GenerateSalesInvoice";
	GenerateSalesInvoiceCommand.Title = NStr("en = 'Sales invoice'");
	
	StandartGenerateSalesInvoiceButton = Form.Items.FormDocumentSalesInvoiceCreateBasedOn;
	StandartGenerateSalesInvoiceButton.Visible = False;
	OverridenGenerateSalesInvoiceButton = Form.Items.Insert("FormCreateBasedOnGenerateSalesInvoice",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateSalesInvoiceButton);
	OverridenGenerateSalesInvoiceButton.CommandName = "GenerateSalesInvoice";
	
EndProcedure

Procedure OverrideStandartGenerateSupplierInvoiceCommand(Form) Export
	
	GenerateSupplierInvoiceCommand = Form.Commands.Add("GenerateSupplierInvoice");
	GenerateSupplierInvoiceCommand.Action = "Attachable_GenerateSupplierInvoice";
	GenerateSupplierInvoiceCommand.Title = NStr("en = 'Supplier invoice'");
	
	StandartGenerateSupplierInvoiceButton = Form.Items.FormDocumentSupplierInvoiceCreateBasedOn;
	StandartGenerateSupplierInvoiceButton.Visible = False;
	OverridenGenerateSupplierInvoiceButton = Form.Items.Insert("FormCreateBasedOnGenerateSupplierInvoice",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateSupplierInvoiceButton);
	OverridenGenerateSupplierInvoiceButton.CommandName = "GenerateSupplierInvoice";
	
EndProcedure

Procedure OverrideStandartGenerateCustomsDeclarationCommand(Form) Export
	
	GenerateCustomsDeclarationCommand = Form.Commands.Add("GenerateCustomsDeclaration");
	GenerateCustomsDeclarationCommand.Action = "Attachable_GenerateCustomsDeclaration";
	GenerateCustomsDeclarationCommand.Title = NStr("en = 'Customs declaration'");
	
	StandartGenerateCustomsDeclarationButton = Form.Items.FormDocumentCustomsDeclarationCreateBasedOn;
	StandartGenerateCustomsDeclarationButton.Visible = False;
	OverridenGenerateCustomsDeclarationButton = Form.Items.Insert("FormCreateBasedOnGenerateCustomsDeclaration",
															Type("FormButton"),
															Form.Items.FormCreateBasedOn,
															StandartGenerateCustomsDeclarationButton);
	OverridenGenerateCustomsDeclarationButton.CommandName = "GenerateCustomsDeclaration";
	
EndProcedure

Function CheckGoodsIssueKeyAttributes(GoodsIssueArray) Export
	
	DataStructure = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsIssueHeader.Company AS Company,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	GoodsIssueHeader.Contract AS Contract,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	GoodsIssueHeader.Order AS Order,
	|	GoodsIssueHeader.Ref AS Ref
	|INTO TT_GoodsIssue
	|FROM
	|	Document.GoodsIssue AS GoodsIssueHeader
	|WHERE
	|	GoodsIssueHeader.Ref IN(&GoodsIssueArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	GoodsIssueHeader.Company AS Company,
	|	GoodsIssueHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsIssueProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsIssueProducts.Contract
	|		ELSE GoodsIssueHeader.Contract
	|	END AS Contract,
	|	GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN GoodsIssueProducts.Order <> VALUE(Document.SalesOrder.EmptyRef)
	|			THEN GoodsIssueProducts.Order
	|		ELSE GoodsIssueHeader.Order
	|	END AS Order,
	|	GoodsIssueHeader.Ref AS Ref
	|INTO TT_GoodsIssueHeader
	|FROM
	|	TT_GoodsIssue AS GoodsIssueHeader
	|		LEFT JOIN Document.GoodsIssue.Products AS GoodsIssueProducts
	|		ON GoodsIssueHeader.Ref = GoodsIssueProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.DocumentCurrency AS DocumentCurrency,
	|	SalesOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrder.PriceKind AS PriceKind,
	|	SalesOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesOrder.VATTaxation AS VATTaxation,
	|	SalesOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrder.DiscountCard AS DiscountCard,
	|	TT_GoodsIssueHeader.Company AS Company,
	|	TT_GoodsIssueHeader.Counterparty AS Counterparty,
	|	TT_GoodsIssueHeader.Contract AS Contract,
	|	TT_GoodsIssueHeader.StructuralUnit AS StructuralUnit,
	|	TT_GoodsIssueHeader.Order AS Order,
	|	TT_GoodsIssueHeader.Ref AS Ref
	|INTO TT_GoodsIssueAndOrders
	|FROM
	|	TT_GoodsIssueHeader AS TT_GoodsIssueHeader
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON TT_GoodsIssueHeader.Order = SalesOrder.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Total.Company) AS Company,
	|	SUM(Total.Counterparty) AS Counterparty,
	|	SUM(Total.Contract) AS Contract,
	|	SUM(Total.StructuralUnit) AS StructuralUnit,
	|	SUM(Total.DocumentCurrency) AS DocumentCurrency,
	|	SUM(Total.IncludeVATInPrice) AS IncludeVATInPrice,
	|	SUM(Total.VATTaxation) AS VATTaxation,
	|	SUM(Total.AmountIncludesVAT) AS AmountIncludesVAT,
	|	SUM(Total.DiscountMarkupKind) AS DiscountMarkupKind,
	|	SUM(Total.PriceKind) AS PriceKind,
	|	SUM(Total.DiscountCard) AS DiscountCard
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT TT_GoodsIssueHeader.Company) AS Company,
	|		COUNT(DISTINCT TT_GoodsIssueHeader.Counterparty) AS Counterparty,
	|		COUNT(DISTINCT TT_GoodsIssueHeader.Contract) AS Contract,
	|		COUNT(DISTINCT TT_GoodsIssueHeader.StructuralUnit) AS StructuralUnit,
	|		0 AS DocumentCurrency,
	|		0 AS IncludeVATInPrice,
	|		0 AS VATTaxation,
	|		0 AS AmountIncludesVAT,
	|		0 AS DiscountMarkupKind,
	|		0 AS PriceKind,
	|		0 AS DiscountCard
	|	FROM
	|		TT_GoodsIssueHeader AS TT_GoodsIssueHeader
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		0,
	|		0,
	|		0,
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.DocumentCurrency),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.IncludeVATInPrice),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.VATTaxation),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.AmountIncludesVAT),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.DiscountMarkupKind),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.PriceKind),
	|		COUNT(DISTINCT TT_GoodsIssueAndOrders.DiscountCard)
	|	FROM
	|		TT_GoodsIssueAndOrders AS TT_GoodsIssueAndOrders) AS Total
	|
	|HAVING
	|	(SUM(Total.Company) > 1
	|		OR SUM(Total.Counterparty) > 1
	|		OR SUM(Total.Contract) > 1
	|		OR SUM(Total.StructuralUnit) > 1
	|		OR SUM(Total.DocumentCurrency) > 1
	|		OR SUM(Total.IncludeVATInPrice) > 1
	|		OR SUM(Total.VATTaxation) > 1
	|		OR SUM(Total.AmountIncludesVAT) > 1
	|		OR SUM(Total.DiscountMarkupKind) > 1
	|		OR SUM(Total.PriceKind) > 1
	|		OR SUM(Total.DiscountCard) > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_GoodsIssueHeader.Ref AS Ref,
	|	TT_GoodsIssueHeader.Contract AS Contract
	|FROM
	|	TT_GoodsIssueHeader AS TT_GoodsIssueHeader
	|TOTALS BY
	|	Contract";
	
	Query.SetParameter("GoodsIssueArray", GoodsIssueArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			OrdersArray = New Array;
			
			Sel = SelGroups.Select();
			While Sel.Next() Do
				OrdersArray.Add(New Structure("Ref, Contract", Sel.Ref, Sel.Contract));
			EndDo;
			
			GroupsArray.Add(OrdersArray);
		EndDo;
		DataStructure.Insert("GoodsIssueGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckOrdersKeyAttributes(OrdersArray, SimpleCheck = False) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrderHeader.Company AS Company,
	|	SalesOrderHeader.Counterparty AS Counterparty,
	|	SalesOrderHeader.Contract AS Contract,
	|	SalesOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	SalesOrderHeader.PriceKind AS PriceKind,
	|	SalesOrderHeader.DiscountMarkupKind AS DiscountMarkupKind,
	|	SalesOrderHeader.DiscountCard AS DiscountCard,
	|	SalesOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	SalesOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	SalesOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	SalesOrderHeader.VATTaxation AS VATTaxation,
	|	SalesOrderHeader.Ref AS Ref
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.SalesOrder AS SalesOrderHeader
	|WHERE
	|	SalesOrderHeader.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeader.Company AS Company,
	|	TT_SalesOrderHeader.Counterparty AS Counterparty,
	|	TT_SalesOrderHeader.Contract AS Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind AS PriceKind,
	|	TT_SalesOrderHeader.DiscountMarkupKind AS DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard AS DiscountCard,
	|	TT_SalesOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SalesOrderHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SalesOrderHeader.Ref) AS MinRef
	|INTO TT_SalesOrderHeaderMin
	|FROM
	|	TT_SalesOrderHeader AS TT_SalesOrderHeader
	|
	|GROUP BY
	|	TT_SalesOrderHeader.IncludeVATInPrice,
	|	TT_SalesOrderHeader.Company,
	|	TT_SalesOrderHeader.Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind,
	|	TT_SalesOrderHeader.DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT,
	|	TT_SalesOrderHeader.VATTaxation,
	|	TT_SalesOrderHeader.Counterparty,
	|	TT_SalesOrderHeader.DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesOrderHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SalesOrderHeader.StructuralUnitReserve) AS StructuralUnitReserve,
	|	COUNT(DISTINCT SalesOrderHeader.PriceKind) AS PriceKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountMarkupKind) AS DiscountMarkupKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountCard) AS DiscountCard,
	|	COUNT(DISTINCT SalesOrderHeader.DocumentCurrency) AS DocumentCurrency,
	|	COUNT(DISTINCT SalesOrderHeader.AmountIncludesVAT) AS AmountIncludesVAT,
	|	COUNT(DISTINCT SalesOrderHeader.IncludeVATInPrice) AS IncludeVATInPrice,
	|	COUNT(DISTINCT SalesOrderHeader.VATTaxation) AS VATTaxation
	|INTO TT_SalesOrderHeaderCount
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderCount.Company AS Company,
	|	TT_SalesOrderHeaderCount.Counterparty AS Counterparty,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.PriceKind
	|	END AS PriceKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountMarkupKind
	|	END AS DiscountMarkupKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountCard
	|	END AS DiscountCard,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.VATTaxation
	|	END AS VATTaxation
	|FROM
	|	TT_SalesOrderHeaderCount AS TT_SalesOrderHeaderCount
	|WHERE
	|	(TT_SalesOrderHeaderCount.Company > 1
	|			OR TT_SalesOrderHeaderCount.Counterparty > 1
	|			OR NOT &SimpleCheck
	|				AND (TT_SalesOrderHeaderCount.Contract > 1
	|					OR TT_SalesOrderHeaderCount.StructuralUnitReserve > 1
	|					OR TT_SalesOrderHeaderCount.PriceKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountMarkupKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountCard > 1
	|					OR TT_SalesOrderHeaderCount.DocumentCurrency > 1
	|					OR TT_SalesOrderHeaderCount.AmountIncludesVAT > 1
	|					OR TT_SalesOrderHeaderCount.IncludeVATInPrice > 1
	|					OR TT_SalesOrderHeaderCount.VATTaxation > 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InnerTable.MinRef AS MinRef,
	|	InnerTable.Counterparty AS Counterparty,
	|	InnerTable.Ref AS Ref
	|FROM
	|	(SELECT
	|		TT_SalesOrderHeaderMin.MinRef AS MinRef,
	|		TT_SalesOrderHeaderMin.Counterparty AS Counterparty,
	|		TT_SalesOrderHeader.Ref AS Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (NOT &SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty
	|				AND TT_SalesOrderHeaderMin.Contract = TT_SalesOrderHeader.Contract
	|				AND TT_SalesOrderHeaderMin.StructuralUnitReserve = TT_SalesOrderHeader.StructuralUnitReserve
	|				AND TT_SalesOrderHeaderMin.PriceKind = TT_SalesOrderHeader.PriceKind
	|				AND TT_SalesOrderHeaderMin.DiscountMarkupKind = TT_SalesOrderHeader.DiscountMarkupKind
	|				AND TT_SalesOrderHeaderMin.DiscountCard = TT_SalesOrderHeader.DiscountCard
	|				AND TT_SalesOrderHeaderMin.DocumentCurrency = TT_SalesOrderHeader.DocumentCurrency
	|				AND TT_SalesOrderHeaderMin.AmountIncludesVAT = TT_SalesOrderHeader.AmountIncludesVAT
	|				AND TT_SalesOrderHeaderMin.IncludeVATInPrice = TT_SalesOrderHeader.IncludeVATInPrice
	|				AND TT_SalesOrderHeaderMin.VATTaxation = TT_SalesOrderHeader.VATTaxation
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_SalesOrderHeaderMin.Company,
	|		TT_SalesOrderHeaderMin.Counterparty,
	|		TT_SalesOrderHeader.Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (&SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty) AS InnerTable
	|
	|GROUP BY
	|	InnerTable.MinRef,
	|	InnerTable.Counterparty,
	|	InnerTable.Ref
	|TOTALS BY
	|	MinRef,
	|	Counterparty";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("SimpleCheck", SimpleCheck);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			SelCounterparty = SelGroups.Select(QueryResultIteration.ByGroups);
			
			While SelCounterparty.Next() Do
				OrdersArray = New Array;
				
				Sel = SelCounterparty.Select();
				While Sel.Next() Do
					OrdersArray.Add(Sel.Ref);
				EndDo;
				
				GroupsArray.Add(OrdersArray);
			EndDo;
		EndDo;
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckWorkOrdersKeyAttributes(OrdersArray, SimpleCheck = False) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Company AS Company,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	WorkOrder.PriceKind AS PriceKind,
	|	WorkOrder.DiscountMarkupKind AS DiscountMarkupKind,
	|	WorkOrder.DiscountCard AS DiscountCard,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	WorkOrder.VATTaxation AS VATTaxation,
	|	WorkOrder.Ref AS Ref
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeader.Company AS Company,
	|	TT_SalesOrderHeader.Counterparty AS Counterparty,
	|	TT_SalesOrderHeader.Contract AS Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind AS PriceKind,
	|	TT_SalesOrderHeader.DiscountMarkupKind AS DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard AS DiscountCard,
	|	TT_SalesOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_SalesOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_SalesOrderHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SalesOrderHeader.Ref) AS MinRef
	|INTO TT_SalesOrderHeaderMin
	|FROM
	|	TT_SalesOrderHeader AS TT_SalesOrderHeader
	|
	|GROUP BY
	|	TT_SalesOrderHeader.IncludeVATInPrice,
	|	TT_SalesOrderHeader.Company,
	|	TT_SalesOrderHeader.Contract,
	|	TT_SalesOrderHeader.StructuralUnitReserve,
	|	TT_SalesOrderHeader.PriceKind,
	|	TT_SalesOrderHeader.DocumentCurrency,
	|	TT_SalesOrderHeader.AmountIncludesVAT,
	|	TT_SalesOrderHeader.VATTaxation,
	|	TT_SalesOrderHeader.Counterparty,
	|	TT_SalesOrderHeader.DiscountMarkupKind,
	|	TT_SalesOrderHeader.DiscountCard
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesOrderHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SalesOrderHeader.StructuralUnitReserve) AS StructuralUnitReserve,
	|	COUNT(DISTINCT SalesOrderHeader.PriceKind) AS PriceKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountMarkupKind) AS DiscountMarkupKind,
	|	COUNT(DISTINCT SalesOrderHeader.DiscountCard) AS DiscountCard,
	|	COUNT(DISTINCT SalesOrderHeader.DocumentCurrency) AS DocumentCurrency,
	|	COUNT(DISTINCT SalesOrderHeader.AmountIncludesVAT) AS AmountIncludesVAT,
	|	COUNT(DISTINCT SalesOrderHeader.IncludeVATInPrice) AS IncludeVATInPrice,
	|	COUNT(DISTINCT SalesOrderHeader.VATTaxation) AS VATTaxation
	|INTO TT_SalesOrderHeaderCount
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderCount.Company AS Company,
	|	TT_SalesOrderHeaderCount.Counterparty AS Counterparty,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.PriceKind
	|	END AS PriceKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountMarkupKind
	|	END AS DiscountMarkupKind,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DiscountCard
	|	END AS DiscountCard,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_SalesOrderHeaderCount.VATTaxation
	|	END AS VATTaxation
	|FROM
	|	TT_SalesOrderHeaderCount AS TT_SalesOrderHeaderCount
	|WHERE
	|	(TT_SalesOrderHeaderCount.Company > 1
	|			OR TT_SalesOrderHeaderCount.Counterparty > 1
	|			OR NOT &SimpleCheck
	|				AND (TT_SalesOrderHeaderCount.Contract > 1
	|					OR TT_SalesOrderHeaderCount.StructuralUnitReserve > 1
	|					OR TT_SalesOrderHeaderCount.PriceKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountMarkupKind > 1
	|					OR TT_SalesOrderHeaderCount.DiscountCard > 1
	|					OR TT_SalesOrderHeaderCount.DocumentCurrency > 1
	|					OR TT_SalesOrderHeaderCount.AmountIncludesVAT > 1
	|					OR TT_SalesOrderHeaderCount.IncludeVATInPrice > 1
	|					OR TT_SalesOrderHeaderCount.VATTaxation > 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InnerTable.MinRef AS MinRef,
	|	InnerTable.Counterparty AS Counterparty,
	|	InnerTable.Ref AS Ref
	|FROM
	|	(SELECT
	|		TT_SalesOrderHeaderMin.MinRef AS MinRef,
	|		TT_SalesOrderHeaderMin.Counterparty AS Counterparty,
	|		TT_SalesOrderHeader.Ref AS Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (NOT &SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty
	|				AND TT_SalesOrderHeaderMin.Contract = TT_SalesOrderHeader.Contract
	|				AND TT_SalesOrderHeaderMin.StructuralUnitReserve = TT_SalesOrderHeader.StructuralUnitReserve
	|				AND TT_SalesOrderHeaderMin.PriceKind = TT_SalesOrderHeader.PriceKind
	|				AND TT_SalesOrderHeaderMin.DiscountMarkupKind = TT_SalesOrderHeader.DiscountMarkupKind
	|				AND TT_SalesOrderHeaderMin.DiscountCard = TT_SalesOrderHeader.DiscountCard
	|				AND TT_SalesOrderHeaderMin.DocumentCurrency = TT_SalesOrderHeader.DocumentCurrency
	|				AND TT_SalesOrderHeaderMin.AmountIncludesVAT = TT_SalesOrderHeader.AmountIncludesVAT
	|				AND TT_SalesOrderHeaderMin.IncludeVATInPrice = TT_SalesOrderHeader.IncludeVATInPrice
	|				AND TT_SalesOrderHeaderMin.VATTaxation = TT_SalesOrderHeader.VATTaxation
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_SalesOrderHeaderMin.Company,
	|		TT_SalesOrderHeaderMin.Counterparty,
	|		TT_SalesOrderHeader.Ref
	|	FROM
	|		TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|			INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|			ON (&SimpleCheck)
	|				AND TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|				AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty) AS InnerTable
	|
	|GROUP BY
	|	InnerTable.MinRef,
	|	InnerTable.Counterparty,
	|	InnerTable.Ref
	|TOTALS BY
	|	MinRef,
	|	Counterparty";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("SimpleCheck", SimpleCheck);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			SelCounterparty = SelGroups.Select(QueryResultIteration.ByGroups);
			
			While SelCounterparty.Next() Do
				OrdersArray = New Array;
				
				Sel = SelCounterparty.Select();
				While Sel.Next() Do
					OrdersArray.Add(Sel.Ref);
				EndDo;
				
				GroupsArray.Add(OrdersArray);
			EndDo;
		EndDo;
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckOrdersAndInvoicesKeyAttributesForGoodsIssue(OrdersInvoicesArray) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrderHeader.Company AS Company,
	|	SalesOrderHeader.Counterparty AS Counterparty,
	|	SalesOrderHeader.ShippingAddress AS ShippingAddress,
	|	SalesOrderHeader.Ref AS Ref
	|INTO TT_SalesOrderHeader
	|FROM
	|	Document.SalesOrder AS SalesOrderHeader
	|WHERE
	|	SalesOrderHeader.Ref IN(&OrdersInvoicesArray)
	|
	|UNION ALL
	|
	|SELECT
	|	SalesInvoice.Company,
	|	SalesInvoice.Counterparty,
	|	SalesInvoice.ShippingAddress,
	|	SalesInvoice.Ref
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&OrdersInvoicesArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeader.Company AS Company,
	|	TT_SalesOrderHeader.Counterparty AS Counterparty,
	|	TT_SalesOrderHeader.ShippingAddress AS ShippingAddress
	|INTO TT_SalesOrderHeaderMin
	|FROM
	|	TT_SalesOrderHeader AS TT_SalesOrderHeader
	|
	|GROUP BY
	|	TT_SalesOrderHeader.Company,
	|	TT_SalesOrderHeader.Counterparty,
	|	TT_SalesOrderHeader.ShippingAddress
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SalesOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT SalesOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SalesOrderHeader.ShippingAddress) AS ShippingAddress
	|INTO TT_SalesOrderHeaderCount
	|FROM
	|	TT_SalesOrderHeader AS SalesOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderCount.Company AS Company,
	|	TT_SalesOrderHeaderCount.Counterparty AS Counterparty,
	|	TT_SalesOrderHeaderCount.ShippingAddress AS ShippingAddress
	|FROM
	|	TT_SalesOrderHeaderCount AS TT_SalesOrderHeaderCount
	|WHERE
	|	(TT_SalesOrderHeaderCount.Company > 1
	|			OR TT_SalesOrderHeaderCount.Counterparty > 1
	|			OR TT_SalesOrderHeaderCount.ShippingAddress > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrderHeaderMin.Company AS Company,
	|	TT_SalesOrderHeaderMin.Counterparty AS Counterparty,
	|	TT_SalesOrderHeaderMin.ShippingAddress AS ShippingAddress,
	|	TT_SalesOrderHeader.Ref AS Ref
	|FROM
	|	TT_SalesOrderHeaderMin AS TT_SalesOrderHeaderMin
	|		INNER JOIN TT_SalesOrderHeader AS TT_SalesOrderHeader
	|		ON TT_SalesOrderHeaderMin.Company = TT_SalesOrderHeader.Company
	|			AND TT_SalesOrderHeaderMin.Counterparty = TT_SalesOrderHeader.Counterparty
	|			AND TT_SalesOrderHeaderMin.ShippingAddress = TT_SalesOrderHeader.ShippingAddress
	|
	|GROUP BY
	|	TT_SalesOrderHeaderMin.Company,
	|	TT_SalesOrderHeaderMin.Counterparty,
	|	TT_SalesOrderHeaderMin.ShippingAddress,
	|	TT_SalesOrderHeader.Ref
	|TOTALS BY
	|	Company,
	|	Counterparty,
	|	ShippingAddress";
	
	Query.SetParameter("OrdersInvoicesArray", OrdersInvoicesArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelectionCompany = Results[4].Select(QueryResultIteration.ByGroups);
		While SelectionCompany.Next() Do
			
			SelectionCounterparty = SelectionCompany.Select(QueryResultIteration.ByGroups);
			While SelectionCounterparty.Next() Do
				
				SelectionAddress = SelectionCounterparty.Select(QueryResultIteration.ByGroups);
				While SelectionAddress.Next() Do
					
					OrdersInvoicesArray = New Array;
					
					SelectionRef = SelectionAddress.Select();
					While SelectionRef.Next() Do
						OrdersInvoicesArray.Add(SelectionRef.Ref);
					EndDo;
					
					GroupsArray.Add(OrdersInvoicesArray);
					
				EndDo;
			EndDo;
		EndDo;
		
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function GetCheckedAttributesPresentationMap()
	
	Map = New Map;
	
	Map.Insert("Company",
		NStr("en = 'Company'"));
		
	Map.Insert("Counterparty",
		NStr("en = 'Counterparty'"));
		
	Map.Insert("Contract",
		NStr("en = 'Contract'"));
		
	Map.Insert("StructuralUnitReserve",
		NStr("en = 'Warehouse (reserve)'"));
		
	Map.Insert("StructuralUnit",
		NStr("en = 'Warehouse'"));
		
	Map.Insert("PriceKind",
		NStr("en = 'Price type'"));
		
	Map.Insert("DiscountMarkupKind",
		NStr("en = 'Discount type'"));
		
	Map.Insert("DiscountCard",
		NStr("en = 'Discount card'"));
		
	Map.Insert("DocumentCurrency",
		NStr("en = 'Currency'"));
		
	Map.Insert("AmountIncludesVAT",
		NStr("en = 'Amount includes VAT'"));
		
	Map.Insert("IncludeVATInPrice",
		NStr("en = 'Include VAT in cost'"));
		
	Map.Insert("VATTaxation",
		NStr("en = 'Tax category'"));
		
	Map.Insert("ShippingAddress",
		NStr("en = 'Shipping address'"));
	
	Return Map;
	
EndFunction

Function CheckPurchaseOrdersKeyAttributes(OrdersArray, SimpleCheck = False) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	PurchaseOrderHeader.Company AS Company,
	|	PurchaseOrderHeader.Counterparty AS Counterparty,
	|	PurchaseOrderHeader.Contract AS Contract,
	|	PurchaseOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	PurchaseOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	PurchaseOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrderHeader.VATTaxation AS VATTaxation,
	|	PurchaseOrderHeader.Ref AS Ref
	|INTO TT_PurchaseOrderHeader
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrderHeader
	|WHERE
	|	PurchaseOrderHeader.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrderHeader.Company AS Company,
	|	TT_PurchaseOrderHeader.Counterparty AS Counterparty,
	|	TT_PurchaseOrderHeader.Contract AS Contract,
	|	TT_PurchaseOrderHeader.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_PurchaseOrderHeader.DocumentCurrency AS DocumentCurrency,
	|	TT_PurchaseOrderHeader.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_PurchaseOrderHeader.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_PurchaseOrderHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_PurchaseOrderHeader.Ref) AS MinRef
	|INTO TT_PurchaseOrderHeaderMin
	|FROM
	|	TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|
	|GROUP BY
	|	TT_PurchaseOrderHeader.IncludeVATInPrice,
	|	TT_PurchaseOrderHeader.Company,
	|	TT_PurchaseOrderHeader.Contract,
	|	TT_PurchaseOrderHeader.StructuralUnitReserve,
	|	TT_PurchaseOrderHeader.DocumentCurrency,
	|	TT_PurchaseOrderHeader.AmountIncludesVAT,
	|	TT_PurchaseOrderHeader.VATTaxation,
	|	TT_PurchaseOrderHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT PurchaseOrderHeader.Company) AS Company,
	|	COUNT(DISTINCT PurchaseOrderHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT PurchaseOrderHeader.Contract) AS Contract,
	|	COUNT(DISTINCT PurchaseOrderHeader.StructuralUnitReserve) AS StructuralUnitReserve,
	|	COUNT(DISTINCT PurchaseOrderHeader.DocumentCurrency) AS DocumentCurrency,
	|	COUNT(DISTINCT PurchaseOrderHeader.AmountIncludesVAT) AS AmountIncludesVAT,
	|	COUNT(DISTINCT PurchaseOrderHeader.IncludeVATInPrice) AS IncludeVATInPrice,
	|	COUNT(DISTINCT PurchaseOrderHeader.VATTaxation) AS VATTaxation
	|INTO TT_PurchaseOrderHeaderCount
	|FROM
	|	TT_PurchaseOrderHeader AS PurchaseOrderHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrderHeaderCount.Company AS Company,
	|	TT_PurchaseOrderHeaderCount.Counterparty AS Counterparty,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.Contract
	|	END AS Contract,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.StructuralUnitReserve
	|	END AS StructuralUnitReserve,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.DocumentCurrency
	|	END AS DocumentCurrency,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.AmountIncludesVAT
	|	END AS AmountIncludesVAT,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.IncludeVATInPrice
	|	END AS IncludeVATInPrice,
	|	CASE
	|		WHEN &SimpleCheck
	|			THEN 0
	|		ELSE TT_PurchaseOrderHeaderCount.VATTaxation
	|	END AS VATTaxation
	|FROM
	|	TT_PurchaseOrderHeaderCount AS TT_PurchaseOrderHeaderCount
	|WHERE
	|	(TT_PurchaseOrderHeaderCount.Company > 1
	|			OR TT_PurchaseOrderHeaderCount.Counterparty > 1
	|			OR NOT &SimpleCheck
	|				AND (TT_PurchaseOrderHeaderCount.Contract > 1
	|					OR TT_PurchaseOrderHeaderCount.StructuralUnitReserve > 1
	|					OR TT_PurchaseOrderHeaderCount.DocumentCurrency > 1
	|					OR TT_PurchaseOrderHeaderCount.AmountIncludesVAT > 1
	|					OR TT_PurchaseOrderHeaderCount.IncludeVATInPrice > 1
	|					OR TT_PurchaseOrderHeaderCount.VATTaxation > 1))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InnerTable.MinRef AS MinRef,
	|	InnerTable.Counterparty AS Counterparty,
	|	InnerTable.Ref AS Ref
	|FROM
	|	(SELECT
	|		TT_PurchaseOrderHeaderMin.MinRef AS MinRef,
	|		TT_PurchaseOrderHeaderMin.Counterparty AS Counterparty,
	|		TT_PurchaseOrderHeader.Ref AS Ref
	|	FROM
	|		TT_PurchaseOrderHeaderMin AS TT_PurchaseOrderHeaderMin
	|			INNER JOIN TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|			ON (NOT &SimpleCheck)
	|				AND TT_PurchaseOrderHeaderMin.Company = TT_PurchaseOrderHeader.Company
	|				AND TT_PurchaseOrderHeaderMin.Counterparty = TT_PurchaseOrderHeader.Counterparty
	|				AND TT_PurchaseOrderHeaderMin.Contract = TT_PurchaseOrderHeader.Contract
	|				AND TT_PurchaseOrderHeaderMin.StructuralUnitReserve = TT_PurchaseOrderHeader.StructuralUnitReserve
	|				AND TT_PurchaseOrderHeaderMin.DocumentCurrency = TT_PurchaseOrderHeader.DocumentCurrency
	|				AND TT_PurchaseOrderHeaderMin.AmountIncludesVAT = TT_PurchaseOrderHeader.AmountIncludesVAT
	|				AND TT_PurchaseOrderHeaderMin.IncludeVATInPrice = TT_PurchaseOrderHeader.IncludeVATInPrice
	|				AND TT_PurchaseOrderHeaderMin.VATTaxation = TT_PurchaseOrderHeader.VATTaxation
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TT_PurchaseOrderHeaderMin.Company,
	|		TT_PurchaseOrderHeaderMin.Counterparty,
	|		TT_PurchaseOrderHeader.Ref
	|	FROM
	|		TT_PurchaseOrderHeaderMin AS TT_PurchaseOrderHeaderMin
	|			INNER JOIN TT_PurchaseOrderHeader AS TT_PurchaseOrderHeader
	|			ON (&SimpleCheck)
	|				AND TT_PurchaseOrderHeaderMin.Company = TT_PurchaseOrderHeader.Company
	|				AND TT_PurchaseOrderHeaderMin.Counterparty = TT_PurchaseOrderHeader.Counterparty) AS InnerTable
	|
	|GROUP BY
	|	InnerTable.MinRef,
	|	InnerTable.Counterparty,
	|	InnerTable.Ref
	|TOTALS BY
	|	MinRef,
	|	Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_PurchaseOrderHeaderCount.Company AS Company,
	|	TT_PurchaseOrderHeaderCount.Counterparty AS Counterparty,
	|	TT_PurchaseOrderHeaderCount.Contract AS Contract,
	|	TT_PurchaseOrderHeaderCount.StructuralUnitReserve AS StructuralUnitReserve,
	|	TT_PurchaseOrderHeaderCount.DocumentCurrency AS DocumentCurrency,
	|	TT_PurchaseOrderHeaderCount.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_PurchaseOrderHeaderCount.IncludeVATInPrice AS IncludeVATInPrice,
	|	TT_PurchaseOrderHeaderCount.VATTaxation AS VATTaxation
	|FROM
	|	TT_PurchaseOrderHeaderCount AS TT_PurchaseOrderHeaderCount";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("SimpleCheck", SimpleCheck);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			SelCounterparty = SelGroups.Select(QueryResultIteration.ByGroups);
			
			While SelCounterparty.Next() Do
				OrdersArray = New Array;
				
				Sel = SelCounterparty.Select();
				While Sel.Next() Do
					OrdersArray.Add(Sel.Ref);
				EndDo;
				
				GroupsArray.Add(OrdersArray);
			EndDo;
		EndDo;
		DataStructure.Insert("OrdersGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckGoodsReceiptKeyAttributes(GoodsReceiptArray) Export
	
	DataStructure = New Structure;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	GoodsReceiptHeader.Contract AS Contract,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	GoodsReceiptHeader.Order AS Order,
	|	GoodsReceiptHeader.Ref AS Ref
	|INTO TT_GoodsReceipt
	|FROM
	|	Document.GoodsReceipt AS GoodsReceiptHeader
	|WHERE
	|	GoodsReceiptHeader.Ref IN(&GoodsReceiptArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	GoodsReceiptHeader.Company AS Company,
	|	GoodsReceiptHeader.Counterparty AS Counterparty,
	|	CASE
	|		WHEN GoodsReceiptProducts.Contract <> VALUE(Catalog.CounterpartyContracts.EmptyRef)
	|			THEN GoodsReceiptProducts.Contract
	|		ELSE GoodsReceiptHeader.Contract
	|	END AS Contract,
	|	GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN GoodsReceiptProducts.Order <> VALUE(Document.PurchaseOrder.EmptyRef)
	|			THEN GoodsReceiptProducts.Order
	|		ELSE GoodsReceiptHeader.Order
	|	END AS Order,
	|	GoodsReceiptHeader.Ref AS Ref
	|INTO TT_GoodsReceiptHeader
	|FROM
	|	TT_GoodsReceipt AS GoodsReceiptHeader
	|		LEFT JOIN Document.GoodsReceipt.Products AS GoodsReceiptProducts
	|		ON GoodsReceiptHeader.Ref = GoodsReceiptProducts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	PurchaseOrder.DocumentCurrency AS DocumentCurrency,
	|	PurchaseOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	PurchaseOrder.VATTaxation AS VATTaxation,
	|	PurchaseOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	TT_GoodsReceiptHeader.Company AS Company,
	|	TT_GoodsReceiptHeader.Counterparty AS Counterparty,
	|	TT_GoodsReceiptHeader.Contract AS Contract,
	|	TT_GoodsReceiptHeader.StructuralUnit AS StructuralUnit,
	|	TT_GoodsReceiptHeader.Order AS Order,
	|	TT_GoodsReceiptHeader.Ref AS Ref
	|INTO TT_GoodsReceiptAndOrders
	|FROM
	|	TT_GoodsReceiptHeader AS TT_GoodsReceiptHeader
	|		INNER JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON TT_GoodsReceiptHeader.Order = PurchaseOrder.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SUM(Total.Company) AS Company,
	|	SUM(Total.Counterparty) AS Counterparty,
	|	SUM(Total.Contract) AS Contract,
	|	SUM(Total.StructuralUnit) AS StructuralUnit,
	|	SUM(Total.DocumentCurrency) AS DocumentCurrency,
	|	SUM(Total.IncludeVATInPrice) AS IncludeVATInPrice,
	|	SUM(Total.VATTaxation) AS VATTaxation,
	|	SUM(Total.AmountIncludesVAT) AS AmountIncludesVAT
	|FROM
	|	(SELECT
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.Company) AS Company,
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.Counterparty) AS Counterparty,
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.Contract) AS Contract,
	|		COUNT(DISTINCT TT_GoodsReceiptHeader.StructuralUnit) AS StructuralUnit,
	|		0 AS DocumentCurrency,
	|		0 AS IncludeVATInPrice,
	|		0 AS VATTaxation,
	|		0 AS AmountIncludesVAT
	|	FROM
	|		TT_GoodsReceiptHeader AS TT_GoodsReceiptHeader
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		0,
	|		0,
	|		0,
	|		0,
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.DocumentCurrency),
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.IncludeVATInPrice),
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.VATTaxation),
	|		COUNT(DISTINCT TT_GoodsReceiptAndOrders.AmountIncludesVAT)
	|	FROM
	|		TT_GoodsReceiptAndOrders AS TT_GoodsReceiptAndOrders) AS Total
	|
	|HAVING
	|	(SUM(Total.Company) > 1
	|		OR SUM(Total.Counterparty) > 1
	|		OR SUM(Total.Contract) > 1
	|		OR SUM(Total.StructuralUnit) > 1
	|		OR SUM(Total.DocumentCurrency) > 1
	|		OR SUM(Total.IncludeVATInPrice) > 1
	|		OR SUM(Total.VATTaxation) > 1
	|		OR SUM(Total.AmountIncludesVAT) > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_GoodsReceiptHeader.Ref AS Ref,
	|	TT_GoodsReceiptHeader.Contract AS Contract
	|FROM
	|	TT_GoodsReceiptHeader AS TT_GoodsReceiptHeader
	|TOTALS BY
	|	Contract";

	Query.SetParameter("GoodsReceiptArray", GoodsReceiptArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleInvoices", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleInvoices", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			OrdersArray = New Array;
			
			Sel = SelGroups.Select();
			While Sel.Next() Do
				OrdersArray.Add(New Structure("Ref, Contract", Sel.Ref, Sel.Contract));
			EndDo;
			
			GroupsArray.Add(OrdersArray);
		EndDo;
		DataStructure.Insert("GoodsReceiptGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

Function CheckSupplierInvoicesKeyAttributes(InvoicesArray) Export
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SupplierInvoiceHeader.Company AS Company,
	|	SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	SupplierInvoiceHeader.Contract AS Contract,
	|	SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	SupplierInvoiceHeader.Ref AS Ref
	|INTO TT_SupplierInvoiceHeader
	|FROM
	|	Document.SupplierInvoice AS SupplierInvoiceHeader
	|WHERE
	|	SupplierInvoiceHeader.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeader.Company AS Company,
	|	TT_SupplierInvoiceHeader.Counterparty AS Counterparty,
	|	TT_SupplierInvoiceHeader.Contract AS Contract,
	|	TT_SupplierInvoiceHeader.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeader.VATTaxation AS VATTaxation,
	|	MIN(TT_SupplierInvoiceHeader.Ref) AS MinRef
	|INTO TT_SupplierInvoiceHeaderMin
	|FROM
	|	TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|
	|GROUP BY
	|	TT_SupplierInvoiceHeader.Company,
	|	TT_SupplierInvoiceHeader.Contract,
	|	TT_SupplierInvoiceHeader.StructuralUnit,
	|	TT_SupplierInvoiceHeader.VATTaxation,
	|	TT_SupplierInvoiceHeader.Counterparty
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(DISTINCT SupplierInvoiceHeader.Company) AS Company,
	|	COUNT(DISTINCT SupplierInvoiceHeader.Counterparty) AS Counterparty,
	|	COUNT(DISTINCT SupplierInvoiceHeader.Contract) AS Contract,
	|	COUNT(DISTINCT SupplierInvoiceHeader.StructuralUnit) AS StructuralUnit,
	|	COUNT(DISTINCT SupplierInvoiceHeader.VATTaxation) AS VATTaxation
	|INTO TT_SupplierInvoiceHeaderCount
	|FROM
	|	TT_SupplierInvoiceHeader AS SupplierInvoiceHeader
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeaderCount.Company AS Company,
	|	TT_SupplierInvoiceHeaderCount.Counterparty AS Counterparty,
	|	TT_SupplierInvoiceHeaderCount.Contract AS Contract,
	|	TT_SupplierInvoiceHeaderCount.StructuralUnit AS StructuralUnit,
	|	TT_SupplierInvoiceHeaderCount.VATTaxation AS VATTaxation
	|FROM
	|	TT_SupplierInvoiceHeaderCount AS TT_SupplierInvoiceHeaderCount
	|WHERE
	|	(TT_SupplierInvoiceHeaderCount.Company > 1
	|			OR TT_SupplierInvoiceHeaderCount.Counterparty > 1
	|			OR TT_SupplierInvoiceHeaderCount.Contract > 1
	|			OR TT_SupplierInvoiceHeaderCount.StructuralUnit > 1
	|			OR TT_SupplierInvoiceHeaderCount.VATTaxation > 1)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SupplierInvoiceHeaderMin.MinRef AS MinRef,
	|	TT_SupplierInvoiceHeader.Ref AS Ref
	|FROM
	|	TT_SupplierInvoiceHeaderMin AS TT_SupplierInvoiceHeaderMin
	|		INNER JOIN TT_SupplierInvoiceHeader AS TT_SupplierInvoiceHeader
	|		ON TT_SupplierInvoiceHeaderMin.Company = TT_SupplierInvoiceHeader.Company
	|			AND TT_SupplierInvoiceHeaderMin.Counterparty = TT_SupplierInvoiceHeader.Counterparty
	|			AND TT_SupplierInvoiceHeaderMin.Contract = TT_SupplierInvoiceHeader.Contract
	|			AND TT_SupplierInvoiceHeaderMin.StructuralUnit = TT_SupplierInvoiceHeader.StructuralUnit
	|			AND TT_SupplierInvoiceHeaderMin.VATTaxation = TT_SupplierInvoiceHeader.VATTaxation
	|TOTALS BY
	|	MinRef";
	
	Query.SetParameter("OrdersArray", InvoicesArray);
	Results = Query.ExecuteBatch();
	
	Result_MultipleData = Results[3];
	
	If Result_MultipleData.IsEmpty() Then
		
		DataStructure.Insert("CreateMultipleCustomsDeclarations", False);
		DataStructure.Insert("DataPresentation", "");
		
	Else
		
		DataStructure.Insert("CreateMultipleCustomsDeclarations", True);
		
		DataPresentation = "";
		AttributesPresentationMap = GetCheckedAttributesPresentationMap();
		
		Selection = Result_MultipleData.Select();
		If Selection.Next() Then
			
			For Each Column In Result_MultipleData.Columns Do
				AttributeName = Column.Name;
				If Selection[AttributeName] > 1 Then
					
					AttributePresentaion = AttributesPresentationMap[AttributeName];
					If AttributePresentaion = Undefined Then
						AttributePresentaion = AttributeName;
					EndIf;
					
					DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "", ", ") + AttributePresentaion;
					
				EndIf;
			EndDo;
			
		EndIf;
		DataStructure.Insert("DataPresentation", DataPresentation);
		
		GroupsArray = New Array;
		SelGroups = Results[4].Select(QueryResultIteration.ByGroups);
		While SelGroups.Next() Do
			InvoicesArray = New Array;
			Sel = SelGroups.Select();
			While Sel.Next() Do
				InvoicesArray.Add(Sel.Ref);
			EndDo;
			GroupsArray.Add(InvoicesArray);
		EndDo;
		DataStructure.Insert("InvoicesGroups", GroupsArray);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

#EndRegion

#EndRegion

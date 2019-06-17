#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Period") Then
		Record.Period = Parameters.Period;
	ElsIf Record.SourceRecordKey.IsEmpty() Then
		Record.Period = BegOfYear(CurrentDate());
	EndIf; 
	
	If Parameters.Property("Company") Then
		Record.Company = Parameters.Company;
		Items.Company.Visible = False;
	EndIf;
	
	If NOT ValueIsFilled(Record.Company) Then
		Record.Company = Catalogs.Companies.MainCompany;
	EndIf;
	
	If Not Record.RegisteredForVAT Then
		ChangeRegisteredForVATAtServer();
	EndIf;
	
	ChangeEnabled();
	
	Company				= Record.Company;
	Period				= Record.Period;
	RegisteredForVAT	= Record.RegisteredForVAT;
	
	PostAdvancePaymentsBySourceDocuments = Record.PostAdvancePaymentsBySourceDocuments;
	PostVATEntriesBySourceDocuments = Record.PostVATEntriesBySourceDocuments;
	InventoryValuationMethod = Record.InventoryValuationMethod;
	
	SetIssueAutomaticallyAgainstSales();
	
EndProcedure

&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	WriteParameters.Insert("Company",	Company);
	WriteParameters.Insert("Period",	Period);
	WriteParameters.Insert("UseGoodsReturnFromCustomer",	Record.UseGoodsReturnFromCustomer);
	WriteParameters.Insert("UseGoodsReturnToSupplier",		Record.UseGoodsReturnToSupplier);
	WriteParameters.Insert("InventoryValuationMethod",		Record.InventoryValuationMethod);
	
	Record.UseGoodsReturnFromCustomer	= ?(UseGoodsReturnFromCustomer = PredefinedValue("Enum.YesNo.Yes"), True, False);
	Record.UseGoodsReturnToSupplier		= ?(UseGoodsReturnToSupplier = PredefinedValue("Enum.YesNo.Yes"), True, False);
	
	Record.InventoryValuationMethod = InventoryValuationMethod;
	
	Record.PostAdvancePaymentsBySourceDocuments = PostAdvancePaymentsBySourceDocuments;
	Record.PostVATEntriesBySourceDocuments = PostVATEntriesBySourceDocuments;
	Record.ObsoleteUseTaxInvoices = Not PostVATEntriesBySourceDocuments;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CompanyWasChanged	= WriteParameters.Company <> Record.Company; 
	PeriodWasChanged	= WriteParameters.Period <> Record.Period; 
	UseGoodsReturnFromCustomerWasChanged = WriteParameters.UseGoodsReturnFromCustomer <> Record.UseGoodsReturnFromCustomer;
	UseGoodsReturnToSupplierWasChanged	 = WriteParameters.UseGoodsReturnToSupplier <> Record.UseGoodsReturnToSupplier;
	InventoryValuationMethodWasChanged	 = WriteParameters.InventoryValuationMethod <> Record.InventoryValuationMethod;

	If CompanyWasChanged
		Or PeriodWasChanged
		Or UseGoodsReturnFromCustomerWasChanged
		Or UseGoodsReturnToSupplierWasChanged 
		Or InventoryValuationMethodWasChanged Then
		
		Query = New Query;
		Query.Text = 
		"SELECT
		|	MAX(GoodsReturn.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.FromCustomer)) AS FromCustomer,
		|	MAX(GoodsReturn.OperationKind = VALUE(Enum.OperationTypesGoodsReturn.ToSupplier)) AS ToSupplier,
		|	GoodsReturn.Date AS Date,
		|	GoodsReturn.Company AS Company
		|INTO Documents
		|FROM
		|	Document.GoodsReturn AS GoodsReturn
		|WHERE
		|	GoodsReturn.Posted
		|	AND GoodsReturn.Date > &Period
		|	AND GoodsReturn.Company = &Company
		|
		|GROUP BY
		|	GoodsReturn.Date,
		|	GoodsReturn.Company
		|
		|UNION ALL
		|
		|SELECT
		|	TRUE,
		|	FALSE,
		|	CreditNote.Date,
		|	CreditNote.Company
		|FROM
		|	Document.CreditNote AS CreditNote
		|WHERE
		|	CreditNote.Posted
		|	AND CreditNote.Date > &Period
		|	AND CreditNote.Company = &Company
		|
		|GROUP BY
		|	CreditNote.Date,
		|	CreditNote.Company
		|
		|UNION ALL
		|
		|SELECT
		|	FALSE,
		|	TRUE,
		|	DebitNote.Date,
		|	DebitNote.Company
		|FROM
		|	Document.DebitNote AS DebitNote
		|WHERE
		|	DebitNote.Posted
		|	AND DebitNote.Date > &Period
		|	AND DebitNote.Company = &Company
		|
		|GROUP BY
		|	DebitNote.Date,
		|	DebitNote.Company
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT TOP 1
		|	Inventory.Period AS Period,
		|	Inventory.Company AS Company
		|INTO SalesDocuments
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.Period >= &Period
		|	AND Inventory.Company = &Company
		|	AND &InventoryValuationMethodWasChanged
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	GoodsReturn.Company AS Company,
		|	MAX(AccountingPolicy.Period) AS Period,
		|	GoodsReturn.Date AS Date,
		|	GoodsReturn.FromCustomer AS FromCustomer,
		|	GoodsReturn.ToSupplier AS ToSupplier
		|INTO MaxPeriod
		|FROM
		|	Documents AS GoodsReturn
		|		LEFT JOIN InformationRegister.AccountingPolicy AS AccountingPolicy
		|		ON GoodsReturn.Company = AccountingPolicy.Company
		|			AND GoodsReturn.Date >= AccountingPolicy.Period
		|
		|GROUP BY
		|	GoodsReturn.Company,
		|	GoodsReturn.Date,
		|	GoodsReturn.FromCustomer,
		|	GoodsReturn.ToSupplier
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	MaxPeriod.Company AS Company,
		|	MaxPeriod.Period AS Period,
		|	MaxPeriod.Date AS Date
		|FROM
		|	MaxPeriod AS MaxPeriod
		|WHERE
		|	MaxPeriod.Period = &Period
		|	AND &UseGoodsReturnFromCustomerWasChanged
		|	AND MaxPeriod.FromCustomer
		|
		|UNION ALL
		|
		|SELECT
		|	MaxPeriod.Company AS Company,
		|	MaxPeriod.Period AS Period,
		|	MaxPeriod.Date AS Date
		|FROM
		|	MaxPeriod AS MaxPeriod
		|WHERE
		|	MaxPeriod.Period = &Period
		|	AND &UseGoodsReturnToSupplierWasChanged
		|	AND MaxPeriod.ToSupplier
		|
		|UNION ALL
		|
		|SELECT
		|	MaxPeriod.Company AS Company,
		|	MaxPeriod.Period AS Period,
		|	MaxPeriod.Date AS Date
		|FROM
		|	MaxPeriod AS MaxPeriod
		|WHERE
		|	MaxPeriod.Period < &Period
		|	AND MaxPeriod.Date > &Period
		|
		|UNION ALL
		|
		|SELECT
		|	Inventory.Company AS Company,
		|	Inventory.Period AS Period,
		|	Inventory.Period AS Date
		|FROM
		|	SalesDocuments AS Inventory
		|";
		
		Query.SetParameter("Company",	CurrentObject.Company);
		Query.SetParameter("Period",	CurrentObject.Period);
		Query.SetParameter("UseGoodsReturnFromCustomerWasChanged",	UseGoodsReturnFromCustomerWasChanged);
		Query.SetParameter("UseGoodsReturnToSupplierWasChanged",	UseGoodsReturnToSupplierWasChanged);
		Query.SetParameter("InventoryValuationMethodWasChanged",	InventoryValuationMethodWasChanged);
		
		QueryResult = Query.Execute();
		If Not QueryResult.IsEmpty() Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'There are documents which were created with the current accounting policy setting.
					|To apply the new settings, please create a new accounting policy setting.'")
				,,,,
				Cancel);
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure AfterWrite(WriteParameters)
	
	If RegisteredForVAT <> Record.RegisteredForVAT 
		OR PostVATEntriesBySourceDocuments <> Record.PostVATEntriesBySourceDocuments
		OR UseGoodsReturnFromCustomer <> Record.UseGoodsReturnFromCustomer
		OR UseGoodsReturnToSupplier <> Record.UseGoodsReturnToSupplier Then
		
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtClient
Procedure RegisteredForVATOnChange(Item)
	
	Items.GroupVATOptionsRight.Enabled = Record.RegisteredForVAT;
	
	If Not Record.RegisteredForVAT Then
		ChangeRegisteredForVATAtServer();
	EndIf;

EndProcedure

&AtClient
Procedure PostVATEntriesBySourceDocumentsOnChange(Item)
	PostVATEntriesBySourceDocumentsAtServer();
	SetIssueAutomaticallyAgainstSales();
EndProcedure

&AtClient
Procedure PostAdvancePaymentsBySourceDocumentsOnChange(Item)
	PostAdvancePaymentsBySourceDocumentsAtServer();
EndProcedure

#EndRegion

#Region OtherProceduresAndFunctions

&AtServer
Procedure SetIssueAutomaticallyAgainstSales()
	
	Items.IssueAutomaticallyAgainstSales.Enabled = Not PostVATEntriesBySourceDocuments;
	
	If PostVATEntriesBySourceDocuments
		AND AccessRight("Update", Metadata.InformationRegisters.AccountingPolicy) Then
		Record.IssueAutomaticallyAgainstSales = False;
	EndIf;
	
EndProcedure

&AtServer
Procedure ChangeRegisteredForVATAtServer()
	
	Option = New Structure("Name, Synonym",
		"RegisteredForVAT",
		Metadata.InformationRegisters.AccountingPolicy.Resources.RegisteredForVAT.Synonym);
		
	CheckVATRecords(Option);
	
	Items.GroupVATOptionsRight.Enabled = Record.RegisteredForVAT;
	If Not Record.RegisteredForVAT Then
		Record.IssueAutomaticallyAgainstSales = False;
		Record.PostAdvancePaymentsBySourceDocuments = True;
		Record.PostVATEntriesBySourceDocuments = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure PostVATEntriesBySourceDocumentsAtServer()
	
	Record.PostVATEntriesBySourceDocuments = PostVATEntriesBySourceDocuments;
	
	Option = New Structure("Name, Synonym",
		"PostVATEntriesBySourceDocuments",
		Metadata.InformationRegisters.AccountingPolicy.Resources.PostVATEntriesBySourceDocuments.Synonym);
		
	CheckVATRecords(Option);
	
	PostVATEntriesBySourceDocuments = Record.PostVATEntriesBySourceDocuments;
	
EndProcedure

&AtServer
Procedure CheckVATRecords(Option)
	
	Query = New Query(
	"SELECT
	|	&MaxDate AS AfterDate,
	|	&Period AS BeforeDate,
	|	&Company AS Company
	|INTO CurrentPolicy
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(Policy.Period) AS AfterDate,
	|	&MaxDate AS BeforeDate,
	|	Policy.Company AS Company
	|INTO VATPeriod
	|FROM
	|	InformationRegister.AccountingPolicy AS Policy
	|WHERE
	|	Policy.Period > &Period
	|	AND Policy.Company = &Company
	|	AND TRUE
	|
	|GROUP BY
	|	Policy.Company
	|
	|UNION ALL
	|
	|SELECT
	|	&MinDate,
	|	MAX(Policy.Period),
	|	Policy.Company
	|FROM
	|	InformationRegister.AccountingPolicy AS Policy
	|WHERE
	|	Policy.Period < &Period
	|	AND Policy.Company = &Company
	|	AND TRUE
	|
	|GROUP BY
	|	Policy.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ISNULL(Boundary.AfterDate, CurrentPolicy.AfterDate)) AS End,
	|	MAX(ISNULL(Boundary.BeforeDate, CurrentPolicy.BeforeDate)) AS Start,
	|	CurrentPolicy.Company AS Company
	|INTO Boundary
	|FROM
	|	CurrentPolicy AS CurrentPolicy
	|		LEFT JOIN VATPeriod AS Boundary
	|		ON (TRUE)
	|
	|GROUP BY
	|	CurrentPolicy.Company
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	1
	|FROM
	|	AccumulationRegister.VATIncurred AS VATIncurred
	|		INNER JOIN Boundary AS Boundary
	|		ON VATIncurred.Company = Boundary.Company
	|			AND VATIncurred.Period >= Boundary.Start
	|			AND VATIncurred.Period <= Boundary.End
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	1
	|FROM
	|	AccumulationRegister.VATInput AS VATInput
	|		INNER JOIN Boundary AS Boundary
	|		ON VATInput.Company = Boundary.Company
	|			AND VATInput.Period >= Boundary.Start
	|			AND VATInput.Period <= Boundary.End
	|
	|UNION ALL
	|
	|SELECT TOP 1
	|	1
	|FROM
	|	AccumulationRegister.VATOutput AS VATOutput
	|		INNER JOIN Boundary AS Boundary
	|		ON VATOutput.Company = Boundary.Company
	|			AND VATOutput.Period >= Boundary.Start
	|			AND VATOutput.Period <= Boundary.End");
	
	Query.Text = StrReplace(Query.Text, "AND TRUE", "AND Policy." + Option.Name);
	
	Query.SetParameter("MinDate", Date("00010101"));
	Query.SetParameter("MaxDate", Date("39991231"));
	Query.SetParameter("Period", Record.Period);
	Query.SetParameter("Company", Record.Company);
	
	If Not Query.Execute().IsEmpty() Then
		
		TextMessage = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'You can''t change the option ""%1"" because there are records in VAT registers.'"),
			Option.Synonym);
			
		CommonUseClientServer.MessageToUser(TextMessage);
			
		// Return the previous value
		Record[Option.Name] = Not Record[Option.Name];
	EndIf;

EndProcedure

&AtServer
Procedure PostAdvancePaymentsBySourceDocumentsAtServer()
	
	Record.PostAdvancePaymentsBySourceDocuments = PostAdvancePaymentsBySourceDocuments;
	
	Option = New Structure("Name, Synonym",
		"PostAdvancePaymentsBySourceDocuments",
		Metadata.InformationRegisters.AccountingPolicy.Resources.PostAdvancePaymentsBySourceDocuments.Synonym);
		
	CheckVATRecords(Option);
	
	PostAdvancePaymentsBySourceDocuments = Record.PostAdvancePaymentsBySourceDocuments;
	
EndProcedure

Procedure ChangeEnabled()
	
	UseGoodsReturnFromCustomer		= ?(Record.UseGoodsReturnFromCustomer, Enums.YesNo.Yes, Enums.YesNo.No);
	UseGoodsReturnToSupplier		= ?(Record.UseGoodsReturnToSupplier, Enums.YesNo.Yes, Enums.YesNo.No);
	
EndProcedure

#EndRegion
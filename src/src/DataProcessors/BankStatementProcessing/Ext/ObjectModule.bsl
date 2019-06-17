
#Region ImportCheck

Procedure CheckAndFillInImportTable(IsImport) Export
	
	MapImportTable();
	CheckTable(Import, IsImport);
	
EndProcedure

Procedure CheckTable(Table, IsImport) Export
	
	ErrorTable.Clear();
	
	ErrorID				= 1;
	FuncOptCompanies	= NOT GetFunctionalOption("MultipleCompaniesAccounting") OR GetFunctionalOption("UseSeveralCompanies");
	MainCompany			= Catalogs.Companies.MainCompany;
	
	For Each Row In Table Do
		
		ErrorFound		= False;
		Row.ErrorID		= "";
		
		If FuncOptCompanies 
			AND NOT ValueIsFilled(Row.Company) Then
			Row.Company = MainCompany;
		EndIf;
		
		If (IsImport AND ValueIsFilled(Row.Document)) 
			Or (NOT IsImport AND ValueIsFilled(Row.ExportDate)) Then
			Row.ImageNumber = 0;
		Else
			
			Row.ImageNumber = 2;
			
			CheckRowErrors(Row, ErrorID, ErrorFound, IsImport);
			
			If ErrorFound Then
				ErrorID = ErrorID + 1;
			EndIf;
			
		EndIf;
		
	EndDo;
	
EndProcedure

Procedure MapImportTable()
	
	Query = New Query;
	Query.Text = GetMappingQueryText();
	
	Query.SetParameter("ImportedTable",	Import);
	Query.SetParameter("Bank",			Bank);
	
	TempTabManager = New TempTablesManager;
	Query.TempTablesManager = TempTabManager;
	
	QueryResult	= Query.Execute();
	Selection	= QueryResult.Select();
	
	If Selection.Next()
		AND Selection.NumberToFill > 0 Then
		
		If Selection.BankAccountToFill OR Selection.CounterpartyBankAccountToFill Then
			Query.Text	= GetBankAccountsMapQuery();
			QueryResult	= Query.Execute();
			Selection	= QueryResult.Select();
			Selection.Next();
		EndIf;
		
		If Selection.CompanyToFill Then
			Query.Text	= GetCompanyMapQuery();
			QueryResult	= Query.Execute();
			Selection	= QueryResult.Select();
			Selection.Next();
		EndIf;
		
		If Selection.CounterpartyToFill Then
			Query.Text = GetCounterpartyMapQuery();
			QueryResult	= Query.Execute();
			Selection	= QueryResult.Select();
			Selection.Next()
		EndIf;
		
		If Selection.ContractToFill Then
			Query.Text = GetContractsMapQuery();
			Query.Execute();
		EndIf;
		
	EndIf;
	
	Query.Text = 
	"SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	ImportedTableAfterMapping.Company AS Company,
	|	ImportedTableAfterMapping.BankAccount AS BankAccount,
	|	ImportedTableAfterMapping.OperationKind AS OperationKind,
	|	ImportedTableAfterMapping.DocumentKind AS DocumentKind,
	|	ImportedTableAfterMapping.Contract AS Contract,
	|	ImportedTableAfterMapping.Document AS Document,
	|	ImportedTableAfterMapping.Order AS Order,
	|	ImportedTableAfterMapping.Counterparty AS Counterparty,
	|	ImportedTableAfterMapping.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableAfterMapping.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableAfterMapping.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMapping.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMapping.CFItem AS CFItem,
	|	ImportedTableAfterMapping.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMapping.Amount AS Amount,
	|	ImportedTableAfterMapping.Received AS Received,
	|	ImportedTableAfterMapping.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMapping.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMapping.PaymentDate AS PaymentDate
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|
	|ORDER BY
	|	LineNumber";
	
	QueryResult = Query.Execute();
	Import.Load(QueryResult.Unload());
	
EndProcedure

Procedure CheckAndFillInExportTable(BankAccount, IsImport) Export
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	PaymentExpense.Ref AS Document,
		|	PaymentExpense.Company AS Company,
		|	PaymentExpense.Comment AS Comment,
		|	CASE
		|		WHEN PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.ToAdvanceHolder)
		|				OR PaymentExpense.OperationKind = VALUE(Enum.OperationTypesPaymentExpense.IssueLoanToEmployee)
		|			THEN PaymentExpense.AdvanceHolder
		|		ELSE PaymentExpense.Counterparty
		|	END AS Counterparty,
		|	PaymentExpense.OperationKind AS OperationKind,
		|	PaymentExpense.BankAccount AS BankAccount,
		|	PaymentExpense.DocumentAmount AS Amount,
		|	PaymentExpense.CounterpartyAccount AS CounterpartyBankAccount,
		|	PaymentExpense.PaymentPurpose AS PaymentPurpose,
		|	Counterparties.ContractByDefault AS Contract,
		|	PaymentExpense.ExportDate AS ExportDate,
		|	CASE
		|		WHEN PaymentExpense.ExportDate = DATETIME(1, 1, 1)
		|			THEN 2
		|		ELSE 0
		|	END AS ImageNumber,
		|	PaymentExpense.Paid AS Paid
		|FROM
		|	Document.PaymentExpense AS PaymentExpense
		|		LEFT JOIN Catalog.Counterparties AS Counterparties
		|		ON PaymentExpense.Counterparty = Counterparties.Ref
		|WHERE
		|	PaymentExpense.Date BETWEEN &StartPeriod AND &EndPeriod
		|	AND PaymentExpense.BankAccount = &BankAccount
		|	AND PaymentExpense.OperationKind IN(&OperationKinds)
		|	AND PaymentExpense.Posted
		|	AND NOT PaymentExpense.Paid
		|
		|ORDER BY
		|	PaymentExpense.Date";
	
	Query.SetParameter("StartPeriod", StartPeriod);
	Query.SetParameter("EndPeriod", ?(ValueIsFilled(EndPeriod), EndPeriod, CurrentDate()));
	Query.SetParameter("BankAccount", BankAccount);
	
	OperationKinds = New Array;
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.Vendor);
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.ToCustomer);
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.LoanSettlements);
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.OtherSettlements);
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.ToAdvanceHolder);
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.Taxes);
	OperationKinds.Add(Enums.OperationTypesPaymentExpense.IssueLoanToEmployee);
	Query.SetParameter("OperationKinds", OperationKinds);
	
	DocumentsForExport.Load(Query.Execute().Unload());
	
	CheckTable(DocumentsForExport, IsImport);
	
EndProcedure

Function GetMappingQueryText()
	
	Return 
	"SELECT
	|	ImportedTable.LineNumber AS LineNumber,
	|	ImportedTable.Company AS Company,
	|	ImportedTable.BankAccount AS BankAccount,
	|	ImportedTable.OperationKind AS OperationKind,
	|	ImportedTable.DocumentKind AS DocumentKind,
	|	ImportedTable.Contract AS Contract,
	|	ImportedTable.Document AS Document,
	|	ImportedTable.Order AS Order,
	|	ImportedTable.Counterparty AS Counterparty,
	|	ImportedTable.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTable.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTable.PaymentPurpose AS PaymentPurpose,
	|	ImportedTable.AdvanceFlag AS AdvanceFlag,
	|	ImportedTable.CFItem AS CFItem,
	|	ImportedTable.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTable.Amount AS Amount,
	|	ImportedTable.Received AS Received,
	|	ImportedTable.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTable.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	NOT(ImportedTable.ExternalDocumentDate = DATETIME(1, 1, 1, 0, 0, 0)
	|			OR (CAST(ImportedTable.ExternalDocumentNumber AS STRING(255))) = """") AS DocumentToFill,
	|	ImportedTable.DocumentKind = ""PaymentReceipt"" AS IsPaymentReceipt,
	|	ImportedTable.DocumentKind = ""PaymentExpense"" AS IsPaymentExpense,
	|	ImportedTable.PaymentDate AS PaymentDate
	|INTO ImportedTable
	|FROM
	|	&ImportedTable AS ImportedTable
	|
	|INDEX BY
	|	DocumentToFill,
	|	ExternalDocumentDate,
	|	ExternalDocumentNumber,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTable.LineNumber AS LineNumber,
	|	PaymentReceipt.Ref AS Ref,
	|	PaymentReceipt.ExternalDocumentDate AS ExternalDocumentDate,
	|	PaymentReceipt.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	PaymentReceipt.Company AS Company,
	|	PaymentReceipt.OperationKind AS OperationKind,
	|	PaymentReceipt.BankAccount AS BankAccount,
	|	PaymentReceipt.Counterparty AS Counterparty,
	|	PaymentReceipt.DocumentAmount AS DocumentAmount,
	|	PaymentReceipt.CounterpartyAccount AS CounterpartyAccount,
	|	PaymentReceipt.Item AS Item,
	|	PaymentReceipt.Date AS Date,
	|	PaymentReceipt.Number AS Number,
	|	PaymentReceipt.Correspondence AS Correspondence
	|INTO Documents
	|FROM
	|	ImportedTable AS ImportedTable
	|		INNER JOIN Document.PaymentReceipt AS PaymentReceipt
	|		ON (ImportedTable.DocumentToFill)
	|			AND ImportedTable.ExternalDocumentDate = PaymentReceipt.ExternalDocumentDate
	|			AND ImportedTable.ExternalDocumentNumber = PaymentReceipt.ExternalDocumentNumber
	|			AND (ImportedTable.IsPaymentReceipt)
	|WHERE
	|	NOT PaymentReceipt.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	ImportedTable.LineNumber,
	|	PaymentExpense.Ref,
	|	PaymentExpense.ExternalDocumentDate,
	|	PaymentExpense.ExternalDocumentNumber,
	|	PaymentExpense.Company,
	|	PaymentExpense.OperationKind,
	|	PaymentExpense.BankAccount,
	|	PaymentExpense.Counterparty,
	|	PaymentExpense.DocumentAmount,
	|	PaymentExpense.CounterpartyAccount,
	|	PaymentExpense.Item,
	|	PaymentExpense.Date,
	|	PaymentExpense.Number,
	|	PaymentExpense.Correspondence
	|FROM
	|	ImportedTable AS ImportedTable
	|		INNER JOIN Document.PaymentExpense AS PaymentExpense
	|		ON (ImportedTable.DocumentToFill)
	|			AND ImportedTable.ExternalDocumentDate = PaymentExpense.ExternalDocumentDate
	|			AND ImportedTable.ExternalDocumentNumber = PaymentExpense.ExternalDocumentNumber
	|			AND (ImportedTable.IsPaymentExpense)
	|WHERE
	|	NOT PaymentExpense.DeletionMark
	|
	|INDEX BY
	|	ExternalDocumentDate,
	|	ExternalDocumentNumber,
	|	Date,
	|	Number
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Documents.Number) AS Number,
	|	MAX(Documents.Date) AS Date,
	|	Documents.ExternalDocumentDate AS ExternalDocumentDate,
	|	Documents.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	Documents.LineNumber AS LineNumber
	|INTO DocumentsMaxDateAndNumber
	|FROM
	|	Documents AS Documents
	|
	|GROUP BY
	|	Documents.ExternalDocumentDate,
	|	Documents.ExternalDocumentNumber,
	|	Documents.LineNumber
	|
	|INDEX BY
	|	ExternalDocumentDate,
	|	ExternalDocumentNumber,
	|	Date,
	|	Number,
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Documents.Ref AS Ref,
	|	Documents.LineNumber AS LineNumber,
	|	Documents.ExternalDocumentDate AS ExternalDocumentDate,
	|	Documents.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	Documents.Company AS Company,
	|	Documents.OperationKind AS OperationKind,
	|	Documents.BankAccount AS BankAccount,
	|	Documents.Counterparty AS Counterparty,
	|	Documents.DocumentAmount AS DocumentAmount,
	|	Documents.CounterpartyAccount AS CounterpartyAccount,
	|	Documents.Item AS Item,
	|	Documents.Date AS Date,
	|	Documents.Number AS Number,
	|	Documents.Correspondence AS Correspondence
	|INTO DocumentSlice
	|FROM
	|	DocumentsMaxDateAndNumber AS DocumentsMaxDateAndNumber
	|		INNER JOIN Documents AS Documents
	|		ON DocumentsMaxDateAndNumber.ExternalDocumentDate = Documents.ExternalDocumentDate
	|			AND DocumentsMaxDateAndNumber.ExternalDocumentNumber = Documents.ExternalDocumentNumber
	|			AND DocumentsMaxDateAndNumber.Date = Documents.Date
	|			AND DocumentsMaxDateAndNumber.Number = Documents.Number
	|			AND DocumentsMaxDateAndNumber.LineNumber = Documents.LineNumber
	|
	|INDEX BY
	|	LineNumber,
	|	ExternalDocumentDate,
	|	ExternalDocumentNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTable.LineNumber AS LineNumber,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.Company
	|		ELSE DocumentSlice.Company
	|	END AS Company,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.BankAccount
	|		ELSE DocumentSlice.BankAccount
	|	END AS BankAccount,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.OperationKind
	|		ELSE DocumentSlice.OperationKind
	|	END AS OperationKind,
	|	ImportedTable.DocumentKind AS DocumentKind,
	|	ImportedTable.Contract AS Contract,
	|	ISNULL(DocumentSlice.Ref, ImportedTable.Document) AS Document,
	|	ImportedTable.Order AS Order,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.Counterparty
	|		ELSE DocumentSlice.Counterparty
	|	END AS Counterparty,
	|	ImportedTable.CounterpartyTIN AS CounterpartyTIN,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.CounterpartyBankAccount
	|		ELSE DocumentSlice.CounterpartyAccount
	|	END AS CounterpartyBankAccount,
	|	ImportedTable.PaymentPurpose AS PaymentPurpose,
	|	ImportedTable.AdvanceFlag AS AdvanceFlag,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.CFItem
	|		ELSE DocumentSlice.Item
	|	END AS CFItem,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.ExpenseGLAccount
	|		ELSE DocumentSlice.Correspondence
	|	END AS ExpenseGLAccount,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.Amount
	|		ELSE DocumentSlice.DocumentAmount
	|	END AS Amount,
	|	CASE
	|		WHEN DocumentSlice.Ref IS NULL
	|			THEN ImportedTable.Received
	|		ELSE DocumentSlice.Date
	|	END AS Received,
	|	ImportedTable.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTable.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	DocumentSlice.Ref IS NULL
	|		AND VALUETYPE(ImportedTable.Counterparty) = TYPE(STRING)
	|		AND NOT (CAST(ImportedTable.Counterparty AS STRING(255))) = """" AS CounterpartyToFill,
	|	DocumentSlice.Ref IS NULL
	|		AND VALUETYPE(ImportedTable.Company) = TYPE(STRING)
	|		AND NOT (CAST(ImportedTable.Company AS STRING(255))) = """" AS CompanyToFill,
	|	DocumentSlice.Ref IS NULL
	|		AND VALUETYPE(ImportedTable.BankAccount) = TYPE(STRING)
	|		AND NOT (CAST(ImportedTable.BankAccount AS STRING(255))) = """" AS BankAccountToFill,
	|	DocumentSlice.Ref IS NULL
	|		AND VALUETYPE(ImportedTable.CounterpartyBankAccount) = TYPE(STRING)
	|		AND NOT (CAST(ImportedTable.CounterpartyBankAccount AS STRING(255))) = """" AS CounterpartyBankAccountToFill,
	|	ImportedTable.PaymentDate AS PaymentDate
	|INTO ImportedTableWithDocuments
	|FROM
	|	ImportedTable AS ImportedTable
	|		LEFT JOIN DocumentSlice AS DocumentSlice
	|		ON (ImportedTable.DocumentToFill)
	|			AND ImportedTable.ExternalDocumentDate = DocumentSlice.ExternalDocumentDate
	|			AND ImportedTable.ExternalDocumentNumber = DocumentSlice.ExternalDocumentNumber
	|			AND ImportedTable.LineNumber = DocumentSlice.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	BankStatementMapping.Attribute AS Attribute,
	|	BankStatementMapping.ReceivedValue AS ReceivedValue,
	|	BankStatementMapping.Value AS Value
	|INTO BankMapping
	|FROM
	|	InformationRegister.BankStatementMapping AS BankStatementMapping
	|WHERE
	|	BankStatementMapping.Bank = &Bank
	|
	|INDEX BY
	|	Attribute,
	|	ReceivedValue
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableWithDocuments.LineNumber AS LineNumber,
	|	NULL AS Company,
	|	BankMapping.Value AS BankAccount,
	|	NULL AS Counterparty,
	|	NULL AS CounterpartyBankAccount
	|INTO BankAccountsMap
	|FROM
	|	ImportedTableWithDocuments AS ImportedTableWithDocuments
	|		INNER JOIN BankMapping AS BankMapping
	|		ON (BankMapping.Attribute = VALUE(Enum.BankMappingAttribute.BankAccount))
	|			AND (BankMapping.ReceivedValue = ImportedTableWithDocuments.BankAccount)
	|			AND (ImportedTableWithDocuments.BankAccountToFill)
	|
	|UNION ALL
	|
	|SELECT
	|	ImportedTableWithDocuments.LineNumber,
	|	NULL,
	|	NULL,
	|	NULL,
	|	BankMapping.Value
	|FROM
	|	ImportedTableWithDocuments AS ImportedTableWithDocuments
	|		INNER JOIN BankMapping AS BankMapping
	|		ON (BankMapping.Attribute = VALUE(Enum.BankMappingAttribute.CounterpartyBankAccount))
	|			AND (BankMapping.ReceivedValue = ImportedTableWithDocuments.CounterpartyBankAccount)
	|			AND (ImportedTableWithDocuments.CounterpartyBankAccountToFill)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Map.LineNumber AS LineNumber,
	|	MAX(Map.Company) AS Company,
	|	MAX(Map.BankAccount) AS BankAccount,
	|	MAX(Map.Counterparty) AS Counterparty,
	|	MAX(Map.CounterpartyBankAccount) AS CounterpartyBankAccount
	|INTO BankAccountsMapWithOwners
	|FROM
	|	(SELECT
	|		BankAccountsMap.LineNumber AS LineNumber,
	|		BankAccounts.Owner AS Company,
	|		BankAccountsMap.BankAccount AS BankAccount,
	|		NULL AS Counterparty,
	|		NULL AS CounterpartyBankAccount
	|	FROM
	|		BankAccountsMap AS BankAccountsMap
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON BankAccountsMap.BankAccount = BankAccounts.Ref
	|	WHERE
	|		NOT BankAccounts.DeletionMark
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		BankAccountsMap.LineNumber,
	|		NULL,
	|		NULL,
	|		BankAccounts.Owner,
	|		BankAccountsMap.CounterpartyBankAccount
	|	FROM
	|		BankAccountsMap AS BankAccountsMap
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON BankAccountsMap.CounterpartyBankAccount = BankAccounts.Ref
	|	WHERE
	|		NOT BankAccounts.DeletionMark) AS Map
	|
	|GROUP BY
	|	Map.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableWithDocuments.LineNumber AS LineNumber,
	|	ISNULL(BankAccountsMapWithOwners.Company, ImportedTableWithDocuments.Company) AS Company,
	|	ISNULL(BankAccountsMapWithOwners.BankAccount, ImportedTableWithDocuments.BankAccount) AS BankAccount,
	|	ImportedTableWithDocuments.OperationKind AS OperationKind,
	|	ImportedTableWithDocuments.DocumentKind AS DocumentKind,
	|	ImportedTableWithDocuments.Contract AS Contract,
	|	ImportedTableWithDocuments.Document AS Document,
	|	ImportedTableWithDocuments.Order AS Order,
	|	ISNULL(BankAccountsMapWithOwners.Counterparty, ImportedTableWithDocuments.Counterparty) AS Counterparty,
	|	ImportedTableWithDocuments.CounterpartyTIN AS CounterpartyTIN,
	|	ISNULL(BankAccountsMapWithOwners.CounterpartyBankAccount, ImportedTableWithDocuments.CounterpartyBankAccount) AS CounterpartyBankAccount,
	|	ImportedTableWithDocuments.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableWithDocuments.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableWithDocuments.CFItem AS CFItem,
	|	ImportedTableWithDocuments.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableWithDocuments.Amount AS Amount,
	|	ImportedTableWithDocuments.Received AS Received,
	|	ImportedTableWithDocuments.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableWithDocuments.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableWithDocuments.CounterpartyToFill
	|		AND BankAccountsMapWithOwners.Counterparty IS NULL AS CounterpartyToFill,
	|	ImportedTableWithDocuments.CompanyToFill
	|		AND BankAccountsMapWithOwners.Company IS NULL AS CompanyToFill,
	|	ImportedTableWithDocuments.BankAccountToFill
	|		AND BankAccountsMapWithOwners.BankAccount IS NULL AS BankAccountToFill,
	|	ImportedTableWithDocuments.CounterpartyBankAccountToFill
	|		AND BankAccountsMapWithOwners.CounterpartyBankAccount IS NULL AS CounterpartyBankAccountToFill,
	|	ImportedTableWithDocuments.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMappingWithBankAccounts
	|FROM
	|	ImportedTableWithDocuments AS ImportedTableWithDocuments
	|		LEFT JOIN BankAccountsMapWithOwners AS BankAccountsMapWithOwners
	|		ON ImportedTableWithDocuments.LineNumber = BankAccountsMapWithOwners.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompanyAndCounterpartyMapUngroupped.LineNumber AS LineNumber,
	|	MAX(CompanyAndCounterpartyMapUngroupped.Company) AS Company,
	|	MAX(CompanyAndCounterpartyMapUngroupped.Counterparty) AS Counterparty
	|INTO CompanyAndCounterpartyMap
	|FROM
	|	(SELECT
	|		ImportedTableAfterMappingWithBankAccounts.LineNumber AS LineNumber,
	|		BankMapping.Value AS Company,
	|		NULL AS Counterparty
	|	FROM
	|		ImportedTableAfterMappingWithBankAccounts AS ImportedTableAfterMappingWithBankAccounts
	|			INNER JOIN BankMapping AS BankMapping
	|			ON (BankMapping.Attribute = VALUE(Enum.BankMappingAttribute.Company))
	|				AND (BankMapping.ReceivedValue = ImportedTableAfterMappingWithBankAccounts.Company)
	|				AND (ImportedTableAfterMappingWithBankAccounts.CompanyToFill)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ImportedTableAfterMappingWithBankAccounts.LineNumber,
	|		NULL,
	|		BankMapping.Value
	|	FROM
	|		ImportedTableAfterMappingWithBankAccounts AS ImportedTableAfterMappingWithBankAccounts
	|			INNER JOIN BankMapping AS BankMapping
	|			ON (BankMapping.Attribute = VALUE(Enum.BankMappingAttribute.Counterparty))
	|				AND (BankMapping.ReceivedValue = ImportedTableAfterMappingWithBankAccounts.Counterparty)
	|				AND (ImportedTableAfterMappingWithBankAccounts.CounterpartyToFill)) AS CompanyAndCounterpartyMapUngroupped
	|
	|GROUP BY
	|	CompanyAndCounterpartyMapUngroupped.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableAfterMappingWithBankAccounts.LineNumber AS LineNumber,
	|	ISNULL(CompanyAndCounterpartyMap.Company, ImportedTableAfterMappingWithBankAccounts.Company) AS Company,
	|	ImportedTableAfterMappingWithBankAccounts.BankAccount AS BankAccount,
	|	ImportedTableAfterMappingWithBankAccounts.OperationKind AS OperationKind,
	|	ImportedTableAfterMappingWithBankAccounts.DocumentKind AS DocumentKind,
	|	ImportedTableAfterMappingWithBankAccounts.Contract AS Contract,
	|	ImportedTableAfterMappingWithBankAccounts.Document AS Document,
	|	ImportedTableAfterMappingWithBankAccounts.Order AS Order,
	|	ISNULL(CompanyAndCounterpartyMap.Counterparty, ImportedTableAfterMappingWithBankAccounts.Counterparty) AS Counterparty,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableAfterMappingWithBankAccounts.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMappingWithBankAccounts.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMappingWithBankAccounts.CFItem AS CFItem,
	|	ImportedTableAfterMappingWithBankAccounts.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMappingWithBankAccounts.Amount AS Amount,
	|	ImportedTableAfterMappingWithBankAccounts.Received AS Received,
	|	ImportedTableAfterMappingWithBankAccounts.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMappingWithBankAccounts.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyToFill
	|		AND CompanyAndCounterpartyMap.Counterparty IS NULL AS CounterpartyToFill,
	|	ImportedTableAfterMappingWithBankAccounts.CompanyToFill
	|		AND CompanyAndCounterpartyMap.Company IS NULL AS CompanyToFill,
	|	ImportedTableAfterMappingWithBankAccounts.BankAccountToFill AS BankAccountToFill,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyBankAccountToFill AS CounterpartyBankAccountToFill,
	|	ImportedTableAfterMappingWithBankAccounts.Contract = UNDEFINED
	|		OR VALUETYPE(ImportedTableAfterMappingWithBankAccounts.Contract) = TYPE(STRING)
	|			AND NOT (CAST(ImportedTableAfterMappingWithBankAccounts.Contract AS STRING(255))) = """"
	|		OR (CAST(ImportedTableAfterMappingWithBankAccounts.Contract AS Catalog.CounterpartyContracts)) = VALUE(Catalog.CounterpartyContracts.EmptyRef) AS ContractToFill,
	|	ImportedTableAfterMappingWithBankAccounts.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMapping
	|FROM
	|	ImportedTableAfterMappingWithBankAccounts AS ImportedTableAfterMappingWithBankAccounts
	|		LEFT JOIN CompanyAndCounterpartyMap AS CompanyAndCounterpartyMap
	|		ON ImportedTableAfterMappingWithBankAccounts.LineNumber = CompanyAndCounterpartyMap.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP BankAccountsMap
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP BankAccountsMapWithOwners
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableAfterMappingWithBankAccounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CompanyAndCounterpartyMap
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP BankMapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(ImportedTableAfterMapping.LineNumber) AS NumberToFill,
	|	COUNT(ImportedTableAfterMapping.CounterpartyToFill) AS CounterpartyToFill,
	|	COUNT(ImportedTableAfterMapping.CompanyToFill) AS CompanyToFill,
	|	COUNT(ImportedTableAfterMapping.BankAccountToFill) AS BankAccountToFill,
	|	COUNT(ImportedTableAfterMapping.CounterpartyBankAccountToFill) AS CounterpartyBankAccountToFill,
	|	COUNT(ImportedTableAfterMapping.ContractToFill) AS ContractToFill
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|WHERE
	|	(ImportedTableAfterMapping.CounterpartyToFill
	|			OR ImportedTableAfterMapping.CompanyToFill
	|			OR ImportedTableAfterMapping.BankAccountToFill
	|			OR ImportedTableAfterMapping.CounterpartyBankAccountToFill
	|			OR ImportedTableAfterMapping.ContractToFill)";

EndFunction

Function GetBankAccountsMapQuery()
	
	Return 
	"SELECT
	|	Map.LineNumber AS LineNumber,
	|	MAX(Map.Company) AS Company,
	|	MAX(Map.BankAccount) AS BankAccount,
	|	MAX(Map.Counterparty) AS Counterparty,
	|	MAX(Map.CounterpartyBankAccount) AS CounterpartyBankAccount
	|INTO BankAccountsMapWithOwners
	|FROM
	|	(SELECT
	|		ImportedTableAfterMapping.LineNumber AS LineNumber,
	|		BankAccounts.Owner AS Company,
	|		BankAccounts.Ref AS BankAccount,
	|		NULL AS Counterparty,
	|		NULL AS CounterpartyBankAccount
	|	FROM
	|		ImportedTableAfterMapping AS ImportedTableAfterMapping
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON ImportedTableAfterMapping.BankAccount = BankAccounts.AccountNo
	|				AND (ImportedTableAfterMapping.BankAccountToFill)
	|	WHERE
	|		NOT BankAccounts.DeletionMark
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ImportedTableAfterMapping.LineNumber,
	|		BankAccounts.Owner,
	|		BankAccounts.Ref,
	|		NULL,
	|		NULL
	|	FROM
	|		ImportedTableAfterMapping AS ImportedTableAfterMapping
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON ImportedTableAfterMapping.BankAccount = BankAccounts.IBAN
	|				AND (ImportedTableAfterMapping.BankAccountToFill)
	|	WHERE
	|		NOT BankAccounts.DeletionMark
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ImportedTableAfterMapping.LineNumber,
	|		NULL,
	|		NULL,
	|		BankAccounts.Owner,
	|		BankAccounts.Ref
	|	FROM
	|		ImportedTableAfterMapping AS ImportedTableAfterMapping
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON ImportedTableAfterMapping.CounterpartyBankAccount = BankAccounts.AccountNo
	|				AND (ImportedTableAfterMapping.CounterpartyBankAccountToFill)
	|	WHERE
	|		NOT BankAccounts.DeletionMark
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		ImportedTableAfterMapping.LineNumber,
	|		NULL,
	|		NULL,
	|		BankAccounts.Owner,
	|		BankAccounts.Ref
	|	FROM
	|		ImportedTableAfterMapping AS ImportedTableAfterMapping
	|			INNER JOIN Catalog.BankAccounts AS BankAccounts
	|			ON ImportedTableAfterMapping.CounterpartyBankAccount = BankAccounts.IBAN
	|				AND (ImportedTableAfterMapping.CounterpartyBankAccountToFill)
	|	WHERE
	|		NOT BankAccounts.DeletionMark) AS Map
	|
	|GROUP BY
	|	Map.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	ISNULL(BankAccountsMapWithOwners.Company, ImportedTableAfterMapping.Company) AS Company,
	|	ISNULL(BankAccountsMapWithOwners.BankAccount, ImportedTableAfterMapping.BankAccount) AS BankAccount,
	|	ImportedTableAfterMapping.OperationKind AS OperationKind,
	|	ImportedTableAfterMapping.DocumentKind AS DocumentKind,
	|	ImportedTableAfterMapping.Contract AS Contract,
	|	ImportedTableAfterMapping.Document AS Document,
	|	ImportedTableAfterMapping.Order AS Order,
	|	ISNULL(BankAccountsMapWithOwners.Counterparty, ImportedTableAfterMapping.Counterparty) AS Counterparty,
	|	ImportedTableAfterMapping.CounterpartyTIN AS CounterpartyTIN,
	|	ISNULL(BankAccountsMapWithOwners.CounterpartyBankAccount, ImportedTableAfterMapping.CounterpartyBankAccount) AS CounterpartyBankAccount,
	|	ImportedTableAfterMapping.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMapping.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMapping.CFItem AS CFItem,
	|	ImportedTableAfterMapping.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMapping.Amount AS Amount,
	|	ImportedTableAfterMapping.Received AS Received,
	|	ImportedTableAfterMapping.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMapping.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMapping.CounterpartyToFill
	|		AND BankAccountsMapWithOwners.Counterparty IS NULL AS CounterpartyToFill,
	|	ImportedTableAfterMapping.CompanyToFill
	|		AND BankAccountsMapWithOwners.Company IS NULL AS CompanyToFill,
	|	ImportedTableAfterMapping.ContractToFill AS ContractToFill,
	|	ImportedTableAfterMapping.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMappingWithBankAccounts
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		LEFT JOIN BankAccountsMapWithOwners AS BankAccountsMapWithOwners
	|		ON ImportedTableAfterMapping.LineNumber = BankAccountsMapWithOwners.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableAfterMapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP BankAccountsMapWithOwners
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableAfterMappingWithBankAccounts.LineNumber AS LineNumber,
	|	ImportedTableAfterMappingWithBankAccounts.Company AS Company,
	|	ImportedTableAfterMappingWithBankAccounts.BankAccount AS BankAccount,
	|	ImportedTableAfterMappingWithBankAccounts.OperationKind AS OperationKind,
	|	ImportedTableAfterMappingWithBankAccounts.DocumentKind AS DocumentKind,
	|	ImportedTableAfterMappingWithBankAccounts.Contract AS Contract,
	|	ImportedTableAfterMappingWithBankAccounts.Document AS Document,
	|	ImportedTableAfterMappingWithBankAccounts.Order AS Order,
	|	ImportedTableAfterMappingWithBankAccounts.Counterparty AS Counterparty,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableAfterMappingWithBankAccounts.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMappingWithBankAccounts.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMappingWithBankAccounts.CFItem AS CFItem,
	|	ImportedTableAfterMappingWithBankAccounts.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMappingWithBankAccounts.Amount AS Amount,
	|	ImportedTableAfterMappingWithBankAccounts.Received AS Received,
	|	ImportedTableAfterMappingWithBankAccounts.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMappingWithBankAccounts.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMappingWithBankAccounts.CounterpartyToFill AS CounterpartyToFill,
	|	ImportedTableAfterMappingWithBankAccounts.CompanyToFill AS CompanyToFill,
	|	ImportedTableAfterMappingWithBankAccounts.ContractToFill AS ContractToFill,
	|	ImportedTableAfterMappingWithBankAccounts.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMapping
	|FROM
	|	ImportedTableAfterMappingWithBankAccounts AS ImportedTableAfterMappingWithBankAccounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableAfterMappingWithBankAccounts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(ImportedTableAfterMapping.CounterpartyToFill) AS CounterpartyToFill,
	|	COUNT(ImportedTableAfterMapping.CompanyToFill) AS CompanyToFill,
	|	COUNT(ImportedTableAfterMapping.ContractToFill) AS ContractToFill
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|WHERE
	|	(ImportedTableAfterMapping.CounterpartyToFill
	|			OR ImportedTableAfterMapping.CompanyToFill
	|			OR ImportedTableAfterMapping.ContractToFill)";
EndFunction

Function GetCompanyMapQuery()
	
	Return 
	"SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	Companies.Ref AS Counterparty,
	|	0 AS Priority
	|INTO CompanyMap
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON ImportedTableAfterMapping.Company = Companies.TIN
	|			AND ((CAST(ImportedTableAfterMapping.Company AS STRING(20))) <> """")
	|			AND (ImportedTableAfterMapping.CompanyToFill)
	|
	|UNION ALL
	|
	|SELECT
	|	ImportedTableAfterMapping.LineNumber,
	|	Companies.Ref,
	|	1
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON (ImportedTableAfterMapping.Company = (CAST(Companies.Description AS STRING(255))))
	|			AND (ImportedTableAfterMapping.CompanyToFill)
	|
	|UNION ALL
	|
	|SELECT
	|	ImportedTableAfterMapping.LineNumber,
	|	Companies.Ref,
	|	2
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.Companies AS Companies
	|		ON (ImportedTableAfterMapping.Company = (CAST(Companies.DescriptionFull AS STRING(255))))
	|			AND (ImportedTableAfterMapping.CompanyToFill)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompanyMap.LineNumber AS LineNumber,
	|	MIN(CompanyMap.Priority) AS Priority
	|INTO CompanyMapMinPriority
	|FROM
	|	CompanyMap AS CompanyMap
	|
	|GROUP BY
	|	CompanyMap.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CompanyMap.LineNumber AS LineNumber,
	|	MAX(CompanyMap.Counterparty) AS Counterparty
	|INTO CompanyMapSlice
	|FROM
	|	CompanyMapMinPriority AS CompanyMapMinPriority
	|		INNER JOIN CompanyMap AS CompanyMap
	|		ON CompanyMapMinPriority.LineNumber = CompanyMap.LineNumber
	|			AND CompanyMapMinPriority.Priority = CompanyMap.Priority
	|
	|GROUP BY
	|	CompanyMap.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	ImportedTableAfterMapping.Company AS Company,
	|	ImportedTableAfterMapping.BankAccount AS BankAccount,
	|	ImportedTableAfterMapping.OperationKind AS OperationKind,
	|	ImportedTableAfterMapping.DocumentKind AS DocumentKind,
	|	ImportedTableAfterMapping.Contract AS Contract,
	|	ImportedTableAfterMapping.Document AS Document,
	|	ImportedTableAfterMapping.Order AS Order,
	|	ISNULL(CompanyMapSlice.Counterparty, ImportedTableAfterMapping.Counterparty) AS Counterparty,
	|	ImportedTableAfterMapping.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableAfterMapping.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableAfterMapping.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMapping.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMapping.CFItem AS CFItem,
	|	ImportedTableAfterMapping.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMapping.Amount AS Amount,
	|	ImportedTableAfterMapping.Received AS Received,
	|	ImportedTableAfterMapping.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMapping.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMapping.CounterpartyToFill AS CounterpartyToFill,
	|	ImportedTableAfterMapping.ContractToFill AS ContractToFill,
	|	ImportedTableAfterMapping.PaymentDate AS PaymentDate
	|INTO ImportedTableWithCompany
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		LEFT JOIN CompanyMapSlice AS CompanyMapSlice
	|		ON ImportedTableAfterMapping.LineNumber = CompanyMapSlice.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableAfterMapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CompanyMapSlice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CompanyMapMinPriority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CompanyMap
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableWithCompanies.LineNumber AS LineNumber,
	|	ImportedTableWithCompanies.Company AS Company,
	|	ImportedTableWithCompanies.BankAccount AS BankAccount,
	|	ImportedTableWithCompanies.OperationKind AS OperationKind,
	|	ImportedTableWithCompanies.DocumentKind AS DocumentKind,
	|	ImportedTableWithCompanies.Contract AS Contract,
	|	ImportedTableWithCompanies.Document AS Document,
	|	ImportedTableWithCompanies.Order AS Order,
	|	ImportedTableWithCompanies.Counterparty AS Counterparty,
	|	ImportedTableWithCompanies.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableWithCompanies.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableWithCompanies.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableWithCompanies.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableWithCompanies.CFItem AS CFItem,
	|	ImportedTableWithCompanies.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableWithCompanies.Amount AS Amount,
	|	ImportedTableWithCompanies.Received AS Received,
	|	ImportedTableWithCompanies.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableWithCompanies.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableWithCompanies.CounterpartyToFill AS CounterpartyToFill,
	|	ImportedTableWithCompanies.ContractToFill AS ContractToFill,
	|	ImportedTableWithCompanies.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMapping
	|FROM
	|	ImportedTableWithCompany AS ImportedTableWithCompanies
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableWithCompany
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(ImportedTableAfterMapping.CounterpartyToFill) AS CounterpartyToFill,
	|	COUNT(ImportedTableAfterMapping.ContractToFill) AS ContractToFill
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|WHERE
	|	(ImportedTableAfterMapping.CounterpartyToFill
	|			OR ImportedTableAfterMapping.ContractToFill)";
	
EndFunction

Function GetCounterpartyMapQuery()
	
	Return 
	"SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	Counterparties.Ref AS Counterparty,
	|	0 AS Priority
	|INTO CounterpartyMap
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON ImportedTableAfterMapping.CounterpartyTIN = Counterparties.TIN
	|			AND (ImportedTableAfterMapping.CounterpartyToFill)
	|			AND ((CAST(Counterparties.TIN AS STRING(20))) <> """")
	|WHERE
	|	NOT Counterparties.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	ImportedTableAfterMapping.LineNumber,
	|	Counterparties.Ref,
	|	1
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON (ImportedTableAfterMapping.Counterparty = (CAST(Counterparties.Description AS STRING(255))))
	|			AND (ImportedTableAfterMapping.CounterpartyToFill)
	|WHERE
	|	NOT Counterparties.DeletionMark
	|
	|UNION ALL
	|
	|SELECT
	|	ImportedTableAfterMapping.LineNumber,
	|	Counterparties.Ref,
	|	2
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON (ImportedTableAfterMapping.Counterparty = (CAST(Counterparties.DescriptionFull AS STRING(255))))
	|			AND (ImportedTableAfterMapping.CounterpartyToFill)
	|WHERE
	|	NOT Counterparties.DeletionMark
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CounterpartyMap.LineNumber AS LineNumber,
	|	MIN(CounterpartyMap.Priority) AS Priority
	|INTO CounterpartyMapMinPriority
	|FROM
	|	CounterpartyMap AS CounterpartyMap
	|
	|GROUP BY
	|	CounterpartyMap.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CounterpartyMap.LineNumber AS LineNumber,
	|	MAX(CounterpartyMap.Counterparty) AS Counterparty
	|INTO CounterpartyMapSlice
	|FROM
	|	CounterpartyMapMinPriority AS CounterpartyMapMinPriority
	|		INNER JOIN CounterpartyMap AS CounterpartyMap
	|		ON CounterpartyMapMinPriority.LineNumber = CounterpartyMap.LineNumber
	|			AND CounterpartyMapMinPriority.Priority = CounterpartyMap.Priority
	|
	|GROUP BY
	|	CounterpartyMap.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	ImportedTableAfterMapping.Company AS Company,
	|	ImportedTableAfterMapping.BankAccount AS BankAccount,
	|	ImportedTableAfterMapping.OperationKind AS OperationKind,
	|	ImportedTableAfterMapping.DocumentKind AS DocumentKind,
	|	ImportedTableAfterMapping.Contract AS Contract,
	|	ImportedTableAfterMapping.Document AS Document,
	|	ImportedTableAfterMapping.Order AS Order,
	|	ISNULL(CounterpartyMapSlice.Counterparty, ImportedTableAfterMapping.Counterparty) AS Counterparty,
	|	ImportedTableAfterMapping.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableAfterMapping.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableAfterMapping.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMapping.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMapping.CFItem AS CFItem,
	|	ImportedTableAfterMapping.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMapping.Amount AS Amount,
	|	ImportedTableAfterMapping.Received AS Received,
	|	ImportedTableAfterMapping.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMapping.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMapping.ContractToFill AS ContractToFill,
	|	ImportedTableAfterMapping.PaymentDate AS PaymentDate
	|INTO ImportedTableWithCounterparties
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		LEFT JOIN CounterpartyMapSlice AS CounterpartyMapSlice
	|		ON ImportedTableAfterMapping.LineNumber = CounterpartyMapSlice.LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableAfterMapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CounterpartyMapSlice
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CounterpartyMapMinPriority
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP CounterpartyMap
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableWithCounterparties.LineNumber AS LineNumber,
	|	ImportedTableWithCounterparties.Company AS Company,
	|	ImportedTableWithCounterparties.BankAccount AS BankAccount,
	|	ImportedTableWithCounterparties.OperationKind AS OperationKind,
	|	ImportedTableWithCounterparties.DocumentKind AS DocumentKind,
	|	ImportedTableWithCounterparties.Contract AS Contract,
	|	ImportedTableWithCounterparties.Document AS Document,
	|	ImportedTableWithCounterparties.Order AS Order,
	|	ImportedTableWithCounterparties.Counterparty AS Counterparty,
	|	ImportedTableWithCounterparties.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableWithCounterparties.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableWithCounterparties.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableWithCounterparties.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableWithCounterparties.CFItem AS CFItem,
	|	ImportedTableWithCounterparties.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableWithCounterparties.Amount AS Amount,
	|	ImportedTableWithCounterparties.Received AS Received,
	|	ImportedTableWithCounterparties.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableWithCounterparties.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableWithCounterparties.ContractToFill AS ContractToFill,
	|	ImportedTableWithCounterparties.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMapping
	|FROM
	|	ImportedTableWithCounterparties AS ImportedTableWithCounterparties
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableWithCounterparties
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	COUNT(ImportedTableAfterMapping.ContractToFill) AS ContractToFill
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|WHERE
	|	ImportedTableAfterMapping.ContractToFill";
	
EndFunction

Function GetContractsMapQuery()
	
	Return
	"SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	ImportedTableAfterMapping.Company AS Company,
	|	CounterpartyContracts.Ref AS Contract,
	|	ImportedTableAfterMapping.Counterparty AS Counterparty,
	|	ImportedTableAfterMapping.CFItem AS CFItem
	|INTO ContractMap
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (ImportedTableAfterMapping.ContractToFill)
	|			AND ImportedTableAfterMapping.Counterparty = CounterpartyContracts.Owner
	|			AND ImportedTableAfterMapping.Company = CounterpartyContracts.Company
	|			AND ImportedTableAfterMapping.CFItem = CounterpartyContracts.CashFlowItem
	|			AND (NOT CounterpartyContracts.DeletionMark)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContractMap.LineNumber AS LineNumber,
	|	ContractMap.Company AS Company,
	|	COUNT(ContractMap.Contract) AS Contract,
	|	ContractMap.Counterparty AS Counterparty,
	|	ContractMap.CFItem AS CFItem
	|INTO ContractsCount
	|FROM
	|	ContractMap AS ContractMap
	|
	|GROUP BY
	|	ContractMap.LineNumber,
	|	ContractMap.Company,
	|	ContractMap.Counterparty,
	|	ContractMap.CFItem
	|
	|HAVING
	|	COUNT(ContractMap.Contract) = 1
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ContractMap.LineNumber AS LineNumber,
	|	ContractMap.Company AS Company,
	|	ContractMap.Contract AS Contract,
	|	ContractMap.Counterparty AS Counterparty,
	|	ContractMap.CFItem AS CFItem
	|INTO DefaultContracts
	|FROM
	|	ContractMap AS ContractMap
	|		INNER JOIN ContractsCount AS ContractsCount
	|		ON ContractMap.LineNumber = ContractsCount.LineNumber
	|			AND ContractMap.Company = ContractsCount.Company
	|			AND ContractMap.Counterparty = ContractsCount.Counterparty
	|			AND ContractMap.CFItem = ContractsCount.CFItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableAfterMapping.LineNumber AS LineNumber,
	|	ImportedTableAfterMapping.Company AS Company,
	|	ImportedTableAfterMapping.BankAccount AS BankAccount,
	|	ImportedTableAfterMapping.OperationKind AS OperationKind,
	|	ImportedTableAfterMapping.DocumentKind AS DocumentKind,
	|	ISNULL(DefaultContracts.Contract, ImportedTableAfterMapping.Contract) AS Contract,
	|	ImportedTableAfterMapping.Document AS Document,
	|	ImportedTableAfterMapping.Order AS Order,
	|	ImportedTableAfterMapping.Counterparty AS Counterparty,
	|	ImportedTableAfterMapping.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableAfterMapping.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableAfterMapping.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableAfterMapping.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableAfterMapping.CFItem AS CFItem,
	|	ImportedTableAfterMapping.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableAfterMapping.Amount AS Amount,
	|	ImportedTableAfterMapping.Received AS Received,
	|	ImportedTableAfterMapping.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableAfterMapping.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableAfterMapping.ContractToFill AS ContractToFill,
	|	ImportedTableAfterMapping.PaymentDate AS PaymentDate
	|INTO ImportedTableWithContracts
	|FROM
	|	ImportedTableAfterMapping AS ImportedTableAfterMapping
	|		LEFT JOIN DefaultContracts AS DefaultContracts
	|		ON ImportedTableAfterMapping.LineNumber = DefaultContracts.LineNumber
	|			AND ImportedTableAfterMapping.Company = DefaultContracts.Company
	|			AND ImportedTableAfterMapping.Counterparty = DefaultContracts.Counterparty
	|			AND ImportedTableAfterMapping.CFItem = DefaultContracts.CFItem
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ContractMap
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ContractsCount
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP DefaultContracts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableAfterMapping
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ImportedTableWithContracts.LineNumber AS LineNumber,
	|	ImportedTableWithContracts.Company AS Company,
	|	ImportedTableWithContracts.BankAccount AS BankAccount,
	|	ImportedTableWithContracts.OperationKind AS OperationKind,
	|	ImportedTableWithContracts.DocumentKind AS DocumentKind,
	|	ImportedTableWithContracts.Contract AS Contract,
	|	ImportedTableWithContracts.Document AS Document,
	|	ImportedTableWithContracts.Order AS Order,
	|	ImportedTableWithContracts.Counterparty AS Counterparty,
	|	ImportedTableWithContracts.CounterpartyTIN AS CounterpartyTIN,
	|	ImportedTableWithContracts.CounterpartyBankAccount AS CounterpartyBankAccount,
	|	ImportedTableWithContracts.PaymentPurpose AS PaymentPurpose,
	|	ImportedTableWithContracts.AdvanceFlag AS AdvanceFlag,
	|	ImportedTableWithContracts.CFItem AS CFItem,
	|	ImportedTableWithContracts.ExpenseGLAccount AS ExpenseGLAccount,
	|	ImportedTableWithContracts.Amount AS Amount,
	|	ImportedTableWithContracts.Received AS Received,
	|	ImportedTableWithContracts.ExternalDocumentDate AS ExternalDocumentDate,
	|	ImportedTableWithContracts.ExternalDocumentNumber AS ExternalDocumentNumber,
	|	ImportedTableWithContracts.ContractToFill AS ContractToFill,
	|	ImportedTableWithContracts.PaymentDate AS PaymentDate
	|INTO ImportedTableAfterMapping
	|FROM
	|	ImportedTableWithContracts AS ImportedTableWithContracts
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP ImportedTableWithContracts";
	
EndFunction

Procedure CheckRowErrors(Row, ErrorID, ErrorFound, IsImport)
	
	If NOT ValueIsFilled(Row.Company)
		OR TypeOf(Row.Company) = Type("String") Then
		AddErrorToTable(Row,
			Enums.BankMappingAttribute.Company,
			ErrorID,
			ErrorFound,
			Catalogs.Companies.EmptyRef(),
			Row.Company);
	EndIf;
	
	If NOT ValueIsFilled(Row.BankAccount)
		OR TypeOf(Row.BankAccount) = Type("String") Then
		AddErrorToTable(Row,
			Enums.BankMappingAttribute.BankAccount,
			ErrorID,
			ErrorFound,
			Catalogs.BankAccounts.EmptyRef(),
			Row.BankAccount);
	EndIf;
	
	If NOT ValueIsFilled(Row.OperationKind)
		OR TypeOf(Row.OperationKind) = Type("String") Then
		AddErrorToTable(Row,
			Enums.BankMappingAttribute.OperationKind,
			ErrorID,
			ErrorFound);
	EndIf;
	
	If Row.OperationKind = Enums.OperationTypesPaymentExpense.ToCustomer
		OR Row.OperationKind = Enums.OperationTypesPaymentExpense.Vendor
		OR Row.OperationKind = Enums.OperationTypesPaymentExpense.LoanSettlements
		OR Row.OperationKind = Enums.OperationTypesPaymentExpense.OtherSettlements
		OR Row.OperationKind = Enums.OperationTypesPaymentReceipt.FromCustomer
		OR Row.OperationKind = Enums.OperationTypesPaymentReceipt.FromVendor Then
		
		If NOT ValueIsFilled(Row.Counterparty)
			OR TypeOf(Row.Counterparty) = Type("String") Then
			AddErrorToTable(Row,
				Enums.BankMappingAttribute.Counterparty,
				ErrorID,
				ErrorFound,
				Catalogs.Counterparties.EmptyRef(),
				Row.Counterparty);
		EndIf;
		
		If NOT ValueIsFilled(Row.CounterpartyBankAccount)
			OR TypeOf(Row.CounterpartyBankAccount) = Type("String") Then
			AddErrorToTable(Row,
				Enums.BankMappingAttribute.CounterpartyBankAccount, 
				ErrorID,
				ErrorFound,
				Catalogs.BankAccounts.EmptyRef(),
				Row.CounterpartyBankAccount);
		EndIf;
		
	EndIf;
	
	If IsImport Then
		If NOT ValueIsFilled(Row.DocumentKind) Then
			AddErrorToTable(Row,
				Enums.BankMappingAttribute.DocumentKind,
				ErrorID,
				ErrorFound,
				"",
				Row.DocumentKind);
		EndIf;
		
		If NOT ValueIsFilled(Row.CFItem) Then
			AddErrorToTable(Row,
				Enums.BankMappingAttribute.CFItem,
				ErrorID,
				ErrorFound,
				Catalogs.CashFlowItems.EmptyRef(),
				Row.CFItem);
		EndIf;
	EndIf;
	
	If Row.Amount = 0 Then
		AddErrorToTable(Row,
			Enums.BankMappingAttribute.Amount,
			ErrorID,
			ErrorFound,
			0,
			0);
	EndIf;
	
EndProcedure

Procedure AddErrorToTable(Row, Field, ErrorID, ErrorFound, DefaultValue = Undefined, ReceivedValue = Undefined)
	
	NewError = ErrorTable.Add();
	NewError.Attribute		= Field;
	NewError.DefaultValue	= DefaultValue;
	NewError.ReceivedValue	= ReceivedValue;
	NewError.ID				= ErrorID;
	
	Row.ErrorID		= ErrorID;
	Row.ImageNumber	= 5;
	
	ErrorFound = True;
	
EndProcedure

#EndRegion

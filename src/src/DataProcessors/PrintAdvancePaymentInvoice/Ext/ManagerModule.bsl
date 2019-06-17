#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Print

Function GetQueryText(ObjectsArray, DocumentType)
	
	QueryText = "";
	
	If ObjectsArray.Count() > 0 Then
		
		DocumentType = ObjectsArray[0].Metadata().Presentation();
		
		If TypeOf(ObjectsArray[0]) = Type("DocumentRef.PaymentReceipt") Then
			QueryText = GetQueryTextForPaymentReceipt();
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.CashReceipt") Then
			QueryText = GetQueryTextForCashReceipt();
		ElsIf TypeOf(ObjectsArray[0]) = Type("DocumentRef.TaxInvoiceIssued") Then
			DocumentType	= NStr("en = 'Advance payment invoice'");
			QueryText		= GetQueryTextForTaxInvoiceIssued();
		EndIf;
		
	EndIf;
	
	Return QueryText;
	
EndFunction

Function GetQueryTextForPaymentReceipt()
	
	Return
	"SELECT
	|	PaymentReceipt.Ref AS Ref,
	|	PaymentReceipt.Number AS Number,
	|	PaymentReceipt.Date AS Date,
	|	PaymentReceipt.Company AS Company,
	|	PaymentReceipt.Counterparty AS Counterparty,
	|	PaymentReceipt.CashCurrency AS CashCurrency,
	|	CAST(PaymentReceipt.Comment AS STRING(1024)) AS Comment,
	|	CAST(PaymentReceipt.PaymentPurpose AS STRING(1024)) AS PaymentPurpose,
	|	PaymentReceipt.BankAccount AS BankAccount
	|INTO TableOfReceipts
	|FROM
	|	Document.PaymentReceipt AS PaymentReceipt
	|WHERE
	|	PaymentReceipt.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfReceipts.Ref AS Ref,
	|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(ExchangeRates.Period, DATETIME(1, 1, 1)) AS Period
	|INTO TempExchangeRates
	|FROM
	|	TableOfReceipts AS TableOfReceipts
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (ExchangeRates.Currency = TableOfReceipts.CashCurrency)
	|			AND (ExchangeRates.Period <= TableOfReceipts.Date)
	|
	|INDEX BY
	|	Ref,
	|	Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempExchangeRates.Ref AS Ref,
	|	MAX(TempExchangeRates.Period) AS Period
	|INTO ExchangeRatesMaxPeriod
	|FROM
	|	TempExchangeRates AS TempExchangeRates
	|
	|GROUP BY
	|	TempExchangeRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempExchangeRates.Ref AS Ref,
	|	TempExchangeRates.ExchangeRate AS ExchangeRate,
	|	TempExchangeRates.Multiplicity AS Multiplicity
	|INTO ExchangeRatesForRef
	|FROM
	|	TempExchangeRates AS TempExchangeRates
	|		INNER JOIN ExchangeRatesMaxPeriod AS ExchangeRatesMaxPeriod
	|		ON TempExchangeRates.Ref = ExchangeRatesMaxPeriod.Ref
	|			AND TempExchangeRates.Period = ExchangeRatesMaxPeriod.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfReceipts.Ref AS Ref,
	|	TableOfReceipts.Number AS DocumentNumber,
	|	TableOfReceipts.Date AS DocumentDate,
	|	TableOfReceipts.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	TableOfReceipts.Counterparty AS Counterparty,
	|	PresentationCurrency.Value AS DocumentCurrency,
	|	TableOfReceipts.Comment AS Comment,
	|	TableOfReceipts.PaymentPurpose AS PaymentPurpose,
	|	TableOfReceipts.BankAccount AS BankAccount,
	|	TableOfReceipts.CashCurrency AS CashCurrency
	|INTO Header
	|FROM
	|	TableOfReceipts AS TableOfReceipts
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON TableOfReceipts.Company = Companies.Ref
	|		LEFT JOIN Constant.PresentationCurrency AS PresentationCurrency
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	Header.PaymentPurpose AS PaymentPurpose,
	|	ReceiptDetails.LineNumber AS LineNumber,
	|	CAST(ReceiptDetails.PaymentAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)) AS Total,
	|	CAST(ReceiptDetails.VATAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)) AS VATAmount,
	|	ReceiptDetails.VATRate AS VATRate,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	Header.BankAccount AS BankAccount,
	|	Header.CashCurrency AS CashCurrency,
	|	ISNULL(ExchangeRatesForRef.ExchangeRate, 1) AS ExchangeRate
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.PaymentReceipt.PaymentDetails AS ReceiptDetails
	|		ON Header.Ref = ReceiptDetails.Ref
	|			AND (ReceiptDetails.AdvanceFlag)
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON (ReceiptDetails.Order = SalesOrder.Ref)
	|		LEFT JOIN ExchangeRatesForRef AS ExchangeRatesForRef
	|		ON (ReceiptDetails.Ref = ExchangeRatesForRef.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.PaymentPurpose AS PaymentPurpose,
	|	MIN(Tabular.LineNumber) AS LineNumber,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Total) AS Total,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total - Tabular.VATAmount) AS Subtotal,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.CashCurrency AS CashCurrency,
	|	MIN(Tabular.ExchangeRate) AS ExchangeRate
	|INTO TabularGrouped
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.VATRate,
	|	Tabular.Company,
	|	Tabular.Ref,
	|	Tabular.Comment,
	|	Tabular.DocumentDate,
	|	Tabular.DocumentNumber,
	|	Tabular.PaymentPurpose,
	|	Tabular.CompanyLogoFile,
	|	Tabular.Counterparty,
	|	Tabular.BankAccount,
	|	Tabular.DocumentCurrency,
	|	Tabular.CashCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	&DocumentType AS DocumentType,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.PaymentPurpose AS PaymentPurpose,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.CashCurrency AS CashCurrency,
	|	Tabular.ExchangeRate AS ExchangeRate
	|FROM
	|	TabularGrouped AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentType),
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	MAX(PaymentPurpose),
	|	MAX(LineNumber),
	|	MAX(VATRate),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(BankAccount),
	|	MAX(CashCurrency),
	|	MAX(ExchangeRate)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total) AS Amount
	|FROM
	|	TabularGrouped AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref";
	
EndFunction

Function GetQueryTextForCashReceipt()
	
	Return
	"SELECT
	|	CashReceipt.Ref AS Ref,
	|	CashReceipt.Number AS Number,
	|	CashReceipt.Date AS Date,
	|	CashReceipt.Company AS Company,
	|	CashReceipt.Counterparty AS Counterparty,
	|	CashReceipt.CashCurrency AS CashCurrency,
	|	CAST(CashReceipt.Comment AS STRING(1024)) AS Comment,
	|	CAST(CashReceipt.Basis AS STRING(1024)) AS PaymentPurpose,
	|	VALUE(Catalog.BankAccounts.EmptyRef) AS BankAccount
	|INTO TableOfReceipts
	|FROM
	|	Document.CashReceipt AS CashReceipt
	|WHERE
	|	CashReceipt.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfReceipts.Ref AS Ref,
	|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(ExchangeRates.Period, DATETIME(1, 1, 1)) AS Period
	|INTO TempExchangeRates
	|FROM
	|	TableOfReceipts AS TableOfReceipts
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON (ExchangeRates.Currency = TableOfReceipts.CashCurrency)
	|			AND (ExchangeRates.Period <= TableOfReceipts.Date)
	|
	|INDEX BY
	|	Ref,
	|	Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempExchangeRates.Ref AS Ref,
	|	MAX(TempExchangeRates.Period) AS Period
	|INTO ExchangeRatesMaxPeriod
	|FROM
	|	TempExchangeRates AS TempExchangeRates
	|
	|GROUP BY
	|	TempExchangeRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempExchangeRates.Ref AS Ref,
	|	TempExchangeRates.ExchangeRate AS ExchangeRate,
	|	TempExchangeRates.Multiplicity AS Multiplicity
	|INTO ExchangeRatesForRef
	|FROM
	|	TempExchangeRates AS TempExchangeRates
	|		INNER JOIN ExchangeRatesMaxPeriod AS ExchangeRatesMaxPeriod
	|		ON TempExchangeRates.Ref = ExchangeRatesMaxPeriod.Ref
	|			AND TempExchangeRates.Period = ExchangeRatesMaxPeriod.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableOfReceipts.Ref AS Ref,
	|	TableOfReceipts.Number AS DocumentNumber,
	|	TableOfReceipts.Date AS DocumentDate,
	|	TableOfReceipts.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	TableOfReceipts.Counterparty AS Counterparty,
	|	PresentationCurrency.Value AS DocumentCurrency,
	|	TableOfReceipts.Comment AS Comment,
	|	TableOfReceipts.PaymentPurpose AS PaymentPurpose,
	|	TableOfReceipts.BankAccount AS BankAccount,
	|	TableOfReceipts.CashCurrency AS CashCurrency
	|INTO Header
	|FROM
	|	TableOfReceipts AS TableOfReceipts
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON TableOfReceipts.Company = Companies.Ref
	|		LEFT JOIN Constant.PresentationCurrency AS PresentationCurrency
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Header.Ref AS Ref,
	|	Header.DocumentNumber AS DocumentNumber,
	|	Header.DocumentDate AS DocumentDate,
	|	Header.Company AS Company,
	|	Header.CompanyLogoFile AS CompanyLogoFile,
	|	Header.Counterparty AS Counterparty,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.Comment AS Comment,
	|	Header.PaymentPurpose AS PaymentPurpose,
	|	ReceiptDetails.LineNumber AS LineNumber,
	|	CAST(ReceiptDetails.PaymentAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)) AS Total,
	|	CAST(ReceiptDetails.VATAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)) AS VATAmount,
	|	ReceiptDetails.VATRate AS VATRate,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	Header.BankAccount AS BankAccount,
	|	Header.CashCurrency AS CashCurrency,
	|	ISNULL(ExchangeRatesForRef.ExchangeRate, 1) AS ExchangeRate
	|INTO Tabular
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.CashReceipt.PaymentDetails AS ReceiptDetails
	|		ON Header.Ref = ReceiptDetails.Ref
	|			AND (ReceiptDetails.AdvanceFlag)
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON (ReceiptDetails.Order = SalesOrder.Ref)
	|		LEFT JOIN ExchangeRatesForRef AS ExchangeRatesForRef
	|		ON (ReceiptDetails.Ref = ExchangeRatesForRef.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.PaymentPurpose AS PaymentPurpose,
	|	MIN(Tabular.LineNumber) AS LineNumber,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Total) AS Total,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total - Tabular.VATAmount) AS Subtotal,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.CashCurrency AS CashCurrency,
	|	MIN(Tabular.ExchangeRate) AS ExchangeRate
	|INTO TabularGrouped
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.VATRate,
	|	Tabular.Company,
	|	Tabular.Ref,
	|	Tabular.Comment,
	|	Tabular.DocumentDate,
	|	Tabular.DocumentNumber,
	|	Tabular.PaymentPurpose,
	|	Tabular.CompanyLogoFile,
	|	Tabular.Counterparty,
	|	Tabular.BankAccount,
	|	Tabular.DocumentCurrency,
	|	Tabular.CashCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	&DocumentType AS DocumentType,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.PaymentPurpose AS PaymentPurpose,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.CashCurrency AS CashCurrency,
	|	Tabular.ExchangeRate AS ExchangeRate
	|FROM
	|	TabularGrouped AS Tabular
	|
	|ORDER BY
	|	DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentType),
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	MAX(PaymentPurpose),
	|	MAX(LineNumber),
	|	MAX(VATRate),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(BankAccount),
	|	MAX(CashCurrency),
	|	MAX(ExchangeRate)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total) AS Amount
	|FROM
	|	TabularGrouped AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref";
	
EndFunction

Function GetQueryTextForTaxInvoiceIssued()
	
	Return
	"SELECT
	|	TaxInvoiceIssued.Ref AS Ref,
	|	TaxInvoiceIssued.Number AS DocumentNumber,
	|	TaxInvoiceIssued.Date AS DocumentDate,
	|	TaxInvoiceIssued.Company AS Company,
	|	TaxInvoiceIssued.Counterparty AS Counterparty,
	|	CAST(TaxInvoiceIssued.Comment AS STRING(1024)) AS Comment
	|INTO TaxInvoiceTable
	|FROM
	|	Document.TaxInvoiceIssued AS TaxInvoiceIssued
	|WHERE
	|	TaxInvoiceIssued.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	TaxInvoiceIssuedBasisDocuments.BasisDocument AS BasisDocument,
	|	TaxInvoiceTable.Ref AS Ref
	|INTO BasisDocuments
	|FROM
	|	Document.TaxInvoiceIssued.BasisDocuments AS TaxInvoiceIssuedBasisDocuments
	|		INNER JOIN TaxInvoiceTable AS TaxInvoiceTable
	|		ON TaxInvoiceIssuedBasisDocuments.Ref = TaxInvoiceTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	CashReceipt.Ref AS ReceiptRef,
	|	CashReceipt.Basis AS PaymentPurpose,
	|	CashReceipt.Date AS ReceiptDate,
	|	CashReceipt.CashCurrency AS Currency,
	|	BasisDocuments.Ref AS Ref
	|INTO ReceiptsTable
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.CashReceipt AS CashReceipt
	|		ON BasisDocuments.BasisDocument = CashReceipt.Ref
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentReceipt.Ref,
	|	PaymentReceipt.PaymentPurpose,
	|	PaymentReceipt.Date,
	|	PaymentReceipt.CashCurrency,
	|	BasisDocuments.Ref
	|FROM
	|	BasisDocuments AS BasisDocuments
	|		INNER JOIN Document.PaymentReceipt AS PaymentReceipt
	|		ON BasisDocuments.BasisDocument = PaymentReceipt.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReceiptsTable.ReceiptRef AS Ref,
	|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(ExchangeRates.Period, DATETIME(1, 1, 1)) AS Period
	|INTO TempExchangeRates
	|FROM
	|	ReceiptsTable AS ReceiptsTable
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON ReceiptsTable.Currency = ExchangeRates.Currency
	|			AND ReceiptsTable.ReceiptDate >= ExchangeRates.Period
	|
	|INDEX BY
	|	Ref,
	|	Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempExchangeRates.Ref AS Ref,
	|	MAX(TempExchangeRates.Period) AS Period
	|INTO ExchangeRatesMaxPeriod
	|FROM
	|	TempExchangeRates AS TempExchangeRates
	|
	|GROUP BY
	|	TempExchangeRates.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TempExchangeRates.Ref AS Ref,
	|	TempExchangeRates.ExchangeRate AS ExchangeRate,
	|	TempExchangeRates.Multiplicity AS Multiplicity
	|INTO ExchangeRatesForRef
	|FROM
	|	TempExchangeRates AS TempExchangeRates
	|		INNER JOIN ExchangeRatesMaxPeriod AS ExchangeRatesMaxPeriod
	|		ON TempExchangeRates.Ref = ExchangeRatesMaxPeriod.Ref
	|			AND TempExchangeRates.Period = ExchangeRatesMaxPeriod.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ReceiptsTable.Ref AS Ref,
	|	CAST(ReceiptsTable.PaymentPurpose AS STRING(1024)) AS PaymentPurpose,
	|	CashReceiptDetails.LineNumber AS LineNumber,
	|	CAST(CashReceiptDetails.PaymentAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)) AS Total,
	|	CashReceiptDetails.VATRate AS VATRate,
	|	CAST(CashReceiptDetails.VATAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)) AS VATAmount,
	|	CashReceiptDetails.Order AS Order,
	|	ReceiptsTable.Currency AS CashCurrency,
	|	ExchangeRatesForRef.ExchangeRate AS ExchangeRate
	|INTO ReceiptDetails
	|FROM
	|	Document.CashReceipt.PaymentDetails AS CashReceiptDetails
	|		INNER JOIN ReceiptsTable AS ReceiptsTable
	|		ON CashReceiptDetails.Ref = ReceiptsTable.ReceiptRef
	|		INNER JOIN ExchangeRatesForRef AS ExchangeRatesForRef
	|		ON CashReceiptDetails.Ref = ExchangeRatesForRef.Ref
	|WHERE
	|	CashReceiptDetails.AdvanceFlag
	|
	|UNION ALL
	|
	|SELECT
	|	ReceiptsTable.Ref,
	|	CAST(ReceiptsTable.PaymentPurpose AS STRING(1024)),
	|	PaymentReceiptDetails.LineNumber,
	|	CAST(PaymentReceiptDetails.PaymentAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)),
	|	PaymentReceiptDetails.VATRate,
	|	CAST(PaymentReceiptDetails.VATAmount * ExchangeRatesForRef.ExchangeRate / ExchangeRatesForRef.Multiplicity AS NUMBER(15, 2)),
	|	PaymentReceiptDetails.Order,
	|	ReceiptsTable.Currency,
	|	ExchangeRatesForRef.ExchangeRate
	|FROM
	|	Document.PaymentReceipt.PaymentDetails AS PaymentReceiptDetails
	|		INNER JOIN ReceiptsTable AS ReceiptsTable
	|		ON PaymentReceiptDetails.Ref = ReceiptsTable.ReceiptRef
	|		INNER JOIN ExchangeRatesForRef AS ExchangeRatesForRef
	|		ON PaymentReceiptDetails.Ref = ExchangeRatesForRef.Ref
	|WHERE
	|	PaymentReceiptDetails.AdvanceFlag
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TaxInvoiceTable.Ref AS Ref,
	|	TaxInvoiceTable.DocumentNumber AS DocumentNumber,
	|	TaxInvoiceTable.DocumentDate AS DocumentDate,
	|	TaxInvoiceTable.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	TaxInvoiceTable.Counterparty AS Counterparty,
	|	TaxInvoiceTable.Comment AS Comment,
	|	PresentationCurrency.Value AS DocumentCurrency,
	|	ReceiptDetails.PaymentPurpose AS PaymentPurpose,
	|	ReceiptDetails.LineNumber AS LineNumber,
	|	ReceiptDetails.VATRate AS VATRate,
	|	ReceiptDetails.Total AS Total,
	|	ReceiptDetails.VATAmount AS VATAmount,
	|	VALUE(Catalog.BankAccounts.EmptyRef) AS BankAccount,
	|	ISNULL(SalesOrder.Number, """") AS SalesOrderNumber,
	|	ISNULL(SalesOrder.Date, DATETIME(1, 1, 1)) AS SalesOrderDate,
	|	ReceiptDetails.CashCurrency AS CashCurrency,
	|	ReceiptDetails.ExchangeRate AS ExchangeRate
	|INTO Tabular
	|FROM
	|	TaxInvoiceTable AS TaxInvoiceTable
	|		INNER JOIN ReceiptDetails AS ReceiptDetails
	|		ON TaxInvoiceTable.Ref = ReceiptDetails.Ref
	|		LEFT JOIN Document.SalesOrder AS SalesOrder
	|		ON (ReceiptDetails.Order = SalesOrder.Ref)
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON TaxInvoiceTable.Company = Companies.Ref
	|		LEFT JOIN Constant.PresentationCurrency AS PresentationCurrency
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.Comment AS Comment,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.PaymentPurpose AS PaymentPurpose,
	|	MIN(Tabular.LineNumber) AS LineNumber,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.Total) AS Total,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total - Tabular.VATAmount) AS Subtotal,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.CashCurrency AS CashCurrency,
	|	MIN(Tabular.ExchangeRate) AS ExchangeRate
	|INTO TabularGrouped
	|FROM
	|	Tabular AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.DocumentNumber,
	|	Tabular.DocumentDate,
	|	Tabular.Company,
	|	Tabular.CompanyLogoFile,
	|	Tabular.Counterparty,
	|	Tabular.Comment,
	|	Tabular.DocumentCurrency,
	|	Tabular.PaymentPurpose,
	|	Tabular.VATRate,
	|	Tabular.BankAccount,
	|	Tabular.CashCurrency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	&DocumentType AS DocumentType,
	|	Tabular.DocumentNumber AS DocumentNumber,
	|	Tabular.DocumentDate AS DocumentDate,
	|	Tabular.Company AS Company,
	|	Tabular.CompanyLogoFile AS CompanyLogoFile,
	|	Tabular.Counterparty AS Counterparty,
	|	Tabular.DocumentCurrency AS DocumentCurrency,
	|	Tabular.Comment AS Comment,
	|	Tabular.PaymentPurpose AS PaymentPurpose,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	Tabular.BankAccount AS BankAccount,
	|	Tabular.CashCurrency AS CashCurrency,
	|	Tabular.ExchangeRate AS ExchangeRate
	|FROM
	|	TabularGrouped AS Tabular
	|
	|ORDER BY
	|	Tabular.DocumentNumber,
	|	LineNumber
	|TOTALS
	|	MAX(DocumentType),
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(DocumentCurrency),
	|	MAX(Comment),
	|	MAX(PaymentPurpose),
	|	MAX(LineNumber),
	|	MAX(VATRate),
	|	SUM(VATAmount),
	|	SUM(Total),
	|	SUM(Subtotal),
	|	MAX(BankAccount),
	|	MAX(CashCurrency),
	|	AVG(ExchangeRate)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Tabular.Ref AS Ref,
	|	Tabular.SalesOrderNumber AS Number,
	|	Tabular.SalesOrderDate AS Date
	|FROM
	|	Tabular AS Tabular
	|WHERE
	|	Tabular.SalesOrderNumber <> """"
	|
	|ORDER BY
	|	Tabular.SalesOrderNumber
	|TOTALS BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.Ref AS Ref,
	|	Tabular.VATRate AS VATRate,
	|	SUM(Tabular.VATAmount) AS VATAmount,
	|	SUM(Tabular.Total) AS Amount
	|FROM
	|	TabularGrouped AS Tabular
	|
	|GROUP BY
	|	Tabular.Ref,
	|	Tabular.VATRate
	|TOTALS BY
	|	Ref";
	
EndFunction

Function PrintForm(ObjectsArray, PrintObjects, TemplateName, SpreadsheetDocument = Undefined) Export
	
	If TemplateName = "AdvancePaymentInvoice" Then
		
		Return PrintAdvancePaymentInvoice(ObjectsArray, PrintObjects, TemplateName, SpreadsheetDocument);
		
	EndIf;
	
EndFunction

Function PrintAdvancePaymentInvoice(ObjectsArray, PrintObjects, TemplateName, SpreadsheetDocument = Undefined)
	
	DocumentType = "";
	
	If SpreadsheetDocument = Undefined Then
		SpreadsheetDocument = New SpreadsheetDocument;
		SpreadsheetDocument.PrintParametersKey = "PrintParameters_AdvancePaymentInvoice";
		FirstDocument = True;
	Else
		FirstDocument = False;
	EndIf;
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	Query.Text = GetQueryText(ObjectsArray, DocumentType);
	Query.SetParameter("DocumentType", DocumentType);
	
	ResultArray = Query.ExecuteBatch();
	
	ArrayCount = ResultArray.Count();
	
	Header						= ResultArray[ArrayCount-3].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SalesOrdersNumbersHeaderSel	= ResultArray[ArrayCount-2].Select(QueryResultIteration.ByGroupsWithHierarchy);
	TaxesHeaderSel				= ResultArray[ArrayCount-1].Select(QueryResultIteration.ByGroupsWithHierarchy);
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_AdvancePaymentInvoice";
		
		Template = PrintManagement.PrintedFormsTemplate("DataProcessor.PrintAdvancePaymentInvoice.PF_MXL_AdvancePaymentInvoice");
		
		#Region PrintAdvancePaymentInvoiceTitleArea
		
		TitleArea = Template.GetArea("Title");
		TitleArea.Parameters.Fill(Header);
		
		If ValueIsFilled(Header.CompanyLogoFile) Then
			
			PictureData = AttachedFiles.GetFileBinaryData(Header.CompanyLogoFile);
			If ValueIsFilled(PictureData) Then
				
				TitleArea.Drawings.Logo.Picture = New Picture(PictureData);
				
			EndIf;
			
		Else
			
			TitleArea.Drawings.Delete(TitleArea.Drawings.Logo);
			
		EndIf;
		
		SpreadsheetDocument.Put(TitleArea);
		
		#EndRegion
		
		#Region PrintAdvancePaymentInvoiceCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, , Header.BankAccount);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintAdvancePaymentInvoiceCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		SalesOrdersNumbersHeaderSel.Reset();
		If SalesOrdersNumbersHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			SalesOrdersNumbersArray = New Array;
			
			SalesOrdersNumbersSel = SalesOrdersNumbersHeaderSel.Select();
			While SalesOrdersNumbersSel.Next() Do
				
				SalesOrdersNumbersArray.Add(
					SalesOrdersNumbersSel.Number
					+ StringFunctionsClientServer.SubstituteParametersInString(
						" %1 ", NStr("en = 'dated'"))
					+ Format(SalesOrdersNumbersSel.Date, "DLF=D"));
				
			EndDo;
			
			CounterpartyInfoArea.Parameters.SalesOrders = StringFunctionsClientServer.GetStringFromSubstringArray(
				SalesOrdersNumbersArray, ", ");
			
		EndIf;
		
		CurrencyParameters = New Structure;
		CurrencyParameters.Insert("TitleCurrency", "");
		CurrencyParameters.Insert("TitleExchRate", "");
		CurrencyParameters.Insert("CashCurrency", "");
		CurrencyParameters.Insert("ExchangeRate", "");

		If NOT Header.DocumentCurrency = Header.CashCurrency Then
			
			CurrencyParameters.TitleCurrency	= NStr("en = 'Currency'");
			CurrencyParameters.TitleExchRate	= NStr("en = 'Exchange rate'");
			CurrencyParameters.CashCurrency		= Header.CashCurrency;
			CurrencyParameters.ExchangeRate		= Header.ExchangeRate;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.Fill(CurrencyParameters);
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintAdvancePaymentInvoiceCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintAdvancePaymentInvoiceTotalsAndTaxesAreaPrefill
		
		TotalsAndTaxesAreasArray = New Array;
		
		LineTotalArea = Template.GetArea("LineTotal");
		LineTotalArea.Parameters.Fill(Header);
		
		TotalsAndTaxesAreasArray.Add(LineTotalArea);
		
		TaxesHeaderSel.Reset();
		If TaxesHeaderSel.FindNext(New Structure("Ref", Header.Ref)) Then
			
			TaxSectionHeaderArea = Template.GetArea("TaxSectionHeader");
			TotalsAndTaxesAreasArray.Add(TaxSectionHeaderArea);
			
			TaxesSel = TaxesHeaderSel.Select();
			While TaxesSel.Next() Do
				
				TaxSectionLineArea = Template.GetArea("TaxSectionLine");
				TaxSectionLineArea.Parameters.Fill(TaxesSel);
				TotalsAndTaxesAreasArray.Add(TaxSectionLineArea);
				
			EndDo;
			
		EndIf;
		
		#EndRegion
		
		#Region PrintAdvancePaymentInvoiceLinesArea
		
		LineHeaderArea = Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		PageNumber = 0;
		
		TabSelection = Header.Select();
		While TabSelection.Next() Do
			
			LineSectionArea.Parameters.Fill(TabSelection);
			
			AreasToBeChecked = New Array;
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAndTaxesAreasArray Do
				AreasToBeChecked.Add(Area);
			EndDo;
			AreasToBeChecked.Add(PageNumberArea);
			
			If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(LineSectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
						Or i = 50 Then
						
						PageNumber = PageNumber + 1;
						PageNumberArea.Parameters.PageNumber = PageNumber;
						SpreadsheetDocument.Put(PageNumberArea);
						Break;
						
					Else
						
						SpreadsheetDocument.Put(EmptyLineArea);
						
					EndIf;
					
				EndDo;
				
				SpreadsheetDocument.PutHorizontalPageBreak();
				SpreadsheetDocument.Put(TitleArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		#Region PrintAdvancePaymentInvoiceTotalsAndTaxesArea
		
		For Each Area In TotalsAndTaxesAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
		AreasToBeChecked.Clear();
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If Not CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked)
				Or i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		#EndRegion
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

#EndRegion

#EndIf

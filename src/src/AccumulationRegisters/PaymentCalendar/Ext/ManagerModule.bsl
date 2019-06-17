#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	LoanContract.Ref AS LoanContract,
	|	LoanContract.CashAssetsType AS CashAssetsType,
	|	LoanContract.InflowItem AS InflowItem,
	|	LoanContract.PettyCash AS PettyCash,
	|	LoanContract.BankAccount AS BankAccount,
	|	LoanContract.Order AS Order,
	|	LoanContract.SettlementsCurrency AS SettlementsCurrency,
	|	LoanContract.Company AS Company,
	|	LoanContract.OutflowItem AS OutflowItem,
	|	LoanContract.LoanKind AS LoanKind,
	|	LoanContract.Date AS Date
	|INTO LoanContracts
	|FROM
	|	Document.LoanContract AS LoanContract
	|WHERE
	|	LoanContract.Posted
	|	AND NOT LoanContract.ChargeFromSalary
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendarRegister.Recorder AS Recorder,
	|	SalesOrderPaymentCalendar.PaymentDate AS Period,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.CashAssetsType AS CashAssetsType,
	|	CASE
	|		WHEN SalesOrder.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN SalesOrder.PettyCash
	|		WHEN SalesOrder.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN SalesOrder.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN CounterpartyContracts.SettlementsInStandardUnits
	|			THEN CounterpartyContracts.SettlementsCurrency
	|		ELSE SalesOrder.DocumentCurrency
	|	END AS Currency,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CounterpartyContracts.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	CASE
	|		WHEN SalesOrder.AmountIncludesVAT
	|			THEN SalesOrderPaymentCalendar.PaymentAmount
	|		ELSE SalesOrderPaymentCalendar.PaymentAmount + SalesOrderPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount,
	|	PaymentCalendarRegister.Amount AS AmountInRegister,
	|	SalesOrder.ShipmentDate AS ShipmentDate
	|INTO Documents
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendarRegister
	|		INNER JOIN Document.SalesOrder AS SalesOrder
	|		ON PaymentCalendarRegister.Recorder = SalesOrder.Ref
	|		INNER JOIN Document.SalesOrder.PaymentCalendar AS SalesOrderPaymentCalendar
	|		ON PaymentCalendarRegister.Recorder = SalesOrderPaymentCalendar.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (SalesOrder.Contract = CounterpartyContracts.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentCalendarRegister.Recorder,
	|	PurchaseOrderPaymentCalendar.PaymentDate,
	|	PurchaseOrder.Company,
	|	PurchaseOrder.CashAssetsType,
	|	CASE
	|		WHEN PurchaseOrder.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PurchaseOrder.PettyCash
	|		WHEN PurchaseOrder.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PurchaseOrder.BankAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN CounterpartyContracts.SettlementsInStandardUnits
	|			THEN CounterpartyContracts.SettlementsCurrency
	|		ELSE PurchaseOrder.DocumentCurrency
	|	END,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	CounterpartyContracts.SettlementsInStandardUnits,
	|	-CASE
	|		WHEN PurchaseOrder.AmountIncludesVAT
	|			THEN PurchaseOrderPaymentCalendar.PaymentAmount
	|		ELSE PurchaseOrderPaymentCalendar.PaymentAmount + PurchaseOrderPaymentCalendar.PaymentVATAmount
	|	END,
	|	PaymentCalendarRegister.Amount,
	|	PurchaseOrder.ReceiptDate
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendarRegister
	|		INNER JOIN Document.PurchaseOrder AS PurchaseOrder
	|		ON PaymentCalendarRegister.Recorder = PurchaseOrder.Ref
	|		INNER JOIN Document.PurchaseOrder.PaymentCalendar AS PurchaseOrderPaymentCalendar
	|		ON PaymentCalendarRegister.Recorder = PurchaseOrderPaymentCalendar.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (PurchaseOrder.Contract = CounterpartyContracts.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentCalendarRegister.Recorder,
	|	SalesInvoicePaymentCalendar.PaymentDate,
	|	SalesInvoice.Company,
	|	SalesInvoice.CashAssetsType,
	|	CASE
	|		WHEN SalesInvoice.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN SalesInvoice.PettyCash
	|		WHEN SalesInvoice.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN SalesInvoice.BankAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN CounterpartyContracts.SettlementsInStandardUnits
	|			THEN CounterpartyContracts.SettlementsCurrency
	|		ELSE SalesInvoice.DocumentCurrency
	|	END,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers),
	|	CounterpartyContracts.SettlementsInStandardUnits,
	|	CASE
	|		WHEN SalesInvoice.AmountIncludesVAT
	|			THEN SalesInvoicePaymentCalendar.PaymentAmount
	|		ELSE SalesInvoicePaymentCalendar.PaymentAmount + SalesInvoicePaymentCalendar.PaymentVATAmount
	|	END,
	|	PaymentCalendarRegister.Amount,
	|	SalesInvoice.Date
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendarRegister
	|		INNER JOIN Document.SalesInvoice AS SalesInvoice
	|		ON PaymentCalendarRegister.Recorder = SalesInvoice.Ref
	|		INNER JOIN Document.SalesInvoice.PaymentCalendar AS SalesInvoicePaymentCalendar
	|		ON PaymentCalendarRegister.Recorder = SalesInvoicePaymentCalendar.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (SalesInvoice.Contract = CounterpartyContracts.Ref)
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentCalendarRegister.Recorder,
	|	SupplierInvoicePaymentCalendar.PaymentDate,
	|	SupplierInvoice.Company,
	|	SupplierInvoice.CashAssetsType,
	|	CASE
	|		WHEN SupplierInvoice.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN SupplierInvoice.PettyCash
	|		WHEN SupplierInvoice.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN SupplierInvoice.BankAccount
	|		ELSE UNDEFINED
	|	END,
	|	CASE
	|		WHEN CounterpartyContracts.SettlementsInStandardUnits
	|			THEN CounterpartyContracts.SettlementsCurrency
	|		ELSE SupplierInvoice.DocumentCurrency
	|	END,
	|	VALUE(Catalog.CashFlowItems.PaymentToVendor),
	|	CounterpartyContracts.SettlementsInStandardUnits,
	|	-CASE
	|		WHEN SupplierInvoice.AmountIncludesVAT
	|			THEN SupplierInvoicePaymentCalendar.PaymentAmount
	|		ELSE SupplierInvoicePaymentCalendar.PaymentAmount + SupplierInvoicePaymentCalendar.PaymentVATAmount
	|	END,
	|	PaymentCalendarRegister.Amount,
	|	SupplierInvoice.Date
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendarRegister
	|		INNER JOIN Document.SupplierInvoice AS SupplierInvoice
	|		ON PaymentCalendarRegister.Recorder = SupplierInvoice.Ref
	|		INNER JOIN Document.SupplierInvoice.PaymentCalendar AS SupplierInvoicePaymentCalendar
	|		ON PaymentCalendarRegister.Recorder = SupplierInvoicePaymentCalendar.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON (SupplierInvoice.Contract = CounterpartyContracts.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Documents.Recorder AS Recorder,
	|	Documents.Period AS Period,
	|	Documents.Company AS Company,
	|	Documents.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	Documents.Recorder AS Quote,
	|	Documents.Item AS Item,
	|	Documents.BankAccountPettyCash AS BankAccountPettyCash,
	|	Documents.Currency AS Currency,
	|	Documents.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	Documents.PaymentAmount AS PaymentAmount,
	|	Documents.Period <= Documents.ShipmentDate AS NeedToWrite
	|INTO DocumentsFiltered
	|FROM
	|	Documents AS Documents
	|WHERE
	|	Documents.PaymentAmount <> Documents.AmountInRegister
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DocumentsFiltered.Recorder AS Recorder,
	|	DocumentsFiltered.Period AS Period,
	|	DocumentsFiltered.Company AS Company,
	|	DocumentsFiltered.CashAssetsType AS CashAssetsType,
	|	DocumentsFiltered.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	DocumentsFiltered.Quote AS Quote,
	|	DocumentsFiltered.Item AS Item,
	|	DocumentsFiltered.BankAccountPettyCash AS BankAccountPettyCash,
	|	DocumentsFiltered.Currency AS Currency,
	|	DocumentsFiltered.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	DocumentsFiltered.PaymentAmount AS PaymentAmount,
	|	ISNULL(ExchangeRates.ExchangeRate, 1) AS ExchangeRate,
	|	ISNULL(ExchangeRates.Multiplicity, 1) AS Multiplicity,
	|	ISNULL(ExchangeRates.Period, DATETIME(1, 1, 1, 0, 0, 0)) AS RatesPeriod,
	|	DocumentsFiltered.NeedToWrite AS NeedToWrite
	|INTO RatesWithDocData
	|FROM
	|	DocumentsFiltered AS DocumentsFiltered
	|		LEFT JOIN InformationRegister.ExchangeRates AS ExchangeRates
	|		ON DocumentsFiltered.Currency = ExchangeRates.Currency
	|			AND DocumentsFiltered.Period <= ExchangeRates.Period
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RatesWithDocData.Recorder AS Recorder,
	|	MAX(RatesWithDocData.RatesPeriod) AS RatesPeriod,
	|	RatesWithDocData.Currency AS Currency
	|INTO MaxRatePeriod
	|FROM
	|	RatesWithDocData AS RatesWithDocData
	|
	|GROUP BY
	|	RatesWithDocData.Recorder,
	|	RatesWithDocData.Currency
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	RatesWithDocData.Recorder AS Recorder,
	|	RatesWithDocData.Period AS Period,
	|	RatesWithDocData.Company AS Company,
	|	RatesWithDocData.Currency AS Currency,
	|	RatesWithDocData.Item AS Item,
	|	RatesWithDocData.CashAssetsType AS CashAssetsType,
	|	RatesWithDocData.BankAccountPettyCash AS BankAccountPettyCash,
	|	RatesWithDocData.Quote AS Quote,
	|	RatesWithDocData.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	CASE
	|		WHEN RatesWithDocData.SettlementsInStandardUnits
	|			THEN CAST(RatesWithDocData.PaymentAmount * CASE
	|						WHEN RatesWithDocData.ExchangeRate <> 0
	|								AND RatesWithDocData.Multiplicity <> 0
	|							THEN RatesWithDocData.ExchangeRate * RatesWithDocData.Multiplicity / (ISNULL(RatesWithDocData.ExchangeRate, 1) * ISNULL(RatesWithDocData.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE RatesWithDocData.PaymentAmount
	|	END AS Amount
	|INTO Registers
	|FROM
	|	MaxRatePeriod AS MaxRatePeriod
	|		INNER JOIN RatesWithDocData AS RatesWithDocData
	|		ON MaxRatePeriod.RatesPeriod = RatesWithDocData.RatesPeriod
	|			AND MaxRatePeriod.Recorder = RatesWithDocData.Recorder
	|			AND MaxRatePeriod.Currency = RatesWithDocData.Currency
	|
	|UNION ALL
	|
	|SELECT
	|	LoanContractPaymentsAndAccrualsSchedule.Ref,
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentDate,
	|	LoanContracts.Company,
	|	LoanContracts.SettlementsCurrency,
	|	CASE
	|		WHEN LoanContracts.LoanKind = VALUE(Enum.LoanContractTypes.Borrowed)
	|			THEN LoanContracts.InflowItem
	|		WHEN LoanContracts.LoanKind = VALUE(Enum.LoanContractTypes.EmployeeLoanAgreement)
	|			THEN LoanContracts.OutflowItem
	|	END,
	|	LoanContracts.CashAssetsType,
	|	CASE
	|		WHEN LoanContracts.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN LoanContracts.PettyCash
	|		WHEN LoanContracts.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN LoanContracts.BankAccount
	|		ELSE UNDEFINED
	|	END,
	|	LoanContracts.Order,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved),
	|	LoanContractPaymentsAndAccrualsSchedule.PaymentAmount
	|FROM
	|	LoanContracts AS LoanContracts
	|		INNER JOIN Document.LoanContract.PaymentsAndAccrualsSchedule AS LoanContractPaymentsAndAccrualsSchedule
	|		ON LoanContracts.LoanContract = LoanContractPaymentsAndAccrualsSchedule.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|		LEFT JOIN AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|		ON LoanContracts.LoanContract = PaymentCalendar.Recorder
	|WHERE
	|	PaymentCalendar.Recorder IS NULL
	|
	|UNION ALL
	|
	|SELECT
	|	PaymentCalendar.Recorder,
	|	PaymentCalendar.Period,
	|	PaymentCalendar.Company,
	|	PaymentCalendar.Currency,
	|	PaymentCalendar.Item,
	|	PaymentCalendar.CashAssetsType,
	|	PaymentCalendar.BankAccountPettyCash,
	|	PaymentCalendar.Quote,
	|	PaymentCalendar.PaymentConfirmationStatus,
	|	PaymentCalendar.Amount
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|WHERE
	|	VALUETYPE(PaymentCalendar.Recorder) = TYPE(Document.SupplierQuote)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	Registers.Recorder AS Recorder,
	|	Registers.Period AS Period,
	|	Registers.Company AS Company,
	|	Registers.Currency AS Currency,
	|	Registers.Item AS Item,
	|	Registers.CashAssetsType AS CashAssetsType,
	|	Registers.BankAccountPettyCash AS BankAccountPettyCash,
	|	Registers.Quote AS Quote,
	|	Registers.PaymentConfirmationStatus AS PaymentConfirmationStatus,
	|	Registers.Amount AS Amount
	|FROM
	|	Registers AS Registers
	|TOTALS BY
	|	Recorder";
	
	DataSelection = Query.Execute().Select(QueryResultIteration.ByGroups);
	While DataSelection.Next() Do
		
		RegisterRecords = AccumulationRegisters.PaymentCalendar.CreateRecordSet();
		RegisterRecords.Filter.Recorder.Set(DataSelection.Recorder);
		
		Selection = DataSelection.Select();

		While Selection.Next() Do
			NewRecord = RegisterRecords.Add();
			FillPropertyValues(NewRecord, Selection);
		EndDo;
		
		Try
			RegisterRecords.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Error on write document %1: %2'"),
				DataSelection.Recorder,
				BriefErrorDescription(ErrorInfo()));
				
			WriteLogEvent(
				"InfobaseUpdate",
				EventLogLevel.Error,
				Metadata.AccumulationRegisters.PaymentCalendar,
				,
				ErrorDescription);
		EndTry;
		
	EndDo;
	
EndProcedure

#EndRegion
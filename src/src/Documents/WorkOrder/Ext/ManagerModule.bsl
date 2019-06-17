#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then

#Region Public

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
Procedure InitializeDocumentData(DocumentRefWorkOrder, StructureAdditionalProperties, DocumentObjectWorkOrder) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ExchangeRatesSliceLast.Currency AS Currency,
	|	ExchangeRatesSliceLast.ExchangeRate AS ExchangeRate,
	|	ExchangeRatesSliceLast.Multiplicity AS Multiplicity
	|INTO TemporaryTableExchangeRatesSliceLatest
	|FROM
	|	InformationRegister.ExchangeRates.SliceLast(&PointInTime, Currency IN (&PresentationCurrency, &CurrencyNational)) AS ExchangeRatesSliceLast
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.ExchangeRate AS ExchangeRate,
	|	WorkOrder.Multiplicity AS Multiplicity,
	|	WorkOrder.Date AS Date,
	|	WorkOrder.Start AS Start,
	|	WorkOrder.Finish AS Finish,
	|	WorkOrder.SalesStructuralUnit AS SalesStructuralUnit,
	|	WorkOrder.Responsible AS Responsible,
	|	Counterparties.DoOperationsByContracts AS DoOperationsByContracts,
	|	Counterparties.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	Counterparties.DoOperationsByOrders AS DoOperationsByOrders,
	|	Counterparties.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.IncludeVATInPrice AS IncludeVATInPrice,
	|	WorkOrder.OrderState AS OrderState,
	|	WorkOrderStatuses.OrderStatus AS OrderStatus,
	|	WorkOrder.SetPaymentTerms AS SetPaymentTerms,
	|	WorkOrder.StructuralUnitReserve AS StructuralUnitReserve,
	|	WorkOrder.InventoryWarehouse AS InventoryWarehouse,
	|	Counterparties.GLAccountVendorSettlements AS GLAccountVendorSettlements
	|INTO WorkOrderHeader
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		INNER JOIN Catalog.Counterparties AS Counterparties
	|		ON WorkOrder.Counterparty = Counterparties.Ref
	|		INNER JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON WorkOrder.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
	|WHERE
	|	WorkOrder.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Finish AS Finish,
	|	&Company AS Company,
	|	WorkOrderHeader.SalesStructuralUnit AS StructuralUnit,
	|	WorkOrderHeader.Responsible AS Responsible,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	WorkOrderWorks.Products.ExpensesGLAccount AS GLAccount,
	|	WorkOrderWorks.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderWorks.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	WorkOrderWorks.Ref AS WorkOrder,
	|	WorkOrderWorks.Ref AS Document,
	|	WorkOrderHeader.Counterparty AS Counterparty,
	|	WorkOrderHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	WorkOrderHeader.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	WorkOrderHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	WorkOrderHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	WorkOrderHeader.SettlementsCurrency AS SettlementsCurrency,
	|	WorkOrderHeader.Contract AS Contract,
	|	WorkOrderHeader.SalesStructuralUnit AS DepartmentSales,
	|	WorkOrderWorks.Products.BusinessLine AS BusinessLineSales,
	|	WorkOrderWorks.Products.BusinessLine.GLAccountRevenueFromSales AS AccountStatementSales,
	|	WorkOrderWorks.Products.BusinessLine.GLAccountCostOfSales AS GLAccountCost,
	|	WorkOrderWorks.Products.ProductsType AS ProductsType,
	|	WorkOrderWorks.Quantity AS Quantity,
	|	WorkOrderWorks.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|				THEN WorkOrderWorks.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderWorks.Total * WorkOrderWorks.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|						THEN WorkOrderWorks.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE WorkOrderWorks.VATAmount * WorkOrderWorks.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|				THEN WorkOrderWorks.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderWorks.VATAmount * WorkOrderWorks.Ref.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS VATAmountSales,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|						THEN WorkOrderWorks.VATAmount * RegExchangeRates.ExchangeRate * WorkOrderWorks.Ref.Multiplicity / (WorkOrderWorks.Ref.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE WorkOrderWorks.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|				THEN WorkOrderWorks.Total * RegExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity / (WorkOrderHeader.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderWorks.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	WorkOrderWorks.Quantity AS QuantityPlan,
	|	WorkOrderHeader.OrderStatus AS OrderStatus,
	|	WorkOrderWorks.Ref.Closed AS Closed,
	|	WorkOrderWorks.Specification AS Specification,
	|	WorkOrderWorks.ConnectionKeyForMarkupsDiscounts AS ConnectionKeyForMarkupsDiscounts,
	|	WorkOrderHeader.SetPaymentTerms AS SetPaymentTerms,
	|	WorkOrderHeader.Start AS Start,
	|	WorkOrderWorks.StandardHours AS StandardHours
	|INTO TemporaryTableWorks
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderWorks.Ref = WorkOrderHeader.Ref
	|WHERE
	|	NOT WorkOrderWorks.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(WorkOrderWorks.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND WorkOrderWorks.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Ref AS Document,
	|	WorkOrderHeader.Counterparty AS Counterparty,
	|	WorkOrderHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	WorkOrderHeader.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	WorkOrderHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	WorkOrderHeader.Contract AS Contract,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Finish AS Finish,
	|	WorkOrderHeader.Start AS Start,
	|	&Company AS Company,
	|	UNDEFINED AS CorrOrganization,
	|	WorkOrderHeader.SalesStructuralUnit AS DepartmentSales,
	|	WorkOrderHeader.Responsible AS Responsible,
	|	WorkOrderInventory.Products.BusinessLine AS BusinessLineSales,
	|	WorkOrderInventory.Products.BusinessLine.GLAccountRevenueFromSales AS AccountStatementSales,
	|	WorkOrderInventory.Products.BusinessLine.GLAccountCostOfSales AS GLAccountCost,
	|	WorkOrderInventory.Products.ProductsType AS ProductsType,
	|	WorkOrderHeader.StructuralUnitReserve AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN WorkOrderInventory.StorageBin
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	WorkOrderInventory.Products.InventoryGLAccount AS GLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	CASE
	|		WHEN &UseBatches
	|				AND WorkOrderInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsOnCommission,
	|	WorkOrderInventory.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN WorkOrderInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	WorkOrderInventory.Ref AS WorkOrder,
	|	UNDEFINED AS CorrOrder,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderInventory.Quantity
	|		ELSE WorkOrderInventory.Quantity * WorkOrderInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderInventory.Reserve
	|		ELSE WorkOrderInventory.Reserve * WorkOrderInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|						THEN WorkOrderInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE WorkOrderInventory.VATAmount * WorkOrderHeader.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmount,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|				THEN WorkOrderInventory.VATAmount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderInventory.VATAmount * WorkOrderHeader.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS AmountVATPurchaseSale,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|				THEN WorkOrderInventory.Total * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderInventory.Total * WorkOrderHeader.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.IncludeVATInPrice
	|				THEN 0
	|			ELSE CASE
	|					WHEN WorkOrderInventory.Ref.DocumentCurrency = &CurrencyNational
	|						THEN WorkOrderInventory.VATAmount * RegExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity / (WorkOrderHeader.ExchangeRate * RegExchangeRates.Multiplicity)
	|					ELSE WorkOrderInventory.VATAmount
	|				END
	|		END AS NUMBER(15, 2)) AS VATAmountCur,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = &CurrencyNational
	|				THEN WorkOrderInventory.Total * RegExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity / (WorkOrderHeader.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderInventory.Total
	|		END AS NUMBER(15, 2)) AS AmountCur,
	|	WorkOrderInventory.Total AS SettlementsAmountTakenPassed,
	|	WorkOrderHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	WorkOrderHeader.GLAccountVendorSettlements AS GLAccountVendorSettlements,
	|	WorkOrderHeader.SettlementsCurrency AS SettlementsCurrency,
	|	WorkOrderHeader.OrderStatus AS OrderStatus,
	|	WorkOrderInventory.ConnectionKey AS ConnectionKey,
	|	WorkOrderHeader.SetPaymentTerms AS SetPaymentTerms
	|INTO TemporaryTableProducts
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderInventory.Ref = WorkOrderHeader.Ref
	|WHERE
	|	NOT WorkOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(WorkOrderInventory.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND WorkOrderInventory.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderMaterials.LineNumber AS LineNumber,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Finish AS Finish,
	|	WorkOrderHeader.Start AS Start,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	WorkOrderMaterials.Ref AS Order,
	|	WorkOrderHeader.SalesStructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN WorkOrderMaterials.StorageBin
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	WorkOrderHeader.StructuralUnitReserve AS InventoryStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN WorkOrderMaterials.StorageBin
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	WorkOrderMaterials.Products.InventoryGLAccount AS GLAccount,
	|	CASE
	|		WHEN WorkOrderMaterials.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN WorkOrderMaterials.Products.InventoryGLAccount
	|		ELSE CASE
	|				WHEN WorkOrderHeader.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN WorkOrderMaterials.Products.InventoryGLAccount
	|				ELSE WorkOrderMaterials.Products.ExpensesGLAccount
	|			END
	|	END AS InventoryGLAccount,
	|	CASE
	|		WHEN WorkOrderHeader.SalesStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN WorkOrderWorks.Products.InventoryGLAccount
	|		ELSE WorkOrderWorks.Products.ExpensesGLAccount
	|	END AS CorrGLAccount,
	|	WorkOrderMaterials.Products AS Products,
	|	WorkOrderWorks.Products AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN WorkOrderWorks.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN WorkOrderMaterials.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	WorkOrderWorks.Specification AS SpecificationCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	WorkOrderMaterials.Ref AS WorkOrder,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderMaterials.Quantity
	|		ELSE WorkOrderMaterials.Quantity * WorkOrderMaterials.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(WorkOrderMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN WorkOrderMaterials.Reserve
	|		ELSE WorkOrderMaterials.Reserve * WorkOrderMaterials.MeasurementUnit.Factor
	|	END AS Reserve,
	|	0 AS Amount,
	|	WorkOrderWorks.Products.ExpensesGLAccount AS AccountDr,
	|	CASE
	|		WHEN WorkOrderMaterials.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN WorkOrderMaterials.Products.InventoryGLAccount
	|		ELSE CASE
	|				WHEN WorkOrderHeader.StructuralUnitReserve.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN WorkOrderMaterials.Products.InventoryGLAccount
	|				ELSE WorkOrderMaterials.Products.ExpensesGLAccount
	|			END
	|	END AS AccountCr,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content,
	|	WorkOrderMaterials.Products.ProductsType AS ProductsType,
	|	WorkOrderHeader.OrderStatus AS OrderStatus,
	|	WorkOrderMaterials.ConnectionKeySerialNumbers AS ConnectionKeySerialNumbers,
	|	WorkOrderMaterials.Products.BusinessLine AS BusinessLine
	|INTO TemporaryTableConsumables
	|FROM
	|	Document.WorkOrder.Materials AS WorkOrderMaterials
	|		LEFT JOIN Document.WorkOrder.Works AS WorkOrderWorks
	|		ON WorkOrderMaterials.ConnectionKey = WorkOrderWorks.ConnectionKey
	|			AND WorkOrderMaterials.Ref = WorkOrderWorks.Ref
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderMaterials.Ref = WorkOrderHeader.Ref
	|WHERE
	|	NOT WorkOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|	AND NOT(WorkOrderMaterials.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				AND WorkOrderMaterials.Ref.Closed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderLaborAssignment.LineNumber AS LineNumber,
	|	WorkOrderHeader.Finish AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	BEGINOFPERIOD(WorkOrderHeader.Finish, MONTH) AS RegistrationPeriod,
	|	WorkOrderHeader.DocumentCurrency AS Currency,
	|	WorkOrderHeader.SalesStructuralUnit AS StructuralUnit,
	|	WorkOrderLaborAssignment.Employee AS Employee,
	|	WorkOrderHeader.Start AS StartDate,
	|	WorkOrderHeader.Finish AS EndDate,
	|	0 AS DaysWorked,
	|	WorkOrderWorks.Quantity AS HoursWorked,
	|	WorkOrderLaborAssignment.Employee.SettlementsHumanResourcesGLAccount AS GLAccount,
	|	WorkOrderWorks.Products.ExpensesGLAccount AS CorrespondentAccountAccountingInventory,
	|	WorkOrderWorks.Products AS ProductsCorr,
	|	WorkOrderWorks.Characteristic AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	WorkOrderWorks.Specification AS SpecificationCorr,
	|	WorkOrderLaborAssignment.Ref AS WorkOrder,
	|	WorkOrderLaborAssignment.Ref AS CorrOrder,
	|	WorkOrderHeader.OrderStatus AS OrderStatus
	|INTO TemporaryTableArtist
	|FROM
	|	Document.WorkOrder.LaborAssignment AS WorkOrderLaborAssignment
	|		INNER JOIN Document.WorkOrder.Works AS WorkOrderWorks
	|		ON WorkOrderLaborAssignment.ConnectionKey = WorkOrderWorks.ConnectionKey
	|			AND WorkOrderLaborAssignment.Ref = WorkOrderWorks.Ref
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS ManagExchangeRates
	|		ON (ManagExchangeRates.Currency = &PresentationCurrency)
	|		LEFT JOIN TemporaryTableExchangeRatesSliceLatest AS RegExchangeRates
	|		ON (RegExchangeRates.Currency = &CurrencyNational)
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderLaborAssignment.Ref = WorkOrderHeader.Ref
	|WHERE
	|	WorkOrderWorks.Products.ProductsType = VALUE(Enum.ProductsTypes.Work)
	|	AND WorkOrderLaborAssignment.Ref.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	WorkOrderDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	CAST(CASE
	|			WHEN WorkOrderHeader.DocumentCurrency = ConstantNationalCurrency.Value
	|				THEN WorkOrderDiscountsMarkups.Amount * RegExchangeRates.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * RegExchangeRates.Multiplicity)
	|			ELSE WorkOrderDiscountsMarkups.Amount * WorkOrderHeader.ExchangeRate * ManagExchangeRates.Multiplicity / (ManagExchangeRates.ExchangeRate * WorkOrderHeader.Multiplicity)
	|		END AS NUMBER(15, 2)) AS Amount,
	|	WorkOrderHeader.Date AS Period,
	|	WorkOrderHeader.Counterparty AS StructuralUnit
	|INTO TemporaryTableAutoDiscountsMarkups
	|FROM
	|	Document.WorkOrder.DiscountsMarkups AS WorkOrderDiscountsMarkups
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS ManagExchangeRates
	|		ON (TRUE)
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantNationalCurrency.Value
	|					FROM
	|						Constant.FunctionalCurrency AS ConstantNationalCurrency)) AS RegExchangeRates
	|		ON (TRUE)
	|		INNER JOIN WorkOrderHeader AS WorkOrderHeader
	|		ON WorkOrderDiscountsMarkups.Ref = WorkOrderHeader.Ref,
	|	Constant.FunctionalCurrency AS ConstantNationalCurrency
	|WHERE
	|	WorkOrderDiscountsMarkups.Amount <> 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderSerialNumbers.ConnectionKey AS ConnectionKey,
	|	WorkOrderSerialNumbers.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbers
	|FROM
	|	WorkOrderHeader AS WorkOrderHeader
	|		INNER JOIN Document.WorkOrder.SerialNumbers AS WorkOrderSerialNumbers
	|		ON WorkOrderHeader.Ref = WorkOrderSerialNumbers.Ref
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderSerialNumbersMaterials.ConnectionKey AS ConnectionKey,
	|	WorkOrderSerialNumbersMaterials.SerialNumber AS SerialNumber
	|INTO TemporaryTableSerialNumbersMaterials
	|FROM
	|	WorkOrderHeader AS WorkOrderHeader
	|		INNER JOIN Document.WorkOrder.SerialNumbersMaterials AS WorkOrderSerialNumbersMaterials
	|		ON WorkOrderHeader.Ref = WorkOrderSerialNumbersMaterials.Ref
	|WHERE
	|	&UseSerialNumbers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderPaymentCalendar.LineNumber AS LineNumber,
	|	WorkOrderPaymentCalendar.PaymentDate AS Period,
	|	&Company AS Company,
	|	WorkOrderHeader.Counterparty AS Counterparty,
	|	WorkOrderHeader.DoOperationsByContracts AS DoOperationsByContracts,
	|	WorkOrderHeader.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	WorkOrderHeader.DoOperationsByOrders AS DoOperationsByOrders,
	|	WorkOrderHeader.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	WorkOrderHeader.Contract AS Contract,
	|	WorkOrderHeader.SettlementsCurrency AS SettlementsCurrency,
	|	&Ref AS DocumentWhere,
	|	VALUE(Enum.SettlementsTypes.Debt) AS SettlemensTypeWhere,
	|	&Ref AS Order,
	|	CASE
	|		WHEN WorkOrderHeader.AmountIncludesVAT
	|			THEN CAST(WorkOrderPaymentCalendar.PaymentAmount * WorkOrderHeader.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * WorkOrderHeader.Multiplicity) AS NUMBER(15, 2))
	|		ELSE CAST((WorkOrderPaymentCalendar.PaymentAmount + WorkOrderPaymentCalendar.PaymentVATAmount) * WorkOrderHeader.ExchangeRate * AccountingExchangeRatesSliceLast.Multiplicity / (AccountingExchangeRatesSliceLast.ExchangeRate * WorkOrderHeader.Multiplicity) AS NUMBER(15, 2))
	|	END AS Amount,
	|	CASE
	|		WHEN WorkOrderHeader.AmountIncludesVAT
	|			THEN WorkOrderPaymentCalendar.PaymentAmount
	|		ELSE WorkOrderPaymentCalendar.PaymentAmount + WorkOrderPaymentCalendar.PaymentVATAmount
	|	END AS AmountCur
	|INTO TemporaryTablePaymentCalendarWithoutGroup
	|FROM
	|	WorkOrderHeader AS WorkOrderHeader
	|		INNER JOIN Document.WorkOrder.PaymentCalendar AS WorkOrderPaymentCalendar
	|		ON WorkOrderHeader.Ref = WorkOrderPaymentCalendar.Ref
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(
	|				&PointInTime,
	|				Currency IN
	|					(SELECT
	|						ConstantAccountingCurrency.Value
	|					FROM
	|						Constant.PresentationCurrency AS ConstantAccountingCurrency)) AS AccountingExchangeRatesSliceLast
	|		ON (TRUE)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MAX(Calendar.LineNumber) AS LineNumber,
	|	Calendar.Period AS Period,
	|	Calendar.Company AS Company,
	|	Calendar.Counterparty AS Counterparty,
	|	Calendar.DoOperationsByContracts AS DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments AS DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders AS DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements AS GLAccountCustomerSettlements,
	|	Calendar.Contract AS Contract,
	|	Calendar.SettlementsCurrency AS SettlementsCurrency,
	|	Calendar.DocumentWhere AS DocumentWhere,
	|	Calendar.SettlemensTypeWhere AS SettlemensTypeWhere,
	|	Calendar.Order AS Order,
	|	SUM(Calendar.Amount) AS Amount,
	|	SUM(Calendar.AmountCur) AS AmountCur
	|INTO TemporaryTablePaymentCalendar
	|FROM
	|	TemporaryTablePaymentCalendarWithoutGroup AS Calendar
	|
	|GROUP BY
	|	Calendar.Period,
	|	Calendar.Company,
	|	Calendar.Counterparty,
	|	Calendar.DoOperationsByContracts,
	|	Calendar.DoOperationsByDocuments,
	|	Calendar.DoOperationsByOrders,
	|	Calendar.GLAccountCustomerSettlements,
	|	Calendar.Contract,
	|	Calendar.SettlementsCurrency,
	|	Calendar.DocumentWhere,
	|	Calendar.SettlemensTypeWhere,
	|	Calendar.Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP TemporaryTablePaymentCalendarWithoutGroup
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|DROP WorkOrderHeader";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref",					DocumentRefWorkOrder);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("PointInTime",			New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("InventoryDistribution",	NStr("en = 'Inventory allocation'", MainLanguageCode));
	Query.SetParameter("UseSerialNumbers",		StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("PresentationCurrency",	Constants.PresentationCurrency.Get());
	Query.SetParameter("CurrencyNational",		Constants.FunctionalCurrency.Get());
	
	Query.ExecuteBatch();
	
	DriveServer.GenerateTransactionsTable(DocumentRefWorkOrder, StructureAdditionalProperties);
	
	GenerateTableInventoryFlowCalendar(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableWorkOrders(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableInventory(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableStockReceivedFromThirdParties(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTablePaymentCalendar(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableTimesheet(DocumentRefWorkOrder, StructureAdditionalProperties);
	GenerateTableConsumedMaterials(DocumentRefWorkOrder, StructureAdditionalProperties);
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentObjectWorkOrder, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;
	
	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If temporary tables "RegisterRecordsInventoryInWarehousesChange",
	// " " "RegisterRecordsWorkOrdersChange",
	// "RegisterRecordsInventoryDemandChange", "RegisterRecordsAccountsReceivableChange" contain records, execute
	// the control of balances.
		
	If StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsWorkOrdersChange Then
		
		Query = New Query;
		Query.Text = GenerateQueryTextBalancesInventory()
			+ GenerateQueryTextBalancesWorkOrders();
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		// Negative balance of inventory.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on work order.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToWorkOrdersRegisterErrors(DocumentObjectWorkOrder, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

// Calculates earning amount for assignee row
//
//
Function ComputeEarningValueByRowAtServer(WorkCoefficients, WorkAmount, LPF, AmountLPF, EarningAndDeductionType, Size) Export
	
	If EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePayFixedAmount Then
		
		Return Size;
		
	ElsIf EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePay Then
		
		Return WorkCoefficients * Size * (LPF / AmountLPF);
		
	ElsIf EarningAndDeductionType = Catalogs.EarningAndDeductionTypes.PieceRatePayPercent Then
		
		Return (WorkAmount / 100 * Size) * (LPF / AmountLPF);
		
	EndIf;
	
EndFunction

// Returns the row from TS Works to specified key
//
// TabularSectionWorks - TS of Work, wob order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function GetRowWorksByConnectionKey(TabularSectionWorks, ConnectionKey) Export
	
	ArrayFoundStrings = TabularSectionWorks.FindRows(New Structure("ConnectionKey", ConnectionKey));
	
	Return ?(ArrayFoundStrings.Count() <> 1, Undefined, ArrayFoundStrings[0]);
	
EndFunction

// Returns the rows of Performers TS by received connection key
//
// TabularSectionPerformers - TS Performers of Work order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function GetRowsPerformersByConnectionKey(TabularSectionPerformers, ConnectionKey) Export
	
	Return TabularSectionPerformers.FindRows(New Structure("ConnectionKey", ConnectionKey));
	
EndFunction

// Returns the amount of Performers LPC included in the Earning for specified work
// 
// TabularSectionPerformers - TS Performers of Work order document;
// ConnectionKey - ConnectionKey attribute value;
//
Function ComputeLPFSumByConnectionKey(TabularSectionPerformers, ConnectionKey) Export
	
	If Not ValueIsFilled(ConnectionKey) Then
		
		Return 1;
		
	EndIf;
	
	Query = New Query;
	Query.TempTablesManager = New TempTablesManager;
	
	Query.Text = 
	"SELECT *
	|INTO CWT_Performers
	|FROM
	|	&TabularSection AS SalesOrderPerformers
	| WHERE SalesOrderPerformers.ConnectionKey = &ConnectionKey";
	
	Query.SetParameter("ConnectionKey", ConnectionKey);
	Query.SetParameter("TabularSection", TabularSectionPerformers.Unload());
	Query.Execute();
	
	Query.Text = 
	"SELECT
	|	SUM(CWT_Performers.LPR) AS AmountLPR
	|FROM
	|	CWT_Performers AS CWT_Performers";
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then 
		
		Return 1;
		
	EndIf;
		
	Selection = QueryResult.Select();
	Selection.Next();
	
	Return ?(Selection.AmountLPR = 0, 1, Selection.AmountLPR);
	
EndFunction

Function ArePerformersWithEmptyEarningSum(LaborAssignment) Export
	
	Var Errors;
	MessageTextTemplate = NStr("en = 'Earnings for employee %1 in line %2 are incorrect.'");
	
	For Each Performer In LaborAssignment Do
		
		If Performer.HoursWorked = 0 Then
			
			SingleErrorText = 
				StringFunctionsClientServer.SubstituteParametersInString(MessageTextTemplate, Performer.Employee.Description, Performer.LineNumber);
			
			CommonUseClientServer.AddUserError(
				Errors, 
				"Object.LaborAssignment[%1].Employee", 
				SingleErrorText, 
				Undefined, 
				Performer.LineNumber);
			
		EndIf;
		
	EndDo;
	
	If ValueIsFilled(Errors) Then
		
		CommonUseClientServer.ShowErrorsToUser(Errors);
		Return True;
		
	EndIf;
	
	Return False;
	
EndFunction

// Checks the possibility of input on the basis.
//
Procedure CheckAbilityOfEnteringByWorkOrder(FillingData, AttributeValues) Export
	
	If AttributeValues.Property("Posted") Then
		If Not AttributeValues.Posted Then
			ErrorText = NStr("en = '%1 is not posted. Cannot use it as a base document. Please, post it first.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FillingData);
			Raise ErrorText;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("Closed") Then
		If (AttributeValues.Property("WorkOrderReturn") AND Constants.UseWorkOrderStatuses.Get())
			OR Not AttributeValues.Property("WorkOrderReturn") Then
			If AttributeValues.Closed Then
				ErrorText = NStr("en = '%1 is completed. Cannot use a completed order as a base document.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FillingData);
				Raise ErrorText;
			EndIf;
		EndIf;
	EndIf;
	
	If AttributeValues.Property("OrderState") Then
		
		If AttributeValues.OrderState.OrderStatus = Enums.OrderStatuses.Open Then
			ErrorText = NStr("en = 'The status of %1 is %2. Cannot use it as a base document.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText, FillingData, AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
		
		If AttributeValues.Property("WorkOrderReturn") Then
			If AttributeValues.OrderState.OrderStatus <> Enums.OrderStatuses.Completed Then
				ErrorText = NStr("en = 'The status of %1 is %2. Cannot use it as a base document for a return.'");
				ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText,
					FillingData,
					AttributeValues.OrderState);
				Raise ErrorText;
			EndIf;
		ElsIf AttributeValues.OrderState.OrderStatus <> Enums.OrderStatuses.InProcess Then
			ErrorText = NStr("en = 'The status of %1 is %2. Cannot use it as a base document.'");
			ErrorText = StringFunctionsClientServer.SubstituteParametersInString(ErrorText,
				FillingData,
				AttributeValues.OrderState);
			Raise ErrorText;
		EndIf;
		
	EndIf;
	
EndProcedure

Function CanceledStatus() Export
	Return "Canceled";
EndFunction

Function InProcessStatus() Export
	Return "In process";
EndFunction

Function CompletedStatus() Export
	Return "Completed";
EndFunction

#Region InfobaseUpdate

// Replaces an empty sales order reference with an undefined
//
Procedure ChangeSalesOrderEmptyRefToUndefined() Export
	
	Documents.InventoryReservation.ChangeSalesOrderEmptyRefToUndefined();
	
	Documents.SalesInvoice.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.Inventory.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.InventoryCostLayer.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.AccountsReceivable.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.IncomeAndExpenses.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.FinancialResult.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.LandedCosts.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.ProductRelease.ChangeSalesOrderEmptyRefToUndefined();
	
	AccumulationRegisters.Sales.ChangeSalesOrderEmptyRefToUndefined();
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

Procedure PresentationFieldsGetProcessing(Fields, StandardProcessing)
	
	StandardProcessing = False;
	Fields.Add("Ref");
	Fields.Add("Date");
	Fields.Add("Number");
	Fields.Add("OperationKind");
	Fields.Add("Posted");
	Fields.Add("DeletionMark");
	
EndProcedure

Procedure PresentationGetProcessing(Data, Presentation, StandardProcessing)
	
	If Data.Number = Null Then
		Return;
	EndIf;
	
	StandardProcessing = False;
	
	If Data.Posted Then
		State = "";
	Else
		If Data.DeletionMark Then
			State = NStr("en = '(deleted)'");
		ElsIf Data.Property("Posted") AND Not Data.Posted Then
			State = NStr("en = '(not posted)'");
		EndIf;
	EndIf;
	
	TitlePresentation = NStr("en = 'Work order'");
	
	Presentation = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 %2 dated %3 %4'"),
		TitlePresentation,
		?(Data.Property("Number"), ObjectPrefixationClientServer.GetNumberForPrinting(Data.Number, True, True), ""),
		Format(Data.Date, "DLF=D"),
		State);
	
EndProcedure

#EndRegion

#Region Private

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventory(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	Query.Text = 
	"SELECT
	|	MIN(TemporaryTableProducts.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TemporaryTableProducts.Period AS Period,
	|	TemporaryTableProducts.Company AS Company,
	|	TemporaryTableProducts.StructuralUnit AS StructuralUnit,
	|	TemporaryTableProducts.StructuralUnit AS StructuralUnitCorr,
	|	TemporaryTableProducts.GLAccount AS GLAccount,
	|	TemporaryTableProducts.GLAccount AS CorrGLAccount,
	|	TemporaryTableProducts.Products AS Products,
	|	TemporaryTableProducts.Products AS ProductsCorr,
	|	TemporaryTableProducts.Characteristic AS Characteristic,
	|	TemporaryTableProducts.Characteristic AS CharacteristicCorr,
	|	TemporaryTableProducts.Batch AS Batch,
	|	TemporaryTableProducts.Batch AS BatchCorr,
	|	CASE
	|		WHEN TemporaryTableProducts.WorkOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTableProducts.WorkOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TemporaryTableProducts.WorkOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TemporaryTableProducts.WorkOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTableProducts.WorkOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TemporaryTableProducts.WorkOrder
	|	END AS CustomerCorrOrder,
	|	&InventoryReservation AS ContentOfAccountingRecord,
	|	SUM(TemporaryTableProducts.Reserve) AS Quantity,
	|	0 AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProducts AS TemporaryTableProducts
	|
	|GROUP BY
	|	TemporaryTableProducts.Period,
	|	TemporaryTableProducts.Company,
	|	TemporaryTableProducts.StructuralUnit,
	|	TemporaryTableProducts.GLAccount,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.Batch,
	|	TemporaryTableProducts.WorkOrder,
	|	TemporaryTableProducts.StructuralUnit,
	|	TemporaryTableProducts.GLAccount,
	|	TemporaryTableProducts.Products,
	|	TemporaryTableProducts.Characteristic,
	|	TemporaryTableProducts.Batch,
	|	TemporaryTableProducts.WorkOrder
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TemporaryTableConsumables.LineNumber),
	|	VALUE(AccumulationRecordType.Expense),
	|	TemporaryTableConsumables.Period,
	|	TemporaryTableConsumables.Company,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Batch,
	|	TemporaryTableConsumables.Batch,
	|	CASE
	|		WHEN TemporaryTableConsumables.WorkOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTableConsumables.WorkOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TemporaryTableConsumables.WorkOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN TemporaryTableConsumables.WorkOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR TemporaryTableConsumables.WorkOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE TemporaryTableConsumables.WorkOrder
	|	END AS CustomerCorrOrder,
	|	&InventoryReservation,
	|	SUM(TemporaryTableConsumables.Reserve),
	|	0,
	|	FALSE
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|
	|GROUP BY
	|	TemporaryTableConsumables.Period,
	|	TemporaryTableConsumables.Company,
	|	TemporaryTableConsumables.StructuralUnit,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Batch,
	|	TemporaryTableConsumables.WorkOrder,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.InventoryStructuralUnit,
	|	TemporaryTableConsumables.GLAccount,
	|	TemporaryTableConsumables.Products,
	|	TemporaryTableConsumables.Characteristic,
	|	TemporaryTableConsumables.Batch,
	|	TemporaryTableConsumables.WorkOrder";
	
	Query.SetParameter("InventoryReservation", NStr("en = 'Inventory reservation'", CommonUseClientServer.MainLanguageCode()));
	
	Result = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", Result.Unload());
	
	GenerateTableRowsInventory(DocumentRefWorkOrder, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableRowsInventory(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	FillAmount = StructureAdditionalProperties.AccountingPolicy.InventoryValuationMethod = Enums.InventoryValuationMethods.WeightedAverage;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	UNDEFINED AS SalesOrder
	|FROM
	|	TemporaryTableProducts AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Inventory");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receiving inventory balances by cost.
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company AS Company,
	|						TableInventory.StructuralUnit AS StructuralUnit,
	|						TableInventory.GLAccount AS GLAccount,
	|						TableInventory.Products AS Products,
	|						TableInventory.Characteristic AS Characteristic,
	|						TableInventory.Batch AS Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableProducts AS TableInventory
	|				
	|					UNION ALL
	|				
	|					SELECT
	|						TableConsumables.Company,
	|						TableConsumables.StructuralUnit,
	|						TableConsumables.GLAccount,
	|						TableConsumables.Products,
	|						TableConsumables.Characteristic,
	|						TableConsumables.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableConsumables AS TableConsumables)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
	
	TemporaryTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.CopyColumns();

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredReserve;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;
			EndIf;
	
			// Expense.
			TableRowExpense = TemporaryTableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			If FillAmount Then
				TableRowExpense.Amount = AmountToBeWrittenOff;
			EndIf;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 OR QuantityRequiredReserve > 0 Then
				
				TableRowReceipt = TemporaryTableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				
				If FillAmount Then
					TableRowReceipt.Amount = AmountToBeWrittenOff;
				EndIf;
				TableRowReceipt.Quantity = QuantityRequiredReserve;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
					
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory = TemporaryTableInventory;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableWorkOrders(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableWorkOrders.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableWorkOrders.Period AS Period,
	|	TableWorkOrders.Company AS Company,
	|	TableWorkOrders.Products AS Products,
	|	TableWorkOrders.Characteristic AS Characteristic,
	|	TableWorkOrders.WorkOrder AS WorkOrder,
	|	SUM(TableWorkOrders.QuantityPlan * TableWorkOrders.StandardHours) AS Quantity,
	|	TableWorkOrders.Start AS ShipmentDate
	|FROM
	|	TemporaryTableWorks AS TableWorkOrders
	|
	|GROUP BY
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder,
	|	TableWorkOrders.Start
	|
	|UNION ALL
	|
	|SELECT
	|	MIN(TableWorkOrders.LineNumber),
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder,
	|	SUM(TableWorkOrders.Quantity),
	|	TableWorkOrders.Start
	|FROM
	|	TemporaryTableProducts AS TableWorkOrders
	|
	|GROUP BY
	|	TableWorkOrders.Period,
	|	TableWorkOrders.Company,
	|	TableWorkOrders.Products,
	|	TableWorkOrders.Characteristic,
	|	TableWorkOrders.WorkOrder,
	|	TableWorkOrders.Start";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableWorkOrders", QueryResult.Unload());
	
EndProcedure

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTablePaymentCalendar(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("PointInTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	Query.Text =
	"SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Start AS ShipmentDate,
	|	WorkOrder.AmountIncludesVAT AS AmountIncludesVAT,
	|	WorkOrder.CashAssetsType AS CashAssetsType,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.PettyCash AS PettyCash,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.BankAccount AS BankAccount,
	|	WorkOrder.Closed AS Closed,
	|	WorkOrder.OrderState AS OrderState
	|INTO Document
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref = &Ref
	|	AND NOT WorkOrder.Closed
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderPaymentCalendar.PaymentDate AS Period,
	|	Document.CashAssetsType AS CashAssetsType,
	|	Document.Ref AS Quote,
	|	CounterpartyContracts.SettlementsCurrency AS SettlementsCurrency,
	|	CounterpartyContracts.SettlementsInStandardUnits AS SettlementsInStandardUnits,
	|	Document.PettyCash AS PettyCash,
	|	Document.DocumentCurrency AS DocumentCurrency,
	|	Document.BankAccount AS BankAccount,
	|	Document.Ref AS Ref,
	|	CASE
	|		WHEN Document.AmountIncludesVAT
	|			THEN WorkOrderPaymentCalendar.PaymentAmount
	|		ELSE WorkOrderPaymentCalendar.PaymentAmount + WorkOrderPaymentCalendar.PaymentVATAmount
	|	END AS PaymentAmount
	|INTO PaymentCalendar
	|FROM
	|	Document AS Document
	|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON Document.OrderState = WorkOrderStatuses.Ref
	|			AND (WorkOrderStatuses.OrderStatus IN (VALUE(Enum.OrderStatuses.InProcess), VALUE(Enum.OrderStatuses.Completed)))
	|		INNER JOIN Document.WorkOrder.PaymentCalendar AS WorkOrderPaymentCalendar
	|		ON Document.Ref = WorkOrderPaymentCalendar.Ref
	|			AND Document.ShipmentDate >= WorkOrderPaymentCalendar.PaymentDate
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON Document.Contract = CounterpartyContracts.Ref
	|		INNER JOIN Constant.UsePaymentCalendar AS UsePaymentCalendar
	|		ON (UsePaymentCalendar.Value)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	PaymentCalendar.Period AS Period,
	|	&Company AS Company,
	|	PaymentCalendar.CashAssetsType AS CashAssetsType,
	|	VALUE(Enum.PaymentApprovalStatuses.Approved) AS PaymentConfirmationStatus,
	|	PaymentCalendar.Ref AS Quote,
	|	VALUE(Catalog.CashFlowItems.PaymentFromCustomers) AS Item,
	|	CASE
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Cash)
	|			THEN PaymentCalendar.PettyCash
	|		WHEN PaymentCalendar.CashAssetsType = VALUE(Enum.CashAssetTypes.Noncash)
	|			THEN PaymentCalendar.BankAccount
	|		ELSE UNDEFINED
	|	END AS BankAccountPettyCash,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN PaymentCalendar.SettlementsCurrency
	|		ELSE PaymentCalendar.DocumentCurrency
	|	END AS Currency,
	|	CASE
	|		WHEN PaymentCalendar.SettlementsInStandardUnits
	|			THEN CAST(PaymentCalendar.PaymentAmount * CASE
	|						WHEN SettlementsExchangeRates.ExchangeRate <> 0
	|								AND ExchangeRatesOfDocument.Multiplicity <> 0
	|							THEN ExchangeRatesOfDocument.ExchangeRate * SettlementsExchangeRates.Multiplicity / (ISNULL(SettlementsExchangeRates.ExchangeRate, 1) * ISNULL(ExchangeRatesOfDocument.Multiplicity, 1))
	|						ELSE 1
	|					END AS NUMBER(15, 2))
	|		ELSE PaymentCalendar.PaymentAmount
	|	END AS Amount
	|FROM
	|	PaymentCalendar AS PaymentCalendar
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS ExchangeRatesOfDocument
	|		ON PaymentCalendar.DocumentCurrency = ExchangeRatesOfDocument.Currency
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&PointInTime, ) AS SettlementsExchangeRates
	|		ON PaymentCalendar.SettlementsCurrency = SettlementsExchangeRates.Currency";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TablePaymentCalendar", QueryResult.Unload());
	
EndProcedure

// Payment calendar table formation procedure.
//
// Parameters:
// DocumentRef - DocumentRef.CashInflowForecast - Current
// document AdditionalProperties - AdditionalProperties - Additional properties of the document
//
Procedure GenerateTableTimesheet(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkOrder.Date AS Period,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.SalesStructuralUnit AS StructuralUnit,
	|	WorkOrderLaborAssignment.Employee AS Employee,
	|	WorkOrderLaborAssignment.PayCode AS TimeKind,
	|	WorkOrderLaborAssignment.HoursWorked AS Hours,
	|	WorkOrderLaborAssignment.Position AS Position
	|FROM
	|	Document.WorkOrder.LaborAssignment AS WorkOrderLaborAssignment
	|		INNER JOIN Document.WorkOrder AS WorkOrder
	|			INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|			ON WorkOrder.OrderState = WorkOrderStatuses.Ref
	|		ON WorkOrderLaborAssignment.Ref = WorkOrder.Ref
	|WHERE
	|	WorkOrderLaborAssignment.Ref = &Ref
	|	AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);

	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("ScheduleTable", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableStockReceivedFromThirdParties(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	WorkOrders.Finish AS Period,
	|	MIN(WorkOrderConsumersInventory.LineNumber) AS LineNumber,
	|	WorkOrders.Company AS Company,
	|	WorkOrderConsumersInventory.Products AS Products,
	|	WorkOrderConsumersInventory.Characteristic AS Characteristic,
	|	WorkOrderConsumersInventory.Batch AS Batch,
	|	WorkOrders.Counterparty AS Counterparty,
	|	WorkOrders.Contract AS Contract,
	|	SUM(WorkOrderConsumersInventory.Quantity) AS Quantity,
	|	CAST(&InventoryIncreaseProductsOnCommission AS STRING(100)) AS ContentOfAccountingRecord,
	|	WorkOrderConsumersInventory.Ref AS Order
	|FROM
	|	Document.WorkOrder.ConsumersInventory AS WorkOrderConsumersInventory
	|		INNER JOIN Document.WorkOrder AS WorkOrders
	|			INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|			ON WorkOrders.OrderState = WorkOrderStatuses.Ref
	|		ON WorkOrderConsumersInventory.Ref = WorkOrders.Ref
	|WHERE
	|	WorkOrderConsumersInventory.Ref = &Ref
	|	AND WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|	AND WorkOrders.WriteOffCustomersInventory
	|
	|GROUP BY
	|	WorkOrders.Finish,
	|	WorkOrders.Company,
	|	WorkOrderConsumersInventory.Products,
	|	WorkOrderConsumersInventory.Characteristic,
	|	WorkOrderConsumersInventory.Batch,
	|	WorkOrders.Counterparty,
	|	WorkOrders.Contract,
	|	WorkOrderConsumersInventory.Ref";
	
	Query.SetParameter("Ref", DocumentRefWorkOrder);
	Query.SetParameter("InventoryIncreaseProductsOnCommission", NStr("en = 'Customer's inventory'", CommonUseClientServer.MainLanguageCode()));
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryFlowCalendar(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	1 AS Ordering,
	|	TableProducts.LineNumber AS LineNumber,
	|	BEGINOFPERIOD(TableProducts.Start, Day) AS Period,
	|	TableProducts.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableProducts.WorkOrder AS Order,
	|	TableProducts.Products AS Products,
	|	TableProducts.Characteristic AS Characteristic,
	|	TableProducts.Quantity AS Quantity
	|FROM
	|	TemporaryTableProducts AS TableProducts
	|
	|UNION ALL
	|
	|SELECT
	|	2,
	|	TableMaterials.LineNumber,
	|	BEGINOFPERIOD(TableMaterials.Start, Day),
	|	TableMaterials.Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment),
	|	TableMaterials.Order,
	|	TableMaterials.Products,
	|	TableMaterials.Characteristic,
	|	TableMaterials.Quantity
	|FROM
	|	TemporaryTableConsumables AS TableMaterials
	|
	|ORDER BY
	|	Ordering,
	|	LineNumber";
	
	QueryResult = Query.Execute();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryFlowCalendar", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableConsumedMaterials(DocumentRefWorkOrder, StructureAdditionalProperties)
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
	TableIncomeAndExpenses = DriveServer.EmptyIncomeAndExpensesTable();
	
	QueryConsumables = New Query;
	QueryConsumables.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	QueryConsumables.Text = 
	"SELECT
	|	TemporaryTableConsumables.LineNumber AS LineNumber,
	|	TemporaryTableConsumables.Period AS Period,
	|	TemporaryTableConsumables.Company AS Company,
	|	TemporaryTableConsumables.InventoryStructuralUnit AS BusinessUnit,
	|	TemporaryTableConsumables.GLAccount AS GLAccount,
	|	TemporaryTableConsumables.Products AS Products,
	|	TemporaryTableConsumables.Characteristic AS Characteristic,
	|	TemporaryTableConsumables.Batch AS Batch,
	|	TemporaryTableConsumables.Quantity AS Quantity,
	|	TemporaryTableConsumables.Amount AS Amount,
	|	TemporaryTableConsumables.AccountDr AS AccountDr,
	|	TemporaryTableConsumables.AccountCr AS AccountCr,
	|	TemporaryTableConsumables.ContentOfAccountingRecord AS Content,
	|	TemporaryTableConsumables.PlanningPeriod AS PlanningPeriod,
	|	TemporaryTableConsumables.BusinessLine AS BusinessLine,
	|	TemporaryTableConsumables.StructuralUnit AS StructuralUnit
	|FROM
	|	TemporaryTableConsumables AS TemporaryTableConsumables
	|WHERE
	|	TemporaryTableConsumables.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
	
	ConsumablesResult = QueryConsumables.Execute();
	
	If Not ConsumablesResult.IsEmpty() Then
		
		Query = New Query;
		Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
		
		// Receiving inventory balances by cost.
		Query.Text = 
		"SELECT
		|	InventoryBalances.Company AS Company,
		|	InventoryBalances.StructuralUnit AS StructuralUnit,
		|	InventoryBalances.GLAccount AS GLAccount,
		|	InventoryBalances.Products AS Products,
		|	InventoryBalances.Characteristic AS Characteristic,
		|	InventoryBalances.Batch AS Batch,
		|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|	SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|FROM
		|	(SELECT
		|		InventoryBalances.Company AS Company,
		|		InventoryBalances.StructuralUnit AS StructuralUnit,
		|		InventoryBalances.GLAccount AS GLAccount,
		|		InventoryBalances.Products AS Products,
		|		InventoryBalances.Characteristic AS Characteristic,
		|		InventoryBalances.Batch AS Batch,
		|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
		|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
		|	FROM
		|		AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
		|					(SELECT
		|						TableInventory.Company,
		|						TableInventory.InventoryStructuralUnit,
		|						TableInventory.GLAccount,
		|						TableInventory.Products,
		|						TableInventory.Characteristic,
		|						TableInventory.Batch,
		|						UNDEFINED AS SalesOrder
		|					FROM
		|						TemporaryTableConsumables AS TableInventory)) AS InventoryBalances
		|	
		|	GROUP BY
		|		InventoryBalances.Company,
		|		InventoryBalances.StructuralUnit,
		|		InventoryBalances.GLAccount,
		|		InventoryBalances.Products,
		|		InventoryBalances.Characteristic,
		|		InventoryBalances.Batch
		|	
		|	UNION ALL
		|	
		|	SELECT
		|		DocumentRegisterRecordsInventory.Company,
		|		DocumentRegisterRecordsInventory.StructuralUnit,
		|		DocumentRegisterRecordsInventory.GLAccount,
		|		DocumentRegisterRecordsInventory.Products,
		|		DocumentRegisterRecordsInventory.Characteristic,
		|		DocumentRegisterRecordsInventory.Batch,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
		|		END,
		|		CASE
		|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
		|				THEN ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Amount, 0)
		|		END
		|	FROM
		|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
		|	WHERE
		|		DocumentRegisterRecordsInventory.Recorder = &Ref
		|		AND DocumentRegisterRecordsInventory.Period <= &ControlPeriod) AS InventoryBalances
		|
		|GROUP BY
		|	InventoryBalances.Company,
		|	InventoryBalances.StructuralUnit,
		|	InventoryBalances.GLAccount,
		|	InventoryBalances.Products,
		|	InventoryBalances.Characteristic,
		|	InventoryBalances.Batch";
		
		Query.SetParameter("Ref", DocumentRefWorkOrder);
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
		Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
		
		QueryResult = Query.Execute();
		
		TableInventoryBalances = QueryResult.Unload();
		TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch");
		
		TableConsumables = ConsumablesResult.Unload();
		
		For n = 0 To TableConsumables.Count() - 1 Do
			
			SelectionConsumables = TableConsumables[n];
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Company", SelectionConsumables.Company);
			StructureForSearch.Insert("StructuralUnit", SelectionConsumables.BusinessUnit);
			StructureForSearch.Insert("GLAccount", SelectionConsumables.GLAccount);
			StructureForSearch.Insert("Products", SelectionConsumables.Products);
			StructureForSearch.Insert("Characteristic", SelectionConsumables.Characteristic);
			StructureForSearch.Insert("Batch", SelectionConsumables.Batch);
			
			QuantityWanted = SelectionConsumables.Quantity;
			
			If QuantityWanted > 0 Then
				
				BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
				
				QuantityBalance = 0;
				AmountBalance = 0;
				
				If BalanceRowsArray.Count() > 0 Then
					QuantityBalance = BalanceRowsArray[0].QuantityBalance;
					AmountBalance = BalanceRowsArray[0].AmountBalance;
				EndIf;
				
				If QuantityBalance > 0 AND QuantityBalance > QuantityWanted Then
					
					AmountToBeWrittenOff = Round(AmountBalance * QuantityWanted / QuantityBalance , 2, 1);
					
					BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityWanted;
					BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
					
				ElsIf QuantityBalance = QuantityWanted Then
					
					AmountToBeWrittenOff = AmountBalance;
					
					BalanceRowsArray[0].QuantityBalance = 0;
					BalanceRowsArray[0].AmountBalance = 0;
					
				Else
					AmountToBeWrittenOff = 0;
				EndIf;
				
				SelectionConsumables.Amount = AmountToBeWrittenOff;
				SelectionConsumables.Quantity = QuantityWanted;
				
			EndIf;
			
			// Generate postings.
			If Round(SelectionConsumables.Amount, 2, 1) <> 0 Then
				
				RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntries, SelectionConsumables);
				
				RowTableIncomeAndExpenses = TableIncomeAndExpenses.Add();
				FillPropertyValues(RowTableIncomeAndExpenses, SelectionConsumables);
				RowTableIncomeAndExpenses.AmountExpense = SelectionConsumables.Amount;
				RowTableIncomeAndExpenses.ContentOfAccountingRecord = SelectionConsumables.Content;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefWorkOrder);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", TableIncomeAndExpenses);
	
EndProcedure

// Function returns batch query template.
//
Function GenerateBatchQueryTemplate()
	
	QueryText =
	Chars.LF +
	";
	|
	|////////////////////////////////////////////////////////////////////////////////"
	+ Chars.LF;
	
	Return QueryText;
	
EndFunction

// Function returns query text by the balance of Inventory register.
//
Function GenerateQueryTextBalancesInventory()
	
	QueryText =
	"SELECT
	|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
	|	RegisterRecordsInventoryChange.Company AS CompanyPresentation,
	|	RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnitPresentation,
	|	RegisterRecordsInventoryChange.GLAccount AS GLAccountPresentation,
	|	RegisterRecordsInventoryChange.Products AS ProductsPresentation,
	|	RegisterRecordsInventoryChange.Characteristic AS CharacteristicPresentation,
	|	RegisterRecordsInventoryChange.Batch AS BatchPresentation,
	|	RegisterRecordsInventoryChange.SalesOrder AS SalesOrderPresentation,
	|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
	|	InventoryBalances.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
	|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
	|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
	|FROM
	|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
	|		INNER JOIN AccumulationRegister.Inventory.Balance(&ControlTime, ) AS InventoryBalances
	|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
	|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
	|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
	|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
	|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
	|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
	|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
	|			AND (ISNULL(InventoryBalances.QuantityBalance, 0) < 0)
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + GenerateBatchQueryTemplate();
	
EndFunction

// Function returns query text by the balance of WorkOrders register.
//
Function GenerateQueryTextBalancesWorkOrders()
	
	QueryText =
	"SELECT
	|	RegisterRecordsWorkOrdersChange.LineNumber AS LineNumber,
	|	RegisterRecordsWorkOrdersChange.Company AS CompanyPresentation,
	|	RegisterRecordsWorkOrdersChange.WorkOrder AS OrderPresentation,
	|	RegisterRecordsWorkOrdersChange.Products AS ProductsPresentation,
	|	RegisterRecordsWorkOrdersChange.Characteristic AS CharacteristicPresentation,
	|	WorkOrdersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
	|	ISNULL(RegisterRecordsWorkOrdersChange.QuantityChange, 0) + ISNULL(WorkOrdersBalance.QuantityBalance, 0) AS BalanceSalesOrders,
	|	ISNULL(WorkOrdersBalance.QuantityBalance, 0) AS QuantityBalanceSalesOrders
	|FROM
	|	RegisterRecordsWorkOrdersChange AS RegisterRecordsWorkOrdersChange
	|		INNER JOIN AccumulationRegister.WorkOrders.Balance(&ControlTime, ) AS WorkOrdersBalance
	|		ON RegisterRecordsWorkOrdersChange.Company = WorkOrdersBalance.Company
	|			AND RegisterRecordsWorkOrdersChange.Products = WorkOrdersBalance.Products
	|			AND RegisterRecordsWorkOrdersChange.Characteristic = WorkOrdersBalance.Characteristic
	|			AND (ISNULL(WorkOrdersBalance.QuantityBalance, 0) < 0)
	|			AND RegisterRecordsWorkOrdersChange.WorkOrder = WorkOrdersBalance.WorkOrder
	|
	|ORDER BY
	|	LineNumber";
	
	Return QueryText + GenerateBatchQueryTemplate();
	
EndFunction

#EndRegion

#Region PrintInterface

Function PrintWorkOrder(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_WorkOrder";
	
	Query = New Query();
	Query.SetParameter("ObjectsArray", ObjectsArray);
	
	#Region PrintWorkOrderQueryText
	
	Query.Text = 
	"SELECT
	|	WorkOrder.Ref AS Ref,
	|	WorkOrder.Number AS Number,
	|	WorkOrder.Date AS Date,
	|	WorkOrder.Company AS Company,
	|	WorkOrder.Counterparty AS Counterparty,
	|	WorkOrder.Contract AS Contract,
	|	WorkOrder.DocumentCurrency AS DocumentCurrency,
	|	WorkOrder.Start AS ExpectedDate,
	|	CAST(WorkOrder.Comment AS STRING(1024)) AS Comment,
	|	WorkOrder.Location AS ShippingAddress,
	|	WorkOrder.ContactPerson AS ContactPerson,
	|	WorkOrder.Equipment AS Equipment,
	|	CAST(WorkOrder.WorkDescription AS STRING(1024)) AS WorkDescription,
	|	CAST(WorkOrder.Terms AS STRING(1024)) AS Terms,
	|	WorkOrder.SerialNumber AS SerialNumber
	|INTO WorkOrderTable
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|WHERE
	|	WorkOrder.Ref IN(&ObjectsArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderTable.Ref AS Ref,
	|	WorkOrderTable.Number AS DocumentNumber,
	|	WorkOrderTable.Date AS DocumentDate,
	|	WorkOrderTable.Company AS Company,
	|	Companies.LogoFile AS CompanyLogoFile,
	|	WorkOrderTable.Counterparty AS Counterparty,
	|	WorkOrderTable.Contract AS Contract,
	|	CASE
	|		WHEN WorkOrderTable.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN WorkOrderTable.ContactPerson
	|		WHEN CounterpartyContracts.ContactPerson <> VALUE(Catalog.ContactPersons.EmptyRef)
	|			THEN CounterpartyContracts.ContactPerson
	|		ELSE Counterparties.ContactPerson
	|	END AS CounterpartyContactPerson,
	|	WorkOrderTable.DocumentCurrency AS DocumentCurrency,
	|	WorkOrderTable.ExpectedDate AS ExpectedDate,
	|	WorkOrderTable.Comment AS Comment,
	|	WorkOrderTable.ShippingAddress AS ShippingAddress,
	|	WorkOrderTable.Equipment AS Equipment,
	|	WorkOrderTable.WorkDescription AS WorkDescription,
	|	WorkOrderTable.Terms AS Terms,
	|	WorkOrderTable.SerialNumber AS SerialNumber
	|INTO Header
	|FROM
	|	WorkOrderTable AS WorkOrderTable
	|		LEFT JOIN Catalog.Companies AS Companies
	|		ON WorkOrderTable.Company = Companies.Ref
	|		LEFT JOIN Catalog.Counterparties AS Counterparties
	|		ON WorkOrderTable.Counterparty = Counterparties.Ref
	|		LEFT JOIN Catalog.CounterpartyContracts AS CounterpartyContracts
	|		ON WorkOrderTable.Contract = CounterpartyContracts.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderInventory.Ref AS Ref,
	|	WorkOrderInventory.LineNumber AS LineNumber,
	|	WorkOrderInventory.Products AS Products,
	|	WorkOrderInventory.Characteristic AS Characteristic,
	|	WorkOrderInventory.Batch AS Batch,
	|	WorkOrderInventory.Quantity AS Quantity,
	|	WorkOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	CAST(WorkOrderInventory.Price * (WorkOrderInventory.Total - WorkOrderInventory.VATAmount) / WorkOrderInventory.Amount AS NUMBER(15, 2)) AS Price,
	|	WorkOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderInventory.Total - WorkOrderInventory.VATAmount AS Amount,
	|	WorkOrderInventory.VATRate AS VATRate,
	|	WorkOrderInventory.VATAmount AS VATAmount,
	|	WorkOrderInventory.Total AS Total,
	|	CAST(WorkOrderInventory.Content AS STRING(1024)) AS Content,
	|	WorkOrderInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	WorkOrderInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderInventory.ConnectionKey AS ConnectionKey,
	|	WorkOrderInventory.SerialNumbers AS SerialNumbers
	|INTO FilteredInventory
	|FROM
	|	Document.WorkOrder.Inventory AS WorkOrderInventory
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderInventory.Ref = WorkOrderTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderWorks.Ref AS Ref,
	|	WorkOrderWorks.LineNumber AS LineNumber,
	|	WorkOrderWorks.Products AS Products,
	|	WorkOrderWorks.Characteristic AS Characteristic,
	|	CAST(WorkOrderWorks.Content AS STRING(1024)) AS Content,
	|	CAST(WorkOrderWorks.Quantity * WorkOrderWorks.StandardHours AS NUMBER(15, 3)) AS Quantity,
	|	WorkOrderWorks.Price AS Price,
	|	WorkOrderWorks.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	WorkOrderWorks.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	WorkOrderWorks.Amount AS Amount,
	|	WorkOrderWorks.VATRate AS VATRate,
	|	WorkOrderWorks.VATAmount AS VATAmount,
	|	WorkOrderWorks.Total AS Total,
	|	WorkOrderWorks.ConnectionKey AS ConnectionKey
	|INTO FilteredWorks
	|FROM
	|	Document.WorkOrder.Works AS WorkOrderWorks
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderWorks.Ref = WorkOrderTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FALSE AS IsWorks,
	|	FilteredInventory.Ref AS Ref,
	|	MIN(FilteredInventory.LineNumber) AS LineNumber,
	|	CatalogProducts.SKU AS SKU,
	|	CASE
	|		WHEN FilteredInventory.Content <> """"
	|			THEN FilteredInventory.Content
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	FilteredInventory.Content <> """" AS ContentUsed,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription,
	|	CatalogProducts.UseSerialNumbers AS UseSerialNumbers,
	|	MIN(FilteredInventory.ConnectionKey) AS ConnectionKey,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS UOM,
	|	SUM(FilteredInventory.Quantity) AS Quantity,
	|	FilteredInventory.Price AS Price,
	|	SUM(FilteredInventory.AutomaticDiscountAmount) AS AutomaticDiscountAmount,
	|	FilteredInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SUM(FilteredInventory.Amount) AS Amount,
	|	FilteredInventory.VATRate AS VATRate,
	|	SUM(FilteredInventory.VATAmount) AS VATAmount,
	|	SUM(FilteredInventory.Total) AS Total,
	|	FilteredInventory.Price * SUM(CASE
	|			WHEN CatalogProducts.IsFreightService
	|				THEN 0
	|			ELSE FilteredInventory.Quantity
	|		END) AS Subtotal,
	|	FilteredInventory.Products AS Products,
	|	FilteredInventory.Characteristic AS Characteristic,
	|	FilteredInventory.Batch AS Batch,
	|	FilteredInventory.MeasurementUnit AS MeasurementUnit,
	|	CatalogProducts.IsFreightService AS IsFreightService
	|INTO Tabular
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON FilteredInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON FilteredInventory.Characteristic = CatalogCharacteristics.Ref
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON FilteredInventory.Batch = CatalogBatches.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON FilteredInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON FilteredInventory.MeasurementUnit = CatalogUOMClassifier.Ref
	|
	|GROUP BY
	|	FilteredInventory.VATRate,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN FilteredInventory.Content <> """"
	|			THEN FilteredInventory.Content
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	FilteredInventory.Content <> """",
	|	FilteredInventory.Ref,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END,
	|	CatalogProducts.UseSerialNumbers,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description),
	|	FilteredInventory.DiscountMarkupPercent,
	|	FilteredInventory.Products,
	|	FilteredInventory.Characteristic,
	|	FilteredInventory.Batch,
	|	FilteredInventory.MeasurementUnit,
	|	FilteredInventory.Price,
	|	CatalogProducts.IsFreightService
	|
	|UNION ALL
	|
	|SELECT
	|	TRUE,
	|	FilteredWorks.Ref,
	|	FilteredWorks.LineNumber,
	|	CatalogProducts.SKU,
	|	CASE
	|		WHEN FilteredWorks.Content <> """"
	|			THEN FilteredWorks.Content
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END,
	|	FilteredWorks.Content <> """",
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END,
	|	"""",
	|	CatalogProducts.UseSerialNumbers,
	|	FilteredWorks.ConnectionKey,
	|	CatalogUOMClassifier.Description,
	|	FilteredWorks.Quantity,
	|	FilteredWorks.Price,
	|	FilteredWorks.AutomaticDiscountAmount,
	|	FilteredWorks.DiscountMarkupPercent,
	|	FilteredWorks.Amount,
	|	FilteredWorks.VATRate,
	|	FilteredWorks.VATAmount,
	|	FilteredWorks.Total,
	|	CAST(FilteredWorks.Quantity * FilteredWorks.Price AS NUMBER(15, 2)),
	|	FilteredWorks.Products,
	|	FilteredWorks.Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef),
	|	CatalogProducts.MeasurementUnit,
	|	CatalogProducts.IsFreightService
	|FROM
	|	FilteredWorks AS FilteredWorks
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON FilteredWorks.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON FilteredWorks.Characteristic = CatalogCharacteristics.Ref
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON (CatalogProducts.MeasurementUnit = CatalogUOMClassifier.Ref)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderConsumersInventory.Products AS Products,
	|	WorkOrderConsumersInventory.Characteristic AS Characteristic,
	|	WorkOrderConsumersInventory.Batch AS Batch,
	|	WorkOrderConsumersInventory.MeasurementUnit AS MeasurementUnit,
	|	WorkOrderConsumersInventory.Quantity AS Quantity,
	|	WorkOrderConsumersInventory.Ref AS Ref
	|INTO FilteredConsumersInventory
	|FROM
	|	Document.WorkOrder.ConsumersInventory AS WorkOrderConsumersInventory
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderConsumersInventory.Ref = WorkOrderTable.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.IsWorks AS IsWorks,
	|	Tabular.Ref AS Ref,
	|	Tabular.LineNumber AS LineNumber,
	|	Tabular.SKU AS SKU,
	|	Tabular.ProductDescription AS ProductDescription,
	|	Tabular.ContentUsed AS ContentUsed,
	|	Tabular.UseSerialNumbers AS UseSerialNumbers,
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Quantity AS Quantity,
	|	Tabular.Price AS Price,
	|	CASE
	|		WHEN Tabular.AutomaticDiscountAmount = 0
	|			THEN Tabular.DiscountMarkupPercent
	|		WHEN Tabular.Subtotal = 0
	|			THEN 0
	|		ELSE CAST((Tabular.Subtotal - Tabular.Amount) / Tabular.Subtotal * 100 AS NUMBER(15, 2))
	|	END AS DiscountRate,
	|	Tabular.Amount AS Amount,
	|	Tabular.VATRate AS VATRate,
	|	Tabular.VATAmount AS VATAmount,
	|	Tabular.Total AS Total,
	|	Tabular.Subtotal AS Subtotal,
	|	CAST(Tabular.Quantity * Tabular.Price - Tabular.Amount AS NUMBER(15, 2)) AS DiscountAmount,
	|	Tabular.CharacteristicDescription AS CharacteristicDescription,
	|	Tabular.BatchDescription AS BatchDescription,
	|	Tabular.Characteristic AS Characteristic,
	|	Tabular.Batch AS Batch,
	|	Tabular.UOM AS UOM
	|FROM
	|	Tabular AS Tabular
	|
	|ORDER BY
	|	Ref,
	|	IsWorks,
	|	LineNumber
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
	|	Header.Contract AS Contract,
	|	Header.CounterpartyContactPerson AS CounterpartyContactPerson,
	|	Header.DocumentCurrency AS DocumentCurrency,
	|	Header.ExpectedDate AS ExpectedDate,
	|	Header.Comment AS Comment,
	|	Header.ShippingAddress AS ShippingAddress,
	|	Header.Equipment AS Equipment,
	|	Header.WorkDescription AS WorkDescription,
	|	Header.Terms AS Terms,
	|	Header.SerialNumber AS SerialNumber
	|FROM
	|	Header AS Header
	|
	|ORDER BY
	|	DocumentNumber
	|TOTALS
	|	MAX(DocumentNumber),
	|	MAX(DocumentDate),
	|	MAX(Company),
	|	MAX(CompanyLogoFile),
	|	MAX(Counterparty),
	|	MAX(Contract),
	|	MAX(CounterpartyContactPerson),
	|	MAX(DocumentCurrency),
	|	MAX(ExpectedDate),
	|	MAX(Comment),
	|	MAX(ShippingAddress),
	|	MAX(Equipment),
	|	MAX(WorkDescription),
	|	MAX(Terms),
	|	MAX(SerialNumber)
	|BY
	|	Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	Tabular.ConnectionKey AS ConnectionKey,
	|	Tabular.Ref AS Ref,
	|	CatalogSerialNumbers.Description AS SerialNumber
	|FROM
	|	FilteredInventory AS FilteredInventory
	|		INNER JOIN Tabular AS Tabular
	|		ON FilteredInventory.Products = Tabular.Products
	|			AND FilteredInventory.DiscountMarkupPercent = Tabular.DiscountMarkupPercent
	|			AND FilteredInventory.Price = Tabular.Price
	|			AND FilteredInventory.VATRate = Tabular.VATRate
	|			AND (NOT Tabular.ContentUsed)
	|			AND FilteredInventory.Ref = Tabular.Ref
	|			AND FilteredInventory.Characteristic = Tabular.Characteristic
	|			AND FilteredInventory.MeasurementUnit = Tabular.MeasurementUnit
	|			AND FilteredInventory.Batch = Tabular.Batch
	|		INNER JOIN Document.WorkOrder.SerialNumbers AS WorkOrderSerialNumbers
	|			LEFT JOIN Catalog.SerialNumbers AS CatalogSerialNumbers
	|			ON WorkOrderSerialNumbers.SerialNumber = CatalogSerialNumbers.Ref
	|		ON (WorkOrderSerialNumbers.ConnectionKey = FilteredInventory.ConnectionKey)
	|			AND FilteredInventory.Ref = WorkOrderSerialNumbers.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	FilteredConsumersInventory.Ref AS Ref,
	|	FilteredConsumersInventory.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(CatalogUOM.Description, CatalogUOMClassifier.Description) AS Unit,
	|	FilteredConsumersInventory.Quantity AS Quantity,
	|	FALSE AS ContentUsed,
	|	FilteredConsumersInventory.Products AS Products,
	|	CASE
	|		WHEN (CAST(CatalogProducts.DescriptionFull AS STRING(1024))) <> """"
	|			THEN CAST(CatalogProducts.DescriptionFull AS STRING(1024))
	|		ELSE CatalogProducts.Description
	|	END AS ProductDescription,
	|	FilteredConsumersInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN CatalogProducts.UseCharacteristics
	|			THEN CatalogCharacteristics.Description
	|		ELSE """"
	|	END AS CharacteristicDescription,
	|	FilteredConsumersInventory.Batch AS Batch,
	|	CASE
	|		WHEN CatalogProducts.UseBatches
	|			THEN CatalogBatches.Description
	|		ELSE """"
	|	END AS BatchDescription
	|FROM
	|	FilteredConsumersInventory AS FilteredConsumersInventory
	|		LEFT JOIN Catalog.Products AS CatalogProducts
	|		ON FilteredConsumersInventory.Products = CatalogProducts.Ref
	|		LEFT JOIN Catalog.ProductsCharacteristics AS CatalogCharacteristics
	|		ON FilteredConsumersInventory.Characteristic = CatalogCharacteristics.Ref
	|		LEFT JOIN Catalog.ProductsBatches AS CatalogBatches
	|		ON FilteredConsumersInventory.Batch = CatalogBatches.Ref
	|		LEFT JOIN Catalog.UOM AS CatalogUOM
	|		ON FilteredConsumersInventory.MeasurementUnit = CatalogUOM.Ref
	|		LEFT JOIN Catalog.UOMClassifier AS CatalogUOMClassifier
	|		ON FilteredConsumersInventory.MeasurementUnit = CatalogUOMClassifier.Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	WorkOrderLaborAssignment.Employee AS Employee,
	|	WorkOrderLaborAssignment.HoursWorked AS HoursWorked,
	|	WorkOrderLaborAssignment.Ref AS Ref
	|FROM
	|	Document.WorkOrder.LaborAssignment AS WorkOrderLaborAssignment
	|		INNER JOIN WorkOrderTable AS WorkOrderTable
	|		ON WorkOrderLaborAssignment.Ref = WorkOrderTable.Ref";
	
	#EndRegion
	
	ResultArray = Query.ExecuteBatch();
	
	FirstDocument = True;
	
	InventoryWorks		= ResultArray[6].Unload();
	Header 				= ResultArray[7].Select(QueryResultIteration.ByGroupsWithHierarchy);
	SerialNumbersSel	= ResultArray[8].Select();
	ConsumersInventory	= ResultArray[9].Unload();
	LaborAssignment		= ResultArray[10].Unload();
	
	While Header.Next() Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		SpreadsheetDocument.PrintParametersName = "PRINT_PARAMETERS_WorkOrder";
		
		Template = PrintManagement.PrintedFormsTemplate("Document.WorkOrder.PF_MXL_WorkOrder");
		
		#Region PrintWorkOrderTitleArea
		
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
		
		#Region PrintWorkOrderCompanyInfoArea
		
		CompanyInfoArea = Template.GetArea("CompanyInfo");
		
		InfoAboutCompany = DriveServer.InfoAboutLegalEntityIndividual(Header.Company, Header.DocumentDate, ,);
		CompanyInfoArea.Parameters.Fill(InfoAboutCompany);
		
		SpreadsheetDocument.Put(CompanyInfoArea);
		
		#EndRegion
		
		#Region PrintWorkOrderCounterpartyInfoArea
		
		CounterpartyInfoArea = Template.GetArea("CounterpartyInfo");
		CounterpartyInfoArea.Parameters.Fill(Header);
		
		InfoAboutCounterparty = DriveServer.InfoAboutLegalEntityIndividual(Header.Counterparty, Header.DocumentDate, ,);
		CounterpartyInfoArea.Parameters.Fill(InfoAboutCounterparty);
		
		InfoAboutShippingAddress	= DriveServer.InfoAboutShippingAddress(Header.ShippingAddress);
		InfoAboutContactPerson		= DriveServer.InfoAboutContactPerson(Header.CounterpartyContactPerson);
		
		If NOT IsBlankString(InfoAboutShippingAddress.DeliveryAddress) Then
			CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutShippingAddress.DeliveryAddress;
		EndIf;
		
		If NOT IsBlankString(InfoAboutContactPerson.PhoneNumbers) Then
			CounterpartyInfoArea.Parameters.PhoneNumbers = InfoAboutContactPerson.PhoneNumbers;
		EndIf;
		
		If IsBlankString(CounterpartyInfoArea.Parameters.DeliveryAddress) Then
			
			If Not IsBlankString(InfoAboutCounterparty.ActualAddress) Then
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.ActualAddress;
				
			Else
				
				CounterpartyInfoArea.Parameters.DeliveryAddress = InfoAboutCounterparty.LegalAddress;
				
			EndIf;
			
		EndIf;
		
		CounterpartyInfoArea.Parameters.PaymentTerms = PaymentTermsServer.TitlePaymentTerms(Header.Ref);
		
		SpreadsheetDocument.Put(CounterpartyInfoArea);
		
		#EndRegion
		
		#Region PrintWorkOrderEquipmentSectionArea
		
		EquipmentSectionArea = Template.GetArea("EquipmentSection");
		EquipmentSectionArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(EquipmentSectionArea);
		
		#EndRegion
		
		#Region PrintWorkOrderWorkDescriptionSectionArea
		
		WorkDescriptionSectionArea = Template.GetArea("WorkDescriptionSection");
		WorkDescriptionSectionArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(WorkDescriptionSectionArea);
		
		#EndRegion
		
		#Region PrintWorkOrderCommentArea
		
		CommentArea = Template.GetArea("Comment");
		CommentArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(CommentArea);
		
		#EndRegion
		
		#Region PrintWorkOrderTermsArea
		
		TermsArea = Template.GetArea("Terms");
		TermsArea.Parameters.Fill(Header);
		SpreadsheetDocument.Put(TermsArea);
		
		#EndRegion
		
		#Region PrintWorkOrderLinesArea
		
		PageNumber = 0;
		
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		Parameters = New Structure;
		Parameters.Insert("Template", Template);
		Parameters.Insert("SpreadsheetDocument", SpreadsheetDocument);
		Parameters.Insert("TitleArea", TitleArea);
		Parameters.Insert("Header", Header);
		Parameters.Insert("SerialNumbersSel", SerialNumbersSel);
		Parameters.Insert("Tabular", InventoryWorks.Copy(New Structure("Ref,IsWorks", Header.Ref, False)));
		Parameters.Insert("IsWorks", False);
		Parameters.Insert("IsLaborAssignment", False);
		
		PutTabularIntoSpreadsheetDocument(Parameters, PageNumber);
		
		Parameters.SerialNumbersSel	= Undefined;
		Parameters.Tabular			= InventoryWorks.Copy(New Structure("Ref,IsWorks", Header.Ref, True));
		Parameters.IsWorks			= True;
		
		PutTabularIntoSpreadsheetDocument(Parameters, PageNumber);
		
		#EndRegion
		
		#Region PrintWorkOrderLaborAssignmentArea
		
		Parameters.Tabular				= LaborAssignment.Copy(New Structure("Ref", Header.Ref));
		Parameters.IsLaborAssignment	= True;
		
		PutAdditionalTabular(Parameters, PageNumber);
		
		#EndRegion
		
		#Region PrintWorkOrderConsumersInventoryArea
		
		Parameters.Tabular				= ConsumersInventory.Copy(New Structure("Ref", Header.Ref));
		Parameters.IsLaborAssignment	= False;
		
		PutAdditionalTabular(Parameters, PageNumber);
		
		#EndRegion
		
		AreasToBeChecked = New Array;
		AreasToBeChecked.Add(EmptyLineArea);
		AreasToBeChecked.Add(PageNumberArea);
		
		For i = 1 To 50 Do
			
			If NOT CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) OR i = 50 Then
				
				PageNumber = PageNumber + 1;
				PageNumberArea.Parameters.PageNumber = PageNumber;
				SpreadsheetDocument.Put(PageNumberArea);
				
				Break;
				
			Else
				
				SpreadsheetDocument.Put(EmptyLineArea);
				
			EndIf;
			
		EndDo;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, Header.Ref);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

Procedure PutTabularIntoSpreadsheetDocument(Parameters, PageNumber)
	
	Template			= Parameters.Template;
	SpreadsheetDocument	= Parameters.SpreadsheetDocument;
	TitleArea			= Parameters.TitleArea;
	Header				= Parameters.Header;
	SerialNumbersSel	= Parameters.SerialNumbersSel;
	Tabular				= Parameters.Tabular;
	IsWorks				= Parameters.IsWorks;
	
	If Tabular.Count() > 0 Then
		
		LineSectionArea	= Template.GetArea("LineSection");
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		LineTotalArea	= Template.GetArea("LineTotal");
		
		TotalsAreasArray = New Array;
		
		LineTotalArea.Parameters.Fill(Header);
		
		LineTotalArea.Parameters.Quantity		= Tabular.Total("Quantity");
		LineTotalArea.Parameters.LineNumber		= Tabular.Count();
		LineTotalArea.Parameters.Subtotal		= Tabular.Total("Subtotal");
		LineTotalArea.Parameters.DiscountAmount	= Tabular.Total("DiscountAmount");
		LineTotalArea.Parameters.VATAmount		= Tabular.Total("VATAmount");
		LineTotalArea.Parameters.Total			= Tabular.Total("Total");
		
		TotalsAreasArray.Add(LineTotalArea);
		
		TabularHeaderArea = Template.GetArea(?(IsWorks, "WorksHeader", "PartsHeader"));
		SpreadsheetDocument.Put(TabularHeaderArea);
		
		LineHeaderArea	= Template.GetArea("LineHeader");
		SpreadsheetDocument.Put(LineHeaderArea);
		
		AreasToBeChecked = New Array;
		
		For Each Row In Tabular Do
			
			LineSectionArea.Parameters.Fill(Row);
			
			PrintManagement.ComplimentProductDescription(LineSectionArea.Parameters.ProductDescription, Row, SerialNumbersSel);
			
			AreasToBeChecked.Add(LineSectionArea);
			For Each Area In TotalsAreasArray Do
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
					
					If NOT CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) OR i = 50 Then
						
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
				SpreadsheetDocument.Put(TabularHeaderArea);
				SpreadsheetDocument.Put(LineHeaderArea);
				SpreadsheetDocument.Put(LineSectionArea);
				
			EndIf;
			
		EndDo;
		
		For Each Area In TotalsAreasArray Do
			
			SpreadsheetDocument.Put(Area);
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure PutAdditionalTabular(Parameters, PageNumber)
	
	Template			= Parameters.Template;
	SpreadsheetDocument	= Parameters.SpreadsheetDocument;
	TitleArea			= Parameters.TitleArea;
	Tabular				= Parameters.Tabular;
	IsLaborAssignment	= Parameters.IsLaborAssignment;
	
	If Tabular.Count() Then
	
		SeeNextPageArea	= Template.GetArea("SeeNextPage");
		EmptyLineArea	= Template.GetArea("EmptyLine");
		PageNumberArea	= Template.GetArea("PageNumber");
		
		If IsLaborAssignment Then
			SectionArea	= Template.GetArea("LaborSection");
			HeaderArea	= Template.GetArea("LaborHeader");
		Else
			SectionArea	= Template.GetArea("CustomersInventorySection");
			HeaderArea	= Template.GetArea("CustomersInventoryHeader");
		EndIf;
		
		SpreadsheetDocument.Put(HeaderArea);
		
		AreasToBeChecked = New Array;
		
		For Each Row In Tabular Do
			
			SectionArea.Parameters.Fill(Row);
			
			If NOT IsLaborAssignment Then
				PrintManagement.ComplimentProductDescription(SectionArea.Parameters.ProductDescription, Row);
			EndIf;
			
			AreasToBeChecked.Add(SectionArea);
			AreasToBeChecked.Add(PageNumberArea);
			
			If CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) Then
				
				SpreadsheetDocument.Put(SectionArea);
				
			Else
				
				SpreadsheetDocument.Put(SeeNextPageArea);
				
				AreasToBeChecked.Clear();
				AreasToBeChecked.Add(EmptyLineArea);
				AreasToBeChecked.Add(PageNumberArea);
				
				For i = 1 To 50 Do
					
					If NOT CommonUse.SpreadsheetDocumentFitsPage(SpreadsheetDocument, AreasToBeChecked) OR i = 50 Then
						
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
				SpreadsheetDocument.Put(HeaderArea);
				SpreadsheetDocument.Put(SectionArea);
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Function checks if the document is posted and calls
// the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	If TemplateName = "WorkOrder" Then
		
		Return PrintWorkOrder(ObjectsArray, PrintObjects, TemplateName);
		
	EndIf;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//  TemplateNames   - String	- Names of layouts separated by commas 
//	ObjectsArray	- Array		- Array of refs to objects that need to be printed 
//	PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection	- Values table	- Generated table documents 
//	OutputParameters		- Structure     - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "WorkOrder") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "WorkOrder", "Work order", PrintForm(ObjectsArray, PrintObjects, "WorkOrder"));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	// Order confirmation
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "WorkOrder";
	PrintCommand.Presentation				= NStr("en = 'Work order'");
	PrintCommand.FormsList					= "DocumentForm, ListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.PlaceProperties			= "GroupImportantCommandsWorkOrder";
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#EndIf

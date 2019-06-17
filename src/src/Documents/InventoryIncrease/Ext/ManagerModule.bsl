#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefInventoryIncrease, StructureAdditionalProperties) Export

	Query = New Query(
	"SELECT
	|	Header.Ref AS Ref,
	|	Header.Date AS Date,
	|	&Company AS Company,
	|	Header.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN Header.Cell
	|		ELSE UNDEFINED
	|	END AS Cell
	|INTO Header
	|FROM
	|	Document.InventoryIncrease AS Header
	|WHERE
	|	Header.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryIncreaseInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryIncreaseInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryIncreaseInventory.Ref.StructuralUnit AS StructuralUnit,
	|	InventoryIncreaseInventory.InventoryGLAccount AS GLAccount,
	|	InventoryIncreaseInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryIncreaseInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryIncreaseInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryIncreaseInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryIncreaseInventory.Quantity
	|		ELSE InventoryIncreaseInventory.Quantity * InventoryIncreaseInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	TRUE AS FixedCost,
	|	InventoryIncreaseInventory.Amount AS Amount,
	|	&InventoryIncrease AS ContentOfAccountingRecord,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|WHERE
	|	InventoryIncreaseInventory.Ref = &Ref
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.LineNumber,
	|	OfflineRecords.RecordType,
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.StructuralUnit,
	|	OfflineRecords.GLAccount,
	|	OfflineRecords.Products,
	|	OfflineRecords.Characteristic,
	|	OfflineRecords.Batch,
	|	OfflineRecords.Quantity,
	|	OfflineRecords.FixedCost,
	|	OfflineRecords.Amount,
	|	OfflineRecords.ContentOfAccountingRecord,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccumulationRegister.Inventory AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryIncreaseInventory.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryIncreaseInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	InventoryIncreaseInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN InventoryIncreaseInventory.Ref.Cell
	|		ELSE UNDEFINED
	|	END AS Cell,
	|	InventoryIncreaseInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN InventoryIncreaseInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN InventoryIncreaseInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(InventoryIncreaseInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN InventoryIncreaseInventory.Quantity
	|		ELSE InventoryIncreaseInventory.Quantity * InventoryIncreaseInventory.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|WHERE
	|	InventoryIncreaseInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryIncreaseInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.LinesOfBusiness.Other) AS BusinessLine,
	|	SUM(InventoryIncreaseInventory.Amount) AS AmountIncome,
	|	SUM(InventoryIncreaseInventory.Amount) AS Amount,
	|	InventoryIncreaseInventory.Ref.Correspondence AS GLAccount,
	|	VALUE(AccountingRecordType.Credit) AS RecordKindAccountingJournalEntries,
	|	&RevenueIncomes AS ContentOfAccountingRecord
	|FROM
	|	Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|WHERE
	|	InventoryIncreaseInventory.Ref = &Ref
	|	AND InventoryIncreaseInventory.Ref.Correspondence.TypeOfAccount = VALUE(Enum.GLAccountsTypes.OtherIncome)
	|	AND InventoryIncreaseInventory.Amount > 0
	|
	|GROUP BY
	|	InventoryIncreaseInventory.Ref,
	|	InventoryIncreaseInventory.Ref.Date,
	|	InventoryIncreaseInventory.Ref.Correspondence
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	InventoryIncreaseInventory.Ref.Date AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	InventoryIncreaseInventory.InventoryGLAccount AS AccountDr,
	|	UNDEFINED AS CurrencyDr,
	|	0 AS AmountCurDr,
	|	InventoryIncreaseInventory.Ref.Correspondence AS AccountCr,
	|	UNDEFINED AS CurrencyCr,
	|	0 AS AmountCurCr,
	|	SUM(InventoryIncreaseInventory.Amount) AS Amount,
	|	&InventoryIncrease AS Content,
	|	FALSE AS OfflineRecord
	|FROM
	|	Document.InventoryIncrease.Inventory AS InventoryIncreaseInventory
	|WHERE
	|	InventoryIncreaseInventory.Ref = &Ref
	|	AND InventoryIncreaseInventory.Amount > 0
	|
	|GROUP BY
	|	InventoryIncreaseInventory.Ref.Date,
	|	InventoryIncreaseInventory.Ref.Correspondence,
	|	InventoryIncreaseInventory.InventoryGLAccount
	|
	|UNION ALL
	|
	|SELECT
	|	OfflineRecords.Period,
	|	OfflineRecords.Company,
	|	OfflineRecords.PlanningPeriod,
	|	OfflineRecords.AccountDr,
	|	OfflineRecords.CurrencyDr,
	|	OfflineRecords.AmountCurDr,
	|	OfflineRecords.AccountCr,
	|	OfflineRecords.CurrencyCr,
	|	OfflineRecords.AmountCurCr,
	|	OfflineRecords.Amount,
	|	OfflineRecords.Content,
	|	OfflineRecords.OfflineRecord
	|FROM
	|	AccountingRegister.AccountingJournalEntries AS OfflineRecords
	|WHERE
	|	OfflineRecords.Recorder = &Ref
	|	AND OfflineRecords.OfflineRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(Inventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	Header.Date AS Period,
	|	Header.Company AS Company,
	|	Inventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	Header.Ref AS CostLayer,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	Header.StructuralUnit AS StructuralUnit,
	|	Inventory.InventoryGLAccount AS GLAccount,
	|	SUM(CASE
	|			WHEN VALUETYPE(Inventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN Inventory.Quantity
	|			ELSE Inventory.Quantity * Inventory.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	SUM(Inventory.Amount) AS Amount,
	|	TRUE AS SourceRecord
	|FROM
	|	Header AS Header
	|		INNER JOIN Document.InventoryIncrease.Inventory AS Inventory
	|		ON Header.Ref = Inventory.Ref
	|		INNER JOIN Catalog.BusinessUnits AS BusinessUnitsRef
	|		ON Header.StructuralUnit = BusinessUnitsRef.Ref
	|		INNER JOIN Catalog.Products AS Product
	|		ON (Inventory.Products = Product.Ref)
	|WHERE
	|	&UseFIFO
	|
	|GROUP BY
	|	Header.Date,
	|	Header.Company,
	|	Inventory.Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN Inventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	Header.Ref,
	|	CASE
	|		WHEN &UseBatches
	|			THEN Inventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	Header.StructuralUnit,
	|	Inventory.InventoryGLAccount
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Ref.Date AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableInventory.Ref.Date AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Ref.StructuralUnit AS StructuralUnit,
	|	TableInventory.Ref.Cell AS Cell,
	|	1 AS Quantity
	|FROM
	|	Document.InventoryIncrease.Inventory AS TableInventory
	|		INNER JOIN Document.InventoryIncrease.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND TableInventory.Ref = &Ref
	|	AND &UseSerialNumbers");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();

	Query.SetParameter("Ref",					DocumentRefInventoryIncrease);
	Query.SetParameter("Company",				StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("InventoryIncrease",		NStr("en = 'Inventory receiving'", MainLanguageCode));
	Query.SetParameter("RevenueIncomes",		NStr("en = 'Receipt of other income'", MainLanguageCode));
	Query.SetParameter("OtherIncome",			NStr("en = 'Other inventory capitalization'", MainLanguageCode));
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	Query.SetParameter("UseFIFO", StructureAdditionalProperties.AccountingPolicy.UseFIFO);
	
	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableIncomeAndExpenses", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableAccountingJournalEntries", ResultsArray[4].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryCostLayer", ResultsArray[5].Unload());
	
	ResultOfAQuery6 = ResultsArray[6].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", ResultOfAQuery6);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", ResultOfAQuery6);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefInventoryIncrease, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the "InventoryTransferAtWarehouseChange",
	// "RegisterRecordsInventoryChange" temporary tables contain records, it is necessary to control the sales of goods.
	
	If StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange Then

		Query = New Query(
		"SELECT
		|	RegisterRecordsInventoryInWarehousesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryInWarehousesChange.Cell) AS PresentationCell,
		|	InventoryInWarehousesOfBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryInWarehousesOfBalance.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryInWarehousesChange.QuantityChange, 0) + ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS BalanceInventoryInWarehouses,
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) AS QuantityBalanceInventoryInWarehouses
		|FROM
		|	RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange
		|		LEFT JOIN AccumulationRegister.InventoryInWarehouses.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Cell) In
		|					(SELECT
		|						RegisterRecordsInventoryInWarehousesChange.Company AS Company,
		|						RegisterRecordsInventoryInWarehousesChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryInWarehousesChange.Products AS Products,
		|						RegisterRecordsInventoryInWarehousesChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryInWarehousesChange.Batch AS Batch,
		|						RegisterRecordsInventoryInWarehousesChange.Cell AS Cell
		|					FROM
		|						RegisterRecordsInventoryInWarehousesChange AS RegisterRecordsInventoryInWarehousesChange)) AS InventoryInWarehousesOfBalance
		|		ON RegisterRecordsInventoryInWarehousesChange.Company = InventoryInWarehousesOfBalance.Company
		|			AND RegisterRecordsInventoryInWarehousesChange.StructuralUnit = InventoryInWarehousesOfBalance.StructuralUnit
		|			AND RegisterRecordsInventoryInWarehousesChange.Products = InventoryInWarehousesOfBalance.Products
		|			AND RegisterRecordsInventoryInWarehousesChange.Characteristic = InventoryInWarehousesOfBalance.Characteristic
		|			AND RegisterRecordsInventoryInWarehousesChange.Batch = InventoryInWarehousesOfBalance.Batch
		|			AND RegisterRecordsInventoryInWarehousesChange.Cell = InventoryInWarehousesOfBalance.Cell
		|WHERE
		|	ISNULL(InventoryInWarehousesOfBalance.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsInventoryChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.StructuralUnit) AS StructuralUnitPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.GLAccount) AS GLAccountPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsInventoryChange.SalesOrder) AS SalesOrderPresentation,
		|	InventoryBalances.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	REFPRESENTATION(InventoryBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsInventoryChange.QuantityChange, 0) + ISNULL(InventoryBalances.QuantityBalance, 0) AS BalanceInventory,
		|	ISNULL(InventoryBalances.QuantityBalance, 0) AS QuantityBalanceInventory,
		|	ISNULL(InventoryBalances.AmountBalance, 0) AS AmountBalanceInventory
		|FROM
		|	RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange
		|		LEFT JOIN AccumulationRegister.Inventory.Balance(
		|				&ControlTime,
		|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
		|					(SELECT
		|						RegisterRecordsInventoryChange.Company AS Company,
		|						RegisterRecordsInventoryChange.StructuralUnit AS StructuralUnit,
		|						RegisterRecordsInventoryChange.GLAccount AS GLAccount,
		|						RegisterRecordsInventoryChange.Products AS Products,
		|						RegisterRecordsInventoryChange.Characteristic AS Characteristic,
		|						RegisterRecordsInventoryChange.Batch AS Batch,
		|						RegisterRecordsInventoryChange.SalesOrder AS SalesOrder
		|					FROM
		|						RegisterRecordsInventoryChange AS RegisterRecordsInventoryChange)) AS InventoryBalances
		|		ON RegisterRecordsInventoryChange.Company = InventoryBalances.Company
		|			AND RegisterRecordsInventoryChange.StructuralUnit = InventoryBalances.StructuralUnit
		|			AND RegisterRecordsInventoryChange.GLAccount = InventoryBalances.GLAccount
		|			AND RegisterRecordsInventoryChange.Products = InventoryBalances.Products
		|			AND RegisterRecordsInventoryChange.Characteristic = InventoryBalances.Characteristic
		|			AND RegisterRecordsInventoryChange.Batch = InventoryBalances.Batch
		|			AND RegisterRecordsInventoryChange.SalesOrder = InventoryBalances.SalesOrder
		|WHERE
		|	ISNULL(InventoryBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber");

		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();

		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty() Then
			DocumentObjectInventoryIncrease = DocumentRefInventoryIncrease.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectInventoryIncrease, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory and cost accounting.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectInventoryIncrease, QueryResultSelection, Cancel);
		EndIf;

	EndIf;

EndProcedure

#Region PrintInterface

Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "InventoryIncrease";
	
	Tables = New Array();
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion

#EndIf
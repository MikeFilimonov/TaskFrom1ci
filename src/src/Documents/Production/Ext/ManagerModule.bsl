#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure generates  nodes content.
//
Procedure FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesBillsOfMaterialstack)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(CASE
	|			WHEN VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|				THEN TableMaterials.Quantity / TableMaterials.ProductsQuantity * &ProductsQuantity
	|			ELSE TableMaterials.Quantity * TableMaterials.MeasurementUnit.Factor / TableMaterials.ProductsQuantity * &ProductsQuantity
	|		END) AS ExpenseNorm,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	Catalog.BillsOfMaterials.Content AS TableMaterials,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	AND TableMaterials.Ref = &Ref
	|
	|GROUP BY
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	StructureLineNumber";
	
	Query.SetParameter("Ref", StringProducts.TMSpecification);
	Query.SetParameter("ProductsQuantity", StringProducts.TMQuantity);
	
	NodesBillsOfMaterialstack.Add(StringProducts.TMSpecification);
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'Recursive item inclusion is found'")+" "+Selection.Products+" "+NStr("en = 'in BOM'")+" "+StringProducts.SpecificationCorr+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			StringProducts.TMQuantity = Selection.ExpenseNorm;
			StringProducts.TMSpecification = Selection.Specification;
			FillProductsTableByNodsStructure(StringProducts, TableProduction, NodesBillsOfMaterialstack);
		Else
			NewRow = TableProduction.Add();
			FillPropertyValues(NewRow, StringProducts);
			NewRow.TMContentRowType = Selection.ContentRowType;
			NewRow.TMProducts = Selection.Products;
			NewRow.TMCharacteristic = Selection.Characteristic;
			NewRow.TMQuantity = Selection.ExpenseNorm;
			NewRow.TMSpecification = Selection.Specification;
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	
EndProcedure

// Procedure distributes materials by the products BillsOfMaterials.
//
Procedure DistributeMaterialsAccordingToNorms(StringMaterials, BaseTable, MaterialsTable)
	
	StringMaterials.Distributed = True;
	
	DistributionBase = 0;
	For Each BaseRow In BaseTable Do
		DistributionBase = DistributionBase + BaseRow.TMQuantity;
		BaseRow.Distributed = True;
	EndDo;
	
	DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, True);
	
EndProcedure

// Procedure distributes materials in proportion to the products quantity.
//
Procedure DistributeMaterialsByQuantity(BaseTable, MaterialsTable, DistributionBase = 0)
	
	ExcDistributed = False;
	If DistributionBase = 0 Then
		ExcDistributed = True;
		For Each BaseRow In BaseTable Do
			If Not BaseRow.Distributed Then
				DistributionBase = DistributionBase + BaseRow.CorrQuantity;
			EndIf;
		EndDo;
	EndIf;
	
	For n = 0 To MaterialsTable.Count() - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		If Not StringMaterials.Distributed Then
			DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure allocates materials string.
//
Procedure DistributeTabularSectionStringMaterials(StringMaterials, BaseTable, MaterialsTable, DistributionBase, AccordingToNorms, ExcDistributed = False)
	
	InitQuantity = 0;
	InitReserve = 0;
	QuantityToWriteOff = StringMaterials.Quantity;
	ReserveToWriteOff = StringMaterials.Reserve;
	
	DistributionBaseQuantity = DistributionBase;
	DistributionBaseReserve = DistributionBase;
	
	For Each BasicTableRow In BaseTable Do
		
		If ExcDistributed AND BasicTableRow.Distributed Then
			Continue;
		EndIf;
		
		If InitQuantity = QuantityToWriteOff Then
			Continue;
		EndIf;
		
		If ValueIsFilled(StringMaterials.ProductsCorr) Then
			NewRow = MaterialsTable.Add();
			FillPropertyValues(NewRow, StringMaterials);
			FillPropertyValues(NewRow, BasicTableRow);
			StringMaterials = NewRow;
		Else
			FillPropertyValues(StringMaterials, BasicTableRow);
		EndIf;
		
		If AccordingToNorms Then
			BasicTableQuantity = BasicTableRow.TMQuantity;
		Else
			BasicTableQuantity = BasicTableRow.CorrQuantity
		EndIf;
		
		// Quantity.
		StringMaterials.Quantity = Round((QuantityToWriteOff - InitQuantity) * BasicTableQuantity / DistributionBaseQuantity, 3, 1);
		
		If (InitQuantity + StringMaterials.Quantity) > QuantityToWriteOff Then
			StringMaterials.Quantity = QuantityToWriteOff - InitQuantity;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - BasicTableQuantity;
			InitQuantity = InitQuantity + StringMaterials.Quantity;
		EndIf;
		
		// Reserve.
		If InitReserve = ReserveToWriteOff Then
			Continue;
		EndIf;
		
		StringMaterials.Reserve = Round((ReserveToWriteOff - InitReserve) * BasicTableQuantity / DistributionBaseReserve, 3, 1);
		
		If (InitReserve + StringMaterials.Reserve) > ReserveToWriteOff Then
			StringMaterials.Reserve = ReserveToWriteOff - InitReserve;
			InitReserve = ReserveToWriteOff;
		Else
			DistributionBaseReserve = DistributionBaseReserve - BasicTableQuantity;
			InitReserve = InitReserve + StringMaterials.Reserve;
		EndIf;
		
	EndDo;
	
	If InitQuantity < QuantityToWriteOff Then
		StringMaterials.Quantity = StringMaterials.Quantity + (QuantityToWriteOff - InitQuantity);
	EndIf;
	
	If InitReserve < ReserveToWriteOff Then
		StringMaterials.Reserve = StringMaterials.Reserve + (ReserveToWriteOff - InitReserve);
	EndIf;
	
EndProcedure

// Procedure distributes materials by the products BillsOfMaterials.
//
Procedure DistributeProductsAccordingToNorms(StringProducts, BaseTable, DistributionBase)
	
	DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, True);
	
EndProcedure

// Procedure distributes materials in proportion to the products quantity.
//
Procedure DistributeProductsAccordingToQuantity(TableProduction, BaseTable, DistributionBase = 0, ExcDistributed = True)
	
	If ExcDistributed Then
		For Each StringMaterials In BaseTable Do
			If Not StringMaterials.NewRow
				AND Not StringMaterials.Distributed Then
				DistributionBase = DistributionBase + StringMaterials.CostPercentage;
			EndIf;
		EndDo;
	EndIf;
	
	For Each StringProducts In TableProduction Do
		
		If Not StringProducts.Distributed Then
			DistributeTabularSectionStringProducts(StringProducts, BaseTable, DistributionBase, False, ExcDistributed);
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure allocates production string.
//
Procedure DistributeTabularSectionStringProducts(ProductsRow, BaseTable, DistributionBase, AccordingToNorms, ExeptDistribution = False)
	
	InitQuantity = 0;
	InitReserve = 0;
	QuantityToWriteOff = ProductsRow.Quantity;
	ReserveToWriteOff = ProductsRow.Reserve;
	
	DistributionBaseQuantity = DistributionBase;
	DistributionBaseReserve = DistributionBase;
	
	DistributionRow = Undefined;
	For n = 0 To BaseTable.Count() - 1 Do
		
		StringMaterials = BaseTable[n];
		
		If InitQuantity = QuantityToWriteOff
			OR StringMaterials.NewRow Then
			StringMaterials.AccountExecuted = False;
			Continue;
		EndIf;
		
		If AccordingToNorms AND Not StringMaterials.AccountExecuted Then
			Continue;
		EndIf;
		
		StringMaterials.AccountExecuted = False;
		
		If Not AccordingToNorms AND ExeptDistribution
			AND StringMaterials.Distributed Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(StringMaterials.Products) Then
			Distributed = StringMaterials.Distributed;
			FillPropertyValues(StringMaterials, ProductsRow);
			DistributionRow = StringMaterials;
			DistributionRow.Distributed = Distributed;
		Else
			DistributionRow = BaseTable.Add();
			FillPropertyValues(DistributionRow, StringMaterials);
			FillPropertyValues(DistributionRow, ProductsRow);
			DistributionRow.NewRow = True;
		EndIf;
		
		// Quantity.
		DistributionRow.Quantity = Round((QuantityToWriteOff - InitQuantity) * StringMaterials.CostPercentage / ?(DistributionBaseQuantity = 0, 1, DistributionBaseQuantity),3,1);
		
		If DistributionRow.Quantity = 0 Then
			DistributionRow.Quantity = QuantityToWriteOff;
			InitQuantity = QuantityToWriteOff;
		Else
			DistributionBaseQuantity = DistributionBaseQuantity - StringMaterials.CostPercentage;
			InitQuantity = InitQuantity + DistributionRow.Quantity;
		EndIf;
		
		If InitQuantity > QuantityToWriteOff Then
			DistributionRow.Quantity = DistributionRow.Quantity - (InitQuantity - QuantityToWriteOff);
			InitQuantity = QuantityToWriteOff;
		EndIf;
		
		// Reserve.
		If InitReserve = ReserveToWriteOff Then
			Continue;
		EndIf;
		
		DistributionRow.Reserve = Round((ReserveToWriteOff - InitReserve) * StringMaterials.CostPercentage / ?(DistributionBaseReserve = 0, 1, DistributionBaseReserve),3,1);
		
		If DistributionRow.Reserve = 0 Then
			DistributionRow.Reserve = ReserveToWriteOff;
			InitReserve = ReserveToWriteOff;
		Else
			DistributionBaseReserve = DistributionBaseReserve - StringMaterials.CostPercentage;
			InitReserve = InitReserve + DistributionRow.Reserve;
		EndIf;
		
		If InitReserve > ReserveToWriteOff Then
			DistributionRow.Reserve = DistributionRow.Reserve - (InitReserve - ReserveToWriteOff);
			InitReserve = ReserveToWriteOff;
		EndIf;
		
	EndDo;
	
	If DistributionRow <> Undefined Then
		
		If InitQuantity < QuantityToWriteOff Then
			DistributionRow.Quantity = DistributionRow.Quantity + (QuantityToWriteOff - InitQuantity);
		EndIf;
		
		If InitReserve < ReserveToWriteOff Then
			DistributionRow.Reserve = DistributionRow.Reserve + (ReserveToWriteOff - InitReserve);
		EndIf;
		
	EndIf;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDisposals(DocumentRefProduction, StructureAdditionalProperties)
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDisposals[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
		// Reusable scraps autotransfer.
		If ValueIsFilled(RowTableInventory.DisposalsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventory.DisposalsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventory.GlAccountWaste;
			
			TableRowExpense.ProductsCorr = RowTableInventory.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventory.Batch;
			TableRowExpense.CustomerCorrOrder = RowTableInventory.SalesOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
			TableRowExpense.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventory);
			
			TableRowReceipt.StructuralUnit = RowTableInventory.DisposalsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventory.GlAccountWaste;

			TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
			
			TableRowReceipt.ProductsCorr = RowTableInventory.Products;
			TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventory.Batch;
			TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
			TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryDisposals");
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	&Company AS Company,
	|	ProductionWaste.Ref.Date AS Period,
	|	ProductionWaste.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionWaste.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN ProductionWaste.Ref.StructuralUnit = ProductionWaste.Ref.DisposalsStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionWaste.Ref.DisposalsStructuralUnit
	|	END AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN ProductionWaste.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionWaste.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionWaste.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionWaste.InventoryGLAccount
	|				ELSE ProductionWaste.ConsumptionGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN ProductionWaste.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionWaste.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionWaste.Ref.DisposalsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionWaste.InventoryGLAccount
	|				ELSE ProductionWaste.ConsumptionGLAccount
	|			END
	|	END AS GlAccountWaste,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN ProductionWaste.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|				AND NOT ProductionWaste.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				AND NOT ProductionWaste.Ref.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN ProductionWaste.Ref.SalesOrder
	|		ELSE UNDEFINED
	|	END AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(ProductionWaste.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionWaste.Quantity
	|		ELSE ProductionWaste.Quantity * ProductionWaste.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&ReturnWaste AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&ReturnWaste AS STRING(100)) AS Content
	|FROM
	|	Document.Production.Disposals AS ProductionWaste
	|WHERE
	|	ProductionWaste.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionWaste.LineNumber AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionWaste.Ref.Date AS Period,
	|	&Company AS Company,
	|	ProductionWaste.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionWaste.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	ProductionWaste.Ref.DisposalsStructuralUnit AS DisposalsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionWaste.Ref.DisposalsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS DisposalsCell,
	|	ProductionWaste.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionWaste.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionWaste.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN VALUETYPE(ProductionWaste.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionWaste.Quantity
	|		ELSE ProductionWaste.Quantity * ProductionWaste.MeasurementUnit.Factor
	|	END AS Quantity
	|FROM
	|	Document.Production.Disposals AS ProductionWaste
	|WHERE
	|	ProductionWaste.Ref = &Ref";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	Query.SetParameter("ReturnWaste", NStr("en = 'Recyclable waste'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDisposals", ResultsArray[0].Unload());

	// Generate table for inventory accounting.
	GenerateTableInventoryDisposals(DocumentRefProduction, StructureAdditionalProperties);

	// Expand table for inventory.
	ResultsSelection = ResultsArray[1].Select();
	
	While ResultsSelection.Next() Do
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.SalesOrder <> UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
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
	|	InventoryBalances.SalesOrder AS SalesOrder,
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
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
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
	|		DocumentRegisterRecordsInventory.SalesOrder,
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
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	AmountForTransfer = 0;
	RowOfTableInventoryToBeTransferred = Undefined;
	TablesProductsToBeTransferred = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.CopyColumns();
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
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
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("SalesOrder", Undefined);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].QuantityBalance = 0;
				BalanceRowsArray[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = Undefined;
					
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
		// Inventory writeoff.
		RowOfTableInventoryToBeTransferred = RowTableInventory;
		
		If AmountForTransfer > 0 
			AND RowOfTableInventoryToBeTransferred <> Undefined 
			AND ValueIsFilled(RowOfTableInventoryToBeTransferred.ProductsStructuralUnit) Then
			
			NewRow = TablesProductsToBeTransferred.Add();
			FillPropertyValues(NewRow, RowOfTableInventoryToBeTransferred);
			NewRow.Amount = AmountForTransfer;
			
		EndIf;
		
		AmountForTransfer = 0;
		
	EndDo;
	
	If TablesProductsToBeTransferred.Count() > 1 Then
		TablesProductsToBeTransferred.GroupBy("Company,Period,PlanningPeriod,ProductsStructuralUnit,ProductionExpenses,CustomerCorrOrder,ProductsCorr,BatchCorr,StructuralUnitCorr,CorrGLAccount,CharacteristicCorr,ProductsAccountDr,ProductsAccountCr,ProductsGLAccount","Amount");
	EndIf;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	// Inventory writeoff.
	For Each StringProductsToBeTransferred In TablesProductsToBeTransferred Do
	
		// Expense.
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, StringProductsToBeTransferred);
		
		TableRowExpense.RecordType = AccumulationRecordType.Expense;
		
		TableRowExpense.StructuralUnit = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowExpense.GLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowExpense.Products = StringProductsToBeTransferred.ProductsCorr;
		TableRowExpense.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.Specification = Undefined;
		TableRowExpense.SalesOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.StructuralUnitCorr = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowExpense.CorrGLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowExpense.ProductsCorr = StringProductsToBeTransferred.ProductsCorr;
		TableRowExpense.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.SpecificationCorr = Undefined;
		TableRowExpense.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.Amount = StringProductsToBeTransferred.Amount;
		TableRowExpense.Quantity = 0;
		
		// Receipt.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, StringProductsToBeTransferred);
		
		TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
		
		TableRowReceipt.StructuralUnit = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowReceipt.GLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowReceipt.Products = StringProductsToBeTransferred.ProductsCorr;
		TableRowReceipt.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.Specification = Undefined;
		TableRowReceipt.SalesOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.AccountDr = StringProductsToBeTransferred.ProductsAccountDr;
		TableRowReceipt.AccountCr = StringProductsToBeTransferred.ProductsAccountCr;
		
		TableRowReceipt.StructuralUnitCorr = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowReceipt.CorrGLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowReceipt.ProductsCorr = StringProductsToBeTransferred.ProductsCorr;
		TableRowReceipt.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.SpecificationCorr = Undefined;
		TableRowReceipt.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.Amount = StringProductsToBeTransferred.Amount;
		TableRowReceipt.Quantity = 0;
		
		TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
		TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
		
		// Generate postings.
		RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
		FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	TablesProductsToBeTransferred = Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefProduction);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductionTransfer(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.GLAccount AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	SUM(TableInventory.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'", MainLanguageCode));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", Query.Execute().Unload());
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|		TableInventory.InventoryGLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.SalesOrder <> UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.InventoryStructuralUnit,
	|		TableInventory.InventoryGLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
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
	|	InventoryBalances.SalesOrder AS SalesOrder,
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
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
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
	|		DocumentRegisterRecordsInventory.SalesOrder,
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
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref",			DocumentRefProduction);
	Query.SetParameter("ControlTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",	StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalancesMove = QueryResult.Unload();
	TableInventoryBalancesMove.Indexes.Add("Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder");
	
	TemporaryTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.CopyColumns();
	
	IsEmptyStructuralUnit		= Catalogs.BusinessUnits.EmptyRef();
	EmptyAccount				= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyProducts	= Catalogs.Products.EmptyRef();
	EmptyCharacteristic			= Catalogs.ProductsCharacteristics.EmptyRef();
	EmptyBatch					= Catalogs.ProductsBatches.EmptyRef();
	EmptySalesOrder				= Undefined;
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();

	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		StructureForSearchTransfer = New Structure;
		StructureForSearchTransfer.Insert("Company",				RowTableInventoryTransfer.Company);
		StructureForSearchTransfer.Insert("StructuralUnit",			RowTableInventoryTransfer.StructuralUnit);
		StructureForSearchTransfer.Insert("GLAccount",				RowTableInventoryTransfer.GLAccount);
		StructureForSearchTransfer.Insert("Products",	RowTableInventoryTransfer.Products);
		StructureForSearchTransfer.Insert("Characteristic",			RowTableInventoryTransfer.Characteristic);
		StructureForSearchTransfer.Insert("Batch",					RowTableInventoryTransfer.Batch);
		
		QuantityRequiredReserveTransfer = RowTableInventoryTransfer.Reserve;
		QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
		
		If QuantityRequiredReserveTransfer > 0 Then
			
			QuantityRequiredAvailableBalanceTransfer = QuantityRequiredAvailableBalanceTransfer - QuantityRequiredReserveTransfer;
			
			StructureForSearchTransfer.Insert("SalesOrder", RowTableInventoryTransfer.SalesOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredReserveTransfer Then

				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredReserveTransfer / QuantityBalanceDisplacement , 2, 1);

				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredReserveTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;

			ElsIf QuantityBalanceDisplacement = QuantityRequiredReserveTransfer Then

				AmountToBeWrittenOffMove = AmountBalanceMove;

				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOffMove = 0;	
			EndIf;
	
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredReserveTransfer;
												
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableAccountingJournalEntriesMove = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntriesMove, RowTableInventoryTransfer);
				RowTableAccountingJournalEntriesMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredReserveTransfer > 0 Then
									
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.Products = RowTableInventoryTransfer.ProductsCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
						
				TableRowReceiptMove.SalesOrder = RowTableInventoryTransfer.CustomerCorrOrder;
								
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsCorr = RowTableInventoryTransfer.Products;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				
				TableRowReceiptMove.CustomerCorrOrder = RowTableInventoryTransfer.SalesOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredReserveTransfer;
								
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalanceTransfer > 0 Then
			
			StructureForSearchTransfer.Insert("SalesOrder", EmptySalesOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then

				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer / QuantityBalanceDisplacement , 2, 1);

				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredAvailableBalanceTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;

			ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then

				AmountToBeWrittenOffMove = AmountBalanceMove;

				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;

			Else
				AmountToBeWrittenOffMove = 0;	
			EndIf;
	
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
			TableRowExpenseMove.SalesOrder = EmptySalesOrder;
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableAccountingJournalEntriesMove = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntriesMove, RowTableInventoryTransfer);
				RowTableAccountingJournalEntriesMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredAvailableBalanceTransfer > 0 Then
								
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.Products = RowTableInventoryTransfer.ProductsCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
				
				TableRowReceiptMove.SalesOrder = RowTableInventoryTransfer.SalesOrder;
								
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsCorr = RowTableInventoryTransfer.Products;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				
				TableRowReceiptMove.CustomerCorrOrder = EmptySalesOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
								
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
						
			EndIf;
			
		EndIf;
					
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove = TemporaryTableInventoryTransfer;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);

	EndDo;	
	
	TemporaryTableInventoryTransfer.Indexes.Add("RecordType,Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	AmountForTransfer = 0;
	RowOfTableInventoryToBeTransferred = Undefined;
	TablesProductsToBeTransferred = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.CopyColumns();
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		QuantityRequiredReserve = RowTableInventory.Reserve;
		QuantityRequiredAvailableBalance = RowTableInventory.Quantity;
		
		If QuantityRequiredReserve > 0 Then
			
			QuantityRequiredAvailableBalance = QuantityRequiredAvailableBalance - QuantityRequiredReserve;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredReserve Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredReserve / QuantityBalance , 2, 1);

				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - QuantityRequiredReserve;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;

			ElsIf QuantityBalance = QuantityRequiredReserve Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].Quantity = 0;
				BalanceRowsArray[0].Amount = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredReserve;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
									
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalance > 0 Then
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = Round(AmountBalance * QuantityRequiredAvailableBalance / QuantityBalance , 2, 1);

				//// Changes
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - QuantityRequiredAvailableBalance;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				//// Changes
				
			ElsIf QuantityBalance = QuantityRequiredAvailableBalance Then

				AmountToBeWrittenOff = AmountBalance;

				BalanceRowsArray[0].Quantity = 0;
				BalanceRowsArray[0].Amount = 0;

			Else
				AmountToBeWrittenOff = 0;	
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
	
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = QuantityRequiredAvailableBalance;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = RowTableInventory.SalesOrder;
			
			// Receipt.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
					
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
					
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				AmountForTransfer = AmountForTransfer + AmountToBeWrittenOff;
				
			EndIf;
			
		EndIf;
		
		// Inventory writeoff.
		RowOfTableInventoryToBeTransferred = RowTableInventory;
		
		If AmountForTransfer > 0 
			AND RowOfTableInventoryToBeTransferred <> Undefined 
			AND ValueIsFilled(RowOfTableInventoryToBeTransferred.ProductsStructuralUnit) Then
			
			NewRow = TablesProductsToBeTransferred.Add();
			FillPropertyValues(NewRow, RowOfTableInventoryToBeTransferred);
			NewRow.Amount = AmountForTransfer;
			
		EndIf;
		
		AmountForTransfer = 0;
		
	EndDo;
	
	If TablesProductsToBeTransferred.Count() > 1 Then
		TablesProductsToBeTransferred.GroupBy("Company,Period,PlanningPeriod,ProductsStructuralUnit,ProductionExpenses,CustomerCorrOrder,ProductsCorr,BatchCorr,StructuralUnitCorr,CorrGLAccount,CharacteristicCorr,ProductsAccountDr,ProductsAccountCr,ProductsGLAccount","Amount");
	EndIf;
	
	// Inventory writeoff.
	For Each StringProductsToBeTransferred In TablesProductsToBeTransferred Do
	
		// Expense.
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowExpense, StringProductsToBeTransferred);
		
		TableRowExpense.RecordType = AccumulationRecordType.Expense;
		
		TableRowExpense.StructuralUnit = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowExpense.GLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowExpense.Products = StringProductsToBeTransferred.ProductsCorr;
		TableRowExpense.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.Specification = Undefined;
		TableRowExpense.SalesOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.StructuralUnitCorr = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowExpense.CorrGLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowExpense.ProductsCorr = StringProductsToBeTransferred.ProductsCorr;
		TableRowExpense.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowExpense.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowExpense.SpecificationCorr = Undefined;
		TableRowExpense.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowExpense.Amount = StringProductsToBeTransferred.Amount;
		TableRowExpense.Quantity = 0;
		
		// Receipt.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, StringProductsToBeTransferred);
		
		TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
		
		TableRowReceipt.StructuralUnit = StringProductsToBeTransferred.ProductsStructuralUnit;
		TableRowReceipt.GLAccount = StringProductsToBeTransferred.ProductsGLAccount;
		TableRowReceipt.Products = StringProductsToBeTransferred.ProductsCorr;
		TableRowReceipt.Characteristic = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.Batch = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.Specification = Undefined;
		TableRowReceipt.SalesOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.AccountDr = StringProductsToBeTransferred.ProductsAccountDr;
		TableRowReceipt.AccountCr = StringProductsToBeTransferred.ProductsAccountCr;
		
		TableRowReceipt.StructuralUnitCorr = StringProductsToBeTransferred.StructuralUnitCorr;
		TableRowReceipt.CorrGLAccount = StringProductsToBeTransferred.CorrGLAccount;
		TableRowReceipt.ProductsCorr = StringProductsToBeTransferred.ProductsCorr;
		TableRowReceipt.CharacteristicCorr = StringProductsToBeTransferred.CharacteristicCorr;
		TableRowReceipt.BatchCorr = StringProductsToBeTransferred.BatchCorr;
		TableRowReceipt.SpecificationCorr = Undefined;
		TableRowReceipt.CustomerCorrOrder = StringProductsToBeTransferred.CustomerCorrOrder;
		
		TableRowReceipt.Amount = StringProductsToBeTransferred.Amount;
		TableRowReceipt.Quantity = 0;
		
		TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
		TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
		
		// Generate postings.
		RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
		FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries = 
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefProduction);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryMove");
	TablesProductsToBeTransferred = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	CASE
	|		WHEN TableInventoryDemand.SalesOrder = UNDEFINED
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE TableInventoryDemand.SalesOrder
	|	END AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;
	
	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Balance receipt
	Query.Text =
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						CASE
	|							WHEN TemporaryTableInventory.SalesOrder = UNDEFINED
	|								THEN VALUE(Document.SalesOrder.EmptyRef)
	|							ELSE TemporaryTableInventory.SalesOrder
	|						END,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	
	If ValueIsFilled(DocumentRefProduction.SalesOrder) Then
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");
	
	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 		RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder", 	?(RowTablesForInventory.SalesOrder = Undefined, Documents.SalesOrder.EmptyRef(), RowTablesForInventory.SalesOrder));
		StructureForSearch.Insert("Products", 	RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic", 	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 AND BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateRawMaterialsConsumptionTableAssembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.CorrLineNumber AS CorrLineNumber,
	|	TableProduction.ProductsCorr AS ProductsCorr,
	|	TableProduction.CharacteristicCorr AS CharacteristicCorr,
	|	TableProduction.BatchCorr AS BatchCorr,
	|	TableProduction.SpecificationCorr AS SpecificationCorr,
	|	TableProduction.CorrGLAccount AS CorrGLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	TableProduction.AccountDr AS AccountDr,
	|	TableProduction.ProductsAccountDr AS ProductsAccountDr,
	|	TableProduction.ProductsAccountCr AS ProductsAccountCr,
	|	TableProduction.CorrQuantity AS CorrQuantity
	|INTO TemporaryTableVT
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.CorrLineNumber AS CorrLineNumber,
	|	TableProductsContent.ProductsCorr AS ProductsCorr,
	|	TableProductsContent.CharacteristicCorr AS CharacteristicCorr,
	|	TableProductsContent.BatchCorr AS BatchCorr,
	|	TableProductsContent.SpecificationCorr AS SpecificationCorr,
	|	TableProductsContent.CorrGLAccount AS CorrGLAccount,
	|	TableProductsContent.ProductsGLAccount AS ProductsGLAccount,
	|	TableProductsContent.AccountDr AS AccountDr,
	|	TableProductsContent.ProductsAccountDr AS ProductsAccountDr,
	|	TableProductsContent.ProductsAccountCr AS ProductsAccountCr,
	|	TableProductsContent.CorrQuantity AS CorrQuantity,
	|	CASE
	|		WHEN VALUETYPE(TableMaterials.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN CASE
	|					WHEN TableMaterials.Quantity = 0
	|						THEN 1
	|					ELSE TableMaterials.Quantity
	|				END / TableMaterials.ProductsQuantity * TableProductsContent.CorrQuantity
	|		ELSE CASE
	|				WHEN TableMaterials.Quantity = 0
	|					THEN 1
	|				ELSE TableMaterials.Quantity
	|			END * TableMaterials.MeasurementUnit.Factor / TableMaterials.ProductsQuantity * TableProductsContent.CorrQuantity
	|	END AS TMQuantity,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.SpecificationCorr = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|
	|ORDER BY
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.Ref.Date AS Period,
	|	ProductionInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit = ProductionInventory.Ref.InventoryStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionInventory.Ref.InventoryStructuralUnit
	|	END AS InventoryStructuralUnit,
	|	ProductionInventory.Ref.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit = ProductionInventory.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionInventory.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	CASE
	|		WHEN ProductionInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionInventory.InventoryGLAccount
	|				ELSE ProductionInventory.ConsumptionGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN ProductionInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionInventory.Ref.InventoryStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionInventory.InventoryGLAccount
	|				ELSE ProductionInventory.ConsumptionGLAccount
	|			END
	|	END AS InventoryGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS CorrGLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	VALUE(Catalog.Products.EmptyRef) AS ProductsCorr,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS CharacteristicCorr,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionInventory.Batch.Status
	|		ELSE VALUE(Enum.BatchStatuses.EmptyRef)
	|	END AS BatchStatus,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS BatchCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS SpecificationCorr,
	|	ProductionInventory.Specification AS Specification,
	|	CASE
	|		WHEN ProductionInventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.Ref.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.Ref.SalesOrder
	|	END AS SalesOrder,
	|	CASE
	|		WHEN VALUETYPE(ProductionInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionInventory.Quantity
	|		ELSE ProductionInventory.Quantity * ProductionInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	CASE
	|		WHEN VALUETYPE(ProductionInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionInventory.Reserve
	|		ELSE ProductionInventory.Reserve * ProductionInventory.MeasurementUnit.Factor
	|	END AS Reserve,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS AccountDr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsAccountDr,
	|	CASE
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|		AND ProductionInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS AccountCr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS ProductsAccountCr,
	|	FALSE AS Distributed
	|FROM
	|	Document.Production.Inventory AS ProductionInventory
	|WHERE
	|	ProductionInventory.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("TableProduction",		TableProduction);
	Query.SetParameter("Ref",					DocumentRefProduction);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProductsContent = ResultsArray[1].Unload();
	MaterialsTable = ResultsArray[2].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.BOMLineType.Node Then
			NodesBillsOfMaterialstack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesBillsOfMaterialstack);
			TableProductsContent.Delete(ProductsRow);
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	
	TableProductsContent.GroupBy("ProductsCorr, CharacteristicCorr, BatchCorr, SpecificationCorr, CorrGLAccount, ProductsGLAccount, AccountDr,
		|ProductsAccountDr, ProductsAccountCr, CorrQuantity, TMProducts, TMCharacteristic, Distributed", "TMQuantity");
	TableProductsContent.Indexes.Add("TMProducts, TMCharacteristic");
	
	DistributedMaterials	= 0;
	ProductsQuantity		= TableProductsContent.Count();
	MaterialsAmount			= MaterialsTable.Count();
	
	For n = 0 To MaterialsAmount - 1 Do
		
		StringMaterials = MaterialsTable[n];
		
		SearchStructure = New Structure;
		SearchStructure.Insert("TMProducts",	StringMaterials.Products);
		SearchStructure.Insert("TMCharacteristic",		StringMaterials.Characteristic);
		
		SearchResult = TableProductsContent.FindRows(SearchStructure);
		If SearchResult.Count() <> 0 Then
			DistributeMaterialsAccordingToNorms(StringMaterials, SearchResult, MaterialsTable);
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
		
	EndDo;
	
	DistributedProducts = 0;
	For Each ProductsContentRow In TableProductsContent Do
		If ProductsContentRow.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
	EndDo;
	
	If DistributedMaterials < MaterialsAmount Then
		If DistributedProducts = ProductsQuantity Then
			DistributionBase = TableProduction.Total("CorrQuantity");
			DistributeMaterialsByQuantity(TableProduction, MaterialsTable, DistributionBase);
		Else
			DistributeMaterialsByQuantity(TableProductsContent, MaterialsTable);
		EndIf;
	EndIf;
	
	TableProduction			= Undefined;
	TableProductsContent	= Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableRawMaterialsConsumptionAssembly", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	ProductionInventory.CellInventory AS CellInventory,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.InventoryGLAccount AS InventoryGLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.ProductsGLAccount AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.BatchStatus AS BatchStatus,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	CASE
	|		WHEN ProductionInventory.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.SalesOrder
	|	END AS SalesOrder,
	|	ProductionInventory.Quantity AS Quantity,
	|	ProductionInventory.Reserve AS Reserve,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.ProductsAccountDr AS ProductsAccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	ProductionInventory.ProductsAccountCr AS ProductsAccountCr,
	|	CAST(&InventoryDistribution AS String(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS String(100)) AS Content
	|INTO TemporaryTableInventory
	|FROM
	|	&TableRawMaterialsConsumptionAssembly AS ProductionInventory
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsGLAccount AS ProductsGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ProductsAccountDr AS ProductsAccountDr,
	|	TableInventory.ProductsAccountCr AS ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	0 AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsAccountDr,
	|	TableInventory.ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.StructuralUnit,
	|	TableInventory.SalesOrder,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS InventoryStructuralUnit,
	|	TableInventory.CellInventory AS CellInventory,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Cell AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS Order,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.BatchStatus = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableRawMaterialsConsumptionAssembly", StructureAdditionalProperties.TableForRegisterRecords.TableRawMaterialsConsumptionAssembly);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());

	// Generate table for inventory accounting.
	If ValueIsFilled(DocumentRefProduction.InventoryStructuralUnit) 
		AND DocumentRefProduction.InventoryStructuralUnit <> DocumentRefProduction.StructuralUnit Then
		
		// Inventory autotransfer.
		GenerateTableInventoryProductionTransfer(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
		
	Else
		
		GenerateTableInventoryProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
		
	EndIf;

	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		// Inventory autotransfer.
		If (ResultsSelection.InventoryStructuralUnit = ResultsSelection.StructuralUnit
			AND ResultsSelection.CellInventory <> ResultsSelection.Cell)
			OR ResultsSelection.InventoryStructuralUnit <> ResultsSelection.StructuralUnit Then
			
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
			FillPropertyValues(TableRowExpense, ResultsSelection);
			
			TableRowExpense.StructuralUnit = ResultsSelection.InventoryStructuralUnit;
			TableRowExpense.Cell = ResultsSelection.CellInventory;
			
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
			FillPropertyValues(TableRowReceipt, ResultsSelection);
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
		EndIf;
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
 
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableRawMaterialsConsumptionAssembly");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductsAssembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Indexes.Add("RecordType,Company,Products,Characteristic");;
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Indexes.Add("RecordType,Company,Products,Characteristic,Batch,ProductsCorr,CharacteristicCorr,BatchCorr,ProductionExpenses");;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If sales order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		// Products autotransfer.
		GLAccountTransferring = Undefined;
		If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.Specification = Undefined;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventoryProducts.ProductsGLAccount;
			
			TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowExpense.SpecificationCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
			TableRowExpense.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
			
			TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
			TableRowReceipt.Specification = Undefined;
			
			GLAccountTransferring = TableRowReceipt.GLAccount;
			
			TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
			
			TableRowReceipt.ProductsCorr = RowTableInventoryProducts.Products;
			TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowReceipt.SpecificationCorr = Undefined;
			TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
			TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
			
		EndIf;
		
		// If the production order is filled in and there is no
		// sales order, then check whether there are placed customers orders in the production order.
		If Not ValueIsFilled(RowTableInventoryProducts.SalesOrder)
			AND ValueIsFilled(RowTableInventoryProducts.ProductionOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			IndexOf = 0;
			OutputQuantity = RowTableInventoryProducts.Quantity;
			ArrayPropertiesProducts = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventoryProducts.Batch);
			StructureForSearch.Insert("ProductionExpenses", False);
			
			If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
				StructureForSearch.Insert("ProductsCorr", RowTableInventoryProducts.Products);
				StructureForSearch.Insert("CharacteristicCorr", RowTableInventoryProducts.Characteristic);
				StructureForSearch.Insert("BatchCorr", RowTableInventoryProducts.Batch);
			EndIf;
			
			OutputCost = 0;
			ArrayCostOutputs = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.FindRows(StructureForSearch);
			For Each OutputRow In ArrayCostOutputs Do
				OutputCost = OutputCost + OutputRow.Amount;
			EndDo;
			
			For Each StringAllocationArray In ArrayPropertiesProducts Do
				
				OutputAmountToReserve = StringAllocationArray.Quantity;
				
				If OutputQuantity = OutputAmountToReserve Then
					OutputCostInReserve = OutputCost;
				Else
					OutputCostInReserve = Round(OutputCost * OutputAmountToReserve / OutputQuantity, 2, 1);
				EndIf;
				
				If OutputAmountToReserve > 0 Then
				
					TotalAmountToWriteOffByOrder = 0;
					
					AmountToBeWrittenOffByOrder = Round(OutputCostInReserve * StringAllocationArray.Quantity / OutputAmountToReserve, 2, 1);
					TotalAmountToWriteOffByOrder = TotalAmountToWriteOffByOrder + AmountToBeWrittenOffByOrder;
					
					If IndexOf = ArrayPropertiesProducts.Count() - 1 Then // It is the last string, it is required to correct amount.
						AmountToBeWrittenOffByOrder = AmountToBeWrittenOffByOrder + (OutputCostInReserve - TotalAmountToWriteOffByOrder);
					EndIf;
					
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
					
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.GLAccount = GLAccountTransferring;
						TableRowExpense.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowExpense.CustomerCorrOrder = StringAllocationArray.SalesOrder;
					TableRowExpense.Quantity = StringAllocationArray.Quantity;
					TableRowExpense.Amount = AmountToBeWrittenOffByOrder;
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.SalesOrder = StringAllocationArray.SalesOrder;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.GLAccount = GLAccountTransferring;
						TableRowReceipt.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowReceipt.ProductsCorr = RowTableInventoryProducts.Products;
					TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowReceipt.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
					TableRowReceipt.Quantity = StringAllocationArray.Quantity;
					TableRowReceipt.Amount = AmountToBeWrittenOffByOrder;
					
					IndexOf = IndexOf + 1;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackordersAssembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.SupplySource";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	CASE
	|		WHEN TableProduction.Quantity > ISNULL(BackordersBalances.Quantity, 0)
	|			THEN ISNULL(BackordersBalances.Quantity, 0)
	|		WHEN TableProduction.Quantity <= ISNULL(BackordersBalances.Quantity, 0)
	|			THEN TableProduction.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				BackordersBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						&ControlTime,
	|						(Company, Products, Characteristic, SupplySource) IN
	|							(SELECT
	|								TableProduction.Company AS Company,
	|								TableProduction.Products AS Products,
	|								TableProduction.Characteristic AS Characteristic,
	|								TableProduction.SupplySource AS SupplySource
	|							FROM
	|								TemporaryTableProduction AS TableProduction
	|							WHERE
	|								TableProduction.SupplySource <> UNDEFINED)) AS BackordersBalances
	|			
	|			UNION ALL
	|			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod) AS BackordersBalances
	|		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableProduction.Company = BackordersBalances.Company
	|			AND TableProduction.Products = BackordersBalances.Products
	|			AND TableProduction.Characteristic = BackordersBalances.Characteristic
	|			AND TableProduction.SupplySource = BackordersBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND BackordersBalances.SalesOrder IS NOT NULL ";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text =
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.StructuralUnit AS StructuralUnit,
	|		TableInventory.GLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.SalesOrder <> UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.StructuralUnit,
	|		TableInventory.GLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
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
	|	InventoryBalances.SalesOrder AS SalesOrder,
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
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.StructuralUnit,
	|						TableInventory.GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
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
	|		DocumentRegisterRecordsInventory.SalesOrder,
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
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalances = QueryResult.Unload();
	TableInventoryBalances.Indexes.Add("Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		ReserveRequired = RowTableInventory.Reserve;
		Required_Quantity = RowTableInventory.Quantity;
		
		If ReserveRequired > 0 Then
			
			Required_Quantity = Required_Quantity - ReserveRequired;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
				
				AmountRequired = Round(BalanceRowsArray[0].AmountBalance * ReserveRequired / BalanceRowsArray[0].QuantityBalance,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > ReserveRequired Then
				
				AmountToBeWrittenOff = Round(AmountBalance * ReserveRequired / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - ReserveRequired;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = ReserveRequired Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = ReserveRequired;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.Products = RowTableInventory.ProductsCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
					TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
						FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Required_Quantity > 0 Then
			
			StructureForSearch.Insert("SalesOrder", Undefined);
			
			BalanceRowsArray = TableInventoryBalances.FindRows(StructureForSearch);
			
			QuantityBalance = 0;
			AmountBalance = 0;
			
			If BalanceRowsArray.Count() > 0 Then
				
				QuantityBalance = BalanceRowsArray[0].QuantityBalance;
				AmountBalance = BalanceRowsArray[0].AmountBalance;
				
				AmountRequired = Round(BalanceRowsArray[0].AmountBalance * Required_Quantity / BalanceRowsArray[0].QuantityBalance,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > Required_Quantity Then
				
				AmountToBeWrittenOff = Round(AmountBalance * Required_Quantity / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - Required_Quantity;
				BalanceRowsArray[0].AmountBalance = BalanceRowsArray[0].AmountBalance - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = Required_Quantity Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = Required_Quantity;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = Undefined;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
				FillPropertyValues(TableRowReceipt, RowTableInventory);
				
				TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceipt.StructuralUnit = RowTableInventory.StructuralUnitCorr;
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				TableRowReceipt.Products = RowTableInventory.ProductsCorr;
				TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
				TableRowReceipt.Batch = RowTableInventory.BatchCorr;
				TableRowReceipt.Specification = RowTableInventory.SpecificationCorr;
				TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
				
				TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnit;
				TableRowReceipt.CorrGLAccount = RowTableInventory.GLAccount;
				TableRowReceipt.ProductsCorr = RowTableInventory.Products;
				TableRowReceipt.CharacteristicCorr = RowTableInventory.Characteristic;
				TableRowReceipt.BatchCorr = RowTableInventory.Batch;
				TableRowReceipt.SpecificationCorr = RowTableInventory.Specification;
				TableRowReceipt.CustomerCorrOrder = Undefined;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.Products = RowTableInventory.ProductsCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
					TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
						FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries =
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefProduction);
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryInventoryDisassemblyTransfer(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.Period AS Period,
	|	TableInventory.Company AS Company,
	|	TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.InventoryGLAccount AS GLAccount,
	|	TableInventory.GLAccount AS CorrGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Products AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Characteristic AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Batch AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.Specification AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	UNDEFINED AS SourceDocument,
	|	UNDEFINED AS CorrSalesOrder,
	|	UNDEFINED AS Department,
	|	UNDEFINED AS Responsible,
	|	TableInventory.GLAccount AS AccountDr,
	|	TableInventory.InventoryGLAccount AS AccountCr,
	|	&InventoryTransfer AS Content,
	|	&InventoryTransfer AS ContentOfAccountingRecord,
	|	FALSE AS FixedCost,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	TableInventory.Amount AS Amount
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.PlanningPeriod,
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.InventoryStructuralUnit,
	|	TableInventory.StructuralUnit,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Batch,
	|	TableInventory.Specification,
	|	TableInventory.Specification,
	|	TableInventory.SalesOrder,
	|	TableInventory.SalesOrder,
	|	TableInventory.GLAccount,
	|	TableInventory.InventoryGLAccount,
	|	TableInventory.Amount";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'", MainLanguageCode));
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryMove", Query.Execute().Unload());
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Setting the exclusive lock for the controlled inventory balances.
	Query.Text = 
	"SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS SalesOrder
	|FROM
	|	(SELECT
	|		TableInventory.Company AS Company,
	|		TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|		TableInventory.InventoryGLAccount AS GLAccount,
	|		TableInventory.Products AS Products,
	|		TableInventory.Characteristic AS Characteristic,
	|		TableInventory.Batch AS Batch,
	|		TableInventory.SalesOrder AS SalesOrder
	|	FROM
	|		TemporaryTableInventory AS TableInventory
	|	WHERE
	|		TableInventory.SalesOrder <> UNDEFINED
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		TableInventory.Company,
	|		TableInventory.InventoryStructuralUnit,
	|		TableInventory.InventoryGLAccount,
	|		TableInventory.Products,
	|		TableInventory.Characteristic,
	|		TableInventory.Batch,
	|		UNDEFINED
	|	FROM
	|		TemporaryTableInventory AS TableInventory) AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder";
	
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
	|	InventoryBalances.SalesOrder AS SalesOrder,
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
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance) AS QuantityBalance,
	|		SUM(InventoryBalances.AmountBalance) AS AmountBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder,
	|		SUM(InventoryBalances.QuantityBalance),
	|		SUM(InventoryBalances.AmountBalance)
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				&ControlTime,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						TableInventory.Company,
	|						TableInventory.InventoryStructuralUnit AS StructuralUnit,
	|						TableInventory.InventoryGLAccount AS GLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	GROUP BY
	|		InventoryBalances.Company,
	|		InventoryBalances.StructuralUnit,
	|		InventoryBalances.GLAccount,
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		InventoryBalances.Batch,
	|		InventoryBalances.SalesOrder
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
	|		DocumentRegisterRecordsInventory.SalesOrder,
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
	|	InventoryBalances.Batch,
	|	InventoryBalances.SalesOrder";
	
	Query.SetParameter("Ref",			DocumentRefProduction);
	Query.SetParameter("ControlTime",	New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	Query.SetParameter("ControlPeriod",	StructureAdditionalProperties.ForPosting.PointInTime.Date);
	
	QueryResult = Query.Execute();
	
	TableInventoryBalancesMove = QueryResult.Unload();
	TableInventoryBalancesMove.Indexes.Add("Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder");
	
	TemporaryTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.CopyColumns();
	
	IsEmptyStructuralUnit	= Catalogs.BusinessUnits.EmptyRef();
	EmptyAccount			= ChartsOfAccounts.PrimaryChartOfAccounts.EmptyRef();
	EmptyProducts			= Catalogs.Products.EmptyRef();
	EmptyCharacteristic		= Catalogs.ProductsCharacteristics.EmptyRef();
	EmptyBatch				= Catalogs.ProductsBatches.EmptyRef();
	EmptySalesOrder			= Undefined;
	
	TableAccountingJournalEntries = DriveServer.EmptyAccountingJournalEntriesTable();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventoryTransfer = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		StructureForSearchTransfer = New Structure;
		StructureForSearchTransfer.Insert("Company",				RowTableInventoryTransfer.Company);
		StructureForSearchTransfer.Insert("StructuralUnit",			RowTableInventoryTransfer.StructuralUnit);
		StructureForSearchTransfer.Insert("GLAccount",				RowTableInventoryTransfer.GLAccount);
		StructureForSearchTransfer.Insert("Products",	RowTableInventoryTransfer.Products);
		StructureForSearchTransfer.Insert("Characteristic",			RowTableInventoryTransfer.Characteristic);
		StructureForSearchTransfer.Insert("Batch",					RowTableInventoryTransfer.Batch);
		
		QuantityRequiredReserveTransfer = RowTableInventoryTransfer.Reserve;
		QuantityRequiredAvailableBalanceTransfer = RowTableInventoryTransfer.Quantity;
		
		If QuantityRequiredReserveTransfer > 0 Then
			
			QuantityRequiredAvailableBalanceTransfer = QuantityRequiredAvailableBalanceTransfer - QuantityRequiredReserveTransfer;
			
			StructureForSearchTransfer.Insert("SalesOrder", RowTableInventoryTransfer.SalesOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredReserveTransfer Then
				
				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredReserveTransfer / QuantityBalanceDisplacement , 2, 1);
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredReserveTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;
				
			ElsIf QuantityBalanceDisplacement = QuantityRequiredReserveTransfer Then
				
				AmountToBeWrittenOffMove = AmountBalanceMove;
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOffMove = 0;
			EndIf;
			
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredReserveTransfer;
			
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableAccountingJournalEntriesMove = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntriesMove, RowTableInventoryTransfer);
				RowTableAccountingJournalEntriesMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredReserveTransfer > 0 Then
				
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.Products = RowTableInventoryTransfer.ProductsCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
				
				TableRowReceiptMove.SalesOrder = RowTableInventoryTransfer.CustomerCorrOrder;
				
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsCorr = RowTableInventoryTransfer.Products;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				TableRowReceiptMove.CustomerCorrOrder = RowTableInventoryTransfer.SalesOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredReserveTransfer;
				
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
		If QuantityRequiredAvailableBalanceTransfer > 0 Then
			
			StructureForSearchTransfer.Insert("SalesOrder", EmptySalesOrder);
			
			BalanceRowsArrayDisplacement = TableInventoryBalancesMove.FindRows(StructureForSearchTransfer);
			
			QuantityBalanceDisplacement = 0;
			AmountBalanceMove = 0;
			
			If BalanceRowsArrayDisplacement.Count() > 0 Then
				QuantityBalanceDisplacement = BalanceRowsArrayDisplacement[0].QuantityBalance;
				AmountBalanceMove = BalanceRowsArrayDisplacement[0].AmountBalance;
			EndIf;
			
			If QuantityBalanceDisplacement > 0 AND QuantityBalanceDisplacement > QuantityRequiredAvailableBalanceTransfer Then
				
				AmountToBeWrittenOffMove = Round(AmountBalanceMove * QuantityRequiredAvailableBalanceTransfer / QuantityBalanceDisplacement , 2, 1);
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = BalanceRowsArrayDisplacement[0].QuantityBalance - QuantityRequiredAvailableBalanceTransfer;
				BalanceRowsArrayDisplacement[0].AmountBalance = BalanceRowsArrayDisplacement[0].AmountBalance - AmountToBeWrittenOffMove;
				
			ElsIf QuantityBalanceDisplacement = QuantityRequiredAvailableBalanceTransfer Then
				
				AmountToBeWrittenOffMove = AmountBalanceMove;
				
				BalanceRowsArrayDisplacement[0].QuantityBalance = 0;
				BalanceRowsArrayDisplacement[0].AmountBalance = 0;
				
			Else
				AmountToBeWrittenOffMove = 0;
			EndIf;
			
			// Expense.
			TableRowExpenseMove = TemporaryTableInventoryTransfer.Add();
			FillPropertyValues(TableRowExpenseMove, RowTableInventoryTransfer);
			
			TableRowExpenseMove.Specification = Undefined;
			TableRowExpenseMove.SpecificationCorr = Undefined;
			
			TableRowExpenseMove.Amount = AmountToBeWrittenOffMove;
			TableRowExpenseMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
			TableRowExpenseMove.SalesOrder = EmptySalesOrder;
			
			// Generate postings.
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 Then
				RowTableAccountingJournalEntriesMove = TableAccountingJournalEntries.Add();
				FillPropertyValues(RowTableAccountingJournalEntriesMove, RowTableInventoryTransfer);
				RowTableAccountingJournalEntriesMove.Amount = AmountToBeWrittenOffMove;
			EndIf;
			
			// Receipt
			If Round(AmountToBeWrittenOffMove, 2, 1) <> 0 OR QuantityRequiredAvailableBalanceTransfer > 0 Then
				
				TableRowReceiptMove = TemporaryTableInventoryTransfer.Add();
				FillPropertyValues(TableRowReceiptMove, RowTableInventoryTransfer);
				
				TableRowReceiptMove.RecordType = AccumulationRecordType.Receipt;
				
				TableRowReceiptMove.Company = RowTableInventoryTransfer.Company;
				TableRowReceiptMove.StructuralUnit = RowTableInventoryTransfer.StructuralUnitCorr;
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				TableRowReceiptMove.Products = RowTableInventoryTransfer.ProductsCorr;
				TableRowReceiptMove.Characteristic = RowTableInventoryTransfer.CharacteristicCorr;
				TableRowReceiptMove.Batch = RowTableInventoryTransfer.BatchCorr;
				TableRowReceiptMove.Specification = Undefined;
				
				TableRowReceiptMove.SalesOrder = RowTableInventoryTransfer.SalesOrder;
				
				TableRowReceiptMove.StructuralUnitCorr = RowTableInventoryTransfer.StructuralUnit;
				TableRowReceiptMove.CorrGLAccount = RowTableInventoryTransfer.GLAccount;
				TableRowReceiptMove.ProductsCorr = RowTableInventoryTransfer.Products;
				TableRowReceiptMove.CharacteristicCorr = RowTableInventoryTransfer.Characteristic;
				TableRowReceiptMove.BatchCorr = RowTableInventoryTransfer.Batch;
				TableRowReceiptMove.SpecificationCorr = Undefined;
				TableRowReceiptMove.CustomerCorrOrder = EmptySalesOrder;
				
				TableRowReceiptMove.Amount = AmountToBeWrittenOffMove;
				
				TableRowReceiptMove.Quantity = QuantityRequiredAvailableBalanceTransfer;
				
				TableRowReceiptMove.GLAccount = RowTableInventoryTransfer.CorrGLAccount;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove = TemporaryTableInventoryTransfer;
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryMove[n];
		
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventory);
		
	EndDo;
	
	TemporaryTableInventoryTransfer.Indexes.Add("RecordType,Company,StructuralUnit,GLAccount,Products,Characteristic,Batch,SalesOrder");
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory.Count() - 1 Do
		
		RowTableInventory = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInventory[n];
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
		StructureForSearch.Insert("Company", RowTableInventory.Company);
		StructureForSearch.Insert("StructuralUnit", RowTableInventory.StructuralUnit);
		StructureForSearch.Insert("GLAccount", RowTableInventory.GLAccount);
		StructureForSearch.Insert("Products", RowTableInventory.Products);
		StructureForSearch.Insert("Characteristic", RowTableInventory.Characteristic);
		StructureForSearch.Insert("Batch", RowTableInventory.Batch);
		
		ReserveRequired = RowTableInventory.Reserve;
		Required_Quantity = RowTableInventory.Quantity;
		
		If ReserveRequired > 0 Then
			
			Required_Quantity = Required_Quantity - ReserveRequired;
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				
				AmountRequired = Round(BalanceRowsArray[0].Amount * ReserveRequired / BalanceRowsArray[0].Quantity,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > ReserveRequired Then
				
				AmountToBeWrittenOff = Round(AmountBalance * ReserveRequired / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - ReserveRequired;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = ReserveRequired Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Write inventory off the warehouse (production department).
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = ReserveRequired;
			
			// Assign written off stocks to either inventory cost in the warehouse, or to WIP costs.
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
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
				TableRowReceipt.CustomerCorrOrder = RowTableInventory.SalesOrder;
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.Products = RowTableInventory.ProductsCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
					TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
						FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
		If Required_Quantity > 0 Then
			
			StructureForSearch.Insert("SalesOrder", RowTableInventory.SalesOrder);
			
			ArrayQuantityBalance = 0;
			ArrayAmountBalance = 0;
			BalanceRowsArray = TemporaryTableInventoryTransfer.FindRows(StructureForSearch);
			For Each RowBalances In BalanceRowsArray Do
				ArrayQuantityBalance = ArrayQuantityBalance + RowBalances.Quantity;
				ArrayAmountBalance = ArrayAmountBalance + RowBalances.Amount;
			EndDo;
			
			QuantityBalance = 0;
			AmountBalance = 0;
			If BalanceRowsArray.Count() > 0 Then
				
				BalanceRowsArray[0].Quantity = ArrayQuantityBalance;
				BalanceRowsArray[0].Amount = ArrayAmountBalance;
				QuantityBalance = BalanceRowsArray[0].Quantity;
				AmountBalance = BalanceRowsArray[0].Amount;
				
				AmountRequired = Round(BalanceRowsArray[0].Amount * Required_Quantity / BalanceRowsArray[0].Quantity,2,1);
				
			EndIf;
			
			If QuantityBalance > 0 AND QuantityBalance > Required_Quantity Then
				
				AmountToBeWrittenOff = Round(AmountBalance * Required_Quantity / QuantityBalance , 2, 1);
				
				BalanceRowsArray[0].Quantity = BalanceRowsArray[0].Quantity - Required_Quantity;
				BalanceRowsArray[0].Amount = BalanceRowsArray[0].Amount - AmountToBeWrittenOff;
				
			ElsIf QuantityBalance = Required_Quantity Then
				
				AmountToBeWrittenOff = AmountBalance;
				
			Else
				AmountToBeWrittenOff = 0;
			EndIf;
			
			AssemblyAmount = AssemblyAmount + AmountToBeWrittenOff;
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventory);
			
			TableRowExpense.Amount = AmountToBeWrittenOff;
			TableRowExpense.Quantity = Required_Quantity;
			TableRowExpense.ProductionExpenses = True;
			TableRowExpense.SalesOrder = RowTableInventory.SalesOrder;
			
			// Receipt
			If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
				
				TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
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
				
				TableRowReceipt.Amount = AmountToBeWrittenOff;
				TableRowReceipt.Quantity = 0;
				
				TableRowReceipt.GLAccount = RowTableInventory.CorrGLAccount;
				
				// Generate postings.
				If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
					RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
					FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
				EndIf;
				
				// Inventory writeoff.
				If ValueIsFilled(RowTableInventory.ProductsStructuralUnit) Then
					
					// Expense.
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventory);
					
					TableRowExpense.StructuralUnit = RowTableInventory.StructuralUnitCorr;
					TableRowExpense.GLAccount = RowTableInventory.CorrGLAccount;
					TableRowExpense.Products = RowTableInventory.ProductsCorr;
					TableRowExpense.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowExpense.Batch = RowTableInventory.BatchCorr;
					TableRowExpense.Specification = Undefined;
					TableRowExpense.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.StructuralUnitCorr = RowTableInventory.ProductsStructuralUnit;
					TableRowExpense.CorrGLAccount = RowTableInventory.ProductsGLAccount;
					TableRowExpense.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowExpense.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowExpense.BatchCorr = RowTableInventory.BatchCorr;
					TableRowExpense.SpecificationCorr = Undefined;
					TableRowExpense.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowExpense.Amount = AmountToBeWrittenOff;
					TableRowExpense.Quantity = 0;
					
					// Receipt.
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventory);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.StructuralUnit = RowTableInventory.ProductsStructuralUnit;
					TableRowReceipt.GLAccount = RowTableInventory.ProductsGLAccount;
					TableRowReceipt.Products = RowTableInventory.ProductsCorr;
					TableRowReceipt.Characteristic = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.Batch = RowTableInventory.BatchCorr;
					TableRowReceipt.Specification = Undefined;
					TableRowReceipt.SalesOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.AccountDr = RowTableInventory.ProductsAccountDr;
					TableRowReceipt.AccountCr = RowTableInventory.ProductsAccountCr;
					
					TableRowReceipt.StructuralUnitCorr = RowTableInventory.StructuralUnitCorr;
					TableRowReceipt.CorrGLAccount = RowTableInventory.CorrGLAccount;
					TableRowReceipt.ProductsCorr = RowTableInventory.ProductsCorr;
					TableRowReceipt.CharacteristicCorr = RowTableInventory.CharacteristicCorr;
					TableRowReceipt.BatchCorr = RowTableInventory.BatchCorr;
					TableRowReceipt.SpecificationCorr = Undefined;
					TableRowReceipt.CustomerCorrOrder = RowTableInventory.CustomerCorrOrder;
					
					TableRowReceipt.Amount = AmountToBeWrittenOff;
					TableRowReceipt.Quantity = 0;
					
					TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
					TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
					
					// Generate postings.
					If Round(AmountToBeWrittenOff, 2, 1) <> 0 Then
						RowTableAccountingJournalEntries = TableAccountingJournalEntries.Add();
						FillPropertyValues(RowTableAccountingJournalEntries, TableRowReceipt);
					EndIf;
					
				EndIf;
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryInventory");
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryMove");
	
	StructureAdditionalProperties.TableForRegisterRecords.TableAccountingJournalEntries =
		DriveServer.AddOfflineAccountingJournalEntriesRecords(TableAccountingJournalEntries, DocumentRefProduction);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryDemandDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	TableInventoryDemand.Company AS Company,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	CASE
	|		WHEN TableInventoryDemand.SalesOrder = UNDEFINED
	|			THEN VALUE(Document.SalesOrder.EmptyRef)
	|		ELSE TableInventoryDemand.SalesOrder
	|	END AS SalesOrder,
	|	TableInventoryDemand.Products AS Products,
	|	TableInventoryDemand.Characteristic AS Characteristic
	|FROM
	|	TemporaryTableInventory AS TableInventoryDemand";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.InventoryDemand");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();

	// Receive balance.
	Query.Text = 	
	"SELECT
	|	InventoryDemandBalances.Company AS Company,
	|	InventoryDemandBalances.SalesOrder AS SalesOrder,
	|	InventoryDemandBalances.Products AS Products,
	|	InventoryDemandBalances.Characteristic AS Characteristic,
	|	SUM(InventoryDemandBalances.Quantity) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryDemandBalances.Company AS Company,
	|		InventoryDemandBalances.SalesOrder AS SalesOrder,
	|		InventoryDemandBalances.Products AS Products,
	|		InventoryDemandBalances.Characteristic AS Characteristic,
	|		SUM(InventoryDemandBalances.QuantityBalance) AS Quantity
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				&ControlTime,
	|				(Company, MovementType, SalesOrder, Products, Characteristic) IN
	|					(SELECT
	|						TemporaryTableInventory.Company AS Company,
	|						VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|						CASE
	|							WHEN TemporaryTableInventory.SalesOrder = UNDEFINED
	|								THEN VALUE(Document.SalesOrder.EmptyRef)
	|							ELSE TemporaryTableInventory.SalesOrder
	|						END AS SalesOrder,
	|						TemporaryTableInventory.Products AS Products,
	|						TemporaryTableInventory.Characteristic AS Characteristic
	|					FROM
	|						TemporaryTableInventory AS TemporaryTableInventory)) AS InventoryDemandBalances
	|	
	|	GROUP BY
	|		InventoryDemandBalances.Company,
	|		InventoryDemandBalances.SalesOrder,
	|		InventoryDemandBalances.Products,
	|		InventoryDemandBalances.Characteristic
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryDemand.Company,
	|		DocumentRegisterRecordsInventoryDemand.SalesOrder,
	|		DocumentRegisterRecordsInventoryDemand.Products,
	|		DocumentRegisterRecordsInventoryDemand.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryDemand.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryDemand.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.InventoryDemand AS DocumentRegisterRecordsInventoryDemand
	|	WHERE
	|		DocumentRegisterRecordsInventoryDemand.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventoryDemand.Period <= &ControlPeriod) AS InventoryDemandBalances
	|
	|GROUP BY
	|	InventoryDemandBalances.Company,
	|	InventoryDemandBalances.SalesOrder,
	|	InventoryDemandBalances.Products,
	|	InventoryDemandBalances.Characteristic";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	
	If ValueIsFilled(DocumentRefProduction.SalesOrder) Then
		Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Else
		Query.SetParameter("ControlTime", New Boundary(StructureAdditionalProperties.ForPosting.PointInTime, BoundaryType.Including));
	EndIf;
	
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();
	
	TableInventoryDemandBalance = QueryResult.Unload();
	TableInventoryDemandBalance.Indexes.Add("Company,SalesOrder,Products,Characteristic");
	
	TemporaryTableInventoryDemand = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand.CopyColumns();
	
	For Each RowTablesForInventory In StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Company", 		RowTablesForInventory.Company);
		StructureForSearch.Insert("SalesOrder", 	?(RowTablesForInventory.SalesOrder = Undefined, Documents.SalesOrder.EmptyRef(), RowTablesForInventory.SalesOrder));
		StructureForSearch.Insert("Products", 	RowTablesForInventory.Products);
		StructureForSearch.Insert("Characteristic", 	RowTablesForInventory.Characteristic);
		
		BalanceRowsArray = TableInventoryDemandBalance.FindRows(StructureForSearch);
		If BalanceRowsArray.Count() > 0 AND BalanceRowsArray[0].QuantityBalance > 0 Then
			
			If RowTablesForInventory.Quantity > BalanceRowsArray[0].QuantityBalance Then
				RowTablesForInventory.Quantity = BalanceRowsArray[0].QuantityBalance;
			EndIf;
			
			TableRowExpense = TemporaryTableInventoryDemand.Add();
			FillPropertyValues(TableRowExpense, RowTablesForInventory);
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.TableInventoryDemand = TemporaryTableInventoryDemand;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateRawMaterialsConsumptionTableDisassembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.BatchStatus AS BatchStatus,
	|	TableProduction.Specification AS Specification,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.InventoryGLAccount AS InventoryGLAccount,
	|	TableProduction.AccountCr AS AccountCr,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Reserve AS Reserve
	|INTO TemporaryTableVT
	|FROM
	|	&TableProduction AS TableProduction
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProductsContent.Products AS Products,
	|	TableProductsContent.Characteristic AS Characteristic,
	|	TableProductsContent.Batch AS Batch,
	|	TableProductsContent.BatchStatus AS BatchStatus,
	|	TableProductsContent.Specification AS Specification,
	|	TableProductsContent.GLAccount AS GLAccount,
	|	TableProductsContent.InventoryGLAccount AS InventoryGLAccount,
	|	TableProductsContent.AccountCr AS AccountCr,
	|	TableProductsContent.Quantity AS Quantity,
	|	TableProductsContent.Reserve AS Reserve,
	|	TableMaterials.ContentRowType AS TMContentRowType,
	|	1 AS CorrQuantity,
	|	1 AS TMQuantity,
	|	TableMaterials.Products AS TMProducts,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS TMCharacteristic,
	|	TableMaterials.Specification AS TMSpecification
	|FROM
	|	TemporaryTableVT AS TableProductsContent
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProductsContent.Specification = TableMaterials.Ref
	|			AND (TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.Ref.Date AS Period,
	|	ProductionInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit = ProductionInventory.Ref.InventoryStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionInventory.Ref.InventoryStructuralUnit
	|	END AS InventoryStructuralUnit,
	|	ProductionInventory.Ref.InventoryStructuralUnit AS StructuralUnitInventoryToWarehouse,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit = ProductionInventory.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionInventory.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.CellInventory
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS CellInventory,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS GLAccount,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS InventoryGLAccount,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS CorrGLAccount,
	|	CASE
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|		AND ProductionInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS ProductsGLAccount,
	|	VALUE(Catalog.Products.EmptyRef) AS Products,
	|	ProductionInventory.Products AS ProductsCorr,
	|	VALUE(Catalog.ProductsCharacteristics.EmptyRef) AS Characteristic,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS CharacteristicCorr,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch,
	|	VALUE(Enum.BatchStatuses.EmptyRef) AS BatchStatus,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS BatchCorr,
	|	VALUE(Catalog.BillsOfMaterials.EmptyRef) AS Specification,
	|	ProductionInventory.Specification AS SpecificationCorr,
	|	CASE
	|		WHEN ProductionInventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.Ref.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.Ref.SalesOrder
	|	END AS SalesOrder,
	|	0 AS Quantity,
	|	0 AS Reserve,
	|	0 AS Amount,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS ProductsAccountDr,
	|	VALUE(ChartOfAccounts.PrimaryChartOfAccounts.EmptyRef) AS AccountCr,
	|	CASE
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|		AND ProductionInventory.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionInventory.InventoryReceivedGLAccount
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS ProductsAccountCr,
	|	ProductionInventory.CostPercentage AS CostPercentage,
	|	FALSE AS NewRow,
	|	FALSE AS AccountExecuted,
	|	FALSE AS Distributed
	|FROM
	|	Document.Production.Inventory AS ProductionInventory
	|WHERE
	|	ProductionInventory.Ref = &Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("TableProduction",		TableProduction);
	Query.SetParameter("Ref",					DocumentRefProduction);
	Query.SetParameter("UseCharacteristics",	StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",			StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins",		StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	
	ResultsArray = Query.ExecuteBatch();
	
	TableProductsContent	= ResultsArray[1].Unload();
	MaterialsTable			= ResultsArray[2].Unload();
	
	Ind = 0;
	While Ind < TableProductsContent.Count() Do
		ProductsRow = TableProductsContent[Ind];
		If ProductsRow.TMContentRowType = Enums.BOMLineType.Node Then
			NodesBillsOfMaterialstack = New Array();
			FillProductsTableByNodsStructure(ProductsRow, TableProductsContent, NodesBillsOfMaterialstack);
			TableProductsContent.Delete(ProductsRow);
		Else
			Ind = Ind + 1;
		EndIf;
	EndDo;
	
	TableProductsContent.GroupBy("Products, Characteristic ,Batch, BatchStatus, Specification, GLAccount,
		|InventoryGLAccount, AccountCr, Quantity, Reserve, TMProducts, TMCharacteristic");
	TableProductsContent.Indexes.Add("Products, Characteristic, Batch, Specification");
	
	MaterialsTable.Indexes.Add("ProductsCorr,CharacteristicCorr");
	
	DistributedProducts	= 0;
	MaterialsAmount		= MaterialsTable.Count();
	ProductsQuantity	= TableProductsContent.Count();
	
	For Each StringProducts In TableProduction Do
		
		SearchStructureProducts = New Structure;
		SearchStructureProducts.Insert("Products",	StringProducts.Products);
		SearchStructureProducts.Insert("Characteristic",		StringProducts.Characteristic);
		SearchStructureProducts.Insert("Batch",					StringProducts.Batch);
		SearchStructureProducts.Insert("Specification",			StringProducts.Specification);
		
		BaseCostPercentage = 0;
		SearchResultProducts = TableProductsContent.FindRows(SearchStructureProducts);
		For Each RowSearchProducts In SearchResultProducts Do
			
			SearchStructureMaterials = New Structure;
			SearchStructureMaterials.Insert("NewRow", False);
			SearchStructureMaterials.Insert("ProductsCorr", RowSearchProducts.TMProducts);
			SearchStructureMaterials.Insert("CharacteristicCorr", RowSearchProducts.TMCharacteristic);
			
			SearchResultMaterials		= MaterialsTable.FindRows(SearchStructureMaterials);
			QuantityContentMaterials	= SearchResultMaterials.Count();
			
			For Each RowSearchMaterials In SearchResultMaterials Do
				StringProducts.Distributed			= True;
				RowSearchMaterials.Distributed		= True;
				RowSearchMaterials.AccountExecuted	= True;
				BaseCostPercentage					= BaseCostPercentage + RowSearchMaterials.CostPercentage;
			EndDo;
			
		EndDo;
		
		If BaseCostPercentage > 0 Then
			DistributeProductsAccordingToNorms(StringProducts, MaterialsTable, BaseCostPercentage);
		EndIf;
		
		If StringProducts.Distributed Then
			DistributedProducts = DistributedProducts + 1;
		EndIf;
		
	EndDo;
	
	DistributedMaterials = 0;
	For Each StringMaterials In MaterialsTable Do
		If StringMaterials.Distributed AND Not StringMaterials.NewRow Then
			DistributedMaterials = DistributedMaterials + 1;
		EndIf;
	EndDo;
	
	If DistributedProducts < TableProduction.Count() Then
		If DistributedMaterials = MaterialsAmount Then
			BaseCostPercentage = MaterialsTable.Total("CostPercentage");
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable, BaseCostPercentage, False);
		Else
			DistributeProductsAccordingToQuantity(TableProduction, MaterialsTable);
		EndIf;
	EndIf;
	
	TableProduction			= Undefined;
	TableProductsContent	= Undefined;
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableOfRawMaterialsConsumptionDisassembling", MaterialsTable);
	MaterialsTable = Undefined;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure DataInitializationByInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount) Export

	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text =
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Period AS Period,
	|	&Company AS Company,
	|	VALUE(Catalog.PlanningPeriods.Actual) AS PlanningPeriod,
	|	ProductionInventory.StructuralUnit AS StructuralUnit,
	|	ProductionInventory.Cell AS Cell,
	|	ProductionInventory.InventoryStructuralUnit AS InventoryStructuralUnit,
	|	ProductionInventory.StructuralUnitInventoryToWarehouse AS StructuralUnitInventoryToWarehouse,
	|	ProductionInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	ProductionInventory.CellInventory AS CellInventory,
	|	ProductionInventory.GLAccount AS GLAccount,
	|	ProductionInventory.InventoryGLAccount AS InventoryGLAccount,
	|	ProductionInventory.CorrGLAccount AS CorrGLAccount,
	|	ProductionInventory.ProductsGLAccount AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	ProductionInventory.ProductsCorr AS ProductsCorr,
	|	ProductionInventory.Characteristic AS Characteristic,
	|	ProductionInventory.CharacteristicCorr AS CharacteristicCorr,
	|	ProductionInventory.Batch AS Batch,
	|	ProductionInventory.BatchStatus AS BatchStatus,
	|	ProductionInventory.BatchCorr AS BatchCorr,
	|	ProductionInventory.Specification AS Specification,
	|	ProductionInventory.SpecificationCorr AS SpecificationCorr,
	|	ProductionInventory.SalesOrder AS SalesOrder,
	|	ProductionInventory.Quantity AS Quantity,
	|	ProductionInventory.Reserve AS Reserve,
	|	0 AS Amount,
	|	ProductionInventory.AccountDr AS AccountDr,
	|	ProductionInventory.ProductsAccountDr AS ProductsAccountDr,
	|	ProductionInventory.AccountCr AS AccountCr,
	|	ProductionInventory.ProductsAccountCr AS ProductsAccountCr,
	|	ProductionInventory.CostPercentage AS CostPercentage,
	|	CAST(&InventoryDistribution AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&InventoryDistribution AS STRING(100)) AS Content
	|INTO TemporaryTableInventory
	|FROM
	|	&TableOfRawMaterialsConsumptionDisassembling AS ProductionInventory
	|WHERE
	|	ProductionInventory.Products <> VALUE(Catalog.Products.EmptyRef)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.PlanningPeriod AS PlanningPeriod,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnit AS StructuralUnitCorr,
	|	TableInventory.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableInventory.GLAccount AS GLAccount,
	|	TableInventory.CorrGLAccount AS CorrGLAccount,
	|	TableInventory.ProductsGLAccount AS ProductsGLAccount,
	|	TableInventory.Products AS Products,
	|	TableInventory.ProductsCorr AS ProductsCorr,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.CharacteristicCorr AS CharacteristicCorr,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.BatchCorr AS BatchCorr,
	|	TableInventory.Specification AS Specification,
	|	TableInventory.SpecificationCorr AS SpecificationCorr,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.SalesOrder AS CustomerCorrOrder,
	|	TableInventory.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableInventory.Quantity) AS Quantity,
	|	SUM(TableInventory.Reserve) AS Reserve,
	|	0 AS Amount,
	|	TableInventory.AccountDr AS AccountDr,
	|	TableInventory.AccountCr AS AccountCr,
	|	TableInventory.ProductsAccountDr AS ProductsAccountDr,
	|	TableInventory.ProductsAccountCr AS ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord AS Content,
	|	TableInventory.CostPercentage AS CostPercentage
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.PlanningPeriod,
	|	TableInventory.StructuralUnit,
	|	TableInventory.ProductsStructuralUnit,
	|	TableInventory.GLAccount,
	|	TableInventory.CorrGLAccount,
	|	TableInventory.ProductsGLAccount,
	|	TableInventory.Products,
	|	TableInventory.ProductsCorr,
	|	TableInventory.Characteristic,
	|	TableInventory.CharacteristicCorr,
	|	TableInventory.Batch,
	|	TableInventory.BatchCorr,
	|	TableInventory.Specification,
	|	TableInventory.SpecificationCorr,
	|	TableInventory.SalesOrder,
	|	TableInventory.AccountDr,
	|	TableInventory.AccountCr,
	|	TableInventory.ProductsAccountDr,
	|	TableInventory.ProductsAccountCr,
	|	TableInventory.ContentOfAccountingRecord,
	|	TableInventory.CostPercentage,
	|	TableInventory.StructuralUnit,
	|	TableInventory.SalesOrder,
	|	TableInventory.ContentOfAccountingRecord
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableInventory.Company AS Company,
	|	TableInventory.StructuralUnit AS StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse AS InventoryStructuralUnit,
	|	TableInventory.CellInventory AS CellInventory,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.Cell AS Cell,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.StructuralUnit,
	|	TableInventory.StructuralUnitInventoryToWarehouse,
	|	TableInventory.CellInventory,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Cell
	|
	|ORDER BY
	|	LineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableInventory.Company AS Company,
	|	TableInventory.Period AS Period,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	TableInventory.SalesOrder AS Order,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|WHERE
	|	TableInventory.BatchStatus = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|
	|GROUP BY
	|	TableInventory.Company,
	|	TableInventory.Period,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.SalesOrder
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableInventory.LineNumber) AS LineNumber,
	|	TableInventory.Period AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	VALUE(Enum.InventoryMovementTypes.Shipment) AS MovementType,
	|	TableInventory.Company AS Company,
	|	TableInventory.SalesOrder AS SalesOrder,
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	SUM(TableInventory.Quantity) AS Quantity
	|FROM
	|	TemporaryTableInventory AS TableInventory
	|
	|GROUP BY
	|	TableInventory.Period,
	|	TableInventory.Company,
	|	TableInventory.SalesOrder,
	|	TableInventory.Products,
	|	TableInventory.Characteristic
	|
	|ORDER BY
	|	LineNumber";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("TableOfRawMaterialsConsumptionDisassembling", StructureAdditionalProperties.TableForRegisterRecords.TableOfRawMaterialsConsumptionDisassembling);
	Query.SetParameter("InventoryDistribution", NStr("en = 'Inventory allocation'", MainLanguageCode));
	Query.SetParameter("InventoryTransfer", NStr("en = 'Inventory transfer'", MainLanguageCode));
	
	ResultsArray = Query.ExecuteBatch();
	
	// Determine table for inventory accounting.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInventory", ResultsArray[1].Unload());
	
	// Generate table for inventory accounting.
	If ValueIsFilled(DocumentRefProduction.InventoryStructuralUnit) 
		AND DocumentRefProduction.InventoryStructuralUnit <> DocumentRefProduction.StructuralUnit Then
		
		// Inventory autotransfer.
		GenerateTableInventoryInventoryDisassemblyTransfer(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
		
	Else
		
		GenerateTableInventoryInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
		
	EndIf;
	
	// Expand table for inventory.
	ResultsSelection = ResultsArray[2].Select();
	While ResultsSelection.Next() Do
		
		// Inventory autotransfer.
		If (ResultsSelection.InventoryStructuralUnit = ResultsSelection.StructuralUnit
			AND ResultsSelection.CellInventory <> ResultsSelection.Cell)
			OR ResultsSelection.InventoryStructuralUnit <> ResultsSelection.StructuralUnit Then
			
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
			FillPropertyValues(TableRowExpense, ResultsSelection);
			
			TableRowExpense.StructuralUnit = ResultsSelection.InventoryStructuralUnit;
			TableRowExpense.Cell = ResultsSelection.CellInventory;
			
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
			FillPropertyValues(TableRowReceipt, ResultsSelection);
			
			TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
			
		EndIf;
		
		TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
		FillPropertyValues(TableRowExpense, ResultsSelection);
		
	EndDo;
	
	// Determine a table of consumed raw material accepted for processing for which you will have to report in the future.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableStockReceivedFromThirdParties", ResultsArray[3].Unload());
	
	// Determine table for movement by the needs of dependent demand positions.
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryDemand", ResultsArray[4].Unload());
	GenerateTableInventoryDemandDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableInventoryProductsDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount)
	
	StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.Indexes.Add("RecordType,Company,Products,Characteristic");;
	StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Indexes.Add("RecordType,Company,Products,Characteristic,Batch,ProductsCorr,CharacteristicCorr,BatchCorr,ProductionExpenses");;
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.Count() - 1 Do
		
		RowTableInventoryProducts = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods[n];
		
		// Generate products release in terms of quantity. If sales order is specified - customer
		// customised if not - then for an empty order.
		TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
		FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
		
		// Products autotransfer.
		GLAccountTransferring = Undefined;
		If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
			
			// Expense.
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			TableRowExpense.Specification = Undefined;
			
			TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowExpense.CorrGLAccount = RowTableInventoryProducts.ProductsGLAccount;
			
			TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
			TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowExpense.SpecificationCorr = Undefined;
			TableRowExpense.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
			
			TableRowExpense.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
			TableRowExpense.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
			
			// Receipt.
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
			
			TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
			TableRowReceipt.GLAccount = RowTableInventoryProducts.ProductsGLAccount;
			TableRowReceipt.Specification = Undefined;
			
			GLAccountTransferring = TableRowReceipt.GLAccount;
			
			TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
			TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
			
			TableRowReceipt.ProductsCorr = RowTableInventoryProducts.Products;
			TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
			TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
			TableRowReceipt.SpecificationCorr = Undefined;
			TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
			
			TableRowReceipt.ContentOfAccountingRecord = NStr("en = 'Inventory transfer'", MainLanguageCode);
			TableRowReceipt.Content = NStr("en = 'Inventory transfer'", MainLanguageCode);
			
		EndIf;
		
		// If the production order is filled in and there is no
		// sales order, then check whether there are placed customers orders in the production order.
		If Not ValueIsFilled(RowTableInventoryProducts.SalesOrder)
			AND ValueIsFilled(RowTableInventoryProducts.ProductionOrder) Then
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Expense);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			
			IndexOf = 0;
			OutputQuantity = RowTableInventoryProducts.Quantity;
			ArrayPropertiesProducts = StructureAdditionalProperties.TableForRegisterRecords.TableBackorders.FindRows(StructureForSearch);
			
			If ArrayPropertiesProducts.Count() = 0 Then
				Continue;
			EndIf;
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("RecordType", AccumulationRecordType.Receipt);
			StructureForSearch.Insert("Company", RowTableInventoryProducts.Company);
			StructureForSearch.Insert("Products", RowTableInventoryProducts.Products);
			StructureForSearch.Insert("Characteristic", RowTableInventoryProducts.Characteristic);
			StructureForSearch.Insert("Batch", RowTableInventoryProducts.Batch);
			StructureForSearch.Insert("ProductionExpenses", False);
			
			If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
				StructureForSearch.Insert("ProductsCorr", RowTableInventoryProducts.Products);
				StructureForSearch.Insert("CharacteristicCorr", RowTableInventoryProducts.Characteristic);
				StructureForSearch.Insert("BatchCorr", RowTableInventoryProducts.Batch);
			EndIf;
			
			OutputCost = 0;
			ArrayCostOutputs = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.FindRows(StructureForSearch);
			For Each OutputRow In ArrayCostOutputs Do
				OutputCost = OutputCost + OutputRow.Amount;
			EndDo;
			
			For Each StringAllocationArray In ArrayPropertiesProducts Do
				
				OutputAmountToReserve = StringAllocationArray.Quantity;
				
				If OutputQuantity = OutputAmountToReserve Then
					OutputCostInReserve = OutputCost;
				Else
					OutputCostInReserve = Round(OutputCost * OutputAmountToReserve / OutputQuantity, 2, 1);
				EndIf;
				
				If OutputAmountToReserve > 0 Then
				
					TotalAmountToWriteOffByOrder = 0;
					
					AmountToBeWrittenOffByOrder = Round(OutputCostInReserve * StringAllocationArray.Quantity / OutputAmountToReserve, 2, 1);
					TotalAmountToWriteOffByOrder = TotalAmountToWriteOffByOrder + AmountToBeWrittenOffByOrder;
					
					If IndexOf = ArrayPropertiesProducts.Count() - 1 Then // It is the last string, it is required to correct amount.
						AmountToBeWrittenOffByOrder = AmountToBeWrittenOffByOrder + (OutputCostInReserve - TotalAmountToWriteOffByOrder);
					EndIf;
					
					TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowExpense, RowTableInventoryProducts);
					
					TableRowExpense.RecordType = AccumulationRecordType.Expense;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowExpense.GLAccount = GLAccountTransferring;
						TableRowExpense.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowExpense.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowExpense.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowExpense.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowExpense.ProductsCorr = RowTableInventoryProducts.Products;
					TableRowExpense.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowExpense.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowExpense.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowExpense.CustomerCorrOrder = StringAllocationArray.SalesOrder;
					TableRowExpense.Quantity = StringAllocationArray.Quantity;
					TableRowExpense.Amount = AmountToBeWrittenOffByOrder;
					
					TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventory.Add();
					FillPropertyValues(TableRowReceipt, RowTableInventoryProducts);
					
					TableRowReceipt.RecordType = AccumulationRecordType.Receipt;
					
					TableRowReceipt.SalesOrder = StringAllocationArray.SalesOrder;
					
					If ValueIsFilled(RowTableInventoryProducts.ProductsStructuralUnit) Then
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.ProductsStructuralUnit;
						TableRowReceipt.GLAccount = GLAccountTransferring;
						TableRowReceipt.CorrGLAccount = GLAccountTransferring;
					Else
						TableRowReceipt.StructuralUnit = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.StructuralUnitCorr = RowTableInventoryProducts.StructuralUnit;
						TableRowReceipt.GLAccount = RowTableInventoryProducts.GLAccount;
						TableRowReceipt.CorrGLAccount = RowTableInventoryProducts.GLAccount;
					EndIf;
					TableRowReceipt.ProductsCorr = RowTableInventoryProducts.Products;
					TableRowReceipt.CharacteristicCorr = RowTableInventoryProducts.Characteristic;
					TableRowReceipt.BatchCorr = RowTableInventoryProducts.Batch;
					TableRowReceipt.SpecificationCorr = RowTableInventoryProducts.Specification;
					TableRowReceipt.CustomerCorrOrder = RowTableInventoryProducts.SalesOrder;
					TableRowReceipt.Quantity = StringAllocationArray.Quantity;
					TableRowReceipt.Amount = AmountToBeWrittenOffByOrder;
					
					IndexOf = IndexOf + 1;
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndDo;
	
	StructureAdditionalProperties.TableForRegisterRecords.Delete("TableInventoryGoods");
	TableProductsAllocation = Undefined;
	
EndProcedure

// Generates a table of values that contains the data for the register.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure GenerateTableBackordersDisassembly(DocumentRefProduction, StructureAdditionalProperties)
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	
	// Set exclusive lock of the controlled orders placement.
	Query.Text = 
	"SELECT
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|
	|GROUP BY
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.SupplySource";
	
	QueryResult = Query.Execute();
	
	Block = New DataLock;
	LockItem = Block.Add("AccumulationRegister.Backorders");
	LockItem.Mode = DataLockMode.Exclusive;
	LockItem.DataSource = QueryResult;

	For Each ColumnQueryResult In QueryResult.Columns Do
		LockItem.UseFromDataSource(ColumnQueryResult.Name, ColumnQueryResult.Name);
	EndDo;
	Block.Lock();
	
	// Receive balance.
	Query.Text = 	
	"SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	BackordersBalances.SalesOrder AS SalesOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.SupplySource AS SupplySource,
	|	CASE
	|		WHEN TableProduction.Quantity > ISNULL(BackordersBalances.Quantity, 0)
	|			THEN ISNULL(BackordersBalances.Quantity, 0)
	|		WHEN TableProduction.Quantity <= ISNULL(BackordersBalances.Quantity, 0)
	|			THEN TableProduction.Quantity
	|	END AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN (SELECT
	|			BackordersBalances.Company AS Company,
	|			BackordersBalances.Products AS Products,
	|			BackordersBalances.Characteristic AS Characteristic,
	|			BackordersBalances.SalesOrder AS SalesOrder,
	|			BackordersBalances.SupplySource AS SupplySource,
	|			SUM(BackordersBalances.QuantityBalance) AS Quantity
	|		FROM
	|			(SELECT
	|				BackordersBalances.Company AS Company,
	|				BackordersBalances.Products AS Products,
	|				BackordersBalances.Characteristic AS Characteristic,
	|				BackordersBalances.SalesOrder AS SalesOrder,
	|				BackordersBalances.SupplySource AS SupplySource,
	|				BackordersBalances.QuantityBalance AS QuantityBalance
	|			FROM
	|				AccumulationRegister.Backorders.Balance(
	|						&ControlTime,
	|						(Company, Products, Characteristic, SupplySource) In
	|							(SELECT
	|								TableProduction.Company AS Company,
	|								TableProduction.Products AS Products,
	|								TableProduction.Characteristic AS Characteristic,
	|								TableProduction.SupplySource AS SupplySource
	|							FROM
	|								TemporaryTableProduction AS TableProduction
	|							WHERE
	|								TableProduction.SupplySource <> UNDEFINED)) AS BackordersBalances
			
	|			UNION ALL
			
	|			SELECT
	|				DocumentRegisterRecordsBackorders.Company,
	|				DocumentRegisterRecordsBackorders.Products,
	|				DocumentRegisterRecordsBackorders.Characteristic,
	|				DocumentRegisterRecordsBackorders.SalesOrder,
	|				DocumentRegisterRecordsBackorders.SupplySource,
	|				CASE
	|					WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|						THEN ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|					ELSE -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|				END
	|			FROM
	|				AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|			WHERE
	|				DocumentRegisterRecordsBackorders.Recorder = &Ref
	|				AND DocumentRegisterRecordsBackorders.Period <= &ControlPeriod) AS BackordersBalances
		
	|		GROUP BY
	|			BackordersBalances.Company,
	|			BackordersBalances.Products,
	|			BackordersBalances.Characteristic,
	|			BackordersBalances.SalesOrder,
	|			BackordersBalances.SupplySource) AS BackordersBalances
	|		ON TableProduction.Company = BackordersBalances.Company
	|			AND TableProduction.Products = BackordersBalances.Products
	|			AND TableProduction.Characteristic = BackordersBalances.Characteristic
	|			AND TableProduction.SupplySource = BackordersBalances.SupplySource
	|WHERE
	|	TableProduction.SupplySource <> UNDEFINED
	|	AND BackordersBalances.SalesOrder IS Not NULL ";
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("ControlTime", StructureAdditionalProperties.ForPosting.ControlTime);
	Query.SetParameter("ControlPeriod", StructureAdditionalProperties.ForPosting.ControlPeriod);
	
	QueryResult = Query.Execute();

	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableBackorders", QueryResult.Unload());
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataAssembly(DocumentRefProduction, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionProducts.LineNumber AS LineNumber,
	|	ProductionProducts.Ref.Date AS Period,
	|	ProductionProducts.ConnectionKey AS ConnectionKey,
	|	ProductionProducts.Ref AS Ref,
	|	&Company AS Company,
	|	ProductionProducts.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionProducts.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN ProductionProducts.Ref.StructuralUnit = ProductionProducts.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionProducts.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	ProductionProducts.Ref.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionProducts.Ref.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	ProductionProducts.Specification AS Specification,
	|	CASE
	|		WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE ProductionProducts.ConsumptionGLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN ProductionProducts.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE ProductionProducts.ConsumptionGLAccount
	|	END AS ProductsGLAccount,
	|	CASE
	|		WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE ProductionProducts.ConsumptionGLAccount
	|	END AS AccountDr,
	|	CASE
	|		WHEN ProductionProducts.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE ProductionProducts.ConsumptionGLAccount
	|	END AS ProductsAccountDr,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END AS ProductsAccountCr,
	|	CASE
	|		WHEN ProductionProducts.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionProducts.Ref.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionProducts.Ref.SalesOrder
	|	END AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	ProductionProducts.Ref.BasisDocument AS ProductionOrder,
	|	CASE
	|		WHEN ProductionProducts.Ref.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionProducts.Ref.BasisDocument
	|	END AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(ProductionProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionProducts.Quantity
	|		ELSE ProductionProducts.Quantity * ProductionProducts.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&Production AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&Production AS STRING(100)) AS Content
	|INTO TemporaryTableProduction
	|FROM
	|	Document.Production.Products AS ProductionProducts
	|WHERE
	|	ProductionProducts.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableProduction.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification,
	|	TableProduction.SalesOrder,
	|	TableProduction.ProductionOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Cell AS Cell,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS ProductsStructuralUnit,
	|	TableProduction.ProductsCell AS ProductsCell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.SalesOrder,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.Products,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS CorrLineNumber,
	|	TableProduction.Products AS ProductsCorr,
	|	TableProduction.Characteristic AS CharacteristicCorr,
	|	TableProduction.Batch AS BatchCorr,
	|	TableProduction.Specification AS SpecificationCorr,
	|	TableProduction.GLAccount AS CorrGLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	TableProduction.AccountDr AS AccountDr,
	|	TableProduction.ProductsAccountDr AS ProductsAccountDr,
	|	TableProduction.ProductsAccountCr AS ProductsAccountCr,
	|	SUM(TableProduction.Quantity) AS CorrQuantity,
	|	FALSE AS Distributed
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.AccountDr,
	|	TableProduction.ProductsAccountDr,
	|	TableProduction.ProductsAccountCr
	|
	|ORDER BY
	|	CorrLineNumber
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbersProducts.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Production.SerialNumbersProducts AS TableSerialNumbersProducts
	|		ON TableProduction.Ref = TableSerialNumbersProducts.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbersProducts.ConnectionKey
	|WHERE
	|	TableSerialNumbersProducts.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.Ref.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventory.Ref.Date,
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ref.InventoryStructuralUnit,
	|	TableInventory.Ref.CellInventory,
	|	1
	|FROM
	|	Document.Production.Inventory AS TableInventory
	|		INNER JOIN Document.Production.SerialNumbers AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches",  StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseOperationsManagement", StructureAdditionalProperties.AccountingPolicy.UseOperationsManagement);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.SetParameter("Production", NStr("en = 'Production'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", ResultsArray[4].Unload());
	
	// Products autotransfer (expand the TableInventoryInWarehouses table).
	For n = 0 To StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Count() - 1 Do
		
		RowTableInventoryInWarehouses = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses[n];
		
		If (RowTableInventoryInWarehouses.ProductsStructuralUnit = RowTableInventoryInWarehouses.StructuralUnit
			AND RowTableInventoryInWarehouses.ProductsCell <> RowTableInventoryInWarehouses.Cell)
			OR RowTableInventoryInWarehouses.ProductsStructuralUnit <> RowTableInventoryInWarehouses.StructuralUnit Then
			
			TableRowExpense = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
			FillPropertyValues(TableRowExpense, RowTableInventoryInWarehouses);
			
			TableRowExpense.RecordType = AccumulationRecordType.Expense;
			
			TableRowReceipt = StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Add();
			FillPropertyValues(TableRowReceipt, RowTableInventoryInWarehouses);
			
			TableRowReceipt.StructuralUnit = RowTableInventoryInWarehouses.ProductsStructuralUnit;
			TableRowReceipt.Cell = RowTableInventoryInWarehouses.ProductsCell;
			
		EndIf;
		
	EndDo;
	
	// Generate documents posting table structure.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackordersAssembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate materials allocation table.
	TableProduction = ResultsArray[7].Unload();
	GenerateRawMaterialsConsumptionTableAssembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByProduction(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Products.
	GenerateTableInventoryProductsAssembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	
	// Serial numbers
	QueryResult8 = ResultsArray[8].Unload();
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult8);
	If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult8);
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentDataDisassembly(DocumentRefProduction, StructureAdditionalProperties) Export
	
	Query = New Query;
	Query.TempTablesManager = StructureAdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager;
	Query.Text = 
	"SELECT
	|	ProductionInventory.LineNumber AS LineNumber,
	|	ProductionInventory.Ref.Date AS Period,
	|	ProductionInventory.Ref AS Ref,
	|	ProductionInventory.ConnectionKey AS ConnectionKey,
	|	&Company AS Company,
	|	ProductionInventory.Ref.StructuralUnit AS StructuralUnit,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.Cell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS Cell,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit = ProductionInventory.Ref.ProductsStructuralUnit
	|			THEN VALUE(Catalog.BusinessUnits.EmptyRef)
	|		ELSE ProductionInventory.Ref.ProductsStructuralUnit
	|	END AS ProductsStructuralUnit,
	|	ProductionInventory.Ref.ProductsStructuralUnit AS ProductsStructuralUnitToWarehouse,
	|	CASE
	|		WHEN &UseStorageBins
	|			THEN ProductionInventory.Ref.ProductsCell
	|		ELSE VALUE(Catalog.Cells.EmptyRef)
	|	END AS ProductsCell,
	|	ProductionInventory.Specification AS Specification,
	|	CASE
	|		WHEN ProductionInventory.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS GLAccount,
	|	CASE
	|		WHEN ProductionInventory.Ref.ProductsStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|			THEN ProductionInventory.InventoryGLAccount
	|		ELSE ProductionInventory.ConsumptionGLAccount
	|	END AS ProductsGLAccount,
	|	ProductionInventory.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionInventory.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionInventory.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN ProductionInventory.Ref.SalesOrder = VALUE(Document.SalesOrder.EmptyRef)
	|				OR ProductionInventory.Ref.SalesOrder = VALUE(Document.WorkOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.Ref.SalesOrder
	|	END AS SalesOrder,
	|	UNDEFINED AS CustomerCorrOrder,
	|	ProductionInventory.Ref.BasisDocument AS ProductionOrder,
	|	CASE
	|		WHEN ProductionInventory.Ref.BasisDocument = VALUE(Document.ProductionOrder.EmptyRef)
	|			THEN UNDEFINED
	|		ELSE ProductionInventory.Ref.BasisDocument
	|	END AS SupplySource,
	|	CASE
	|		WHEN VALUETYPE(ProductionInventory.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|			THEN ProductionInventory.Quantity
	|		ELSE ProductionInventory.Quantity * ProductionInventory.MeasurementUnit.Factor
	|	END AS Quantity,
	|	0 AS Amount,
	|	CAST(&Production AS STRING(100)) AS ContentOfAccountingRecord,
	|	CAST(&Production AS STRING(100)) AS Content
	|INTO TemporaryTableProduction
	|FROM
	|	Document.Production.Inventory AS ProductionInventory
	|WHERE
	|	ProductionInventory.Ref = &Ref
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(TableProduction.LineNumber) AS LineNumber,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.Company AS Company,
	|	UNDEFINED AS PlanningPeriod,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	UNDEFINED AS StructuralUnitCorr,
	|	TableProduction.ProductsStructuralUnit AS ProductsStructuralUnit,
	|	TableProduction.GLAccount AS GLAccount,
	|	TableProduction.ProductsGLAccount AS ProductsGLAccount,
	|	UNDEFINED AS CorrGLAccount,
	|	TableProduction.Products AS Products,
	|	UNDEFINED AS ProductsCorr,
	|	TableProduction.Characteristic AS Characteristic,
	|	UNDEFINED AS CharacteristicCorr,
	|	TableProduction.Batch AS Batch,
	|	UNDEFINED AS BatchCorr,
	|	TableProduction.Specification AS Specification,
	|	UNDEFINED AS SpecificationCorr,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.CustomerCorrOrder AS CustomerCorrOrder,
	|	UNDEFINED AS AccountDr,
	|	UNDEFINED AS AccountCr,
	|	UNDEFINED AS Content,
	|	TableProduction.ContentOfAccountingRecord AS ContentOfAccountingRecord,
	|	FALSE AS ProductionExpenses,
	|	SUM(TableProduction.Quantity) AS Quantity,
	|	SUM(TableProduction.Amount) AS Amount,
	|	FALSE AS FixedCost
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.ProductsStructuralUnit,
	|	TableProduction.GLAccount,
	|	TableProduction.ProductsGLAccount,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification,
	|	TableProduction.SalesOrder,
	|	TableProduction.ProductionOrder,
	|	TableProduction.CustomerCorrOrder,
	|	TableProduction.ContentOfAccountingRecord
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Cell AS Cell,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	&Company,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	(TableProduction.StructuralUnit <> TableProduction.ProductsStructuralUnitToWarehouse
	|			OR TableProduction.Cell <> TableProduction.ProductsCell)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Cell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt),
	|	TableProduction.Period,
	|	&Company,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	(TableProduction.StructuralUnit <> TableProduction.ProductsStructuralUnitToWarehouse
	|			OR TableProduction.Cell <> TableProduction.ProductsCell)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.ProductsCell,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.SalesOrder AS SalesOrder,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.Specification AS Specification,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.SalesOrder,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	TableProduction.Specification
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	&Company AS Company,
	|	TableProduction.ProductionOrder AS ProductionOrder,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductionOrder <> VALUE(Document.ProductionOrder.EmptyRef)
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductionOrder,
	|	TableProduction.Products,
	|	TableProduction.Characteristic
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch,
	|	SUM(TableProduction.Quantity)
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.ProductsStructuralUnitToWarehouse,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS Period,
	|	TableProduction.StructuralUnit AS StructuralUnit,
	|	TableProduction.Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	SUM(TableProduction.Quantity) AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|WHERE
	|	TableProduction.ProductsStructuralUnitToWarehouse <> TableProduction.StructuralUnit
	|
	|GROUP BY
	|	TableProduction.Period,
	|	TableProduction.StructuralUnit,
	|	TableProduction.Company,
	|	TableProduction.Products,
	|	TableProduction.Characteristic,
	|	TableProduction.Batch
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(ProductionProducts.LineNumber) AS LineNumber,
	|	ProductionProducts.Products AS Products,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END AS Batch,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch.Status
	|		ELSE VALUE(Enum.BatchStatuses.EmptyRef)
	|	END AS BatchStatus,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END AS GLAccount,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.InventoryStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END AS InventoryGLAccount,
	|	ProductionProducts.Specification AS Specification,
	|	SUM(CASE
	|			WHEN VALUETYPE(ProductionProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN ProductionProducts.Quantity
	|			ELSE ProductionProducts.Quantity * ProductionProducts.MeasurementUnit.Factor
	|		END) AS Quantity,
	|	SUM(CASE
	|			WHEN VALUETYPE(ProductionProducts.MeasurementUnit) = TYPE(Catalog.UOMClassifier)
	|				THEN ProductionProducts.Reserve
	|			ELSE ProductionProducts.Reserve * ProductionProducts.MeasurementUnit.Factor
	|		END) AS Reserve,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END AS AccountCr,
	|	FALSE AS Distributed
	|FROM
	|	Document.Production.Products AS ProductionProducts
	|WHERE
	|	ProductionProducts.Ref = &Ref
	|
	|GROUP BY
	|	ProductionProducts.Products,
	|	ProductionProducts.Specification,
	|	CASE
	|		WHEN &UseCharacteristics
	|			THEN ProductionProducts.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch
	|		ELSE VALUE(Catalog.ProductsBatches.EmptyRef)
	|	END,
	|	CASE
	|		WHEN &UseBatches
	|			THEN ProductionProducts.Batch.Status
	|		ELSE VALUE(Enum.BatchStatuses.EmptyRef)
	|	END,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.InventoryStructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END,
	|	CASE
	|		WHEN ProductionProducts.Batch.Status = VALUE(Enum.BatchStatuses.CounterpartysInventory)
	|			THEN ProductionProducts.InventoryGLAccount
	|		ELSE CASE
	|				WHEN ProductionProducts.Ref.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Warehouse)
	|					THEN ProductionProducts.InventoryGLAccount
	|				ELSE ProductionProducts.ConsumptionGLAccount
	|			END
	|	END
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TableProduction.Period AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	TableProduction.Period AS EventDate,
	|	VALUE(Enum.SerialNumbersOperations.Receipt) AS Operation,
	|	TableSerialNumbers.SerialNumber AS SerialNumber,
	|	&Company AS Company,
	|	TableProduction.Products AS Products,
	|	TableProduction.Characteristic AS Characteristic,
	|	TableProduction.Batch AS Batch,
	|	TableProduction.ProductsStructuralUnitToWarehouse AS StructuralUnit,
	|	TableProduction.ProductsCell AS Cell,
	|	1 AS Quantity
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		INNER JOIN Document.Production.SerialNumbers AS TableSerialNumbers
	|		ON TableProduction.Ref = TableSerialNumbers.Ref
	|			AND TableProduction.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableProduction.Ref = &Ref
	|	AND &UseSerialNumbers
	|
	|UNION ALL
	|
	|SELECT
	|	TableInventory.Ref.Date,
	|	VALUE(AccumulationRecordType.Expense),
	|	TableInventory.Ref.Date,
	|	VALUE(Enum.SerialNumbersOperations.Expense),
	|	TableSerialNumbers.SerialNumber,
	|	&Company,
	|	TableInventory.Products,
	|	TableInventory.Characteristic,
	|	TableInventory.Batch,
	|	TableInventory.Ref.InventoryStructuralUnit,
	|	TableInventory.Ref.CellInventory,
	|	1
	|FROM
	|	Document.Production.Products AS TableInventory
	|		INNER JOIN Document.Production.SerialNumbersProducts AS TableSerialNumbers
	|		ON TableInventory.Ref = TableSerialNumbers.Ref
	|			AND TableInventory.ConnectionKey = TableSerialNumbers.ConnectionKey
	|WHERE
	|	TableSerialNumbers.Ref = &Ref
	|	AND &UseSerialNumbers";
	
	MainLanguageCode = CommonUseClientServer.MainLanguageCode();
	
	Query.SetParameter("Ref", DocumentRefProduction);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	Query.SetParameter("UseCharacteristics", StructureAdditionalProperties.AccountingPolicy.UseCharacteristics);
	Query.SetParameter("UseBatches", StructureAdditionalProperties.AccountingPolicy.UseBatches);
	Query.SetParameter("UseStorageBins", StructureAdditionalProperties.AccountingPolicy.UseStorageBins);
	Query.SetParameter("UseOperationsManagement", StructureAdditionalProperties.AccountingPolicy.UseOperationsManagement);
	
	Query.SetParameter("UseSerialNumbers", StructureAdditionalProperties.AccountingPolicy.UseSerialNumbers);
	
	Query.SetParameter("Production", NStr("en = 'Production'", MainLanguageCode));

	ResultsArray = Query.ExecuteBatch();
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryGoods", ResultsArray[1].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventory", StructureAdditionalProperties.TableForRegisterRecords.TableInventoryGoods.CopyColumns());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableInventoryInWarehouses", ResultsArray[2].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductRelease", ResultsArray[3].Unload());
	StructureAdditionalProperties.TableForRegisterRecords.Insert("TableProductionOrders", ResultsArray[4].Unload());
	
	// Creation of document postings.
	DriveServer.GenerateTransactionsTable(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate table by orders placement.
	GenerateTableBackordersDisassembly(DocumentRefProduction, StructureAdditionalProperties);
	
	// Generate materials allocation table.
	TableProduction = ResultsArray[7].Unload();
	GenerateRawMaterialsConsumptionTableDisassembly(DocumentRefProduction, StructureAdditionalProperties, TableProduction);
	
	// Inventory.
	AssemblyAmount = 0;
	DataInitializationByInventoryDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Products.
	GenerateTableInventoryProductsDisassembly(DocumentRefProduction, StructureAdditionalProperties, AssemblyAmount);
	
	// Disposals.
	DataInitializationByDisposals(DocumentRefProduction, StructureAdditionalProperties);
	
	// Serial numbers
	If StructureAdditionalProperties.TableForRegisterRecords.TableInventoryInWarehouses.Count()>0 Then
		QueryResult8 = ResultsArray[8].Unload();
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", QueryResult8);
		If StructureAdditionalProperties.AccountingPolicy.SerialNumbersBalance Then
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", QueryResult8);
		Else
			StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
		EndIf;
	Else
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersInWarranty", New ValueTable);
		StructureAdditionalProperties.TableForRegisterRecords.Insert("TableSerialNumbersBalance", New ValueTable);
	EndIf;
	
EndProcedure

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentRefProduction, StructureAdditionalProperties) Export
	
	If DocumentRefProduction.OperationKind = Enums.OperationTypesProduction.Assembly Then
		
		InitializeDocumentDataAssembly(DocumentRefProduction, StructureAdditionalProperties)
		
	Else
		
		InitializeDocumentDataDisassembly(DocumentRefProduction, StructureAdditionalProperties)
		
	EndIf;	
	
EndProcedure

// Controls the occurrence of negative balances.
//
Procedure RunControl(DocumentRefProduction, AdditionalProperties, Cancel, PostingDelete = False) Export
	
	If Not DriveServer.RunBalanceControl() Then
		Return;
	EndIf;

	StructureTemporaryTables = AdditionalProperties.ForPosting.StructureTemporaryTables;
	
	// If the temporary
	// tables "RegisterRecordsProductionOrdersChange"
	// "RegisterRecordsBackordersChange" "RegisterRecordsInventoryChange" contain records, control goods implementation.
	
	If StructureTemporaryTables.RegisterRecordsProductionOrdersChange
		OR StructureTemporaryTables.RegisterRecordsBackordersChange
		OR StructureTemporaryTables.RegisterRecordsInventoryChange
		OR StructureTemporaryTables.RegisterRecordsInventoryInWarehousesChange
		OR StructureTemporaryTables.RegisterRecordsStockReceivedFromThirdPartiesChange
		OR StructureTemporaryTables.RegisterRecordsSerialNumbersChange Then
		
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
		|				(Company, StructuralUnit, Products, Characteristic, Batch, Cell) IN
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
		|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
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
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsStockReceivedFromThirdPartiesChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Batch) AS BatchPresentation,
		|	REFPRESENTATION(RegisterRecordsStockReceivedFromThirdPartiesChange.Order) AS OrderPresentation,
		|	REFPRESENTATION(StockReceivedFromThirdPartiesBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsStockReceivedFromThirdPartiesChange.QuantityChange, 0) + ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS BalanceStockReceivedFromThirdParties,
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) AS QuantityBalanceStockReceivedFromThirdParties
		|FROM
		|	RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange
		|		LEFT JOIN AccumulationRegister.StockReceivedFromThirdParties.Balance(
		|				&ControlTime,
		|				(Company, Products, Characteristic, Batch, Order) IN
		|					(SELECT
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Company AS Company,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Products AS Products,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic AS Characteristic,
		|						RegisterRecordsStockReceivedFromThirdPartiesChange.Batch AS Batch,
		|						UNDEFINED AS Order
		|					FROM
		|						RegisterRecordsStockReceivedFromThirdPartiesChange AS RegisterRecordsStockReceivedFromThirdPartiesChange)) AS StockReceivedFromThirdPartiesBalances
		|		ON RegisterRecordsStockReceivedFromThirdPartiesChange.Company = StockReceivedFromThirdPartiesBalances.Company
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Products = StockReceivedFromThirdPartiesBalances.Products
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Characteristic = StockReceivedFromThirdPartiesBalances.Characteristic
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Batch = StockReceivedFromThirdPartiesBalances.Batch
		|			AND RegisterRecordsStockReceivedFromThirdPartiesChange.Order = StockReceivedFromThirdPartiesBalances.Order
		|WHERE
		|	ISNULL(StockReceivedFromThirdPartiesBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsProductionOrdersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.ProductionOrder) AS ProductionOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsProductionOrdersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(ProductionOrdersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsProductionOrdersChange.QuantityChange, 0) + ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS BalanceProductionOrders,
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) AS QuantityBalanceProductionOrders
		|FROM
		|	RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange
		|		LEFT JOIN AccumulationRegister.ProductionOrders.Balance(
		|				&ControlTime,
		|				(Company, ProductionOrder, Products, Characteristic) IN
		|					(SELECT
		|						RegisterRecordsProductionOrdersChange.Company AS Company,
		|						RegisterRecordsProductionOrdersChange.ProductionOrder AS ProductionOrder,
		|						RegisterRecordsProductionOrdersChange.Products AS Products,
		|						RegisterRecordsProductionOrdersChange.Characteristic AS Characteristic
		|					FROM
		|						RegisterRecordsProductionOrdersChange AS RegisterRecordsProductionOrdersChange)) AS ProductionOrdersBalances
		|		ON RegisterRecordsProductionOrdersChange.Company = ProductionOrdersBalances.Company
		|			AND RegisterRecordsProductionOrdersChange.ProductionOrder = ProductionOrdersBalances.ProductionOrder
		|			AND RegisterRecordsProductionOrdersChange.Products = ProductionOrdersBalances.Products
		|			AND RegisterRecordsProductionOrdersChange.Characteristic = ProductionOrdersBalances.Characteristic
		|WHERE
		|	ISNULL(ProductionOrdersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsBackordersChange.LineNumber AS LineNumber,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Company) AS CompanyPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SalesOrder) AS SalesOrderPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Products) AS ProductsPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.Characteristic) AS CharacteristicPresentation,
		|	REFPRESENTATION(RegisterRecordsBackordersChange.SupplySource) AS SupplySourcePresentation,
		|	REFPRESENTATION(BackordersBalances.Products.MeasurementUnit) AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsBackordersChange.QuantityChange, 0) + ISNULL(BackordersBalances.QuantityBalance, 0) AS BalanceBackorders,
		|	ISNULL(BackordersBalances.QuantityBalance, 0) AS QuantityBalanceBackorders
		|FROM
		|	RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange
		|		LEFT JOIN AccumulationRegister.Backorders.Balance(
		|				&ControlTime,
		|				(Company, SalesOrder, Products, Characteristic, SupplySource) IN
		|					(SELECT
		|						RegisterRecordsBackordersChange.Company AS Company,
		|						RegisterRecordsBackordersChange.SalesOrder AS SalesOrder,
		|						RegisterRecordsBackordersChange.Products AS Products,
		|						RegisterRecordsBackordersChange.Characteristic AS Characteristic,
		|						RegisterRecordsBackordersChange.SupplySource AS SupplySource
		|					FROM
		|						RegisterRecordsBackordersChange AS RegisterRecordsBackordersChange)) AS BackordersBalances
		|		ON RegisterRecordsBackordersChange.Company = BackordersBalances.Company
		|			AND RegisterRecordsBackordersChange.SalesOrder = BackordersBalances.SalesOrder
		|			AND RegisterRecordsBackordersChange.Products = BackordersBalances.Products
		|			AND RegisterRecordsBackordersChange.Characteristic = BackordersBalances.Characteristic
		|			AND RegisterRecordsBackordersChange.SupplySource = BackordersBalances.SupplySource
		|WHERE
		|	ISNULL(BackordersBalances.QuantityBalance, 0) < 0
		|
		|ORDER BY
		|	LineNumber
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	RegisterRecordsSerialNumbersChange.LineNumber AS LineNumber,
		|	RegisterRecordsSerialNumbersChange.SerialNumber AS SerialNumberPresentation,
		|	RegisterRecordsSerialNumbersChange.StructuralUnit AS StructuralUnitPresentation,
		|	RegisterRecordsSerialNumbersChange.Products AS ProductsPresentation,
		|	RegisterRecordsSerialNumbersChange.Characteristic AS CharacteristicPresentation,
		|	RegisterRecordsSerialNumbersChange.Batch AS BatchPresentation,
		|	RegisterRecordsSerialNumbersChange.Cell AS PresentationCell,
		|	SerialNumbersBalance.StructuralUnit.StructuralUnitType AS StructuralUnitType,
		|	SerialNumbersBalance.Products.MeasurementUnit AS MeasurementUnitPresentation,
		|	ISNULL(RegisterRecordsSerialNumbersChange.QuantityChange, 0) + ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceSerialNumbers,
		|	ISNULL(SerialNumbersBalance.QuantityBalance, 0) AS BalanceQuantitySerialNumbers
		|FROM
		|	RegisterRecordsSerialNumbersChange AS RegisterRecordsSerialNumbersChange
		|		INNER JOIN AccumulationRegister.SerialNumbers.Balance(&ControlTime, ) AS SerialNumbersBalance
		|		ON RegisterRecordsSerialNumbersChange.StructuralUnit = SerialNumbersBalance.StructuralUnit
		|			AND RegisterRecordsSerialNumbersChange.Products = SerialNumbersBalance.Products
		|			AND RegisterRecordsSerialNumbersChange.Characteristic = SerialNumbersBalance.Characteristic
		|			AND RegisterRecordsSerialNumbersChange.Batch = SerialNumbersBalance.Batch
		|			AND RegisterRecordsSerialNumbersChange.SerialNumber = SerialNumbersBalance.SerialNumber
		|			AND RegisterRecordsSerialNumbersChange.Cell = SerialNumbersBalance.Cell
		|			AND (ISNULL(SerialNumbersBalance.QuantityBalance, 0) < 0)
		|
		|ORDER BY
		|	LineNumber");
		
		Query.TempTablesManager = StructureTemporaryTables.TempTablesManager;
		Query.SetParameter("ControlTime", AdditionalProperties.ForPosting.ControlTime);
		
		ResultsArray = Query.ExecuteBatch();
		
		If Not ResultsArray[0].IsEmpty()
			OR Not ResultsArray[1].IsEmpty()
			OR Not ResultsArray[2].IsEmpty()
			OR Not ResultsArray[3].IsEmpty()
			OR Not ResultsArray[4].IsEmpty()
			OR Not ResultsArray[5].IsEmpty() Then
			DocumentObjectProduction = DocumentRefProduction.GetObject()
		EndIf;
		
		// Negative balance of inventory in the warehouse.
		If Not ResultsArray[0].IsEmpty() Then
			QueryResultSelection = ResultsArray[0].Select();
			DriveServer.ShowMessageAboutPostingToInventoryInWarehousesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory.
		If Not ResultsArray[1].IsEmpty() Then
			QueryResultSelection = ResultsArray[1].Select();
			DriveServer.ShowMessageAboutPostingToInventoryRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of inventory received.
		If Not ResultsArray[2].IsEmpty() Then
			QueryResultSelection = ResultsArray[2].Select();
			DriveServer.ShowMessageAboutPostingToStockReceivedFromThirdPartiesRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance by production orders.
		If Not ResultsArray[3].IsEmpty() Then
			QueryResultSelection = ResultsArray[3].Select();
			DriveServer.ShowMessageAboutPostingToProductionOrdersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance on the inventories placement.
		If Not ResultsArray[4].IsEmpty() Then
			QueryResultSelection = ResultsArray[4].Select();
			DriveServer.ShowMessageAboutPostingToBackordersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
		// Negative balance of serial numbers in the warehouse.
		If NOT ResultsArray[5].IsEmpty() Then
			QueryResultSelection = ResultsArray[5].Select();
			DriveServer.ShowMessageAboutPostingSerialNumbersRegisterErrors(DocumentObjectProduction, QueryResultSelection, Cancel);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PrintInterface

// Function checks if the document is posted and calls the procedure of document printing.
//
Function PrintForm(ObjectsArray, PrintObjects, TemplateName)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_ProductionAssembly";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
	
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		If TemplateName = "GoodsContentForm" Then
			
			Query = New Query();
			Query.SetParameter("CurrentDocument", CurrentDocument);
			
			If CurrentDocument.OperationKind = Enums.OperationTypesProduction.Assembly Then
				
				Query.Text =
				"SELECT
				|	Production.Date AS DocumentDate,
				|	Production.StructuralUnit AS WarehousePresentation,
				|	Production.Cell AS CellPresentation,
				|	Production.Number AS Number,
				|	Production.Company.Prefix AS Prefix,
				|	Production.Inventory.(
				|		LineNumber AS LineNumber,
				|		Products.Warehouse AS Warehouse,
				|		Products.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(Production.Inventory.Products.DescriptionFull AS String(100))) = """"
				|				THEN Production.Inventory.Products.Description
				|			ELSE Production.Inventory.Products.DescriptionFull
				|		END AS InventoryItem,
				|		Products.SKU AS SKU,
				|		Products.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic,
				|		Products.ProductsType AS ProductsType,
				|		ConnectionKey
				|	),
				|	Production.SerialNumbers.(
				|		SerialNumber,
				|		ConnectionKey
				|	)
				|FROM
				|	Document.Production AS Production
				|WHERE
				|	Production.Ref = &CurrentDocument
				|
				|ORDER BY
				|	LineNumber";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Inventory.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbers.Select();
				
			Else
				
				Query.Text = 
				"SELECT
				|	Production.Date AS DocumentDate,
				|	Production.StructuralUnit AS WarehousePresentation,
				|	Production.Cell AS CellPresentation,
				|	Production.Number AS Number,
				|	Production.Company.Prefix AS Prefix,
				|	Production.Products.(
				|		LineNumber AS LineNumber,
				|		Products.Warehouse AS Warehouse,
				|		Products.Cell AS Cell,
				|		CASE
				|			WHEN (CAST(Production.Products.Products.DescriptionFull AS String(100))) = """"
				|				THEN Production.Products.Products.Description
				|			ELSE Production.Products.Products.DescriptionFull
				|		END AS InventoryItem,
				|		Products.SKU AS SKU,
				|		Products.Code AS Code,
				|		MeasurementUnit.Description AS MeasurementUnit,
				|		Quantity AS Quantity,
				|		Characteristic AS Characteristic,
				|		Products.ProductsType AS ProductsType,
				|		ConnectionKey
				|	),
				|	Production.SerialNumbersProducts.(
				|		SerialNumber,
				|		ConnectionKey
				|	)
				|FROM
				|	Document.Production AS Production
				|WHERE
				|	Production.Ref = &CurrentDocument";
				
				Header = Query.Execute().Select();
				Header.Next();
				
				LinesSelectionInventory = Header.Products.Select();
				LinesSelectionSerialNumbers = Header.SerialNumbersProducts.Select();
				
			EndIf;
			
			SpreadsheetDocument.PrintParametersName = "PARAMETERS_PRINT_Production_GoodsContentForm";
			
			Template = PrintManagement.PrintedFormsTemplate("Document.Production.PF_MXL_GoodsContentForm");
			
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
			
			TemplateArea = Template.GetArea("Title");
			TemplateArea.Parameters.HeaderText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Production #%1 dated %2'"),
				DocumentNumber,
				Format(Header.DocumentDate, "DLF=DD"));
													
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("Warehouse");
			TemplateArea.Parameters.WarehousePresentation = Header.WarehousePresentation;
			SpreadsheetDocument.Put(TemplateArea);
			
			If Constants.UseStorageBins.Get() Then
				
				TemplateArea = Template.GetArea("Cell");
				TemplateArea.Parameters.CellPresentation = Header.CellPresentation;
				SpreadsheetDocument.Put(TemplateArea);
				
			EndIf;
			
			TemplateArea = Template.GetArea("PrintingTime");
			TemplateArea.Parameters.PrintingTime = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Date and time of printing: %1. User: %2'"),
				CurrentDate(),
				Users.CurrentUser());
				
			SpreadsheetDocument.Put(TemplateArea);
			
			TemplateArea = Template.GetArea("TableHeader");
			SpreadsheetDocument.Put(TemplateArea);
			TemplateArea = Template.GetArea("String");
			
			While LinesSelectionInventory.Next() Do

				If Not LinesSelectionInventory.ProductsType = Enums.ProductsTypes.InventoryItem Then
					Continue;
				EndIf;
				
				TemplateArea.Parameters.Fill(LinesSelectionInventory);
				StringSerialNumbers = WorkWithSerialNumbers.SerialNumbersStringFromSelection(LinesSelectionSerialNumbers, LinesSelectionInventory.ConnectionKey);
				
				TemplateArea.Parameters.InventoryItem = DriveServer.GetProductsPresentationForPrinting(
					LinesSelectionInventory.InventoryItem,
					LinesSelectionInventory.Characteristic,
					LinesSelectionInventory.SKU,
					StringSerialNumbers);
					
				SpreadsheetDocument.Put(TemplateArea);
				
			EndDo;
			
			TemplateArea = Template.GetArea("Total");
			SpreadsheetDocument.Put(TemplateArea);	
			
		EndIf;
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
		
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate objects printing forms.
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, PrintFormsCollection, PrintObjects, OutputParameters) Export
		
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsContentForm") Then	
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "GoodsContentForm", 
			NStr("en = 'Goods content form'"), PrintForm(ObjectsArray, PrintObjects, "GoodsContentForm"));		
	ElsIf PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "GoodsReceivedNote") Then
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection,
															"GoodsReceivedNote",
															NStr("en = 'Goods received note'"),
															DataProcessors.PrintGoodsReceivedNote.PrintForm(ObjectsArray, PrintObjects, "GoodsReceivedNote"));
	EndIf;

	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsReceivedNote";
	PrintCommand.Presentation				= NStr("en = 'Goods received note'");
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 1;

	PrintCommand = PrintCommands.Add();
	PrintCommand.ID							= "GoodsContentForm";
	PrintCommand.Presentation				= NStr("en = 'Goods content form'");
	PrintCommand.FormsList					= "DocumentForm, ListForm, DocumentsListForm";
	PrintCommand.CheckPostingBeforePrint	= False;
	PrintCommand.Order						= 10;
	
EndProcedure

#EndRegion

#Region InfobaseUpdate

Procedure FillNewGLAccounts() Export
	
	DocumentName = "Production";
	
	Tables = New Array();
	
	// Table "Products"
	TableDecription = New Structure("Name, Conditions", "Products", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "ConsumptionGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	// Table "Inventory"
	TableDecription = New Structure("Name, Conditions", "Inventory", New Array());
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.ExpensesGLAccount";
	GLAccountFields.Receiver = "ConsumptionGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	GLAccountFields = ChartsOfAccounts.PrimaryChartOfAccounts.GLAccountFields();
	GLAccountFields.Source = "Products.InventoryGLAccount";
	GLAccountFields.Receiver = "InventoryGLAccount";
	TableDecription.Conditions.Add(GLAccountFields);
	
	Tables.Add(TableDecription);
	
	ChartsOfAccounts.PrimaryChartOfAccounts.FillNewGLAccounts(DocumentName, Tables);
	
EndProcedure

#EndRegion


#EndIf
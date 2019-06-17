#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region Public

Procedure FillingHandler(FillingData) Export
	
	If TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		
		Query = New Query(QueryTextForFilling());
		Query.SetParameter("Parameter", FillingData);
		ResultsArray = Query.ExecuteBatch();
		
		Header = ResultsArray[0].Unload();
		
		If Header.Count() > 0 Then
			
			FillPropertyValues(ThisObject, Header[0]);
			
			If DocumentCurrency <> Constants.FunctionalCurrency.Get() Then
				CurrencyStructure = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
				ExchangeRate = CurrencyStructure.ExchangeRate;
				Multiplicity = CurrencyStructure.Multiplicity;
			EndIf;
			
			Inventory.Clear();
			TabularSection = ResultsArray[1].Unload();
			For Each TabularSectionSelection In TabularSection Do
				NewRow = Inventory.Add();
				FillPropertyValues(NewRow, TabularSectionSelection);
				NewRow.ProductsTypeInventory = (TabularSectionSelection.ProductsProductsType = Enums.ProductsTypes.InventoryItem);
			EndDo;
			
			Works.Clear();
			TabularSection = ResultsArray[2].Unload();
			For Each TabularSectionSelection In TabularSection Do
				NewRow = Works.Add();
				FillPropertyValues(NewRow, TabularSectionSelection);
				NewRow.ProductsTypeService = (TabularSectionSelection.ProductsProductsType = Enums.ProductsTypes.Service);
			EndDo;
			
			If GetFunctionalOption("UseAutomaticDiscounts") Then
				TabularSection = ResultsArray[3].Unload();
				For Each SelectionDiscountsMarkups In TabularSection Do
					FillPropertyValues(DiscountsMarkups.Add(), SelectionDiscountsMarkups);
				EndDo;
			EndIf;
			
			DocumentAmount = Inventory.Total("Total") + Works.Total("Total");
			
			// Payment calendar
			PaymentCalendar.Clear();
			
			Query = New Query;
			Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
			Query.SetParameter("Quote", FillingData);
			Query.Text = 
			"SELECT
			|	DATEADD(&Date, DAY, DATEDIFF(Calendar.Ref.Date, Calendar.PaymentDate, DAY)) AS PaymentDate,
			|	Calendar.PaymentPercentage AS PaymentPercentage,
			|	Calendar.PaymentAmount AS PaymentAmount,
			|	Calendar.PaymentVATAmount AS PaymentVATAmount
			|FROM
			|	Document.Quote.PaymentCalendar AS Calendar
			|WHERE
			|	Calendar.Ref = &Quote";
			
			Selection = Query.Execute().Select();
			While Selection.Next() Do
				NewLine = PaymentCalendar.Add();
				FillPropertyValues(NewLine, Selection);
			EndDo;
			
			SetPaymentTerms = PaymentCalendar.Count() > 0;
			
		EndIf;
	
	EndIf;

EndProcedure

Procedure FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkgroupsContent.Employee AS Employee,
	|	WorkgroupsContent.Employee.Description AS Description,
	|	CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType
	|INTO TemporaryTableEmployeesAndEarningDeductionSorts
	|FROM
	|	Catalog.Teams.Content AS WorkgroupsContent
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality
	|					AND EarningAndDeductionType IN (VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))) AS CompensationPlanSliceLast
	|		ON WorkgroupsContent.Employee = CompensationPlanSliceLast.Employee
	|WHERE
	|	WorkgroupsContent.Ref IN(&ArrayOfTeams)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Description AS Description,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType AS EarningAndDeductionType,
	|	1 AS LPF,
	|	CompensationPlanSliceLast.Amount * EarningCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * EarningCurrencyRate.Multiplicity) AS AmountEarningDeduction
	|FROM
	|	TemporaryTableEmployeesAndEarningDeductionSorts AS TemporaryTableEmployeesAndEarningDeductionSorts
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS CompensationPlanSliceLast
	|		ON TemporaryTableEmployeesAndEarningDeductionSorts.Employee = CompensationPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType = CompensationPlanSliceLast.EarningAndDeductionType
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS EarningCurrencyRate
	|		ON (CompensationPlanSliceLast.Currency = EarningCurrencyRate.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("ToDate", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow In Works Do
			
			If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Work Then
				
				For Each TSRow In EmployeesTable Do
					
					NewRow = LaborAssignment.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow In EmployeesTable Do
			
			NewRow = LaborAssignment.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) IN
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
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
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow In TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;
	
EndProcedure

Procedure GoodsFillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
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
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure GoodsFillColumnReserveByReserves() Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("Order", Ref);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				
				TotalBalance = 0;
				
			Else
				
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure MaterialsFillColumnReserveByBalances(MaterialsConnectionKey) Export
	
	If MaterialsConnectionKey = Undefined Then
		Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
	Else
		SearchResult = Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
		For Each TabularSectionRow In SearchResult Do
			TabularSectionRow.Reserve = 0;
		EndDo;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
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
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure MaterialsFillColumnReserveByReserves(MaterialsConnectionKey) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
	Query.SetParameter("Order", Ref);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				TotalBalance = 0;
			Else
				
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillPaymentCalendarFromContract() Export
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	TotalAmount = Inventory.Total("Amount") + Works.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount") + Works.Total("VATAmount");
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentSessionDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	If Constants.UseWorkOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewWorkOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.WorkOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.WorkOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("Structure")
		AND FillingData.Property("Products") Then
		
		Products = FillingData.Products;
		TabularSection = New ValueTable;
		TabularSection.Columns.Add("Products");
		NewRow = TabularSection.Add();
		NewRow.Products = Products;
		
		If Products.ProductsType = Enums.ProductsTypes.InventoryItem Then
			NameTS = "Inventory";
		ElsIf Products.ProductsType = Enums.ProductsTypes.Service
			Or Products.ProductsType = Enums.ProductsTypes.Work Then
			NameTS = "Works";
		Else
			NameTS = "";
		EndIf;
		
		FillingData = New Structure;
		If ValueIsFilled(NameTS) Then
			FillingData.Insert(NameTS, TabularSection);
		EndIf;
		If Products.ProductsType = Enums.ProductsTypes.WorkKind Then
			FillingData.Insert("WorkKind", Products);
		EndIf;
		
	EndIf;

	If CommonUse.ReferenceTypeValue(FillingData) Then
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler");
	Else
		ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("WorkOrderStatuses", "Completed") Then
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'You cannot make changes to a completed %1.'"), Ref);
		CommonUseClientServer.MessageToUser(MessageText,,,,);
		Return;
	EndIf;

	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
			Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total") + Works.Total("Total");
	
	ChangeDate = CurrentSessionDate();
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	Documents.WorkOrder.InitializeDocumentData(Ref, AdditionalProperties, ThisObject);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectWorkOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTimesheet(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.WriteRecordSets(ThisObject);

	Documents.WorkOrder.RunControl(ThisObject, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.WorkOrder.RunControl(ThisObject, AdditionalProperties, Cancel, True);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If OrderState.OrderStatus = Enums.OrderStatuses.InProcess
		OR OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
		CheckedAttributes.Add("Start");
		CheckedAttributes.Add("Finish");
		
	EndIf;
	
	If WriteOffCustomersInventory AND OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
		CheckedAttributes.Add("ConsumersInventory.Batch");
		
	EndIf;
	
	If OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
		
		CheckedAttributes.Add("LaborAssignment.Position");
		CheckedAttributes.Add("LaborAssignment.PayCode");
		
	EndIf;
	
	If Materials.Count() > 0 OR Inventory.Count() > 0 Then
		CheckedAttributes.Add("StructuralUnitReserve");
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		For Each StringInventory In Inventory Do
		
			If StringInventory.Reserve > 0
			AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is required.'");
				DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If SetPaymentTerms
		AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
		
		CheckedAttributes.Add("BankAccount")
		
	ElsIf SetPaymentTerms
		AND CashAssetsType = Enums.CashAssetTypes.Cash Then
		
		CheckedAttributes.Add("PettyCash");
				
	EndIf;
	
	If SetPaymentTerms
		AND PaymentCalendar.Count() = 1
		AND Not ValueIsFilled(PaymentCalendar[0].PaymentDate) Then
		
		MessageText = NStr("en = 'The payment date is required.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "PaymentDate", Cancel);
		
		PaymentDateAttributes = CheckedAttributes.Find("PaymentCalendar.PaymentDate");
		If PaymentDateAttributes <> Undefined Then
			CheckedAttributes.Delete(PaymentDateAttributes);
		EndIf;
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		
		For Each StringInventory In Inventory Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then	
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'The quantity of items to be reserved in line #%1 of the Goods list exceeds the available quantity.'"),
					StringInventory.LineNumber),
					"Inventory",
					StringInventory.LineNumber,
					"Reserve",
					Cancel);
				
			EndIf;
			
		EndDo;
		
		For Each StringInventory In Materials Do
			
			If StringInventory.Reserve > StringInventory.Quantity Then
				
				DriveServer.ShowMessageAboutError(
				ThisObject,
				StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The quantity of items to be reserved in line #%1 of the Materials list exceeds the available quantity.'"),
				StringInventory.LineNumber),
				"Materials",
				StringInventory.LineNumber,
				"Reserve",
				Cancel);
				
			EndIf;
			
		EndDo;
		
		// Serial numbers
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Inventory, SerialNumbers, StructuralUnitReserve, ThisObject);
		WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Materials, SerialNumbersMaterials, StructuralUnitReserve, ThisObject, "ConnectionKeySerialNumbers");
		
	EndIf;
	
	If Not Constants.UseWorkOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The order status is required. Specify the available statuses in Accounting settings > Sales.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			
			// AutomaticDiscounts
			CurAmount					= StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Amount is required in line #%1 of the Products list.'"),
						StringInventory.LineNumber),
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel);
					
			EndIf;
		EndDo;
	EndIf;
	
	If ThereAreManualDiscounts Then
		For Each WorkRow In Works Do
			
			// AutomaticDiscounts
			CurAmount					= WorkRow.Price * WorkRow.Quantity * WorkRow.StandardHours;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * WorkRow.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, WorkRow.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If WorkRow.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(WorkRow.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Amount is required in line #%1 of the Works list.'"),
						WorkRow.LineNumber),
					"Works",
					WorkRow.LineNumber,
					"Amount",
					Cancel);
				
			EndIf;
		EndDo;
	EndIf;
	
	// Also check filling of the employees Earnings
	Documents.WorkOrder.ArePerformersWithEmptyEarningSum(LaborAssignment);
	
	// Payment calendar
	Amount = Inventory.Total("Amount") + Works.Total("Amount");
	VATAmount = Inventory.Total("VATAmount") + Works.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

#EndRegion

#Region Private

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

Function QueryTextForFilling()
	
	Text = "SELECT ALLOWED
	|	Quote.Ref AS BasisDocument,
	|	Quote.VATTaxation AS VATTaxation,
	|	Quote.Company AS Company,
	|	Quote.DiscountCard AS DiscountCard,
	|	Quote.ExchangeRate AS ExchangeRate,
	|	Quote.DiscountPercentByDiscountCard AS DiscountPercentByDiscountCard,
	|	Quote.Multiplicity AS Multiplicity,
	|	Quote.Contract AS Contract,
	|	Quote.AmountIncludesVAT AS AmountIncludesVAT,
	|	Quote.Counterparty AS Counterparty,
	|	Quote.DocumentCurrency AS DocumentCurrency,
	|	Quote.BankAccount AS BankAccount,
	|	Quote.PettyCash AS PettyCash,
	|	Quote.CashAssetsType AS CashAssetsType,
	|	Quote.DiscountsAreCalculated AS DiscountsAreCalculated
	|FROM
	|	Document.Quote AS Quote
	|WHERE
	|	Quote.Ref = &Parameter
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	QuoteInventory.Amount AS Amount,
	|	QuoteInventory.Products AS Products,
	|	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	QuoteInventory.Products.ProductsType AS ProductsProductsType,
	|	QuoteInventory.Characteristic AS Characteristic,
	|	QuoteInventory.Price AS Price,
	|	QuoteInventory.Content AS Content,
	|	QuoteInventory.Quantity AS Quantity,
	|	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	|	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	QuoteInventory.VATRate AS VATRate,
	|	QuoteInventory.VATAmount AS VATAmount,
	|	QuoteInventory.Total AS Total,
	|	QuoteInventory.ConnectionKey AS ConnectionKey
	|FROM
	|	Document.Quote.Inventory AS QuoteInventory
	|		INNER JOIN Catalog.Products AS ProductsTable
	|		ON QuoteInventory.Products = ProductsTable.Ref
	|		INNER JOIN Document.Quote AS Quote
	|		ON QuoteInventory.Ref = Quote.Ref
	|			AND QuoteInventory.Variant = Quote.PreferredVariant
	|WHERE
	|	QuoteInventory.Ref = &Parameter
	|	AND ProductsTable.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	QuoteInventory.AutomaticDiscountAmount AS AutomaticDiscountAmount,
	|	QuoteInventory.Amount AS Amount,
	|	QuoteInventory.Products AS Products,
	|	QuoteInventory.AutomaticDiscountsPercent AS AutomaticDiscountsPercent,
	|	QuoteInventory.Products.ProductsType AS ProductsProductsType,
	|	QuoteInventory.Characteristic AS Characteristic,
	|	QuoteInventory.Price AS Price,
	|	QuoteInventory.Content AS Content,
	|	QuoteInventory.Quantity AS Quantity,
	|	QuoteInventory.MeasurementUnit AS MeasurementUnit,
	|	QuoteInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	QuoteInventory.VATRate AS VATRate,
	|	QuoteInventory.VATAmount AS VATAmount,
	|	QuoteInventory.Total AS Total,
	|	QuoteInventory.ConnectionKey AS ConnectionKey
	|	FROM
	|	Document.Quote.Inventory AS QuoteInventory
	|		INNER JOIN Catalog.Products AS ProductsTable
	|		ON QuoteInventory.Products = ProductsTable.Ref
	|		INNER JOIN Document.Quote AS Quote
	|		ON QuoteInventory.Ref = Quote.Ref
	|			AND QuoteInventory.Variant = Quote.PreferredVariant
	|WHERE
	|	QuoteInventory.Ref = &Parameter
	|	AND (ProductsTable.ProductsType = VALUE(Enum.ProductsTypes.Service)
	|			OR ProductsTable.ProductsType = VALUE(Enum.ProductsTypes.Work))
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	QuoteDiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	QuoteDiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	QuoteDiscountsMarkups.Amount AS Amount
	|FROM
	|	Document.Quote.DiscountsMarkups AS QuoteDiscountsMarkups
	|WHERE
	|	QuoteDiscountsMarkups.Ref = &Parameter";
	
	Return Text;
	
EndFunction

Procedure FillByDefault()

	If Constants.UseWorkOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "StatusOfNewWorkOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.WorkOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.WorkOrdersInProgressStatus.Get();
	EndIf;

EndProcedure

#EndRegion

#EndIf

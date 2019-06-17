#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableProduction.LineNumber AS LineNumber,
	|	TableProduction.Quantity AS Quantity,
	|	TableProduction.Factor AS Factor,
	|	TableProduction.Specification AS Specification
	|INTO TemporaryTableProduction
	|FROM
	|	&TableProduction AS TableProduction
	|WHERE
	|	TableProduction.Specification <> VALUE(Catalog.BillsOfMaterials.EmptyRef)";
	
	If NodesTable = Undefined Then
		Inventory.Clear();
		TableProduction = Products.Unload();
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableProduction.Columns.Add("Factor", TypeDescriptionC);
		For Each StringProducts In TableProduction Do
			If ValueIsFilled(StringProducts.MeasurementUnit)
				AND TypeOf(StringProducts.MeasurementUnit) = Type("CatalogRef.UOM") Then
				StringProducts.Factor = StringProducts.MeasurementUnit.Factor;
			Else
				StringProducts.Factor = 1;
			EndIf;
		EndDo;
		NodesTable = TableProduction.CopyColumns("LineNumber,Quantity,Factor,Specification");
		Query.SetParameter("TableProduction", TableProduction);
	Else
		Query.SetParameter("TableProduction", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	MIN(TableProduction.LineNumber) AS ProductionLineNumber,
	|	TableProduction.Specification AS ProductionSpecification,
	|	MIN(TableMaterials.LineNumber) AS StructureLineNumber,
	|	TableMaterials.ContentRowType AS ContentRowType,
	|	TableMaterials.Products AS Products,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END AS Characteristic,
	|	SUM(TableMaterials.Quantity / TableMaterials.ProductsQuantity * TableProduction.Factor * TableProduction.Quantity) AS Quantity,
	|	TableMaterials.MeasurementUnit AS MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END AS Factor,
	|	TableMaterials.CostPercentage AS CostPercentage,
	|	TableMaterials.Specification AS Specification
	|FROM
	|	TemporaryTableProduction AS TableProduction
	|		LEFT JOIN Catalog.BillsOfMaterials.Content AS TableMaterials
	|		ON TableProduction.Specification = TableMaterials.Ref,
	|	Constant.UseCharacteristics AS UseCharacteristics
	|WHERE
	|	TableMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	TableProduction.Specification,
	|	TableMaterials.ContentRowType,
	|	TableMaterials.Products,
	|	TableMaterials.MeasurementUnit,
	|	CASE
	|		WHEN TableMaterials.ContentRowType = VALUE(Enum.BOMLineType.Node)
	|				AND VALUETYPE(TableMaterials.MeasurementUnit) = Type(Catalog.UOM)
	|				AND TableMaterials.MeasurementUnit <> VALUE(Catalog.UOM.EmptyRef)
	|			THEN TableMaterials.MeasurementUnit.Factor
	|		ELSE 1
	|	END,
	|	TableMaterials.CostPercentage,
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
	|	ProductionLineNumber,
	|	StructureLineNumber";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		If Selection.ContentRowType = Enums.BOMLineType.Node Then
			NodesTable.Clear();
			If Not NodesBillsOfMaterialstack.Find(Selection.Specification) = Undefined Then
				MessageText = NStr("en = 'During filling in of the Specification materials
				                   |tabular section a recursive item occurrence was found'")+" "+Selection.Products+" "+NStr("en = 'in BOM'")+" "+Selection.ProductionSpecification+"
									|The operation failed.";
				Raise MessageText;
			EndIf;
			NodesBillsOfMaterialstack.Add(Selection.Specification);
			NewRow = NodesTable.Add();
			FillPropertyValues(NewRow, Selection);
			FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable);
		Else
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
				If ValueIsFilled(NewRow.Products.VATRate) Then
					NewRow.VATRate = NewRow.Products.VATRate;
				Else
					NewRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
				EndIf;
			Else
				If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
					NewRow.VATRate = Catalogs.VATRates.Exempt;
				Else
					NewRow.VATRate = Catalogs.VATRates.ZeroRate;
				EndIf;
			EndIf;
			
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	Inventory.GroupBy("Products, Characteristic, Batch, MeasurementUnit, VATRate", "Quantity");
	
EndProcedure

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsReceivableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsReceivableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsReceivableBalances
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.Contract AS Contract,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.Document.Date AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsReceivable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order = &Order
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsAccountsReceivable.Contract,
	|		DocumentRegisterRecordsAccountsReceivable.Document,
	|		DocumentRegisterRecordsAccountsReceivable.Document.Date,
	|		DocumentRegisterRecordsAccountsReceivable.Order,
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
	|		AND DocumentRegisterRecordsAccountsReceivable.Contract = &Contract
	|		AND DocumentRegisterRecordsAccountsReceivable.Order = &Order
	|		AND DocumentRegisterRecordsAccountsReceivable.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsReceivableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsReceivableBalances.Document AS Document,
	|	AccountsReceivableBalances.Order AS Order,
	|	AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsReceivableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsReceivableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsReceivableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsReceivableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsReceivableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (SettlementsCurrencyExchangeRatesRate / SettlementsCurrencyExchangeRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesRate AS DocumentCurrencyExchangeRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesMultiplicity AS DocumentCurrencyExchangeRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsReceivableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsReceivableBalances.Document AS Document,
	|		AccountsReceivableBalances.DocumentDate AS DocumentDate,
	|		AccountsReceivableBalances.Order AS Order,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsReceivableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsReceivableBalances.AmountBalance, 0) * SettlementsCurrencyExchangeRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyExchangeRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyExchangeRates.ExchangeRate AS SettlementsCurrencyExchangeRatesRate,
	|		SettlementsCurrencyExchangeRates.Multiplicity AS SettlementsCurrencyExchangeRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyExchangeRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyExchangeRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsReceivableBalances AS AccountsReceivableBalances
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &PresentationCurrency) AS SettlementsCurrencyExchangeRates
	|			ON (TRUE)) AS AccountsReceivableBalances
	|
	|GROUP BY
	|	AccountsReceivableBalances.Document,
	|	AccountsReceivableBalances.Order,
	|	AccountsReceivableBalances.DocumentDate,
	|	AccountsReceivableBalances.SettlementsCurrency,
	|	SettlementsCurrencyExchangeRatesRate,
	|	SettlementsCurrencyExchangeRatesMultiplicity,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesRate,
	|	AccountsReceivableBalances.DocumentCurrencyExchangeRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsReceivableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	If Counterparty.DoOperationsByOrders Then
		Query.SetParameter("Order", SalesOrder);
	Else
		Query.SetParameter("Order", Undefined);
	EndIf;
	
	Query.SetParameter("Company", ParentCompany);
	Query.SetParameter("Counterparty", Counterparty);
	Query.SetParameter("Contract", Contract);
	Query.SetParameter("Period", Date);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("PresentationCurrency", Constants.PresentationCurrency.Get());
	If Contract.SettlementsCurrency = DocumentCurrency Then
		Query.SetParameter("DocumentCurrencyRate", ExchangeRate);
		Query.SetParameter("MultiplicityOfDocumentCurrency", Multiplicity);
	Else
		Query.SetParameter("DocumentCurrencyRate", 1);
		Query.SetParameter("MultiplicityOfDocumentCurrency", 1);
	EndIf;
	Query.SetParameter("Ref", Ref);
	
	Query.Text = QueryText;
	
	Prepayment.Clear();
	AmountLeftToDistribute = Products.Total("Total");
	AmountLeftToDistribute = DriveServer.RecalculateFromCurrencyToCurrency(
		AmountLeftToDistribute,
		?(Contract.SettlementsCurrency = DocumentCurrency, ExchangeRate, 1),
		ExchangeRate,
		?(Contract.SettlementsCurrency = DocumentCurrency, Multiplicity, 1),
		Multiplicity
	);
	
	SelectionOfQueryResult = Query.Execute().Select();
	
	While AmountLeftToDistribute > 0 Do
		
		If SelectionOfQueryResult.Next() Then
			
			If SelectionOfQueryResult.SettlementsAmount <= AmountLeftToDistribute Then // balance amount is less or equal than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				AmountLeftToDistribute = AmountLeftToDistribute - SelectionOfQueryResult.SettlementsAmount;
				
			Else // Balance amount is greater than it is necessary to distribute
				
				NewRow = Prepayment.Add();
				FillPropertyValues(NewRow, SelectionOfQueryResult);
				NewRow.SettlementsAmount = AmountLeftToDistribute;
				NewRow.PaymentAmount = DriveServer.RecalculateFromCurrencyToCurrency(
					NewRow.SettlementsAmount,
					SelectionOfQueryResult.ExchangeRate,
					SelectionOfQueryResult.DocumentCurrencyExchangeRatesRate,
					SelectionOfQueryResult.Multiplicity,
					SelectionOfQueryResult.DocumentCurrencyExchangeRatesMultiplicity
				);
				AmountLeftToDistribute = 0;
				
			EndIf;
			
		Else
			
			AmountLeftToDistribute = 0;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure fills out the Quantity column according to reserves to be ordered.
//
Procedure FillColumnReserveByReserves() Export
	
	Products.LoadColumn(New Array(Products.Count()), "Reserve");
	
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
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Products.Unload());
	Query.SetParameter("Order", ?(ValueIsFilled(SalesOrder), SalesOrder, Undefined));
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
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnit);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Products.FindRows(StructureForSearch);
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

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice 
// FillingData   - Structure - Document filling data
//	
Procedure FillBySalesOrder(FillingData)
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData,
			New Structure("Company, Counterparty, Contract, Ref, StructuralUnitReserve, PriceKind, DiscountMarkupKind, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity, OrderState, Closed, Posted"));
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract, PriceKind, DiscountMarkupKind, DocumentCurrency, VATTaxation, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity");
	
	SalesOrder = AttributeValues.Ref;
	If Constants.UseInventoryReservation.Get() Then
		StructuralUnit = AttributeValues.StructuralUnitReserve;
	EndIf;
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	If Not DocumentCurrency = Constants.FunctionalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(?(ValueIsFilled(Date), Date, CurrentDate()), New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	SUM(OrdersBalance.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		OrdersBalance.Products AS Products,
	|		OrdersBalance.Characteristic AS Characteristic,
	|		OrdersBalance.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.SalesOrders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsSalesOrders.Products,
	|		DocumentRegisterRecordsSalesOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsSalesOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsSalesOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsSalesOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.SalesOrders AS DocumentRegisterRecordsSalesOrders
	|	WHERE
	|		DocumentRegisterRecordsSalesOrders.Recorder = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic
	|
	|HAVING
	|	SUM(OrdersBalance.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	StockReceivedFromThirdPartiesBalances.SalesOrder AS SalesOrder,
	|	StockReceivedFromThirdPartiesBalances.Contract AS Contract,
	|	StockReceivedFromThirdPartiesBalances.Products AS Products,
	|	StockReceivedFromThirdPartiesBalances.Characteristic AS Characteristic,
	|	StockReceivedFromThirdPartiesBalances.Batch AS Batch,
	|	SUM(StockReceivedFromThirdPartiesBalances.QuantityBalance) AS Quantity,
	|	SUM(StockReceivedFromThirdPartiesBalances.SettlementsAmount) AS Amount
	|FROM
	|	(SELECT
	|		StockReceivedFromThirdPartiesBalances.Order AS SalesOrder,
	|		StockReceivedFromThirdPartiesBalances.Contract AS Contract,
	|		StockReceivedFromThirdPartiesBalances.Products AS Products,
	|		StockReceivedFromThirdPartiesBalances.Characteristic AS Characteristic,
	|		StockReceivedFromThirdPartiesBalances.Batch AS Batch,
	|		StockReceivedFromThirdPartiesBalances.QuantityBalance AS QuantityBalance,
	|		StockReceivedFromThirdPartiesBalances.SettlementsAmountBalance AS SettlementsAmount
	|	FROM
	|		AccumulationRegister.StockReceivedFromThirdParties.Balance(
	|				,
	|				Order = &BasisDocument) AS StockReceivedFromThirdPartiesBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventoryAccepted.Order,
	|		DocumentRegisterRecordsInventoryAccepted.Contract,
	|		DocumentRegisterRecordsInventoryAccepted.Products,
	|		DocumentRegisterRecordsInventoryAccepted.Characteristic,
	|		DocumentRegisterRecordsInventoryAccepted.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryAccepted.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryAccepted.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryAccepted.Quantity, 0)
	|		END,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventoryAccepted.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventoryAccepted.SettlementsAmount, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventoryAccepted.SettlementsAmount, 0)
	|		END
	|	FROM
	|		AccumulationRegister.StockReceivedFromThirdParties AS DocumentRegisterRecordsInventoryAccepted
	|	WHERE
	|		DocumentRegisterRecordsInventoryAccepted.Recorder = &Ref) AS StockReceivedFromThirdPartiesBalances
	|
	|GROUP BY
	|	StockReceivedFromThirdPartiesBalances.SalesOrder,
	|	StockReceivedFromThirdPartiesBalances.Contract,
	|	StockReceivedFromThirdPartiesBalances.Products,
	|	StockReceivedFromThirdPartiesBalances.Characteristic,
	|	StockReceivedFromThirdPartiesBalances.Batch
	|
	|HAVING
	|	SUM(StockReceivedFromThirdPartiesBalances.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Products.ProductsType AS ProductsType,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	SalesOrderInventory.Batch AS Batch,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.Quantity AS Quantity,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.Price AS Price,
	|	SalesOrderInventory.DiscountMarkupPercent AS DiscountMarkupPercent,
	|	SalesOrderInventory.Amount AS Amount,
	|	SalesOrderInventory.VATRate AS VATRate,
	|	SalesOrderInventory.VATAmount AS VATAmount,
	|	SalesOrderInventory.Total AS Total,
	|	SalesOrderInventory.Content AS Content,
	|	SalesOrderInventory.Specification AS Specification,
	|	SalesOrderInventory.AutomaticDiscountsPercent,
	|	SalesOrderInventory.AutomaticDiscountAmount,
	|	SalesOrderInventory.ConnectionKey
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	DiscountsMarkups.Ref AS Order,
	|	DiscountsMarkups.ConnectionKey AS ConnectionKey,
	|	DiscountsMarkups.DiscountMarkup AS DiscountMarkup,
	|	DiscountsMarkups.Amount AS Amount
	|FROM
	|	Document.SalesOrder.DiscountsMarkups AS DiscountsMarkups
	|WHERE
	|	DiscountsMarkups.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	// AutomaticDiscounts.
	OrderDiscountsMarkups = ResultsArray[3].Unload();
	DiscountsMarkups.Clear();
	// End AutomaticDiscounts.
	
	Products.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[2].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products", Selection.Products);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			NewRow = Products.Add();
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				QuantityToWriteOff = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
				DataStructure = DriveServer.GetTabularSectionRowSum(
					New Structure("Quantity, Price, Amount, DiscountMarkupPercent, VATRate, VATAmount, AmountIncludesVAT, Total",
						QuantityToWriteOff, Selection.Price, 0, Selection.DiscountMarkupPercent, Selection.VATRate, 0, AmountIncludesVAT, 0));
				
				FillPropertyValues(NewRow, DataStructure);
				
			EndIf;
			
			// AutomaticDiscounts
			QuantityInDocument = Selection.Quantity * Selection.Factor;
			RecalculateAmounts = QuantityInDocument <> QuantityToWriteOff;
			DiscountRecalculationCoefficient = ?(RecalculateAmounts, QuantityToWriteOff / QuantityInDocument, 1);
			If DiscountRecalculationCoefficient <> 1 Then
				NewRow.AutomaticDiscountAmount = ROUND(Selection.AutomaticDiscountAmount * DiscountRecalculationCoefficient,2);
			EndIf;
			
			// Creating discounts tabular section
			SumDistribution = NewRow.AutomaticDiscountAmount;
			
			HasDiscountString = False;
			If Selection.ConnectionKey <> 0 Then
				For Each OrderDiscountString In OrderDiscountsMarkups.FindRows(New Structure("Order,ConnectionKey", FillingData, Selection.ConnectionKey)) Do
					
					DiscountString = DiscountsMarkups.Add();
					FillPropertyValues(DiscountString, OrderDiscountString);
					DiscountString.Amount = DiscountRecalculationCoefficient * DiscountString.Amount;
					SumDistribution = SumDistribution - DiscountString.Amount;
					HasDiscountString = True;
					
				EndDo;
			EndIf;
			
			If HasDiscountString AND SumDistribution <> 0 Then
				DiscountString.Amount = DiscountString.Amount + SumDistribution;
			EndIf;
			// End AutomaticDiscounts
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// AutomaticDiscounts.
	DiscountsMarkupsCalculationResult = DiscountsMarkups.Unload();
	DiscountsMarkupsServer.ApplyDiscountCalculationResultToObject(ThisObject, "Inventory", DiscountsMarkupsCalculationResult);
	// End AutomaticDiscounts.
	
	Inventory.Clear();
	BalanceTable = ResultsArray[1].Unload();
	PresentationCurrency = Constants.PresentationCurrency.Get();
	For Each StringInventory In BalanceTable Do
		
		NewRow = Inventory.Add();
		FillPropertyValues(NewRow, StringInventory);
		
		If StringInventory.Amount > 0 Then
			If DocumentCurrency = StringInventory.Contract.SettlementsCurrency Then
				Amount = StringInventory.Amount;
			Else
				ExchangeRatesStructure = DriveServer.GetExchangeRates(DocumentCurrency, StringInventory.Contract.SettlementsCurrency, ?(ValueIsFilled(Date), Date, CurrentDate()));
				Amount = DriveServer.RecalculateFromCurrencyToCurrency(
							StringInventory.Amount,
							ExchangeRatesStructure.InitRate,
							ExchangeRatesStructure.ExchangeRate,
							ExchangeRatesStructure.RepetitionBeg,
							ExchangeRatesStructure.Multiplicity);
			EndIf;
		Else
			Amount = 0;
		EndIf;
		
		NewRow.MeasurementUnit = StringInventory.Products.MeasurementUnit;
		NewRow.Price = Amount / StringInventory.Quantity;
		
		If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
			If ValueIsFilled(StringInventory.Products.VATRate) Then
				NewRow.VATRate = StringInventory.Products.VATRate;
			Else
				NewRow.VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
			EndIf;
		Else
			If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
				NewRow.VATRate = Catalogs.VATRates.Exempt;
			Else
				NewRow.VATRate = Catalogs.VATRates.ZeroRate;
			EndIf;
		EndIf;
		
		DataStructure = DriveServer.GetTabularSectionRowSum(
					New Structure("Quantity, Price, Amount, VATRate, VATAmount, AmountIncludesVAT, Total",
						StringInventory.Quantity, NewRow.Price, 0, NewRow.VATRate, 0, AmountIncludesVAT, 0));
						
		FillPropertyValues(NewRow, DataStructure);
		
	EndDo;
	
	// Filling out reserves.
	If Products.Count() > 0
		AND Constants.UseInventoryReservation.Get() Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure

// Procedure for filling the document on the basis of inventory assembly.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier invoice FillingData - Structure - Document filling
//	data
Procedure FillByProduction(FillingData)
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, New Structure("Company, OperationKind, ProductsStructuralUnit, ProductsCell, SalesOrder"));
	
	FillPropertyValues(ThisObject, AttributeValues);
	
	If AttributeValues.ProductsStructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
		StructuralUnit = AttributeValues.ProductsStructuralUnit;
		Cell = AttributeValues.ProductsCell;
	EndIf;
	
	If AttributeValues.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		TSProducts = "Inventory";
		TSMaterials = "Products";
	Else
		TSProducts = "Products";
		TSMaterials = "Inventory";
	EndIf;
	
	// Filling out tabular section.
	Query = New Query;
	Query.Text =
	"SELECT
	|	Production.Products.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		SerialNumbers AS SerialNumbers,
	|		ConnectionKey AS ConnectionKey,
	|		CASE
	|			WHEN Production.Products.Products.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|				THEN AccountingPolicySliceLast.DefaultVATRate
	|			ELSE Production.Products.Products.VATRate
	|		END AS VATRate,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	) AS Products,
	|	Production.Inventory.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		SerialNumbers AS SerialNumbers,
	|		ConnectionKey AS ConnectionKey,
	|		CASE
	|			WHEN Production.Inventory.Products.VATRate = VALUE(Catalog.VATRates.EmptyRef)
	|				THEN AccountingPolicySliceLast.DefaultVATRate
	|			ELSE Production.Inventory.Products.VATRate
	|		END AS VATRate,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Specification AS Specification
	|	) AS Inventory,
	|	Production.Disposals.(
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Batch AS Batch,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit
	|	) AS Disposals
	|FROM
	|	Document.Production AS Production
	|		LEFT JOIN InformationRegister.AccountingPolicy.SliceLast AS AccountingPolicySliceLast
	|		ON Production.Products.Ref.Company = AccountingPolicySliceLast.Company
	|WHERE
	|	Production.Ref = &BasisDocument";
	
	Query.SetParameter("BasisDocument", FillingData);
	
	Products.Clear();
	Inventory.Clear();
	Disposals.Clear();
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		Selection = QueryResult.Select();
		Selection.Next();
		For Each SelectionMaterials In Selection[TSMaterials].Unload() Do
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, SelectionMaterials);
		EndDo;
		For Each SelectionProducts In Selection[TSProducts].Unload() Do
			NewRow = Products.Add();
			FillPropertyValues(NewRow, SelectionProducts);
		EndDo;
		For Each SelectionDisposals In Selection.Disposals.Unload() Do
			NewRow = Disposals.Add();
			FillPropertyValues(NewRow, SelectionDisposals);
		EndDo;
		
		WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, TSProducts);
		
	EndIf;
	
	// Filling out reserves.
	If Products.Count() > 0
		AND Constants.UseInventoryReservation.Get()
		AND ValueIsFilled(StructuralUnit) Then
		FillColumnReserveByReserves();
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	PrepaymentTotal = Prepayment.Total("PaymentAmount");
	TotalAmountProducts = Products.Total("Total");
	
	If Constants.UseInventoryReservation.Get() Then
		
		For Each StringProducts In Products Do
			
			If StringProducts.Reserve > StringProducts.Quantity Then
				
				MessageText = NStr("en = 'The number of items shipped from the reserve exceeds the total inventory quantity in row #%Number% of the ""Products"" tabular section.'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Products",
					StringProducts.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;	
			
		EndDo;	
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringProducts In Products Do
			// AutomaticDiscounts
			CurAmount = StringProducts.Price * StringProducts.Quantity;
			ManualDiscountCurAmount = ?(ThereAreManualDiscounts, ROUND(CurAmount * StringProducts.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount = ?(ThereAreAutomaticDiscounts, StringProducts.AutomaticDiscountAmount, 0);
			CurAmountDiscounts = ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			If StringProducts.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringProducts.Amount) Then
				MessageText = NStr("en = 'The ""Amount"" column in the %Number% line of the ""Products"" list is not populated.'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Products",
					StringProducts.LineNumber,
					"Amount",
					Cancel
				);
			EndIf;
		EndDo;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbers, StructuralUnit, ThisObject);
	
	//Payment calendar
	Amount = Products.Total("Amount");
	VATAmount = Products.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Filling(FillingData, StandardProcessing)
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.SalesOrder") Then
		FillBySalesOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("DocumentRef.Production") Then
		FillByProduction(FillingData);
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Products.Total("Total");
	
	FillSalesRep();
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SubcontractorReportIssued.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsReceivable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	// AutomaticDiscounts
	DriveServer.FlipAutomaticDiscountsApplied(AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorReportIssued.RunControl(Ref, AdditionalProperties, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorReportIssued.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

#EndRegion

#Region Private

Procedure FillSalesRep()
	
	SalesRep = Undefined;
	If ValueIsFilled(ShippingAddress) Then
		SalesRep = CommonUse.ObjectAttributeValue(ShippingAddress, "SalesRep");
	EndIf;
	If Not ValueIsFilled(SalesRep) Then
		SalesRep = CommonUse.ObjectAttributeValue(Counterparty, "SalesRep");
	EndIf;
	
	For Each CurrentRow In Products Do
		CurrentRow.SalesRep = SalesRep;
	EndDo;
	
EndProcedure



#EndRegion

#EndIf

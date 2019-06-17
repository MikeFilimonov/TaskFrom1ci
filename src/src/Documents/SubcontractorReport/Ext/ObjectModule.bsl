#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Procedure fills tabular section according to specification.
//
Procedure FillTabularSectionBySpecification(NodesBillsOfMaterialstack, NodesTable = Undefined) Export
	
	TempTablesManager = New TempTablesManager;
	
	TableProduction = New ValueTable;
	
	Array = New Array;
	Array.Add(Type("CatalogRef.BillsOfMaterials"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableProduction.Columns.Add("Specification", TypeDescription);
	
	Array.Add(Type("Number"));
	TypeDescription = New TypeDescription(Array, ,);
	Array.Clear();
	TableProduction.Columns.Add("Quantity", TypeDescription);
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
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
		
		NewProducts = TableProduction.Add();
		NewProducts.Specification = Specification;
		NewProducts.Quantity = Quantity;
		
		Array = New Array();
		Array.Add(Type("Number"));
		TypeDescriptionC = New TypeDescription(Array, , ,New NumberQualifiers(10,3));
		TableProduction.Columns.Add("Factor", TypeDescriptionC);
		
		If ValueIsFilled(MeasurementUnit)
			AND TypeOf(MeasurementUnit) = Type("CatalogRef.UOM") Then
			NewProducts.Factor = MeasurementUnit.Factor;
		Else
			NewProducts.Factor = 1;
		EndIf;
			
		NodesTable = TableProduction.CopyColumns("Quantity,Factor,Specification");
		Query.SetParameter("TableProduction", TableProduction);
	Else
		Query.SetParameter("TableProduction", NodesTable);
	EndIf;
	
	Query.Execute();
	
	Query.Text =
	"SELECT
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
	|	TableMaterials.Specification,
	|	CASE
	|		WHEN UseCharacteristics.Value
	|			THEN TableMaterials.Characteristic
	|		ELSE VALUE(Catalog.ProductsCharacteristics.EmptyRef)
	|	END
	|
	|ORDER BY
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
		EndIf;
	EndDo;
	
	NodesBillsOfMaterialstack.Clear();
	
EndProcedure

#Region Filling

// Procedure fills advances.
//
Procedure FillPrepayment() Export
	
	ParentCompany = DriveServer.GetCompany(Company);
	
	// Filling prepayment details.
	Query = New Query;
	
	QueryText =
	"SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency AS SettlementsCurrency,
	|	SUM(AccountsPayableBalances.AmountBalance) AS AmountBalance,
	|	SUM(AccountsPayableBalances.AmountCurBalance) AS AmountCurBalance
	|INTO TemporaryTableAccountsPayableBalances
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.Contract AS Contract,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.Document.Date AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AmountBalance,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS AmountCurBalance
	|	FROM
	|		AccumulationRegister.AccountsPayable.Balance(
	|				,
	|				Company = &Company
	|					AND Counterparty = &Counterparty
	|					AND Contract = &Contract
	|					AND Order = &Order
	|					AND SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsVendorSettlements.Contract,
	|		DocumentRegisterRecordsVendorSettlements.Document,
	|		DocumentRegisterRecordsVendorSettlements.Document.Date,
	|		DocumentRegisterRecordsVendorSettlements.Order,
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
	|		AND DocumentRegisterRecordsVendorSettlements.Contract = &Contract
	|		AND DocumentRegisterRecordsVendorSettlements.Order = &Order
	|		AND DocumentRegisterRecordsVendorSettlements.SettlementsType = VALUE(Enum.SettlementsTypes.Advance)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.Contract.SettlementsCurrency
	|
	|HAVING
	|	SUM(AccountsPayableBalances.AmountCurBalance) < 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT ALLOWED
	|	AccountsPayableBalances.Document AS Document,
	|	AccountsPayableBalances.Order AS Order,
	|	AccountsPayableBalances.DocumentDate AS DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|	-SUM(AccountsPayableBalances.AccountingAmount) AS AccountingAmount,
	|	-SUM(AccountsPayableBalances.SettlementsAmount) AS SettlementsAmount,
	|	-SUM(AccountsPayableBalances.PaymentAmount) AS PaymentAmount,
	|	SUM(AccountsPayableBalances.AccountingAmount / CASE
	|			WHEN ISNULL(AccountsPayableBalances.SettlementsAmount, 0) <> 0
	|				THEN AccountsPayableBalances.SettlementsAmount
	|			ELSE 1
	|		END) * (AccountsPayableBalances.SettlementsCurrencyExchangeRatesRate / AccountsPayableBalances.SettlementsCurrencyExchangeRatesMultiplicity) AS ExchangeRate,
	|	1 AS Multiplicity,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesRate AS DocumentCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesMultiplicity AS DocumentCurrencyExchangeRatesMultiplicity
	|FROM
	|	(SELECT
	|		AccountsPayableBalances.SettlementsCurrency AS SettlementsCurrency,
	|		AccountsPayableBalances.Document AS Document,
	|		AccountsPayableBalances.DocumentDate AS DocumentDate,
	|		AccountsPayableBalances.Order AS Order,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) AS AccountingAmount,
	|		ISNULL(AccountsPayableBalances.AmountCurBalance, 0) AS SettlementsAmount,
	|		ISNULL(AccountsPayableBalances.AmountBalance, 0) * SettlementsCurrencyExchangeRates.ExchangeRate * &MultiplicityOfDocumentCurrency / (&DocumentCurrencyRate * SettlementsCurrencyExchangeRates.Multiplicity) AS PaymentAmount,
	|		SettlementsCurrencyExchangeRates.ExchangeRate AS SettlementsCurrencyExchangeRatesRate,
	|		SettlementsCurrencyExchangeRates.Multiplicity AS SettlementsCurrencyExchangeRatesMultiplicity,
	|		&DocumentCurrencyRate AS DocumentCurrencyExchangeRatesRate,
	|		&MultiplicityOfDocumentCurrency AS DocumentCurrencyExchangeRatesMultiplicity
	|	FROM
	|		TemporaryTableAccountsPayableBalances AS AccountsPayableBalances
	|			LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&Period, Currency = &PresentationCurrency) AS SettlementsCurrencyExchangeRates
	|			ON (TRUE)) AS AccountsPayableBalances
	|
	|GROUP BY
	|	AccountsPayableBalances.Document,
	|	AccountsPayableBalances.Order,
	|	AccountsPayableBalances.DocumentDate,
	|	AccountsPayableBalances.SettlementsCurrency,
	|	AccountsPayableBalances.SettlementsCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.SettlementsCurrencyExchangeRatesMultiplicity,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesRate,
	|	AccountsPayableBalances.DocumentCurrencyExchangeRatesMultiplicity
	|
	|HAVING
	|	-SUM(AccountsPayableBalances.SettlementsAmount) > 0
	|
	|ORDER BY
	|	DocumentDate";
	
	If Counterparty.DoOperationsByOrders Then
		Query.SetParameter("Order", BasisDocument);
	Else
		Query.SetParameter("Order", Documents.PurchaseOrder.EmptyRef());
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
	AmountLeftToDistribute = Total;
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

// Procedure of filling the document on the basis of the supplier invoice.
//
// Parameters:
// BasisDocument - DocumentRef.SupplierInvoice - supplier
// invoice FillingData - Structure - Document filling data
//	
Procedure FillByPurchaseOrder(FillingData)
	
	// Header filling.
	BasisDocument = FillingData;
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData,
			New Structure("Company, Counterparty, Contract, SalesOrder, DocumentCurrency, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity, OrderState, Closed, Posted"));
	
	Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract, DocumentCurrency, AmountIncludesVAT, IncludeVATInPrice, ExchangeRate, Multiplicity");
	
	If Constants.UseInventoryReservation.Get() Then
		SalesOrder = AttributeValues.SalesOrder;
	EndIf;
	
	VATTaxation = DriveServer.VATTaxation(Company, ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	If Not DocumentCurrency = Constants.FunctionalCurrency.Get() Then
		StructureByCurrency = InformationRegisters.ExchangeRates.GetLast(?(ValueIsFilled(Date), Date, CurrentDate()), New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = StructureByCurrency.ExchangeRate;
		Multiplicity = StructureByCurrency.Multiplicity;
	EndIf;
	
	// Document filling.
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
	|		AccumulationRegister.PurchaseOrders.Balance(
	|				,
	|				PurchaseOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS OrdersBalance
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsPurchaseOrders.Products,
	|		DocumentRegisterRecordsPurchaseOrders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsPurchaseOrders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsPurchaseOrders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.PurchaseOrders AS DocumentRegisterRecordsPurchaseOrders
	|	WHERE
	|		DocumentRegisterRecordsPurchaseOrders.Recorder = &Ref) AS OrdersBalance
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
	|	MIN(PurchaseOrderInventory.LineNumber) AS LineNumber,
	|	PurchaseOrderInventory.Products AS Products,
	|	PurchaseOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE PurchaseOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	PurchaseOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SUM(PurchaseOrderInventory.Quantity) AS Quantity
	|FROM
	|	Document.PurchaseOrder.Inventory AS PurchaseOrderInventory
	|WHERE
	|	PurchaseOrderInventory.Ref = &BasisDocument
	|	AND PurchaseOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	PurchaseOrderInventory.Products,
	|	PurchaseOrderInventory.Characteristic,
	|	PurchaseOrderInventory.MeasurementUnit,
	|	CASE
	|		WHEN VALUETYPE(PurchaseOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE PurchaseOrderInventory.MeasurementUnit.Factor
	|	END
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", FillingData);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("Ref", Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products,Characteristic");
	
	Inventory.Clear();
	If BalanceTable.Count() > 0 Then
		
		Selection = ResultsArray[1].Select();
		While Selection.Next() Do
			
			StructureForSearch = New Structure;
			StructureForSearch.Insert("Products", Selection.Products);
			StructureForSearch.Insert("Characteristic", Selection.Characteristic);
			
			BalanceRowsArray = BalanceTable.FindRows(StructureForSearch);
			If BalanceRowsArray.Count() = 0 Then
				Continue;
			EndIf;
			
			Products = Selection.Products;
			Characteristic = Selection.Characteristic;
			MeasurementUnit = Selection.MeasurementUnit;
			Specification = DriveServer.GetDefaultSpecification(Products, Characteristic);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			Else
				Quantity = Selection.Quantity;
			EndIf;
			
			Break;
			
		EndDo;
		
	EndIf;
	
	If ValueIsFilled(Specification) Then
		
		NodesBillsOfMaterialstack = New Array;
		FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
		
	EndIf;
	
EndProcedure

#EndRegion

#EndRegion

#Region EventHandlers

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
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If TypeOf(FillingData) = Type("DocumentRef.PurchaseOrder") Then
		FillByPurchaseOrder(FillingData);
	ElsIf TypeOf(FillingData) = Type("Structure") Then
		FillPropertyValues(ThisObject, FillingData);
	EndIf;
	
	WorkWithVAT.ForbidReverseChargeTaxationTypeDocumentGeneration(ThisObject);
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If ValueIsFilled(Expense)
	 OR ValueIsFilled(Total) Then
		
		CheckedAttributes.Add("Expense");
		CheckedAttributes.Add("Amount");
		
	EndIf;
	
	PrepaymentTotal = Prepayment.Total("PaymentAmount");
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbersInInputField(Cancel, ThisObject);
	
EndProcedure

// Procedure - event handler Posting object.
//
Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting.
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Document data initialization.
	Documents.SubcontractorReport.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of records sets.
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectProductRelease(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountsPayable(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesCashMethod(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUnallocatedExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpensesRetained(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	
	// SerialNumbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);

	// Record of the records sets.
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.SubcontractorReport.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.SubcontractorReport.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	Prepayment.Clear();
	
EndProcedure

#EndRegion

#EndIf

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers
	
Procedure OnCopy(CopiedObject)
	
	OrderState	= GetPurchaseOrderstate();
	Closed		= False;
	Event		= Documents.Event.EmptyRef();
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("DocumentRef.SalesOrder")]			= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.ProductionOrder")]	= "FillByProductionOrder";
	FillingStrategy[Type("DocumentRef.SupplierQuote")]		= "FillByRFQResponse";
	
	ExcludingProperties = "OrderState";
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, ExcludingProperties);
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("PurchaseOrderStatuses", "Completed") Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'You cannot make changes to a completed %1.'"), Ref);
		CommonUseClientServer.MessageToUser(MessageText,,,,);
		Return;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.ReceiptDate <> ReceiptDate Then
				TabularSectionRow.ReceiptDate = ReceiptDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		If Inventory.Count() > 0 Then
			ReceiptDate = Inventory[0].ReceiptDate;
		EndIf;
	EndIf;
	
	If ValueIsFilled(Counterparty)
	AND Not Counterparty.DoOperationsByContracts
	AND Not ValueIsFilled(Contract) Then
		Contract = Counterparty.ContractByDefault;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.PurchaseOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);

	// Control
	Documents.PurchaseOrder.RunControl(Ref, AdditionalProperties, Cancel);
	
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
	Documents.PurchaseOrder.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If Materials.Total("Reserve") > 0 Then
		
		For Each StringMaterials In Materials Do
		
			If StringMaterials.Reserve > 0 AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is required.'");
				DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If SetPaymentTerms
	   AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
	   
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		
	ElsIf SetPaymentTerms
	   AND CashAssetsType = Enums.CashAssetTypes.Cash Then
	   
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	Else
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PettyCash");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "BankAccount");
		
	EndIf;
	
	If SetPaymentTerms
	   AND PaymentCalendar.Count() = 1
	   AND Not ValueIsFilled(PaymentCalendar[0].PaymentDate) Then
		
		MessageText = NStr("en = 'The ""Payment date"" field is not filled in.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "PaymentDate", Cancel);
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "PaymentCalendar.PaymentDate");
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get()
		AND OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
		
		For Each StringMaterials In Materials Do
			
			If StringMaterials.Reserve > StringMaterials.Quantity Then
				
				MessageText = NStr("en = 'In row #%Number% of the ""Materials for processing"" tabular section quantity of the write-off items from reserve exceeds the total material quantity.'");
				MessageText = StrReplace(MessageText, "%Number%", StringMaterials.LineNumber);
				DriveServer.ShowMessageAboutError(
					ThisObject,
					MessageText,
					"Materials",
					StringMaterials.LineNumber,
					"Reserve",
					Cancel
				);
				
			EndIf;	
			
		EndDo;		
		
	EndIf;
	
	If Not Constants.UsePurchaseOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The ""Order state"" field is not filled. Specify state values in the accounting parameter settings.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	If ReceiptDatePosition = Enums.AttributeStationing.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ReceiptDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ReceiptDate"));
	EndIf;
	
	//Payment calendar
	Amount = Inventory.Total("Amount");
	VATAmount = Inventory.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillBySalesOrder(DocumentRefSalesOrder) Export
	
	If Not ValueIsFilled(DocumentRefSalesOrder) Then
		Return;
	EndIf;
	
	// Header filling.
	AttributeValues = CommonUse.ObjectAttributesValues(DocumentRefSalesOrder, 
	New Structure("Company, Ref, OperationKind, Start, ShipmentDate, OrderState, Posted"));
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(DocumentRefSalesOrder, AttributeValues);
	
	Company			= AttributeValues.Company;
	SalesOrder	= AttributeValues.Ref;
	ReceiptDate	= AttributeValues.ShipmentDate;
	
	// Tabular section filling.
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
	|		InventoryBalances.Products,
	|		InventoryBalances.Characteristic,
	|		-InventoryBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		PlacementBalances.Products,
	|		PlacementBalances.Characteristic,
	|		-PlacementBalances.QuantityBalance
	|	FROM
	|		AccumulationRegister.Backorders.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)) AS PlacementBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsBackorders.Products,
	|		DocumentRegisterRecordsBackorders.Characteristic,
	|		CASE
	|			WHEN DocumentRegisterRecordsBackorders.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN -ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|			ELSE ISNULL(DocumentRegisterRecordsBackorders.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Backorders AS DocumentRegisterRecordsBackorders
	|	WHERE
	|		DocumentRegisterRecordsBackorders.Recorder = &Ref
	|		AND DocumentRegisterRecordsBackorders.SalesOrder = &BasisDocument) AS OrdersBalance
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
	|	MIN(SalesOrderInventory.LineNumber) AS LineNumber,
	|	SalesOrderInventory.Products AS Products,
	|	SalesOrderInventory.Characteristic AS Characteristic,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END AS Factor,
	|	SalesOrderInventory.MeasurementUnit AS MeasurementUnit,
	|	SalesOrderInventory.ShipmentDate AS InventoryIncreaseDate,
	|	SalesOrderInventory.VATRate,
	|	SUM(SalesOrderInventory.Quantity) AS Quantity
	|FROM
	|	Document.SalesOrder.Inventory AS SalesOrderInventory
	|WHERE
	|	SalesOrderInventory.Ref = &BasisDocument
	|	AND SalesOrderInventory.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|
	|GROUP BY
	|	SalesOrderInventory.Products,
	|	SalesOrderInventory.Characteristic,
	|	SalesOrderInventory.MeasurementUnit,
	|	SalesOrderInventory.VATRate,
	|	CASE
	|		WHEN VALUETYPE(SalesOrderInventory.MeasurementUnit) = Type(Catalog.UOMClassifier)
	|			THEN 1
	|		ELSE SalesOrderInventory.MeasurementUnit.Factor
	|	END,
	|	SalesOrderInventory.ShipmentDate
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument", DocumentRefSalesOrder);
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
			
			NewRow = Inventory.Add();
			FillPropertyValues(NewRow, Selection);
			
			QuantityToWriteOff = Selection.Quantity * Selection.Factor;
			BalanceRowsArray[0].QuantityBalance = BalanceRowsArray[0].QuantityBalance - QuantityToWriteOff;
			If BalanceRowsArray[0].QuantityBalance < 0 Then
				
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
				
			EndIf;
			
			NewRow.ReceiptDate = Selection.InventoryIncreaseDate;
			If ReceiptDate <> NewRow.ReceiptDate Then
				ReceiptDatePositionAtHeader = False;
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
	// Payment calendar
	PaymentCalendar.Clear();
	
	Query = New Query;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentSessionDate()));
	Query.SetParameter("BasisDocument", DocumentRefSalesOrder);
	Query.Text = 
	"SELECT
	|	DATEADD(&Date, DAY, DATEDIFF(SalesOrderPaymentCalendar.Ref.Date, SalesOrderPaymentCalendar.PaymentDate, DAY)) AS PaymentDate,
	|	SalesOrderPaymentCalendar.PaymentPercentage AS PaymentPercentage,
	|	SalesOrderPaymentCalendar.PaymentAmount AS PaymentAmount,
	|	SalesOrderPaymentCalendar.PaymentVATAmount AS PaymentVATAmount
	|FROM
	|	Document.SalesOrder.PaymentCalendar AS SalesOrderPaymentCalendar
	|WHERE
	|	SalesOrderPaymentCalendar.Ref = &BasisDocument";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewLine = PaymentCalendar.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
EndProcedure

Procedure FillByProductionOrder(DocumentRefProductionOrder) Export
	
	BasisOperationKind = CommonUse.ObjectAttributeValue(DocumentRefProductionOrder, "OperationKind");
	
	If BasisOperationKind <> Enums.OperationTypesProductionOrder.Assembly
		AND BasisOperationKind <> Enums.OperationTypesProductionOrder.Disassembly
		Then
		Return;
	EndIf;
	
	Query = New Query(
	"SELECT
	|	ProductionOrder.Ref AS Order,
	|	ProductionOrder.Company AS Company,
	|	CASE
	|		WHEN UseInventoryReservation.Value
	|			THEN ProductionOrder.SalesOrder
	|		ELSE ProductionOrder.BasisDocument
	|	END AS SalesOrder,
	|	ProductionOrder.BasisDocument,
	|	ProductionOrder.Start AS ReceiptDate,
	|	ProductionOrder.Inventory.(
	|		Ref.Start AS ReceiptDate,
	|		Products,
	|		Characteristic,
	|		MeasurementUnit,
	|		Quantity,
	|		Products.VATRate AS VATRate
	|	) AS Inventory
	|FROM
	|	Document.ProductionOrder AS ProductionOrder,
	|	Constant.UseInventoryReservation AS UseInventoryReservation
	|WHERE
	|	ProductionOrder.Ref = &BasisDocument");
	
	If BasisOperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		Query.Text = StrReplace(
		Query.Text,
		"ProductionOrder.Inventory.(",
		"ProductionOrder.Products.(");
	EndIf;
	
	Query.SetParameter("BasisDocument", DocumentRefProductionOrder);
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	VATRate = Undefined;
	VATRateFromProducts = False;
	If VATTaxation = Enums.VATTaxationTypes.SubjectToVAT Then
		If VATTaxation = Enums.VATTaxationTypes.NotSubjectToVAT Then
			VATRate = Catalogs.VATRates.Exempt;
		Else
			VATRate = Catalogs.VATRates.ZeroRate;
		КонецЕсли;
	Else
		VATRateFromProducts = True;
		VATRate = InformationRegisters.AccountingPolicy.GetDefaultVATRate(Date, Company);
	EndIf;
	
	Inventory.Load(QueryResultSelection.Inventory.Unload());
	
	For Each RowInventory In Inventory Do
		If VATRateFromProducts Then
			If Not ValueIsFilled(RowInventory.VATRate) Then
				RowInventory.VATRate = VATRate;
			EndIf;
		Else
			RowInventory.VATRate = VATRate;
		EndIf;
	EndDo;
	
EndProcedure

Procedure FillByRFQResponse(DocumentRefRFQResponse) Export
	
	Query = New Query(
	"SELECT
	|	SupplierQuote.Ref AS RFQResponse,
	|	SupplierQuote.Company AS Company,
	|	SupplierQuote.Counterparty AS Counterparty,
	|	SupplierQuote.Contract AS Contract,
	|	SupplierQuote.CashAssetsType AS CashAssetsType,
	|	SupplierQuote.BankAccount AS BankAccount,
	|	SupplierQuote.DocumentCurrency AS DocumentCurrency,
	|	SupplierQuote.Multiplicity AS Multiplicity,
	|	SupplierQuote.ExchangeRate AS ExchangeRate,
	|	SupplierQuote.VATTaxation AS VATTaxation,
	|	SupplierQuote.AmountIncludesVAT AS AmountIncludesVAT,
	|	SupplierQuote.SupplierPriceTypes AS SupplierPriceTypes,
	|	SupplierQuote.PettyCash AS PettyCash,
	|	SupplierQuote.DocumentAmount AS DocumentAmount,
	|	SupplierQuote.Event AS Event,
	|	SupplierQuote.SetPaymentTerms AS SetPaymentTerms,
	|	SupplierQuote.Responsible AS Responsible,
	|	SupplierQuote.Inventory.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		Products AS Products,
	|		Characteristic AS Characteristic,
	|		Quantity AS Quantity,
	|		MeasurementUnit AS MeasurementUnit,
	|		Price AS Price,
	|		Amount AS Amount,
	|		VATRate AS VATRate,
	|		VATAmount AS VATAmount,
	|		Total AS Total,
	|		Content AS Content
	|	) AS Inventory,
	|	SupplierQuote.PaymentCalendar.(
	|		Ref AS Ref,
	|		LineNumber AS LineNumber,
	|		DATEADD(&Date, DAY, DATEDIFF(SupplierQuote.Date, SupplierQuote.PaymentCalendar.PaymentDate, DAY)) AS PaymentDate,
	|		PaymentPercentage AS PaymentPercentage,
	|		PaymentAmount AS PaymentAmount,
	|		PaymentVATAmount AS PaymentVATAmount
	|	) AS PaymentCalendar
	|FROM
	|	Document.SupplierQuote AS SupplierQuote
	|WHERE
	|	SupplierQuote.Ref = &BasisDocument");
	
	Query.SetParameter("BasisDocument", DocumentRefRFQResponse);
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	QueryResult = Query.Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	QueryResultSelection = QueryResult.Select();
	QueryResultSelection.Next();
	
	FillPropertyValues(ThisObject, QueryResultSelection);
	
	Inventory.Load(QueryResultSelection.Inventory.Unload());
	PaymentCalendar.Load(QueryResultSelection.PaymentCalendar.Unload());
	
EndProcedure

Procedure FillColumnReserveByBalances() Export
	
	Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	VALUE(Catalog.ProductsBatches.EmptyRef) AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory";
	
	Query.SetParameter("TableInventory", Materials.Unload());
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
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
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

Procedure FillByDefault()
	
	If Not ValueIsFilled(OrderState) Then
		OrderState = GetPurchaseOrderstate();
	EndIf;
	
	If Not ValueIsFilled(ReceiptDate) Then
		ReceiptDate = CurrentSessionDate();
	EndIf;
	
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
	
	TotalAmount = Inventory.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount");
	
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

#Region ServiceProceduresAndFunctions

Function GetPurchaseOrderstate()
	
	If Constants.UsePurchaseOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewPurchaseOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.PurchaseOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.PurchaseOrdersInProgressStatus.Get();
	EndIf;
	
	Return OrderState;
	
EndFunction

#EndRegion

#EndIf
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]					= "FillByStructure";
	FillingStrategy[Type("DocumentRef.SalesOrder")]		= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.PurchaseOrder")]	= "FillByPurchaseOrder";
	FillingStrategy[Type("DocumentRef.GoodsReceipt")]	= "FillByGoodsReceipt";
	FillingStrategy[Type("DocumentRef.SalesInvoice")]	= "FillBySalesInvoice";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "Order");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		CheckedAttributes.Add("Contract");
	Else
		CheckedAttributes.Add("Products.Contract");
	EndIf;
	
	If OperationType = Enums.OperationTypesGoodsIssue.ReturnToAThirdParty Then
		CheckedAttributes.Add("Products.Batch");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If SalesOrderPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Products Do
			TabularSectionRow.Order = Order;
			TabularSectionRow.Contract = Contract;
		EndDo;
	Else
		Order = Undefined;
		Contract = Undefined;
	EndIf;
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
	FillSalesRep();
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsIssueDocumentPostingInitialization");
	
	Documents.GoodsIssue.InitializeDocumentData(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsIssueDocumentPostingMovementsCreation");
	
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsShippedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsInvoicedNotShipped(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectIncomeAndExpenses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSales(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);

	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);

	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsIssueDocumentPostingMovementsRecord");
	
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsIssueDocumentPostingControl");
	
	Documents.GoodsIssue.RunControl(Ref, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	Documents.GoodsIssue.RunControl(Ref, AdditionalProperties, Cancel, True);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillBySalesOrder(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesOrders") Then
		OrdersArray = FillingData.ArrayOfSalesOrders;
	Else
		OrdersArray = New Array;
		OrdersArray.Add(FillingData);
		Order = FillingData;
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	SalesOrder.Ref AS BasisRef,
	|	SalesOrder.Posted AS BasisPosted,
	|	SalesOrder.Closed AS Closed,
	|	SalesOrder.OrderState AS OrderState,
	|	SalesOrder.Company AS Company,
	|	SalesOrder.StructuralUnitReserve AS StructuralUnit,
	|	SalesOrder.Counterparty AS Counterparty,
	|	SalesOrder.Contract AS Contract,
	|	SalesOrder.ShippingAddress AS ShippingAddress,
	|	SalesOrder.ContactPerson AS ContactPerson,
	|	SalesOrder.Incoterms AS Incoterms,
	|	SalesOrder.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	SalesOrder.DeliveryTimeTo AS DeliveryTimeTo,
	|	SalesOrder.GoodsMarking AS GoodsMarking,
	|	SalesOrder.LogisticsCompany AS LogisticsCompany,
	|	SalesOrder.DeliveryOption AS DeliveryOption
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref IN(&OrdersArray)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TT_SalesOrders.BasisRef AS BasisRef,
	|	TT_SalesOrders.BasisPosted AS BasisPosted,
	|	TT_SalesOrders.Closed AS Closed,
	|	TT_SalesOrders.OrderState AS OrderState,
	|	TT_SalesOrders.Company AS Company,
	|	TT_SalesOrders.StructuralUnit AS StructuralUnit,
	|	TT_SalesOrders.Counterparty AS Counterparty,
	|	TT_SalesOrders.Contract AS Contract,
	|	TT_SalesOrders.ShippingAddress AS ShippingAddress,
	|	TT_SalesOrders.ContactPerson AS ContactPerson,
	|	TT_SalesOrders.Incoterms AS Incoterms,
	|	TT_SalesOrders.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	TT_SalesOrders.DeliveryTimeTo AS DeliveryTimeTo,
	|	TT_SalesOrders.GoodsMarking AS GoodsMarking,
	|	TT_SalesOrders.LogisticsCompany AS LogisticsCompany,
	|	TT_SalesOrders.DeliveryOption AS DeliveryOption
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	GoodsInvoicedNotShipped.SalesInvoice AS SalesInvoice
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN AccumulationRegister.GoodsInvoicedNotShipped AS GoodsInvoicedNotShipped
	|		ON TT_SalesOrders.BasisRef = GoodsInvoicedNotShipped.SalesOrder";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	QueryResults = Query.ExecuteBatch();
	
	Selection = QueryResults[1].Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted",
			Selection.OrderState,
			Selection.Closed,
			Selection.BasisPosted);
		Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(Selection.BasisRef, VerifiedAttributesValues);
	EndDo;
	
	FillPropertyValues(ThisObject, Selection);
	
	If Not ValueIsFilled(StructuralUnit) Then
		SettingValue = DriveReUse.GetValueOfSetting("MainWarehouse");
		If Not ValueIsFilled(SettingValue) Then
			StructuralUnit = Catalogs.BusinessUnits.MainWarehouse;
		EndIf;
	EndIf;
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	Documents.GoodsIssue.FillBySalesOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Products);
	
	InvoicesArray = QueryResults[2].Unload().UnloadColumn("SalesInvoice");
	If InvoicesArray.Count() Then
		
		InvoicedProducts = Products.UnloadColumns();
		Documents.GoodsIssue.FillBySalesInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), InvoicedProducts);
		
		For Each InvoicedProductsRow In InvoicedProducts Do
			If Not OrdersArray.Find(InvoicedProductsRow.Order) = Undefined Then
				FillPropertyValues(Products.Add(), InvoicedProductsRow);
			EndIf;
		EndDo;
		
	EndIf;
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() > 0 Then
		Order = OrdersTable[0].Order;
		Contract = OrdersTable[0].Contract;
	EndIf;
	
	If Products.Count() = 0 Then
		If OrdersArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 has already been shipped.'"),
				Order);
		Else
			MessageText = NStr("en = 'The selected orders have already been shipped.'");
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillBySalesInvoice(FillingData) Export
	
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("ArrayOfSalesInvoices") Then
		InvoicesArray = FillingData.ArrayOfSalesInvoices;
	Else
		InvoicesArray = New Array;
		InvoicesArray.Add(FillingData);
	EndIf;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SalesInvoice.Ref AS BasisRef,
	|	SalesInvoice.Posted AS BasisPosted,
	|	SalesInvoice.Company AS Company,
	|	SalesInvoice.StructuralUnit AS StructuralUnit,
	|	SalesInvoice.Counterparty AS Counterparty,
	|	SalesInvoice.Contract AS Contract,
	|	SalesInvoice.ShippingAddress AS ShippingAddress,
	|	SalesInvoice.ContactPerson AS ContactPerson,
	|	SalesInvoice.Incoterms AS Incoterms,
	|	SalesInvoice.DeliveryTimeFrom AS DeliveryTimeFrom,
	|	SalesInvoice.DeliveryTimeTo AS DeliveryTimeTo,
	|	SalesInvoice.GoodsMarking AS GoodsMarking,
	|	SalesInvoice.LogisticsCompany AS LogisticsCompany,
	|	SalesInvoice.DeliveryOption AS DeliveryOption
	|FROM
	|	Document.SalesInvoice AS SalesInvoice
	|WHERE
	|	SalesInvoice.Ref IN(&InvoicesArray)";
	
	Query.SetParameter("InvoicesArray", InvoicesArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Selection = Query.Execute().Select();
	Selection.Next();
	
	FillPropertyValues(ThisObject, Selection);
	
	DocumentData = New Structure;
	DocumentData.Insert("Ref", Ref);
	DocumentData.Insert("Company", Company);
	DocumentData.Insert("StructuralUnit", StructuralUnit);
	
	Documents.GoodsIssue.FillBySalesInvoices(DocumentData, New Structure("InvoicesArray", InvoicesArray), Products);
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		SalesOrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		SalesOrderPosition = DriveReUse.GetValueOfSetting("SalesOrderPositionInShipmentDocuments");
		If Not ValueIsFilled(SalesOrderPosition) Then
			SalesOrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If SalesOrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) AND OrdersTable.Count() > 0 Then
		Order = OrdersTable[0].Order;
		Contract = OrdersTable[0].Contract;
	EndIf;
	
	If Products.Count() = 0 Then
		If InvoicesArray.Count() = 1 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 has already been shipped.'"),
				InvoicesArray[0]);
		Else
			MessageText = NStr("en = 'The selected invoices have already been shipped.'");
		EndIf;
		CommonUseClientServer.MessageToUser(MessageText, Ref);
	EndIf;
	
EndProcedure

Procedure FillByPurchaseOrder(FillingData) Export
	
	If DriveReUse.AttributeInHeader("SalesOrderPositionInShipmentDocuments") Then
		Order = FillingData.Ref;
	Else
		Order = Undefined;
	EndIf;
	
	// Header filling.
	AttributeValues = CommonUse.GetAttributeValues(FillingData,
			New Structure("Company, OperationKind, StructuralUnitReserve, Counterparty, Contract, OrderState, Closed, Posted"));
			
	AttributeValues.Insert("GoodsIssue");
	Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract");
	
	// Tabular section filling.
	Products.Clear();
	If FillingData.OperationKind = Enums.OperationTypesPurchaseOrder.OrderForProcessing Then
		OperationType	= Enums.OperationTypesGoodsIssue.TransferToAThirdParty;
		StructuralUnit	= AttributeValues.StructuralUnitReserve;
		FillByPurchaseOrderForProcessing(FillingData);
	EndIf;
	
EndProcedure

Procedure FillByPurchaseOrderForProcessing(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	MIN(OrdersBalance.LineNumber) AS LineNumber,
	|	CASE
	|		WHEN OrdersBalance.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END AS ProductsTypeInventory,
	|	OrdersBalance.Products AS Products,
	|	OrdersBalance.Characteristic AS Characteristic,
	|	OrdersBalance.MeasurementUnit AS MeasurementUnit,
	|	OrdersBalance.Order AS Order,
	|	SUM(OrdersBalance.Quantity) AS Quantity
	|FROM
	|	(SELECT
	|		PurchaseOrderMaterials.LineNumber AS LineNumber,
	|		PurchaseOrderMaterials.Products AS Products,
	|		PurchaseOrderMaterials.Characteristic AS Characteristic,
	|		PurchaseOrderMaterials.MeasurementUnit AS MeasurementUnit,
	|		PurchaseOrderMaterials.Ref AS Order,
	|		PurchaseOrderMaterials.Quantity AS Quantity
	|	FROM
	|		Document.PurchaseOrder.Materials AS PurchaseOrderMaterials
	|	WHERE
	|		PurchaseOrderMaterials.Ref = &BasisDocument
	|		AND PurchaseOrderMaterials.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SupplierInvoiceInventory.LineNumber,
	|		SupplierInvoiceInventory.Products,
	|		SupplierInvoiceInventory.Characteristic,
	|		SupplierInvoiceInventory.MeasurementUnit,
	|		SupplierInvoiceInventory.Order,
	|		SupplierInvoiceInventory.Quantity
	|	FROM
	|		Document.GoodsReceipt.Products AS SupplierInvoiceInventory
	|	WHERE
	|		SupplierInvoiceInventory.Ref.Posted
	|		AND SupplierInvoiceInventory.Ref.OperationType = VALUE(Enum.OperationTypesGoodsReceipt.ReturnFromAThirdParty)
	|		AND SupplierInvoiceInventory.Order = &BasisDocument
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		SalesInvoiceInventory.LineNumber,
	|		SalesInvoiceInventory.Products,
	|		SalesInvoiceInventory.Characteristic,
	|		SalesInvoiceInventory.MeasurementUnit,
	|		SalesInvoiceInventory.Order,
	|		-SalesInvoiceInventory.Quantity
	|	FROM
	|		Document.GoodsIssue.Products AS SalesInvoiceInventory
	|	WHERE
	|		SalesInvoiceInventory.Ref.Posted
	|		AND SalesInvoiceInventory.Ref.OperationType = VALUE(Enum.OperationTypesGoodsIssue.TransferToAThirdParty)
	|		AND SalesInvoiceInventory.Order = &BasisDocument
	|		AND NOT SalesInvoiceInventory.Ref = &Ref) AS OrdersBalance
	|
	|GROUP BY
	|	CASE
	|		WHEN OrdersBalance.Products.ProductsType = VALUE(Enum.ProductsTypes.InventoryItem)
	|			THEN TRUE
	|		ELSE FALSE
	|	END,
	|	OrdersBalance.Products,
	|	OrdersBalance.Characteristic,
	|	OrdersBalance.MeasurementUnit,
	|	OrdersBalance.Order
	|
	|HAVING
	|	SUM(OrdersBalance.Quantity) > 0";
	
	Query.SetParameter("BasisDocument",	FillingData);
	Query.SetParameter("Ref",			Ref);
	
	QueryResult = Query.Execute();
	Products.Load(QueryResult.Unload());
	
EndProcedure

Procedure FillByGoodsReceipt(FillingData) Export
	
	Company			= FillingData.Company;
	Counterparty	= FillingData.Counterparty;
	Contract		= FillingData.Contract;
	StructuralUnit	= FillingData.StructuralUnit;
	Cell			= FillingData.Cell;
	OperationType	= Enums.OperationTypesGoodsIssue.ReturnToAThirdParty;
	
	StructureData = New Structure;
	ObjectParameters = New Structure;
	ObjectParameters.Insert("Company", Company);
	ObjectParameters.Insert("StructuralUnit", StructuralUnit);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	
	Products.Clear();
	For Each TabularSectionRow In FillingData.Products Do
		
		NewRow = Products.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		NewRow.Order = Undefined;
	EndDo;

	GLAccountsInDocuments.FillTabSectionFromProductGLAccounts(ThisObject, FillingData);
	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, "Products");

EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("ArrayOfSalesOrders") Then
		FillBySalesOrder(FillingData);
	EndIf;
	If FillingData.Property("ArrayOfSalesInvoices") Then
		FillBySalesInvoice(FillingData);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("GoodsMarking",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

Procedure FillSalesRep()
	
	SalesRep = Undefined;
	If ValueIsFilled(ShippingAddress) Then
		SalesRep = CommonUse.ObjectAttributeValue(ShippingAddress, "SalesRep");
	EndIf;
	If Not ValueIsFilled(SalesRep) Then
		SalesRep = CommonUse.ObjectAttributeValue(Counterparty, "SalesRep");
	EndIf;
	
	For Each CurrentRow In Products Do
		If ValueIsFilled(CurrentRow.SalesInvoice)
			And ValueIsFilled(CurrentRow.SalesRep) Then
			Continue;
		ElsIf ValueIsFilled(CurrentRow.Order)
			And CurrentRow.Order <> Order Then
			CurrentRow.SalesRep = CommonUse.ObjectAttributeValue(CurrentRow.Order, "SalesRep");
		Else
			CurrentRow.SalesRep = SalesRep;
		EndIf;
	EndDo;
	
EndProcedure
		
#EndRegion

#EndIf
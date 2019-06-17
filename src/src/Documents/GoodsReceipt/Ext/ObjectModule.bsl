#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure Filling(FillingData, FillingText, StandardProcessing) Export
	
	FillingStrategy = New Map;
	FillingStrategy[Type("Structure")]					= "FillByStructure";
	FillingStrategy[Type("DocumentRef.PurchaseOrder")]	= "FillByPurchaseOrder";
	FillingStrategy[Type("DocumentRef.SalesOrder")]		= "FillBySalesOrder";
	FillingStrategy[Type("DocumentRef.GoodsIssue")]		= "FillByGoodsIssue";
	
	ObjectFillingDrive.FillDocument(ThisObject, FillingData, FillingStrategy, "Order");
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If OrderPosition = Enums.AttributeStationing.InHeader Then
		CheckedAttributes.Add("Contract");
	Else
		CheckedAttributes.Add("Products.Contract");
	EndIf;
	
	// Serial numbers
	WorkWithSerialNumbers.FillCheckingSerialNumbers(Cancel, Products, SerialNumbers, StructuralUnit, ThisObject);
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If OrderPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Products Do
			TabularSectionRow.Order = Order;
			TabularSectionRow.Contract = Contract;
		EndDo;
	Else
		Order = Undefined;
		Contract = Undefined;
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReceiptDocumentPostingInitialization");
	
	Documents.GoodsReceipt.InitializeDocumentData(Ref, AdditionalProperties);
	
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Account for in accounting sections.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReceiptDocumentPostingMovementsCreation");
	
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryInWarehouses(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPurchaseOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectGoodsReceivedNotInvoiced(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryAccepted(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectStockTransferredToThirdParties(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectAccountingJournalEntries(AdditionalProperties, RegisterRecords, Cancel);

	// Serial numbers
	DriveServer.ReflectTheSerialNumbersOfTheGuarantee(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectTheSerialNumbersBalance(AdditionalProperties, RegisterRecords, Cancel);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);

	// Record of the records sets.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReceiptDocumentPostingMovementsRecord");
	
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control of occurrence of a negative balance.
	PerformanceEstimationClientServer.StartTimeMeasurement("GoodsReceiptDocumentPostingControl");
	
	Documents.GoodsReceipt.RunControl(Ref, AdditionalProperties, Cancel);

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
	Documents.GoodsReceipt.RunControl(Ref, AdditionalProperties, Cancel, True);
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillByPurchaseOrder(FillingData) Export
	
	// Document basis and document setting.
	OrdersArray = New Array;
	If TypeOf(FillingData) = Type("Structure") AND FillingData.Property("OrdersArray") Then
		OrdersArray = FillingData.OrdersArray;
	Else
		OrdersArray.Add(FillingData.Ref);
		Order = FillingData;
	EndIf;
	
	// Header filling.
	Query = New Query;
	Query.Text =
	"SELECT
	|	PurchaseOrder.Ref AS BasisRef,
	|	PurchaseOrder.Posted AS BasisPosted,
	|	PurchaseOrder.Closed AS Closed,
	|	PurchaseOrder.OrderState AS OrderState,
	|	PurchaseOrder.Company AS Company,
	|	PurchaseOrder.StructuralUnitReserve AS StructuralUnit,
	|	PurchaseOrder.Counterparty AS Counterparty,
	|	PurchaseOrder.Contract AS Contract
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	PurchaseOrder.Ref IN(&OrdersArray)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Query.SetParameter("DocumentDate", ?(ValueIsFilled(Date), Date, CurrentDate()));
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		VerifiedAttributesValues = New Structure("OrderState, Closed, Posted", Selection.OrderState, Selection.Closed, Selection.BasisPosted);
		Documents.PurchaseOrder.CheckEnteringAbilityOnTheBasisOfVendorOrder(Selection.BasisRef, VerifiedAttributesValues);
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
	
	Documents.GoodsReceipt.FillByPurchaseOrders(DocumentData, New Structure("OrdersArray", OrdersArray), Products);
	
	DiscountsAreCalculated = False;
	
	OrdersTable = Products.Unload(, "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	If OrdersTable.Count() > 1 Then
		OrderPosition = Enums.AttributeStationing.InTabularSection;
	Else
		OrderPosition = DriveReUse.GetValueOfSetting("PurchaseOrderPositionInReceiptDocuments");
		If Not ValueIsFilled(OrderPosition) Then
			OrderPosition = Enums.AttributeStationing.InHeader;
		EndIf;
	EndIf;
	
	If OrderPosition = Enums.AttributeStationing.InTabularSection Then
		Order = Undefined;
		Contract = Undefined;
	ElsIf Not ValueIsFilled(Order) Then
		
		If OrdersTable.Count() > 0 Then
			Order = OrdersTable[0].Order;
			Contract = OrdersTable[0].Contract;
		ElsIf OrdersArray.Count() > 0 Then
			Order = OrdersArray[0];
		EndIf;
		
	EndIf;
	
	If Products.Count() = 0 Then
		CommonUseClientServer.MessageToUser(
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'The %1 is completely delivered before'"),
				Order),
			Ref);
	EndIf;
	
EndProcedure

Procedure FillBySalesOrder(FillingData) Export
	
	Order = FillingData;
	
	AttributeValues = CommonUse.ObjectAttributesValues(FillingData, 
			New Structure("Company, Ref, OperationKind, Counterparty, Contract, OrderState, Closed, Posted"));
	
	AttributeValues.Insert("WorkOrderReturn");
	AttributeValues.Insert("GoodsReceipt");
	
	Documents.SalesOrder.CheckAbilityOfEnteringBySalesOrder(FillingData, AttributeValues);
	
	FillPropertyValues(ThisObject, AttributeValues, "Company, Counterparty, Contract");
	
	Products.Clear();
	If AttributeValues.OperationKind = Enums.OperationTypesSalesOrder.OrderForProcessing Then
		OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty;
		FillBySalesOrderForProcessing(FillingData);
	EndIf;
	
EndProcedure

Procedure FillBySalesOrderForProcessing(FillingData)
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	DemandBalances.Products AS Products,
	|	DemandBalances.Characteristic AS Characteristic,
	|	SUM(DemandBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		DemandBalances.Products AS Products,
	|		DemandBalances.Characteristic AS Characteristic,
	|		DemandBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.InventoryDemand.Balance(
	|				,
	|				SalesOrder = &BasisDocument
	|					AND MovementType = VALUE(Enum.InventoryMovementTypes.Receipt)) AS DemandBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
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
	|		AND DocumentRegisterRecordsInventoryDemand.SalesOrder = &BasisDocument) AS DemandBalances
	|
	|GROUP BY
	|	DemandBalances.Products,
	|	DemandBalances.Characteristic
	|
	|HAVING
	|	SUM(DemandBalances.QuantityBalance) > 0
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	SalesOrder.Ref AS Ref,
	|	SalesOrder.Company AS Company
	|INTO TT_SalesOrders
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	SalesOrder.Ref = &BasisDocument
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	MIN(SalesOrderConsumerMaterials.LineNumber) AS LineNumber,
	|	SalesOrderConsumerMaterials.Products AS Products,
	|	SalesOrderConsumerMaterials.Characteristic AS Characteristic,
	|	SalesOrderConsumerMaterials.MeasurementUnit AS MeasurementUnit,
	|	ISNULL(UOM.Factor, 1) AS Factor,
	|	SalesOrderConsumerMaterials.Ref AS Order,
	|	SUM(SalesOrderConsumerMaterials.Quantity) AS Quantity
	|FROM
	|	TT_SalesOrders AS TT_SalesOrders
	|		INNER JOIN Document.SalesOrder.ConsumerMaterials AS SalesOrderConsumerMaterials
	|		ON TT_SalesOrders.Ref = SalesOrderConsumerMaterials.Ref
	|		INNER JOIN Catalog.Products AS ProductsCatalog
	|		ON (SalesOrderConsumerMaterials.Products = ProductsCatalog.Ref)
	|		LEFT JOIN Catalog.UOM AS UOM
	|		ON (SalesOrderConsumerMaterials.MeasurementUnit = UOM.Ref)
	|
	|GROUP BY
	|	SalesOrderConsumerMaterials.Products,
	|	SalesOrderConsumerMaterials.Characteristic,
	|	SalesOrderConsumerMaterials.MeasurementUnit,
	|	ISNULL(UOM.Factor, 1),
	|	SalesOrderConsumerMaterials.Ref
	|
	|ORDER BY
	|	LineNumber";
	
	Query.SetParameter("BasisDocument",	FillingData);
	Query.SetParameter("Ref",			Ref);
	
	ResultsArray = Query.ExecuteBatch();
	BalanceTable = ResultsArray[0].Unload();
	BalanceTable.Indexes.Add("Products, Characteristic");
	
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
				NewRow.Quantity = (QuantityToWriteOff + BalanceRowsArray[0].QuantityBalance) / Selection.Factor;
			EndIf;
			
			If BalanceRowsArray[0].QuantityBalance <= 0 Then
				BalanceTable.Delete(BalanceRowsArray[0]);
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillByGoodsIssue(FillingData) Export
	
	Company			= FillingData.Company;
	Counterparty	= FillingData.Counterparty;
	Contract		= FillingData.Contract;
	StructuralUnit	= FillingData.StructuralUnit;
	Cell			= FillingData.Cell;
	OperationType	= Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty;
	
	Products.Clear();
	For Each TabularSectionRow In FillingData.Products Do
		
		NewRow = Products.Add();
		FillPropertyValues(NewRow, TabularSectionRow);
		
		NewRow.Order = Undefined;
		
	EndDo;

	WorkWithSerialNumbers.FillTSSerialNumbersByConnectionKey(ThisObject, FillingData, "Products");
	
EndProcedure

Procedure FillByStructure(FillingData) Export
	
	If FillingData.Property("OrdersArray") Then
		FillByPurchaseOrder(FillingData);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
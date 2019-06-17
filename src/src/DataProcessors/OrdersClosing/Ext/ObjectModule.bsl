
Procedure CloseOrders() Export
	
	CompleteSalesOrders();
	CompletePurchaseOrders();
	CompleteProductionOrders();
	CompleteWorkOrders();
	
EndProcedure

Procedure FillOrders(Parameters) Export
	
	If Parameters.Property("PurposeUseKey") Then
		ShowSalesOrders = (Parameters.PurposeUseKey = "SalesOrders");
		ShowPurchaseOrders = (Parameters.PurposeUseKey = "PurchaseOrders");
		ShowProductionOrders = (Parameters.PurposeUseKey = "ProductionOrders");
		ShowWorkOrders = (Parameters.PurposeUseKey = "WorkOrders");
	EndIf;
		
	SalesOrders.Clear();
	PurchaseOrders.Clear();
	ProductionOrders.Clear();
	WorkOrders.Clear();
	
	SalesOrdersArray = Undefined;
	SalesOrdersArray = Undefined;
	ProductionOrdersArray = Undefined;
	WorkOrdersArray = Undefined;
	
	If Parameters.Property("SalesOrders", SalesOrdersArray) Then
		For Each Order In SalesOrdersArray Do
			If Not Order.Closed Then
				TableRow = SalesOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("PurchaseOrders", SalesOrdersArray) Then
		For Each Order In SalesOrdersArray Do
			If Not Order.Closed Then
				TableRow = PurchaseOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("ProductionOrders", ProductionOrdersArray) Then
		For Each Order In ProductionOrdersArray Do
			If Not Order.Closed Then
				TableRow = ProductionOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	ElsIf Parameters.Property("WorkOrders", WorkOrdersArray) Then
		For Each Order In WorkOrdersArray Do
			If Not Order.Closed Then
				TableRow = WorkOrders.Add();
				TableRow.Order = Order;
				TableRow.Mark = True;
			EndIf;
		EndDo;
	Else
		Query = New Query;
		Query.Text = 
		"SELECT
		|	SalesOrder.Ref AS Order,
		|	SalesOrder.OrderState AS Status
		|INTO SalesOrders
		|FROM
		|	Document.SalesOrder AS SalesOrder
		|WHERE
		|	SalesOrder.Posted
		|	AND NOT SalesOrder.Closed
		|	AND &ShowSalesOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseOrder.Ref AS Order,
		|	PurchaseOrder.OrderState AS Status
		|INTO PurchaseOrders
		|FROM
		|	Document.PurchaseOrder AS PurchaseOrder
		|WHERE
		|	PurchaseOrder.Posted
		|	AND NOT PurchaseOrder.Closed
		|	AND &ShowPurchaseOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductionOrder.Ref AS Order,
		|	ProductionOrder.OrderState AS Status
		|INTO ProductionOrders
		|FROM
		|	Document.ProductionOrder AS ProductionOrder
		|WHERE
		|	ProductionOrder.Posted
		|	AND NOT ProductionOrder.Closed
		|	AND &ShowProductionOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrder.Ref AS Order,
		|	WorkOrder.OrderState AS Status
		|INTO WorkOrders
		|FROM
		|	Document.WorkOrder AS WorkOrder
		|WHERE
		|	WorkOrder.Posted
		|	AND NOT WorkOrder.Closed
		|	AND &ShowWorkOrders
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	SalesOrders.Order AS Order,
		|	SalesOrders.Status AS Status
		|FROM
		|	SalesOrders AS SalesOrders
		|		INNER JOIN Catalog.SalesOrderStatuses AS SalesOrderStatuses
		|		ON SalesOrders.Status = SalesOrderStatuses.Ref
		|			AND (SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	PurchaseOrders.Order AS Order,
		|	PurchaseOrders.Status AS Status
		|FROM
		|	PurchaseOrders AS PurchaseOrders
		|		INNER JOIN Catalog.PurchaseOrderStatuses AS PurchaseOrderStatuses
		|		ON PurchaseOrders.Status = PurchaseOrderStatuses.Ref
		|			AND (PurchaseOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	ProductionOrders.Order AS Order,
		|	ProductionOrders.Status AS Status
		|FROM
		|	ProductionOrders AS ProductionOrders
		|		INNER JOIN Catalog.ProductionOrderStatuses AS ProductionOrderStatuses
		|		ON ProductionOrders.Status = ProductionOrderStatuses.Ref
		|			AND (ProductionOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))
		|;
		|
		|////////////////////////////////////////////////////////////////////////////////
		|SELECT
		|	WorkOrders.Order AS Order,
		|	WorkOrders.Status AS Status
		|FROM
		|	WorkOrders AS WorkOrders
		|		INNER JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|		ON WorkOrders.Status = WorkOrderStatuses.Ref
		|			AND (WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess))";
		
		Query.SetParameter("ShowSalesOrders", ShowSalesOrders);
		Query.SetParameter("ShowPurchaseOrders", ShowPurchaseOrders);
		Query.SetParameter("ShowProductionOrders", ShowProductionOrders);
		Query.SetParameter("ShowWorkOrders", ShowProductionOrders);
		ResultArray = Query.ExecuteBatch();
		
		SalesOrders.Load(ResultArray[4].Unload());
		PurchaseOrders.Load(ResultArray[5].Unload());
		ProductionOrders.Load(ResultArray[6].Unload());
		WorkOrders.Load(ResultArray[7].Unload());
		
	EndIf;

EndProcedure

Procedure CompleteSalesOrders()
	
	If SalesOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
	
	For Each Row In SalesOrders Do
		If Row.Mark Then 
			ReverseInvoicesAndOrdersPayment(Row.Order);
			ReverseInventory(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseSalesOrders(Row.Order);
			ReverseOrderFulfillmentSchedule(Row.Order);
			ReversePaymentCalendar(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompleteWorkOrders()
	
	If WorkOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetStatusCompletedWorkOrders();
	
	For Each Row In WorkOrders Do
		If Row.Mark Then
			ReverseInventory(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseWorkOrders(Row.Order);
			ReversePaymentCalendar(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompletePurchaseOrders()
	
	If PurchaseOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("PurchaseOrderStatuses", "Completed");
	
	For Each Row In PurchaseOrders Do
		If Row.Mark Then 
			ReverseInvoicesAndOrdersPayment(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReversePurchaseOrders(Row.Order);
			ReverseOrderFulfillmentSchedule(Row.Order);
			ReversePaymentCalendar(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure CompleteProductionOrders()
	
	If ProductionOrders.Count() = 0 Then
		Return;
	EndIf;
	
	CompletedStatus = DriveReUse.GetOrderStatus("ProductionOrderStatuses", "Completed");
	
	For Each Row In ProductionOrders Do
		If Row.Mark Then 
			ReverseBackorders(Row.Order);
			ReverseInventoryDemand(Row.Order);
			ReverseInventoryFlowCalendar(Row.Order);
			ReverseProductionOrders(Row.Order);
			
			OrderObject = Row.Order.GetObject();
			OrderObject.OrderState = CompletedStatus;
			OrderObject.Closed = True;
			OrderObject.DataExchange.Load = True;
			OrderObject.Write();
			
			ReflectTasksForCostsCalculation(OrderObject);
			Row.Completed = True;
		EndIf;
	EndDo;
	
EndProcedure

Procedure ReverseInvoicesAndOrdersPayment(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	AccountsReceivableTurnovers.Order AS Order,
	|	AccountsReceivableTurnovers.Company AS Company,
	|	AccountsReceivableTurnovers.AmountCurReceipt AS Amount
	|INTO TableInvoicesAndOrdersPayment
	|FROM
	|	AccumulationRegister.AccountsReceivable.Turnovers(, , , Order = &Order) AS AccountsReceivableTurnovers
	|
	|UNION ALL
	|
	|SELECT
	|	AccountsPayableTurnovers.Order,
	|	AccountsPayableTurnovers.Company,
	|	AccountsPayableTurnovers.AmountCurReceipt
	|FROM
	|	AccumulationRegister.AccountsPayable.Turnovers(, , , Order = &Order) AS AccountsPayableTurnovers
	|
	|UNION ALL
	|
	|SELECT
	|	InvoicesAndOrdersPaymentTurnovers.Quote,
	|	InvoicesAndOrdersPaymentTurnovers.Company,
	|	-InvoicesAndOrdersPaymentTurnovers.AmountTurnover
	|FROM
	|	AccumulationRegister.InvoicesAndOrdersPayment.Turnovers(, , , Quote = &Order) AS InvoicesAndOrdersPaymentTurnovers
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&CurrentDate AS Period,
	|	TableInvoicesAndOrdersPayment.Order AS Quote,
	|	TableInvoicesAndOrdersPayment.Company AS Company,
	|	SUM(TableInvoicesAndOrdersPayment.Amount) AS Amount
	|FROM
	|	TableInvoicesAndOrdersPayment AS TableInvoicesAndOrdersPayment
	|
	|GROUP BY
	|	TableInvoicesAndOrdersPayment.Order,
	|	TableInvoicesAndOrdersPayment.Company
	|
	|HAVING
	|	SUM(TableInvoicesAndOrdersPayment.Amount) <> 0";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.InvoicesAndOrdersPayment.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseInventory(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	InventoryBalance.Company AS Company,
	|	InventoryBalance.StructuralUnit AS StructuralUnit,
	|	InventoryBalance.GLAccount AS GLAccount,
	|	InventoryBalance.Products AS Products,
	|	InventoryBalance.Characteristic AS Characteristic,
	|	InventoryBalance.Batch AS Batch,
	|	InventoryBalance.SalesOrder AS SalesOrder,
	|	-InventoryBalance.QuantityBalance AS Quantity,
	|	-InventoryBalance.AmountBalance AS Amount,
	|	UNDEFINED AS CustomerCorrOrder,
	|	InventoryBalance.StructuralUnit AS StructuralUnitCorr,
	|	InventoryBalance.GLAccount AS CorrGLAccount,
	|	InventoryBalance.Products AS ProductsCorr
	|INTO Balances
	|FROM
	|	AccumulationRegister.Inventory.Balance(, SalesOrder = &Order) AS InventoryBalance
	|
	|UNION ALL
	|
	|SELECT
	|	VALUE(AccumulationRecordType.Expense),
	|	InventoryBalance.Company,
	|	InventoryBalance.StructuralUnit,
	|	InventoryBalance.GLAccount,
	|	InventoryBalance.Products,
	|	InventoryBalance.Characteristic,
	|	InventoryBalance.Batch,
	|	UNDEFINED,
	|	-InventoryBalance.QuantityBalance,
	|	-InventoryBalance.AmountBalance,
	|	InventoryBalance.SalesOrder,
	|	InventoryBalance.StructuralUnit,
	|	InventoryBalance.GLAccount,
	|	InventoryBalance.Products
	|FROM
	|	AccumulationRegister.Inventory.Balance(, SalesOrder = &Order) AS InventoryBalance
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT DISTINCT
	|	&CurrentDate AS Period,
	|	Balances.RecordType AS RecordType,
	|	Balances.Company AS Company,
	|	Balances.StructuralUnit AS StructuralUnit,
	|	Balances.GLAccount AS GLAccount,
	|	Balances.Products AS Products,
	|	Balances.Characteristic AS Characteristic,
	|	Balances.Batch AS Batch,
	|	Balances.SalesOrder AS SalesOrder,
	|	Balances.Quantity AS Quantity,
	|	Balances.Amount AS Amount,
	|	Balances.CustomerCorrOrder AS CustomerCorrOrder,
	|	&Content AS Content,
	|	Balances.StructuralUnitCorr AS StructuralUnitCorr,
	|	Balances.CorrGLAccount AS CorrGLAccount,
	|	Balances.ProductsCorr AS ProductsCorr
	|FROM
	|	Balances AS Balances
	|		INNER JOIN AccumulationRegister.Inventory AS Inventory
	|		ON (Balances.SalesOrder = Inventory.Recorder
	|				OR Balances.CustomerCorrOrder = Inventory.Recorder)";
	
	Query.SetParameter("Content", NStr("en = 'Inventory reservation'", CommonUseClientServer.MainLanguageCode()));
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.Inventory.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseInventoryFlowCalendar(Order)
	
	RecordSet = AccumulationRegisters.InventoryFlowCalendar.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Write();
	
EndProcedure

Procedure ReverseSalesOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	SalesOrdersBalance.Company AS Company,
	|	SalesOrdersBalance.Products AS Products,
	|	SalesOrdersBalance.Characteristic AS Characteristic,
	|	SalesOrdersBalance.SalesOrder AS SalesOrder,
	|	-SalesOrdersBalance.QuantityBalance AS Quantity,
	|	SalesOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.SalesOrders.Balance(, SalesOrder = &Order) AS SalesOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.SalesOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseWorkOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	WorkOrdersBalance.Company AS Company,
	|	WorkOrdersBalance.Products AS Products,
	|	WorkOrdersBalance.Characteristic AS Characteristic,
	|	-WorkOrdersBalance.QuantityBalance AS Quantity,
	|	WorkOrdersBalance.Products AS ProductsCorr,
	|	WorkOrdersBalance.WorkOrder AS WorkOrder
	|FROM
	|	AccumulationRegister.WorkOrders.Balance(, WorkOrder = &Order) AS WorkOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.WorkOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReversePurchaseOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	PurchaseOrdersBalance.Company AS Company,
	|	PurchaseOrdersBalance.Products AS Products,
	|	PurchaseOrdersBalance.Characteristic AS Characteristic,
	|	PurchaseOrdersBalance.PurchaseOrder AS PurchaseOrder,
	|	-PurchaseOrdersBalance.QuantityBalance AS Quantity,
	|	PurchaseOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.PurchaseOrders.Balance(, PurchaseOrder = &Order) AS PurchaseOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.PurchaseOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseInventoryDemand(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionOrder.Ref AS Ref
	|INTO Registers
	|FROM
	|	Document.ProductionOrder AS ProductionOrder
	|WHERE
	|	ProductionOrder.Ref = &Order
	|
	|UNION ALL
	|
	|SELECT
	|	Production.Ref
	|FROM
	|	Document.Production AS Production
	|WHERE
	|	Production.Posted
	|	AND Production.BasisDocument = &Order
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	InventoryDemandTurnovers.Company AS Company,
	|	InventoryDemandTurnovers.Products AS Products,
	|	InventoryDemandTurnovers.Characteristic AS Characteristic,
	|	InventoryDemandTurnovers.MovementType AS MovementType,
	|	InventoryDemandTurnovers.SalesOrder AS SalesOrder,
	|	SUM(InventoryDemandTurnovers.QuantityTurnover) AS Quantity
	|FROM
	|	AccumulationRegister.InventoryDemand.Turnovers(, , Recorder, ) AS InventoryDemandTurnovers
	|		INNER JOIN Registers AS Registers
	|		ON InventoryDemandTurnovers.Recorder = Registers.Ref
	|
	|GROUP BY
	|	InventoryDemandTurnovers.Products,
	|	InventoryDemandTurnovers.MovementType,
	|	InventoryDemandTurnovers.Characteristic,
	|	InventoryDemandTurnovers.SalesOrder,
	|	InventoryDemandTurnovers.Company
	|
	|HAVING
	|	SUM(InventoryDemandTurnovers.QuantityTurnover) <> 0";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.InventoryDemand.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseProductionOrders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Receipt) AS RecordType,
	|	ProductionOrdersBalance.Company AS Company,
	|	ProductionOrdersBalance.Products AS Products,
	|	ProductionOrdersBalance.Characteristic AS Characteristic,
	|	ProductionOrdersBalance.ProductionOrder AS ProductionOrder,
	|	-ProductionOrdersBalance.QuantityBalance AS Quantity,
	|	ProductionOrdersBalance.Products AS ProductsCorr
	|FROM
	|	AccumulationRegister.ProductionOrders.Balance(, ProductionOrder = &Order) AS ProductionOrdersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.ProductionOrders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseBackorders(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	&CurrentDate AS Period,
	|	VALUE(AccumulationRecordType.Expense) AS RecordType,
	|	BackordersBalance.Company AS Company,
	|	BackordersBalance.SalesOrder AS SalesOrder,
	|	BackordersBalance.Products AS Products,
	|	BackordersBalance.Characteristic AS Characteristic,
	|	BackordersBalance.SupplySource AS SupplySource,
	|	BackordersBalance.QuantityBalance AS Quantity
	|FROM
	|	AccumulationRegister.Backorders.Balance(, SupplySource = &Order) AS BackordersBalance";
	
	Query.SetParameter("CurrentDate", CurrentSessionDate());
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.Backorders.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Read();
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		Record = RecordSet.Add();
		FillPropertyValues(Record, Selection);
		RecordSet.Write();
	EndDo;
	
EndProcedure

Procedure ReverseOrderFulfillmentSchedule(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	OrderFulfillmentSchedule.Order AS Order
	|FROM
	|	InformationRegister.OrderFulfillmentSchedule AS OrderFulfillmentSchedule
	|WHERE
	|	OrderFulfillmentSchedule.Order = &Order";
	
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.OrderFulfillmentSchedule.CreateRecordSet();
	RecordSet.Filter.Order.Set(Order);	
	RecordSet.Write();
	
EndProcedure

Procedure ReversePaymentCalendar(Order)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	PaymentCalendar.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.PaymentCalendar AS PaymentCalendar
	|WHERE
	|	PaymentCalendar.Recorder = &Order";
	
	Query.SetParameter("Order", Order);
	
	QueryResult = Query.Execute();
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	RecordSet = AccumulationRegisters.PaymentCalendar.CreateRecordSet();
	RecordSet.Filter.Recorder.Set(Order);	
	RecordSet.Write();
	
EndProcedure

Procedure ReflectTasksForCostsCalculation(Order)
	
	InformationRegisters.TasksForCostsCalculation.CreateRegisterRecord(
		BegOfMonth(CurrentSessionDate()),
		Order.Company,
		Order.Ref);
	
EndProcedure

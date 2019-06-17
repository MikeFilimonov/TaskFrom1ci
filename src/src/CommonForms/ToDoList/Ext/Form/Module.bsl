
#Region GeneralPurposeProceduresAndFunctions

// Generates measures.
//
&AtServer
Procedure GenerateMetrics()
	
	IndicatorsGroupsArray = GetArrayOfGroupsOfIndicators();
	
	FinalQueryText = "";
	For Each IndicatorsGroup In IndicatorsGroupsArray Do
		QueryText = GetTextOfQueryToCalculateIndicators(IndicatorsGroup);
		If QueryText <> "" Then
			FinalQueryText = FinalQueryText + QueryText + ";";
		EndIf;
	EndDo;
	
	If FinalQueryText = "" Then
		Return;
	EndIf;
	
	Query = New Query();
	Query.Text = FinalQueryText;
	
	Query.SetParameter("User", User);
	Query.SetParameter("EmployeesList", EmployeesList);
	Query.SetParameter("CurrentDateTimeSession", CurrentSessionDate());
	Query.SetParameter("CurrentTimeOfSession", Date(1,1,1,Hour(CurrentSessionDate()), Minute(CurrentSessionDate()), Second(CurrentSessionDate())));
	Query.SetParameter("EndOfDayIfCurrentDateTimeSession", EndOfDay(CurrentSessionDate()));
	Query.SetParameter("StartOfDayIfCurrentDateTimeSession", BegOfDay(CurrentSessionDate()));
	Query.SetParameter("EndOfLastSessionOfMonth", BegOfMonth(CurrentSessionDate()) - 1);
	
	QueryResultArray = Query.ExecuteBatch();
	
	SetDisplayOfElements(True);
	
	IndexOf = 0;
	NullData.Clear();
	For Each QueryResultRow In QueryResultArray Do
		
		QueryResult = QueryResultArray[IndexOf];
		
		Selection = QueryResult.Select();
		If Selection.Next() Then
			For Each IndicatorName In QueryResult.Columns Do
				
				ThisForm[IndicatorName.Name] = Items[IndicatorName.Name].Title + " ("+ Selection[IndicatorName.Name] + ")";
				
				If Selection[IndicatorName.Name] = 0 Then
					NullData.Add(IndicatorName.Name);
				EndIf;
				
			EndDo;
		EndIf;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	SetDisplayOfElements();
	
EndProcedure

// Procedure sets items display.
//
&AtServer
Procedure SetDisplayOfElements(ItemsVisible = False)
	
	For Each IndicatorName In NullData Do
		If ItemsVisible Then
			Items[IndicatorName.Value].Visible = ItemsVisible;
		Else
			Items[IndicatorName.Value].Visible = Not NotRepresentNullData;
		EndIf;
	EndDo;
	
EndProcedure

// Generates list of user employees.
//
&AtServer
Function GetListOfUsersStaff()
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	UserEmployees.Employee AS Employee,
	|	UserEmployees.Employee.Description AS Description,
	|	ChangeHistoryOfIndividualNamesSliceLast.Surname AS Surname,
	|	ChangeHistoryOfIndividualNamesSliceLast.Name AS Name,
	|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic AS Patronymic
	|FROM
	|	InformationRegister.UserEmployees AS UserEmployees
	|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&ToDate, ) AS ChangeHistoryOfIndividualNamesSliceLast
	|		ON UserEmployees.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
	|WHERE
	|	UserEmployees.User = &User";
	
	Query.SetParameter("User", User);
	Query.SetParameter("ToDate", CurrentSessionDate());
	
	EmployeesPresentation = "";
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		EmployeesList.Add(Selection.Employee);
		PresentationResponsible = DriveServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic);
		EmployeesPresentation = EmployeesPresentation + ?(EmployeesPresentation = "", "", ", ") + ?(ValueIsFilled(PresentationResponsible), PresentationResponsible, Selection.Description);
	EndDo;
	
EndFunction

// Generates measures list according to FO and rights.
//
&AtServer
Function GetArrayOfGroupsOfIndicators()
	
	IndicatorsGroupsArray = New Array;
	
	// Events
	GroupName = "Events";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.Event);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Work orders
	GroupName = "WorkOrders";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.ObsoleteWorkOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Sales orders
	GroupName = "SalesOrders";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.SalesOrder)
									AND AccessRight("Posting", Metadata.Documents.SalesOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Purchase orders
	GroupName = "PurchaseOrders";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.PurchaseOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Production order
	GroupName = "ProductionOrders";
	Items[GroupName].Visible = GetFunctionalOption("UseProductionSubsystem")
									AND AccessRight("Edit", Metadata.Documents.ProductionOrder);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// Month closing
	GroupName = "MonthEndClosing";
	Items[GroupName].Visible = AccessRight("Edit", Metadata.Documents.MonthEndClosing);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	// My reminders
	GroupName = "MyReminders";
	Items[GroupName].Visible = GetFunctionalOption("UseReminders")
									AND AccessRight("Edit", Metadata.InformationRegisters.UserReminders);
	If Items[GroupName].Visible Then
		IndicatorsGroupsArray.Add(GroupName);
	EndIf;
	
	Return IndicatorsGroupsArray;
	
EndFunction

// Receives query text for measures calculation.
//
&AtServer
Function GetTextOfQueryToCalculateIndicators(IndicatorsGroup)
	
	If IndicatorsGroup = "Events" Then
		
		Return GetTextOfQueryToIndexEvent();
		
	ElsIf IndicatorsGroup = "WorkOrders" Then
		
		Return GetTextOfRequestForIndexWorkOrders();
		
	ElsIf IndicatorsGroup = "SalesOrders" Then
		
		Return GetQueryTextForTargetSalesOrders();
		
	ElsIf IndicatorsGroup = "PurchaseOrders" Then
		
		Return GetQueryTextForFigureOrdersToSuppliers();
		
	ElsIf IndicatorsGroup = "ProductionOrders" Then
		
		Return GetTextOfQueryForRecordOrdersForProduction();
		
	ElsIf IndicatorsGroup = "MonthEndClosing" Then
		
		Return GetTextOfQueryForRecordMonthEnd();
		
	ElsIf IndicatorsGroup = "MyReminders" Then
		
		Return GetTextOfRequestForMyReminders();
		
	EndIf;
	
	Return "";
	
EndFunction

// Receives query text for the Events group measures.:
// Overdue, For today, Planned.
//
&AtServer
Function GetTextOfQueryToIndexEvent()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN Events.EventEnding < &CurrentDateTimeSession
	|					AND Events.EventBegin <> DATETIME(1, 1, 1)
	|				THEN Events.Ref
	|		END) AS EventsExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN Events.EventBegin <= &EndOfDayIfCurrentDateTimeSession
	|					AND Events.EventEnding >= &CurrentDateTimeSession
	|				THEN Events.Ref
	|		END) AS EventsForToday,
	|	COUNT(DISTINCT Events.Ref) AS PlannedEvents
	|FROM
	|	Document.Event AS Events
	|WHERE
	|	Events.State <> VALUE(Catalog.JobAndEventStatuses.Completed)
	|	AND Events.State <> VALUE(Catalog.JobAndEventStatuses.Canceled)
	|	AND Events.Responsible IN(&EmployeesList)
	|	AND Not Events.DeletionMark"
	;
	
	Return QueryText;
	
EndFunction

// Receives query text for the WorkOrders group measures.:
// Overdue, For today, Planned, Controled.
//
&AtServer
Function GetTextOfRequestForIndexWorkOrders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN (WorkOrders.Day < &StartOfDayIfCurrentDateTimeSession
	|					OR WorkOrders.Day = &StartOfDayIfCurrentDateTimeSession
	|						AND WorkOrders.EndTime < &CurrentTimeOfSession)
	|					AND WorkOrders.EndTime <> DATETIME(1, 1, 1)
	|					AND WorkOrders.Day <> DATETIME(1, 1, 1)
	|					AND WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrders.Day = &StartOfDayIfCurrentDateTimeSession
	|					AND WorkOrders.BeginTime <= &CurrentTimeOfSession
	|					AND WorkOrders.EndTime >= &CurrentTimeOfSession
	|					AND WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersOnToday,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersPlanned,
	|	COUNT(DISTINCT CASE
	|			WHEN WorkOrders.Ref.Author = &User
	|					AND Not WorkOrders.Ref.Employee IN (&EmployeesList)
	|				THEN WorkOrders.Ref
	|		END) AS WorkOrdersOnControl
	|FROM
	|	Document.ObsoleteWorkOrder.Works AS WorkOrders
	|WHERE
	|	WorkOrders.Ref.Posted
	|	AND WorkOrders.Ref.State <> VALUE(Catalog.JobAndEventStatuses.Completed)
	|	AND WorkOrders.Ref.State <> VALUE(Catalog.JobAndEventStatuses.Canceled)"
	;
	
	Return QueryText;
	
EndFunction

// Receives query text for the SalesOrders group measures.:
// Overdue shipments, Overdue payment, For today, New orders, Orders in process.
//
&AtServer
Function GetQueryTextForTargetSalesOrders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|		END) AS BuyersOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.SetPaymentTerms
	|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.Quote IS NULL 
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|		END) AS BuyersOrdersPaymentExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.SetPaymentTerms
	|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.Quote IS NULL 
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocSalesOrder.Ref
	|		END) AS SalesOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN UseSalesOrderStatuses.Value
	|				THEN CASE
	|						WHEN DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|							THEN DocSalesOrder.Ref
	|					END
	|			ELSE CASE
	|					WHEN Not DocSalesOrder.Posted
	|							AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|						THEN DocSalesOrder.Ref
	|				END
	|		END) AS BuyersNewOrders,
	|	COUNT(DISTINCT CASE
	|			WHEN DocSalesOrder.Posted
	|					AND DocSalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocSalesOrder.Ref
	|		END) AS BuyersOrdersInWork
	|FROM
	|	Document.SalesOrder AS DocSalesOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON DocSalesOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocSalesOrder.Ref = PaymentSchedule.Quote
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)},
	|	Constant.UseSalesOrderStatuses AS UseSalesOrderStatuses
	|WHERE
	|	Not DocSalesOrder.Closed
	|	AND DocSalesOrder.Responsible IN(&EmployeesList)
	|	AND Not DocSalesOrder.DeletionMark"
	;
	
	Return QueryText;
	
EndFunction

// Receives query text for the group PurchaseOrders measures.:
// Overdue receipts, Overdue payment, For today, Orders in process.
//
&AtServer
Function GetQueryTextForFigureOrdersToSuppliers()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.SetPaymentTerms
	|					AND DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.Quote IS NULL 
	|					AND PaymentSchedule.Period < &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersPaymentExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not RunSchedule.Order IS NULL 
	|					AND RunSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|			WHEN DocPurchaseOrder.SetPaymentTerms
	|					AND DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|					AND Not PaymentSchedule.Quote IS NULL 
	|					AND PaymentSchedule.Period = &StartOfDayIfCurrentDateTimeSession
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersForToday,
	|	COUNT(DISTINCT CASE
	|			WHEN DocPurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|				THEN DocPurchaseOrder.Ref
	|		END) AS SupplierOrdersInWork
	|FROM
	|	Document.PurchaseOrder AS DocPurchaseOrder
	|		LEFT JOIN InformationRegister.OrderFulfillmentSchedule AS RunSchedule
	|		ON DocPurchaseOrder.Ref = RunSchedule.Order
	|			AND (RunSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)
	|		{LEFT JOIN InformationRegister.OrdersPaymentSchedule AS PaymentSchedule
	|		ON DocPurchaseOrder.Ref = PaymentSchedule.Quote
	|			AND (PaymentSchedule.Period <= &StartOfDayIfCurrentDateTimeSession)}
	|WHERE
	|	DocPurchaseOrder.Posted
	|	AND Not DocPurchaseOrder.Closed
	|	AND DocPurchaseOrder.Responsible IN(&EmployeesList)"
	;
	
	Return QueryText;
	
EndFunction

// Receives query text for the OrdersForProduction group measures.:
// Overdue execution, For today, Orders in process.
//
&AtServer
Function GetTextOfQueryForRecordOrdersForProduction()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN DocProductionOrder.Finish < &CurrentDateTimeSession
	|					AND ISNULL(ProductionOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocProductionOrder.Ref
	|		END) AS OrdersForProductionExecutionExpired,
	|	COUNT(DISTINCT CASE
	|			WHEN DocProductionOrder.Start <= &EndOfDayIfCurrentDateTimeSession
	|					AND DocProductionOrder.Finish >= &CurrentDateTimeSession
	|					AND ISNULL(ProductionOrdersBalances.QuantityBalance, 0) > 0
	|				THEN DocProductionOrder.Ref
	|		END) AS OrdersForProductionForToday,
	|	COUNT(DISTINCT DocProductionOrder.Ref) AS OrdersForProductionInWork
	|FROM
	|	Document.ProductionOrder AS DocProductionOrder
	|		{LEFT JOIN AccumulationRegister.ProductionOrders.Balance(, ) AS ProductionOrdersBalances
	|		ON DocProductionOrder.Ref = ProductionOrdersBalances.ProductionOrder}
	|WHERE
	|	DocProductionOrder.Posted
	|	AND Not DocProductionOrder.Closed
	|	AND DocProductionOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)
	|	AND DocProductionOrder.Responsible IN(&EmployeesList)"
	;
	
	Return QueryText;
	
EndFunction

// Receives query text for the OrdersForProduction group measures.:
// Overdue execution, For today, Orders in process.
//
&AtServer
Function GetTextOfQueryForRecordMonthEnd()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(DISTINCT CASE
	|			WHEN VALUETYPE(DocMonthEnd.Ref) <> Type(Document.MonthEndClosing)
	|				THEN InventoryBalances.Company
	|		END) AS MonthClosureNotCalculatedTotals
	|FROM
	|	AccumulationRegister.Inventory.Balance(&EndOfLastSessionOfMonth, ) AS InventoryBalances
	|		LEFT JOIN Document.MonthEndClosing AS DocMonthEnd
	|		ON InventoryBalances.Company = DocMonthEnd.Company
	|			AND (DocMonthEnd.Posted)
	|			AND (BEGINOFPERIOD(&EndOfLastSessionOfMonth, MONTH) = BEGINOFPERIOD(DocMonthEnd.Date, MONTH))"
	;
	
	Return QueryText;
	
EndFunction

// Receives query text for the MyNotifications group measures.:
//
&AtServer
Function GetTextOfRequestForMyReminders()
	
	QueryText =
	"SELECT ALLOWED
	|	COUNT(*) AS MyRemindersTotalReminders
	|FROM
	|	InformationRegister.UserReminders AS InformationRegisterUserReminders
	|WHERE
	|	InformationRegisterUserReminders.User = &User"
	;
	
	Return QueryText;
	
EndFunction

#EndRegion

#Region FormEventHandlers

// Procedure - OnCreateAtServer form event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	NotRepresentNullData = Items.FormSetNullDataRepresentation.Check;
	
	User = Users.AuthorizedUser();
	GetListOfUsersStaff();
	
	GenerateMetrics();
	
EndProcedure

// Procedure - OnLoadDataFromSettingsAtServer form event handler.
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	ZerosRepresentationSetting = Settings.Get("NotRepresentNullData");
	If ZerosRepresentationSetting <> Undefined Then
		NotRepresentNullData = ZerosRepresentationSetting;
	EndIf;
	
	Items.FormSetNullDataRepresentation.Check = NotRepresentNullData;
	SetDisplayOfElements();
	
EndProcedure

#EndRegion

#Region CommandHandlers

// Procedure - Update command handler of the To-do lists panel.
//
&AtClient
Procedure Refresh(Command)
	
	GenerateMetrics();
	
EndProcedure

// Procedure - SetZeroMeasureDisplay handler command of the To-do lists panel.
//
&AtClient
Procedure SetNullDataRepresentation(Command)
	
	NotRepresentNullData = Not NotRepresentNullData;
	Items.FormSetNullDataRepresentation.Check = NotRepresentNullData;
	SetDisplayOfElements();
	
EndProcedure

#EndRegion

#Region Events

// Procedure - Overdue command handler of the Events list.
//
&AtClient
Procedure EventsExpiredExecutionPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.Event.ListForm", OpenParameters);
	
EndProcedure

// Procedure - ForToday command handler of the Events list.
//
&AtClient
Procedure EventsForTodayPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.Event.ListForm", OpenParameters);
	
EndProcedure

// Procedure - Planned command handler of the Events list.
//
&AtClient
Procedure ScheduledPressEvent(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("Planned");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.Event.ListForm", OpenParameters);
	
EndProcedure

#EndRegion

#Region WorkOrders

// Procedure - Overdue command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersExpiredPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ObsoleteWorkOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - ForToday command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersOnTodaysPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ObsoleteWorkOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - Planned command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersScheduledPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("Planned");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ObsoleteWorkOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - Controled command handler of the WorkOrders list.
//
&AtClient
Procedure WorkOrdersControlClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("OnControl");
	OpenParameters.Insert("Performer", EmployeesList);
	OpenParameters.Insert("Author", New Structure("User, Initials", User, EmployeesPresentation));
	
	OpenForm("Document.ObsoleteWorkOrder.ListForm", OpenParameters);
	
EndProcedure

#EndRegion

#Region SalesOrders

// Procedure - ShipmentOverdue command handler of the SalesOrders list.
//
&AtClient
Procedure SalesOrdersAreOutstandingRunningPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("SalesOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - PaymentOverdue command handler of the SalesOrders list.
//
&AtClient
Procedure SalesOrdersExpiredPaymentButton(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("SalesOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - ForToday command handler of the SalesOrders list.
//
&AtClient
Procedure SalesOrdersOnTodayClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("SalesOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - InProcess command handler of the SalesOrders list.
//
&AtClient
Procedure SalesOrdersInPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("SalesOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - New command handler of the SalesOrders list.
//
&AtClient
Procedure ClickingNewSalesOrders(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("AreNew");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("SalesOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

#Region WorkOrders

// Procedure - ExecutionOverdue command handler of the WorkOrders list.
//
&AtClient
Procedure CustomerWorkOrdersPastPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("WorkOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - PaymentOverdue command handler of the WorkOrders list.
//
&AtClient
Procedure CustomerWorkOrdersPaymentOverdueClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("WorkOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - ForToday command handler of the WorkOrders list.
//
&AtClient
Procedure CustomerWorkOrdersOnTodayPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("WorkOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - InProcess command handler of the CustomerWorkOrders list.
//
&AtClient
Procedure CustomerWorkOrdersInWorkPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	OpenParameters.Insert("WorkOrder");
	
	OpenForm("Document.SalesOrder.ListForm", OpenParameters);
	
EndProcedure

#EndRegion

#Region PurchaseOrders

// Procedure - ReceiptOverdue command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersHasExpiredPressing(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - PaymentOverdue command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersHasExpiredPaymentButton(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("OverduePayment");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - ForToday command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersOnTodayClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - InProcess command handler of the PurchaseOrders list.
//
&AtClient
Procedure OrdersToSuppliersInPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.PurchaseOrder.ListForm", OpenParameters);
	
EndProcedure

#EndRegion
#EndRegion

#Region ProductionOrders

// Procedure - ExecutionOverdue command handler of the ProductionOrders list.
//
&AtClient
Procedure ManufacturingOrdersDueFulfilmentOfPressing(Item, StandardProcessing)

	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("PastPerformance");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ProductionOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - ForToday command handler of the ProductionOrders list.
//
&AtClient
Procedure ManufacturingOrdersOnTodayPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("ForToday");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ProductionOrder.ListForm", OpenParameters);
	
EndProcedure

// Procedure - InProcess command handler of the ProductionOrders list.
//
&AtClient
Procedure ManufacturingOrdersInWorkClicking(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenParameters = New Structure;
	OpenParameters.Insert("ToDoList");
	OpenParameters.Insert("InProcess");
	OpenParameters.Insert("Responsible", New Structure("List, Initials", EmployeesList, EmployeesPresentation));
	
	OpenForm("Document.ProductionOrder.ListForm", OpenParameters);
	
EndProcedure

#Region MonthEnd

// Procedure - TotalsNotCalculated command handler of the MonthClosing list.
//
&AtClient
Procedure ClosingOfMonthResultsNotCalculatedPress(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("DataProcessor.MonthEndClosing.Form");
	
EndProcedure

#EndRegion

#Region MyReminders

// Procedure - NotificationsTotally command handler of the MyNotifications list.
//
&AtClient
Procedure MyRemindersTotalRemindersClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	OpenForm("InformationRegister.UserReminders.Form.MyReminders");
	
EndProcedure

#EndRegion

#EndRegion

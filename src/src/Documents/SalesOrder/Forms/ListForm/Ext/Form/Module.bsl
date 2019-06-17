
#Region GeneralPurposeProceduresAndFunctions

&AtServer
Procedure CloseOrdersAtServer(OrdersArray)
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SalesOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Items.List.Refresh();
	
EndProcedure

// Processes a row activation event of the document list.
//
&AtClient
Procedure HandleIncreasedRowsList()
	
	InfPanelParameters = New Structure("CIAttribute, Counterparty, ContactPerson", "Counterparty");
	DriveClient.InfoPanelProcessListRowActivation(ThisForm, InfPanelParameters);
	
EndProcedure

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseSalesOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.SalesOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.StateCompletedSalesOrders.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.SalesOrderStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = PredefinedValue("Enum.OrderStatuses.InProcess") Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = PredefinedValue("Enum.OrderStatuses.Completed") Then
				If TypeOf(BackColorCompleted) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorCompleted;
			Else
				Continue;
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		If PaintByState Then
			FilterItem.LeftValue = New DataCompositionField("OrderState");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			FilterItem.RightValue = SelectionOrderStatuses.Ref;
		Else
			FilterItem.LeftValue = New DataCompositionField("OrderStatus");
			FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
			If SelectionOrderStatuses.OrderStatus = PredefinedValue("Enum.OrderStatuses.InProcess") Then
				FilterItem.RightValue = "In process";
			Else
				FilterItem.RightValue = "Completed";
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "By order state " + SelectionOrderStatuses.Description;
		
	EndDo;
	
	If Not PaintByState Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is canceled";
		
	EndIf;
	
EndProcedure

// Procedure sets filter in the list table for section To-do list.
//
&AtServer
Procedure SetFilterToDoList()
	
	If Not Parameters.Property("ToDoList") Then
		Return;
	EndIf;
	
	FormHeaderText = "";
	If Parameters.Property("PastPerformance") Then
		FormHeaderText = NStr("en = 'Sales orders: fulfillment expired'");
		DriveClientServer.SetListFilterItem(List, "PastPerformance", True);
	EndIf;
	
	If Parameters.Property("OverduePayment") Then
		FormHeaderText = NStr("en = 'Sales orders: payment overdue'");
		DriveClientServer.SetListFilterItem(List, "OverduePayment", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = NStr("en = 'Sales orders: for today'");
		DriveClientServer.SetListFilterItem(List, "ForToday",True);
	EndIf;
	
	If Parameters.Property("AreNew") Then
		UseStatuses = Constants.UseSalesOrderStatuses.Get();
		FormHeaderText = NStr("en = 'Sales orders: new'");
		If UseStatuses Then
			DriveClientServer.SetListFilterItem(List, "OrderStateState", PredefinedValue("Enum.OrderStatuses.Open"));
		Else
			DriveClientServer.SetListFilterItem(List, "OrderStatus", "In process");
			DriveClientServer.SetListFilterItem(List, "Posted", False);
		EndIf;
		DriveClientServer.SetListFilterItem(List, "Closed", False);
		DriveClientServer.SetListFilterItem(List, "DeletionMark", False);
	EndIf;
	
	If Parameters.Property("InProcess") Then
		FormHeaderText = NStr("en = 'Sales orders: in progress'");
		DriveClientServer.SetListFilterItem(List, "OrderInProcess", True);
	EndIf;
	
	If Parameters.Property("Responsible") Then
		If Parameters.Responsible.List.Count() = 1 Then
			DriveClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List[0].Value);
		Else
			DriveClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List,,DataCompositionComparisonType.InList);
		EndIf;
		FormHeaderText = FormHeaderText + ", " + NStr("en = 'manager:'") + " " + Parameters.Responsible.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		Title = FormHeaderText;
	EndIf;
	
	Items.FilterResponsible.Visible = False;
	Items.FilterState.Visible = False;
	Items.FilterStatus.Visible = False;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	Items.FilterActuality.ChoiceList.Add("All", NStr("en = 'All'"));
	Items.FilterActuality.ChoiceList.Add("Except closed", NStr("en = 'Except closed'"));
	Items.FilterActuality.ChoiceList.Add("Closed", NStr("en = 'Closed'"));
	
	Items.FilterStatus.ChoiceList.Add("In process", NStr("en = 'In process'"));
	Items.FilterStatus.ChoiceList.Add("Completed", NStr("en = 'Completed'"));
	Items.FilterStatus.ChoiceList.Add("Canceled", NStr("en = 'Canceled'"));
	
	ValueList = New ValueList;
	ValueList.Add(PredefinedValue("Enum.OperationTypesSalesOrder.OrderForProcessing"));
	ValueList.Add(PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale"));
	
	DriveClientServer.SetListFilterItem(List,"OperationKind",ValueList,True,DataCompositionComparisonType.InList);
	
	UseStatuses = Constants.UseSalesOrderStatuses.Get();
	
	List.Parameters.SetParameterValue("CurrentDateSession", BegOfDay(CurrentSessionDate()));
	
	// Function menu - Marketnig and product sales.
	If Parameters.Property("FunctionsMenuOrderingStage") Then
		
		DriveClientServer.SetListFilterItem(List,"OperationKind", PredefinedValue("Enum.OperationTypesSalesOrder.OrderForSale"));
		
		If Parameters.Property("Responsible") Then
			FilterResponsible = Parameters.Responsible;
		EndIf;
		
		If Parameters.FunctionsMenuOrderingStage = "New" Then
			Title = Title + " (AreNew)";
			If UseStatuses Then
				DriveClientServer.SetListFilterItem(List, "OrderStateState", PredefinedValue("Enum.OrderStatuses.Open"), True, DataCompositionComparisonType.Equal);
				DriveClientServer.SetListFilterItem(List, "Closed", False);
			Else
				DriveClientServer.SetListFilterItem(List, "OrderStatus", "In process");
				DriveClientServer.SetListFilterItem(List, "Posted", False);
			EndIf;
			DriveClientServer.SetListFilterItem(List, "DeletionMark", False);
			Items.ShipmentPictureNumber.Visible = False;
			Items.PaymentPictureNumber.Visible = False;
		ElsIf Parameters.FunctionsMenuOrderingStage = "NotShipped" Then
			Title = Title + " (" + NStr("en = 'for dispatch'") + ")";
			DriveClientServer.SetListFilterItem(List, "ForShipment", 0, True, DataCompositionComparisonType.Greater);
			If UseStatuses Then
				DriveClientServer.SetListFilterItem(List, "Closed", False);
			Else
				DriveClientServer.SetListFilterItem(List, "OrderStatus", "In process");
			EndIf;
		ElsIf Parameters.FunctionsMenuOrderingStage = "Unpaid" Then
			Title = Title + " (" + NStr("en = 'for payment'") + ")";
			DriveClientServer.SetListFilterItem(List, "ForPayment", 0, True, DataCompositionComparisonType.Greater);
			If UseStatuses Then
				DriveClientServer.SetListFilterItem(List, "Closed", False);
			Else
				DriveClientServer.SetListFilterItem(List, "OrderStatus", "In process");
			EndIf;
		EndIf;
		
		Items.OrderStatus.Visible = False;
		Items.FilterStatus.Visible = False;
		
		If Not UseStatuses Then
			Items.FilterState.Visible = False;
			Items.OrderState.Visible = False;
		EndIf;
		
	// Use sales order status.
	ElsIf UseStatuses Then
		Items.OrderStatus.Visible = False;
		Items.FilterStatus.Visible = False;
	Else
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	PaintList();
	
	SetFilterToDoList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsSalesOrder);
	// End StandardSubsystems.Printing
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisForm);
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisForm);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("ToDoList") Then
		
		Settings.Delete("FilterCompany");
		Settings.Delete("FilterState");
		Settings.Delete("FilterStatus");
		Settings.Delete("FilterCounterparty");
		Settings.Delete("FilterActuality");
		Settings.Delete("FilterResponsible");
		
	Else
		
		FilterCompany = Settings.Get("FilterCompany");
		FilterState = Settings.Get("FilterState");
		FilterStatus = Settings.Get("FilterStatus");
		FilterCounterparty = Settings.Get("FilterCounterparty");
		FilterActuality = Settings.Get("FilterActuality");
		
		If Not ValueIsFilled(FilterActuality) Then
			FilterActuality = "All";
		EndIf;
		
		// Call is excluded from function panel.
		If Not Parameters.Property("Responsible") Then
			FilterResponsible = Settings.Get("FilterResponsible");
		EndIf;
		Settings.Delete("FilterResponsible");
		
		UseStatuses = Constants.UseSalesOrderStatuses.Get();
		
		// Log.
		If Not Parameters.Property("FunctionsMenuOrderingStage") Then
			If FilterActuality = "Except closed" Then
				DriveClientServer.SetListFilterItem(List, "Closed", False);
			ElsIf FilterActuality = "Closed" Then
				DriveClientServer.SetListFilterItem(List, "Closed", True);
			EndIf;
			If UseStatuses Then
				FilterStatus = "";
				DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
			Else
				DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
			EndIf;
		EndIf;
		
		DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
		DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
		DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
		
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_SupplierInvoiceReturn"
	 OR EventName = "Record_SalesInvoice"
	 OR EventName = "NotificationAboutOrderPayment" 
	 OR EventName = "NotificationAboutChangingDebt" Then
		Items.List.Refresh();
	EndIf;
	
	If EventName = "Record_SalesOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of clicking the SendEmailToCounterparty button.
//
&AtClient
Procedure SendEmailToCounterparty(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(CounterpartyInformationES) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.Counterparty);
		StructureRecipient.Insert("Address", CounterpartyInformationES);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure

// Procedure - handler of clicking the SendEmailToContactPerson button.
//
&AtClient
Procedure SendEmailToContactPerson(Item, StandardProcessing)
	
	StandardProcessing = False;
	
	ListCurrentData = Items.List.CurrentData;
	If ListCurrentData = Undefined Then
		Return;
	EndIf;
	
	Recipients = New Array;
	If ValueIsFilled(ContactPersonESInformation) Then
		StructureRecipient = New Structure;
		StructureRecipient.Insert("Presentation", ListCurrentData.ContactPerson);
		StructureRecipient.Insert("Address", ContactPersonESInformation);
		Recipients.Add(StructureRecipient);
	EndIf;
	
	SendingParameters = New Structure;
	SendingParameters.Insert("Recipient", Recipients);
	
	EmailOperationsClient.CreateNewEmail(SendingParameters);
	
EndProcedure

&AtClient
// Procedure - command handler CreateSalesOrder
//
Procedure CreateSalesOrder(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("FillingValues",
		DriveClient.ReadValuesOfFilterDynamicList(List));
	
	OpenForm("Document.SalesOrder.ObjectForm", OpenParameters, Items.List);
	
EndProcedure

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.List);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	CloseOrdersAtServer(OrdersArray);
	
EndProcedure

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	DriveClient.SalesInvoiceGenerationBasedOnSalesOrder(Items.List);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSalesOrder(Items.List);
EndProcedure

#Region AttributeEventHandlers

// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentsListSalesOrderFilterResponsible");
	// End StandardSubsystems.PerformanceMeasurement
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

// Procedure - event handler OnChange input field FilterState.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterStateOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
	
EndProcedure

// Procedure - event handler OnChange input field FilterStatus.
//
&AtClient
Procedure FilterStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure

// Procedure - event handler OnChange input field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentsListSalesOrderFilterCounterparty");
	// End StandardSubsystems.PerformanceMeasurement
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

// Procedure - event handler OnChange input field FilterActuality.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "Except closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "Closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", True, True);
	Else
		DriveClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

#EndRegion

// Procedure - event handler OnActivateRow of dynamic list List.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	Items.FormCreateBasedOn.Enabled = Item.CurrentData = Undefined 
		Or Not Item.CurrentData.Closed;
	
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingSalesOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningSalesOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure
// End StandardSubsystems.Printing

#EndRegion

#EndRegion

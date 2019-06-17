
#Region GeneralPurposeProceduresAndFunctions

&AtServer
Procedure CloseOrdersAtServer(OrdersArray)
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("ProductionOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Items.List.Refresh();
	
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
	
	PaintByState = Constants.UseProductionOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.ProductionOrdersCompletionStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.ProductionOrderStatuses.Select();
	While SelectionOrderStatuses.Next() Do
		
		If PaintByState Then
			BackColor = SelectionOrderStatuses.Color.Get();
			If TypeOf(BackColor) <> Type("Color") Then
				Continue;
			EndIf;
		Else
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
				If TypeOf(BackColorInProcess) <> Type("Color") Then
					Continue;
				EndIf;
				BackColor = BackColorInProcess;
			ElsIf SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.Completed Then
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
			If SelectionOrderStatuses.OrderStatus = Enums.OrderStatuses.InProcess Then
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
		FormHeaderText = NStr("en = 'Production orders: execution is overdue'");
		DriveClientServer.SetListFilterItem(List, "PastPerformance", True);
	EndIf;
	
	If Parameters.Property("ForToday") Then
		FormHeaderText = NStr("en = 'Production orders: for today'");
		DriveClientServer.SetListFilterItem(List, "ForToday", True);
	EndIf;
	
	If Parameters.Property("InProcess") Then
		FormHeaderText = NStr("en = 'Production orders: in progress'");
		DriveClientServer.SetListFilterItem(List, "OrderInProcess", True);
	EndIf;
	
	If Parameters.Property("Responsible") Then
		DriveClientServer.SetListFilterItem(List, "Responsible", Parameters.Responsible.List, True, DataCompositionComparisonType.InList);
		FormHeaderText = FormHeaderText + ", " + NStr("en = 'responsible'") + " " + Parameters.Responsible.Initials;
	EndIf;
	
	If Not IsBlankString(FormHeaderText) Then
		AutoTitle = False;
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
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterDepartment.ListChoiceMode = True;
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
	Items.FilterActuality.ChoiceList.Add("All", NStr("en = 'All'"));
	Items.FilterActuality.ChoiceList.Add("Except closed", NStr("en = 'Except closed'"));
	Items.FilterActuality.ChoiceList.Add("Closed", NStr("en = 'Closed'"));
	
	Items.FilterStatus.ChoiceList.Add("In process", NStr("en = 'In process'"));
	Items.FilterStatus.ChoiceList.Add("Completed", NStr("en = 'Completed'"));
	Items.FilterStatus.ChoiceList.Add("Canceled", NStr("en = 'Canceled'"));
	
	PaintList();
	
	List.Parameters.SetParameterValue("CurrentDateSession", CurrentSessionDate());
	
	UseStatuses = Constants.UseProductionOrderStatuses.Get();	
	
	// Use the states of production orders.
	If UseStatuses Then
		Items.FilterStatus.Visible = False;
		Items.OrderStatus.Visible = False;
	Else
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	SetFilterToDoList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	If Parameters.Property("ToDoList") Then
		
		Settings.Delete("FilterCompany");
		Settings.Delete("FilterState");
		Settings.Delete("FilterStatus");
		Settings.Delete("FilterDepartment");
		Settings.Delete("FilterActuality");
		Settings.Delete("FilterResponsible");
		
	Else
		
		FilterCompany = Settings.Get("FilterCompany");
		FilterState = Settings.Get("FilterState");
		FilterStatus = Settings.Get("FilterStatus");
		FilterResponsible = Settings.Get("FilterResponsible");
		FilterDepartment = Settings.Get("FilterDepartment");
		FilterActuality = Settings.Get("FilterActuality");
		If Not ValueIsFilled(FilterActuality) Then
			FilterActuality = "All";
		EndIf;
		
		If Constants.UseProductionOrderStatuses.Get() Then
			FilterStatus = "";
			DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
		Else
			FilterActuality = "All";
			FilterState = Catalogs.ProductionOrderStatuses.EmptyRef();
			DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
		EndIf;
		
		DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
		DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
		DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
		
		If FilterActuality = "Except closed" Then
			DriveClientServer.SetListFilterItem(List, "Closed", False);
		ElsIf FilterActuality = "Closed" Then
			DriveClientServer.SetListFilterItem(List, "Closed", True);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - Form event handler "NotificationProcessing".
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ProductionOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - ATTRIBUTE EVENT HANDLERS

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterState.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterStateOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OrderState", FilterState, ValueIsFilled(FilterState));
EndProcedure

// Procedure - event handler OnChange input field FilterStatus.
//
&AtClient
Procedure FilterStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "OrderStatus", FilterStatus, ValueIsFilled(FilterStatus));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterResponsibleOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterDepartment.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterDepartmentOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterActuality.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterActualityOnChange(Item)
	
	If FilterActuality = "Except closed" Then
		DriveClientServer.SetListFilterItem(List, "Closed", False, True);
	ElsIf FilterActuality = "Closed" Then
	    DriveClientServer.SetListFilterItem(List, "Closed", True, True);
	Else
	    DriveClientServer.SetListFilterItem(List, "Closed", True, False);
	EndIf;
	
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingProductionOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningProductionOrder";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	Items.FormCreateBasedOn.Enabled = Item.CurrentData = Undefined 
		Or Not Item.CurrentData.Closed;
EndProcedure

#EndRegion

#Region LibrariesHandlers

// StandardSubsystems.AdditionalReportsAndDataProcessors
&AtClient
Procedure Attachable_ExecuteAssignedCommand(Command)
	If Not AdditionalReportsAndDataProcessorsClient.ExecuteAllocatedCommandAtClient(ThisForm, Command.Name) Then
		ExecutionResult = Undefined;
		AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(Command.Name, ExecutionResult);
		AdditionalReportsAndDataProcessorsClient.ShowCommandExecutionResult(ThisForm, ExecutionResult);
	EndIf;
EndProcedure

&AtServer
Procedure AdditionalReportsAndProcessingsExecuteAllocatedCommandAtServer(ItemName, ExecutionResult)
	AdditionalReportsAndDataProcessors.ExecuteAllocatedCommandAtServer(ThisForm, ItemName, ExecutionResult);
EndProcedure
// End StandardSubsystems.AdditionalReportsAndDataProcessors

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.List);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	CloseOrdersAtServer(OrdersArray);
		
EndProcedure

#EndRegion

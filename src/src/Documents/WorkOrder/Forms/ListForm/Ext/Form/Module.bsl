
#Region FormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Items.FilterActuality.ChoiceList.Add("All", NStr("en = 'All'"));
	Items.FilterActuality.ChoiceList.Add("Except closed", NStr("en = 'Except closed'"));
	Items.FilterActuality.ChoiceList.Add("Closed", NStr("en = 'Closed'"));
	
	Items.FilterStatus.ChoiceList.Add(Documents.WorkOrder.InProcessStatus(), NStr("en = 'In process'"));
	Items.FilterStatus.ChoiceList.Add(Documents.WorkOrder.CompletedStatus(), NStr("en = 'Completed'"));
	Items.FilterStatus.ChoiceList.Add(Documents.WorkOrder.CanceledStatus(), NStr("en = 'Canceled'"));
	
	UseStatuses = Constants.UseWorkOrderStatuses.Get();
	
	List.Parameters.SetParameterValue("CurrentDateSession", BegOfDay(CurrentSessionDate()));
	List.Parameters.SetParameterValue("CurrentDateTimeSession", CurrentSessionDate());
	
	List.Parameters.SetParameterValue("InProcess", Documents.WorkOrder.InProcessStatus());
	List.Parameters.SetParameterValue("Completed", Documents.WorkOrder.CompletedStatus());
	List.Parameters.SetParameterValue("Canceled", Documents.WorkOrder.CanceledStatus());

	// Function menu - Marketing and product sales.
	If UseStatuses Then
		Items.OrderStatus.Visible = False;
		Items.FilterStatus.Visible = False;
	Else
		Items.FilterState.Visible = False;
		Items.OrderState.Visible = False;
	EndIf;
	
	PaintList();
	
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	PrintManagement.OnCreateAtServer(ThisObject, Items.GroupImportantCommandsWorkOrder);
	
	DriveServer.OverrideStandartGenerateSalesInvoiceCommand(ThisObject);
	
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
		
		UseStatuses = Constants.UseWorkOrderStatuses.Get();
		
		// Log.
		If Not Parameters.Property("FunctionsMenuOrderingStage") Then
			If FilterActuality = "Except canceled" Then
				DriveClientServer.SetListFilterItem(List, "Closed", False);
			ElsIf FilterActuality = "Canceled" Then
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
		OR EventName = "Record_SalesInvoice" Then
		Items.List.Refresh();
	EndIf;
	
	If EventName = "Record_WorkOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

// Procedure - event handler OnChange input field FilterCompany.
// The procedure defines the situation, when after changing the date of the document, the document appears in the other
// period of document numbering, and in this case the procedure assigns a new unique number to the document. Overrides
// the corresponding form parameter.
//
&AtClient
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

// Procedure - event handler OnChange input field FilterResponsible.
// The procedure defines the situation, when after changing the date of the document, the document appears in the other
// period of document numbering, and in this case the procedure assigns a new unique number to the document. Overrides
// the corresponding form parameter.
//
&AtClient
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

// Procedure - event handler OnChange input field FilterState.
// The procedure defines the situation, when after changing the date of the document, the document appears in the other
// period of document numbering, and in this case the procedure assigns a new unique number to the document. Overrides
// the corresponding form parameter.
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
// The procedure defines the situation, when after changing the date of the document, the document appears in the other
// period of document numbering, and in this case the procedure assigns a new unique number to the document. Overrides
// the corresponding form parameter.
//
&AtClient
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

// Procedure - event handler OnChange input field FilterActuality.
// The procedure defines the situation, when after changing the date of the document, the document appears in the other
// period of document numbering, and in this case the procedure assigns a new unique number to the document. Overrides
// the corresponding form parameter.
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

#Region ListFormTableItemsEventHandlers

// Procedure - event handler OnActivateRow of dynamic list List.
//
&AtClient
Procedure ListOnActivateRow(Item)
	
	AttachIdleHandler("HandleIncreasedRowsList", 0.2, True);
	Items.FormCreateBasedOn.Enabled = Item.CurrentData = Undefined Or Not Item.CurrentData.Closed;
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

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
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.List);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	CloseOrdersAtServer(OrdersArray);
	
EndProcedure

&AtClient
// Procedure - command handler CreateWorkOrder
//
Procedure CreateWorkOrder(Command)
	
	OpenParameters = New Structure;
	OpenParameters.Insert("FillingValues",
		DriveClient.ReadValuesOfFilterDynamicList(List));
	
	OpenForm("Document.WorkOrder.ObjectForm", OpenParameters, Items.List, "NewWorkOrder");
	
EndProcedure

&AtClient
Procedure Attachable_GenerateSalesInvoice(Command)
	DriveClient.SalesInvoiceGenerationBasedOnWorkOrder(Items.List);
EndProcedure

#EndRegion

#Region Private

#Region CommonUseProceduresAndFunctions

&AtServer
Procedure CloseOrdersAtServer(OrdersArray)
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("WorkOrders", OrdersArray);
	
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
	DriveClient.InfoPanelProcessListRowActivation(ThisObject, InfPanelParameters);
	
EndProcedure

// Procedure colors the list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In List.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = NStr("en = 'Order is closed'") Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		List.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UseWorkOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.WorkOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.StateCompletedWorkOrders.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.WorkOrderStatuses.Select();
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
				FilterItem.RightValue = Documents.WorkOrder.InProcessStatus();
			Else
				FilterItem.RightValue = Documents.WorkOrder.CompletedStatus();
			EndIf;
		EndIf;
		
		ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColor);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("en = 'By order state'")+ " " + SelectionOrderStatuses.Description;
		
	EndDo;
	
	If Not PaintByState Then
		
		ConditionalAppearanceItem = List.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = Documents.WorkOrder.CanceledStatus();
		
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = NStr("en = 'Order is canceled'");
		
	EndIf;
	
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
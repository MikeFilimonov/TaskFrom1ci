#Region FormEventHandlers

&AtServer
// Procedure - Form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Use sales order status.
	If GetFunctionalOption("UseSalesOrderStatuses") Then
		Items.ListSalesOrdersOrderStatus.Visible = False;
	Else
		Items.ListSalesOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	PaintWorkOrderList();
	ImportFormSettings();
	
	If Parameters.Property("FunctionsMenuOrderingStage") Then
		
		// Call from the functions panel.
		If Parameters.Property("Responsible") Then
			FilterResponsible = Parameters.Responsible;
		EndIf;
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
		Items.ListGroup.ShowTitle = True;
		Items.ListGroup.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.PageSalesOrders.Visible = False;
		
	EndIf;
	
	UseGoodsReturnFromCustomer = GetFunctionalOption("UseGoodsReturnFromCustomer");
	CommonUseClientServer.SetFormItemProperty(Items, "FormDocumentGoodsReturnCreateBasedOn", "Visible", UseGoodsReturnFromCustomer);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.GroupImportantCommandsReceipts);
	// End StandardSubsystems.Printing
	
	DriveServer.OverrideStandartGenerateGoodsIssueCommand(ThisObject);
	
EndProcedure

&AtServer
// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany = Settings.Get("FilterCompany");
	FilterCounterparty = Settings.Get("FilterCounterparty");
	FilterWarehouse = Settings.Get("FilterWarehouse");
	
	// Call is excluded from function panel.
	If Not Parameters.Property("Responsible") Then
		FilterResponsible = Settings.Get("FilterResponsible");
	EndIf;
	Settings.Delete("FilterResponsible");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	DriveClientServer.SetListFilterItem(List, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
// Procedure - handler of form event OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	SettingsStructure = New Structure;
	SettingsStructure.Insert("Period", FilterPeriod);
	SaveFormSettings(SettingsStructure);
	
EndProcedure

&AtClient
// Procedure - event handler of the form NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_SalesInvoice" Then
		Items.ListSalesOrders.Refresh();
	EndIf;
	
	If EventName = "Record_SalesOrderStates" Then
		PaintList();
	EndIf;
		
	If EventName = "Record_WorkOrderStates" Then
		PaintWorkOrderList();
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
// Procedure - event handler OnChange input field FilterCompany.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterCounterparty.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterCounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterWarehouse.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterWarehouseOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterWarehouse, ValueIsFilled(FilterWarehouse));
	
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
	DriveClientServer.SetListFilterItem(ListSalesOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterPaymentStatus.
//
Procedure FilterPaymentStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "PaymentStatus", FilterPaymentStatus, ValueIsFilled(FilterPaymentStatus));
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	KeyOperation = "CreateFormSalesInvoice";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
	If Not OnlyReturns Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKindReturn", OnlyReturns);
	OpenForm("Document.SalesInvoice.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningSalesInvoice";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
	If Item.CurrentRow = Undefined
		OR Not OnlyReturns Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKindReturn", OnlyReturns);
	FormParameters.Insert("Key", Item.CurrentRow);
	OpenForm("Document.SalesInvoice.ObjectForm", FormParameters, Item);
	
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.ListSalesOrders);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("SalesOrders", OrdersArray);
	
	OpenForm("DataProcessor.OrdersClosing.Form.Form", ClosingStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure CloseWorkOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.ListWorkOrders);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("WorkOrders", OrdersArray);
	
	OpenForm("DataProcessor.OrdersClosing.Form.Form", ClosingStructure, ThisObject);
	
EndProcedure

&AtClient
// Procedure - handler of the CreateSalesInvoice button clicking.
//
Procedure CreateSalesInvoice(Command)
	DriveClient.SalesInvoiceGenerationBasedOnSalesOrder(Items.ListSalesOrders);
EndProcedure

&AtClient
Procedure CreateSalesInvoiceBasedOnWO(Command)
	DriveClient.SalesInvoiceGenerationBasedOnWorkOrder(Items.ListWorkOrders);
EndProcedure

&AtClient
Procedure Attachable_GenerateGoodsIssue(Command)
	DriveClient.GoodsIssueGenerationBasedOnSalesInvoice(Items.List);
EndProcedure

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#Region Private

#Region GeneralPurposeProceduresAndFunctions

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("SalesInvoiceDocumentsListForm", "SettingsStructure", SettingsStructure);
	
EndProcedure

&AtServer
// Procedure imports the form settings.
//
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("SalesInvoiceDocumentsListForm", "SettingsStructure");
		
	If TypeOf(SettingsStructure) = Type("Structure") Then
				
		// Period.
		If SettingsStructure.Property("Period") Then
			FilterPeriod = SettingsStructure.Period;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring orders for production.
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = GetFunctionalOption("UseSalesOrderStatuses");
	
	If Not PaintByState Then
		InProcessStatus = DriveReUse.GetStatusInProcessOfSalesOrders();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = DriveReUse.GetStatusCompletedSalesOrders();
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
		
		ConditionalAppearanceItem = ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
	
	If PaintByState Then
		
		ConditionalAppearanceItem = ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is closed";
		
	Else
		
		ConditionalAppearanceItem = ListSalesOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is canceled";
		
	EndIf;
	
EndProcedure

// Procedure colors work order list.
//
&AtServer
Procedure PaintWorkOrderList()
	
	// List coloring orders for production.
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ListWorkOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		ListWorkOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = GetFunctionalOption("UseWorkOrderStatuses");
	
	If Not PaintByState Then
		InProcessStatus = DriveReUse.GetStatusInProcessOfWorkOrders();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = DriveReUse.GetStatusCompletedWorkOrders();
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
		
		ConditionalAppearanceItem = ListWorkOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
	
	If PaintByState Then
		
		ConditionalAppearanceItem = ListWorkOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("Closed");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = True;
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is closed";
		
	Else
		
		ConditionalAppearanceItem = ListWorkOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
		FilterItem = ConditionalAppearanceItem.Filter.Items.Add(Type("DataCompositionFilterItem"));
		
		FilterItem.LeftValue = New DataCompositionField("OrderStatus");
		FilterItem.ComparisonType = DataCompositionComparisonType.Equal;
		FilterItem.RightValue = "Canceled";
		
		TextFontRows = New Font(,,,,,True);
		ConditionalAppearanceItem.Appearance.SetParameterValue("Font", TextFontRows);
		If TypeOf(BackColorCompleted) = Type("Color") Then
			ConditionalAppearanceItem.Appearance.SetParameterValue("TextColor", BackColorCompleted);
		EndIf;
		ConditionalAppearanceItem.ViewMode = DataCompositionSettingsItemViewMode.Inaccessible;
		ConditionalAppearanceItem.UserSettingID = "Preset";
		ConditionalAppearanceItem.Presentation = "Order is canceled";
		
	EndIf;
	
EndProcedure

#EndRegion
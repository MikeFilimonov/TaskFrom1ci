// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ListProductionOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		ListProductionOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
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
		
		ConditionalAppearanceItem = ListProductionOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
	
	If PaintByState Then
		
		ConditionalAppearanceItem = ListProductionOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
		
		ConditionalAppearanceItem = ListProductionOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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

#Region GeneralPurposeProceduresAndFunctions

&AtServer
// Function calls document filling data processor on basis.
//
Function GenerateProductionDocumentsAndWrite(OrdersArray)
	
	ArrayProduction = New Array();
	For Each RowFTS In OrdersArray Do
		
		NewDocumentProduction = Documents.Production.CreateDocument();
		
		NewDocumentProduction.Date = CurrentDate();
		NewDocumentProduction.Fill(RowFTS);
		
		NewDocumentProduction.Write();
		ArrayProduction.Add(NewDocumentProduction.Ref);
		
	EndDo;
	
	Items.List.Refresh();
	
	Return ArrayProduction;
	
EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - Form event handler "OnCreateAtServer".
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.FilterDepartment.ListChoiceMode = True;
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.FilterDepartment.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
	// Use the states of production orders.
	If Constants.UseProductionOrderStatuses.Get() Then
		Items.ListProductionOrdersOrderStatus.Visible = False;
	Else
		Items.ListProductionOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
EndProcedure

&AtServer
// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	FilterCompany 		= Settings.Get("FilterCompany");
	FilterDepartment 		= Settings.Get("FilterDepartment");
	FilterResponsible 		= Settings.Get("FilterResponsible");
	
	DriveClientServer.SetListFilterItem(List, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(List, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
	DriveClientServer.SetListFilterItem(ListProductionOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListProductionOrders, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	DriveClientServer.SetListFilterItem(ListProductionOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
// Procedure - event handler of the form NotificationProcessing.
//
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_Production" Then
		Items.ListProductionOrders.Refresh();
	EndIf;
	
	If EventName = "Record_ProductionOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.ListProductionOrders);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("ProductionOrders", OrdersArray);
	
	OpenForm("DataProcessor.OrdersClosing.Form.Form", ClosingStructure, ThisObject);
	
EndProcedure

&AtClient
// Procedure - button click handler CreateProduction.
//
Procedure CreateProduction(Command)
	
	If Items.ListProductionOrders.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = Items.ListProductionOrders.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.Production.ObjectForm", OpenParameters);
		
	Else
		
		ArrayProduction = GenerateProductionDocumentsAndWrite(OrdersArray);
		Text = NStr("en = 'Created:'");
		For Each RowProduction In ArrayProduction Do
			
			ShowUserNotification(Text, GetURL(RowProduction), RowProduction, PictureLib.Information32);
			
		EndDo;
		
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
	DriveClientServer.SetListFilterItem(ListProductionOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
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
	DriveClientServer.SetListFilterItem(ListProductionOrders, "StructuralUnit", FilterDepartment, ValueIsFilled(FilterDepartment));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterResponsible.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
Procedure FilterResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(ListProductionOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

#Region LibrariesHandlers

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Items.List);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion

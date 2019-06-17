// Procedure colors list.
//
&AtServer
Procedure PaintList()
	
	// List coloring orders for production.
	ListOfItemsForDeletion = New ValueList;
	For Each ConditionalAppearanceItem In ListPurchaseOrders.SettingsComposer.Settings.ConditionalAppearance.Items Do
		If ConditionalAppearanceItem.UserSettingID = "Preset"
			OR ConditionalAppearanceItem.Presentation = "Order is closed" Then
			ListOfItemsForDeletion.Add(ConditionalAppearanceItem);
		EndIf;
	EndDo;
	For Each Item In ListOfItemsForDeletion Do
		ListPurchaseOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Delete(Item.Value);
	EndDo;
	
	PaintByState = Constants.UsePurchaseOrderStatuses.Get();
	
	If Not PaintByState Then
		InProcessStatus = Constants.PurchaseOrdersInProgressStatus.Get();
		BackColorInProcess = InProcessStatus.Color.Get();
		CompletedStatus = Constants.PurchaseOrdersCompletionStatus.Get();
		BackColorCompleted = CompletedStatus.Color.Get();
	EndIf;
	
	SelectionOrderStatuses = Catalogs.PurchaseOrderStatuses.Select();
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
		
		ConditionalAppearanceItem = ListPurchaseOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
		
		ConditionalAppearanceItem = ListPurchaseOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
		
		ConditionalAppearanceItem = ListPurchaseOrders.SettingsComposer.Settings.ConditionalAppearance.Items.Add();
		
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
// Function checks the difference between key attributes.
//
Function CheckKeyAttributesOfOrders(OrdersArray)
	
	DataStructure = New Structure();
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	COUNT(DISTINCT PurchaseOrderHeader.Company) AS CountCompany,
	|	COUNT(DISTINCT PurchaseOrderHeader.Counterparty) AS CountCounterparty,
	|	COUNT(DISTINCT PurchaseOrderHeader.Contract) AS CountContract,
	|	COUNT(DISTINCT PurchaseOrderHeader.SupplierPriceTypes) AS CountPriceKind,
	|	COUNT(DISTINCT PurchaseOrderHeader.DocumentCurrency) AS CountDocumentCurrency,
	|	COUNT(DISTINCT PurchaseOrderHeader.AmountIncludesVAT) AS CountAmountVATIn,
	|	COUNT(DISTINCT PurchaseOrderHeader.IncludeVATInPrice) AS CountIncludeVATInPrice,
	|	COUNT(DISTINCT PurchaseOrderHeader.VATTaxation) AS CountVATTaxation
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrderHeader
	|WHERE
	|	PurchaseOrderHeader.Ref IN(&OrdersArray)
	|
	|HAVING
	|	(COUNT(DISTINCT PurchaseOrderHeader.Company) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.Counterparty) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.Contract) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.SupplierPriceTypes) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.DocumentCurrency) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.AmountIncludesVAT) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.IncludeVATInPrice) > 1
	|		OR COUNT(DISTINCT PurchaseOrderHeader.VATTaxation) > 1)";
	
	Query.SetParameter("OrdersArray", OrdersArray);
	Result = Query.Execute();
	If Result.IsEmpty() Then
		DataStructure.Insert("GenerateFewOrders", False);
		DataStructure.Insert("DataPresentation", "");
	Else
		DataStructure.Insert("GenerateFewOrders", True);
		DataPresentation = "";
		Selection = Result.Select();
		While Selection.Next() Do
			
			If Selection.CountCompany > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Company", ", Company");
			EndIf;
			
			If Selection.CountCounterparty > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Counterparty", ", Counterparty");
			EndIf;
			
			If Selection.CountContract > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Contract", ", Contract");
			EndIf;
			
			If Selection.CountPriceKind > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Price kind", ", Prices kind");
			EndIf;
			
			If Selection.CountDocumentCurrency > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Currency", ", Currency");
			EndIf;
			
			If Selection.CountAmountVATIn > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Amount inc. VAT", ", Amount inc. VAT");
			EndIf;
			
			If Selection.CountIncludeVATInPrice > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "VAT inc. in cost", ", VAT inc. in cost");
			EndIf;
			
			If Selection.CountVATTaxation > 1 Then
				DataPresentation = DataPresentation + ?(IsBlankString(DataPresentation), "Taxation", ", Taxation");
			EndIf;
			
		EndDo;
		
		DataStructure.Insert("DataPresentation", DataPresentation);
		
	EndIf;
	
	Return DataStructure;
	
EndFunction

&AtServer
// Function calls document filling data processor on basis.
//
Function GenerateReceiptDocumentsAndWrite(OrdersArray)
	
	ReceiptDocumentsArray = New Array();
	For Each RowFTS In OrdersArray Do
		
		NewReceiptDocument = Documents.SupplierInvoice.CreateDocument();
		
		NewReceiptDocument.Date = CurrentDate();
		NewReceiptDocument.Fill(RowFTS);
		DriveServer.FillDocumentHeader(NewReceiptDocument,,,, True, );
		
		NewReceiptDocument.Write();
		ReceiptDocumentsArray.Add(NewReceiptDocument.Ref);
		
	EndDo;
	
	Items.List.Refresh();
	
	Return ReceiptDocumentsArray;
	
EndFunction

&AtServerNoContext
// Procedure saves the form settings.
//
Procedure SaveFormSettings(SettingsStructure)
	
	FormDataSettingsStorage.Save("SupplierInvoiceDocumentsListForm", "SettingsStructure", SettingsStructure);
	
EndProcedure

&AtServer
// Procedure imports the form settings.
//
Procedure ImportFormSettings()
	
	SettingsStructure = FormDataSettingsStorage.Load("SupplierInvoiceDocumentsListForm", "SettingsStructure");
		
	If TypeOf(SettingsStructure) = Type("Structure") Then
				
		// Period.
		If SettingsStructure.Property("Period") Then
			FilterPeriod = SettingsStructure.Period;
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - Form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Use purchase order conditions.
	If Constants.UsePurchaseOrderStatuses.Get() Then
		Items.ListPurchaseOrdersOrderStatus.Visible = False;
	Else
		Items.ListPurchaseOrdersOrderState.Visible = False;
	EndIf;
	
	PaintList();
	ImportFormSettings();
	
	If Parameters.Property("FunctionsMenuOrderingStage") Then
		
		// Call from the functions panel.
		If Parameters.Property("Responsible") Then
			FilterResponsible = Parameters.Responsible;
		EndIf;
		
		Items.Pages.PagesRepresentation = FormPagesRepresentation.None;
		Items.FOGroupList.ShowTitle = True;
		Items.FOGroupList.Representation = UsualGroupRepresentation.WeakSeparation;
		Items.PagePurchaseOrders.Visible = False;
		
	EndIf;
	
	
	UseGoodsReturnToSupplier = GetFunctionalOption("UseGoodsReturnToSupplier");
	CommonUseClientServer.SetFormItemProperty(Items, "FormDocumentGoodsReturnCreateBasedOn", "Visible", UseGoodsReturnToSupplier);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisObject);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisObject, Items.GroupImportantCommandsReceipts);
	// End StandardSubsystems.Printing
	
	DriveServer.OverrideStandartGenerateCustomsDeclarationCommand(ThisObject);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
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
	
	DriveClientServer.SetListFilterItem(ListPurchaseOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	DriveClientServer.SetListFilterItem(ListPurchaseOrders, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	DriveClientServer.SetListFilterItem(ListPurchaseOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
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
	
	If EventName = "Record_SupplierInvoice" Then
		Items.ListPurchaseOrders.Refresh();
	EndIf;
	
	If EventName = "Write_PurchaseOrderStates" Then
		PaintList();
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
Procedure CloseOrders(Command)
	
	OrdersArray = DriveClient.CheckGetSelectedRefsInList(Items.ListPurchaseOrders);
	If OrdersArray.Count() = 0 Then
		Return;
	EndIf;
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("PurchaseOrders", OrdersArray);
	
	OpenForm("DataProcessor.OrdersClosing.Form.Form", ClosingStructure, ThisObject);
	
EndProcedure

&AtClient
// Procedure - CreateSupplierInvoice button click handler.
//
Procedure CreateSupplierInvoice(Command)
	
	If Items.ListPurchaseOrders.CurrentData = Undefined Then
		
		WarningText = NStr("en = 'Command cannot be executed for the specified object.'");
		ShowMessageBox(Undefined,WarningText);
		Return;
		
	EndIf;
	
	OrdersArray = Items.ListPurchaseOrders.SelectedRows;
	
	If OrdersArray.Count() = 1 Then
		
		OpenParameters = New Structure("Basis", OrdersArray[0]);
		OpenForm("Document.SupplierInvoice.ObjectForm", OpenParameters);
		
	Else
		
		DataStructure = CheckKeyAttributesOfOrders(OrdersArray);
		If DataStructure.GenerateFewOrders Then
			
			MessageText = NStr("en = 'The orders have different data (%DataPresentation%) in document headers. Create multiple supplier invoices?'");
			MessageText = StrReplace(MessageText, "%DataPresentation%", DataStructure.DataPresentation);
			Response = Undefined;

			ShowQueryBox(New NotifyDescription("CreateSupplierInvoiceEnd", ThisObject, New Structure("OrdersArray", OrdersArray)), MessageText, QuestionDialogMode.YesNo, 0);
			
		Else
			
			FillStructure = New Structure();
			FillStructure.Insert("ArrayOfPurchaseOrders", OrdersArray);
			OpenForm("Document.SupplierInvoice.ObjectForm", New Structure("Basis", FillStructure));
			
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure CreateSupplierInvoiceEnd(Result, AdditionalParameters) Export
    
    OrdersArray = AdditionalParameters.OrdersArray;
    
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        ReceiptDocumentsArray = GenerateReceiptDocumentsAndWrite(OrdersArray);
        Text = NStr("en = 'Created:'");
        For Each RowReceiptDocument In ReceiptDocumentsArray Do
            
            ShowUserNotification(Text, GetURL(RowReceiptDocument), RowReceiptDocument, PictureLib.Information32);
            
        EndDo;
        
    EndIf;

EndProcedure

&AtClient
Procedure Attachable_GenerateCustomsDeclaration(Command)
	DriveClient.CustomsDeclarationGenerationBasedOnSupplierInvoice(Items.List);
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
	DriveClientServer.SetListFilterItem(ListPurchaseOrders, "Company", FilterCompany, ValueIsFilled(FilterCompany));
	
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
	DriveClientServer.SetListFilterItem(ListPurchaseOrders, "Counterparty", FilterCounterparty, ValueIsFilled(FilterCounterparty));
	
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
	DriveClientServer.SetListFilterItem(ListPurchaseOrders, "Responsible", FilterResponsible, ValueIsFilled(FilterResponsible));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange input field FilterPaymentStatus.
//
Procedure FilterPaymentStatusOnChange(Item)
	DriveClientServer.SetListFilterItem(List, "PaymentStatus", FilterPaymentStatus, ValueIsFilled(FilterPaymentStatus));
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group, Parameter)
	
	KeyOperation = "CreatingFormSupplierInvoice";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
	If Not OnlyReturns Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKindReturn", OnlyReturns);
	OpenForm("Document.SupplierInvoice.ObjectForm", FormParameters, Item);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningSupplierInvoice";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
	If Item.CurrentRow = Undefined
		OR Not OnlyReturns Then
		Return;
	EndIf;
	
	Cancel = True;
	
	FormParameters = New Structure;
	FormParameters.Insert("OperationKindReturn", OnlyReturns);
	FormParameters.Insert("Key", Item.CurrentRow);
	OpenForm("Document.SupplierInvoice.ObjectForm", FormParameters, Item);
	
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

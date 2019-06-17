﻿
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	Filter = "modified";
	
	Device               = Parameters.Device;
	
	DeviceSettings = PeripheralsOfflineServerCall.GetDeviceParameters(Device);
	
	EquipmentType        = DeviceSettings.EquipmentType;
	InfobaseNode         = DeviceSettings.InfobaseNode;
	MaximumCode          = DeviceSettings.MaximumCode;
	
	ExchangeRule         = Parameters.ExchangeRule;
	
	PeripheralsOfflineServerCall.RefreshProductProduct(ExchangeRule);
	
	FilterOnChangeAtServer();
	
	If Not ValueIsFilled(InfobaseNode) Then
		Items.ProductsRegisterChanges.Visible                = False;
		Items.GoodsContextMenuRegisterChanges.Visible = False;
	EndIf;
	
	Title = "Products" + " " + NStr("en = 'for'") + " " + Device;
	
EndProcedure

#EndRegion

#Region FormHeaderItemEventHandlers

&AtClient
Procedure FilterOnChange(Item)
	
	Status(NStr("en = 'Goods table is being updated...'"));
	
	FilterOnChangeAtServer();
	
EndProcedure

#EndRegion

#Region FormTableItemEventHandlersProducts

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	SelectedRow = Products.FindByID(SelectedRow);
	If SelectedRow <> Undefined Then
		ShowValue(Undefined, SelectedRow.Products);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure RecordChanges(Command)
	
	ErrorDescription = "";
	CodesArray = New Array;
	RowArray = New Array;
	
	For Each SelectedRow In Items.Products.SelectedRows Do
		FoundString = Products.FindByID(SelectedRow);
		RowArray.Add(FoundString);
		CodesArray.Add(FoundString.Code);
	EndDo;
	
	If CodesArray.Count() > 0 Then
		Result = RecordChangesAtServer(CodesArray, ErrorDescription);
		If Result Then
			For Each TSRow In RowArray Do
				TSRow.PictureIndexAreChanges = 1;
			EndDo;
			Notify("Record_CodesOfGoodsPeripheral", New Structure, Undefined);
		Else
			ShowMessageBox(Undefined, NStr("en = 'During the change registration an error occurred:'") + " " + ErrorDescription);
		EndIf;
	Else
		ShowMessageBox(Undefined, NStr("en = 'Rows for change registration are not selected'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsClear(Command)
	
	DeviceArray = New Array;
	DeviceArray.Add(Device);
	
	Completed = 0;
	
	NotificationOnImplementation = New NotifyDescription(
		"ExchangeWithEquipmentEnd",
		ThisObject,
	);
	
	PeripheralsOfflineClient.AsynchronousClearProductsInEquipmentOffline(EquipmentType, DeviceArray, , , NotificationOnImplementation);
	
EndProcedure

&AtClient
Procedure ProductsReload(Command)
	
	DeviceArray = New Array;
	DeviceArray.Add(Device);
	
	Completed = 0;
	
	NotificationOnImplementation = New NotifyDescription(
		"ExchangeWithEquipmentEnd",
		ThisObject,
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, , , NotificationOnImplementation, False);
	
EndProcedure

&AtClient
Procedure ExchangeWithEquipmentEnd(Result, Parameters) Export
	
	If Result Then
		FilterOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsExport(Command)
	
	DeviceArray = New Array;
	DeviceArray.Add(Device);
	
	Completed = 0;
	
	NotificationOnImplementation = New NotifyDescription(
		"ExportProductsEnd",
		ThisObject,
	);
	
	PeripheralsOfflineClient.AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, , , NotificationOnImplementation, True);
	
EndProcedure

&AtClient
Procedure ExportProductsEnd(Result, Parameters) Export
	
	If Result Then
		Notify("Writing_ExchangeRulesWithPeripheralsOffline", New Structure, Undefined);
		FilterOnChangeAtServer();
	EndIf;
	
EndProcedure

&AtClient
Procedure TagsPrinting(Command)
	
	AddressInStorage = GetDataToPrintPriceTags();
	If AddressInStorage <> Undefined Then
	
		ParameterStructure = New Structure("AddressInStorage", AddressInStorage);
		
		OpenForm(
			"DataProcessor.PrintLabelsAndTags.Form.Form",
			ParameterStructure,            // Parameters
			,                              // Owner
			New UUID                       // Uniqueness
		);
	
	EndIf;

EndProcedure

&AtClient
Procedure PrintProductCodes(Command)
	
	ObjectsArray = New Array;
	ObjectsArray.Add(New Structure("ExchangeRule, Device", ExchangeRule, Device));
	PrintManagementClient.ExecutePrintCommand(
		"Catalog.ExchangeWithOfflinePeripheralsRules",
		"ProductCodes",
		ObjectsArray,
		Undefined,
		Undefined
	);
	
EndProcedure

&AtClient
Procedure Refresh(Command)
	
	FilterOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure DeleteChangesRegistrationForSelectedStrings(Command)
	
	ErrorDescription = "";
	RowArray = New Array;
	CodesArray = New Array;
	
	For Each SelectedRow In Items.Products.SelectedRows Do
		FoundString = Products.FindByID(SelectedRow);
		RowArray.Add(FoundString);
		CodesArray.Add(FoundString.Code);
	EndDo;
	
	If CodesArray.Count() > 0 Then
		Result = DeleteChangeRecordsAtServer(CodesArray, ErrorDescription);
		If Result Then
			For Each TSRow In RowArray Do
				TSRow.PictureIndexAreChanges = 0;
			EndDo;
			Notify("Record_CodesOfGoodsPeripheral", New Structure, Undefined);
		Else
			ShowMessageBox(Undefined, NStr("en = 'An error occurred during the change registration deletion:'") + " " + ErrorDescription);
		EndIf;
	Else
		ShowMessageBox(Undefined, NStr("en = 'Rows for change registration deletion are not selected'"));
	EndIf;
	
EndProcedure

#EndRegion

#Region OnAttributeChange

&AtServer
Procedure FilterOnChangeAtServer()
	
	ExportParameters = PeripheralsOfflineServerCall.GetDeviceParameters(Device);
	
	If Filter = "modified" Then
		ExportParameters.Insert("PartialExport", True);
		Table = PeripheralsOfflineServerCall.GetGoodsTableForExport(Device, ExportParameters);
	ElsIf Filter = "With errors" Then
		ExportParameters.Insert("PartialExport", False);
		Table = PeripheralsOfflineServerCall.GetGoodsTableForExport(Device, ExportParameters).Copy(New Structure("HasErrors", True));
	Else
		ExportParameters.Insert("PartialExport", False);
		Table = PeripheralsOfflineServerCall.GetGoodsTableForExport(Device, ExportParameters);
	EndIf;
	
	If Table <> Undefined Then
		Products.Load(Table);
	EndIf;
	
EndProcedure

#EndRegion

#Region Other

&AtServer
Function GetDataToPrintPriceTags()
	
	Query = New Query(
	"SELECT TOP 1
	|	ISNULL(CatalogPeripherals.ExchangeRule.StructuralUnit, UNDEFINED) AS StructuralUnit,
	|	ISNULL(CashRegisters.Owner, UNDEFINED) AS Company,
	|	ISNULL(CatalogPeripherals.ExchangeRule.StructuralUnit.RetailPriceKind, UNDEFINED) AS PriceKind
	|FROM
	|	Catalog.Peripherals AS CatalogPeripherals
	|		LEFT JOIN Catalog.CashRegisters AS CashRegisters
	|		ON (CashRegisters.Peripherals = CatalogPeripherals.Ref)
	|WHERE
	|	CatalogPeripherals.Ref = &Device");
	
	Query.SetParameter("Device", Device);
	
	Result = Query.Execute();
	Selection = Result.Select();
	
	If Not Selection.Next() Then
		Return Undefined;
	EndIf;
	
	TableProducts = New ValueTable;
	TableProducts.Columns.Add("Products", New TypeDescription("CatalogRef.Products"));
	TableProducts.Columns.Add("Characteristic", New TypeDescription("CatalogRef.ProductsCharacteristics"));
	TableProducts.Columns.Add("Batch", New TypeDescription("CatalogRef.ProductsBatches"));
	TableProducts.Columns.Add("MeasurementUnit", New TypeDescription("CatalogRef.UOM"));
	TableProducts.Columns.Add("Quantity", New TypeDescription("Number"));
	TableProducts.Columns.Add("Order", New TypeDescription("Number"));
	
	IndexOf = 1;
	For Each SelectedRow In Items.Products.SelectedRows Do
		
		TSRow = Products.FindByID(SelectedRow);
		
		NewRow = TableProducts.Add();
		NewRow.Products = TSRow.Products;
		NewRow.Characteristic = TSRow.Characteristic;
		NewRow.Batch = TSRow.Batch;
		NewRow.MeasurementUnit = TSRow.MeasurementUnit;
		NewRow.Quantity = 1;
		NewRow.Order = IndexOf;
		
		IndexOf = IndexOf + 1;
		
	EndDo;
	
	// Prepare actions structure for labels and price tags printing processor
	ActionsStructure = New Structure;
	ActionsStructure.Insert("FillCompany", Selection.Company);
	ActionsStructure.Insert("FillWarehouse", Selection.StructuralUnit);
	ActionsStructure.Insert("FillKindPrices", Selection.PriceKind);
	ActionsStructure.Insert("FillExchangeRule", ExchangeRule);
	ActionsStructure.Insert("ShowColumnNumberOfDocument", True);
	
	ActionsStructure.Insert("SetPrintModeFromDocument");
	ActionsStructure.Insert("SetMode", "TagsPrinting");
	ActionsStructure.Insert("FillOutPriceTagsQuantityOnDocument");
	ActionsStructure.Insert("FillProductsTable");
	
	// Data preparation for filling tabular section of labels and price tags printing processor
	ResultStructure = New Structure;
	ResultStructure.Insert("Inventory", TableProducts);
	ResultStructure.Insert("ActionsStructure", ActionsStructure);
	
	Return PutToTempStorage(ResultStructure);
	
EndFunction

&AtServer
Function RecordChangesAtServer(CodesArray, ErrorDescription = "")
	
	ReturnValue = True;
	
	Try
		BeginTransaction();
		Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
		For Each Code In CodesArray Do
			
			Set.Filter.ExchangeRule.Value = ExchangeRule;
			Set.Filter.ExchangeRule.Use = True;
			
			Set.Filter.Code.Value = Code;
			Set.Filter.Code.Use = True;
			
			ExchangePlans.RecordChanges(InfobaseNode, Set);
			
		EndDo;
		CommitTransaction();
	Except
		ReturnValue = False;
		ErrorDescription = ErrorInfo().Definition;
	EndTry;
	
	Return ReturnValue;
	
EndFunction

&AtServer
Function DeleteChangeRecordsAtServer(CodesArray, ErrorDescription = "")
	
	ReturnValue = True;
	
	Try
		BeginTransaction();
		Set = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordSet();
		For Each Code In CodesArray Do
			
			Set.Filter.ExchangeRule.Value = ExchangeRule;
			Set.Filter.ExchangeRule.Use = True;
			
			Set.Filter.Code.Value = Code;
			Set.Filter.Code.Use = True;
			
			ExchangePlans.DeleteChangeRecords(InfobaseNode, Set);
			
		EndDo;
		CommitTransaction();
		
		If Filter = "modified" Then
			FilterOnChangeAtServer();
		EndIf;
		
	Except
		ReturnValue = False;
		ErrorDescription = ErrorInfo().Definition;
	EndTry;
	
	Return ReturnValue;
	
EndFunction

#EndRegion
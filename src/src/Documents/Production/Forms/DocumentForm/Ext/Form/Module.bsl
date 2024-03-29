﻿
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure fills in Inventory by specification.
//
&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

// It receives data set from server for the DateOnChange procedure.
//
&AtServerNoContext
Function GetDataDateOnChange(DocumentRef, DateNew, DateBeforeChange)
	
	StructureData = New Structure();
	StructureData.Insert("DATEDIFF", DriveServer.CheckDocumentNumber(DocumentRef, DateNew, DateBeforeChange));
	
	Return StructureData;
	
EndFunction

// Gets data set from server.
//
&AtServer
Function GetCompanyDataOnChange(Company)
	
	FillAddedColumns(True);
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	
	If StructureData.Property("Characteristic") Then
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	Else
		StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products));
	EndIf;
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitOnChange(StructureData)
	
	FillAddedColumns(True);
	
	If StructureData.Department.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR StructureData.Department.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		
		StructureData.Insert("ProductsStructuralUnit", StructureData.Department.TransferRecipient);
		StructureData.Insert("ProductsCell", StructureData.Department.TransferRecipientCell);
		
	Else
		
		StructureData.Insert("ProductsStructuralUnit", Undefined);
		StructureData.Insert("ProductsCell", Undefined);
		
	EndIf;
	
	If StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR StructureData.Department.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		
		StructureData.Insert("InventoryStructuralUnit", StructureData.Department.TransferSource);
		StructureData.Insert("CellInventory", StructureData.Department.TransferSourceCell);
		
	Else
		
		StructureData.Insert("InventoryStructuralUnit", Undefined);
		StructureData.Insert("CellInventory", Undefined);
		
	EndIf;
	
	StructureData.Insert("DisposalsStructuralUnit", StructureData.Department.RecipientOfWastes);
	StructureData.Insert("DisposalsCell", StructureData.Department.DisposalsRecipientCell);
	
	Return StructureData;
	
EndFunction

// Receives data set from the server for CellOnChange procedure.
//
&AtServerNoContext
Function GetDataCellOnChange(StructureData)
	
	If StructureData.StructuralUnit = StructureData.ProductsStructuralUnit Then
		
		If StructureData.StructuralUnit.TransferRecipient <> StructureData.ProductsStructuralUnit
			OR StructureData.StructuralUnit.TransferRecipientCell <> StructureData.ProductsCell Then
			
			StructureData.Insert("NewGoodsCell", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.InventoryStructuralUnit Then
		
		If StructureData.StructuralUnit.TransferSource <> StructureData.InventoryStructuralUnit
			OR StructureData.StructuralUnit.TransferSourceCell <> StructureData.CellInventory Then
			
			StructureData.Insert("NewCellInventory", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	If StructureData.StructuralUnit = StructureData.DisposalsStructuralUnit Then
		
		If StructureData.StructuralUnit.RecipientOfWastes <> StructureData.DisposalsStructuralUnit
			OR StructureData.StructuralUnit.DisposalsRecipientCell <> StructureData.DisposalsCell Then
			
			StructureData.Insert("NewCellWastes", StructureData.Cell);
			
		EndIf;
		
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(AttributeBasis = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object[AttributeBasis], );
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	
	SetVisibleAndEnabled();
	
EndProcedure

// Peripherals
// Procedure gets data by barcodes.
//
&AtServerNoContext
Procedure GetDataByBarCodes(StructureData)
	
	// Transform weight barcodes.
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		InformationRegisters.Barcodes.ConvertWeightBarcode(CurBarcode);
		
	EndDo;
	
	DataByBarCodes = InformationRegisters.Barcodes.GetDataByBarCodes(StructureData.BarcodesArray);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		
		BarcodeData = DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() <> 0 Then
			
			StructureProductsData = New Structure();
			StructureProductsData.Insert("Products", BarcodeData.Products);
			StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
			BarcodeData.Insert("StructureProductsData", GetDataProductsOnChange(StructureProductsData));
			
			If Not ValueIsFilled(BarcodeData.MeasurementUnit) Then
				BarcodeData.MeasurementUnit  = BarcodeData.Products.MeasurementUnit;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	StructureData.Insert("DataByBarCodes", DataByBarCodes);
	
EndProcedure

&AtClient
Function FillByBarcodesData(BarcodesData)
	
	UnknownBarcodes = New Array;
	
	If TypeOf(BarcodesData) = Type("Array") Then
		BarcodesArray = BarcodesData;
	Else
		BarcodesArray = New Array;
		BarcodesArray.Add(BarcodesData);
	EndIf;
	
	StructureData = New Structure();
	StructureData.Insert("BarcodesArray", BarcodesArray);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products, Characteristic, Batch, MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.CostPercentage = 1;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				Items.Inventory.CurrentRow = NewRow.GetID();
			EndIf;
			
			If BarcodeData.Property("SerialNumber") AND ValueIsFilled(BarcodeData.SerialNumber) Then
				WorkWithSerialNumbersClientServer.AddSerialNumberToString(NewRow, BarcodeData.SerialNumber, Object);
			EndIf;
		EndIf;
	EndDo;
	
	Return UnknownBarcodes;

EndFunction

// Procedure processes the received barcodes.
//
&AtClient
Procedure BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	UnknownBarcodes = FillByBarcodesData(BarcodesData);
	
	ReturnParameters = Undefined;
	
	If UnknownBarcodes.Count() > 0 Then
		
		Notification = New NotifyDescription("BarcodesAreReceivedEnd", ThisForm, UnknownBarcodes);
		
		OpenForm(
			"InformationRegister.Barcodes.Form.BarcodesRegistration",
			New Structure("UnknownBarcodes", UnknownBarcodes), ThisForm,,,,Notification
		);
		
		Return;
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedEnd(ReturnParameters, Parameters) Export
	
	UnknownBarcodes = Parameters;
	
	If ReturnParameters <> Undefined Then
		
		BarcodesArray = New Array;
		
		For Each ArrayElement In ReturnParameters.RegisteredBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		For Each ArrayElement In ReturnParameters.ReceivedNewBarcodes Do
			BarcodesArray.Add(ArrayElement);
		EndDo;
		
		UnknownBarcodes = FillByBarcodesData(BarcodesArray);
		
	EndIf;
	
	BarcodesAreReceivedFragment(UnknownBarcodes);
	
EndProcedure

&AtClient
Procedure BarcodesAreReceivedFragment(UnknownBarcodes) Export
	
	For Each CurUndefinedBarcode In UnknownBarcodes Do
		
		MessageString = NStr("en = 'Barcode data is not found: %1%; quantity: %2%'");
		MessageString = StrReplace(MessageString, "%1%", CurUndefinedBarcode.Barcode);
		MessageString = StrReplace(MessageString, "%2%", CurUndefinedBarcode.Quantity);
		CommonUseClientServer.MessageToUser(MessageString);
		
	EndDo;
	
EndProcedure

// End Peripherals

// The procedure fills in column Reserve by reserves for the order.
//
&AtServer
Procedure FillColumnReserveByReservesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByReserves();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = Enums.OperationTypesProduction.Disassembly Then
		
		// Reserve.
		Items.InventoryReserve.Visible = False;
		ReservationUsed = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.ProductsReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.InventoryCostPercentage.Visible = True;
		
		// Batch status.
		NewArray = New Array();
		NewArray.Add(Enums.BatchStatuses.OwnInventory);
		NewArray.Add(Enums.BatchStatuses.CounterpartysInventory);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.Status", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsBatch.ChoiceParameters = NewParameters;
		
		Items.GroupWarehouseProductsAssembling.Visible = False;
		Items.GroupWarehouseProductsDisassembling.Visible = True;
		
		Items.GroupWarehouseInventoryAssembling.Visible = False;
		Items.GroupWarehouseInventoryDisassembling.Visible = True;
		
	Else
		
		// Reserve.
		Items.InventoryReserve.Visible = ValueIsFilled(Object.SalesOrder);
		ReservationUsed = ValueIsFilled(Object.SalesOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.ProductsReserve.Visible = False;
		Items.InventoryCostPercentage.Visible = False;
		
		// Batch status.
		NewParameter = New ChoiceParameter("Filter.Status", Enums.BatchStatuses.OwnInventory);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsBatch.ChoiceParameters = NewParameters;
		
		For Each StringProducts In Object.Products Do
			
			If ValueIsFilled(StringProducts.Batch)
				AND StringProducts.Batch.Status = Enums.BatchStatuses.CounterpartysInventory Then
				StringProducts.Batch = Undefined;
			EndIf;
			
		EndDo;
		
		Items.GroupWarehouseProductsAssembling.Visible = True;
		Items.GroupWarehouseProductsDisassembling.Visible = False;
		
		Items.GroupWarehouseInventoryAssembling.Visible = True;
		Items.GroupWarehouseInventoryDisassembling.Visible = False;
		
	EndIf;
	
EndProcedure

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Items.Cell.Enabled = False;
	EndIf;
		
	If Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		Items.ProductsCellAssembling.Enabled = False;
		Items.CellInventoryDisassembling.Enabled = False;
	EndIf;
	
	If Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		Items.CellInventoryAssembling.Enabled = False;
		Items.ProductsCellDisassembling.Enabled = False;
	EndIf;
	
	If Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		Items.DisposalsCell.Enabled = False;
	EndIf;
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.ProductsStructuralUnitAssembling.ListChoiceMode = True;
		Items.ProductsStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.ProductsStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.ProductsStructuralUnitDisassembling.ListChoiceMode = True;
		Items.ProductsStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.ProductsStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.InventoryStructuralUnitAssembling.ListChoiceMode = True;
		Items.InventoryStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.InventoryStructuralUnitAssembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.InventoryStructuralUnitDisassembling.ListChoiceMode = True;
		Items.InventoryStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.InventoryStructuralUnitDisassembling.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.DisposalsStructuralUnit.ListChoiceMode = True;
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.DisposalsStructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
	EndIf;
	
EndProcedure

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	SelectionMarker		= "Inventory";
	DocumentPresentaion	= NStr("en = 'production'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
	SelectionParameters.Insert("Company", ParentCompany);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.ProductsStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	EndIf;
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - handler of the Action event of the Pick TS Products command.
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	SelectionMarker		= "Products";
	DocumentPresentaion	= NStr("en = 'production'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", ParentCompany);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.ProductsStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	EndIf;
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure DisposalsPick(Command)
	
	TabularSectionName	= "Disposals";
	SelectionMarker		= "Disposals";
	DocumentPresentaion	= NStr("en = 'production'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", ParentCompany);
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		SelectionParameters.Insert("StructuralUnit", Object.ProductsStructuralUnit);
	Else
		SelectionParameters.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	EndIf;
	NotificationDescriptionOnCloseSelection = New NotifyDescription("OnCloseSelection", ThisObject);
	OpenForm("DataProcessor.ProductsSelection.Form.MainForm",
			SelectionParameters,
			ThisObject,
			True,
			,
			,
			NotificationDescriptionOnCloseSelection,
			FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, TabularSectionName);
	StructureData.Insert("Products", TableForImport.UnloadColumn("Products"));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		FillPropertyValues(StructureData, NewRow);
		FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

// Peripherals
// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure SearchByBarcode(Command)
	
	CurBarcode = "";
	ShowInputValue(New NotifyDescription("SearchByBarcodeEnd", ThisObject, New Structure("CurBarcode", CurBarcode)), CurBarcode, NStr("en = 'Enter barcode'"));

EndProcedure

&AtClient
Procedure SearchByBarcodeEnd(Result, AdditionalParameters) Export
    
    CurBarcode = ?(Result = Undefined, AdditionalParameters.CurBarcode, Result);
    
    
    If Not IsBlankString(CurBarcode) Then
        BarcodesReceived(New Structure("Barcode, Quantity, CostPercentage", CurBarcode, 1, 1));
    EndIf;

EndProcedure

// Procedure - event handler Action of the GetWeight command
//
&AtClient
Procedure GetWeight(Command)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow = Undefined Then
		
		ShowMessageBox(Undefined, NStr("en = 'Select a line for which the weight should be received.'"));
		
	ElsIf EquipmentManagerClient.RefreshClientWorkplace() Then // Checks if the operator's workplace is specified
		
		NotifyDescription = New NotifyDescription("GetWeightEnd", ThisObject, TabularSectionRow);
		EquipmentManagerClient.StartWeightReceivingFromElectronicScales(NotifyDescription, UUID);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure GetWeightEnd(Weight, Parameters) Export
	
	TabularSectionRow = Parameters;
	
	If Not Weight = Undefined Then
		If Weight = 0 Then
			MessageText = NStr("en = 'Electronic scales returned zero weight.'");
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			// Weight is received.
			TabularSectionRow.Quantity = Weight;
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - ImportDataFromDTC command handler.
//
&AtClient
Procedure ImportDataFromDCT(Command)
	
	NotificationsAtImportFromDCT = New NotifyDescription("ImportFromDCTEnd", ThisObject);
	EquipmentManagerClient.StartImportDataFromDCT(NotificationsAtImportFromDCT, UUID);
	
EndProcedure

&AtClient
Procedure ImportFromDCTEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array") 
	   AND Result.Count() > 0 Then
		BarcodesReceived(Result);
	EndIf;
	
EndProcedure

// End Peripherals

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage = ClosingResult.CartAddressInStorage;
			
			GetInventoryFromStorage(InventoryAddressInStorage, SelectionMarker, True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveServer.FillDocumentHeader(
		Object,
		,
		Parameters.CopyingValue,
		Parameters.Basis,
		PostingIsAllowed,
		Parameters.FillingValues);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
	FillAddedColumns();
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Production.TabularSections.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals.
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	Items.InventoryDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentProductionPosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If ValueIsFilled(Object.BasisDocument) Then
		Notify("Record_Production", Object.Ref);
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[0], 1, 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity, CostPercentage", Parameter[1][1], 1, 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
	If EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		If Items.Pages.CurrentPage = Items.TSProducts Then
			GetProductsSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		Else
			GetSerialNumbersInventoryFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the production document?'"), QuestionDialogMode.YesNo, 0);

EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument();
        
        If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly") Then
            
            If Not ValueIsFilled(Object.SalesOrder) Then
                
                For Each StringInventory In Object.Products Do
                    StringInventory.Reserve = 0;
                EndDo;
                Items.Products.ChildItems.ProductsReserve.Visible = False;
                
            Else
                
                If Items.Products.ChildItems.ProductsReserve.Visible = False Then
                    Items.Products.ChildItems.ProductsReserve.Visible = True;
                EndIf;
                
            EndIf;
            
        Else
            
            If Not ValueIsFilled(Object.SalesOrder) Then
                
                For Each StringInventory In Object.Inventory Do
                    StringInventory.Reserve = 0;
                EndDo;
                Items.Inventory.ChildItems.InventoryReserve.Visible = False;
                Items.InventoryChangeReserve.Visible = False;
                ReservationUsed = False;
                
            Else
                
                If Items.Inventory.ChildItems.InventoryReserve.Visible = False Then
                    Items.Inventory.ChildItems.InventoryReserve.Visible = True;
                    Items.InventoryChangeReserve.Visible = True;
                    ReservationUsed = True;
                EndIf;
                
            EndIf;
            
        EndIf;
        
    EndIf;

EndProcedure

// Procedure - handler of the  FillUsingSalesOrder click button.
//
&AtClient
Procedure FillUsingSalesOrder(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillBySalesOrderEnd", ThisObject), NStr("en = 'The document will be completely refilled according to ""Sales order"". Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillBySalesOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument("SalesOrder");
    EndIf;

EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory and services"" tabular section is not filled in.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByReservesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory and services"" tabular section is not filled in.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the date
// of a document this document is found in another period
// of documents enumeration, and in this case the procedure assigns new unique number to the document.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure DateOnChange(Item)
	
	// Date change event DataProcessor.
	DateBeforeChange = DocumentDate;
	DocumentDate = Object.Date;
	If Object.Date <> DateBeforeChange Then
		StructureData = GetDataDateOnChange(Object.Ref, Object.Date, DateBeforeChange);
		If StructureData.DATEDIFF <> 0 Then
			Object.Number = "";
		EndIf;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the Company input field.
// In procedure the document number
// is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

// Procedure - handler of the OnChange event of the BasisDocument input field.
//
&AtClient
Procedure BasisDocumentOnChange(Item)
	
	Items.SalesOrder.ReadOnly = ValueIsFilled(Object.BasisDocument);
	
EndProcedure

// Procedure - handler of the OnChange event of the SalesOrder input field.
//
&AtClient
Procedure SalesOrderOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly") Then
		
		Items.ProductsReserve.Visible = ValueIsFilled(Object.SalesOrder);
		
		For Each StringProducts In Object.Products Do
			StringProducts.Reserve = 0;
		EndDo;
		
	Else
		
		Items.InventoryReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.SalesOrder);
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		ReservationUsed = ValueIsFilled(Object.SalesOrder);
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.GroupAdditional, Object.Comment);
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit) Then
	
		StructureData = New Structure();
		StructureData.Insert("Department", Object.StructuralUnit);
		
		StructureData = GetDataStructuralUnitOnChange(StructureData);
		
		If ValueIsFilled(StructureData.ProductsStructuralUnit) Then
			
			Object.ProductsStructuralUnit = StructureData.ProductsStructuralUnit;
			Object.ProductsCell = StructureData.ProductsCell;
			
		Else
			
			Object.ProductsStructuralUnit = Object.StructuralUnit;
			Object.ProductsCell = Object.Cell;
			
		EndIf;
		
		If ValueIsFilled(StructureData.InventoryStructuralUnit) Then
			
			Object.InventoryStructuralUnit = StructureData.InventoryStructuralUnit;
			Object.CellInventory = StructureData.CellInventory;
			
		Else
			
			Object.InventoryStructuralUnit = Object.StructuralUnit;
			Object.CellInventory = Object.Cell;
			
		EndIf;
		
		If ValueIsFilled(StructureData.DisposalsStructuralUnit) Then
			
			Object.DisposalsStructuralUnit = StructureData.DisposalsStructuralUnit;
			Object.DisposalsCell = StructureData.DisposalsCell;
			
		Else
			
			Object.DisposalsStructuralUnit = Object.StructuralUnit;
			Object.DisposalsCell = Object.Cell;
			
		EndIf;
		
	Else
		
		Items.Cell.Enabled = False;
		
	EndIf;
	
EndProcedure

// Procedure - event handler Field opening StructuralUnit.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the Cell input field.
//
&AtClient
Procedure CellOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("StructuralUnit", Object.StructuralUnit);
	StructureData.Insert("Cell", Object.Cell);
	StructureData.Insert("ProductsStructuralUnit", Object.ProductsStructuralUnit);
	StructureData.Insert("ProductsCell", Object.ProductsCell);
	StructureData.Insert("InventoryStructuralUnit", Object.InventoryStructuralUnit);
	StructureData.Insert("CellInventory", Object.CellInventory);
	StructureData.Insert("DisposalsStructuralUnit", Object.DisposalsStructuralUnit);
	StructureData.Insert("DisposalsCell", Object.DisposalsCell);
	
	StructureData = GetDataCellOnChange(StructureData);
	
	If StructureData.Property("NewGoodsCell") Then
		Object.ProductsCell = StructureData.NewGoodsCell;
	EndIf;
	
	If StructureData.Property("NewCellInventory") Then
		Object.CellInventory = StructureData.NewCellInventory;
	EndIf;
	
	If StructureData.Property("NewCellWastes") Then
		Object.DisposalsCell = StructureData.NewCellWastes;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the ProductsStructuralUnitAssembling input field.
//
&AtClient
Procedure ProductsStructuralUnitAssemblingOnChange(Item)
	
	If Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		Items.ProductsCellAssembling.Enabled = False;
		
	EndIf;
	
	FillAddedColumns(True);
	
EndProcedure

// Procedure - Open event handler of ProductsStructuralUnitAssembling field.
//
&AtClient
Procedure StructuralUnitOfProductAssemblyOpening(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitAssembling.ListChoiceMode
		AND Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the ProductsStructuralUnitDisassembling input field.
//
&AtClient
Procedure ProductsStructuralUnitDisassemblingOnChange(Item)
	
	If Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		Items.ProductsCellDisassembling.Enabled = False;
		
	EndIf;
	
	FillAddedColumns(True);
	
EndProcedure

// Procedure - Open event handler of ProductsStructuralUnitDisassembling field.
//
&AtClient
Procedure ProductsStructuralUnitDisassemblingOpen(Item, StandardProcessing)
	
	If Items.ProductsStructuralUnitDisassembling.ListChoiceMode
		AND Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the InventoryStructuralUnitAssembling input field.
//
&AtClient
Procedure InventoryStructuralUnitAssemblingOnChange(Item)
	
	If Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		Items.CellInventoryAssembling.Enabled = False;
		
	EndIf;
	
	FillAddedColumns(True);
	
EndProcedure

// Procedure - Open event handler of InventoryStructuralUnitAssembling field.
//
&AtClient
Procedure InventoryStructuralUnitInAssemblingOpen(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitAssembling.ListChoiceMode
		AND Not ValueIsFilled(Object.InventoryStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the InventoryStructuralUnitDisassembling input field.
//
&AtClient
Procedure InventoryStructuralUnitDisassemblyOnChange(Item)
	
	If Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		Items.CellInventoryDisassembling.Enabled = False;
		
	EndIf;
	
	FillAddedColumns(True);
	
EndProcedure

// Procedure - Handler of event Opening InventoryStructuralUnitDisassembling field.
//
&AtClient
Procedure InventoryStructuralUnitDisassemblyOpening(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitDisassembling.ListChoiceMode
		AND Not ValueIsFilled(Object.ProductsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the DisposalsStructuralUnit input field.
//
&AtClient
Procedure DisposalsStructuralUnitOnChange(Item)
	
	If Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		
		Items.DisposalsCell.Enabled = False;
		
	EndIf;
	
	FillAddedColumns(True);
	
EndProcedure

// Procedure - Open event handler of DisposalsStructuralUnit field.
//
&AtClient
Procedure DisposalsStructuralUnitOpening(Item, StandardProcessing)
	
	If Items.DisposalsStructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.DisposalsStructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

#Region TabularSectionCommandpanelsActions

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CommandFillBySpecification(Command)
	
	If Object.Inventory.Count() <> 0 Then
		
		Response = Undefined;

		
		ShowQueryBox(New NotifyDescription("CommandToFillBySpecificationEnd", ThisObject), NStr("en = 'Tabular section ""Materials"" will be filled in again. Continue?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
		
	EndIf;
	
	CommandToFillBySpecificationFragment();
EndProcedure

&AtClient
Procedure CommandToFillBySpecificationEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CommandToFillBySpecificationFragment();

EndProcedure

&AtClient
Procedure CommandToFillBySpecificationFragment()
    
    FillByBillsOfMaterialsAtServer();

EndProcedure

#EndRegion

#Region TabularSectionAttributeEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "Products");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbersProducts, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure ProductsCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

#EndRegion

#Region TabularSectionInventoryEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "Inventory");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Specification = StructureData.Specification;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.CostPercentage = 1;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, Items.Inventory.CurrentData);
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);

EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection("Inventory", "SerialNumbers");
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection("Inventory", "SerialNumbers");
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Inventory");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnActivateCell(Item)
	
	CurrentData = Items.Inventory.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Inventory.CurrentItem;
		If TableCurrentColumn.Name = "InventoryGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Inventory.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "Inventory");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Inventory.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Inventory");
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, Items.Products.CurrentData, "SerialNumbersProducts");
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Products.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbersProducts, CurrentData,  ,UseSerialNumbersBalance);

EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "ProductsSerialNumbers" Then
		OpenSerialNumbersSelection("Products","SerialNumbersProducts");
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure ProductsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection("Products","SerialNumbersProducts");
	
EndProcedure

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductsGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Products");
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnActivateCell(Item)
	
	CurrentData = Items.Products.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Products.CurrentItem;
		If TableCurrentColumn.Name = "ProductsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Products.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "Products");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure ProductsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure ProductsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Products.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Products");
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products",	TabRow.Products);
	StructureData.Insert("Batch",	TabRow.Batch);
	StructureData.Insert("TabName",	"Inventory");
	AddGLAccountsToStructure(StructureData, TabRow);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	FillProductGLAccounts(StructureData, GLAccounts);		
	
EndProcedure

#EndRegion

#Region TabularSectionDisposalsEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure DisposalsProductsOnChange(Item)
	
	TabularSectionRow = Items.Disposals.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "Disposals");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
EndProcedure

&AtClient
Procedure DisposalsOnStartEdit(Item, NewRow, Clone)
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure DisposalsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "DisposalsGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "Disposals");
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsOnActivateCell(Item)
	
	CurrentData = Items.Disposals.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.Disposals.CurrentItem;
		If TableCurrentColumn.Name = "DisposalsGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.Disposals.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "Disposals");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure DisposalsOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure DisposalsGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.Disposals.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "Disposals");
	
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

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"Production.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import goods from file'"));
	
	DataImportFromExternalSourcesClient.ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, ThisObject);
	
EndProcedure

&AtClient
Procedure ImportDataFromExternalSourceResultDataProcessor(ImportResult, AdditionalParameters) Export
	
	If TypeOf(ImportResult) = Type("Structure") Then
		ProcessPreparedData(ImportResult);
	EndIf;
	
EndProcedure

&AtServer
Procedure ProcessPreparedData(ImportResult)
	
	DataImportFromExternalSourcesOverridable.ImportDataFromExternalSourceResultDataProcessor(ImportResult, Object);
	
EndProcedure

#EndRegion

// StandardSubsystems.Printing
&AtClient
Procedure Attachable_ExecutePrintCommand(Command)
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure

// End StandardSubsystems.Printing

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure OpenSerialNumbersSelection(NameTSInventory, TSNameSerialNumbers)
	
	CurrentDataIdentifier = Items[NameTSInventory].CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier, NameTSInventory, TSNameSerialNumbers);
	// Using field InventoryStructuralUnit for SN selection
	ParametersOfSerialNumbers.Insert("StructuralUnit", Object.InventoryStructuralUnit);
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);
	
EndProcedure

&AtServer
Function GetSerialNumbersInventoryFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Inventory");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbers");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);

EndFunction

&AtServer
Function GetProductsSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	ParametersFieldNames = New Structure;
	ParametersFieldNames.Insert("NameTSInventory", "Products");
	ParametersFieldNames.Insert("TSNameSerialNumbers", "SerialNumbersProducts");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, ParametersFieldNames);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier, TSName, TSNameSerialNumbers)
	
	If TSName = "Inventory" AND Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Assembly") Then
		PickMode = True;
	ElsIf TSName = "Products" AND Object.OperationKind = PredefinedValue("Enum.OperationTypesProduction.Disassembly") Then
		PickMode = True;
	Else
		PickMode = False;
	EndIf;
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, PickMode, TSName, TSNameSerialNumbers);
	
EndFunction

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue, TabName)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object[TabName].FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, TabName, RowData);
	
	RowParameters = GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",	TabName);
	RowParameters.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	StructureData.Insert("Batch", 					TabRow.Batch);
	StructureData.Insert("ConsumptionGLAccount",	TabRow.ConsumptionGLAccount);
	StructureData.Insert("InventoryGLAccount",		TabRow.InventoryGLAccount);
	
	If StructureData.TabName = "Inventory" Then
		StructureData.Insert("InventoryReceivedGLAccount",	TabRow.InventoryReceivedGLAccount);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	Products = Object.Products;
	Inventory = Object.Inventory;
	Disposals = Object.Disposals;
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	If GetGLAccounts Then
		StructureData = New Structure();
		StructureData.Insert("ObjectParameters", ObjectParameters);
		StructureData.Insert("Products", Object.Products.Unload(, "Products").UnloadColumn(("Products")));
		
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	EndIf;
	
	StructureData = GetStructureData(ObjectParameters, "Products");
	
	For Each Row In Products Do
		FillPropertyValues(StructureData, Row);
		
		If GetGLAccounts Then
			FillProductGLAccounts(StructureData, GLAccounts);		
		Else
			GLAccountsForFilling = GetGLAccountsStructure(StructureData);
			GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		EndIf;
		
		FillPropertyValues(Row, StructureData);
	EndDo;
	
	StructureData = GetStructureData(ObjectParameters, "Disposals");
	StructureData.Insert("Products", Object.Disposals.Unload(, "Products").UnloadColumn(("Products")));

	If GetGLAccounts Then
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	EndIf;
	
	For Each Row In Disposals Do
		FillPropertyValues(StructureData, Row);
		
		If GetGLAccounts Then
			FillProductGLAccounts(StructureData, GLAccounts);		
		Else
			GLAccountsForFilling = GetGLAccountsStructure(StructureData);
			GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		EndIf;
		
		FillPropertyValues(Row, StructureData);
	EndDo;
	
	StructureData = GetStructureData(ObjectParameters, "Inventory");
	StructureData.Insert("Products", Object.Inventory.Unload(, "Products").UnloadColumn(("Products")));
	
	If GetGLAccounts Then
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	EndIf;
	
	For Each Row In Inventory Do
		FillPropertyValues(StructureData, Row);
		
		If GetGLAccounts Then
			FillProductGLAccounts(StructureData, GLAccounts);		
		Else
			GLAccountsForFilling = GetGLAccountsStructure(StructureData);
			GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		EndIf;
		
		FillPropertyValues(Row, StructureData);
	EndDo;
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	TabName = GLAccounts.TableName;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabName, TabRow);
		
		GLAccountsForFilling = GetGLAccountsStructure(StructureData);
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function GetGLAccountsStructure(StructureData)

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;
	
	If ValueIsFilled(StructureData.Batch) 
		And CommonUse.ObjectAttributeValue(StructureData.Batch, "Status") = Enums.BatchStatuses.CounterpartysInventory Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	Else
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	EndIf;
	
	If CommonUse.ObjectAttributeValue(ObjectParameters.StructuralUnit, "StructuralUnitType") <> Enums.BusinessUnitsTypes.Warehouse Then
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;

EndFunction

&AtServerNoContext
Procedure FillProductGLAccounts(StructureData, GLAccounts)

	GLAccountsForFilling = GetGLAccountsStructure(StructureData);
	FillPropertyValues(GLAccountsForFilling, GLAccounts[StructureData.Products]);
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, TabName, RowData = Undefined, ProductName = "Products") Export
	
	If TabName = "Products"
		Or TabName = "Disposals"
		Or TabName = "Inventory" Then
		StructureData = New Structure("Products, Batch, InventoryGLAccount, InventoryReceivedGLAccount, ConsumptionGLAccount,
			|GLAccounts, GLAccountsFilled");
	EndIf;
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
		
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
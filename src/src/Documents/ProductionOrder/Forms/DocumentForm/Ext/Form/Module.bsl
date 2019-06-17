
#Region Variables

&AtClient
Var WhenChangingStart;

&AtClient
Var WhenChangingFinish;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure fills inventories by specification.
//
&AtServer
Procedure FillByBillsOfMaterialsAtServer()
	
	Document = FormAttributeToValue("Object");
	NodesBillsOfMaterialstack = New Array;
	Document.FillTabularSectionBySpecification(NodesBillsOfMaterialstack);
	ValueToFormAttribute(Document, "Object");
	
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
&AtServerNoContext
Function GetCompanyDataOnChange(Company)
	
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
	
	StructureData.Insert("ProductsType", StructureData.Products.ProductsType);
	
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
&AtServerNoContext
Function GetDataStructuralUnitOnChange(Warehouse)
	
	If Warehouse.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR Warehouse.TransferSource.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		
		Return Warehouse.TransferSource;
		
	Else
		
		Return Undefined;
		
	EndIf;	
	
EndFunction

// Gets the data set from the server for the BusinessUnitsOnChangeReserve procedure.
//
&AtServerNoContext
Function GetDataStructuralUnitReserveOnChange(Warehouse)
	
	If Warehouse.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse
		OR Warehouse.TransferRecipient.StructuralUnitType = Enums.BusinessUnitsTypes.Department Then
		
		Return Warehouse.TransferRecipient;
		
	Else
		
		Return Undefined;
		
	EndIf;
	
	Return Warehouse.TransferRecipient;
	
EndFunction

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(Attribute = "BasisDocument")
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object[Attribute], );
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	
EndProcedure

// Procedure sets availability of the form items.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationKind = Enums.OperationTypesProductionOrder.Disassembly Then
		
		// Reserve.
		Items.InventoryStructuralUnitReserve.Visible = False;
		Items.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.ProductionStructuralUnitReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.ProductsReserve.Visible = ValueIsFilled(Object.SalesOrder);
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		// Product type.
		NewParameter = New ChoiceParameter("Filter.ProductsType", Enums.ProductsTypes.InventoryItem);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProducts.ChoiceParameters = NewParameters;
		
	Else
		
		// Reserve.
		Items.InventoryStructuralUnitReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.InventoryReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.ProductionStructuralUnitReserve.Visible = False;
		Items.ProductsReserve.Visible = False;
		
		For Each StringProducts In Object.Products Do
			StringProducts.Reserve = 0;
		EndDo;
		
		// Product type.
		NewArray = New Array();
		NewArray.Add(Enums.ProductsTypes.InventoryItem);
		NewArray.Add(Enums.ProductsTypes.Work);
		NewArray.Add(Enums.ProductsTypes.Service);
		ArrayInventoryWork = New FixedArray(NewArray);
		NewParameter = New ChoiceParameter("Filter.ProductsType", ArrayInventoryWork);
		NewParameter2 = New ChoiceParameter("Additionally.TypeRestriction", ArrayInventoryWork);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.ProductsProducts.ChoiceParameters = NewParameters;
		
	EndIf;
	
EndProcedure

// Procedure sets selection mode and selection list for the form units.
//
// Parameters:
//  No.
//
&AtServer
Procedure SetModeAndChoiceList()
	
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.StructuralUnit.ListChoiceMode = True;
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		
		Items.ProductionStructuralUnitReserve.ListChoiceMode = True;
		Items.ProductionStructuralUnitReserve.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.ProductionStructuralUnitReserve.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
		Items.InventoryStructuralUnitReserve.ListChoiceMode = True;
		Items.InventoryStructuralUnitReserve.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.InventoryStructuralUnitReserve.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
	EndIf;
	
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
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Specification = BarcodeData.StructureProductsData.Specification;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				FoundString = TSRowsArray[0];
				FoundString.Quantity = FoundString.Quantity + CurBarcode.Quantity;
				Items.Inventory.CurrentRow = FoundString.GetID();
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

// Procedure fills the column Reserve by free balances on stock.
//
&AtServer
Procedure FillColumnReserveByBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillColumnReserveByBalances();
	ValueToFormAttribute(Document, "Object");
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURES FOR WORK WITH THE SELECTION

// Procedure - handler of the Action event of the Pick TS Inventory command.
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'production order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", Counterparty);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnitReserve);
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
	
	TabularSectionName 	= "Products";
	DocumentPresentaion	= NStr("en = 'production order'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
	SelectionParameters.Insert("Company", Counterparty);
	SelectionParameters.Insert("StructuralUnit", Object.StructuralUnitReserve);
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
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		If TabularSectionName = "Products" Then
			
			If ValueIsFilled(ImportRow.Products) Then
				
				NewRow.ProductsType = ImportRow.Products.ProductsType;
				
			EndIf;
			
		EndIf;
		
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
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
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
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			CurrentPagesProducts		= (Items.Pages.CurrentPage = Items.TSProducts);
			TabularSectionName			= ?(CurrentPagesProducts, "Products", "Inventory");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, False);
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

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
	
	Items.Inventory.ChildItems.InventoryReserve.Visible = ValueIsFilled(Object.SalesOrder);
	
	SetVisibleAndEnabled();
	SetModeAndChoiceList();
	
	If ValueIsFilled(Object.Ref) Then
		NotifyWorkCalendar = False;
	Else
		NotifyWorkCalendar = True;
	EndIf; 
	DocumentModified = False;
	
	InProcessStatus = Constants.ProductionOrdersInProgressStatus.Get();
	CompletedStatus = Constants.ProductionOrdersCompletionStatus.Get();
	
	If Not Constants.UseProductionOrderStatuses.Get() Then
		
		Items.StateGroup.Visible = False;
		
		Items.Status.ChoiceList.Add("InProcess", NStr("en = 'In process'"));
		Items.Status.ChoiceList.Add("Completed", NStr("en = 'Completed'"));
		Items.Status.ChoiceList.Add("Canceled", NStr("en = 'Canceled'"));
		
		If Object.OrderState.OrderStatus = Enums.OrderStatuses.InProcess AND Not Object.Closed Then
			Status = "InProcess";
		ElsIf Object.OrderState.OrderStatus = Enums.OrderStatuses.Completed Then
			Status = "Completed";
		Else
			Status = "Canceled";
		EndIf;
		
	Else
		
		Items.GroupStatuses.Visible = False;
		
	EndIf;
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.Production.TabularSections.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, , "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	ListOfElectronicScales = EquipmentManagerServerCall.GetEquipmentList("ElectronicScales", , EquipmentManagerServerCall.GetClientWorkplace());
	If ListOfElectronicScales.Count() = 0 Then
		// There are no connected scales.
		Items.InventoryGetWeight.Visible = False;
	EndIf;
	Items.InventoryImportDataFromDCT.Visible = UsePeripherals;
	// End Peripherals
	
	Items.ProductsDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

// Procedure - OnReadAtServer event handler.
//
&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.ChangesProhibitionDates
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.ChangesProhibitionDates
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	WhenChangingStart = Object.Start;
	WhenChangingFinish = Object.Finish;
	
	FormManagement();

	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler AfterWriting.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	If DocumentModified Then
		NotifyWorkCalendar = True;
		DocumentModified = False;
	EndIf;
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// StandardSubsystems.Properties 
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	// End StandardSubsystems.Properties
	
	// Peripherals
	If Source = "Peripherals"
		AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;
			
			BarcodesReceived(Data);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure-handler of the BeforeWriteAtServer event.
// Performs initial attributes forms filling.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		DocumentModified = True;
	EndIf;
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

// Procedure - BeforeWrite event handler.
//
&AtClient
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("DocumentProductionOrderPosting");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

// Procedure - event handler BeforeClose form.
//
&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If NotifyWorkCalendar Then
		Notify("ChangedProductionOrder", Object.Responsible);
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

&AtClient
Procedure CloseOrder(Command)
	
	If Modified Or Not Object.Posted Then
		ShowQueryBox(New NotifyDescription("CloseOrderEnd", ThisObject),
			NStr("en = 'Data is still not recorded. Completion of order is possible only after data is recorded.
					|Data will be written.'"), QuestionDialogMode.OKCancel);
		Return;
	EndIf;
		
	CloseOrderFragment();
	FormManagement();
	
EndProcedure

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the production order?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        
        FillByDocument();
        
        If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly") Then
            
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
                
            Else
                
                If Not Items.Inventory.ChildItems.InventoryReserve.Visible Then
                    Items.Inventory.ChildItems.InventoryReserve.Visible = True;
                    Items.InventoryChangeReserve.Visible = True;
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

	
	ShowQueryBox(New NotifyDescription("FillBySalesOrderEnd", ThisObject), NStr("en = 'The document will be completely refilled on the ""Customer order."" Continue?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillBySalesOrderEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument("SalesOrder");
    EndIf;

EndProcedure

// Procedure - command handler FillByBalance submenu ChangeReserve.
//
&AtClient
Procedure ChangeReserveFillByBalances(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory"" tabular section is not filled in.'");
		Message.Message();
		Return;
	EndIf;
	
	FillColumnReserveByBalancesAtServer();
	
EndProcedure

// Procedure - command handler ClearReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveClearReserve(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory"" tabular section is not filled in.'");
		Message.Message();
		Return;
	EndIf;
	
	For Each TabularSectionRow In Object.Inventory Do
		TabularSectionRow.Reserve = 0;
	EndDo;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// COMMAND ACTIONS OF THE ORDER STATES PANEL

// Procedure - event handler OnChange input field Status.
//
&AtClient
Procedure StatusOnChange(Item)
	
	If Status = "InProcess" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	ElsIf Status = "Completed" Then
		Object.OrderState = CompletedStatus;
	ElsIf Status = "Canceled" Then
		Object.OrderState = InProcessStatus;
		Object.Closed = False;
	EndIf;
	
	Modified = True;
	FormManagement();
	
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

&AtClient
Procedure OrderStateStartChoice(Item, ChoiceData, StandardProcessing)
	StandardProcessing = False;
	ChoiceData = GetProductionOrderStates();
EndProcedure

// Procedure - handler of the OnChange event of the SalesOrder input field.
//
&AtClient
Procedure SalesOrderOnChange(Item)
	
	If Object.OperationKind = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly") Then
		
		Items.ProductionStructuralUnitReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.ProductsReserve.Visible = ValueIsFilled(Object.SalesOrder);
		
		For Each StringProducts In Object.Products Do
			StringProducts.Reserve = 0;
		EndDo;
		
	Else
		
		Items.InventoryStructuralUnitReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.InventoryReserve.Visible = ValueIsFilled(Object.SalesOrder);
		Items.InventoryChangeReserve.Visible = ValueIsFilled(Object.SalesOrder);
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the ChoiceProcessing of the OperationKind input field.
//
&AtClient
Procedure OperationKindChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	If ValueSelected = PredefinedValue("Enum.OperationTypesProductionOrder.Disassembly") Then
		
		ProductsTypeInventory = PredefinedValue("Enum.ProductsTypes.InventoryItem");
		For Each StringProducts In Object.Products Do
			
			If ValueIsFilled(StringProducts.Products)
				AND StringProducts.ProductsType <> ProductsTypeInventory Then
				
				MessageText = NStr("en = 'Disassembling operation is invalid for works and services.
				                   |The %ProductsPresentation% products could be a work(service) in the line #%Number% of the tabular section ""Products""'");
				MessageText = StrReplace(MessageText, "%Number%", StringProducts.LineNumber);
				MessageText = StrReplace(MessageText, "%ProductsPresentation%", String(StringProducts.Products));
				
				DriveClient.ShowMessageAboutError(Object, MessageText);
				StandardProcessing = False;
				
			EndIf;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	SetVisibleAndEnabled();
	
EndProcedure

&AtClient
Procedure OrderStateOnChange(Item)
	
	If Object.OrderState <> CompletedStatus Then 
		Object.Closed = False;
	EndIf;
	
	FormManagement();
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure StartOnChange(Item)
	
	If Object.Start > Object.Finish AND ValueIsFilled(Object.Finish) Then
		Object.Start = WhenChangingStart;
		CommonUseClientServer.MessageToUser(NStr("en = 'Start date cannot be greater than end date.'"));
	Else
		WhenChangingStart = Object.Start;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure FinishOnChange(Item)
	
	If Hour(Object.Finish) = 0 AND Minute(Object.Finish) = 0 Then
		Object.Finish = EndOfDay(Object.Finish);
	EndIf;
	
	If Object.Finish < Object.Start Then
		Object.Finish = WhenChangingFinish;
		CommonUseClientServer.MessageToUser(NStr("en = 'Finish date can not be less than the start date.'"));
	Else
		WhenChangingFinish = Object.Finish;
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnit)
		AND Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		DataStructuralUnitReserve = GetDataStructuralUnitOnChange(Object.StructuralUnit);
		Object.StructuralUnitReserve = DataStructuralUnitReserve;
		
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

// Procedure - handler of the OnChange event of the StructuralUnitReserve input field.
//
&AtClient
Procedure StructuralUnitReserveOnChange(Item)
	
	If ValueIsFilled(Object.StructuralUnitReserve)
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		DataStructuralUnit = GetDataStructuralUnitReserveOnChange(Object.StructuralUnitReserve);
		Object.StructuralUnit = DataStructuralUnit;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the Opening event of the StructuralUnitReserve input field.
//
&AtClient
Procedure ProductsStructuralUnitReserveOpen(Item, StandardProcessing)
	
	If Items.ProductionStructuralUnitReserve.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - handler of the Opening event of the StructuralUnitReserve input field.
//
&AtClient
Procedure InventoryStructuralUnitReserveOpen(Item, StandardProcessing)
	
	If Items.InventoryStructuralUnitReserve.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitReserve) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE PRODUCTS TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure ProductsProductsOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
	TabularSectionRow.ProductsType = StructureData.ProductsType;
	
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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF THE INVENTORY TABULAR SECTION ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;
	
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

// Procedure - OnChange event handler of the Comment input field.
//
&AtClient
Procedure CommentOnChange(Item)
	
	AttachIdleHandler("Attachable_SetPictureForComment", 0.5, True);
	
EndProcedure

&AtClient
Procedure Attachable_SetPictureForComment()
	
	DriveClientServer.SetPictureForComment(Items.AdvancedPage, Object.Comment);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENTS HANDLERS OF THE ENTERPRISE RESOURCES TABULAR SECTION ATTRIBUTES

// Procedure calculates the operation duration.
//
// Parameters:
//  No.
//
&AtClient
Function CalculateDuration(CurrentRow)
	
	DurationInSeconds = CurrentRow.Finish - CurrentRow.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	
	Return Duration;
	
EndFunction

// It receives data set from the server for the CompanyResourcesOnStartEdit procedure.
//
&AtClient
Function GetDataCompanyResourcesOnStartEdit(DataStructure)
	
	DataStructure.Start = Object.Start - Second(Object.Start);
	DataStructure.Finish = Object.Finish - Second(Object.Finish);
	
	If ValueIsFilled(DataStructure.Start) AND ValueIsFilled(DataStructure.Finish) Then
		If BegOfDay(DataStructure.Start) <> BegOfDay(DataStructure.Finish) Then
			DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		EndIf;
		If DataStructure.Start >= DataStructure.Finish Then
			DataStructure.Finish = DataStructure.Start + 1800;
			If BegOfDay(DataStructure.Finish) <> BegOfDay(DataStructure.Start) Then
				If EndOfDay(DataStructure.Start) = DataStructure.Start Then
					DataStructure.Start = DataStructure.Start - 29 * 60;
				EndIf;
				DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
			EndIf;
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Start) Then
		DataStructure.Start = DataStructure.Start;
		DataStructure.Finish = EndOfDay(DataStructure.Start) - 59;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Start = BegOfDay(DataStructure.Start);
		EndIf;
	ElsIf ValueIsFilled(DataStructure.Finish) Then
		DataStructure.Start = BegOfDay(DataStructure.Finish);
		DataStructure.Finish = DataStructure.Finish;
		If DataStructure.Finish = DataStructure.Start Then
			DataStructure.Finish = EndOfDay(DataStructure.Finish) - 59;
		EndIf;
	Else
		DataStructure.Start = BegOfDay(CurrentDate());
		DataStructure.Finish = EndOfDay(CurrentDate()) - 59;
	EndIf;
	
	DurationInSeconds = DataStructure.Finish - DataStructure.Start;
	Hours = Int(DurationInSeconds / 3600);
	Minutes = (DurationInSeconds - Hours * 3600) / 60;
	Duration = Date(0001, 01, 01, Hours, Minutes, 0);
	DataStructure.Duration = Duration;
	
	Return DataStructure;
	
EndFunction

// Procedure - event handler OnStartEdit tabular section CompanyResources.
//
&AtClient
Procedure CompanyResourcesOnStartEdit(Item, NewRow, Copy)
	
	If NewRow Then
		
		TabularSectionRow = Items.CompanyResources.CurrentData;
		
		DataStructure = New Structure;
		DataStructure.Insert("Start", '00010101');
		DataStructure.Insert("Finish", '00010101');
		DataStructure.Insert("Duration", '00010101');
		
		DataStructure = GetDataCompanyResourcesOnStartEdit(DataStructure);
		TabularSectionRow.Start = DataStructure.Start;
		TabularSectionRow.Finish = DataStructure.Finish;
		TabularSectionRow.Duration = DataStructure.Duration;
		
	EndIf;
	
EndProcedure

// Procedure - event handler OnChange input field CompanyResource.
//
&AtClient
Procedure CompanyResourcesCompanyResourceOnChange(Item)
	
	TabularSectionRow = Items.CompanyResources.CurrentData;
	TabularSectionRow.Capacity = 1;
	
EndProcedure

// Procedure - event handler OnChange input field Day.
//
&AtClient
Procedure CompanyResourcesDayOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = CurrentDate();
	EndIf;
	
	FinishInSeconds = Hour(CurrentRow.Finish) * 3600 + Minute(CurrentRow.Finish) * 60;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	CurrentRow.Finish = BegOfDay(CurrentRow.Start) + FinishInSeconds;
	CurrentRow.Start = CurrentRow.Finish - DurationInSeconds;
	
EndProcedure

// Procedure - event handler OnChange input field Duration.
//
&AtClient
Procedure CompanyResourcesDurationOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	DurationInSeconds = Hour(CurrentRow.Duration) * 3600 + Minute(CurrentRow.Duration) * 60;
	If DurationInSeconds = 0 Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
	Else
		CurrentRow.Finish = CurrentRow.Start + DurationInSeconds;
	EndIf;
	If BegOfDay(CurrentRow.Start) <> BegOfDay(CurrentRow.Finish) Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure

// Procedure - event handler OnChange input field Start.
//
&AtClient
Procedure CompanyResourcesStartOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	
	If CurrentRow.Start = '00010101' Then
		CurrentRow.Start = BegOfDay(CurrentRow.Finish);
	EndIf;
	
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure

// Procedure - event handler OnChange input field Finish.
//
&AtClient
Procedure CompanyResourcesFinishOnChange(Item)
	
	CurrentRow = Items.CompanyResources.CurrentData;
	
	If Hour(CurrentRow.Finish) = 0 AND Minute(CurrentRow.Finish) = 0 Then
		CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
	EndIf;
	If CurrentRow.Start >= CurrentRow.Finish Then
		CurrentRow.Finish = CurrentRow.Start + 1800;
		If BegOfDay(CurrentRow.Finish) <> BegOfDay(CurrentRow.Start) Then
			If EndOfDay(CurrentRow.Start) = CurrentRow.Start Then
				CurrentRow.Start = CurrentRow.Start - 29 * 60;
			EndIf;
			CurrentRow.Finish = EndOfDay(CurrentRow.Start) - 59;
		EndIf;
	EndIf;
	
	CurrentRow.Duration = CalculateDuration(CurrentRow);
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TOOLTIP EVENTS HANDLERS

&AtClient
Procedure StatusExtendedTooltipNavigationLinkProcessing(Item, URL, StandardProcessing)
	
	StandardProcessing = False;
	OpenForm("DataProcessor.AdministrationPanel.Form.SectionProduction");
	
EndProcedure

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileGoods(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"ProductionOrder.Products");
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
	PrintManagementClient.ExecuteConnectedPrintCommand(Command, ThisObject, Object);
EndProcedure
// End StandardSubsystems.Printing

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties()
PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm);
EndProcedure

// End StandardSubsystems.Properties

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure CloseOrderEnd(QuestionResult, AdditionalParameters) Export
	
	Response = QuestionResult;
	WriteParameters = New Structure;
	WriteParameters.Insert("WriteMode", DocumentWriteMode.Posting);
	
	If Response = DialogReturnCode.Cancel
		Or Not Write(WriteParameters) Then
		Return;
	EndIf;
	
	CloseOrderFragment();
	FormManagement();
	
EndProcedure

&AtServer
Procedure CloseOrderFragment(Result = Undefined, AdditionalParameters = Undefined) Export
	
	OrdersArray = New Array;
	OrdersArray.Add(Object.Ref);
	
	ClosingStructure = New Structure;
	ClosingStructure.Insert("ProductionOrders", OrdersArray);
	
	OrdersClosingObject = DataProcessors.OrdersClosing.Create();
	OrdersClosingObject.FillOrders(ClosingStructure);
	OrdersClosingObject.CloseOrders();
	Read();
	
EndProcedure

&AtClient
Procedure FormManagement()

	StatusIsComplete = (Object.OrderState = CompletedStatus);
	
	Items.FormWrite.Enabled 				= Not StatusIsComplete Or Not Object.Closed;
	Items.FormPost.Enabled 					= Not StatusIsComplete Or Not Object.Closed;
	Items.FormPostAndClose.Enabled 			= Not StatusIsComplete Or Not Object.Closed;
	Items.FormCreateBasedOn.Enabled 		= Not StatusIsComplete Or Not Object.Closed;
	Items.CloseOrder.Visible					= Not Object.Closed;
	Items.CloseOrderStatus.Visible				= Not Object.Closed;
	Items.ProductsCommandBar.Enabled			= Not StatusIsComplete;
	Items.InventoryCommandBar.Enabled			= Not StatusIsComplete;
	Items.CompanyResourcesCommandBar.Enabled	= Not StatusIsComplete;
	Items.FillByBasis.Enabled					= Not StatusIsComplete;
	Items.FillUsingSalesOrder.Enabled			= Not StatusIsComplete;
	Items.StructuralUnit.ReadOnly				= StatusIsComplete;
	Items.StarFinishGroup.ReadOnly				= StatusIsComplete;
	Items.GroupBasisDocument.ReadOnly			= StatusIsComplete;
	Items.GroupBasisDocument.ReadOnly			= StatusIsComplete;
	Items.RightColumn.ReadOnly					= StatusIsComplete;
	Items.Pages.ReadOnly						= StatusIsComplete;
	
EndProcedure

&AtServerNoContext
Function GetProductionOrderStates()
	
	Query = New Query;
	Query.Text = 
	"SELECT
	|	ProductionOrderStatuses.Ref AS Status
	|FROM
	|	Catalog.ProductionOrderStatuses AS ProductionOrderStatuses
	|		INNER JOIN Enum.OrderStatuses AS OrderStatuses
	|		ON ProductionOrderStatuses.OrderStatus = OrderStatuses.Ref
	|
	|ORDER BY
	|	OrderStatuses.Order";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	ChoiceData = New ValueList;
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Status);
	EndDo;
	
	Return ChoiceData;	
	
EndFunction

#EndRegion


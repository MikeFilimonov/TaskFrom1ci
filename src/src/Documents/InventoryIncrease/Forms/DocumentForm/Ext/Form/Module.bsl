
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region ServiceProceduresAndFunctions

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
	
	If StructureData.Property("PriceKind") Then
		StructureData.Insert("DocumentCurrency", Constants.PresentationCurrency.Get());
		Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
		StructureData.Insert("Price", Price);
	Else
		StructureData.Insert("Price", 0);
	EndIf;
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
// It receives data set from server for the CharacteristicOnChange procedure.
//
Function GetDataCharacteristicOnChange(StructureData)
	
	If TypeOf(StructureData.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", StructureData.MeasurementUnit.Factor);
	EndIf;
	
	StructureData.Insert("DocumentCurrency", Constants.PresentationCurrency.Get());
	Price = DriveServer.GetProductsPriceByPriceKind(StructureData);
	StructureData.Insert("Price", Price);
	
	Return StructureData;
	
EndFunction

// Gets the data set from the server for procedure MeasurementUnitOnChange.
//
&AtServerNoContext
Function GetDataMeasurementUnitOnChange(CurrentMeasurementUnit = Undefined, MeasurementUnit = Undefined)
	
	StructureData = New Structure;
	
	If CurrentMeasurementUnit = Undefined Then
		StructureData.Insert("CurrentFactor", 1);
	Else
		StructureData.Insert("CurrentFactor", CurrentMeasurementUnit.Factor);
	EndIf;
	
	If MeasurementUnit = Undefined Then
		StructureData.Insert("Factor", 1);
	Else
		StructureData.Insert("Factor", MeasurementUnit.Factor);
	EndIf;
	
	Return StructureData;
	
EndFunction

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument()
	
	Document = FormAttributeToValue("Object");
	Document.Filling(Object.BasisDocument, );
	ValueToFormAttribute(Document, "Object");
	Modified = True;	
	FillAddedColumns();
	
EndProcedure

// Procedure recalculates in the document
// tabular section after making changes in the "Prices and currency" form. The columns are recalculated as follows:
// price, amount.
//
&AtClient
Procedure ProcessChangesOnButtonPrices()
	
	// 1. Form parameter structure to fill the "Prices and Currency" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("RefillPrices", False);
	ParametersStructure.Insert("WereMadeChanges", False);
	ParametersStructure.Insert("PriceKind", Object.PriceKind);
	
	StructurePricesAndCurrency = Undefined;
	
	OpenForm("Document.InventoryIncrease.Form.PriceKindChoiceForm", ParametersStructure,,,,, New NotifyDescription("ProcessChangesByPricesEndButton", ThisObject));
	
EndProcedure

&AtClient
Procedure ProcessChangesByPricesEndButton(Result, AdditionalParameters) Export
    
    // 2. Open the form "Prices and Currency".
    StructurePricesAndCurrency = Result;
    
    // 3. Refill the tabular section "Inventory" if changes were made to the form "Prices and Currency".
    If TypeOf(StructurePricesAndCurrency) = Type("Structure")
        AND StructurePricesAndCurrency.WereMadeChanges Then
        
        Object.PriceKind = StructurePricesAndCurrency.PriceKind;
        
        // Recalculate prices by kind of prices.
        If StructurePricesAndCurrency.RefillPrices Then
            RefillTabularSectionPricesByPriceKind();
        EndIf;
        
    EndIf;
    
    // Generate the price label.
    LabelStructure = New Structure("PriceKind", Object.PriceKind);
    PricePresentation = GeneratePriceLabel(LabelStructure);

EndProcedure

// Function returns the "Prices" label text.
//
&AtClientAtServerNoContext
Function GeneratePriceLabel(LabelStructure)
	
	LabelText = "";
	
	// Prices kind.
	If ValueIsFilled(LabelStructure.PriceKind) Then
		LabelText = LabelText + NStr("en = '%PriceKind%'");
		LabelText = StrReplace(LabelText, "%PriceKind%", TrimAll(String(LabelStructure.PriceKind)));
	Else
		LabelText = LabelText + NStr("en = 'specify type prices'");
	EndIf;
	
	Return LabelText;
	
EndFunction

// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
&AtServerNoContext
Procedure GetTabularSectionPricesByPriceKindAtServer(DataStructure, DocumentTabularSection)
	
	DataStructure.Insert("DocumentCurrency", Constants.PresentationCurrency.Get());
	DriveServer.GetTabularSectionPricesByPriceKind(DataStructure, DocumentTabularSection);
	
EndProcedure

&AtClient
// Recalculate the price of the tabular section of the document after making changes in the "Prices and currency" form.
// 
Procedure RefillTabularSectionPricesByPriceKind()
	
	DataStructure = New Structure;
	DocumentTabularSection = New Array;
	
	DataStructure.Insert("Date", Object.Date);
	DataStructure.Insert("Company", ParentCompany);
	DataStructure.Insert("PriceKind", Object.PriceKind);
	For Each TSRow In Object.Inventory Do
		
		TSRow.Price = 0;
		
		If Not ValueIsFilled(TSRow.Products) Then
			Continue;
		EndIf;
		
		TabularSectionRow = New Structure();
		TabularSectionRow.Insert("Products", TSRow.Products);
		TabularSectionRow.Insert("Characteristic", TSRow.Characteristic);
		TabularSectionRow.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		TabularSectionRow.Insert("Price", 0);
		
		DocumentTabularSection.Add(TabularSectionRow);
		
	EndDo;
		
	GetTabularSectionPricesByPriceKindAtServer(DataStructure, DocumentTabularSection);
		
	For Each TSRow In DocumentTabularSection Do

		SearchStructure = New Structure;
		SearchStructure.Insert("Products", TSRow.Products);
		SearchStructure.Insert("Characteristic", TSRow.Characteristic);
		SearchStructure.Insert("MeasurementUnit", TSRow.MeasurementUnit);
		
		SearchResult = Object.Inventory.FindRows(SearchStructure);
		
		For Each ResultRow In SearchResult Do
			
			ResultRow.Price = TSRow.Price;
			ResultRow.Amount = ResultRow.Quantity * ResultRow.Price;
			
		EndDo;
		
	EndDo;
	
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
			If ValueIsFilled(StructureData.PriceKind) Then
				StructureProductsData.Insert("ProcessingDate", StructureData.Date);
				StructureProductsData.Insert("Company", StructureData.Company);
				StructureProductsData.Insert("Characteristic", BarcodeData.Characteristic);
				StructureProductsData.Insert("DocumentCurrency", Constants.PresentationCurrency.Get());
				StructureProductsData.Insert("PriceKind", StructureData.PriceKind);
				If ValueIsFilled(BarcodeData.MeasurementUnit)
					AND TypeOf(BarcodeData.MeasurementUnit) = Type("CatalogRef.UOM") Then
					StructureProductsData.Insert("Factor", BarcodeData.MeasurementUnit.Factor);
				Else
					StructureProductsData.Insert("Factor", 1);
				EndIf;
			EndIf;
			
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
	StructureData.Insert("Company", Object.Company);
	StructureData.Insert("PriceKind", Object.PriceKind);
	StructureData.Insert("Date", Object.Date);
	GetDataByBarCodes(StructureData);
	
	For Each CurBarcode In StructureData.BarcodesArray Do
		BarcodeData = StructureData.DataByBarCodes[CurBarcode.Barcode];
		
		If BarcodeData <> Undefined
		   AND BarcodeData.Count() = 0 Then
			UnknownBarcodes.Add(CurBarcode);
		Else
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Price = BarcodeData.StructureProductsData.Price;
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				NewRow.Amount = NewRow.Quantity * NewRow.Price;
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

#Region ControlOfTheFormAppearance

// Receives the flag of Order warehouse.
//
&AtServer
Procedure SetCellVisible()
	
	If Not ValueIsFilled(Object.StructuralUnit) 
		OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail Then
		Items.Cell.Enabled = False;
	Else
		Items.Cell.Enabled = True;
	EndIf;
	
EndProcedure

&AtServer
// The procedure sets the form
// attributes visible on the option Use subsystem Production.
//
// Parameters:
// No.
//
Procedure SetVisibleByFOUseProductionSubsystem()
	
	// Production.
	If Constants.UseProductionSubsystem.Get() Then
		
		// Setting the method of Business unit selection depending on FO.
		If Not Constants.UseSeveralDepartments.Get()
			AND Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnit.ListChoiceMode = True;
			Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			Items.StructuralUnit.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			
		EndIf;
		
	Else
		
		If Constants.UseSeveralWarehouses.Get() Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
			NewArray.Add(Enums.BusinessUnitsTypes.Retail);
			ArrayTypesOfBusinessUnits = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayTypesOfBusinessUnits);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
			Items.StructuralUnit.ChoiceParameters = NewParameters;
			
		Else
			
			Items.StructuralUnit.Visible = False;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region PickButtonClickProcedures

// Procedure - event handler Action of the
// Pick command
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'inventory increase'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, True, False);
	SelectionParameters.Insert("Company", ParentCompany);
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

// Function gets a product list from
// the temporary storage
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	// Transfer the received positions from the selection to PM
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	StructureData.Insert("Products", TableForImport.UnloadColumn("Products"));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	
	For Each ImportRow In TableForImport Do
		
		NewRow = Object[TabularSectionName].Add();
		FillPropertyValues(NewRow, ImportRow);
		
		FillPropertyValues(StructureData, NewRow);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
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
        BarcodesReceived(New Structure("Barcode, Quantity", CurBarcode, 1));
    EndIf;

EndProcedure

// Procedure - event handler Action of the
// GetWeight command
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
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
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
			GetInventoryFromStorage(InventoryAddressInStorage, "Inventory", True, True);
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Inventory.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False);
	
EndFunction

&AtClient
Procedure CalculateAmountInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Inventory.CurrentData;
	EndIf;
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	SetCellVisible();
	
EndProcedure

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object.Inventory.FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	StructureData = GetStructureData(ObjectParameters, RowData);
	
	GLAccountsForFilling = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	GLAccountsForFilling.Insert("TableName",	"Inventory");
	GLAccountsForFilling.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", GLAccountsForFilling, ThisObject);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	StructureData.Insert("InventoryGLAccount",	TabRow.InventoryGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	Tables.Add(GetStructureData(ObjectParameters));
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
EndProcedure

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabRow);
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, InventoryGLAccount, GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"SalesInvoice.Inventory");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import inventory from file'"));
	
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

#Region CopyPasteRows

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory");   
EndProcedure

&AtClient
Procedure CopyRowsTabularPart(TabularPartName)
	
	If TabularPartCopyClient.CanCopyRows(Object[TabularPartName],Items[TabularPartName].CurrentData) Then
		CountOfCopied = 0;
		CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied);
		TabularPartCopyClient.NotifyUserCopyRows(CountOfCopied);
	EndIf;
	
EndProcedure

&AtServer 
Procedure CopyRowsTabularPartAtSever(TabularPartName, CountOfCopied)
	
	TabularPartCopyServer.Copy(Object[TabularPartName], Items[TabularPartName].SelectedRows, CountOfCopied);
	
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory"); 
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtServer
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructData = New Structure;     	
		StructData.Insert("Products",  Row.Products); 		
		StructData = GetDataProductsOnChange(StructData); 
		
		If Not ValueIsFilled(Row.MeasurementUnit) Then
			Row.MeasurementUnit = StructData.MeasurementUnit;
		EndIf;
		
	EndDo;
	
EndProcedure

#EndRegion

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
	
	If TypeOf(Parameters.Basis) = Type("DocumentRef.Stocktaking") Then
		
		Query = New Query(
		"SELECT
		|	TOP 1 Stocktaking.Quantity - Stocktaking.QuantityAccounting
		|AS
		|	Quantity FROM Document.Stocktaking.Inventory
		|AS
		|	Stocktaking WHERE Stocktaking.Ref
		|	= &BasisDocument AND Stocktaking.Quantity - Stocktaking.QuantityAccounting > 0");
		
		Query.SetParameter("BasisDocument", Parameters.Basis);
		
		QueryResult = Query.Execute();
		If QueryResult.IsEmpty() Then
			DoNotOpenForm = True;
			Return;
		EndIf;
		
	EndIf;
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	PresentationCurrency = Constants.PresentationCurrency.Get();
	
	FillAddedColumns();
	SetCellVisible();
	
	// Generate the price label.
	LabelStructure = New Structure("PriceKind", Object.PriceKind);
	PricePresentation = GeneratePriceLabel(LabelStructure);
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.InventoryIncrease.TabularSections.Inventory, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm, Items.ImportantCommandsGroup);
	// End StandardSubsystems.Printing
	
	// Peripherals
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
	
	Items.InventoryDataImportFromExternalSources.Visible = AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
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
	
	If DoNotOpenForm Then
		Cancel = True;
	EndIf;
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals

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
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
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
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf; 
	ElsIf EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID
		Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateAmountInTabularSectionLine();
		EndIf;
	EndIf;
	
EndProcedure

#Region ActionsOfTheFormCommandpanels

// Procedure - handler of clicking the FillByBasis button.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the inventory increase?'"), QuestionDialogMode.YesNo, 0);	

EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument();		
    EndIf;

EndProcedure

&AtClient
// Procedure is called by clicking
// "Prices" button with command of tabular section panel.
//
Procedure EditPrices(Item, StandardProcessing)
	
	StandardProcessing = False;
	ProcessChangesOnButtonPrices();
	Modified = True;
	
EndProcedure

#EndRegion

#Region EventHandlersOfHeaderAttributes

// Procedure - event handler OnChange of the Date input field.
// The procedure determines the situation when after changing the
// date of a document this document is found in
// another period of documents enumeration, and in this case the procedure assigns new unique number to the document.
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
// In procedure the document
// number is cleared, and also the form functional options are configured.
// Overrides the corresponding form parameter.
//
&AtClient
Procedure CompanyOnChange(Item)

	// Company change event data processor.
	Object.Number = "";
	StructureData = GetCompanyDataOnChange(Object.Company);
	Counterparty = StructureData.Counterparty;
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructuralUnitOnChangeAtServer();
	
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

#Region TabularSectionsHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	If ValueIsFilled(Object.PriceKind) Then
		
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("Factor", 1);
		
	EndIf;
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryCharacteristicOnChange(Item)
	
	If ValueIsFilled(Object.PriceKind) Then
		
		TabularSectionRow = Items.Inventory.CurrentData;
		
		StructureData = New Structure();
		StructureData.Insert("ProcessingDate", Object.Date);
		StructureData.Insert("Company", Object.Company);
		StructureData.Insert("Products", TabularSectionRow.Products);
		StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
		StructureData.Insert("PriceKind", Object.PriceKind);
		StructureData.Insert("MeasurementUnit", TabularSectionRow.MeasurementUnit);
		
		StructureData = GetDataCharacteristicOnChange(StructureData);
		
		TabularSectionRow.Price = StructureData.Price;
		TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
		
	EndIf;
	
EndProcedure

// Procedure - event handler ChoiceProcessing of the MeasurementUnit input field.
//
&AtClient
Procedure InventoryMeasurementUnitChoiceProcessing(Item, ValueSelected, StandardProcessing)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	If TabularSectionRow.MeasurementUnit = ValueSelected 
		OR TabularSectionRow.Price = 0 Then
		Return;
	EndIf;	
	
	CurrentFactor = 0;
	If TypeOf(TabularSectionRow.MeasurementUnit) = Type("CatalogRef.UOMClassifier") Then
		CurrentFactor = 1;
	EndIf;	
	
	Factor = 0;
	If TypeOf(ValueSelected) = Type("CatalogRef.UOMClassifier") Then
		Factor = 1;
	EndIf;
	
	If CurrentFactor = 0 AND Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit, ValueSelected);
	ElsIf CurrentFactor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(TabularSectionRow.MeasurementUnit);
	ElsIf Factor = 0 Then
		StructureData = GetDataMeasurementUnitOnChange(,ValueSelected);
	ElsIf CurrentFactor = 1 AND Factor = 1 Then
		StructureData = New Structure("CurrentFactor, Factor", 1, 1);
	EndIf;
	
	// Price.
	If StructureData.CurrentFactor <> 0 Then
		TabularSectionRow.Price = TabularSectionRow.Price * StructureData.Factor / StructureData.CurrentFactor;
	EndIf; 		
	
	// Amount.
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;
	
EndProcedure

// Procedure - OnChange event handler
// of the Quantity input field in the Inventory tabular section line.
// Recalculates the amount in the tabular section line.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - OnChange event handler
// of the Price input field in the Inventory tabular section line.
// Recalculates the amounts in the tabular section line.
//
&AtClient
Procedure InventoryPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Price;

EndProcedure

// Procedure - OnChange event handler
// of the Amount input field in the Inventory tabular section line.
// Recalculates prices in the tabular section line.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Price = ?(TabularSectionRow.Quantity = 0, 0, TabularSectionRow.Amount / TabularSectionRow.Quantity);

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
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

&AtClient
Procedure InventorySelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow);
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
			OpenProductGLAccountsForm(SelectedRow);
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
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

#EndRegion

#EndRegion

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

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
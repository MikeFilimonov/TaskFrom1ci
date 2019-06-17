
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// The procedure fills in the "Inventory by standards" tabular section.
//
Procedure FillTabularSectionInventoryByStandards()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryFillingByStandards();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the "Inventory by balance" tabular section.
//
Procedure FillTabularSectionInventoryByBalance()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryFillingByBalance();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns();
	
EndProcedure

// The procedure fills in the "InventoryAllocation by standards" tabular section.
//
Procedure FillTabularSectionInventoryDistributionByStandards()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryDistributionByStandards();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the "InventoryAllocation by quantity" tabular section.
//
Procedure FillTabularSectionInventoryDistributionByCount()
	
	Document = FormAttributeToValue("Object");
	Document.RunInventoryDistributionByCount();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the Costs tabular section.
//
Procedure FillTabularSectionCostsByBalance()
	
	Document = FormAttributeToValue("Object");
	Document.RunExpenseFillingByBalance();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the ExpensesAllocation tabular section.
//
Procedure FillTabularSectionCostingByCount()
	
	Document = FormAttributeToValue("Object");
	Document.RunCostingByCount();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

// The procedure fills in the Production tabular section.
//
Procedure FillTabularSectionProductsByOutput()
	
	Document = FormAttributeToValue("Object");
	Document.RunProductsFillingByOutput();
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
&AtServer
Function GetCompanyDataOnChange(Company)
	
	FillAddedColumns(True);
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	Return StructureData;
	
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
	
	RowParameters = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",	TabName);
	RowParameters.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",				TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",		TabRow.GLAccountsFilled);
	StructureData.Insert("ConsumptionGLAccount",	TabRow.ConsumptionGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	
	Tables = New Array();
	Tables.Add(GetStructureData(ObjectParameters, "Inventory"));
	Tables.Add(GetStructureData(ObjectParameters, "InventoryDistribution"));
	Tables.Add(GetStructureData(ObjectParameters, "CostAllocation"));
	
	GLAccountsInDocuments.FillGLAccountsInTable(Object, Tables, GetGLAccounts);
	
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
		
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, TabName, RowData = Undefined, ProductName = "Products") Export
	
	If TabName = "Inventory"
		Or TabName = "InventoryDistribution"
		Or TabName = "CostAllocation" Then
		StructureData = New Structure("Products, ConsumptionGLAccount, GLAccounts, GLAccountsFilled");
		
	EndIf;
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
		
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", TabName);
	StructureData.Insert("ProductName", ProductName);
	
	Return StructureData;

EndFunction

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
			StructureProductsData.Insert("Company", StructureData.Company);
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
	StructureData.Insert("Company", Object.Company);
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

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure ProductsPick(Command)
	
	TabularSectionName	= "Products";
	DocumentPresentaion	= NStr("en = 'cost allocation'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure InventoryPick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'cost allocation'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, False);
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
		
		If TabularSectionName = "Inventory" Then
			NewRow.ConnectionKey = DriveServer.CreateNewLinkKey(ThisForm);
		EndIf;
		
		FillPropertyValues(NewRow, ImportRow);
		
		FillPropertyValues(StructureData, NewRow);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(NewRow, StructureData);
		
	EndDo;
	
EndProcedure

// Procedure of processing the results of selection closing
//
&AtClient
Procedure OnCloseSelection(ClosingResult, AdditionalParameters) Export
	
	If TypeOf(ClosingResult) = Type("Structure") Then
		
		If Not IsBlankString(ClosingResult.CartAddressInStorage) Then
			
			InventoryAddressInStorage	= ClosingResult.CartAddressInStorage;
			TabularSectionName 	= ?(Items.Pages.CurrentPage = Items.GroupProducts, "Products", "Inventory");
			
			GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, True, True);		
			
		EndIf;
		
	EndIf;
	
EndProcedure
#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

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
		Parameters.FillingValues
	);
	
	// Form attributes setting.
	DocumentDate = Object.Date;
	If Not ValueIsFilled(DocumentDate) Then
		DocumentDate = CurrentDate();
	EndIf;
	
	ParentCompany = DriveServer.GetCompany(Object.Company);
	
	FillAddedColumns();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
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
	
	If StructureData.TabName <> "Products" Then
		GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	EndIf;
	
	Return StructureData;
	
EndFunction

// It receives data set from server for the CharacteristicOnChange procedure.
//
&AtServerNoContext
Function GetDataCharacteristicOnChange(StructureData)
	
	StructureData.Insert("Specification", DriveServer.GetDefaultSpecification(StructureData.Products, StructureData.Characteristic));
	
	Return StructureData;
	
EndFunction

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - FORM TABULAR SECTIONS COMMAND PANELS ACTIONS

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryFillByStandards(Command)
	
	If Object.Inventory.Count() <> 0 Then

		QuestionText = NStr("en = 'The ""Inventory"" tabular section will be filled in again.'") + Chars.LF;
		If Object.InventoryDistribution.Count() <> 0 Then
			QuestionText = QuestionText + NStr("en = 'The ""Inventory allocation"" tabular section will be cleared.'") + Chars.LF;
		EndIf;	
		QuestionText = QuestionText + NStr("en = 'Continue?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryFillByStandardsEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryFillByStandardsFragment();
EndProcedure

&AtClient
Procedure InventoryFillByStandardsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryFillByStandardsFragment();

EndProcedure

&AtClient
Procedure InventoryFillByStandardsFragment()
    
    FillTabularSectionInventoryByStandards();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryFillByBalances(Command)
	
	If Object.Inventory.Count() <> 0 Then

		QuestionText = NStr("en = 'The ""Inventory"" tabular section will be filled in again.'") + Chars.LF;
		If Object.InventoryDistribution.Count() <> 0 Then
			QuestionText = QuestionText + NStr("en = 'The ""Inventory allocation"" tabular section will be cleared.'") + Chars.LF;
		EndIf;	
		QuestionText = QuestionText + NStr("en = 'Continue?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryFillByBalancesEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryFillByBalancesFragment();
EndProcedure

&AtClient
Procedure InventoryFillByBalancesEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryFillByBalancesFragment();

EndProcedure

&AtClient
Procedure InventoryFillByBalancesFragment()
    
    FillTabularSectionInventoryByBalance();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryDistributeByStandards(Command)
	
	If Object.InventoryDistribution.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryDistributeByStandardsEnd", ThisObject), NStr("en = 'The ""Inventory allocation"" tabular section will be filled in again. Continue?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryDistributeByStandardsFragment();
EndProcedure

&AtClient
Procedure InventoryDistributeByStandardsEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryDistributeByStandardsFragment();

EndProcedure

&AtClient
Procedure InventoryDistributeByStandardsFragment()
    
    FillTabularSectionInventoryDistributionByStandards();
    
    If Object.Inventory.Count() <> 0 Then
        
        If Items.Inventory.CurrentRow = Undefined Then
            Items.Inventory.CurrentRow = 0;
        EndIf;	
        
        TabularSectionName = "Inventory";
        DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure InventoryDistributeByQuantity(Command)
	
	If Object.InventoryDistribution.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("InventoryDistributeByQuantityEnd", ThisObject), NStr("en = 'The ""Inventory allocation"" tabular section will be filled in again. Continue?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	InventoryDistributeByQuantityFragment();
EndProcedure

&AtClient
Procedure InventoryDistributeByQuantityEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    InventoryDistributeByQuantityFragment();

EndProcedure

&AtClient
Procedure InventoryDistributeByQuantityFragment()
    
    FillTabularSectionInventoryDistributionByCount();
    
    If Object.Inventory.Count() <> 0 Then
        
        If Items.Inventory.CurrentRow = Undefined Then
            Items.Inventory.CurrentRow = 0;
        EndIf;
        
        TabularSectionName = "Inventory";
        DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CostsFillByBalance(Command)
	
	If Object.Costs.Count() <> 0 Then

		QuestionText = NStr("en = 'The ""Expenses"" tabular section will be filled in again.'") + Chars.LF;
		QuestionText = QuestionText + NStr("en = 'The ""Expense allocation"" tabular section will be filled in again.'") + Chars.LF;
		QuestionText = QuestionText + NStr("en = 'Continue?'");
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("CostsFillByBalanceEnd", ThisObject), QuestionText, QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	CostsFillByBalanceFragment();
EndProcedure

&AtClient
Procedure CostsFillByBalanceEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    CostsFillByBalanceFragment();

EndProcedure

&AtClient
Procedure CostsFillByBalanceFragment()
    
    FillTabularSectionCostsByBalance();

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure CostsDistributeByQuantity(Command)
	                  
	If Object.CostAllocation.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("AllocateCostsByQuantityEnd", ThisObject), NStr("en = 'The ""Expense allocation"" tabular section will be filled in again. Continue?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	AllocateCostsByQuantityFragment();
EndProcedure

&AtClient
Procedure AllocateCostsByQuantityEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    AllocateCostsByQuantityFragment();

EndProcedure

&AtClient
Procedure AllocateCostsByQuantityFragment()
    
    FillTabularSectionCostingByCount();
    
    If Object.Costs.Count() <> 0 Then
        
        If Items.Costs.CurrentRow = Undefined Then
            Items.Costs.CurrentRow = 0;
        EndIf;
        
        TabularSectionName = "Costs";
        DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
        
    EndIf;

EndProcedure

// Procedure - command handler of the tabular section command panel.
//
&AtClient
Procedure ProductsFillByOutput(Command)
	
	If Object.Products.Count() <> 0 Then

		Response = Undefined;

		ShowQueryBox(New NotifyDescription("ProductsFillByOutputEnd", ThisObject), NStr("en = 'The ""Products"" tabular section will be filled in again. Continue?'"), 
							QuestionDialogMode.YesNo, 0);
        Return;
 
	EndIf;
	
	ProductsFillByOutputFragment();
EndProcedure

&AtClient
Procedure ProductsFillByOutputEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    
    If Response = DialogReturnCode.No Then
        Return;
    EndIf;
    
    
    ProductsFillByOutputFragment();

EndProcedure

&AtClient
Procedure ProductsFillByOutputFragment()
    
    FillTabularSectionProductsByOutput();

EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - TABULAR SECTIONS EVENT HANDLERS

// Procedure - OnActivating event handler of the Costs tabular section.
//
&AtClient
Procedure CostsOnActivateRow(Item)
	
	TabularSectionName = "Costs";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Costs tabular section.
//
&AtClient
Procedure CostsOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Costs";
	If NewRow Then

		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "CostAllocation");
		
	EndIf;

EndProcedure

// Procedure - BeforeDeleting event handler of the Costs tabular section.
//
&AtClient
Procedure CostsBeforeDelete(Item, Cancel)

	TabularSectionName = "Costs";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "CostAllocation");

EndProcedure

// Procedure - OnStartEdit event handler of the CostAllocation tabular section.
//
&AtClient
Procedure CostingOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Costs";
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

// Procedure - BeforeStartAdding event handler of the CostAllocation tabular section.
//
&AtClient
Procedure CostingBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Costs";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
Procedure CostingSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "CostAllocationGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "CostAllocation");
	EndIf;
	
EndProcedure

&AtClient
Procedure CostingOnActivateCell(Item)
	
	CurrentData = Items.CostAllocation.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.CostAllocation.CurrentItem;
		If TableCurrentColumn.Name = "CostAllocationGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.CostAllocation.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "CostAllocation");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure CostingOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure CostingGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.CostAllocation.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "CostAllocation");
	
EndProcedure

// Procedure - OnActivating event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnActivateRow(Item)
	
	TabularSectionName = "Inventory";
	DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
	
EndProcedure

// Procedure - OnStartEdit event handler of the Inventory tabular section.
//
&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Inventory";
	If NewRow Then

		DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
		DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
		
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

// Procedure - handler of event BeforeDelete of tabular section Inventory.
//
&AtClient
Procedure InventoryBeforeDelete(Item, Cancel)

	TabularSectionName = "Inventory";
	DriveClient.DeleteRowsOfSubordinateTabularSection(ThisForm, "InventoryDistribution");

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

// Procedure - OnStartEdit event handler of the InventoryAllocation tabular section.
//
&AtClient
Procedure InventoryDistributionOnStartEdit(Item, NewRow, Copy)
	
	TabularSectionName = "Inventory";
	If NewRow Then
		DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, Item.Name);
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

// Procedure - BeforeStartEditing event handler of the InventoryAllocation tabular section.
//
&AtClient
Procedure InventoryDistributionBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	TabularSectionName = "Inventory";
	Cancel = DriveClient.BeforeAddToSubordinateTabularSection(ThisForm, Item.Name);
	
EndProcedure

&AtClient
Procedure InventoryDistributionSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "InventoryDistributionGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow, "InventoryDistribution");
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryDistributionOnActivateCell(Item)
	
	CurrentData = Items.InventoryDistribution.CurrentData;
	
	If CurrentData = Undefined Then
		Return;
	EndIf;
	
	If ThisIsNewRow Then
		TableCurrentColumn = Items.InventoryDistribution.CurrentItem;
		If TableCurrentColumn.Name = "InventoryDistributionGLAccounts"
			And Not CurrentData.GLAccountsFilled Then
			SelectedRow = Items.InventoryDistribution.CurrentRow;
			OpenProductGLAccountsForm(SelectedRow, "InventoryDistribution");
		EndIf;
	EndIf;
	
EndProcedure

&AtClient
Procedure InventoryDistributionOnEditEnd(Item, NewRow, CancelEdit)
	ThisIsNewRow = False;
EndProcedure

&AtClient
Procedure InventoryDistributionGLAccountsStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	SelectedRow = Items.InventoryDistribution.CurrentRow;
	OpenProductGLAccountsForm(SelectedRow, "InventoryDistribution");
	
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
	StructureData.Insert("TabName", "Products");
	
	StructureData = GetDataProductsOnChange(StructureData);
	
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	TabularSectionRow.Specification = StructureData.Specification;

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
	StructureData.Insert("TabName", "Inventory");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
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

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF INVENTORY ALLOCATION TS ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryDistributionProductsOnChange(Item)
	
	TabularSectionRow = Items.InventoryDistribution.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "InventoryDistribution");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure InventoryDistributionCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.InventoryDistribution.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// PROCEDURE - EVENT HANDLERS OF COSTS ALLOCATION TS ATTRIBUTES

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure CostAllocationProductsOnChange(Item)
	
	TabularSectionRow = Items.CostAllocation.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("TabName", "CostAllocation");
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

// Procedure - event handler OnChange of the Characteristic input field.
//
&AtClient
Procedure CostingCharacteristicOnChange(Item)
	
	TabularSectionRow = Items.CostAllocation.CurrentData;
	
	StructureData = New Structure;
	StructureData.Insert("Products", TabularSectionRow.Products);
	StructureData.Insert("Characteristic", TabularSectionRow.Characteristic);
	
	StructureData = GetDataCharacteristicOnChange(StructureData);
	
	TabularSectionRow.Specification = StructureData.Specification;
	
EndProcedure

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

#Region CopyPasteRows

&AtClient
Procedure ProductsCopyRows(Command)
	CopyRowsTabularPart("Products");
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
Procedure ProductsPasteRows(Command)
	PasteRowsTabularPart("Products");
EndProcedure

&AtClient
Procedure PasteRowsTabularPart(TabularPartName)
	
	CountOfCopied = 0;
	CountOfPasted = 0;
	PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted);
	ProcessPastedRows(TabularPartName, CountOfPasted);
	TabularPartCopyClient.NotifyUserPasteRows(CountOfCopied, CountOfPasted);
	
EndProcedure

&AtServer
Procedure PasteRowsTabularPartAtServer(TabularPartName, CountOfCopied, CountOfPasted)
	
	TabularPartCopyServer.Paste(Object, TabularPartName, Items, CountOfCopied, CountOfPasted);
	ProcessPastedRowsAtServer(TabularPartName, CountOfPasted);
	
EndProcedure

&AtClient 
Procedure ProcessPastedRows(TabularPartName, CountOfPasted)
	
	
	If TabularPartName = "Inventory" Then 
		
		Count = Object[TabularPartName].Count();
		
		For iterator = 1 To CountOfPasted Do
			
			Row = Object[TabularPartName][Count - iterator];
			
			DriveClient.AddConnectionKeyToTabularSectionLine(ThisForm);
			DriveClient.SetFilterOnSubordinateTabularSection(ThisForm, "InventoryDistribution");
			
			
			Items[TabularPartName].SelectedRows.Add(Row.GetID());
			
			
		EndDo; 
		
	ElsIf  TabularPartName = "InventoryDistribution"  Then
		
		Count = Object[TabularPartName].Count();
		
		For iterator = 1 To CountOfPasted Do
			
			Row = Object[TabularPartName][Count - iterator];	
			
			DriveClient.AddConnectionKeyToSubordinateTabularSectionLine(ThisForm, "InventoryDistribution");

			Items[TabularPartName].SelectedRows.Add(Row.GetID());

		EndDo; 	
		
		
	EndIf;   	

	
EndProcedure

&AtServer 
Procedure ProcessPastedRowsAtServer(TabularPartName, CountOfPasted)
	
	Count = Object[TabularPartName].Count();
	
	For iterator = 1 To CountOfPasted Do
		
		Row = Object[TabularPartName][Count - iterator];
		
		StructData = New Structure;
	
		StructData.Insert("Products",  Row.Products);
		StructData.Insert("Characteristic", 	  Row.Characteristic);
		
		StructData = GetDataProductsOnChange(StructData);
		
		If Not ValueIsFilled(Row.Characteristic) Then
			Row.Characteristic = StructData.Characteristic;
		EndIf;
		
		
		If TabularPartName = "Inventory" OR TabularPartName = "Products" Then 
			
			If Not ValueIsFilled(Row.MeasurementUnit) Then
				Row.MeasurementUnit = StructData.MeasurementUnit;
			EndIf;
			
		EndIf;   		
		
	EndDo;
	
EndProcedure

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory"); 
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory");
EndProcedure

&AtClient
Procedure InventoryDistributionCopyRows(Command)
	CopyRowsTabularPart("InventoryDistribution");
EndProcedure

&AtClient
Procedure InventoryDistributionPasteRows(Command)
	PasteRowsTabularPart("InventoryDistribution");   
EndProcedure

#EndRegion

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
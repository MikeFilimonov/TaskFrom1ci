
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	FillAddedColumns();
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// StandardSubsystems.ObjectVersioning
	ObjectVersioning.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.ObjectVersioning
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.GoodsReceipt.TabularSections.Products, DataLoadSettings, ThisObject);
	// End StandardSubsystems.DataImportFromExternalSource
	
	// StandardSubsystems.Printing
	PrintManagement.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.Printing
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "AdditionalAttributesGroup");
	// End StandardSubsystems.Properties
	
	// Serial numbers
	UseSerialNumbersBalance = WorkWithSerialNumbers.UseSerialNumbersBalance();
	
	DriveServer.OverrideStandartGenerateSupplierInvoiceCommand(ThisForm);
	
	FillAddedColumns();
	SetVisibleAndEnabled();
	
	Items.ProductsDataImportFromExternalSources.Visible =
		AccessRight("Use", Metadata.DataProcessors.DataImportFromExternalSources);
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillAddedColumns();
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties

EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	// StandardSubsystems.Properties
	PropertiesManagement.FillCheckProcessing(ThisForm, Cancel, CheckedAttributes);
	// End StandardSubsystems.Properties

EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "SerialNumbersSelection"
		AND ValueIsFilled(Parameter) 
		// Form owner checkup
		AND Source <> New UUID("00000000-0000-0000-0000-000000000000")
		AND Source = UUID Then
		
		ChangedCount = GetSerialNumbersFromStorage(Parameter.AddressInTemporaryStorage, Parameter.RowKey);
		If ChangedCount Then
			CalculateQuantityInTabularSectionLine();
		EndIf;
		
	EndIf;
	
	// Properties subsystem
	If PropertiesManagementClient.ProcessAlerts(ThisForm, EventName, Parameter) Then
		UpdateAdditionalAttributesItems();
	EndIf;
	
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If ChoiceSource.FormName = "CommonForm.SelectionFromOrders" Then
		OrderedProductsSelectionProcessingAtServer(SelectedValue.TempStorageInventoryAddress);
	ElsIf ChoiceSource.FormName = "CommonForm.ProductGLAccounts" Then
		GLAccountsChoiceProcessingAtClient(SelectedValue);
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsHandlers

&AtClient
Procedure CompanyOnChange(Item)
	CompanyOnChangeAtServer();
EndProcedure

&AtClient
Procedure CounterpartyOnChange(Item)
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
EndProcedure

&AtClient
Procedure OperationTypeOnChange(Item)
	ProcessOperationTypeChange();
EndProcedure

&AtClient
Procedure StructuralUnitOnChange(Item)
	StructuralUnitOnChangeAtServer();	
EndProcedure

#EndRegion

#Region TableEventHandlers

&AtClient
Procedure ProductsProductOnChange(Item)
	
	TabularSectionRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Company",			Object.Company);
	StructureData.Insert("Products",		TabularSectionRow.Products);
	StructureData.Insert("Characteristic",	TabularSectionRow.Characteristic);
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit	= StructureData.MeasurementUnit;
	TabularSectionRow.Quantity			= 1;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow,, UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure ProductsQuantityOnChange(Item)
	CalculateQuantityInTabularSectionLine();
EndProcedure

&AtClient
Procedure ProductsSerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();

EndProcedure

&AtClient
Procedure ProductsSupplierInvoiceOnChange(Item)
	
	TabRow = Items.Products.CurrentData;
	
	StructureData = New Structure();
	AddGLAccountsToStructure(StructureData, TabRow);
	StructureData.Insert("Products",		TabRow.Products);
	StructureData.Insert("SupplierInvoice",	TabRow.SupplierInvoice);

	ProductsSupplierInvoiceOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure ProductsBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Products.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData,, UseSerialNumbersBalance);

EndProcedure

&AtClient
Procedure ProductsOnStartEdit(Item, NewRow, Clone)
	
	If NewRow AND Clone Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;
	
	If Item.CurrentItem.Name = "SerialNumbersInventory" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Clone Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();

EndProcedure

&AtClient
Procedure ProductsSelection(Item, SelectedRow, Field, StandardProcessing)
	
	If Field.Name = "ProductsGLAccounts" Then
		StandardProcessing = False;
		OpenProductGLAccountsForm(SelectedRow);
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
			OpenProductGLAccountsForm(SelectedRow);
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
	OpenProductGLAccountsForm(SelectedRow);
	
EndProcedure

#EndRegion

#Region CommandHandlenrs

&AtClient
Procedure FillFromOrder(Command)
	
	ShowQueryBox(New NotifyDescription("FillByOrderEnd", ThisObject),
		NStr("en = 'The document will be fully filled out according to the ""Order."" Continue?'"),
		QuestionDialogMode.YesNo);
	
EndProcedure

&AtClient
Procedure FillByOrderEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Yes Then
		FillByDocument(Object.Order);
	EndIf;

EndProcedure

&AtClient
Procedure Settings(Command)
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("PurchaseOrderPositionInReceiptDocuments", Object.OrderPosition);
	ParametersStructure.Insert("WereMadeChanges", False);
	
	InvCount = Object.Products.Count();
	If InvCount > 1 Then
		
		CurrOrder = Object.Products[0].Order;
		MultipleOrders = False;
		
		For Index = 1 To InvCount - 1 Do
			
			If CurrOrder <> Object.Products[Index].Order Then
				MultipleOrders = True;
				Break;
			EndIf;
			
			CurrOrder = Object.Products[Index].Order;
			
		EndDo;
		
		If MultipleOrders Then
			ParametersStructure.Insert("ReadOnly", True);
		EndIf;
		
	EndIf;
	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("SettingEnd", ThisObject));
	
EndProcedure

#EndRegion

#Region WorkWithSelect

&AtClient
Procedure SelectOrderedProducts(Command)

	Try
		LockFormDataForEdit();
		Modified = True;
	Except
		ShowMessageBox(Undefined, BriefErrorDescription(ErrorInfo()));
		Return;
	EndTry;
	
	SelectionParameters = New Structure(
		"Ref,
		|Company,
		|StructuralUnit,
		|Counterparty,
		|Contract,
		|Order");
	FillPropertyValues(SelectionParameters, Object);
	
	SelectionParameters.Insert("TempStorageInventoryAddress", PutProductsToTempStorage());
	SelectionParameters.Insert("ShowGoodsIssue", False);
	SelectionParameters.Insert("ShowPurchaseOrders", True);
	
	OpenForm("CommonForm.SelectionFromOrders", SelectionParameters, ThisForm, , , , , FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

&AtServer
Function PutProductsToTempStorage()
	
	ProductsTable = Object.Products.Unload();
	
	ProductsTable.Columns.Add("Reserve", New TypeDescription("Number"));
	ProductsTable.Columns.Add("Content", New TypeDescription("String"));
	ProductsTable.Columns.Add("GoodsIssue", New TypeDescription("DocumentRef.GoodsIssue"));
	ProductsTable.Columns.Add("SalesInvoice", New TypeDescription("DocumentRef.SalesInvoice"));
	
	If ValueIsFilled(Object.Order) Then
		For Each ProductRow In ProductsTable Do
			
			If Not ValueIsFilled(ProductRow.Order) Then
				ProductRow.Order = Object.Order;
			EndIf;
			
			ProductRow.Content = String(ProductRow.Products);
			
		EndDo;
	EndIf;
	
	Return PutToTempStorage(ProductsTable);
	
EndFunction

&AtServer
Procedure OrderedProductsSelectionProcessingAtServer(TempStorageInventoryAddress)
	
	TablesStructure = GetFromTempStorage(TempStorageInventoryAddress);
	
	InventorySearchStructure = New Structure("Products, Characteristic, Batch, Order");
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
	
	For Each InventoryRow In TablesStructure.Inventory Do
		
		FillPropertyValues(InventorySearchStructure, InventoryRow);
		InventorySearchStructure.Products = InventoryRow.Products;
		
		TS_InventoryRows = Object.Products.FindRows(InventorySearchStructure);
		For Each TS_InventoryRow In TS_InventoryRows Do
			Object.Products.Delete(TS_InventoryRow);
		EndDo;
			
		TS_InventoryRow = Object.Products.Add();
		FillPropertyValues(TS_InventoryRow, InventoryRow);
		
		FillPropertyValues(StructureData, TS_InventoryRow);
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
		GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
		FillPropertyValues(TS_InventoryRow, StructureData);
		
	EndDo;
	
	OrdersTable = Object.Products.Unload( , "Order, Contract");
	OrdersTable.GroupBy("Order, Contract");
	
	If OrdersTable.Count() > 1 Then
		Object.Order = Undefined;
		Object.Contract = Undefined;
		Object.OrderPosition = Enums.AttributeStationing.InTabularSection;
	ElsIf OrdersTable.Count() = 1 Then
		Object.Order = OrdersTable[0].Order;
		Object.Contract = OrdersTable[0].Contract;
		Object.OrderPosition = Enums.AttributeStationing.InHeader;
	EndIf;
	
	SetVisibleFromUserSettings();
	
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
Procedure DataImportFromExternalSources(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"GoodsReceipt.Products");
	DataLoadSettings.Insert("Title",					NStr("en = 'Import products from file'"));
	
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

// StandardSubsystems.Properties
&AtClient
Procedure Attachable_EditContentOfProperties(Command)
	
	PropertiesManagementClient.EditContentOfProperties(ThisForm, Object.Ref);
	
EndProcedure

&AtServer
Procedure UpdateAdditionalAttributesItems()
	
	PropertiesManagement.UpdateAdditionalAttributesItems(ThisForm, FormAttributeToValue("Object"));
	
EndProcedure
// End StandardSubsystems.Properties

#EndRegion

#Region Private

&AtClient
Procedure Attachable_GenerateSupplierInvoice(Command)
	
	Array = New Array;
	Array.Add(Object.Ref);
	
	DriveClient.SupplierInvoiceGenerationBasedOnGoodsReceipt(Array);
	
EndProcedure

&AtServer
Procedure CompanyOnChangeAtServer()
	FillAddedColumns(True);
EndProcedure

&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	StructureData.Insert("MeasurementUnit", StructureData.Products.MeasurementUnit);
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

&AtServerNoContext
Function GetContractByDefault(Document, Counterparty, Company, OperationType)
	
	If Not Counterparty.DoOperationsByContracts Then
		Return Counterparty.ContractByDefault;
	EndIf;
	
	ManagerOfCatalog = Catalogs.CounterpartyContracts;
	
	ContractTypesList = ManagerOfCatalog.GetContractKindsListForDocument(Document, OperationType);
	ContractByDefault = ManagerOfCatalog.GetDefaultContractByCompanyContractKind(Counterparty, Company, ContractTypesList);
	
	Return ContractByDefault;
	
EndFunction

&AtClient
Procedure OpenSerialNumbersSelection()
		
	CurrentDataIdentifier = Items.Products.CurrentData.GetID();
	ParametersOfSerialNumbers = SerialNumberPickParameters(CurrentDataIdentifier);
	
	OpenForm("DataProcessor.SerialNumbersSelection.Form", ParametersOfSerialNumbers, ThisObject);

EndProcedure

&AtServer
Procedure SetVisibleFromUserSettings()
	
	Items.FormSettings.Visible = Object.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier;

	VisibleValue = Object.OrderPosition = Enums.AttributeStationing.InHeader
					OR Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty
					OR Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty;
	
	Items.Order.Enabled = VisibleValue;
	Items.Contract.Enabled = VisibleValue;

	If VisibleValue Then
		Items.Order.InputHint = "";
		Items.Contract.InputHint = "";
	Else 
		Items.Order.InputHint = NStr("en = '<Multiple orders mode>'");
		Items.Contract.InputHint = NStr("en = '<Multiple orders mode>'");
	EndIf;
	
	Items.ProductsOrder.Visible = Not VisibleValue;
	Items.ProductsContract.Visible = Not VisibleValue;
	Items.FillFromOrder.Visible = VisibleValue;
	
EndProcedure

&AtClient
Procedure SettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.OrderPosition = StructureDocumentSetting.PurchaseOrderPositionInReceiptDocuments;
		If Object.OrderPosition = PredefinedValue("Enum.AttributeStationing.InHeader") Then
			
			If Object.Products.Count() Then
				Object.Order = Object.Products[0].Order;
				Object.Contract = Object.Products[0].Contract;
			EndIf;
			
		Else
			
			If ValueIsFilled(Object.Order) Then
				For Each InventoryRow In Object.Products Do
					If Not ValueIsFilled(InventoryRow.Order) Then
						InventoryRow.Order = Object.Order;
					EndIf;
				EndDo;
				
				Object.Order = Undefined;
			EndIf;
			
			If ValueIsFilled(Object.Contract) Then
				For Each InventoryRow In Object.Products Do
					If Not ValueIsFilled(InventoryRow.Contract) Then
						InventoryRow.Contract = Object.Contract;
					EndIf;
				EndDo;
				
				Object.Contract = Undefined;
			EndIf;
			
		EndIf;
		
		SetVisibleAndEnabled();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure StructuralUnitOnChangeAtServer()
	
	FillAddedColumns(True);
	SetVisibleAndEnabled();
	
EndProcedure

&AtServer
Function GetSerialNumbersFromStorage(AddressInTemporaryStorage, RowKey)
	
	Modified = True;
	AdditionalParameters = New Structure("NameTSInventory", "Products");
	
	Return WorkWithSerialNumbers.GetSerialNumbersFromStorage(Object, AddressInTemporaryStorage, RowKey, AdditionalParameters);
	
EndFunction

&AtServer
Function SerialNumberPickParameters(CurrentDataIdentifier)
	Return WorkWithSerialNumbers.SerialNumberPickParameters(Object, ThisObject.UUID, CurrentDataIdentifier, False, "Products");
EndFunction

&AtClient
Procedure CalculateQuantityInTabularSectionLine(TabularSectionRow = Undefined)
	
	If TabularSectionRow = Undefined Then
		TabularSectionRow = Items.Products.CurrentData;
	EndIf;
	
	// Serial numbers
	If UseSerialNumbersBalance <> Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow, "SerialNumbers");
	EndIf;

EndProcedure

&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument, "", True);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	FillAddedColumns();
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtServer
Procedure ProcessOperationTypeChange()
	
	If NOT GetFunctionalOption("UseBatches")
		AND (Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty
			OR Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty) Then
			
		CommonUseClientServer.MessageToUser(NStr("en = 'The functional option ""Use batches"" should be on for this operation type'"),, 
			"OperationKind");
			
	EndIf;
	
	FillAddedColumns(True);
	SetVisibleAndEnabled();
	
	Object.Contract = GetContractByDefault(Object.Ref, Object.Counterparty, Object.Company, Object.OperationType);
	
EndProcedure

&AtServer
Procedure SetVisibleAndEnabled()
	
	If Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
		Items.GroupOrder.Visible = False;
		Items.ProductsOrder.Visible = False;
	ElsIf Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
		Items.ProductsOrder.Visible = False;
	Else
		Items.GroupOrder.Visible = True;
		Items.ProductsOrder.Visible = True;
	EndIf;
	
	If Object.OperationType = Enums.OperationTypesGoodsReceipt.PurchaseFromSupplier Then
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.PurchaseOrder");
		
		ParamentersArray = New Array;
		NewParameter = New ChoiceParameter("Filter.OperationKind", Enums.OperationTypesPurchaseOrder.OrderForPurchase);
		ParamentersArray.Add(NewParameter);
		
		Items.Order.ChoiceParameters = New FixedArray(ParamentersArray);
	Else
		Items.Order.TypeRestriction = New TypeDescription("DocumentRef.SalesOrder");
		
		ParamentersArray = New Array;
		NewParameter = New ChoiceParameter("Filter.OperationKind", Enums.OperationTypesSalesOrder.OrderForProcessing);
		ParamentersArray.Add(NewParameter);
		
		Items.Order.ChoiceParameters = New FixedArray(ParamentersArray);
	EndIf;
	
	If GetFunctionalOption("UseBatches") Then
		
		If Object.OperationType = Enums.OperationTypesGoodsReceipt.ReceiptFromAThirdParty Then
			
			NewParameter = New ChoiceParameter("Filter.Status", Enums.BatchStatuses.CounterpartysInventory);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
		ElsIf Object.OperationType = Enums.OperationTypesGoodsReceipt.ReturnFromAThirdParty Then
			
			NewArray = New Array();
			NewArray.Add(Enums.BatchStatuses.OwnInventory);
			NewArray.Add(Enums.BatchStatuses.CounterpartysInventory);
			ArrayOwnInventoryAndGoodsOnCommission = New FixedArray(NewArray);
			NewParameter = New ChoiceParameter("Filter.Status", ArrayOwnInventoryAndGoodsOnCommission);
			NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", ArrayOwnInventoryAndGoodsOnCommission);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewArray.Add(NewParameter2);
			NewParameters = New FixedArray(NewArray);
			
		Else
			
			NewParameter = New ChoiceParameter("Filter.Status", Enums.BatchStatuses.OwnInventory);
			NewArray = New Array();
			NewArray.Add(NewParameter);
			NewParameters = New FixedArray(NewArray);
			
		EndIf;
		
		Items.ProductsBatch.ChoiceParameters = NewParameters;
		
	EndIf;
	
	StructuralUnitType = Object.StructuralUnit.StructuralUnitType;
	
	If Not ValueIsFilled(Object.StructuralUnit)
		OR StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items.Cell.Visible = False;
	Else
		Items.Cell.Visible = True;
	EndIf;
	
	SetVisibleFromUserSettings();
	
EndProcedure

&AtClient
Procedure OpenProductGLAccountsForm(SelectedValue)

	If SelectedValue = Undefined Then
		Return;
	EndIf;

	If Not ReadOnly Then
		LockFormDataForEdit();
	EndIf;

	RowData = Object.Products.FindByID(SelectedValue);
	
	ObjectParameters = GLAccountsInDocumentsClientServer.GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, RowData);
	
	RowParameters = GLAccountsInDocumentsClientServer.GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",	"Products");
	RowParameters.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("InventoryGLAccount",					TabRow.InventoryGLAccount);
	StructureData.Insert("InventoryTransferredGLAccount",		TabRow.InventoryTransferredGLAccount);
	StructureData.Insert("InventoryReceivedGLAccount",			TabRow.InventoryReceivedGLAccount);
	StructureData.Insert("GoodsReceivedNotInvoicedGLAccount",	TabRow.GoodsReceivedNotInvoicedGLAccount);
	StructureData.Insert("GoodsInvoicedNotDeliveredGLAccount",	TabRow.GoodsInvoicedNotDeliveredGLAccount);
	StructureData.Insert("SupplierInvoice",						TabRow.SupplierInvoice);
	StructureData.Insert("GLAccounts",							TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",					TabRow.GLAccountsFilled);
	
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

&AtServer
Procedure ProductsSupplierInvoiceOnChangeAtServer(StructureData)
	
	StructureData.Insert("ObjectParameters", GLAccountsInDocumentsClientServer.GetObjectParameters(Object));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	GLAccountsInDocumentsServerCall.FillProductGLAccounts(StructureData, GLAccounts);
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, SupplierInvoice, GoodsReceivedNotInvoicedGLAccount,
		|GoodsInvoicedNotDeliveredGLAccount, InventoryGLAccount, InventoryTransferredGLAccount, InventoryReceivedGLAccount,
		|GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Products");
	StructureData.Insert("ProductName", ProductName);
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
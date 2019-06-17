
#Region Variables

&AtClient
Var ThisIsNewRow;

#EndRegion

#Region GeneralPurposeProceduresAndFunctions

// Procedure calls the data processor for document filling by basis.
//
&AtServer
Procedure FillByDocument(BasisDocument)
	
	Document = FormAttributeToValue("Object");
	Document.Filling(BasisDocument,);
	ValueToFormAttribute(Document, "Object");
	Modified = True;
	FillAddedColumns();
	
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
Function GetCompanyDataOnChange(Company, DocumentDate)
	
	StructureData = New Structure();
	StructureData.Insert("Counterparty", DriveServer.GetCompany(Company));
	
	ResponsiblePersons = DriveServer.OrganizationalUnitsResponsiblePersons(Company, DocumentDate);
	
	StructureData.Insert("ChiefAccountant", ResponsiblePersons.ChiefAccountant);
	StructureData.Insert("Released", ResponsiblePersons.WarehouseSupervisor);
	StructureData.Insert("ReleasedPosition", ResponsiblePersons.WarehouseSupervisorPositionRef);
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

// Receives the set of data from the server for the ProductsOnChange procedure.
//
&AtServerNoContext
Function GetDataProductsOnChange(StructureData)
	
	ProductStructure = CommonUse.ObjectAttributesValues(StructureData.Products, "MeasurementUnit, BusinessLine"); 
	StructureData.Insert("BusinessLine", ProductStructure.BusinessLine);
	StructureData.Insert("MeasurementUnit", ProductStructure.MeasurementUnit);
	
	GLAccountsInDocuments.FillProductGLAccountsInStructure(StructureData);
	
	Return StructureData;
	
EndFunction

// Shows the flag showing the activity direction visible.
//
&AtServerNoContext
Function GetLinesOfBusinessVisible(OperationKind)
	
	Return OperationKind = PredefinedValue("Enum.OperationTypesInventoryTransfer.WriteOffToExpenses")
		Or OperationKind = PredefinedValue("Enum.OperationTypesInventoryTransfer.TransferToOperation");
	
EndFunction

// It receives data set from the server for the StructuralUnitOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitOnChange(StructureData)
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
						  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
	If StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.TransferRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.TransferRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", StructureData.Source.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting);
		
		FunctionalOptionOrderTransferInHeader = Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
			
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
		EndIf;
		
		If (Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting)
			AND (Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
			Items.SalesOrder.Visible = False;
			Items.Inventory.ChildItems.InventorySalesOrder.Visible = False;
		Else
			Items.SalesOrder.Visible = FunctionalOptionOrderTransferInHeader;
			Items.Inventory.ChildItems.InventorySalesOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then	
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.WriteOffToExpensesRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.WriteOffToExpensesRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then		
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.PassToOperationRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.PassToOperationRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then	
		
		StructureData.Insert("StructuralUnitPayee", StructureData.Source.ReturnFromOperationRecipient);
		StructureData.Insert("CellPayee", StructureData.Source.ReturnFromOperationRecipientCell);
		StructureData.Insert("TypeOfStructuralUnitRetailAmmountAccounting", False);
		
	EndIf;
	
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

// Receives the data set from server for the StructuralUnitReceiverOnChange procedure.
//
&AtServer
Function GetDataStructuralUnitPayeeOnChange(StructureData)

	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
						  OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
	If StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.TransferSource);
		StructureData.Insert("Cell", StructureData.Recipient.TransferSourceCell);
				
		FunctionalOptionOrderTransferInHeader = Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 	 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
			
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
			
		EndIf;
		
		If (Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		 OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting)
		   AND (Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 	OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
		 	Items.SalesOrder.Visible = False;
			Items.Inventory.ChildItems.InventorySalesOrder.Visible = False;
		Else
			Items.SalesOrder.Visible = FunctionalOptionOrderTransferInHeader;
			Items.Inventory.ChildItems.InventorySalesOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		EndIf;
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then	
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.WriteOffToExpensesSource);
		StructureData.Insert("Cell", StructureData.Recipient.WriteOffToExpensesSourceCell);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then		
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.PassToOperationSource);
		StructureData.Insert("Cell", StructureData.Recipient.PassToOperationSourceCell);
		
	ElsIf StructureData.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then	
		
		StructureData.Insert("StructuralUnit", StructureData.Recipient.ReturnFromOperationSource);
		StructureData.Insert("Cell", StructureData.Recipient.ReturnFromOperationSourceCell);
		
	EndIf;
	
	ShippingAddress = "";
	ArrayOfOwners = New Array;
	ArrayOfOwners.Add(StructureData.Recipient);
	
	Addresses = ContactInformationManagement.ObjectsContactInformation(ArrayOfOwners, , Catalogs.ContactInformationTypes.BusinessUnitsActualAddress);
	If Addresses.Count() > 0 Then
		
		ShippingAddress = Addresses[0].Presentation;
		
	EndIf;
	StructureData.Insert("ShippingAddress", ShippingAddress);
	
	FillAddedColumns(True);
	
	Return StructureData;
	
EndFunction

&AtServer
Procedure InventoryBatchOnChangeAtServer(StructureData)
	
	StructureData.Insert("ObjectParameters", GetObjectParameters(Object));
	GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	FillProductGLAccounts(StructureData, GLAccounts);		
	
EndProcedure

// The procedure of processing the document operation kind change.
//
&AtServer
Procedure ProcessOperationKindChange()
	
	If ValueIsFilled(Object.OperationKind)
		AND Not Object.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		User = Users.CurrentUser();
		
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainWarehouse");
		MainWarehouse = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainWarehouse);
		
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "MainDepartment");
		MainDepartment = ?(ValueIsFilled(SettingValue), SettingValue, Catalogs.BusinessUnits.MainDepartment);
		
		If Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses 
			OR Object.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
			
			If Not Constants.UseSeveralWarehouses.Get() Then
				
				Object.StructuralUnit = MainWarehouse;
				
			EndIf;
			
			If Not Constants.UseSeveralDepartments.Get() Then
				
				Object.StructuralUnitPayee = MainDepartment;
				
			EndIf;
			
		ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
			
			If Not Constants.UseSeveralDepartments.Get() Then
				
				Object.StructuralUnit = MainDepartment;
				
			EndIf;
			
			If Not Constants.UseSeveralWarehouses.Get() Then
				
				Object.StructuralUnitPayee = MainWarehouse;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	FillAddedColumns(True);	
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
			TSRowsArray = Object.Inventory.FindRows(New Structure("Products,Characteristic,Batch,MeasurementUnit",BarcodeData.Products,BarcodeData.Characteristic,BarcodeData.Batch,BarcodeData.MeasurementUnit));
			If TSRowsArray.Count() = 0 Then
				NewRow = Object.Inventory.Add();
				NewRow.Products = BarcodeData.Products;
				NewRow.Characteristic = BarcodeData.Characteristic;
				NewRow.Batch = BarcodeData.Batch;
				NewRow.Quantity = CurBarcode.Quantity;
				NewRow.MeasurementUnit = ?(ValueIsFilled(BarcodeData.MeasurementUnit), BarcodeData.MeasurementUnit, BarcodeData.StructureProductsData.MeasurementUnit);
				NewRow.Amount = NewRow.Quantity * NewRow.Cost;
				Items.Inventory.CurrentRow = NewRow.GetID();
			Else
				NewRow = TSRowsArray[0];
				NewRow.Quantity = NewRow.Quantity + CurBarcode.Quantity;
				NewRow.Amount = NewRow.Quantity * NewRow.Cost;
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
Procedure FillInventoryByWarehouseBalancesAtServer()
	
	Document = FormAttributeToValue("Object");
	Document.FillInventoryByInventoryBalances();
	ValueToFormAttribute(Document, "Object");
	FillAddedColumns(True);
	
EndProcedure

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
&AtServer
Procedure SetVisibleAndEnabled()
	
	FunctionalOptionOrderTransferInHeader = Object.SalesOrderPosition = Enums.AttributeStationing.InHeader;
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	NewArray.Add(Enums.BusinessUnitsTypes.Retail);
	NewArray.Add(Enums.BusinessUnitsTypes.RetailEarningAccounting);
	If Constants.UseProductionSubsystem.Get() Then
		NewArray.Add(Enums.BusinessUnitsTypes.Department);
	EndIf;
	ArrayWarehouseSubdepartmentRetail = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Department);
	ArrayUnit = New FixedArray(NewArray);
	
	NewArray = New Array();
	NewArray.Add(Enums.BusinessUnitsTypes.Warehouse);
	ArrayWarehouse = New FixedArray(NewArray);
	
	If Object.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		
		Items.InventoryBusinessLine.Visible = False;
		Items.SalesOrder.Visible = FunctionalOptionOrderTransferInHeader;
		Items.Inventory.ChildItems.InventorySalesOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		Items.InventoryPick.Visible = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdepartmentRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouseSubdepartmentRetail);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
			Items.Inventory.ChildItems.InventoryReserve.Visible = False;
			Items.InventoryChangeReserve.Visible = False;
			ReservationUsed = False;
		Else
			Items.Inventory.ChildItems.InventoryReserve.Visible = True;
			Items.InventoryChangeReserve.Visible = True;
			ReservationUsed = True;
		EndIf;
		
		If (Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
			OR Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting)
			AND (Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
	 	OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting) Then
			Items.SalesOrder.Visible = False;
			Items.Inventory.ChildItems.InventorySalesOrder.Visible = False;
		Else
			Items.SalesOrder.Visible = FunctionalOptionOrderTransferInHeader;
			Items.Inventory.ChildItems.InventorySalesOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		EndIf;
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		
		Items.InventoryBusinessLine.Visible = GetLinesOfBusinessVisible(Object.OperationKind);
		Items.SalesOrder.Visible = FunctionalOptionOrderTransferInHeader;
		Items.Inventory.ChildItems.InventorySalesOrder.Visible = Not FunctionalOptionOrderTransferInHeader;
		Items.Inventory.ChildItems.InventoryReserve.Visible = True;
		Items.InventoryChangeReserve.Visible = True;
		Items.InventoryPick.Visible = True;
		ReservationUsed = True;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else	
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.TransferToOperation Then
		
		Items.InventoryBusinessLine.Visible = GetLinesOfBusinessVisible(Object.OperationKind);
		Items.SalesOrder.Visible = False;
		Items.Inventory.ChildItems.InventorySalesOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.InventoryPick.Visible = True;
		ReservationUsed = False;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	ElsIf Object.OperationKind = Enums.OperationTypesInventoryTransfer.ReturnFromExploitation Then
		
		Items.InventoryBusinessLine.Visible = False;
		Items.SalesOrder.Visible = False;
		Items.Inventory.ChildItems.InventorySalesOrder.Visible = False;
		Items.Inventory.ChildItems.InventoryReserve.Visible = False;
		Items.InventoryChangeReserve.Visible = False;
		Items.InventoryPick.Visible = False;
		ReservationUsed = False;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayUnit);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnit.ChoiceParameters = NewParameters;
		
		NewParameter = New ChoiceParameter("Filter.StructuralUnitType", ArrayWarehouse);
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.StructuralUnitPayee.ChoiceParameters = NewParameters;
		
		For Each StringInventory In Object.Inventory Do
			StringInventory.Reserve = 0;
		EndDo;
		
		If Not Constants.UseSeveralDepartments.Get() Then
			
			Items.StructuralUnit.Visible = False;
			
		Else
			
			Items.StructuralUnit.Visible = True;
			
		EndIf;
		
		If Not Constants.UseSeveralWarehouses.Get() Then
			
			Items.StructuralUnitPayee.Visible = False;
			
		Else
			
			Items.StructuralUnitPayee.Visible = True;
			
		EndIf;
		
	Else
		
		Items.StructuralUnit.Visible = True;
		Items.StructuralUnitPayee.Visible = True;
		
	EndIf;
	
	Items.Inventory.ChildItems.InventoryCostPrice.Visible = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	Items.Inventory.ChildItems.InventoryAmount.Visible = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
	
	Items.InventoryBusinessLine.Visible = GetLinesOfBusinessVisible(Object.OperationKind);
	
	SetCellVisible("Cell", Object.StructuralUnit);
	SetCellVisible("CellPayee", Object.StructuralUnitPayee);
	
EndProcedure

&AtServer
Procedure SetCellVisible(CellName, Warehouse)
	
	If Not ValueIsFilled(Warehouse)
		OR Warehouse.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
		OR Warehouse.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting Then
		Items[CellName].Visible = False;
	Else
		Items[CellName].Visible = True;
	EndIf;
	
EndProcedure

&AtServer
// The procedure sets the form attributes
// visible on the option Use subsystem Production.
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
			
			Items.StructuralUnitPayee.ListChoiceMode = True;
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
			Items.StructuralUnitPayee.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
			
		EndIf;
		
	EndIf;
	
	If Constants.UseProductionSubsystem.Get()
		OR Constants.UseSeveralWarehouses.Get() Then
		
		Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.Transfer);
		
	ElsIf Not ValueIsFilled(Object.Ref) Then
		
		Object.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses;
		
	EndIf;
	
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.WriteOffToExpenses);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.TransferToOperation);
	Items.OperationKind.ChoiceList.Add(Enums.OperationTypesInventoryTransfer.ReturnFromExploitation);
	
EndProcedure

#Region WorkWithSelection

// Procedure - event handler Action of the Pick command
//
&AtClient
Procedure Pick(Command)
	
	TabularSectionName	= "Inventory";
	DocumentPresentaion	= NStr("en = 'inventory transfer'");
	SelectionParameters	= DriveClient.GetSelectionParameters(ThisObject, TabularSectionName, DocumentPresentaion, True, False, True);
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

// Function gets a product list from the temporary storage
//
&AtServer
Procedure GetInventoryFromStorage(InventoryAddressInStorage, TabularSectionName, AreCharacteristics, AreBatches)
	
	TableForImport = GetFromTempStorage(InventoryAddressInStorage);
	
	ObjectParameters = GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters);
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
			TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;
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
	
	// Filling in responsible persons for new documents
	If Not ValueIsFilled(Object.Ref) Then
		
		ResponsiblePersons		= DriveServer.OrganizationalUnitsResponsiblePersons(Object.Company, Object.Date);
		
		Object.ChiefAccountant = ResponsiblePersons.ChiefAccountant;
		Object.Released			= ResponsiblePersons.WarehouseSupervisor;
		Object.ReleasedPosition= ResponsiblePersons.WarehouseSupervisorPositionRef;
		
	EndIf;
	
	IsRetail = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.Retail
				OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.Retail;
	IsRetailEarningAccounting = Object.StructuralUnit.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting
				OR Object.StructuralUnitPayee.StructuralUnitType = Enums.BusinessUnitsTypes.RetailEarningAccounting;
				
	FillAddedColumns();
	
	// FO Use Production subsystem.
	SetVisibleByFOUseProductionSubsystem();
	
	SetVisibleAndEnabled();
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	// StandardSubsystems.DataImportFromExternalSources
	DataImportFromExternalSources.OnCreateAtServer(Metadata.Documents.InventoryTransfer.TabularSections.Inventory, DataLoadSettings, ThisObject);
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
	
	ClosingDates.ObjectOnReadAtServer(ThisForm, CurrentObject);
	FillAddedColumns();
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	SetChoiceParameters();
	
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

// Procedure - command handler DocumentSetup.
//
&AtClient
Procedure DocumentSetup(Command)
	
	// 1. Form parameter structure to fill "Document setting" form.
	ParametersStructure = New Structure;
	ParametersStructure.Insert("SalesOrderPositionInInventoryTransfer", 	Object.SalesOrderPosition);
	ParametersStructure.Insert("WereMadeChanges", 							False);
	
	StructureDocumentSetting = Undefined;

	
	OpenForm("CommonForm.DocumentSetup", ParametersStructure,,,,, New NotifyDescription("DocumentSettingEnd", ThisObject));
	
EndProcedure

&AtClient
Procedure DocumentSettingEnd(Result, AdditionalParameters) Export
	
	StructureDocumentSetting = Result;
	
	
	If TypeOf(StructureDocumentSetting) = Type("Structure") AND StructureDocumentSetting.WereMadeChanges Then
		
		Object.SalesOrderPosition = StructureDocumentSetting.SalesOrderPositionInInventoryTransfer;
		SetVisibleAndEnabled();
		
	EndIf;

EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// You can call the procedure by clicking
// the button "FillByBasis" of the tabular field command panel.
//
&AtClient
Procedure FillByBasis(Command)
	
	Response = Undefined;

	
	ShowQueryBox(New NotifyDescription("FillByBasisEnd", ThisObject), NStr("en = 'Do you want to refill the inventory transfer?'"), QuestionDialogMode.YesNo, 0);
	
EndProcedure

&AtClient
Procedure FillByBasisEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response = DialogReturnCode.Yes Then
        FillByDocument(Object.BasisDocument);
    EndIf;

EndProcedure

// FillInByBalance command event handler procedure
//
&AtClient
Procedure FillByBalanceAtWarehouse(Command)
	
	If Object.Inventory.Count() > 0 Then
		Response = Undefined;

		ShowQueryBox(New NotifyDescription("FillByBalanceOnWarehouseEnd", ThisObject), NStr("en = 'Tabular section will be cleared. Continue?'"), QuestionDialogMode.YesNo, 0);
        Return; 
	EndIf;
	
	FillByBalanceOnWarehouseEndFragment();
EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEnd(Result, AdditionalParameters) Export
    
    Response = Result;
    If Response <> DialogReturnCode.Yes Then
        Return;
    EndIf; 
    
    FillByBalanceOnWarehouseEndFragment();

EndProcedure

&AtClient
Procedure FillByBalanceOnWarehouseEndFragment()
    
    FillInventoryByWarehouseBalancesAtServer();

EndProcedure

// Procedure - command handler FillByReserve of the ChangeReserve submenu.
//
&AtClient
Procedure ChangeReserveFillByReserves(Command)
	
	If Object.Inventory.Count() = 0 Then
		Message = New UserMessage;
		Message.Text = NStr("en = 'The ""Inventory"" tabular section is not filled in.'");
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
		Message.Text = NStr("en = 'The ""Inventory"" tabular section is not filled in.'");
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
	StructureData = GetCompanyDataOnChange(Object.Company, Object.Date);
	Counterparty = StructureData.Counterparty;
	
	Object.ChiefAccountant = StructureData.ChiefAccountant;
	Object.Released			= StructureData.Released;
	Object.ReleasedPosition= StructureData.ReleasedPosition;
	
EndProcedure

// Procedure - event handler OnChange of the OperationKind input field.
//
&AtClient
Procedure OperationKindOnChange(Item)
	
	ProcessOperationKindChange();
	
EndProcedure

// Procedure - event handler OnChange of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Source", Object.StructuralUnit);
	
	StructureData = GetDataStructuralUnitOnChange(StructureData);
	
	If Not ValueIsFilled(Object.StructuralUnitPayee) Then
		Object.StructuralUnitPayee = StructureData.StructuralUnitPayee;
		Object.CellPayee = StructureData.CellPayee;
	EndIf;
	
	If StructureData.TypeOfStructuralUnitRetailAmmountAccounting Then
		Items.Inventory.ChildItems.InventoryCostPrice.Visible = True;
		Items.Inventory.ChildItems.InventoryAmount.Visible = True;
	ElsIf Not StructureData.TypeOfStructuralUnitRetailAmmountAccounting Then
		For Each StringInventory In Object.Inventory Do
			StringInventory.Cost = 0;
			StringInventory.Amount = 0;
		EndDo;
		Items.Inventory.ChildItems.InventoryCostPrice.Visible = False;
		Items.Inventory.ChildItems.InventoryAmount.Visible = False;
	EndIf;
	
	SetCellVisible("Cell", Object.StructuralUnit);

	SetChoiceParameters();
	
EndProcedure

// Procedure - OnChange event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOnChange(Item)
	
	StructureData = New Structure();
	StructureData.Insert("OperationKind", Object.OperationKind);
	StructureData.Insert("Recipient", Object.StructuralUnitPayee);
	
	StructureData = GetDataStructuralUnitPayeeOnChange(StructureData);
	
	If Not ValueIsFilled(Object.StructuralUnit) Then
		Object.StructuralUnit = StructureData.StructuralUnit;
		Object.Cell = StructureData.Cell;
	EndIf;
	
	StructureData.Property("ShippingAddress", Object.ShippingAddress);
	
	SetCellVisible("CellPayee", Object.StructuralUnitPayee);
	
	SetChoiceParameters();
	
EndProcedure

// Procedure - Opening event handler of the StructuralUnit input field.
//
&AtClient
Procedure StructuralUnitOpening(Item, StandardProcessing)
	
	If Items.StructuralUnit.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnit) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure - Opening event handler of the StructuralUnitRecipient input field.
//
&AtClient
Procedure StructuralUnitPayeeOpening(Item, StandardProcessing)
	
	If Items.StructuralUnitPayee.ListChoiceMode
		AND Not ValueIsFilled(Object.StructuralUnitPayee) Then
		
		StandardProcessing = False;
		
	EndIf;
	
EndProcedure

// Procedure sets choice parameter links.
//
&AtClient
Procedure SetChoiceParameters()
	
	If IsRetailEarningAccounting Then
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewParameter = New ChoiceParameter("Filter.Status", New FixedArray(NewArray));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	Else
		NewArray = New Array();
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.OwnInventory"));
		NewArray.Add(PredefinedValue("Enum.BatchStatuses.CounterpartysInventory"));
		NewParameter = New ChoiceParameter("Filter.Status", New FixedArray(NewArray));
		NewParameter2 = New ChoiceParameter("Additionally.StatusRestriction", New FixedArray(NewArray));
		NewArray = New Array();
		NewArray.Add(NewParameter);
		NewArray.Add(NewParameter2);
		NewParameters = New FixedArray(NewArray);
		Items.Inventory.ChildItems.InventoryBatch.ChoiceParameters = NewParameters;
	EndIf;
	
EndProcedure

&AtClient
Procedure CommentStartChoice(Item, ChoiceData, StandardProcessing)
	
	CommonUseClient.ShowCommentEditingForm(Item.EditText, ThisObject, "Object.Comment");
		
EndProcedure

#Region TabularSectionAttributeEventHandlers

// Procedure - event handler OnChange of the Products input field.
//
&AtClient
Procedure InventoryProductsOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	StructureData.Insert("Products", TabularSectionRow.Products);
	
	AddGLAccountsToStructure(StructureData, TabularSectionRow);	
	StructureData.Insert("ObjectParameters", GetObjectParameters(Object));
	StructureData = GetDataProductsOnChange(StructureData);
	
	FillPropertyValues(TabularSectionRow, StructureData); 
	TabularSectionRow.MeasurementUnit = StructureData.MeasurementUnit;
	TabularSectionRow.Quantity = 1;
	
	// Serial numbers
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, TabularSectionRow, , UseSerialNumbersBalance);
	
EndProcedure

&AtClient
Procedure InventoryBatchOnChange(Item)
	
	TabRow = Items.Inventory.CurrentData;
	
	StructureData = New Structure();
	AddGLAccountsToStructure(StructureData, TabRow);
	StructureData.Insert("Products",	TabRow.Products);
	StructureData.Insert("Batch",	TabRow.Batch);
	
	InventoryBatchOnChangeAtServer(StructureData);
	FillPropertyValues(TabRow, StructureData);
	
EndProcedure

&AtClient
Procedure InventoryOnStartEdit(Item, NewRow, Copy)
	
	If NewRow AND Copy Then
		Item.CurrentData.ConnectionKey = 0;
		Item.CurrentData.SerialNumbers = "";
	EndIf;	
	
	If Item.CurrentItem.Name = "InventorySerialNumbers" Then
		OpenSerialNumbersSelection();
	EndIf;
	
	If Not NewRow Or Copy Then
		Return;	
	EndIf;
	
	Item.CurrentData.GLAccounts = GLAccountsInDocumentsClientServer.GetEmptyGLAccountPresentation();
	
EndProcedure

&AtClient
Procedure InventoryBeforeDeleteRow(Item, Cancel)
	
	// Serial numbers
	CurrentData = Items.Inventory.CurrentData;
	WorkWithSerialNumbersClientServer.DeleteSerialNumbersByConnectionKey(Object.SerialNumbers, CurrentData, , UseSerialNumbersBalance);
	
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

&AtClient
Procedure InventorySerialNumbersStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	OpenSerialNumbersSelection();
	
EndProcedure

// Procedure - event handler OnChange of the Count input field.
//
&AtClient
Procedure InventoryQuantityOnChange(Item)
	
	CalculateAmountInTabularSectionLine();
	
EndProcedure

// Procedure - OnChange event handler of the Primecost input field.
//
&AtClient
Procedure InventoryCostPriceOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;

EndProcedure

// Procedure - event handler OnChange of the Amount input field.
//
&AtClient
Procedure InventoryAmountOnChange(Item)
	
	TabularSectionRow = Items.Inventory.CurrentData;
	
	// Price.
	If TabularSectionRow.Quantity <> 0 Then
		TabularSectionRow.Cost = TabularSectionRow.Amount / TabularSectionRow.Quantity;
	EndIf;
	
EndProcedure

#EndRegion

#Region DataImportFromExternalSources

&AtClient
Procedure LoadFromFileInventory(Command)
	
	NotifyDescription = New NotifyDescription("ImportDataFromExternalSourceResultDataProcessor", ThisObject, DataLoadSettings);
	
	DataLoadSettings.Insert("TabularSectionFullName",	"InventoryTransfer.Inventory");
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

#Region CopyPasteRows

&AtClient
Procedure InventoryCopyRows(Command)
	CopyRowsTabularPart("Inventory"); 
EndProcedure

&AtClient
Procedure InventoryPasteRows(Command)
	PasteRowsTabularPart("Inventory"); 
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

#Region ServiceProceduresAndFunctions

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
	
	TabularSectionRow.Amount = TabularSectionRow.Quantity * TabularSectionRow.Cost;
	
	// Serial numbers
	If UseSerialNumbersBalance<>Undefined Then
		WorkWithSerialNumbersClientServer.UpdateSerialNumbersQuantity(Object, TabularSectionRow);
	EndIf;
	
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
	
	ObjectParameters = GetObjectParameters(Object);
	StructureData = GetStructureData(ObjectParameters, RowData);
	
	RowParameters = GetGLAccountsStructure(StructureData);
	RowParameters.Insert("TableName",	"Inventory");
	RowParameters.Insert("Products",	RowData.Products);

	OpenForm("CommonForm.ProductGLAccounts", RowParameters, ThisForm);
	
EndProcedure

&AtClient
Procedure AddGLAccountsToStructure(StructureData, TabRow)
	
	StructureData.Insert("GLAccounts",			TabRow.GLAccounts);
	StructureData.Insert("GLAccountsFilled",	TabRow.GLAccountsFilled);
	StructureData.Insert("Batch",				TabRow.Batch);
	StructureData.Insert("InventoryGLAccount",		TabRow.InventoryGLAccount);
	StructureData.Insert("InventoryToGLAccount",		TabRow.InventoryToGLAccount);
	StructureData.Insert("InventoryReceivedGLAccount",	TabRow.InventoryReceivedGLAccount);
	StructureData.Insert("ConsumptionGLAccount",		TabRow.ConsumptionGLAccount);
	StructureData.Insert("SignedOutEquipmentGLAccount",	TabRow.SignedOutEquipmentGLAccount);
	
EndProcedure

&AtServer
Procedure FillAddedColumns(GetGLAccounts = False)
	
	StructureData = New Structure();
	ObjectParameters = GetObjectParameters(Object);
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("Products", Object.Inventory.Unload(, "Products").UnloadColumn(("Products")));
	
	Inventory = Object.Inventory;
	
	If GetGLAccounts Then
		GLAccounts = GLAccountsInDocuments.GetProductListGLAccounts(StructureData);
	EndIf;
	
	StructureData = GetStructureData(ObjectParameters);
	
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

&AtServer
Function GetObjectParameters(Val FormObject) Export

	ObjectParameters = New Structure;
	ObjectParameters.Insert("Ref", FormObject.Ref);
	ObjectParameters.Insert("Company", FormObject.Company);
	ObjectParameters.Insert("Date", FormObject.Date);
	ObjectParameters.Insert("StructuralUnit", FormObject.StructuralUnit);
	ObjectParameters.Insert("StructuralUnitPayee", FormObject.StructuralUnitPayee);
	ObjectParameters.Insert("StructuralUnitPayeeType", CommonUse.ObjectAttributeValue(FormObject.StructuralUnitPayee, "StructuralUnitType"));
	ObjectParameters.Insert("OperationKind", FormObject.OperationKind);
	
	Return ObjectParameters;
	
EndFunction

&AtServerNoContext
Procedure FillProductGLAccounts(StructureData, GLAccounts)

	GLAccountsForFilling = GetGLAccountsStructure(StructureData);
	FillPropertyValues(GLAccountsForFilling, GLAccounts[StructureData.Products]);
	GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
	
EndProcedure

&AtServerNoContext
Function GetGLAccountsStructure(StructureData)

	ObjectParameters = StructureData.ObjectParameters;
	GLAccountsForFilling = New Structure;

	If CommonUse.ObjectAttributeValue(StructureData.Batch, "Status") = Enums.BatchStatuses.CounterpartysInventory Then
		GLAccountsForFilling.Insert("InventoryReceivedGLAccount", StructureData.InventoryReceivedGLAccount);
	Else
		GLAccountsForFilling.Insert("InventoryGLAccount", StructureData.InventoryGLAccount);
	EndIf;
	
	If ObjectParameters.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer
		And ObjectParameters.StructuralUnitPayeeType = Enums.BusinessUnitsTypes.Department
		Or ObjectParameters.OperationKind = Enums.OperationTypesInventoryTransfer.WriteOffToExpenses Then
		GLAccountsForFilling.Insert("ConsumptionGLAccount", StructureData.ConsumptionGLAccount);
	ElsIf ObjectParameters.OperationKind = Enums.OperationTypesInventoryTransfer.Transfer Then
		GLAccountsForFilling.Insert("InventoryToGLAccount", StructureData.InventoryToGLAccount);
	Else	
		GLAccountsForFilling.Insert("SignedOutEquipmentGLAccount", StructureData.SignedOutEquipmentGLAccount);
	EndIf;
	
	Return GLAccountsForFilling;

EndFunction

&AtClient
Procedure GLAccountsChoiceProcessingAtClient(GLAccounts)

	TabRow = Items[GLAccounts.TableName].CurrentData;
	FillPropertyValues(TabRow, GLAccounts);
	Modified = True;
	
	If TabRow.Property("GLAccounts") Then
		ObjectParameters = GetObjectParameters(Object);
		StructureData = GetStructureData(ObjectParameters, TabRow);
		
		GLAccountsForFilling = GetGLAccountsStructure(StructureData);
		GLAccountsInDocumentsClientServer.FillProductGLAccountsDescription(StructureData, GLAccountsForFilling);
		FillPropertyValues(TabRow, StructureData);
	EndIf;
	
EndProcedure

&AtClientAtServerNoContext
Function GetStructureData(ObjectParameters, RowData = Undefined, ProductName = "Products") Export
	
	StructureData = New Structure("Products, Batch, InventoryGLAccount, InventoryToGLAccount, ConsumptionGLAccount,
		|SignedOutEquipmentGLAccount, InventoryReceivedGLAccount, GLAccounts, GLAccountsFilled");
	StructureData.Insert("ObjectParameters", ObjectParameters);
	StructureData.Insert("TabName", "Inventory");
	StructureData.Insert("ProductName", ProductName);
	StructureData.Insert("Batch", PredefinedValue("Catalog.ProductsBatches.EmptyRef"));
	
	If RowData <> Undefined Then 
		FillPropertyValues(StructureData, RowData);
	EndIf;
	
	Return StructureData;

EndFunction

#EndRegion

#Region Initialize

ThisIsNewRow = False;

#EndRegion
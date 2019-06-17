
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("ErrorText") Then
		
		// There is no option to use CommonUseClientServer.ReportToUser as it is required to pass the UID forms
		CustomMessage = New UserMessage;
		Result.Property("Field", CustomMessage.Field);
		Result.Property("ErrorText", CustomMessage.Text);
		CustomMessage.TargetID = UUID;
		CustomMessage.Message();
		
		RefreshingInterface = False;
		
	EndIf;
	
	If RefreshingInterface Then
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
		RefreshInterface = True;
	EndIf;
	
	If Result.Property("NotificationForms") Then
		Notify(Result.NotificationForms.EventName, Result.NotificationForms.Parameter, Result.NotificationForms.Source);
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshInterface();
	EndIf;
	
EndProcedure

// Procedure manages visible of the WEB Application group
//
&AtClient
Procedure VisibleManagement()
	
	#If Not WebClient Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", False);
		
	#Else
		
		CommonUseClientServer.SetFormItemProperty(Items, "WEBApplication", "Visible", True);
		
	#EndIf
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If RunMode.ThisIsSystemAdministrator 
		OR CommonUseReUse.CanUseSeparatedData() Then
		
		If AttributePathToData = "ConstantsSet.UseSeveralWarehouses" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogBusinessUnitsWarehouses", "Enabled", ConstantsSet.UseSeveralWarehouses);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UsePurchaseOrderStatuses" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "SettingPurchaseOrderStatesDefault","Enabled", Not ConstantsSet.UsePurchaseOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogSalesOrderStates",	"Enabled", ConstantsSet.UsePurchaseOrderStatuses);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseBatches" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "SettingsReceptionProductsForSafeCustody", "Enabled", ConstantsSet.UseBatches);
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSerialNumbers" OR AttributePathToData = "" Then
			CommonUseClientServer.SetFormItemProperty(Items, "UseSerialNumbersAsInventoryRecordDetails", "Enabled", ConstantsSet.UseSerialNumbers);
		EndIf;
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	ValidateAbilityToChangeAttributeValue(AttributePathToData, Result);
	
	If Result.Property("CurrentValue") Then
		
		// Rollback to previous value
		ReturnFormAttributeValue(AttributePathToData, Result.CurrentValue);
		
	Else
		
		SaveAttributeValue(AttributePathToData, Result);
		
		SetEnabled(AttributePathToData);
		
		RefreshReusableValues();
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure("Value", ConstantValue), ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderStatuses" Then
		
		ConstantsSet.UsePurchaseOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PurchaseOrdersInProgressStatus" Then
		
		ConstantsSet.PurchaseOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.PurchaseOrdersCompletionStatus" Then
		
		ConstantsSet.PurchaseOrdersCompletionStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralWarehouses" Then
		
		ConstantsSet.UseSeveralWarehouses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSeveralUnitsForProduct" Then
		
		ConstantsSet.UseSeveralUnitsForProduct = CurrentValue;
		
	ElsIf  AttributePathToData = "ConstantsSet.AcceptInventoryInTheCustody" Then
		
		ConstantsSet.AcceptInventoryInTheCustody = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseInventoryReservation" Then
		
		ConstantsSet.UseInventoryReservation = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseStorageBins" Then
		
		ConstantsSet.UseStorageBins = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseCharacteristics" Then
		
		ConstantsSet.UseCharacteristics = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseBatches" Then
		
		ConstantsSet.UseBatches = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSubcontractorManufacturers" Then
		
		ConstantsSet.UseSubcontractorManufacturers = CurrentValue;
		
	EndIf;
	
EndProcedure

// Checks whether it is possible to clear the UsePurchaseOrderStatuses option.
//
&AtServer
Function CancellationUncheckUsePurchaseOrderStates()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	PurchaseOrder.Ref
	|FROM
	|	Document.PurchaseOrder AS PurchaseOrder
	|WHERE
	|	(PurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR PurchaseOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND (NOT PurchaseOrder.Closed))";
	
	Result = Query.Execute();
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are Purchase order documents with the Open and/or Executed (not closed) status in the base.
		                 |Disabling the option is prohibited.
		                 |Note:
		                 |If there are documents in the state with
		                 |the status ""Open"", set them to state with the status ""In progress""
		                 |or ""Executed (closed)"" If there are documents in the state
		                 |with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'"
		);
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseSeveralWarehouses option.
//
&AtServer
Function CancellationUncheckAccountingBySeveralWarehouses()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	BusinessUnits.Ref
		|FROM
		|	Catalog.BusinessUnits AS BusinessUnits
		|WHERE
		|	BusinessUnits.StructuralUnitType = &StructuralUnitType
		|	AND BusinessUnits.Ref <> &MainWarehouse"
	);
	
	Query.SetParameter("StructuralUnitType", Enums.BusinessUnitsTypes.Warehouse);
	Query.SetParameter("MainWarehouse", Catalogs.BusinessUnits.MainWarehouse);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Warehouses different from the main warehouse are used in the infobase. Cannot disable the option.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear AccountingInVariousUOMs option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingInVariousUOM()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	Cancel = False;
	
	SelectionOfUOM = Catalogs.UOM.Select();
	While SelectionOfUOM.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionOfUOM.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'Documents with user unit of measure are entered in the application. Cannot disable the option.'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction

// Check for the option to uncheck UseSerialNumbers.
//
Function CancelRemoveFunctionalOptionUseSerialNumbers() Export
	
	ErrorText = "";
	AreRecords = False;
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SerialNumbers.SerialNumber
	|FROM
	|	AccumulationRegister.SerialNumbers AS SerialNumbers
	|WHERE
	|	SerialNumbers.SerialNumber <> VALUE(Catalog.SerialNumbers.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.Пустой() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'There are balances by serial numbers in the database. The removal of the flag is prohibited.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the InventoryReservation option.
//
&AtServer
Function CancellationUncheckFunctionalOptionInventoryReservation()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	Inventory.SalesOrder
		|FROM
		|	AccumulationRegister.Inventory AS Inventory
		|WHERE
		|	Inventory.SalesOrder <> UNDEFINED"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'There is information about reserves in the infobase. Cannot clear the check box.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseStorageBins option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingByCells()
	
	ErrorText = "";
	
	Query = New Query(
		"SELECT TOP 1
		|	InventoryInWarehouses.Company
		|FROM
		|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
		|WHERE
		|	InventoryInWarehouses.Cell <> VALUE(Catalog.Cells.EmptyRef)"
	);
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		
		ErrorText = NStr("en = 'Records are registered for the cells in the infobase. Cannot clear the flag.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseCharachteristics option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseCharacteristics()
	
	ErrorText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("ProductRelease");
	ListOfRegisters.Add("InventoryFlowCalendar");
	ListOfRegisters.Add("ObsoleteWorkOrders");
	ListOfRegisters.Add("ProductionOrders");
	ListOfRegisters.Add("SalesOrders");
	ListOfRegisters.Add("PurchaseOrders");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryInWarehouses");
	ListOfRegisters.Add("StockTransferredToThirdParties");
	ListOfRegisters.Add("StockReceivedFromThirdParties");
	ListOfRegisters.Add("SalesTarget");
	ListOfRegisters.Add("InventoryDemand");
	ListOfRegisters.Add("Sales");
	ListOfRegisters.Add("Backorders");
	ListOfRegisters.Add("Workload");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister In ListOfRegisters Do
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				" 
				|
				|UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Value + ".Characteristic
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Value + ".Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Inventory.Characteristic
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Characteristic <> VALUE(Catalog.ProductsCharacteristics.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'Records are registered for the characteristics in the infobase. Cannot clear the flag.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Checks whether it is possible to clear the UseBatches option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseBatches()
	
	ErrorText = "";
	
	ListOfRegisters = New ValueList;
	ListOfRegisters.Add("ProductRelease");
	ListOfRegisters.Add("Purchases");
	ListOfRegisters.Add("InventoryInWarehouses");
	ListOfRegisters.Add("StockTransferredToThirdParties");
	ListOfRegisters.Add("StockReceivedFromThirdParties");
	ListOfRegisters.Add("Sales");
	
	AccumulationRegistersCounter = 0;
	Query = New Query;
	For Each AccumulationRegister In ListOfRegisters Do
		Query.Text = Query.Text + 
			?(Query.Text = "",
				"SELECT ALLOWED TOP 1", 
				" 
				|
				|UNION ALL 
				|
				|SELECT TOP 1 ") + "
				|
				|	AccumulationRegister" + AccumulationRegister.Value + ".Batch
				|FROM
				|	AccumulationRegister." + AccumulationRegister.Value + " AS AccumulationRegister" + AccumulationRegister.Value + "
				|WHERE
				|	AccumulationRegister" + AccumulationRegister.Value + ".Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)";
		
		AccumulationRegistersCounter = AccumulationRegistersCounter + 1;
		
		If AccumulationRegistersCounter > 3 Then
			AccumulationRegistersCounter = 0;
			Try
				QueryResult = Query.Execute();
				AreRecords = Not QueryResult.IsEmpty();
			Except
				
			EndTry;
			
			If AreRecords Then
				Break;
			EndIf; 
			Query.Text = "";
		EndIf;
	EndDo;
	
	If AccumulationRegistersCounter > 0 Then
		Try
			QueryResult = Query.Execute();
			If Not QueryResult.IsEmpty() Then
				AreRecords = True;
			EndIf;
		Except
			
		EndTry;
	EndIf;
	
	Query.Text =
	"SELECT
	|	Inventory.Batch
	|FROM
	|	AccumulationRegister.Inventory AS Inventory
	|WHERE
	|	Inventory.Batch <> VALUE(Catalog.ProductsBatches.EmptyRef)";
	
	QueryResult = Query.Execute();
	If Not QueryResult.IsEmpty() Then
		AreRecords = True;
	EndIf;
	
	If AreRecords Then
		
		ErrorText = NStr("en = 'Records are registered for the batches in the infobase. Cannot clear the flag.'");
		
	EndIf;
	
	If GetFunctionalOption("AcceptConsignedGoods") Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'The ""Goods receipt for commission"" option is enabled (the Sales section). Clearing the check box is prohibited.'");
		
	EndIf;
	
	If GetFunctionalOption("UseSubcontractingManufacturing") Then
		
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'The ""Processing of supplier''s raw materials"" option is enabled (the Production section). Clearing the check box is prohibited.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are the Purchase order documents with the status other than Executed,then it is not allowed to remove the flag.
	If AttributePathToData = "ConstantsSet.UsePurchaseOrderStatuses" Then
		
		If Constants.UsePurchaseOrderStatuses.Get() <> ConstantsSet.UsePurchaseOrderStatuses
			AND (NOT ConstantsSet.UsePurchaseOrderStatuses) Then
			
			ErrorText = CancellationUncheckUsePurchaseOrderStates();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the PurchaseOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.PurchaseOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UsePurchaseOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.PurchaseOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several purchase order states"" check box is cleared, but the ""In progress"" purchase order state parameter is not filled in.'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.PurchaseOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the PurchaseOrdersCompletionStatus constant
	If AttributePathToData = "ConstantsSet.PurchaseOrdersCompletionStatus" Then
		
		If Not ConstantsSet.UsePurchaseOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.PurchaseOrdersCompletionStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several purchase order states"" check box is cleared, but the ""Completed"" purchase order state parameter is not filled in.'");
			
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.PurchaseOrdersCompletionStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are references to the warehouses not equal to the main warehouse, the removal of the UseSeveralWarehouses
	// flag is prohibited
	If AttributePathToData = "ConstantsSet.UseSeveralWarehouses" Then
		
		If Constants.UseSeveralWarehouses.Get() <> ConstantsSet.UseSeveralWarehouses
			AND (NOT ConstantsSet.UseSeveralWarehouses) Then
			
			ErrorText = CancellationUncheckAccountingBySeveralWarehouses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If the documents contain any references to UOM, it is not allowed to remove the UseSeveralUnitsForProduct flag	
	If AttributePathToData = "ConstantsSet.UseSeveralUnitsForProduct" Then
			
		If Constants.UseSeveralUnitsForProduct.Get() <> ConstantsSet.UseSeveralUnitsForProduct 
			AND (NOT ConstantsSet.UseSeveralUnitsForProduct) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingInVariousUOM();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Inventory" for the non-empty sales order, the clearing of  the
	// UseInventoryReservation check box is prohibited
	If AttributePathToData = "ConstantsSet.UseInventoryReservation" Then
		
		If Constants.UseInventoryReservation.Get() <> ConstantsSet.UseInventoryReservation 
			AND (NOT ConstantsSet.UseInventoryReservation) Then
			
			ErrorText = CancellationUncheckFunctionalOptionInventoryReservation();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in register "Warehouse inventory" for a non-empty cell, the clearing of the
	// UseStorageBins check box is prohibited
	If AttributePathToData = "ConstantsSet.UseStorageBins" Then
		
		If Constants.UseStorageBins.Get() <> ConstantsSet.UseStorageBins 
			AND (NOT ConstantsSet.UseStorageBins) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingByCells();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in the characteristic registers, the clearing of the UseCharacteristics check box is prohibited
	If AttributePathToData = "ConstantsSet.UseCharacteristics" Then
		
		If Constants.UseCharacteristics.Get() <> ConstantsSet.UseCharacteristics
			AND (NOT ConstantsSet.UseCharacteristics) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseCharacteristics();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any movements in registers containing batches, it is not allowed to clear the UseBatches check box
	If AttributePathToData = "ConstantsSet.UseBatches" Then
		
		If Constants.UseBatches.Get() <> ConstantsSet.UseBatches
			AND (NOT ConstantsSet.UseBatches) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseBatches();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check for the option to uncheck UseSerialNumbers.
	If AttributePathToData = "ConstantsSet.UseSerialNumbers" Then
		
		If Constants.UseSerialNumbers.Get() <> ConstantsSet.UseSerialNumbers 
			AND (NOT ConstantsSet.UseSerialNumbers) Then
			
			ErrorText = CancelRemoveFunctionalOptionUseSerialNumbers();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;

	// Check for the option to uncheck UseSerialNumbersAsInventoryRecordDetails.
	If AttributePathToData = "ConstantsSet.UseSerialNumbers" Then
		
		If Constants.UseSerialNumbersAsInventoryRecordDetails.Get() <> ConstantsSet.UseSerialNumbersAsInventoryRecordDetails 
			AND (NOT ConstantsSet.UseSerialNumbersAsInventoryRecordDetails) Then
			
			ErrorText = CancelRemoveFunctionalOptionUseSerialNumbers();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;

EndFunction

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - handler of the PurchaseOrdersStatesCatalog command.
//
&AtClient
Procedure CatalogPurchaseOrderStates(Command)
	
	OpenForm("Catalog.PurchaseOrderStatuses.ListForm");
	
EndProcedure

#EndRegion

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	SetEnabled();
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler OnClose form.
&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;
	
	RefreshApplicationInterface();
	
EndProcedure

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - handler of the OnChange event of the UseSeveralUnitsForProduct field.
//
&AtClient
Procedure FunctionalOptionAccountingInVariousUOMOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseCharacteristics field.
//
&AtClient
Procedure FunctionalOptionUseCharacteristicsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the  OnChange event of the UseBatches field.
//
&AtClient
Procedure FunctionalOptionUseBatchesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSeveralWarehouses field.
//
&AtClient
Procedure FunctionalOptionAccountingByMultipleWarehousesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the FunctionalOptionUseSerialNumbers field.
//
&AtClient
Procedure FunctionalOptionFunctionalOptionUseSerialNumbersOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the FunctionalOptionUseSerialNumbersAsInventoryRecordDetails field.
//
&AtClient
Procedure FunctionalOptionUseSerialNumbersAsInventoryRecordDetailsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the CatalogBusinessUnitsWarehouses command.
//
&AtClient
Procedure CatalogBusinessUnitsWarehouses(Command)
	
	If ConstantsSet.UseSeveralWarehouses Then
		
		FilterArray = New Array;
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Warehouse"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.Retail"));
		FilterArray.Add(PredefinedValue("Enum.BusinessUnitsTypes.RetailEarningAccounting"));
		
		FilterStructure = New Structure("StructuralUnitType", FilterArray);
		
		OpenForm("Catalog.BusinessUnits.ListForm", New Structure("Filter", FilterStructure));
		
	Else
		
		ParameterWarehouse = New Structure("Key", PredefinedValue("Catalog.BusinessUnits.MainWarehouse"));
		OpenForm("Catalog.BusinessUnits.ObjectForm", ParameterWarehouse);
		
	EndIf;
	
EndProcedure

// Procedure - the OnChange event handler of the UseStorageBins field.
//
&AtClient
Procedure FunctionalOptionAccountingByCellsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseInventoryReservation field.
//
&AtClient
Procedure FunctionalOptionInventoryReservationOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UsePurchaseOrderStatuses field.
//
&AtClient
Procedure UsePurchaseOrderStatesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the InProcessStatus field.
//
&AtClient
Procedure InProcessStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CompletedStatus field.
// 
&AtClient
Procedure CompletedStatusOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - handler of the OnChange event of the UseSubcontractorManufacturers field.
//
&AtClient
Procedure FunctionalOptionTransferRawMaterialsForProcessingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

&AtClient
Procedure FunctionalOptionCounterpartiesPricesAccountingOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion

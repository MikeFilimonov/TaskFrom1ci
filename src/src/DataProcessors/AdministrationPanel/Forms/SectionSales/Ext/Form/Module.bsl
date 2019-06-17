
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
		
		If AttributePathToData = "ConstantsSet.UseRetail" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "Group1", 							"Enabled", ConstantsSet.UseRetail);
			CommonUseClientServer.SetFormItemProperty(Items, "SettingAccountingRetailSalesDetails","Enabled", ConstantsSet.UseRetail);
			CommonUseClientServer.SetFormItemProperty(Items, "Group2", 							"Enabled", ConstantsSet.UseRetail);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogSalesOrderStates",			"Enabled", ConstantsSet.UseSalesOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "SalesOrdersDefaultStatusSetting","Enabled", Not ConstantsSet.UseSalesOrderStatuses);
			
		EndIf;
		
		If AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogWorkOrderStates",			"Enabled", ConstantsSet.UseWorkOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "WorkOrdersDefaultStatusSetting",	"Enabled", Not ConstantsSet.UseWorkOrderStatuses);
			
		EndIf;
		
		// DiscountCards
		If AttributePathToData = "ConstantsSet.UseManualDiscounts" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "UseDiscountCards", "Enabled", ConstantsSet.UseManualDiscounts);
			
		EndIf;
		// End DiscountCards
		
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
		Result.Insert("NotificationForms", NotificationForms);
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses Then
			
			If Not ValueIsFilled(ConstantsSet.SalesOrdersInProgressStatus)
				OR ValueIsFilled(ConstantsSet.StateCompletedSalesOrders) Then
				
				UpdateSalesOrderStatesOnChange();
				
			EndIf;
		
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Then
		
		If Not ConstantsSet.UseWorkOrderStatuses Then
			
			If Not ValueIsFilled(ConstantsSet.WorkOrdersInProgressStatus)
				OR ValueIsFilled(ConstantsSet.StateCompletedWorkOrders) Then
				
				UpdateWorkOrderStatesOnChange();
				
			EndIf;
		
		EndIf;
		
	EndIf;
	
EndProcedure

// Procedure assigns the passed value to form attribute
//
// It is used if a new value did not pass the check
//
//
&AtServer
Procedure ReturnFormAttributeValue(AttributePathToData, CurrentValue)
	
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		ConstantsSet.UseSalesOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Then
		
		ConstantsSet.UseWorkOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SalesOrdersInProgressStatus" Then
		
		ConstantsSet.SalesOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		ConstantsSet.StateCompletedSalesOrders = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.WorkOrdersInProgressStatus" Then
		
		ConstantsSet.WorkOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.StateCompletedWorkOrders" Then
		
		ConstantsSet.StateCompletedWorkOrders = CurrentValue;

	ElsIf AttributePathToData = "ConstantsSet.UseManualDiscounts" Then
		
		ConstantsSet.UseManualDiscounts = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SendGoodsOnConsignment" Then
		
		ConstantsSet.SendGoodsOnConsignment = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.AcceptConsignedGoods" Then
		
		ConstantsSet.AcceptConsignedGoods = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseRetail" Then
		
		ConstantsSet.UseRetail = CurrentValue;
		
	// DiscountCards
	ElsIf AttributePathToData = "ConstantsSet.UseDiscountCards" Then
		
		ConstantsSet.UseDiscountCards = CurrentValue;
		
	// End
	// DiscountCards AutomaticDiscounts
	ElsIf AttributePathToData = "ConstantsSet.UseAutomaticDiscounts" Then
		
		ConstantsSet.UseAutomaticDiscounts = CurrentValue;
		
	// End AutomaticDiscounts
	EndIf;
	
EndProcedure

// Check the possibility to disable the UseSalesOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseSalesOrderStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	SalesOrder.Ref AS Ref
	|FROM
	|	Document.SalesOrder AS SalesOrder
	|WHERE
	|	(SalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR SalesOrder.OrderState.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT SalesOrder.Closed
	|				AND (SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForSale)
	|					OR SalesOrder.OperationKind = VALUE(Enum.OperationTypesSalesOrder.OrderForProcessing)))";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are documents ""Sales order"" in the base with the status ""Open"" or ""Executed (not closed)""!
		                 |Disabling the option is prohibited.
		                 |Note:
		                 |If there are documents in the state with
		                 |the status ""Open"", set them to state with the status ""In progress""
		                 |or ""Executed (closed)"" If there are documents in the state
		                 |with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseWorkOrderStatuses option.
//
&AtServer
Function CancellationUncheckUseWorkOrderStatuses()
	
	ErrorText = "";
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	WorkOrder.Ref AS Ref
	|FROM
	|	Document.WorkOrder AS WorkOrder
	|		LEFT JOIN Catalog.WorkOrderStatuses AS WorkOrderStatuses
	|		ON WorkOrder.OrderState = WorkOrderStatuses.Ref
	|WHERE
	|	(WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Open)
	|			OR WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)
	|				AND NOT WorkOrder.Closed)";
	
	Result = Query.Execute();
		
	If Not Result.IsEmpty() Then
		
		ErrorText = NStr("en = 'There are documents work orders in the base with the status ""Open"" or ""Executed (not closed)""!
		                 |Disabling the option is prohibited!
		                 |Note:
		                 |If there are documents in the state with
		                 |the status ""Open"", set them to state with the status ""In progress""
		                 |or ""Executed (closed)"" If there are documents in the state
		                 |with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseManualDiscounts option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscountsMarkups()
	
	ErrorText = "";
	SetPrivilegedMode(True);
	
	SelectionDiscountTypes = Catalogs.DiscountTypes.Select();
	While SelectionDiscountTypes.Next() Do
		RefArray = New Array;
		RefArray.Add(SelectionDiscountTypes.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			ErrorText = NStr("en = 'Discounts are already used in the database. You can''t unmark the checkbox.'");
			Break;
		EndIf;
	EndDo;
	
	SetPrivilegedMode(False);
	
	ArrayOfDocuments = New Array;

	ArrayOfDocuments.Add("Document.SalesOrder.Inventory");
	ArrayOfDocuments.Add("Document.SalesOrder.Works");
	ArrayOfDocuments.Add("Document.SubcontractorReportIssued.Products");
	ArrayOfDocuments.Add("Document.ShiftClosure.Inventory");
	ArrayOfDocuments.Add("Document.SalesInvoice.Inventory");
	ArrayOfDocuments.Add("Document.Quote.Inventory");
	ArrayOfDocuments.Add("Document.SalesSlip.Inventory");
	ArrayOfDocuments.Add("Document.ProductReturn.Inventory");
	
	QueryPattern = 
	"SELECT TOP 1
	|	CWT_Of_Document.Ref AS Ref
	|FROM
	|	&DocumentTabularSection AS CWT_Of_Document
	|WHERE
	|	CWT_Of_Document.DiscountMarkupPercent <> 0";
	
	Query = New Query;
	
	For Each ArrayElement In ArrayOfDocuments Do
		If Not IsBlankString(Query.Text) Then
			Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
		EndIf;
		Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
	EndDo;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +
			NStr("en = 'Automatic discounts are already used in the database. You can''t unmark the checkbox.'");
	EndIf;
	
	// DiscountCards
	If GetFunctionalOption("UseDiscountCards") Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) + 
			NStr("en = 'Option ""Use discount cards"" is enabled. You can''t unmark the checkbox.'");
	EndIf;
	// End DiscountCards
	
	Return ErrorText;
	
EndFunction

// Check the possibility to disable the UseRetail option.
//
&AtServer
Function CancellationUncheckFunctionalOptionAccountingRetail()
	
	ErrorText = "";
	
	Query = New Query;
	
	Query.Text =
	"SELECT
	|	SUM(ISNULL(AccumulationRegisters.RecordersCount, 0)) AS RecordersCount
	|FROM
	|	(SELECT
	|		COUNT(AccumulationRegister.Recorder) AS RecordersCount
	|	FROM
	|		AccumulationRegister.ProductRelease AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.IncomeAndExpenses AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.Inventory AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.InventoryInWarehouses AS AccumulationRegister
	|	WHERE
	|		AccumulationRegister.StructuralUnit.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.CashInCashRegisters AS AccumulationRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(AccumulationRegister.Recorder)
	|	FROM
	|		AccumulationRegister.POSSummary AS AccumulationRegister
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		COUNT(Catalog.Ref)
	|	FROM
	|		Catalog.BusinessUnits AS Catalog
	|	WHERE
	|		(Catalog.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.Retail)
	|				OR Catalog.StructuralUnitType = VALUE(Enum.BusinessUnitsTypes.RetailEarningAccounting))) AS AccumulationRegisters";
	
	QuerySelection = Query.Execute().Select();
	
	If QuerySelection.Next()
		AND QuerySelection.RecordersCount > 0 Then
		
		ErrorText = NStr("en = 'There are movements or objects related to the retail sale transaction accounting in the infobase. Cannot clear the check box.'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

#Region AutomaticDiscounts

// Check on the possibility to disable the UseAutomaticDiscounts option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseAutomaticDiscountsMarkups()
	
	ErrorText = "";
	SetPrivilegedMode(True);
	
	SelectionAutomaticDiscounts = Catalogs.AutomaticDiscountTypes.Select();
	While SelectionAutomaticDiscounts.Next() Do
		RefArray = New Array;
		RefArray.Add(SelectionAutomaticDiscounts.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			ErrorText = NStr("en = 'Cannot turn automatic discounts off because they are applied to some of the documents.'");
			Break;
		EndIf;
	EndDo;
	
	SetPrivilegedMode(False);
	
	ArrayOfDocuments = New Array;
	ArrayOfDocuments.Add("Document.SalesOrder.Inventory");
	ArrayOfDocuments.Add("Document.SalesOrder.Works");
	ArrayOfDocuments.Add("Document.ShiftClosure.Inventory");
	ArrayOfDocuments.Add("Document.SalesInvoice.Inventory");
	ArrayOfDocuments.Add("Document.Quote.Inventory");
	ArrayOfDocuments.Add("Document.SalesSlip.Inventory");
	ArrayOfDocuments.Add("Document.ProductReturn.Inventory");
	ArrayOfDocuments.Add("Document.SubcontractorReportIssued.Products");
	
	QueryPattern =
	"SELECT TOP 1
	|	CWT_Of_Document.Ref AS Ref
	|FROM
	|	&DocumentTabularSection AS CWT_Of_Document
	|WHERE
	|	CWT_Of_Document.AutomaticDiscountsPercent <> 0";
	
	Query = New Query;
	
	For Each ArrayElement In ArrayOfDocuments Do
		If Not IsBlankString(Query.Text) Then
			Query.Text = Query.Text + Chars.LF + "UNION ALL" + Chars.LF;
		EndIf;
		Query.Text = Query.Text + StrReplace(QueryPattern, "&DocumentTabularSection", ArrayElement);
	EndDo;
	
	QueryResult = Query.Execute();
	
	If Not QueryResult.IsEmpty() Then
		ErrorText = ErrorText + ?(IsBlankString(ErrorText), "", Chars.LF) +
			NStr("en = 'Cannot turn automatic discounts off because they are applied to some of the documents.'");
	EndIf;
	
	Return ErrorText;
	
EndFunction

#EndRegion

#Region DiscountCards

// Check on the possibility to uncheck the UseDiscountCards option.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseDiscountCards()
	
	ErrorText = "";
	
	SetPrivilegedMode(True);
	
	SelectionDiscountCards = Catalogs.DiscountCards.Select();
	While SelectionDiscountCards.Next() Do
		
		RefArray = New Array;
		RefArray.Add(SelectionDiscountCards.Ref);
		RefsTable = FindByRef(RefArray);
		
		If RefsTable.Count() > 0 Then
			
			ErrorText = NStr("en = 'Discount cards are used in the infobase. Cannot clear the check box.'");
			Break;
			
		EndIf;
		
	EndDo;
	
	SetPrivilegedMode(False);
	
	Return ErrorText;
	
EndFunction

#EndRegion

// Procedure updates the parameters of the sales order status.
//
&AtServerNoContext
Procedure UpdateSalesOrderStatesOnChange()
	
	InProcessStatus = Constants.SalesOrdersInProgressStatus.Get();
	CompletedStatus = Constants.StateCompletedSalesOrders.Get();
	
	If Not ValueIsFilled(InProcessStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	SalesOrderStatuses.Ref AS State
		|FROM
		|	Catalog.SalesOrderStatuses AS SalesOrderStatuses
		|WHERE
		|	SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.SalesOrdersInProgressStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(CompletedStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	SalesOrderStatuses.Ref AS State
		|FROM
		|	Catalog.SalesOrderStatuses AS SalesOrderStatuses
		|WHERE
		|	SalesOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.StateCompletedSalesOrders.Set(Selection.State);
		EndDo;
	EndIf;
	
EndProcedure

// Procedure updates the parameters of the sales order status.
//
&AtServerNoContext
Procedure UpdateWorkOrderStatesOnChange()
	
	InProcessStatus = Constants.WorkOrdersInProgressStatus.Get();
	CompletedStatus = Constants.StateCompletedWorkOrders.Get();
	
	If Not ValueIsFilled(InProcessStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	WorkOrderStatuses.Ref AS State
		|FROM
		|	Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|WHERE
		|	WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.InProcess)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.WorkOrdersInProgressStatus.Set(Selection.State);
		EndDo;
	EndIf;
	
	If Not ValueIsFilled(CompletedStatus) Then
		Query = New Query;
		Query.Text =
		"SELECT TOP 1
		|	WorkOrderStatuses.Ref AS State
		|FROM
		|	Catalog.WorkOrderStatuses AS WorkOrderStatuses
		|WHERE
		|	WorkOrderStatuses.OrderStatus = VALUE(Enum.OrderStatuses.Completed)";
		
		Result = Query.Execute();
		Selection = Result.Select();
		While Selection.Next() Do
			Constants.StateCompletedWorkOrders.Set(Selection.State);
		EndDo;
	EndIf;
	
EndProcedure

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// If there are documents Sales order or Work order with the status which differs from Executed, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		If Constants.UseSalesOrderStatuses.Get() <> ConstantsSet.UseSalesOrderStatuses
			AND (NOT ConstantsSet.UseSalesOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseSalesOrderStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the SalesOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.SalesOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.SalesOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""In progress"" state parameter is not filled in.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.SalesOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the StateCompletedSalesOrders constant
	If AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.StateCompletedSalesOrders) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""Completed"" state parameter is not filled in.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.StateCompletedSalesOrders.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are documents Sales order or Work order with the status which differs from Executed, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseWorkOrderStatuses" Then
		
		If Constants.UseWorkOrderStatuses.Get() <> ConstantsSet.UseWorkOrderStatuses
			AND (NOT ConstantsSet.UseWorkOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseWorkOrderStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the SalesOrdersInProgressStatus constant
	If AttributePathToData = "ConstantsSet.WorkOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseWorkOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.WorkOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several work order states"" check box is cleared, but the ""In progress"" state parameter is not filled in.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.WorkOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	// Check the correct filling of the StateCompletedSalesOrders constant
	If AttributePathToData = "ConstantsSet.StateCompletedWorkOrders" Then
		
		If Not ConstantsSet.UseWorkOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.StateCompletedWorkOrders) Then
			
			ErrorText = NStr("en = 'The ""Use several work order states"" check box is cleared, but the ""Completed"" state parameter is not filled in.'");
			
			Result.Insert("Field",				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.StateCompletedWorkOrders.Get());
			
		EndIf;
		
	EndIf;
	
	// If there are any references to discounts kinds in the documents, it is not allowed to remove the UseManualDiscounts flag
	If AttributePathToData = "ConstantsSet.UseManualDiscounts" Then
	
		If Constants.UseManualDiscounts.Get() <> ConstantsSet.UseManualDiscounts 
			AND (NOT ConstantsSet.UseManualDiscounts) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscountsMarkups();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are any register records, containing the retail structural unit, it is not allowed to remove the UseRetail flag
	If AttributePathToData = "ConstantsSet.UseRetail" Then
	
		If Constants.UseRetail.Get() <> ConstantsSet.UseRetail
			AND (NOT ConstantsSet.UseRetail) Then
			
			ErrorText = CancellationUncheckFunctionalOptionAccountingRetail();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// DiscountCards
	// If there are any references to the automatic discounts kinds in the documents, it is not allowed to remove the
	// UseDiscountCards flag
	If AttributePathToData = "ConstantsSet.UseDiscountCards" Then
	
		If Constants.UseDiscountCards.Get() <> ConstantsSet.UseDiscountCards 
			AND (NOT ConstantsSet.UseDiscountCards) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseDiscountCards();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End DiscountCards
	
	// AutomaticDiscounts
	// If there are any references to the automatic discounts kinds in the documents, it is not allowed to remove the
	// UseAutomaticDiscounts flag
	If AttributePathToData = "ConstantsSet.UseAutomaticDiscounts" Then
	
		If Constants.UseAutomaticDiscounts.Get() <> ConstantsSet.UseAutomaticDiscounts 
			AND (NOT ConstantsSet.UseAutomaticDiscounts) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseAutomaticDiscountsMarkups();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field",				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	// End AutomaticDiscounts
	
EndFunction

#EndRegion

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CatalogCashRegisters.
//
&AtClient
Procedure CatalogCashRegisters(Command)
	
	OpenForm("Catalog.CashRegisters.ListForm");
	
EndProcedure

// Procedure - command handler CatalogPOSTerminals.
//
&AtClient
Procedure CatalogPOSTerminals(Command)
	
	OpenForm("Catalog.POSTerminals.ListForm");
	
EndProcedure

// Procedure - command handler CatalogSalesOrderStates.
//
&AtClient
Procedure CatalogSalesOrderStates(Command)
	
	OpenForm("Catalog.SalesOrderStatuses.ListForm");
	
EndProcedure

// Procedure - command handler CatalogSalesOrderStates.
//
&AtClient
Procedure CatalogWorkOrderStates(Command)
	
	OpenForm("Catalog.WorkOrderStatuses.ListForm");
	
EndProcedure

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
	
	// Additionally
	CommonUseClientServer.SetFormItemProperty(Items, "SettingsUseReceptionForCommission", "Enabled", ConstantsSet.UseBatches);
	
EndProcedure

// Procedure - event handler OnCreateAtServer of the form.
//
&AtClient
Procedure OnOpen(Cancel)
	
	VisibleManagement();
	
EndProcedure

// Procedure - event handler of the form NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "Record_ConstantsSet" Then
		
		If Source = "UseBatches" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "SettingsUseReceptionForCommission", "Enabled", Parameter.Value);
			
		EndIf;
		
	EndIf;
	
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

// Procedure - event handler OnChange of the UseRetail field.
//
&AtClient
Procedure FunctionalOptionAccountingRetailOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the ArchiveSalesSlipsDuringTheShiftClosure field.
//
&AtClient
Procedure ArchiveCRReceiptsOnCloseCashCRSessionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the DeleteNonIssuedSalesSlips field.
//
&AtClient
Procedure DeleteUnpinnedChecksOnCloseCashRegisterShiftsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the CheckStockBalanceWhenIssuingSalesSlips field.
//
&AtClient
Procedure ControlBalancesDuringCreationCRReceiptsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseSalesOrderStatuses field.
//
&AtClient
Procedure UseSalesOrderStatusesOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseWorkOrderStatuses field.
//
&AtClient
Procedure UseWorkOrderStatusesOnChange(Item)
	
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

// Procedure - event handler OnChange of the SendGoodsOnConsignment field
//
&AtClient
Procedure FunctionalOptionTransferGoodsOnCommissionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the AcceptConsignedGoods field.
//
&AtClient
Procedure FunctionalOptionReceiveGoodsOnCommissionOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseManualDiscounts field.
//
&AtClient
Procedure FunctionalOptionUseDiscountsMarkupsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseProjects field.
//
&AtClient
Procedure FunctionalOptionAccountingByProjectsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#Region DiscountCards

// Procedure - event handler OnChange of the UseDiscountCards field.
//
&AtClient
Procedure FunctionalOptionFunctionalOptionUseDiscountCardsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

#EndRegion

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
	
	If AttributePathToData = "ConstantsSet.UseWorkOrders" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsWorkOrders",	"Enabled", ConstantsSet.UseWorkOrders);
		
		If ConstantsSet.UseWorkOrders Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogWorkOrderStates", 			"Enabled", ConstantsSet.UseSalesOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "SettingWorkOrderStatesDefault", "Enabled", Not ConstantsSet.UseSalesOrderStatuses);
			
		EndIf;
		
	EndIf;
	
	If (RunMode.ThisIsSystemAdministrator OR CommonUseReUse.CanUseSeparatedData())
		AND ConstantsSet.UseWorkOrders Then
		
		If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" OR AttributePathToData = "" Then
			
			CommonUseClientServer.SetFormItemProperty(Items, "CatalogWorkOrderStates", 			"Enabled", ConstantsSet.UseSalesOrderStatuses);
			CommonUseClientServer.SetFormItemProperty(Items, "SettingWorkOrderStatesDefault", "Enabled", Not ConstantsSet.UseSalesOrderStatuses);
			
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
		
		NotificationForms = New Structure("EventName, Parameter, Source", "Record_ConstantsSet", New Structure, ConstantName);
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
	
	If AttributePathToData = "ConstantsSet.UseWorkOrders" Then
		
		ConstantsSet.UseWorkOrders = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		ConstantsSet.UseSalesOrderStatuses = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.SalesOrdersInProgressStatus" Then
		
		ConstantsSet.SalesOrdersInProgressStatus = CurrentValue;
		
	ElsIf AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		ConstantsSet.StateCompletedSalesOrders = CurrentValue;
		
	EndIf;
	
EndProcedure

// Procedure to control the clearing of the "Use work" check box.
//
&AtServer
Function CancellationUncheckFunctionalOptionUseWorkSubsystem()
	
	ErrorText = "";
	
	Return ErrorText;
	
EndFunction

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
		
		ErrorText = NStr("en = 'There are documents ""Sales order"" in the base in the state with the ""Open"" and/or ""Executed (not closed)"" status!
		                 |Disabling the option is prohibited.
		                 |Note:
		                 |If there are documents in the state with
		                 |the status ""Open"", set them to state with the status ""In progress""
		                 |or ""Executed (closed)"" If there are documents in the state
		                 |with the status ""Executed (not closed)"", then set them to state with the status ""Executed (closed)"".'");
		
	EndIf;
	
	Return ErrorText;
	
EndFunction

// Initialization of checking the possibility to disable the ForeignExchangeAccounting option.
//
&AtServer
Function ValidateAbilityToChangeAttributeValue(AttributePathToData, Result)
	
	// Disable/disable the Service section
	If AttributePathToData = "ConstantsSet.UseWorkOrders" Then
		
		If Constants.UseWorkOrders.Get() <> ConstantsSet.UseWorkOrders
			AND (NOT ConstantsSet.UseWorkOrders) Then
			
			ErrorText = CancellationUncheckFunctionalOptionUseWorkSubsystem();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	// If there are documents Sales order or Work order with the status which differs from Executed, it is not allowed to
	// remove the flag.
	If AttributePathToData = "ConstantsSet.UseSalesOrderStatuses" Then
		
		If Constants.UseSalesOrderStatuses.Get() <> ConstantsSet.UseSalesOrderStatuses
			AND (NOT ConstantsSet.UseSalesOrderStatuses) Then
			
			ErrorText = CancellationUncheckUseSalesOrderStatuses();
			If Not IsBlankString(ErrorText) Then
				
				Result.Insert("Field", 				AttributePathToData);
				Result.Insert("ErrorText", 		ErrorText);
				Result.Insert("CurrentValue",	True);
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.SalesOrdersInProgressStatus" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.SalesOrdersInProgressStatus) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""In progress"" state parameter is not filled in.'");
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.SalesOrdersInProgressStatus.Get());
			
		EndIf;
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.StateCompletedSalesOrders" Then
		
		If Not ConstantsSet.UseSalesOrderStatuses
			AND Not ValueIsFilled(ConstantsSet.StateCompletedSalesOrders) Then
			
			ErrorText = NStr("en = 'The ""Use several sales order states"" check box is cleared, but the ""Completed"" state parameter is not filled in.'");
			Result.Insert("Field", 				AttributePathToData);
			Result.Insert("ErrorText", 		ErrorText);
			Result.Insert("CurrentValue",	Constants.StateCompletedSalesOrders.Get());
			
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

// Procedure - command handler CatalogWorkOrderStates.
//
&AtClient
Procedure CatalogWorkOrderStates(Command)
	
	OpenForm("Catalog.SalesOrderStatuses.ListForm");
	
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

// Procedure - event handler OnChange of the UseWorkOrders field.
//
&AtClient
Procedure FunctionalOptionUseWorkSubsystemOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of the UseWorkOrderStates field.
//
&AtClient
Procedure UseWorkOrderStatesOnChange(Item)
	
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

#EndRegion

#EndRegion
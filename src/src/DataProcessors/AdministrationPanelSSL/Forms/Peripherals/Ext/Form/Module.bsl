
#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
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

// Procedure controls the group visible WEB Application
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
	
	If AttributePathToData = "ConstantsSet.UsePeripherals" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "SettingsName", "Enabled", ConstantsSet.UsePeripherals);
		
	EndIf;
	
	If AttributePathToData = "ConstantsSet.UseOfflineExchangeWithPeripherals" OR AttributePathToData = "" Then
		
		CommonUseClientServer.SetFormItemProperty(Items, "OpenExchangeRulesWithPeripherals", "Enabled", ConstantsSet.UseOfflineExchangeWithPeripherals);
		
	EndIf;

EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	If ItemName = "UsePeripherals" 
		AND Not ConstantsSet.UsePeripherals Then
		ConstantsSet.UseOfflineExchangeWithPeripherals = False;
		SaveAttributeValue(Items["ConstantsSetUseOfflineExchangeWithPeripherals"].DataPath, Result);
	EndIf;
	
	SetEnabled(AttributePathToData);
	
	RefreshReusableValues();
	
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

#Region FormCommandHandlers

// Procedure - command handler UpdateSystemParameters.
//
&AtClient
Procedure UpdateSystemParameters()
	
	RefreshInterface();
	
EndProcedure

// Procedure - command handler CompanyCatalog.
//
&AtClient
Procedure CatalogPeripherals(Command)
	
	EquipmentManagerClient.RefreshClientWorkplace();
	OpenForm("Catalog.Peripherals.ListForm");
	
EndProcedure

// Procedure - command handler Workplaces.
//
&AtClient
Procedure OpenWorkplaces(Command)
	
	OpenForm("Catalog.Workplaces.ListForm", , ThisForm);
	
EndProcedure

// Procedure - command handler OpenExchangeRulesWithPeripherals.
//
&AtClient
Procedure OpenExchangeRulesWithPeripherals(Command)
	
	// RefreshInterface();
	OpenForm("Catalog.ExchangeWithOfflinePeripheralsRules.ListForm", , ThisForm);
	
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

// Procedure - event handler OnChange of field UsePeripherals.
//
&AtClient
Procedure FunctionalOptionUsePeripheralsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

// Procedure - event handler OnChange of field ConstantsSetUseOfflineExchangeWithPeripherals.
//
&AtClient
Procedure ConstantsSetUseOfflineExchangeWithPeripheralsOnChange(Item)
	
	Attachable_OnAttributeChange(Item);
	
EndProcedure

#EndRegion

#EndRegion

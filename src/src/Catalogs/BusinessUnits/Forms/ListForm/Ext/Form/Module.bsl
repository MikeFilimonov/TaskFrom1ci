
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then
		Return; // Return if the form for analysis is received..
	EndIf;
	
	MainDepartment	= DriveReUse.GetValueOfSetting("MainDepartment");
	MainWarehouse	= DriveReUse.GetValueOfSetting("MainWarehouse");
	
	MainBusinessUnits = New Array;
	MainBusinessUnits.Add(MainDepartment);
	MainBusinessUnits.Add(MainWarehouse);
	List.Parameters.SetParameterValue("MainBusinessUnits", MainBusinessUnits);
	
	ShowDepartment	= True;
	ShowWarehouse	= True;
	
	If Parameters.Filter.Property("StructuralUnitType") Then
		
		ShowDepartment	= False;
		ShowWarehouse	= False;
		
		If TypeOf(Parameters.Filter.StructuralUnitType) = Type("EnumRef.BusinessUnitsTypes") Then
			
			ShowDepartment	= Parameters.Filter.StructuralUnitType = Enums.BusinessUnitsTypes.Department;
			ShowWarehouse	= Not ShowDepartment;
			
		Else
			
			For Each ArrayItem In Parameters.Filter.StructuralUnitType Do
				If ArrayItem = Enums.BusinessUnitsTypes.Department Then
					ShowDepartment = True;
				Else
					ShowWarehouse = True;
				EndIf;
			EndDo;
			
		EndIf;
		
	EndIf;
	
	Title	= "";
	If ShowWarehouse Then
		Title	= NStr("en = 'Warehouses'");
	EndIf;
	If ShowDepartment Then
		Title	= Title + ?(ValueIsFilled(Title),", ","") + NStr("en = 'Departments'");
	EndIf;
	
	Items.FormUseAsMainDepartment.Visible	= ShowDepartment;
	Items.FormUseAsMainWarehouse.Visible	= ShowWarehouse;
	
	Items.Company.Visible = GetFunctionalOption("UseDataSync");
	
	TypesHierarchy = False;
	If Not (ShowWarehouse AND ShowDepartment) Then
		TypesHierarchy = CheckTypesHierarchy();
	EndIf;
	
	// Set form settings for the case of the opening of the choice mode
	Items.List.ChoiceMode		= Parameters.ChoiceMode;
	Items.List.MultipleChoice	= ?(Parameters.CloseOnChoice = Undefined, False, Not Parameters.CloseOnChoice);
	If Parameters.ChoiceMode Then
		PurposeUseKey = PurposeUseKey + "ChoicePick";
		WindowOpeningMode = FormWindowOpeningMode.LockOwnerWindow;
	Else
		PurposeUseKey = PurposeUseKey + "List";
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If TypesHierarchy Then
		Items.List.Representation = TableRepresentation.List;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormItemsEventsHandlers

&AtClient
Procedure ListOnActivateRow(Item)
	
	If TypeOf(Items.List.CurrentRow) <> Type("DynamicalListGroupRow")
		AND Items.List.CurrentData <> Undefined Then
		
		IsDepartment = Items.List.CurrentData.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department");
		Items.FormUseAsMainDepartment.Enabled	= Not Items.List.CurrentData.IsMain AND IsDepartment;
		Items.FormUseAsMainWarehouse.Enabled	= Not Items.List.CurrentData.IsMain AND Not IsDepartment;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UseAsMainDepartment(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMain
		Or Items.List.CurrentData.StructuralUnitType <> PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
		
		Return;
	EndIf;
	
	SetMainStructuralUnit(Items.List.CurrentData.Ref, "MainDepartment");
	Items.FormUseAsMainDepartment.Enabled	= Not Items.List.CurrentData.IsMain;
	
EndProcedure

&AtClient
Procedure UseAsMainWarehouse(Command)
	
	If TypeOf(Items.List.CurrentRow) = Type("DynamicalListGroupRow")
		Or Items.List.CurrentData = Undefined
		Or Items.List.CurrentData.IsMain
		Or Items.List.CurrentData.StructuralUnitType = PredefinedValue("Enum.BusinessUnitsTypes.Department") Then
		
		Return;
	EndIf;
	
	SetMainStructuralUnit(Items.List.CurrentData.Ref, "MainWarehouse");
	Items.FormUseAsMainWarehouse.Enabled	= Not Items.List.CurrentData.IsMain;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetMainStructuralUnit(Val NewMainStructuralUnit, SettingName)
	
	DriveServer.SetUserSetting(NewMainStructuralUnit, SettingName);
	
	ThisObject[SettingName] = NewMainStructuralUnit;
	
	MainBusinessUnits = New Array;
	MainBusinessUnits.Add(MainDepartment);
	MainBusinessUnits.Add(MainWarehouse);
	List.Parameters.SetParameterValue("MainBusinessUnits", MainBusinessUnits);
	
EndProcedure

&AtServer
Function CheckTypesHierarchy()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	BusinessUnits.Ref
	|FROM
	|	Catalog.BusinessUnits AS BusinessUnits
	|WHERE
	|	BusinessUnits.Parent <> VALUE(Catalog.BusinessUnits.EmptyRef)
	|	AND BusinessUnits.StructuralUnitType <> BusinessUnits.Parent.StructuralUnitType";
	
	Result = Query.Execute();
	If Result.IsEmpty() Then
		Return False;
	Else
		Return True;
	EndIf;
	
EndFunction

#EndRegion

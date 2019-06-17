﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	ReadOnly = True;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableEditingAbility(Command)
	
	ReadOnly = False;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.ListAdjustment.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.ThisCheckingTableRights");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = True;

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("List.Adjustment");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = Catalogs.MetadataObjectIDs.EmptyRef();

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Check the Read right'"));
	Item.Appearance.SetParameterValue("Text", NStr("en = 'Check the Edit right'"));

EndProcedure

#EndRegion
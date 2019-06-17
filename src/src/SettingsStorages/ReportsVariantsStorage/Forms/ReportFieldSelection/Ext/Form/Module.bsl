﻿#Region FormEvents

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	If Not Parameters.Property("SettingsComposer", SettingsComposer) Then
		Raise NStr("en = 'The SettingsLinker service parameter is not passed.'");
	EndIf;
	If Not Parameters.Property("Mode", Mode) Then
		Raise NStr("en = 'Service parameter ""Mode"" is not transferred.'");
	EndIf;
	If Mode = "GroupingContent" Or Mode = "VariantStructure" Then
		Mode = "GroupFields";
	EndIf;
	If Mode <> "Filters" AND Mode <> "SelectedFields" AND Mode <> "Sort" AND Mode <> "GroupFields" Then
		Raise StrReplace(NStr("en = 'Incorrect value of the ""Mode"" parameter: ""%1"".'"), "%1", String(Mode));
	EndIf;
	If Not Parameters.Property("ReportSettings", ReportSettings) Then
		Raise NStr("en = 'Service parameter ReportSettings is not passed.'");
	EndIf;
	If Parameters.Property("CurrentCDHostIdentifier", CurrentCDHostIdentifier)
		AND CurrentCDHostIdentifier <> Undefined Then
		CurrentKDNode = SettingsComposer.Settings.GetObjectByID(CurrentCDHostIdentifier);
		If TypeOf(CurrentKDNode) = Type("DataCompositionTableStructureItemCollection")
			Or TypeOf(CurrentKDNode) = Type("DataCompositionChartStructureItemCollection")
			Or TypeOf(CurrentKDNode) = Type("DataCompositionTable")
			Or TypeOf(CurrentKDNode) = Type("DataCompositionChart") Then
			CurrentCDHostIdentifier = Undefined;
		EndIf;
	EndIf;
	
	If Mode = "GroupFields" Then
		TreeItems = GroupFields.GetItems();
		GroupFieldsExpandString(KDTable(ThisObject), TreeItems);
		StringDetails = TreeItems.Add();
		StringDetails.Presentation = NStr("en = '<Detailed records>'");
		StringDetails.Picture      = PictureLib.PredefinedItem;
	EndIf;
	
	DCField = Undefined;
	Parameters.Property("DCField", DCField);
	If DCField <> Undefined Then
		KDTable = KDTable(ThisObject);
		AvailableDCField = KDTable.FindField(DCField);
		If AvailableDCField <> Undefined Then
			Items[Mode + "Table"].CurrentRow = KDTable.GetIDByObject(AvailableDCField);
		EndIf;
	EndIf;
	
	Items.Pages.CurrentPage = Items[Mode + "Page"];
	
	Source = New DataCompositionAvailableSettingsSource(ReportSettings.SchemaURL);
	SettingsComposer.Initialize(Source);
	
	CloseOnChoice = False;
EndProcedure

#EndRegion

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure Select(Command)
	ChooseAndClose();
EndProcedure

#EndRegion

#Region TABLEEVENTSFiltersTable

#Region FormTableItemsEventsHandlersFiltersTable

&AtClient
Procedure FiltersTableChoice(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ChooseAndClose();
EndProcedure

#EndRegion

#EndRegion

#Region TABLEEVENTSSelectedFieldsTable

#Region FormTableItemsEventsHandlersSelectedFieldsTable

&AtClient
Procedure SelectedFieldsTableSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ChooseAndClose();
EndProcedure

#EndRegion

#EndRegion

#Region TABLEEVENTSSortingTable

#Region FormTableItemsEventsHandlersSortingTable

&AtClient
Procedure SortTableSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ChooseAndClose();
EndProcedure

#EndRegion

#EndRegion

#Region TABLEEVENTSGroupFields

#Region FormTableItemsEventsHandlersGroupFields

&AtClient
Procedure GroupFieldsTableBeforeExpanding(ItemTable, RowID, Cancel)
	TreeRow = GroupFields.FindByID(RowID);
	If TreeRow = Undefined Then
		Return;
	EndIf;
	If Not TreeRow.NecessaryToReadAttached Then
		Return;
	EndIf;
	
	TreeRows = TreeRow.GetItems();
	TreeRows.Clear();
	
	KDTable = KDTable(ThisObject);
	AvailableDCField = KDTable.GetObjectByID(TreeRow.DCIdentifier);
	GroupFieldsExpandString(KDTable, TreeRows, AvailableDCField);
EndProcedure

&AtClient
Procedure GroupFieldsTableSelection(Item, SelectedRow, Field, StandardProcessing)
	StandardProcessing = False;
	ChooseAndClose();
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

#Region Client

&AtClient
Procedure ChooseAndClose()
	ItemTable = Items[Mode + "Table"];
	If Mode = "GroupFields" Then
		TreeRow = ItemTable.CurrentData;
		If TreeRow = Undefined Then
			Return;
		EndIf;
		DCIdentifier = TreeRow.DCIdentifier;
	Else
		DCIdentifier = ItemTable.CurrentRow;
	EndIf;
	If DCIdentifier = Undefined Then
		If Mode = "GroupFields" Then
			AvailableDCField = "<>";
		Else
			Return;
		EndIf;
	Else
		AvailableDCField = KDTable(ThisObject).GetObjectByID(DCIdentifier);
		If AvailableDCField = Undefined Then
			Return;
		EndIf;
	EndIf;
	NotifyChoice(AvailableDCField);
	Close(AvailableDCField);
EndProcedure

////////////////////////////////////////////////////////////////////////////////
// Client, Server

&AtClientAtServerNoContext
Function KDTable(ThisObject)
	If ThisObject.Mode = "Filters" Then
		Return ThisObject.SettingsComposer.Settings.Filter.FilterAvailableFields;
	ElsIf ThisObject.Mode = "SelectedFields" Then
		Return ThisObject.SettingsComposer.Settings.Selection.SelectionAvailableFields;
	ElsIf ThisObject.Mode = "Sort" Then
		Return ThisObject.SettingsComposer.Settings.Order.OrderAvailableFields;
	ElsIf ThisObject.Mode = "GroupFields" Then
		If ThisObject.CurrentCDHostIdentifier = Undefined Then
			CurrentKDNode = ThisObject.SettingsComposer.Settings;
		Else
			CurrentKDNode = ThisObject.SettingsComposer.Settings.GetObjectByID(ThisObject.CurrentCDHostIdentifier);
		EndIf;
		If TypeOf(CurrentKDNode) = Type("DataCompositionSettings") Then
			Return CurrentKDNode.GroupAvailableFields;
		Else
			Return CurrentKDNode.GroupFields.GroupFieldsAvailableFields;
		EndIf;
	EndIf;
EndFunction

&AtClientAtServerNoContext
Procedure GroupFieldsExpandString(KDTable, TreeRows, AvailableKDFieldParent = Undefined)
	If AvailableKDFieldParent = Undefined Then
		AvailableKDFieldParent = KDTable;
		Prefix = "";
	Else
		Prefix = AvailableKDFieldParent.Title + ".";
	EndIf;
	
	For Each AvailableDCField In AvailableKDFieldParent.Items Do
		If TypeOf(AvailableDCField) = Type("DataCompositionAvailableField") Then
			TreeRow = TreeRows.Add();
			TreeRow.Presentation = StrReplace(AvailableDCField.Title, Prefix, "");
			TreeRow.DCIdentifier = KDTable.GetIDByObject(AvailableDCField);
			If AvailableDCField.Table Then
				TreeRow.Picture = PictureLib.NestedTable;
			ElsIf AvailableDCField.Resource Then
				TreeRow.Picture = PictureLib.Resource;
			Else
				TreeRow.Picture = PictureLib.Attribute;
			EndIf;
			If AvailableDCField.Items.Count() > 0 Then
				TreeRow.NecessaryToReadAttached = True;
				TreeRow.GetItems().Add();
			EndIf;
		EndIf;
	EndDo;
EndProcedure

#EndRegion

#EndRegion

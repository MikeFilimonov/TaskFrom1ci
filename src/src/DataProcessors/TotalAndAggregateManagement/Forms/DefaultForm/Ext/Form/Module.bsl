﻿#Region Variables

&AtClient
Var SelectContext;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)

	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	PathToMetadataObject = FormAttributeToValue("Object").Metadata().FullName();
	
	If Not Users.InfobaseUserWithFullAccess() Then
		StandardProcessing = False;
		Return;
	EndIf;
	
	ReadInformationOnRegisters();
	
	RefreshTotalsListAtServer();
	RefreshUnitsInRegistersAtServer();
	
	If AggregatesByRegisters.Count() <> 0 Then
		Items.AggregatesList.Title = Prefix() + " " + AggregatesByRegisters[0].Description;
	Else
		Items.AggregatesList.Title = Prefix();
	EndIf;
	
	If TotalsList.Count() = 0 Then
		Items.GroupTotals.Enabled = False;
		Items.SetTotalsPeriod.Enabled = False;
		Items.EnableTotalsUsage.Enabled = False;
	EndIf;
	
	If AggregatesByRegisters.Count() = 0 Then
		Items.GroupAggregates.Enabled = False;
		Items.RebuildAndPopulateAggregates.Enabled = False;
		Items.ReceiveOptimalAggregates.Enabled = False;
	EndIf;
	
	Items.Operations.PagesRepresentation = FormPagesRepresentation.None;
	
	SetExpandedMode();
	
	CalculateTotalsOn = CurrentSessionDate();
	
	Items.DescriptionSettingPeriod.Title = StringFunctionsClientServer.SubstituteParametersInString(
		Items.DescriptionSettingPeriod.Title,
		Format(EndOfPeriod(AddMonth(CalculateTotalsOn, -1)), "DLF=D"),
		Format(EndOfPeriod(CalculateTotalsOn), "DLF=D"));
	
EndProcedure

&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	SetExpandedMode();
EndProcedure

&AtClient
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If Upper(ChoiceSource.FormName) = Upper("DataProcessor.TotalAndAggregateManagement.Form.PeriodChoiceForm") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		TotalParameters = New Structure;
		TotalParameters.Insert("ProcessHeader",  NStr("en = 'Setting calculated totals period ...'"));
		TotalParameters.Insert("AfterProcess",          NStr("en = 'Setting of calculated totals period is complete'"));
		TotalParameters.Insert("Action",               "SetTotalPeriod");
		TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
		TotalParameters.Insert("Field",                   "TotalsPeriod");
		TotalParameters.Insert("Value1",              ValueSelected.AccumulationRegistersPeriod);
		TotalParameters.Insert("Value2",              ValueSelected.PeriodForAccountingRegisters);
		TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when setting the calculated totals period.'"));
		
		TotalsControl(TotalParameters);
		
	ElsIf Upper(ChoiceSource.FormName) = Upper("DataProcessor.TotalAndAggregateManagement.Form.RebuildParametersForm") Then
		
		If TypeOf(ValueSelected) <> Type("Structure") Then
			Return;
		EndIf;
		
		If SelectContext = "RebuildAggregates" Then
			
			RelativeSize = ValueSelected.RelativeSize;
			MinimalEffect   = ValueSelected.MinimalEffect;
			
			TotalParameters = New Structure;
			TotalParameters.Insert("ProcessHeader",  NStr("en = 'Rebuilding aggregates ...'"));
			TotalParameters.Insert("AfterProcess",          NStr("en = 'Aggregates are rebuilt'"));
			TotalParameters.Insert("Action",               "RebuildAggregates");
			TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
			TotalParameters.Insert("Field",                   "Description");
			TotalParameters.Insert("Value1",              ValueSelected.RelativeSize);
			TotalParameters.Insert("Value2",              ValueSelected.MinimalEffect);
			TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when rebuilding aggregates.'"));
			
			ChangeClientAggregates(TotalParameters);
			
		ElsIf SelectContext = "OptimalAggregates" Then
			
			OptimalRelativeSize = ValueSelected.RelativeSize;
			GetOptimumAggregateClient();
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure HyperLinkWithTextOnClick(Item, StandardProcessing)
	
	StandardProcessing = False;
	FullAbilities = Not FullAbilities;
	SetExpandedMode();
	
EndProcedure

#EndRegion

#Region FormTableItemsEventsHandlersListTotals

&AtClient
Procedure TotalsListOnActivateRow(Item)
	
	If Item.CurrentData = Undefined Then
		Items.GroupTotalsDivision.Enabled = False;
	Else
		Items.GroupTotalsDivision.Enabled = Item.CurrentData.EnableTotalsSplitting;
	EndIf;
	
EndProcedure

&AtClient
Procedure TotalListChoice(Item, SelectedRow, Field, StandardProcessing)
	
	NameMetadata = TotalsList.FindByID(SelectedRow).NameMetadata;
	If Field.Name = "TotalsAggregatesTotals" Then
		
		StandardProcessing = False;
		
		ArrayOfResult = AggregatesByRegisters.FindRows(
			New Structure("NameMetadata", NameMetadata));
		
		If ArrayOfResult.Count() > 0 Then
			
			IndexOf = AggregatesByRegisters.IndexOf(ArrayOfResult[0]);
			CurrentItem = Items.AggregatesByRegisters;
			Items.AggregatesByRegisters.CurrentRow = IndexOf;
			Items.AggregatesByRegisters.CurrentItem = Items.AggregatesByRegistersDescription;
			
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure EnableTotalsUsage(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Enable totals usage...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling usage of totals is completed'"));
	TotalParameters.Insert("Action",               "SetTotalsUsing");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "UseTotals");
	TotalParameters.Insert("Value1",              True);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the totals usage.'"));
	
	TotalsControl(TotalParameters);

EndProcedure

&AtClient
Procedure EnableUsingCurrentTotals(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Current totals use disabling ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling usage of the current totals is completed'"));
	TotalParameters.Insert("Action",               "UseCurrentTotals");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "UseCurrentTotals");
	TotalParameters.Insert("Value1",              True);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the current totals usage.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure DisableTotalsUsage(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Disable totals usage...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Disabling usage of totals is completed'"));
	TotalParameters.Insert("Action",               "SetTotalsUsing");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "UseTotals");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when disabling the totals usage.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure DisableCurrentTotalsUsage(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Current totals use disabling ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Disabling usage of the current totals is completed'"));
	TotalParameters.Insert("Action",               "UseCurrentTotals");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "UseCurrentTotals");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when disabling usage of the current totals.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure UpdateTotalState(Command)
	
	RefreshTotalsListAtServer();
	
EndProcedure

&AtClient
Procedure SetTotalPeriod(Command)
	
	FormParameters = New Structure;
	FormParameters.Insert("AccumulationReg",  False);
	FormParameters.Insert("AccountingReg", False);
	
	For Each IndexOf In Items.TotalsList.SelectedRows Do
		InformationByRegister = TotalsList.FindByID(IndexOf);
		FormParameters.AccumulationReg  = FormParameters.AccumulationReg  Or InformationByRegister.Type = 0;
		FormParameters.AccountingReg = FormParameters.AccountingReg Or InformationByRegister.Type = 1;
	EndDo;
	
	OpenForm("DataProcessor.TotalAndAggregateManagement.Form.PeriodChoiceForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure TurnOnDataSeparationTotals(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Enable totals separation...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling of total separation is completed'"));
	TotalParameters.Insert("Action",               "ADivisionOf");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "TotalsDivision");
	TotalParameters.Insert("Value1",              True);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the total separation.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure DisableTotalsDivision(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Disable totals separation...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Disabling division of totals is completed'"));
	TotalParameters.Insert("Action",               "ADivisionOf");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "TotalsDivision");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when disabling the totals separation.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure UpdateAggregatesData(Command)
	
	RefreshUnitsInRegistersAtServer();
	SetFilterForUnitsList();
	
EndProcedure

&AtClient
Procedure AggregatesByRegistersOnActivateRow(Item)
	
	SetFilterForUnitsList();
	
	If Item.CurrentData = Undefined Then
		ItemsEnabled = False;
		
	ElsIf Item.SelectionMode = TableSelectionMode.SingleRow Then
		ItemsEnabled = Item.CurrentData.AggregatesMode;
	Else
		ItemsEnabled = True;
	EndIf;
	
	Items.AggregatesButtonRebuild.Enabled                     = ItemsEnabled;
	Items.AggregatesButtonClearAggregatesByRegisters.Enabled     = ItemsEnabled;
	Items.AggregatesButtonPopulateAggregatesByRegisters.Enabled    = ItemsEnabled;
	Items.AggregatesButtonOptimal.Enabled                     = ItemsEnabled;
	Items.AggregatesButtonDisableAggregatesUsage.Enabled = ItemsEnabled;
	Items.AggregatesButtonEnableAggregatesUsage.Enabled  = ItemsEnabled;
	
EndProcedure

&AtClient
Procedure EnableAggregateMode(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Enable aggregate mode ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling of aggregate mode is completed'"));
	TotalParameters.Insert("Action",               "SetUnits");
	TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalParameters.Insert("Field",                   "AggregatesMode");
	TotalParameters.Insert("Value1",              True);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the aggregate mode.'"));
	
	ChangeClientAggregates(TotalParameters);
	
EndProcedure

&AtClient
Procedure EnableTotalsMode(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Enabling the totals mode...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling of the totals mode is completed'"));
	TotalParameters.Insert("Action",               "SetUnits");
	TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalParameters.Insert("Field",                   "AggregatesMode");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the totals mode.'"));
	
	ChangeClientAggregates(TotalParameters);
	
EndProcedure

&AtClient
Procedure EnableAggregatesUsage(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Enable aggregate usage...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling of aggregate usage is completed'"));
	TotalParameters.Insert("Action",               "InstallUsingUnits");
	TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalParameters.Insert("Field",                   "AggregatesUsage");
	TotalParameters.Insert("Value1",              True);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the aggregate usage.'"));
	
	ChangeClientAggregates(TotalParameters);
	
EndProcedure

&AtClient
Procedure DisableAggregatesUsage(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Disable aggregate usage...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Disabling aggregation usage is completed'"));
	TotalParameters.Insert("Action",               "InstallUsingUnits");
	TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalParameters.Insert("Field",                   "AggregatesUsage");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when disabling aggregate usage.'"));
	
	ChangeClientAggregates(TotalParameters);
	
EndProcedure

&AtClient
Procedure RebuildAggregates(Command)
	
	SelectContext = "RebuildAggregates";
	
	FormParameters = New Structure;
	FormParameters.Insert("RelativeSize", RelativeSize);
	FormParameters.Insert("MinimalEffect",   MinimalEffect);
	FormParameters.Insert("RebuildingMode",   True);
	
	OpenForm("DataProcessor.TotalAndAggregateManagement.Form.RebuildParametersForm", FormParameters, ThisObject);
	
EndProcedure

&AtClient
Procedure ClearAggregatesByRegisters(Command)
	
	QuestionText = NStr("en = 'Aggregate cleanup may significantly slow down the reports.'");
	
	Buttons = New ValueList;
	Buttons.Add(DialogReturnCode.Yes, NStr("en = 'Clear aggregates'"));
	Buttons.Add(DialogReturnCode.Cancel);
	
	Handler = New NotifyDescription("ClearAggregatesByRegistersEnd", ThisObject);
	ShowQueryBox(Handler, QuestionText, Buttons, , DialogReturnCode.Cancel);
	
EndProcedure

&AtClient
Procedure FillAggregatesOnRegisters(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Populating aggregates...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Aggregates are populated'"));
	TotalParameters.Insert("Action",               "CompleteUnits");
	TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
	TotalParameters.Insert("Field",                   "Description");
	TotalParameters.Insert("Value1",              Undefined);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when filling in aggregates.'"));
	
	ChangeClientAggregates(TotalParameters);
	
EndProcedure

&AtClient
Procedure OptimalAggregates(Command)
	SelectContext = "OptimalAggregates";
	
	FormParameters = New Structure;
	FormParameters.Insert("RelativeSize", OptimalRelativeSize);
	FormParameters.Insert("MinimalEffect",   0);
	FormParameters.Insert("RebuildingMode",   False);
	
	OpenForm("DataProcessor.TotalAndAggregateManagement.Form.RebuildParametersForm", FormParameters, ThisObject);
EndProcedure

&AtClient
Procedure SetTotalsPeriod(Command)
	
	Result = True;
	ClearMessages();
	
	ArrayActions = TotalsList.FindRows(New Structure("BalanceAndTurnovers", True));
	
	If ArrayActions.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No registers to perform this action.'"));
		Return;
	EndIf;
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Setting calculated totals period ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Setting of calculated totals period is complete'"));
	TotalParameters.Insert("Action",               "SetTotalPeriod");
	TotalParameters.Insert("RowArray",            ArrayActions);
	TotalParameters.Insert("Field",                   "TotalsPeriod");
	TotalParameters.Insert("Value1",              EndOfPeriod(AddMonth(CalculateTotalsOn, -1)) );
	TotalParameters.Insert("Value2",              EndOfPeriod(CalculateTotalsOn) );
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when setting the calculated totals period.'"));
	TotalParameters.Insert("GroupProcessing",     True);
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure EnableTotalsUsageQuickAccess(Command)
	
	Result = True;
	ClearMessages();
	
	ArrayActions = TotalsList.FindRows(New Structure("UseTotals", False));
	
	If ArrayActions.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No registers to perform this action.'"));
		Return;
	EndIf;
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Enable totals usage...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Enabling usage of totals is completed'"));
	TotalParameters.Insert("Action",               "SetTotalsUsing");
	TotalParameters.Insert("RowArray",            ArrayActions);
	TotalParameters.Insert("Field",                   "");
	TotalParameters.Insert("Value1",              True);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when enabling the totals usage.'"));
	TotalParameters.Insert("GroupProcessing",     True);
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure FillAggregatesAndExecuteRebuild(Command)
	
	ClearMessages();
	
	ArrayActions = AggregatesByRegisters.FindRows(New Structure("AggregatesMode,AggregatesUsage", True, True));
	
	If ArrayActions.Count() = 0 Then
		ShowMessageBox(, NStr("en = 'No registers to perform the selected action for.'"));
		Return;
	EndIf;
	
	ProcessStep = 100/ArrayActions.Count();
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Rebuilding aggregates ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Aggregates are rebuilt'"));
	TotalParameters.Insert("Action",               "RebuildAggregates");
	TotalParameters.Insert("RowArray",            ArrayActions);
	TotalParameters.Insert("Field",                   "");
	TotalParameters.Insert("Value1",              0);
	TotalParameters.Insert("Value2",              0);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when rebuilding aggregates.'"));
	TotalParameters.Insert("GroupProcessing",     True);
	
	ChangeClientAggregates(TotalParameters);
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Populating aggregates...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Aggregates are populated'"));
	TotalParameters.Insert("Action",               "CompleteUnits");
	TotalParameters.Insert("RowArray",            ArrayActions);
	TotalParameters.Insert("Field",                   "");
	TotalParameters.Insert("Value1",              Undefined);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when filling in aggregates.'"));
	
	ChangeClientAggregates(TotalParameters);
	
EndProcedure

&AtClient
Procedure ReceiveOptimalAggregates(Command)
	GetOptimumAggregateClient();
EndProcedure

&AtClient
Procedure RecalcTotals(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Recalculating totals ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Totals are recalculated'"));
	TotalParameters.Insert("Action",               "RecalcTotals");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "Description");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'Total recalculation error.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure RecalcPresentTotals(Command)
	
	TotalParameters = New Structure;
	TotalParameters.Insert("ProcessHeader",  NStr("en = 'Recalculating the current totals ...'"));
	TotalParameters.Insert("AfterProcess",          NStr("en = 'Current totals recalculation completed'"));
	TotalParameters.Insert("Action",               "RecalcPresentTotals");
	TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
	TotalParameters.Insert("Field",                   "Description");
	TotalParameters.Insert("Value1",              False);
	TotalParameters.Insert("Value2",              Undefined);
	TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when recalculating the current totals.'"));
	
	TotalsControl(TotalParameters);
	
EndProcedure

&AtClient
Procedure RecalcTotalsForPeriod(Command)
	
	Handler = New NotifyDescription("RecalcTotalsForPeriodEnd", ThisObject);
	
	Dialog = New StandardPeriodEditDialog;
	Dialog.Period = RegistersRecalculationPeriod;
	Dialog.Show(Handler);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 0;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Totals'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 1;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Aggregates'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 2;

	Item.Appearance.SetParameterValue("Text", NStr("en = 'Just total register'"));

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsUseCurrentTotals.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsTotalsPeriod.Name);

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsTotalsDivision.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TotalsList.BalancesAndTurnovers");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsAggregatesTotals.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 2;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.TotalsUseTotals.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("TotalsList.AggregatesTotals");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = 1;

	Item.Appearance.SetParameterValue("BackColor", WebColors.Gainsboro);

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.AggregatesByRegisters.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("AggregatesByRegisters.OptimalBuilding");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));

EndProcedure

#Region HandlersOfAsynchronousDialogs

&AtClient
Procedure ClearAggregatesByRegistersEnd(Response, AdditionalParameters) Export
	If Response = DialogReturnCode.Yes Then
		
		TotalParameters = New Structure;
		TotalParameters.Insert("ProcessHeader",  NStr("en = 'Clearing aggregates ...'"));
		TotalParameters.Insert("AfterProcess",          NStr("en = 'Aggregates are cleared'"));
		TotalParameters.Insert("Action",               "ClearAggregates");
		TotalParameters.Insert("RowArray",            Items.AggregatesByRegisters.SelectedRows);
		TotalParameters.Insert("Field",                   "Description");
		TotalParameters.Insert("Value1",              Undefined);
		TotalParameters.Insert("Value2",              Undefined);
		TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when clearing aggregates.'"));
		
		ChangeClientAggregates(TotalParameters);
		
	EndIf;
EndProcedure

&AtClient
Procedure RecalcTotalsForPeriodEnd(ValueSelected, AdditionalParameters) Export
	If ValueSelected <> Undefined Then
		
		RegistersRecalculationPeriod = ValueSelected;
		
		TotalParameters = New Structure;
		TotalParameters.Insert("ProcessHeader",  NStr("en = 'Totals recalculation for the period ...'"));
		TotalParameters.Insert("AfterProcess",          NStr("en = 'Totals recalculation for the period completed'"));
		TotalParameters.Insert("Action",               "RecalcTotalsForPeriod");
		TotalParameters.Insert("RowArray",            Items.TotalsList.SelectedRows);
		TotalParameters.Insert("Field",                   "Description");
		TotalParameters.Insert("Value1",              RegistersRecalculationPeriod.StartDate);
		TotalParameters.Insert("Value2",              RegistersRecalculationPeriod.EndDate);
		TotalParameters.Insert("ErrorMessageText", NStr("en = 'An error occurred when recalculating the totals for the period.'"));
		
		TotalsControl(TotalParameters);
		
	EndIf;
EndProcedure

#Region Client

&AtClient
Procedure SetFilterForUnitsList()
	
	CurrentData = Items.AggregatesByRegisters.CurrentData;
	
	If CurrentData <> Undefined Then
		Filter = New FixedStructure("NameMetadata", CurrentData.NameMetadata);
		NewHeader = Prefix() +  " " + CurrentData.Description;
	Else
		Filter = New FixedStructure("NameMetadata", "");
		NewHeader = Prefix();
	EndIf;
	
	Items.AggregatesList.RowFilter = Filter;
	
	If Items.AggregatesList.Title <> NewHeader Then
		Items.AggregatesList.Title = NewHeader;
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowExecutionResult(Result, ExecuteParameters) Export
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, ExecuteParameters);
EndProcedure

&AtClient
Procedure ChangeClientAggregates(Val TotalParameters)
	
	Result = True;
	ClearMessages();
	Selected = TotalParameters.RowArray;
	
	If Selected.Count() = 0 Then
		Return;
	EndIf;
	
	ProcessStep = 100/Selected.Count();
	
	If TotalParameters.Property("GroupProcessing") Then
		NeedToBreakAfterError = ?(TotalParameters.GroupProcessing, False, AbortOnError);
	Else
		NeedToBreakAfterError = AbortOnError;
	EndIf;
	
	For Counter = 1 To Selected.Count() Do
		If TypeOf(Selected[Counter - 1]) = Type("Number") Then
			SelectedRow = AggregatesByRegisters.FindByID(Selected[Counter-1]);
		Else
			SelectedRow = Selected[Counter-1];
		EndIf;
		
		ErrorMessageField = "";
		If Not IsBlankString(TotalParameters.Field) Then
			ErrorMessageField = "AggregatesByRegisters[" + Selected[Counter-1] + "]." + TotalParameters.Field;
		EndIf;
		
		If Not SelectedRow.AggregatesMode
			AND Upper(TotalParameters.Action) <> Upper("SetUnits") Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'The operation is not allowed in the totals mode'"),
				,
				ErrorMessageField);
			Continue;
		EndIf;
		
		Status(TotalParameters.ProcessHeader, Counter * ProcessStep, SelectedRow.Description);
		
		ServerParameters = New Structure;
		ServerParameters.Insert("RegisterName",        SelectedRow.NameMetadata);
		ServerParameters.Insert("Action",           TotalParameters.Action);
		ServerParameters.Insert("ValueActions1",  TotalParameters.Value1);
		ServerParameters.Insert("ActionValue2",  TotalParameters.Value2);
		ServerParameters.Insert("ErrorInfo",  TotalParameters.ErrorMessageText);
		ServerParameters.Insert("FormField",          ErrorMessageField);
		ServerParameters.Insert("FormID", UUID);
		Result = ChangeServerAggregates(ServerParameters);
		
		UserInterruptProcessing();
		
		If Not Result.Successfully AND NeedToBreakAfterError Then
			Break;
		EndIf;
		
	EndDo;
	
	If Upper(TotalParameters.Action) = Upper("SetUnits")
		Or Upper(TotalParameters.Action) = Upper("InstallUsingUnits") Then
		RefreshTotalsListAtServer();
	EndIf;
	
	RefreshUnitsInRegistersAtServer();
	
	Status(TotalParameters.AfterProcess);
	SetFilterForUnitsList();
	
EndProcedure

&AtClient
Procedure TotalsControl(Val TotalParameters)
	
	Result = True;
	ClearMessages();
	
	Selected = TotalParameters.RowArray;
	If Selected.Count() = 0 Then
		Return;
	EndIf;
	
	ProcessStep = 100/Selected.Count();
	Action = Lower(TotalParameters.Action);
	
	If TotalParameters.Property("GroupProcessing") Then
		NeedToBreakAfterError = ?(TotalParameters.GroupProcessing, False, AbortOnError);
	Else
		NeedToBreakAfterError = AbortOnError;
	EndIf;
	
	For Counter = 1 To Selected.Count() Do
		If TypeOf(Selected[Counter-1]) = Type("Number") Then
			SelectedRow = TotalsList.FindByID(Selected[Counter-1]);
		Else
			SelectedRow = Selected[Counter-1];
		EndIf;
		
		Status(TotalParameters.ProcessHeader, Counter * ProcessStep, SelectedRow.Description);
		
		If Upper(Action) = Upper("SetTotalsUsing") Then
			If SelectedRow.AggregatesTotals = 1 Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("UseCurrentTotals") Then
			If SelectedRow.AggregatesTotals = 1 Or Not SelectedRow.BalanceAndTurnovers Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("SetTotalPeriod") Then
			If SelectedRow.AggregatesTotals = 1 Or Not SelectedRow.BalanceAndTurnovers Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("ADivisionOf") Then
			If Not SelectedRow.EnableTotalsSplitting Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("RecalcTotals") Then
			If SelectedRow.AggregatesTotals Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("RecalcTotalsForPeriod") Then
			If SelectedRow.AggregatesTotals = 1 Or Not SelectedRow.BalanceAndTurnovers Then
				Continue;
			EndIf;
			
		ElsIf Upper(Action) = Upper("RecalcPresentTotals") Then
			If Not SelectedRow.BalanceAndTurnovers Then
				Continue;
			EndIf;
		EndIf;
		
		ErrorMessageField = "";
		If Not IsBlankString(TotalParameters.Field) Then
			ErrorMessageField = "TotalsList[" + Selected[Counter - 1] + "]." + TotalParameters.Field;
		EndIf;
		
		Result = SetRegisterParametersAtServer(
			SelectedRow.Type,
			SelectedRow.NameMetadata,
			TotalParameters.Action,
			TotalParameters.Value1,
			TotalParameters.Value2,
			ErrorMessageField,
			TotalParameters.ErrorMessageText);
		
		UserInterruptProcessing();
		
		If Not Result AND NeedToBreakAfterError Then
			Break;
		EndIf;
	EndDo;
	
	RefreshTotalsListAtServer();
	
	Status(TotalParameters.AfterProcess);
	
EndProcedure

&AtClient
Procedure GetOptimumAggregateClient()
	If FullAbilities Then
		If Items.AggregatesByRegisters.SelectedRows.Count() = 0 Then
			Return;
		EndIf;
	Else
		If AggregatesByRegisters.Count() = 0 Then
			ShowMessageBox(, NStr("en = 'No registers to perform this action.'"));
			Return;
		EndIf;
	EndIf;
	
	Result = GetOptimumAggregatesServer();
	Handler = New NotifyDescription("ShowExecutionResult", ThisObject, Result);
	If Result.YouCanGet Then
		#If WebClient Then
			GetFile(Result.FileURL, Result.FileName, True);
			ExecuteNotifyProcessing(Handler, True);
		#Else
			FilesToReceive = New Array;
			FilesToReceive.Add(New TransferableFileDescription(Result.FileName, Result.FileURL));
			Extension = Lower(Mid(Result.FileName, Find(Result.FileName, ".") + 1));
			If Extension = "zip" Then
				Filter = NStr("en = 'Archive ZIP (*.%1)|*.%1'");
			ElsIf Extension = "xml" Then
				Filter = NStr("en = 'XML document (*.%1)|*.%1'");
			Else
				Filter = "";
			EndIf;
			Filter = StringFunctionsClientServer.SubstituteParametersInString(Filter, Extension);
			SaveFileDialog = New FileDialog(FileDialogMode.Save);
			SaveFileDialog.FullFileName = Result.FileName;
			SaveFileDialog.Filter = Filter;
			SaveFileDialog.Multiselect = False;
			BeginGettingFiles(Handler, FilesToReceive, SaveFileDialog, True);
		#EndIf
	Else
		ExecuteNotifyProcessing(Handler, True);
	EndIf;
	
EndProcedure

#EndRegion

#Region ClientServer

&AtClientAtServerNoContext
Function EndOfPeriod(Val Date)
	
	Return EndOfDay(EndOfMonth(Date));
	
EndFunction

&AtClientAtServerNoContext
Function Prefix()
	
	Return NStr("en = 'Register aggregates'");
	
EndFunction

#EndRegion

#Region ServerCallServer

&AtServer
Function GetOptimumAggregatesServer()
	Result = New Structure;
	Result.Insert("YouCanGet", False);
	Result.Insert("FileURL", "");
	Result.Insert("FileName", "");
	
	If FullAbilities Then
		Collection = SelectedRows("AggregatesByRegisters");
		MaximumRelativeSize = OptimalRelativeSize;
	Else
		Collection = AggregatesByRegisters;
		MaximumRelativeSize = 0;
	EndIf;
	Total = Collection.Count();
	Successfully = 0;
	HasErrors = False;
	DetailedErrorsText = "";
	
	TempFilesDir = CommonUseClientServer.AddFinalPathSeparator(
		GetTempFileName(".TAM")); // Totals & Aggregates Management.
	CreateDirectory(TempFilesDir);
	
	FilesForBackup = New ValueList;
	
	// Aggregates receiving.
	For LineNumber = 1 To Total Do
		AccumulationRegisterName = Collection[LineNumber - 1].NameMetadata;
		
		ManagerRegister = AccumulationRegisters[AccumulationRegisterName];
		ErrorInfo = Undefined;
		Try
			OptimalUnits = ManagerRegister.FindOptimalUnits(MaximumRelativeSize);
		Except
			ErrorInfo = ErrorInfo();
		EndTry;
		If ErrorInfo <> Undefined Then
			HasErrors = True;
			ErrorTitle = NStr("en = 'Cannot receive optimal aggregates of register ""%1"":'");
			DetailedErrorsText = DetailedErrorsText
				+ ?(DetailedErrorsText = "", "", Chars.LF + Chars.LF)
				+ StrReplace(ErrorTitle, "%1", AccumulationRegisterName)
				+ Chars.LF
				+ DetailErrorDescription(ErrorInfo);
			Continue;
		EndIf;
		
		FullFileName = TempFilesDir + AccumulationRegisterName + ".xml";
		
		XMLWriter = New XMLWriter();
		XMLWriter.OpenFile(FullFileName);
		XMLWriter.WriteXMLDeclaration();
		XDTOSerializer.WriteXML(XMLWriter, OptimalUnits);
		XMLWriter.Close();
		
		FilesForBackup.Add(FullFileName, AccumulationRegisterName);
		Successfully = Successfully + 1;
	EndDo;
	
	// Preparing result to transfer on client.
	If Successfully > 0 Then
		If Successfully = 1 Then
			ItemOfList = FilesForBackup[0];
			FullFileName = ItemOfList.Value;
			ShortFileName = ItemOfList.Presentation + ".xml";
		Else
			ShortFileName = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Optimal aggregates of accumulation register %1.zip'"),
				Format(CurrentSessionDate(), "DF=yyyy-MM-dd"));
			FullFileName = TempFilesDir + ShortFileName;
			SaveMode = ZIPStorePathMode.StoreRelativePath;
			ProcessingMode = ZIPSubDirProcessingMode.ProcessRecursively;
			ZipFileWriter = New ZipFileWriter(FullFileName);
			For Each ItemOfList In FilesForBackup Do
				ZipFileWriter.Add(ItemOfList.Value, SaveMode, ProcessingMode);
			EndDo;
			ZipFileWriter.Write();
		EndIf;
		BinaryData = New BinaryData(FullFileName);
		Result.YouCanGet = True;
		Result.FileName      = ShortFileName;
		Result.FileURL    = PutToTempStorage(BinaryData, UUID);
	EndIf;
	
	// Garbage clearing.
	DeleteFiles(TempFilesDir);
	
	// Messages texts preparation.
	If Total = 1 Then
		// When 1 register.
		ItemOfList = FilesForBackup[0];
		RegisterName = ItemOfList.Presentation;
		If HasErrors Then
			StandardSubsystemsClientServer.DisplayWarning(
				Result,
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'Cannot receive optimal aggregates of accumulation register ""%1"".'"),
					RegisterName),
				DetailedErrorsText);
		Else
			StandardSubsystemsClientServer.DisplayNotification(
				Result,
				NStr("en = 'Optimal aggregates successfully received.'"),
				StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = '%1 (accumulation register)'"),
					RegisterName),
				PictureLib.Successfully32);
		EndIf;
	ElsIf Successfully = 0 Then
		// Nothing worked.
		StandardSubsystemsClientServer.DisplayWarning(
			Result,
			NStr("en = 'Cannot receive optimal aggregates of accumulation registers.'"),
			DetailedErrorsText);
	ElsIf HasErrors Then
		// Partially successfully.
		StandardSubsystemsClientServer.DisplayWarning(
			Result,
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Aggregates for %1 and %2 registers are successfully received.
				     |Not received: %3.'"),
				Successfully,
				Total,
				Total - Successfully),
			DetailedErrorsText);
	Else
		// Fully successful.
		StandardSubsystemsClientServer.DisplayNotification(
			Result,
			NStr("en = 'Aggregates are received successfully.'"),
			StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Accumulation registers (%1)'"),
				Successfully),
			PictureLib.Successfully32);
	EndIf;
	
	Return Result;
EndFunction

&AtServer
Procedure RefreshTotalsListAtServer()
	
	Managers = New Array;
	Managers.Add(AccumulationRegisters);
	Managers.Add(AccountingRegisters);
	
	For Each TableRow In TotalsList Do
		
		Register = Managers[TableRow.Type][TableRow.NameMetadata];
		
		TableRow.UseTotals = Register.GetTotalsUsing();
		TableRow.TotalsDivision  = Register.GetTotalsSplittingMode();
		
		If TableRow.BalanceAndTurnovers Then
			
			TableRow.UseCurrentTotals = Register.GetPresentTotalsUsing();
			TableRow.TotalsPeriod             = Register.GetMaxTotalsPeriod();
			TableRow.AggregatesTotals            = 2;
			
		Else
			
			TableRow.UseCurrentTotals = False;
			TableRow.TotalsPeriod             = Undefined;
			TableRow.AggregatesTotals            = Register.GetAggregatesMode();
			
			If TableRow.AggregatesTotals Then
				TableRow.UseTotals = False;
			EndIf;
			
		EndIf;
		
	EndDo;
	
	GroupTotalsTitle = NStr("en = 'Totals'");
	CountTotals = TotalsList.Count();
	If CountTotals > 0 Then
		GroupTotalsTitle = GroupTotalsTitle + " (" + Format(CountTotals, "NG=") + ")";
	EndIf;
	Items.GroupTotals.Title = GroupTotalsTitle;
EndProcedure

&AtServer
Procedure RefreshUnitsInRegistersAtServer()
	
	RegisterAggregatesList.Clear();
	
	For Each TableRow In AggregatesByRegisters Do
		
		ManagerRegister = AccumulationRegisters[TableRow.NameMetadata];
		
		TableRow.AggregatesMode         = ManagerRegister.GetAggregatesMode();
		TableRow.AggregatesUsage = ManagerRegister.GetAggregatesUsing();

		Aggregates = ManagerRegister.GetUnits();
		TableRow.BuildDate     = Aggregates.BuildDate;
		TableRow.Size             = Aggregates.Size;
		TableRow.SizeLimitation = Aggregates.SizeLimitation;
		TableRow.Effect             = Aggregates.Effect;
		
		For Each Unit In Aggregates.Aggregates Do
			
			RegisterAggregatesString = RegisterAggregatesList.Add();
			
			ModificationString = "";
			For Each Dimensions In Unit.Dimensions Do
				ModificationString = ModificationString + Dimensions + ", ";
			EndDo;
			ModificationString = Mid(ModificationString, 1, StrLen(ModificationString)-2);
			
			RegisterAggregatesString.NameMetadata = TableRow.NameMetadata;
			RegisterAggregatesString.Periodicity  = String(Unit.Periodicity);
			RegisterAggregatesString.Dimensions      = ModificationString;
			RegisterAggregatesString.Use  = Unit.Use;
			RegisterAggregatesString.BeginOfPeriod  = Unit.BeginOfPeriod;
			RegisterAggregatesString.EndOfPeriod   = Unit.EndOfPeriod;
			RegisterAggregatesString.Size         = Unit.Size;
			
		EndDo;
	EndDo;
	
	RegisterAggregatesList.Sort("Use Desc");
	
	GroupUnitsHeader = NStr("en = 'Aggregates'");
	NumberOfUnits = AggregatesByRegisters.Count();
	If NumberOfUnits > 0 Then
		GroupUnitsHeader = GroupUnitsHeader + " (" + Format(NumberOfUnits, "NG=") + ")";
	EndIf;
	Items.GroupAggregates.Title = GroupUnitsHeader;
EndProcedure

&AtServerNoContext
Function SetRegisterParametersAtServer(Val RegisterType,
                                             Val RegisterName,
                                             Val Action,
                                             Val Value1,
                                             Val Value2, // Default value: Undefined.
                                             Val ErrorField,
                                             Val ErrorInfo)
	
	Managers = New Array;
	Managers.Add(AccumulationRegisters);
	Managers.Add(AccountingRegisters);
	
	Manager = Managers[RegisterType][RegisterName];
	Action = Lower(Action);
	
	Try
		
		If Upper(Action) = Upper("SetTotalsUsing") Then
			Manager.SetTotalsUsing(Value1);
			
		ElsIf Upper(Action) = Upper("UseCurrentTotals") Then
			Manager.SetUsageOfCurrentTotals(Value1);
			
		ElsIf Upper(Action) = Upper("ADivisionOf") Then
			Manager.SetTotalsSplittingMode(Value1);
			
		ElsIf Upper(Action) = Upper("SetTotalPeriod") Then
			
			If RegisterType = 0 Then
				Date = Value1;
				
			ElsIf RegisterType = 1 Then
				Date = Value2;
			EndIf;
			
			Manager.SetMaxTotalsPeriod(Date);
			
		ElsIf Upper(Action) = Upper("RecalcTotals") Then
			Manager.RecalcTotals();
			
		ElsIf Upper(Action) = Upper("RecalcPresentTotals") Then
			Manager.RecalcPresentTotals();
			
		ElsIf Upper(Action) = Upper("RecalcTotalsForPeriod") Then
			Manager.RecalcTotalsForPeriod(Value1, Value2);
			
		Else
			Raise NStr("en = 'Incorrect partner name'") + "(1): " + Action;
		EndIf;
		
	Except
		CommonUseClientServer.MessageToUser(
			ErrorInfo
			+ Chars.LF
			+ BriefErrorDescription(ErrorInfo()),
			,
			ErrorField);
		Return False;
	EndTry;
	
	Return True;
	
EndFunction

&AtServerNoContext
Function ChangeServerAggregates(Val ServerParameters)
	Result = New Structure;
	Result.Insert("Successfully", True);
	Result.Insert("ValueActions1", ServerParameters.ValueActions1);
	Result.Insert("FileAddressInTemporaryStorage", "");
	
	ManagerRegister = AccumulationRegisters[ServerParameters.RegisterName];
	RegisterMetadata = Metadata.AccumulationRegisters[ServerParameters.RegisterName];
	
	Try
		
		If Upper(ServerParameters.Action) = Upper("SetUnits") Then
			ManagerRegister.SetUnits(ServerParameters.ValueActions1);
			
		ElsIf Upper(ServerParameters.Action) = Upper("InstallUsingUnits") Then
			ManagerRegister.InstallUsingUnits(ServerParameters.ValueActions1);
			
		ElsIf Upper(ServerParameters.Action) = Upper("CompleteUnits") Then
			ManagerRegister.UpdateAggregates(False);
			
		ElsIf Upper(ServerParameters.Action) = Upper("RebuildAggregates") Then
			ManagerRegister.RebuildAggregatesUsing(ServerParameters.ValueActions1, ServerParameters.ActionValue2);
			
		ElsIf Upper(ServerParameters.Action) = Upper("ClearAggregates") Then
			ManagerRegister.ClearAggregates();
			
		Else
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Incorrect name of parameter: %1'"),
				ServerParameters.Action);
		EndIf;
		
	Except
		
		ErrorInfo = ServerParameters.ErrorInfo + " (" + BriefErrorDescription(ErrorInfo()) + ")";
		CommonUseClientServer.MessageToUser(ErrorInfo, , ServerParameters.FormField);
		Result.Successfully = False;
		
	EndTry;
	
	Return Result;
	
EndFunction

&AtServer
Procedure SetExpandedMode()
	
	If FullAbilities Then
		Title        = NStr("en = 'Totals management - full functionality'");
		HyperlinkText = NStr("en = 'Frequently used features'");
		Items.Operations.CurrentPage = Items.AdvancedAbilities;
		Items.QuickAccess.Visible          = False;
		Items.AdvancedAbilities.Visible = True;
	Else
		Title        = NStr("en = 'Totals management - frequently used features'");
		HyperlinkText = NStr("en = 'Full functionality'");
		Items.Operations.CurrentPage = Items.QuickAccess;
		Items.QuickAccess.Visible          = True;
		Items.AdvancedAbilities.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region Server

&AtServer
Function SelectedRows(TableName)
	Result = New Array;
	SelectedRows = Items[TableName].SelectedRows;
	Table = ThisObject[TableName];
	For Each ID In SelectedRows Do
		Result.Add(Table.FindByID(ID));
	EndDo;
	Return Result;
EndFunction

&AtServer
Procedure ReadInformationOnRegisters()
	
	TotalsList.Clear();
	AggregatesByRegisters.Clear();
	RegisterAggregatesList.Clear();
	
	For Each Register In Metadata.AccountingRegisters Do
		
		If Not AccessRight("TotalsControl", Register) Then
			Continue;
		EndIf;
		
		Presentation = Register.Presentation() + " (" + NStr("en = 'Accounting register'") + ")";
		Picture = PictureLib.AccountingRegister;
		
		TableRow = TotalsList.Add();
		TableRow.Type                       = 1;
		TableRow.NameMetadata            = Register.Name;
		TableRow.Picture                  = Picture;
		TableRow.BalanceAndTurnovers           = True;
		TableRow.Description              = Presentation;
		TableRow.EnableTotalsSplitting = Register.EnableTotalsSplitting ;
		
	EndDo;
	
	For Each Register In Metadata.AccumulationRegisters Do
		
		Postfix = "";
		If Register.RegisterType = Metadata.ObjectProperties.AccumulationRegisterType.Turnovers Then
			BalanceAndTurnovers = False;
			Postfix = NStr("en = 'turnover accumulation register'");
		Else
			BalanceAndTurnovers = True;
			Postfix = NStr("en = 'Accumulation register'");
		EndIf;
		
		If Not AccessRight("TotalsControl", Register) Then
			Continue;
		EndIf;
		
		Presentation = Register.Presentation() + " (" + Postfix + ")";
		Picture = PictureLib.AccumulationRegister;
		
		TableRow = TotalsList.Add();
		TableRow.Type                       = 0;
		TableRow.NameMetadata            = Register.Name;
		TableRow.Picture                  = Picture;
		TableRow.BalanceAndTurnovers           = BalanceAndTurnovers;
		TableRow.Description              = Presentation;
		TableRow.EnableTotalsSplitting = Register.EnableTotalsSplitting ;
		
	EndDo;
	
	For Each Register In Metadata.AccumulationRegisters Do
		
		If Register.RegisterType <> Metadata.ObjectProperties.AccumulationRegisterType.Turnovers Then
			Continue;
		EndIf;
		
		If Not AccessRight("TotalsControl", Register) Then
			Continue;
		EndIf;
		
		Presentation = Register.Presentation();
		Picture = PictureLib.AccumulationRegister;
		
		Aggregates = Register.Aggregates;
		
		If Aggregates.Count() = 0 Then
			Continue;
		EndIf;
		
		TableRow = AggregatesByRegisters.Add();
		TableRow.NameMetadata       = Register.Name;
		TableRow.Picture             = Picture;
		TableRow.Description         = Presentation;
		TableRow.OptimalBuilding = True;
		
	EndDo;
	
	TotalsList.Sort("Description Asc");
	AggregatesByRegisters.Sort("Description Asc");
	
EndProcedure

#EndRegion

#EndRegion

#EndRegion

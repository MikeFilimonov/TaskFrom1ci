
#Region Variables

#Region VariableForms

&AtClient
Var IdleHandlerParameters;	// Survey parameters for background job completion. See the LongActions common module

#EndRegion

#EndRegion

#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then		
		Return;		
	EndIf;
	
	QuickActionsOpened = CommonUse.CommonSettingsStorageImport("BusinessPulse", "QuickActionsOpened");
	
	If QuickActionsOpened = Undefined Then
		
		// After update, open the quick actions as a separate form
		RefreshInterface = False;
		AddQuickActionsToDesktop(RefreshInterface);
		CommonUse.CommonSettingsStorageSave("BusinessPulse", "QuickActionsOpened", True);
		
		If RefreshInterface Then
			Return;
		EndIf; 
		
	EndIf; 
	
	Initialization();
	ImportSettingsPeriods();
	LoadSettings();
	CreateItemsIndicators();
	CreateChartItems();
	UpdatePeriodPresentations(ThisForm);
	
	// Shows that the form is placed. If False (default value), then the form is opened by the platform on the home page.
	Parameters.Property("OpenedNotOnHomePage", OpenedNotOnHomePage);
	
	If OpenedNotOnHomePage Then
		Title = NStr("en = 'Business pulse'");
	EndIf; 
	
	IndicatorSettingAddress = PutToTempStorage(IndicatorSettings.Unload(), UUID);
	ChartSettingAddress = PutToTempStorage(ChartSettings.Unload(), UUID);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	If RefreshInterface Then
		AttachIdleHandler("DelayedInterfaceUpdate", 0.1, True);
		Return;
	EndIf; 
	
	// Set delay on the application start
	If OpenedNotOnHomePage Then
		BackgroundJobStartInterval = 0.1;
	Else
		BackgroundJobStartInterval = 3;
	EndIf;
	
	AttachIdleHandler("Attachable_RunBackgroundJobOnOpen", BackgroundJobStartInterval, True);
	
	CurrentItem = Items.DecorationRefresh;
	
EndProcedure

&AtClient
Procedure DelayedInterfaceUpdate()	
	RefreshInterface();		
EndProcedure

&AtClient
Procedure ChoiceProcessing(SelectedValue, ChoiceSource)
	
	If Not TypeOf(SelectedValue) = Type("Structure") Then
		Return;
	EndIf;
	
	If SelectedValue.Event = "IndicatorSetting" Then
		
		If SelectedValue.Property("RowID") Then
			Str = AddedIndicators.FindByID(SelectedValue.RowID);
		Else
			Str = AddedIndicators.Add(); 
		EndIf; 
		
		FillPropertyValues(Str, SelectedValue);
		
		// ID connection with the indicator options table
		FilterStructure = New Structure;
		FilterStructure.Insert("Indicator", SelectedValue.Indicator);
		FilterStructure.Insert("Resource",	SelectedValue.Resource);
		Rows = IndicatorSettings.FindRows(FilterStructure);
		
		If Rows.Count() > 0 Then
			Str.SettingLineID	= Rows[0].GetID();
			Str.Balance			= Rows[0].Balance;
		EndIf;
	
		SaveIndicatorSettingServer();
		
		If BackgroundJobRunning Then
			Items.PageWaiting.Visible	= True;
			Items.PageData.Visible		= False;
		EndIf;
		
		StartAwaitingBackgroundJobCompletionOnClient();
		
	ElsIf SelectedValue.Event = "ChartSetting" Then
		
		// ID connection with the indicator options table
		FilterStructure = New Structure;
		FilterStructure.Insert("Chart", SelectedValue.Chart);
		Rows = ChartSettings.FindRows(FilterStructure);
		
		If Rows.Count() = 0 Then
			Return;
		EndIf;
		
		SettingPage = Rows[0];
		SeriesDescription	= SettingPage.Series[SelectedValue.Series];
		PointDescription	= SettingPage.Points[SelectedValue.Point];
		
		If SelectedValue.Property("RowID") Then
			Str = AddedCharts.FindByID(SelectedValue.RowID);
		Else
			Str = AddedCharts.Add(); 
		EndIf; 
		
		FillPropertyValues(Str, SelectedValue);
		
		Str.SettingLineID		= SettingPage.GetID();
		Str.PointPresentations	= PointDescription.Presentations;
		
		If ValueIsFilled(SelectedValue.ComparisonPeriod) AND Not SelectedValue.BalanceMode Then
			
			PresentationArray = New Array;
			PresentationArray.Add(StandardPeriodPresentation(SelectedValue.Period));
			PresentationArray.Add(StandardPeriodPresentation(SelectedValue.ComparisonPeriod, SelectedValue.Period));
			Str.SeriesPresentations = New FixedArray(PresentationArray);
			
		ElsIf ValueIsFilled(SelectedValue.ComparisonPeriod) AND SelectedValue.BalanceMode Then
			
			PresentationArray = New Array;
			PresentationArray.Add(StandardStartDatePresentation(SelectedValue.Period));
			PresentationArray.Add(StandardStartDatePresentation(SelectedValue.ComparisonPeriod, SelectedValue.Period));
			Str.SeriesPresentations = New FixedArray(PresentationArray);
			
		Else
			Str.SeriesPresentations = SeriesDescription.Presentations;
		EndIf; 
		
		SaveChartSettingServer();
		
		If BackgroundJobRunning Then
			
			Items.PageWaiting.Visible	= True;
			Items.PageData.Visible		= False;
			
		EndIf;
		
		StartAwaitingBackgroundJobCompletionOnClient();
		
	EndIf; 
	
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	If EventName = "EnterBalance" Then
		UpdateForm();
		StartAwaitingBackgroundJobCompletionOnClient();
	EndIf;
	
EndProcedure

#EndRegion 

#Region FormsItemEventHandlers

&AtClient
Procedure Attachable_IndicatorValueClick(Item)
	
	ContextDecryptIndicator(Item);
	StandardProcessing = False;
	
EndProcedure

&AtClient
Procedure DecorationRefreshClick(Item)
	
	UpdateForm();
	StartAwaitingBackgroundJobCompletionOnClient();

EndProcedure

&AtClient
Procedure Attachable_ChartSelection(Item, ChartValue, StandardProcessing)
	
	GroupName = Left(Item.Name, Find(Item.Name, "_") - 1);
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	Rows = AddedCharts.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	DecryptChart(Rows[0].GetID());
	
EndProcedure

#EndRegion 

#Region FormCommandHandlers

&AtClient
Procedure AddIndicatorCommand(Command)	
	OpenIndicatorAdditionForm();	
EndProcedure

#Region Periods

&AtClient
Procedure SelectDate(Command)
	
	Menu = New ValueList;
	
	If ComparisonDate <> Undefined Then
		Menu.Add("InComparison", NStr("en = 'Disable comparison'"));
	Else
		Menu.Add("InComparison", NStr("en = 'Enable comparison'"));
	EndIf; 
	
	Notification = New NotifyDescription("DateSelectEnd", ThisObject);
	
	ShowChooseFromMenu(Notification, Menu, Items.DecorationIndentDateCenter);
	
EndProcedure

&AtClient
Procedure DateSelectEnd(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	If SelectedValue.Value = "InComparison" Then
		
		If ComparisonDate = Undefined Then
			ComparisonDate = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek);
		Else
			ComparisonDate = Undefined;
		EndIf; 
		
		UpdatePeriodPresentations(ThisForm);
		UpdatePartially("Balance", "ComparisonDate");
		
	EndIf; 
	
EndProcedure
 
&AtClient
Procedure ComparisonDateSelection(Command)
	
	DateArray = New Array;
	DateArray.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfLastDay));
	DateArray.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek));
	DateArray.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisMonth));
	DateArray.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisQuarter));
	DateArray.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisHalfYear));
	DateArray.Add(New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisYear));
	
	Menu = New ValueList;
	
	For Each ItemDate In DateArray Do
		Menu.Add(ItemDate, StandardStartDatePresentation(ItemDate, Date));
	EndDo;
	
	Menu.Add(New StandardBeginningDate, NStr("en = 'Custom date'"));
	
	Notification = New NotifyDescription("ComparisonDateSelectEnd", ThisObject);
	
	ShowChooseFromMenu(Notification, Menu, Items.DecorationIndentComparisonDateCenter);
	
EndProcedure

&AtClient
Procedure ComparisonDateSelectEnd(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	If SelectedValue.Value = New StandardBeginningDate Then		
		Notification = New NotifyDescription("ComparisonDateSelectionArbitraryDate", ThisObject);
		ShowInputDate(Notification, ComparisonDate, NStr("en = 'Set date'"), DateFractions.Date);		
	Else
		
		ComparisonDate		= SelectedValue.Value;
		ComparisonDateType	= DateType(ComparisonDate);
		
		UpdatePeriodPresentations(ThisForm);
		UpdatePartially("Balance", "ComparisonDate");
		
	EndIf; 
	
EndProcedure
 
&AtClient
Procedure ComparisonDateSelectionArbitraryDate(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	ComparisonDate		= New StandardBeginningDate(SelectedValue);
	ComparisonDateType	= DateType(ComparisonDate);
	
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Balance", "ComparisonDate");
	
EndProcedure
 
&AtClient
Procedure ComparisonDateBack(Command)
	
	ComparisonDate = PreviousDate(ComparisonDate, ComparisonDateType);
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Balance");
	
EndProcedure

&AtClient
Procedure ComparisonDateForward(Command)
	
	ComparisonDate = NextDate(ComparisonDate, ComparisonDateType);
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Balance");
	
EndProcedure

&AtClient
Procedure PeriodSelection(Command)
	
	PeriodArray = New Array;
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.Today));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.ThisWeek));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.ThisMonth));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.ThisQuarter));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.ThisHalfYear));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.ThisYear));
	
	LastYear = New Structure;
	LastYear.Insert("Variant", "Last7DaysExceptForCurrentDay");
	
	PreviousPeriod = DriveClientServer.Last7DaysExceptForCurrentDay();
	LastYear.Insert("StartDate",	PreviousPeriod.StartDate);
	LastYear.Insert("EndDate",		PreviousPeriod.EndDate);
	PeriodArray.Add(LastYear);
	
	Menu = New ValueList;
	
	For Each ItemPeriod In PeriodArray Do
		Menu.Add(ItemPeriod, StandardPeriodPresentation(ItemPeriod));
	EndDo;
	
	Menu.Add(New StandardPeriod, NStr("en = 'Custom period'"));
	
	If ComparisonPeriod <> Undefined Then
		Menu.Add("InComparison", NStr("en = 'Disable comparison'"));
	Else
		Menu.Add("InComparison", NStr("en = 'Enable comparison'"));
	EndIf; 
	
	Notification = New NotifyDescription("PeriodSelectEnd", ThisObject);
	
	ShowChooseFromMenu(Notification, Menu, Items.DecorationIndentPeriodCenter);
	
EndProcedure

&AtClient
Procedure PeriodSelectEnd(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	If SelectedValue.Value = "InComparison" Then
		
		If ComparisonPeriod = Undefined Then
			
			ComparisonPeriod		= ComparisonPeriodByPeriod(Period);
			ComparisonPeriodType	= PeriodType(ComparisonPeriod);
			
		Else
			
			ComparisonPeriod		= Undefined;
			ComparisonPeriodType	= "";
			
		EndIf; 
		
		UpdatePeriodPresentations(ThisForm);
		UpdatePartially("Turnovers", "ComparisonPeriod");
		
	ElsIf SelectedValue.Value = New StandardPeriod Then
		
		Notification = New NotifyDescription("PeriodSelectionArbitraryPeriod", ThisObject);
		
		Dialog = New StandardPeriodEditDialog;
		Dialog.Period = ?(TypeOf(Period) = Type("StandardPeriod"), Period, New StandardPeriod);
		Dialog.Show(Notification);
		
	Else
		
		Period		= SelectedValue.Value;
		PeriodType	= PeriodType(Period);
		
		If ComparisonPeriod <> Undefined Then
			
			ComparisonPeriod		= ComparisonPeriodByPeriod(Period);
			ComparisonPeriodType	= PeriodType(ComparisonPeriod);
			
		EndIf; 
		
		UpdatePeriodPresentations(ThisForm);
		UpdatePartially("Turnovers", "Period" + ?(ComparisonPeriod <> Undefined, ", ComparisonPeriod", ""));
		
	EndIf; 
	
EndProcedure
 
&AtClient
Procedure PeriodSelectionArbitraryPeriod(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	Period		= SelectedValue;
	PeriodType	= PeriodType(Period);
	
	If ComparisonPeriod <> Undefined Then
		
		ComparisonPeriod		= ComparisonPeriodByPeriod(Period);
		ComparisonPeriodType	= PeriodType(ComparisonPeriod);
		
	EndIf; 
	
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Turnovers", "Period" + ?(ComparisonPeriod <> Undefined, ", ComparisonPeriod", ""));
	
EndProcedure
 
&AtClient
Procedure PeriodBack(Command)
	
	Period = PreviousPeriod(Period, PeriodType);
	
	If ComparisonPeriod <> Undefined Then
		
		ComparisonPeriod		= ComparisonPeriodByPeriod(Period);
		ComparisonPeriodType	= PeriodType(ComparisonPeriod);
		
	EndIf; 
	
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Turnovers");
	
EndProcedure

&AtClient
Procedure PeriodForward(Command)
	
	Period = NextPeriod(Period, PeriodType);
	
	If ComparisonPeriod <> Undefined Then
		
		ComparisonPeriod		= ComparisonPeriodByPeriod(Period);
		ComparisonPeriodType	= PeriodType(ComparisonPeriod);
		
	EndIf; 
	
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Turnovers");
	
EndProcedure

&AtClient
Procedure ComparisonPeriodSelection(Command)
	
	PeriodArray = New Array;
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.Yesterday));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.LastWeek));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.LastMonth));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.LastQuarter));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.LastHalfYear));
	PeriodArray.Add(New StandardPeriod(StandardPeriodVariant.LastYear));
	
	RollingPeriod = New Structure;
	RollingPeriod.Insert("Variant", "PreviousFloatingPeriod");
	
	PreviousPeriod = DriveClientServer.PreviousFloatingPeriod(Period);
	RollingPeriod.Insert("StartDate",	PreviousPeriod.StartDate);
	RollingPeriod.Insert("EndDate",		PreviousPeriod.EndDate);
	
	PeriodArray.Add(RollingPeriod);
	
	LastYear = New Structure;
	LastYear.Insert("Variant", "ForLastYear");
	
	PreviousPeriod = DriveClientServer.SamePeriodOfLastYear(Period);
	LastYear.Insert("StartDate",	PreviousPeriod.StartDate);
	LastYear.Insert("EndDate",		PreviousPeriod.EndDate);
	
	PeriodArray.Add(LastYear);
	
	Menu = New ValueList;
	
	For Each ItemPeriod In PeriodArray Do
		Menu.Add(ItemPeriod, StandardPeriodPresentation(ItemPeriod, Period));
	EndDo;	
	
	Menu.Add(New StandardPeriod, NStr("en = 'Custom period'"));
	
	Notification = New NotifyDescription("ComparisonPeriodSelectEnd", ThisObject);
	
	ShowChooseFromMenu(Notification, Menu, Items.DecorationIndentComparisonPeriodCenter);
	
EndProcedure

&AtClient
Procedure ComparisonPeriodSelectEnd(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	If SelectedValue.Value = New StandardPeriod Then
		
		Notification	= New NotifyDescription("ComparisonPeriodSelectArbitraryPeriod", ThisObject);
		
		Dialog			= New StandardPeriodEditDialog;
		Dialog.Period	= ?(TypeOf(ComparisonPeriod) = Type("StandardPeriod"), ComparisonPeriod, New StandardPeriod);
		Dialog.Show(Notification);
		
	Else
		
		ComparisonPeriod		= SelectedValue.Value;
		ComparisonPeriodType	= PeriodType(ComparisonPeriod);
		
		UpdatePeriodPresentations(ThisForm);
		UpdatePartially("Turnovers", "ComparisonPeriod");
		
	EndIf; 
	
EndProcedure
 
&AtClient
Procedure ComparisonPeriodSelectArbitraryPeriod(SelectedValue, AdditionalData) Export
	
	If SelectedValue = Undefined Then
		Return;
	EndIf; 	
	
	ComparisonPeriod		= SelectedValue;
	ComparisonPeriodType	= PeriodType(ComparisonPeriod);
	
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Turnovers", "ComparisonPeriod");
	
EndProcedure
 
&AtClient
Procedure ComparisonPeriodBack(Command)
	
	ComparisonPeriod = PreviousPeriod(ComparisonPeriod, ComparisonPeriodType);
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Turnovers");
	
EndProcedure

&AtClient
Procedure ComparisonPeriodForward(Command)
	
	ComparisonPeriod = NextPeriod(ComparisonPeriod, ComparisonPeriodType);
	UpdatePeriodPresentations(ThisForm);
	UpdatePartially("Turnovers");
	
EndProcedure

#EndRegion 

#Region Indicators

&AtClient
Procedure ContextSetUpIndicator(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedIndicators.FindRows(FilterStructure);
	If Rows.Count() = 0 Then
		Return;
	EndIf; 
	
	OpenIndicatorSettingForm(Rows[0].GetID());
	
EndProcedure

&AtClient
Procedure ContextDeleteIndicator(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	Notification = New NotifyDescription("ContextDeleteIndicatorEnd", ThisObject, GroupName);
	ShowQueryBox(Notification, 
		NStr("en = 'Remove indicator?'"), 
		QuestionDialogMode.YesNo, 
		0, 
		DialogReturnCode.No
	);
	
EndProcedure

&AtClient
Procedure ContextDeleteIndicatorEnd(Result, GroupName) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf; 	
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedIndicators.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	Index = AddedIndicators.IndexOf(Rows[0]);
	Index = ?(Index=0, 0, Index - 1);
	
	ContextDeleteIndicatorServer(Rows[0].GetID());
	
	If AddedIndicators.Count()>0 
		AND Not IsBlankString(AddedIndicators[Index].GroupName) Then
		
		CurrentItem = Items[AddedIndicators[Index].GroupName + "_Title"];
		
	EndIf; 
	
EndProcedure

&AtServer
Procedure ContextDeleteIndicatorServer(ID)
	
	Str = AddedIndicators.FindByID(ID);	
	DeleteItemsRecursively(Items[Str.GroupName]);
	
	Items.Delete(Items[Str.GroupName]);
	AddedIndicators.Delete(Str);
	
	SaveSettings("Indicators");
	
EndProcedure

&AtClient
Procedure ContextMoveIndicatorUp(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedIndicators.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	ContextMoveIndicatorUpServer(Rows[0].GetID());
	
EndProcedure

&AtServer
Procedure ContextMoveIndicatorUpServer(ID)
	
	Str		= AddedIndicators.FindByID(ID);
	Index	= AddedIndicators.IndexOf(Str);
	Group	= Items[Str.GroupName];
	
	PreviousGroup = PreviousItem(Group);
	
	If PreviousGroup = Undefined Then
		Return;
	EndIf; 
	
	Items.Move(Group, Group.Parent, PreviousGroup);
	
	AddedIndicators.Move(Index, -1);
	SaveSettings("Indicators");
	
EndProcedure

&AtClient
Procedure ContextMoveIndicatorDown(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedIndicators.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	ContextMoveIndicatorDownServer(Rows[0].GetID());
	
EndProcedure

&AtServer
Procedure ContextMoveIndicatorDownServer(ID)
	
	Str		= AddedIndicators.FindByID(ID);
	Index	= AddedIndicators.IndexOf(Str);
	
	If Index = AddedIndicators.Count() - 1 Then
		Return;
	EndIf;
	
	Group		= Items[Str.GroupName];
	NextGroup	= NextItem(Group);
	
	If NextGroup = Undefined Then
		Items.Move(Group, Group.Parent);
	Else
		Items.Move(Group, Group.Parent, NextGroup);
	EndIf; 
	
	AddedIndicators.Move(Index, 1);
	SaveSettings("Indicators");
	
EndProcedure

&AtClient
Procedure ContextDecryptIndicator(Command)
	
	GroupName		= Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedIndicators.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	DecryptIndicator(Rows[0].GetID());
	
EndProcedure

#EndRegion 

#Region Charts

&AtClient
Procedure AddChartCommand(Command)	
	OpenChartAdditionForm();	
EndProcedure

&AtClient
Procedure ContextSetUpChart(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedCharts.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf; 
	
	OpenChartSettingForm(Rows[0].GetID());
	
EndProcedure

&AtClient
Procedure ContextDeleteChart(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	Notification = New NotifyDescription("ContextDeleteChartEnd", ThisObject, GroupName);
	ShowQueryBox(Notification, 
		NStr("en = 'Remove chart?'"), 
		QuestionDialogMode.YesNo, 
		0, 
		DialogReturnCode.No);
	
EndProcedure

&AtClient
Procedure ContextDeleteChartEnd(Result, GroupName) Export
	
	If Result <> DialogReturnCode.Yes Then
		Return;
	EndIf; 	
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedCharts.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	ContextDeleteChartServer(Rows[0].GetID());
	CurrentItem = Items.DecorationRefresh;
	
EndProcedure
 
&AtServer
Procedure ContextDeleteChartServer(ID)
	
	Str = AddedCharts.FindByID(ID);
	DeleteItemsRecursively(Items[Str.GroupName]);
	
	Items.Delete(Items[Str.GroupName]);
	AddedCharts.Delete(Str);
	
	SaveSettings("Charts");
	
EndProcedure

&AtClient
Procedure ContextMoveChartUp(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedCharts.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	ContextMoveChartUpServer(Rows[0].GetID());
	
EndProcedure

&AtServer
Procedure ContextMoveChartUpServer(ID)
	
	Str		= AddedCharts.FindByID(ID);
	Index	= AddedCharts.IndexOf(Str);
	
	If Index = 0 Then
		Return;
	EndIf;
	
	StrBefore = AddedCharts[Index-1];
	Items.Move(Items[Str.GroupName], Items.GroupAddedCharts, Items[StrBefore.GroupName]);
	AddedCharts.Move(Index, -1);
	
	SaveSettings("Charts");
	
EndProcedure

&AtClient
Procedure ContextMoveChartDown(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedCharts.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	ContextMoveChartDownServer(Rows[0].GetID());
	
EndProcedure

&AtServer
Procedure ContextMoveChartDownServer(ID)
	
	Str		= AddedCharts.FindByID(ID);
	Index	= AddedCharts.IndexOf(Str);
	
	If Index = AddedCharts.Count() - 1 Then
		Return;
	EndIf;
	
	If Index = AddedCharts.Count() - 2 Then
		Items.Move(Items[Str.GroupName], Items.GroupAddedCharts);
	Else
		
		StrAfter = AddedCharts[Index + 2];
		Items.Move(Items[Str.GroupName], Items.GroupAddedCharts, Items[StrAfter.GroupName]);
		
	EndIf; 
	
	AddedCharts.Move(Index, 1);
	SaveSettings("Charts");
	
EndProcedure

&AtClient
Procedure ContextDecryptChart(Command)
	
	GroupName = Left(Command.Name, Find(Command.Name, "_") - 1);
	
	FilterStructure = New Structure;
	FilterStructure.Insert("GroupName", GroupName);
	
	Rows = AddedCharts.FindRows(FilterStructure);
	
	If Rows.Count() = 0 Then
		Return;
	EndIf;
	
	DecryptChart(Rows[0].GetID());
	
EndProcedure

#EndRegion 

#EndRegion 

#Region BackgroundJobReceiveData

&AtClient
Procedure Attachable_RunBackgroundJobOnOpen()
	
	RunBackgroundJobOnServer();
	
	If Not BackgroundJobRunning Then
		
		If Items.PageWaiting.Visible Then		
			Items.PageWaiting.Visible	= False;
			Items.PageData.Visible		= True;			
		EndIf;
		
	EndIf;
	
	StartAwaitingBackgroundJobCompletionOnClient();
	
EndProcedure

&AtClient
Procedure Attachable_CheckLongActionCompletion()
	
	If BackgroundJobRunning Then
		
		If JobCompleted(BackgroundJobID) Then
			
			// Data is calculated, update the form data
			BackgroundJobRunning	= False;
			BackgroundJobCompleted	= True;
			
			RefreshData();
			
			If Items.PageWaiting.Visible Then
				
				Items.PageWaiting.Visible	= False;
				Items.PageData.Visible		= True;
				
			EndIf;
			
			If Not Items.GroupIndicatorsBalance.Enabled Then
				Items.GroupIndicatorsBalance.Enabled = True;
			EndIf;
			
			If Not Items.GroupIndicatorsTurnovers.Enabled Then
				Items.GroupIndicatorsTurnovers.Enabled = True;
			EndIf;
			
		Else
			
			// Continue waiting
			LongActionsClient.UpdateIdleHandlerParameters(IdleHandlerParameters);
			AttachIdleHandler(
				"Attachable_CheckLongActionCompletion",
				IdleHandlerParameters.CurrentInterval,
				True);
				
		EndIf;
		
	EndIf;
	
EndProcedure

&AtServer
Procedure RunBackgroundJobOnServer(Section = "", SavedPeriods = "")
	
	If ExclusiveMode() Then
		Return;
	EndIf;
	
	If Not IsBlankString(SavedPeriods) Then
		SaveSettingsPeriods(SavedPeriods);
	EndIf; 
	
	If BackgroundJobRunning AND Not JobCompleted(BackgroundJobID) Then
		BackgroundJobCancel(BackgroundJobID);
	EndIf;
	
	CurrentSessionDate = CurrentSessionDate();
	
	// Turn the parameters into structure to transfer them via LongActions.
	ProcedureParameters = New Structure;
	ProcedureParameters.Insert("Date",				New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay));
	ProcedureParameters.Insert("ComparisonDate",	ComparisonDate);
	ProcedureParameters.Insert("Period",			Period);
	ProcedureParameters.Insert("ComparisonPeriod",	ComparisonPeriod);
	ProcedureParameters.Insert("Indicators",		AddedIndicators.Unload());
	ProcedureParameters.Insert("Charts",			AddedCharts.Unload());
	
	If Not IsBlankString(Section) Then
		ProcedureParameters.Insert("Section", Section);
	EndIf; 
	
	JobDescription = NStr("en = 'Business pulse widgets update'");
		
	Result = LongActions.ExecuteInBackground(
		UUID,
		"DataProcessors.BusinessPulse.ReceiveData",
		ProcedureParameters,
		JobDescription);
	
	BackgroundJobResultAddress = Result.StorageAddress;
	BackgroundJobID   = Result.JobID;
	
	// If the background job was finished during call, the data has already been received
	If Result.JobCompleted Then
		
		RefreshData();
		BackgroundJobCompleted = True;
		
	Else
		// otherwise, start waiting for the background job to be completed
		BackgroundJobRunning = True;
		
		If IsBlankString(Section) Then
			
			Items.PageWaiting.Visible	= True;
			Items.PageData.Visible		= False;
			
		EndIf; 
		
	EndIf;
	
EndProcedure

&AtClient
Procedure StartAwaitingBackgroundJobCompletionOnClient()
	
	If BackgroundJobRunning Then
		
		// Start survey of background job completion
		LongActionsClient.InitIdleHandlerParameters(IdleHandlerParameters);
		AttachIdleHandler("Attachable_CheckLongActionCompletion",
			IdleHandlerParameters.CurrentInterval,
			True);
			
	EndIf;
	
EndProcedure

&AtServerNoContext
Function JobCompleted(JobID)	
	Return LongActions.JobCompleted(JobID);	
EndFunction

&AtServerNoContext
Procedure BackgroundJobCancel(BackgroundJobID)	
	LongActions.CancelJobExecution(BackgroundJobID);	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

#Region Indicators

&AtServer
Procedure AddIndicator(
	Indicator, 
	Resource 					= "", 
	Presentation 				= "", 
	ResourcePresentation 		= "", 
	Balance 					= False, 
	Currency 					= False, 
	Format						= "", 
	TemplateName 				= "", 
	ReportName 					= "", 
	VariantKey 					= "", 
	ReportColumns 				= "", 
	AccountingSection 			= "")
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Indicator", Indicator);
	SearchStructure.Insert("Resource", Resource);
	
	If IndicatorSettings.FindRows(SearchStructure).Count() > 0 Then
		Return;
	EndIf; 
	
	Str = IndicatorSettings.Add();
	Str.Indicator				= Indicator;
	Str.Resource 				= Resource;
	Str.Presentation			= ?(IsBlankString(Presentation), Indicator, Presentation);
	Str.ResourcePresentation	= ?(IsBlankString(ResourcePresentation), Resource, ResourcePresentation);
	Str.Balance					= Balance;
	Str.Currency				= Currency;
	Str.Format					= Format;
	Str.TemplateName			= TemplateName;
	Str.ReportName				= ReportName;
	Str.VariantKey				= VariantKey;
	
	If ValueIsFilled(ReportName) 
		AND ValueIsFilled(VariantKey) Then
		
		Str.Variant				= ReportsVariants.GetRef(
			CommonUse.MetadataObjectID(Metadata.FindByFullName(ReportName)), 
			VariantKey);
		
	EndIf; 
	
	Str.ReportColumns			= ReportColumns;
	Str.AccountingSection		= AccountingSection;
	
EndProcedure

&AtServer
Procedure DisplayIndicator(Indicator, Resource, Presentation = "")
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Indicator",	Indicator);
	FilterStructure.Insert("Resource",	Resource);
	
	Rows = IndicatorSettings.FindRows(FilterStructure);
	
	For Each Str In Rows Do
		
		DataStr = AddedIndicators.Add();
		FillPropertyValues(DataStr, Str, "Indicator, Resource");
		
		DataStr.Presentation	= ?(IsBlankString(Presentation), Str.ResourcePresentation, Presentation);
		DataStr.SettingLineID	= Str.GetID();
		DataStr.Balance			= Str.Balance;
		
		If Not IsBlankString(Str.AccountingSection) Then
			DataStr.EnterBalance = BalanceInputModes[Str.AccountingSection];
		EndIf;
		
	EndDo; 
	
EndProcedure

&AtClient
Procedure OpenIndicatorAdditionForm()
	
	If BackgroundJobRunning Then
		Return;
	EndIf; 
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("Indicator",	Undefined);
	OpeningStructure.Insert("Resource",		Undefined);
	OpeningStructure.Insert("Presentation",	"");
	OpeningStructure.Insert("Filters",		New FixedArray(New Array));
	OpeningStructure.Insert("Settings",		New FixedArray(New Array));
	
	OpeningStructure.Insert("IndicatorSettingAddress", IndicatorSettingAddress);
	
	OpenForm("DataProcessor.BusinessPulse.Form.IndicatorSettingForm", OpeningStructure, ThisObject);
	
EndProcedure

&AtClient
Procedure OpenIndicatorSettingForm(ID)
	
	If BackgroundJobRunning Then
		Return;
	EndIf; 
	
	Str = AddedIndicators.FindByID(ID);
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("Indicator",	Str.Indicator);
	OpeningStructure.Insert("Resource",		Str.Resource);
	OpeningStructure.Insert("Presentation",	Str.Presentation);
	OpeningStructure.Insert("Filters",		Str.Filters);
	OpeningStructure.Insert("Settings",		Str.Settings);
	OpeningStructure.Insert("RowID",		ID);
	
	OpeningStructure.Insert("IndicatorSettingAddress", IndicatorSettingAddress);
	
	OpenForm("DataProcessor.BusinessPulse.Form.IndicatorSettingForm", OpeningStructure, ThisObject);
	
EndProcedure

&AtServer
Procedure UpdateIndicatorValues()
	
	Data = GetFromTempStorage(BackgroundJobResultAddress);
	
	For Each Str In AddedIndicators Do
		
		If Not IsBlankString(Data.Section) 
			AND	((Data.Section = "Balance" AND Not Str.Balance) 
				OR (Data.Section = "Turnovers" AND Str.Balance)) Then
					Continue;
		EndIf; 
		
		Str.Value = 0;
		Str.Update = 0;
		Str.Tooltip = "";
		
	EndDo;
	
	For Each Str In AddedCharts Do
		
		ObjectChart = ThisForm[Str.AttributeName];
		ObjectChart.RefreshEnabled = False;
		
	EndDo;
	
	For Each Item In Data.Indicators Do
		
		ValueStructure = Item.Value;
		
		If Not ValueIsFilled(ValueStructure.Value) AND Not ValueIsFilled(ValueStructure.ComparisonValue) Then
			Continue;
		EndIf; 
		
		Str			= AddedIndicators[Item.Key];
		SettingsRow = IndicatorSettings.FindByID(Str.SettingLineID);
		
		If ValueIsFilled(ValueStructure.Value) Then
			Str.Value = FormatValue(ValueStructure.Value, Str);
		EndIf; 
		
		If (ComparisonPeriod <> Undefined AND Not Str.Balance) OR
			(ComparisonDate <> Undefined AND Str.Balance) Then
			
			If TypeOf(ValueStructure.Value) = Type("Map") Then
				Continue;
			EndIf; 
			
			If ValueStructure.ComparisonValue < ValueStructure.Value Then
				Str.Update = 1;
			ElsIf ValueStructure.ComparisonValue > ValueStructure.Value Then
				Str.Update = 2;
			Else
				Str.Update = 0;
			EndIf;
			
			If SettingsRow.Balance Then
				
				Str.Tooltip = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'At the %1: %2'"),
					Lower(StandardStartDatePresentation(ComparisonDate, Date)),
					FormatValue(ValueStructure.ComparisonValue, Str));
					
			Else
					
				Str.Tooltip = StringFunctionsClientServer.SubstituteParametersInString(
					NStr("en = 'For the %1: %2'"),
					Lower(StandardPeriodPresentation(ComparisonPeriod, Period)),
					FormatValue(ValueStructure.ComparisonValue, Str));
					
			EndIf; 
			
		EndIf;
		
	EndDo;
	
	For Each Str In AddedIndicators Do
		
		If IsBlankString(Str.Resource) Then
			Continue;
		EndIf;
		
		If Not ValueIsFilled(Str.Value) Then
			Str.Value = ?(Str.EnterBalance, New FormattedString(PictureLib.PlusGray), "-");
		EndIf; 
		
		ItemValue			= Items[Str.GroupName+"_Value"];
		ItemValue.Title		= Str.Value;
		ItemValue.Hyperlink = Not (Str.Value="-");
		
		ItemComparison		= Items[Str.GroupName+"_Comparison"];
		
		If Str.Update = 0 Then
			ItemComparison.Picture = PictureLib.Empty;
		ElsIf Str.Update = 1 Then
			ItemComparison.Picture = PictureLib.ValueIncrease;
		ElsIf Str.Update = 2 Then
			ItemComparison.Picture = PictureLib.ValueDecrease;
		EndIf;
		
		ItemComparison.Tooltip = Str.Tooltip;
		
	EndDo; 
	
	For Each Str In AddedCharts Do
		
		ObjectChart = ThisForm[Str.AttributeName];
		ObjectChart.RefreshEnabled = True;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CreateItemsIndicators()
	
	For Each Str In AddedIndicators Do
		
		If IsBlankString(Str.Resource) Then
			Continue;
		EndIf; 
		
		If IsBlankString(Str.GroupName) Then
			
			Str.GroupName = "Indicator" + StrReplace(String(New UUID), "-", "");
			
			If Str.Balance Then
				NewGroup = Items.Add(Str.GroupName, Type("FormGroup"), Items.GroupIndicatorsBalance);
			Else
				NewGroup = Items.Add(Str.GroupName, Type("FormGroup"), Items.GroupIndicatorsTurnovers);
			EndIf; 
			
			NewGroup.Type					= FormGroupType.UsualGroup;
			NewGroup.ShowTitle				= False;
			NewGroup.Representation			= UsualGroupRepresentation.None;
			NewGroup.VerticalStretch		= False;
			NewGroup.Group					= ChildFormItemsGroup.Horizontal;
			NewGroup.ThroughAlign			= ThroughAlign.Use;
			
			ItemHeader						= Items.Add(Str.GroupName + "_Title", Type("FormDecoration"), NewGroup);
			ItemHeader.Type					= FormDecorationType.Label;
			ItemHeader.VerticalAlign		= ItemVerticalAlign.Top;
			ItemHeader.HorizontalStretch	= True;
			ItemHeader.AutoMaxWidth			= False;
			ItemHeader.MaxWidth				= 0;
			ItemHeader.SkipOnInput			= False;
			
			If Not IsBlankString(Str.Resource) Then
				
				ItemHeader.TextColor		= StyleColors.MinorInscriptionText;
				ItemHeader.Width			= 25;
				
				ItemValue					= Items.Add(Str.GroupName + "_Value", Type("FormDecoration"), NewGroup);
				ItemValue.Type				= FormDecorationType.Label;
				ItemValue.Hyperlink			= True;
				ItemValue.Width				= 11;
				ItemValue.HorizontalAlign	= ItemHorizontalLocation.Right;
				ItemValue.VerticalAlign		= ItemVerticalAlign.Top;
				ItemValue.HorizontalStretch	= False;
				ItemValue.Height			= 1;
				ItemValue.TextColor			= StyleColors.FormTextColor;
				ItemValue.SetAction("Click", "Attachable_IndicatorValueClick");
				
				ItemComparison						= Items.Add(Str.GroupName + "_Comparison", Type("FormDecoration"), NewGroup);
				ItemComparison.Type					= FormDecorationType.Picture;
				ItemComparison.HorizontalStretch	= False;
				ItemComparison.VerticalStretch		= False;
				ItemComparison.Height				= 1;
				ItemComparison.Width				= 1;
				ItemComparison.PictureSize			= PictureSize.RealSize;
				
			Else
				
				ItemHeader.HorizontalAlign	= ItemHorizontalLocation.Center;
				ItemHeader.VerticalAlign	= ItemVerticalAlign.Bottom;
				ItemHeader.Height			= ?(AddedIndicators.IndexOf(Str) = 0, 1, 2);
				
			EndIf; 
			
			// Context menu
			AddCommand(Str.GroupName, 
				"_Setup", 
				ItemHeader, 
				"ContextSetUpIndicator", 
				NStr("en = 'Indicator settings'"), 
				PictureLib.SettingsStorage
			);
			
			Button = AddCommand(Str.GroupName, 
				"_Delete", 
				ItemHeader, 
				"ContextDeleteIndicator", 
				NStr("en = 'Remove indicator'"), 
				PictureLib.Delete
			);
			
			If IsBlankString(Str.Resource) Then
				Button.Title = NStr("en = 'Remove title'");
			EndIf; 
			
			AddCommand(Str.GroupName, 
				"_Up", 
				ItemHeader, 
				"ContextMoveIndicatorUp", 
				NStr("en = 'Move up'"), 
				PictureLib.MoveUp
			);
			
			AddCommand(Str.GroupName, 
				"_Down", 
				ItemHeader, 
				"ContextMoveIndicatorDown", 
				NStr("en = 'Move down'"), 
				PictureLib.MoveDown
			);
			
		Else
			ItemHeader = Items[Str.GroupName + "_Title"];
		EndIf;
		
		If IsBlankString(Str.Resource) Then
			ItemHeader.Title = New FormattedString(Upper(Str.Presentation), New Font(New Font(),,, True));
		Else
			ItemHeader.Title = Str.Presentation;
		EndIf;
		
	EndDo; 
	
EndProcedure

&AtClient
Procedure DecryptIndicator(ID)
	
	CurPage		= AddedIndicators.FindByID(ID);
	SettingPage	= IndicatorSettings.FindByID(CurPage.SettingLineID);
	
	If Not ValueIsFilled(SettingPage.Variant) Then
		Return;
	EndIf;
	
	If CurPage.EnterBalance Then
		
		// Open opening balance input wizard instead of decryption
		OpenParameters = New Structure;
		OpenParameters.Insert("AccountingSection", SettingPage.AccountingSection);
		OpenForm("CommonForm.OpeningBalanceFillingWizard", OpenParameters, ThisObject);
		
		Return;
		
	EndIf; 
	
	DecryptionFilter = New Map;
	
	If SettingPage.Balance Then
		
		DecryptionPeriod = '0001-01-01';
		DecryptionFilter.Insert("BeginOfPeriod",	BegOfDay(DecryptionPeriod));
		DecryptionFilter.Insert("Period",			DecryptionPeriod);
		DecryptionFilter.Insert("EndOfPeriod",		DecryptionPeriod);
		
	Else
		
		If TypeOf(Period) = Type("StandardPeriod") Then
			
			DecryptionStartDate	= BegOfDay(Period.StartDate);
			DecryptionEndDate	= ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), '0001-01-01');
			
		ElsIf TypeOf(Period) = Type("Structure") Then
			
			UpdatePeriodStartAndEndDates(Period);
			DecryptionStartDate = BegOfDay(Period.StartDate);
			DecryptionEndDate	= ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), '0001-01-01');
			
		Else
			DecryptionStartDate	= '0001-01-01';
			DecryptionEndDate	= '0001-01-01';
		EndIf; 
		
		DecryptionFilter.Insert("BeginOfPeriod",	DecryptionStartDate);
		DecryptionFilter.Insert("EndOfPeriod",		DecryptionEndDate);
		
	EndIf;
	
	If TypeOf(CurPage.Filters) = Type("FixedArray") Then
		
		For Each Filter In CurPage.Filters Do
			
			ValueStructure = New Structure;
			ValueStructure.Insert("ComparisonType", Filter.ComparisonType);
			ValueStructure.Insert("Value",			Filter.Value);
			
			DecryptionFilter.Insert(Filter.Field, ValueStructure);
			
		EndDo; 
		
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("GenerateOnOpen", True);
	
	If Not IsBlankString(SettingPage.ReportColumns) Then
		FormParameters.Insert("Columns", SettingPage.ReportColumns);
	EndIf; 
	
	FormParameters.Insert("DecryptionFilter", DecryptionFilter);
	ReportsVariantsClient.OpenReportForm(ThisForm, SettingPage.Variant, FormParameters);
	
EndProcedure

&AtServer
Procedure SaveIndicatorSettingServer()
	
	SaveSettings("Indicators");
	CreateItemsIndicators();
	RunBackgroundJobOnServer();
	
EndProcedure

#EndRegion 

#Region Charts

&AtServer
Procedure AddPointSeriesDescription(SeriesPointStructure, Name, Presentations, Title = "", ChartType = Undefined, Currency = False, Format = "", AvailableSeriesPoints = "", RequiredFilters = Undefined)
	
	PointSeriesDescription = New Structure;
	
	If TypeOf(Presentations) = Type("String") Then		
		PresentationArray = New Array;
		PresentationArray.Add(Presentations);		
	Else
		PresentationArray = Presentations;
	EndIf; 
	
	PointSeriesDescription.Insert("Presentations",			New FixedArray(PresentationArray));
	PointSeriesDescription.Insert("Title",					Title);
	PointSeriesDescription.Insert("ChartType",				ChartType);
	PointSeriesDescription.Insert("Currency",				Currency);
	PointSeriesDescription.Insert("Format",					Format);
	PointSeriesDescription.Insert("AvailableSeriesPoints",	AvailableSeriesPoints);
	PointSeriesDescription.Insert("RequiredFilters",		RequiredFilters);
	
	SeriesPointStructure.Insert(Name, PointSeriesDescription);
	
EndProcedure

&AtServer
Procedure AddChart(Chart, Presentation = "", Series, Points, Balance, TemplateName = "", ReportName = "", VariantKey = "", ProhibitComparison = False)
	
	SearchStructure = New Structure;
	SearchStructure.Insert("Chart", Chart);
	
	If ChartSettings.FindRows(SearchStructure).Count() > 0 Then
		Return;
	EndIf; 
	
	Str						= ChartSettings.Add();
	Str.Chart				= Chart;
	Str.Presentation		= ?(IsBlankString(Presentation), Chart, Presentation);
	Str.Series				= Series;
	Str.Points				= Points;
	Str.Balance				= Balance;
	Str.TemplateName		= TemplateName;
	Str.ReportName			= ReportName;
	Str.VariantKey			= VariantKey;
	Str.ProhibitComparison	= ProhibitComparison;
	
	If ValueIsFilled(ReportName) AND ValueIsFilled(VariantKey) Then
		Str.Variant = ReportsVariants.GetRef(CommonUse.MetadataObjectID(Metadata.FindByFullName(ReportName)), VariantKey);
	EndIf; 
	
EndProcedure

&AtServer
Procedure DisplayChart(Chart, Series, Point, Period = Undefined, ComparisonPeriod = Undefined, Presentation = "", Filters = Undefined)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Chart", Chart);
	Rows = ChartSettings.FindRows(FilterStructure);
	
	For Each Str In Rows Do
		
		SeriesSettings	= Str.Series[Series];
		PointSettings	= Str.Points[Point];
		
		DataStr						= AddedCharts.Add();
		DataStr.Chart				= Chart;
		DataStr.Series				= Series;
		DataStr.Point				= Point;
		DataStr.Presentation		= ?(IsBlankString(Presentation), Str.Presentation, Presentation);
		DataStr.SeriesPresentations	= SeriesSettings.Presentations;
		DataStr.PointPresentations	= PointSettings.Presentations;
		DataStr.SettingLineID		= Str.GetID();
		
		If ValueIsFilled(Period) Then
			DataStr.Period = Period;
		EndIf; 
		
		If ValueIsFilled(ComparisonPeriod) Then
			DataStr.ComparisonPeriod = ComparisonPeriod;
		EndIf;
		
		If ValueIsFilled(Filters) Then
			DataStr.Filters = New FixedArray(Filters);
		EndIf;
		
	EndDo; 
	
EndProcedure

&AtClient
Procedure OpenChartAdditionForm()
	
	If BackgroundJobRunning Then
		Return;
	EndIf; 
	
	OpeningStructure = New Structure;
	OpeningStructure.Insert("Chart",			Undefined);
	OpeningStructure.Insert("Series",			Undefined);
	OpeningStructure.Insert("Point",			Undefined);
	OpeningStructure.Insert("Presentation",		"");
	OpeningStructure.Insert("Period",			New StandardPeriod);
	OpeningStructure.Insert("ComparisonPeriod",	New StandardPeriod);
	OpeningStructure.Insert("Filters",			New FixedArray(New Array));
	OpeningStructure.Insert("Settings",			New FixedArray(New Array));
	
	OpeningStructure.Insert("ChartSettingAddress", ChartSettingAddress);
	
	OpenForm("DataProcessor.BusinessPulse.Form.ChartSettingForm", OpeningStructure, ThisObject);
	
EndProcedure
 
&AtClient
Procedure OpenChartSettingForm(ID)
	
	If BackgroundJobRunning Then
		Return;
	EndIf; 
	
	Str = AddedCharts.FindByID(ID);
	OpeningStructure = New Structure;
	OpeningStructure.Insert("Chart",			Str.Chart);
	OpeningStructure.Insert("Series",			Str.Series);
	OpeningStructure.Insert("Point",			Str.Point);
	OpeningStructure.Insert("Presentation",		Str.Presentation);
	OpeningStructure.Insert("Period",			Str.Period);
	OpeningStructure.Insert("ComparisonPeriod",	Str.ComparisonPeriod);
	
	If TypeOf(Str.Filters) = Type("FixedArray") Then
		OpeningStructure.Insert("Filters", Str.Filters);
	Else
		OpeningStructure.Insert("Filters", New FixedArray(New Array));
	EndIf;
	
	If TypeOf(Str.Settings) = Type("FixedArray") Then
		OpeningStructure.Insert("Settings", Str.Settings);
	Else
		OpeningStructure.Insert("Settings", New FixedArray(New Array));
	EndIf;
	
	OpeningStructure.Insert("RowID",				ID);	
	OpeningStructure.Insert("ChartSettingAddress",	ChartSettingAddress);
	
	OpenForm("DataProcessor.BusinessPulse.Form.ChartSettingForm", OpeningStructure, ThisObject);
	
EndProcedure

&AtServer
Procedure UpdateChartValues()
	
	Data = GetFromTempStorage(BackgroundJobResultAddress);
	
	If Not IsBlankString(Data.Section) Then
		Return;
	EndIf; 
	
	For Each Str In AddedCharts Do
		
		ObjectChart = ThisForm[Str.AttributeName];
		ObjectChart.RefreshEnabled = False;
		ObjectChart.Clear();
		
	EndDo; 
	
	For Each Item In Data.Charts Do
		
		DataArray	= Item.Value;
		Str			= AddedCharts[Item.Key];
		SettingRow	= ChartSettings.FindByID(Str.SettingLineID);
		
		PointDescription	= SettingRow.Points[Str.Point];
		SeriesDescription	= SettingRow.Series[Str.Series];
		ObjectChart			= ThisForm[Str.AttributeName];
		
		Try
			
			ValueTable = New ValueTable;
			ValueTable.Columns.Add("Point");
			ValueTable.Columns.Add("ToCompare");
			ValueTable.Columns.Add("Order");
			ValueTable.Columns.Add("SeriesCount");
			ValueTable.Columns.Add("BaseValue");
			
			CurrentNumberOfSeries = 0;
			
			For Each ValueStructure In DataArray Do
				
				If ValueStructure.SeriesCount > CurrentNumberOfSeries Then
					
					For s = CurrentNumberOfSeries To ValueStructure.SeriesCount Do
						ValueTable.Columns.Add("Series" + (s + 1));
					EndDo;
					
					CurrentNumberOfSeries = ValueStructure.SeriesCount;
					
				EndIf; 
				
				FillPropertyValues(ValueTable.Add(), ValueStructure);
				
			EndDo; 
			
			ValueTable.Sort("Order, ToCompare");
			
			ThereDataToDisplay = Not EmptyChart(ValueTable);
			
			If Not ThereDataToDisplay Then
				FillWithRandomData(ObjectChart, DataArray, PointDescription, SeriesDescription);
			Else
				
				ObjectChart.ShowTitle = False;
				
				For Each ValueStructure In ValueTable Do
					
					If ThisPieChart(SeriesDescription.ChartType) Then
						
						If Not ValueIsFilled(ValueStructure.Point) Then
							Continue;
						EndIf; 
						
						Point	= ObjectChart.SetPoint(Str.SeriesPresentations[0]);
						Series	= ObjectChart.SetSeries(?(Not ValueIsFilled(ValueStructure.Series1), 
									NStr("en = '<empty>'"), 
									ValueStructure.Series1)
						);
						
						ObjectChart.SetValue(Point, Series, ValueStructure.Point);
						
					ElsIf SeriesDescription.ChartType = ChartType.StackedArea Then
						
						If Not IsBlankString(PointDescription.Format) Then
							Point = ObjectChart.SetPoint(Format(ValueStructure.Point, PointDescription.Format));
						Else
							
							Point = ObjectChart.SetPoint(
								?(Not ValueIsFilled(ValueStructure.Point), 
								NStr("en = '<empty>'"), 
								String(ValueStructure.Point))
							);
							
						EndIf;
						
						If ValueIsFilled(ValueStructure.BaseValue) Then
							
							Series			= ObjectChart.SetSeries("BaseValue");
							Series.Text		= "-";
							Series.Color	= StyleColors.ColorChartMissingData;
							
							ObjectChart.SetValue(Point, Series, ValueStructure.BaseValue);
							
						EndIf; 
						
						For s = 1 To ValueStructure.SeriesCount Do
							
							If Not ValueIsFilled(ValueStructure["Series" + s]) Then
								Continue;
							EndIf; 
							
							Series = ObjectChart.SetSeries(Str.SeriesPresentations[s - 1]);
							ObjectChart.SetValue(Point, 
								Series, 
								?(ValueStructure["Series" + s] < 0, -ValueStructure["Series" + s], ValueStructure["Series"+s])
							);
							
						EndDo;
						
					Else
						
						If Not IsBlankString(PointDescription.Format) Then
							Point = ObjectChart.SetPoint(Format(ValueStructure.Point, PointDescription.Format));
						Else
							
							Point = ObjectChart.SetPoint(
								?(Not ValueIsFilled(ValueStructure.Point), 
								NStr("en = '<empty>'"), 
								String(ValueStructure.Point))
							);
							
						EndIf;
						
						If ValueIsFilled(ValueStructure.Series1) AND ValueStructure.ToCompare Then
							
							Series = ObjectChart.SetSeries(Str.SeriesPresentations[1]);
							ObjectChart.SetValue(Point, Series, ValueStructure.Series1);
							
						Else
							
							For s = 1 To ValueStructure.SeriesCount Do
								
								If Not ValueIsFilled(ValueStructure["Series" + s]) Then
									Continue;
								EndIf; 
								
								Series = ObjectChart.SetSeries(Str.SeriesPresentations[s - 1]);
								ObjectChart.SetValue(Point, Series, ValueStructure["Series" + s]);
								
							EndDo;
							
						EndIf; 
						
					EndIf; 
					
				EndDo;
				
			EndIf; 
			
			If Not ThisPieChart(SeriesDescription.ChartType)
				AND ObjectChart.Series.Count() <= 1 Then
				
				ObjectChart.ShowLegend		= False;
				ObjectChart.PlotArea.Right	= 0.99;
				
			ElsIf ThisPieChart(SeriesDescription.ChartType) Then
				
				ObjectChart.ShowLegend		= True;
				ObjectChart.PlotArea.Right	= 0.55;
				ObjectChart.LegendArea.Left = 0.58;
				
			Else
				
				ObjectChart.ShowLegend		= True;
				ObjectChart.PlotArea.Right	= 0.75;
				ObjectChart.LegendArea.Left = 0.78;
				
			EndIf; 
			
			SetChartDisplay(ObjectChart, ThereDataToDisplay);
			ObjectChart.RefreshEnabled = True;
			
		Except
			
			ObjectChart.Clear();
			ObjectChart.RefreshEnabled = True;
			ErrorInfo = ErrorInfo();
			DisplayChartError(ObjectChart, ErrorInfo);
		    
		EndTry;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure DisplayChartError(ObjectChart, ErrorInfo)
	
	ErrorDescription		= BriefErrorDescription(ErrorInfo);
	DetailErrorDescription	= NStr("en = 'Generation error:'")
		+ Chars.LF 
		+ DetailErrorDescription(ErrorInfo);
	
	If IsBlankString(ErrorDescription) Then
		ErrorDescription = DetailErrorDescription;
	EndIf;
	
	ObjectChart.ShowTitle = True;
	ObjectChart.TitleArea.Text = ErrorDescription;
	ObjectChart.TitleArea.TextColor = StyleColors.ColorInvalidInformation;
	
EndProcedure
 
&AtServer
Procedure CreateChartItems()
	
	// Create form attributes
	AttributeArray = New Array;
	
	For Each Str In AddedCharts Do
		
		If Not IsBlankString(Str.AttributeName) Then
			Continue;
		EndIf;
		
		Str.AttributeName = "Chart" + StrReplace(String(New UUID), "-", "");
		AttributeArray.Add(New FormAttribute(Str.AttributeName, New TypeDescription("Chart")));
		
	EndDo;
	
	ChangeAttributes(AttributeArray);
	
	For Each Str In AddedCharts Do
		
		SettingRow			= ChartSettings.FindByID(Str.SettingLineID);
		PointDescription	= SettingRow.Points[Str.Point];
		SeriesDescription	= SettingRow.Series[Str.Series];
		
		If IsBlankString(Str.GroupName) Then
			
			Str.GroupName = "Chart" + StrReplace(String(New UUID), "-", "");
			
			NewGroup						= Items.Add(Str.GroupName, Type("FormGroup"), Items.GroupAddedCharts);
			NewGroup.Type					= FormGroupType.UsualGroup;
			NewGroup.ShowTitle				= False;
			NewGroup.Representation 		= UsualGroupRepresentation.None;
			NewGroup.VerticalStretch		= False;
			NewGroup.Group					= ChildFormItemsGroup.Vertical;
			
			ItemHeader						= Items.Add(Str.GroupName + "_Title", Type("FormDecoration"), NewGroup);
			ItemHeader.Type					= FormDecorationType.Label;
			ItemHeader.HorizontalStretch	= True;
			ItemHeader.HorizontalAlign		= ItemHorizontalLocation.Center;
			ItemHeader.Font					= New Font("Arial", 10, True);
			ItemHeader.VerticalAlign		= ItemVerticalAlign.Bottom;
			ItemHeader.Height				= ?(AddedCharts.IndexOf(Str) = 0, 1, 2);
			
			ItemChart						= Items.Add(Str.GroupName + "_Chart", Type("FormField"), NewGroup);
			ItemChart.Type					= FormFieldType.ChartField;
			ItemChart.TitleLocation		 	= FormItemTitleLocation.None;
			ItemChart.DataPath				= Str.AttributeName;
			ItemChart.Width					= 30;
			ItemChart.Height				= 7;
			
			ItemChart.SetAction("Selection", "Attachable_ChartSelection");
			
			// Context menu
			AddCommand(Str.GroupName, 
				"_Setup", 
				ItemChart, 
				"ContextSetUpChart", 
				NStr("en = 'Chart settings'"), 
				PictureLib.SettingsStorage);
				
			AddCommand(Str.GroupName, 
				"_Delete", 
				ItemChart,
				"ContextDeleteChart",
				NStr("en = 'Remove chart'"),
				PictureLib.Delete);
				
			AddCommand(Str.GroupName,
				"_Up", 
				ItemChart,
				"ContextMoveChartUp", 
				NStr("en = 'Move up'"), 
				PictureLib.MoveUp);
				
			AddCommand(Str.GroupName,
				"_Down",
				ItemChart,
				"ContextMoveChartDown",
				NStr("en = 'Move down'"), 
				PictureLib.MoveDown);
				
			AddCommand(Str.GroupName, 
				"_Decrypt", 
				ItemChart, 
				"ContextDecryptChart", 
				NStr("en = 'Drilldown'"), 
				PictureLib.Find);
			
			// Title context menu
			AddCommand(Str.GroupName, 
				"_Setup", 
				ItemHeader, 
				"ContextSetUpChart", 
				NStr("en = 'Chart settings'"), 
				PictureLib.SettingsStorage);
				
			AddCommand(Str.GroupName, 
				"_Delete", 
				ItemHeader, 
				"ContextDeleteChart", 
				NStr("en = 'Remove chart'"), 
				PictureLib.Delete);
				
			AddCommand(Str.GroupName, 
				"_Up", 
				ItemHeader, 
				"ContextMoveChartUp", 
				NStr("en = 'Move up'"), 
				PictureLib.MoveUp);
				
			AddCommand(Str.GroupName, 
				"_Down", 
				ItemHeader, 
				"ContextMoveChartDown", 
				NStr("en = 'Move down'"), 
				PictureLib.MoveDown);
				
			AddCommand(Str.GroupName, 
				"_Decrypt", 
				ItemHeader,
				"ContextDecryptChart",
				NStr("en = 'Drilldown'"), 
				PictureLib.Find);
			
		Else
			
			NewGroup	= Items[Str.GroupName];
			ItemChart	= Items[Str.GroupName + "_Chart"];
			ItemHeader	= Items[Str.GroupName + "_Title"];
			
		EndIf;
		
		ItemHeader.Title = Upper(Str.Presentation);
		
		ObjectChart						= ThisForm[Str.AttributeName];
		ObjectChart.RefreshEnabled		= False;
		ObjectChart.ChartType			= SeriesDescription.ChartType;
		ObjectChart.ShowTitle			= False;
		ObjectChart.LegendArea.Font 	= New Font(ObjectChart.LegendArea.Font, "Arial", 7);
		ObjectChart.PlotArea.Font		= New Font(ObjectChart.PlotArea.Font, "Arial", 7);
		ObjectChart.PlotArea.Bottom		= 0.99;
		
		If ThisPieChart(SeriesDescription.ChartType) Then
			
			ObjectChart.PlotArea.Right	= 0.55;
			ObjectChart.LegendArea.Left	= 0.58;
			ObjectChart.MaxSeries		= MaxSeries.Limited;
			ObjectChart.MaxSeriesCount	= 10;
			
		ElsIf SeriesDescription.ChartType = ChartType.StackedArea Then
			
			ObjectChart.PlotArea.Right					= 0.75;
			ObjectChart.LegendArea.Left					= 0.78;
			ObjectChart.AutoSeriesText					= False;
			ObjectChart.PlotArea.ShowPointsScaleLabels	= False;
			ObjectChart.PlotArea.ShowScaleValueLines	= False;
			ObjectChart.SplineMode						= ChartSplineMode.SmoothCurve;
			
		Else
			
			ObjectChart.PlotArea.LabelsOrientation = ChartLabelsOrientation.Vertical;
			
			If Not ThisStackedColumnChart(SeriesDescription.ChartType) Then
				ObjectChart.SpaceMode = ChartSpaceMode.None;
			EndIf; 
			
			ObjectChart.PlotArea.ShowScaleValueLines = False;
			
		EndIf;
		
		ObjectChart.Animation		= ChartAnimation.DontUse;		
		ObjectChart.RefreshEnabled	= True;
		
	EndDo; 
	
EndProcedure

&AtClientAtServerNoContext
Function ThisPieChart(Type)
	
	Return (Type = ChartType.Pie OR 
			Type = ChartType.Pie3D);	
	
EndFunction

&AtClientAtServerNoContext
Function ThisStackedColumnChart(Type)
	
	Return (Type = ChartType.StackedColumn OR 
			Type = ChartType.StackedColumn3D);	
	
EndFunction

&AtServer
Procedure FillWithRandomData(ObjectChart, ValueTable, PointDescription, SeriesDescription)
	
	Generator	= New RandomNumberGenerator;
	BasicAmount = 100;
	
	If ValueTable.Count() > 0 Then
		
		For Each ValueStructure In ValueTable Do
			
			ComparisonSuffix = ?(ValueStructure.ToCompare, " (" + NStr("en = 'compare'"), "") + ")";
			
			If Not IsBlankString(PointDescription.Format) Then
				Point = ObjectChart.SetPoint(Format(ValueStructure.Point, PointDescription.Format) + ComparisonSuffix);
			Else
				
				Point = ObjectChart.SetPoint(
					?(Not ValueIsFilled(ValueStructure.Point), 
					NStr("en = '<empty>'") + ComparisonSuffix, 
					String(ValueStructure.Point) + ComparisonSuffix)
				);
				
			EndIf; 
			
			Series = ObjectChart.SetSeries(NStr("en = 'Example 1'"));
			ObjectChart.SetValue(Point, Series, Generator.RandomNumber(0, 100));
			
			If ThisStackedColumnChart(SeriesDescription.ChartType) Then
				Series = ObjectChart.SetSeries(NStr("en = 'Example 2'"));
				ObjectChart.SetValue(Point, Series, Generator.RandomNumber(0, 30));
			EndIf; 
			
		EndDo; 
		
	Else
		
		For s = 1 To 8 Do
			
			If ThisPieChart(SeriesDescription.ChartType) Then
				
				BasicAmount = Round(BasicAmount * (100 - Generator.RandomNumber(0, 30)) / 100, 2);
				Point		= ObjectChart.SetPoint(NStr("en = 'Total'"));
				Series		= ObjectChart.SetSeries(NStr("en = 'Example'") + " " + s);
				
				ObjectChart.SetValue(Point, Series, BasicAmount);
				
			Else
				
				Point	= ObjectChart.SetPoint(NStr("en = 'Example'") + " " + s);
				Series	= ObjectChart.SetSeries(NStr("en = 'Example 1'"));
				ObjectChart.SetValue(Point, Series, Generator.RandomNumber(0, 100));
				
				If ThisStackedColumnChart(SeriesDescription.ChartType) Then
					
					Series = ObjectChart.SetSeries(NStr("en = 'Example 2'"));
					ObjectChart.SetValue(Point, Series, Generator.RandomNumber(0, 30));
					
				EndIf; 
				
			EndIf;
			
		EndDo;
		
	EndIf; 
	
	ObjectChart.ShowTitle			= True;
	ObjectChart.TitleArea.Text		= NStr("en = 'EXAMPLE'");
	ObjectChart.TitleArea.TextColor	= StyleColors.BorderColor;
	ObjectChart.TitleArea.Font		= New Font("Arial", 18, True);
			
EndProcedure

&AtServer
Function EmptyChart(Data)
	
	For Each Str In Data Do
		
		If TypeOf(Str.Point) = Type("Number") AND ValueIsFilled(Str.Point) Then
			Return False;
		EndIf; 
		
		For s = 1 To Str.SeriesCount Do
			
			If TypeOf(Str["Series" + s]) = Type("Number") AND ValueIsFilled(Str["Series" + s]) Then
				Return False;
			EndIf;
			
		EndDo; 
		
	EndDo; 
	
	Return True;
	
EndFunction

// Chart post-processing. Sets series colors and line width
//
// Parameters:
//  Chart - chart - processed
//  chart ThereDataToDisplay - Boolean - shows whether
//  there				is/is not SeriesColors data - array - color array according to which colors are assigned. If it is not specified, they are assigned by default
&AtServerNoContext
Procedure SetChartDisplay(Chart, ThereDataToDisplay, SeriesColors = Undefined)
	
	Chart.Border					= New Border(ControlBorderType.WIthoutBorder, 0);
	Chart.BorderColor				= StyleColors.FormBackColor;
	Chart.TitleArea.Transparent		= True;
	Chart.PlotArea.Transparent		= True;
	Chart.LegendArea.Transparent	= True;
	
	Chart.PlotArea.BorderColor		= StyleColors.FormBackColor;
	Chart.LegendArea.BorderColor	= StyleColors.FormBackColor;
	Chart.TitleArea.BorderColor		= StyleColors.FormBackColor;
		
	If SeriesColors = Undefined Then
		SeriesColors = DriveClientServer.ChartSeriesColors();
	EndIf;
	
	Chart.SummarySeries.Color	= StyleColors.ColorChartMissingData;
	Chart.SummarySeries.Text	= NStr("en = 'Others'");
	
	// If there are fewer points on the chart, draw series using thick line; if there are more - then use thin line
	MaxChartPointsWithThickLine = 10;
	
	ThinLine	= New Line(ChartLineType.Solid, 1);
	ThickLine	= New Line(ChartLineType.Solid, 2);
	
	For SeriesIndex = 0 To Chart.Series.Count() - 1 Do
		
		Series = Chart.Series[SeriesIndex];
		
		If Series.Color = StyleColors.ColorChartMissingData Then
			Continue;
		EndIf; 
		
		If ThereDataToDisplay AND SeriesIndex < SeriesColors.Count() Then
			Series.Color = SeriesColors[SeriesIndex];
		ElsIf Not ThereDataToDisplay AND SeriesIndex < SeriesColors.Count() Then
			
			BasicColor = SeriesColors[SeriesIndex];
			
			SeriesColor = New Color(
				BasicColor.R + (255 - BasicColor.R) / 2,
				BasicColor.G + (255 - BasicColor.G) / 2,
				BasicColor.B + (255 - BasicColor.B) / 2
			);
			
			Series.Color = SeriesColor;
			
		Else
			Series.Color = StyleColors.ColorChartMissingData;
		EndIf;
		
		If Chart.Points.Count() > MaxChartPointsWithThickLine Then
			Series.Line = ThinLine;
		Else
			Series.Line = ThickLine;
		EndIf;
		
	EndDo;
	
	Chart.TitleArea.Left		= 0;
	Chart.TitleArea.Right		= 1;
	Chart.TitleArea.Top			= 0;
	Chart.TitleArea.Bottom		= 1;
	Chart.PlotArea.Top			= 0.01;
	Chart.LegendArea.Top		= 0.01;
	Chart.LegendArea.Scrolling	= (Chart.Series.Count() > 5);
		
EndProcedure

&AtClient
Procedure DecryptChart(ID)
	
	CurPage = AddedCharts.FindByID(ID);
	
	SettingPage = ChartSettings.FindByID(CurPage.SettingLineID);
	
	If Not ValueIsFilled(SettingPage.Variant) Then
		Return;
	EndIf;
	
	DecryptionFilter = New Map;
	
	If SettingPage.Balance Then
		
		If TypeOf(CurPage.Period) = Type("StandardBeginningDate") Then
			DecryptionPeriod = BegOfDay(CurPage.Period.Date) - 1;
		ElsIf TypeOf(CurPage.Period) = Type("StandardBeginningDate") Then			
			UpdateDate(CurPage.Period);
			DecryptionPeriod = BegOfDay(CurPage.Period.Date) - 1;			
		Else
			DecryptionPeriod = '0001-01-01';
		EndIf;
		
		DecryptionFilter.Insert("BeginOfPeriod",	BegOfDay(DecryptionPeriod));
		DecryptionFilter.Insert("Period",			DecryptionPeriod);
		DecryptionFilter.Insert("EndOfPeriod",		DecryptionPeriod);
		
	Else
		
		If TypeOf(CurPage.Period) = Type("StandardPeriod") Then			
			DecryptionStartDate = BegOfDay(CurPage.Period.StartDate);
			DecryptionEndDate	= ?(ValueIsFilled(CurPage.Period.EndDate), EndOfDay(CurPage.Period.EndDate), '0001-01-01');		
		ElsIf TypeOf(CurPage.Period) = Type("Structure") Then		
			
			UpdatePeriodStartAndEndDates(CurPage.Period);
			
			DecryptionStartDate = BegOfDay(CurPage.Period.StartDate);
			DecryptionEndDate	= ?(ValueIsFilled(CurPage.Period.EndDate), EndOfDay(CurPage.Period.EndDate), '0001-01-01');	
		Else
			DecryptionStartDate = '0001-01-01';
			DecryptionEndDate	= '0001-01-01';			
		EndIf; 
		
		DecryptionFilter.Insert("BeginOfPeriod",	DecryptionStartDate);
		DecryptionFilter.Insert("EndOfPeriod",		DecryptionEndDate);
		
	EndIf;
	
	If TypeOf(CurPage.Filters) = Type("FixedArray") Then
		
		For Each Filter In CurPage.Filters Do
			
			ValueStructure = New Structure;
			ValueStructure.Insert("ComparisonType", Filter.ComparisonType);
			ValueStructure.Insert("Value",			Filter.Value);
			
			DecryptionFilter.Insert(Filter.Field, ValueStructure);
			
		EndDo;
		
	EndIf;
	
	FormParameters = New Structure;
	FormParameters.Insert("GenerateOnOpen",		True);
	FormParameters.Insert("DecryptionFilter",	DecryptionFilter);
	
	ReportsVariantsClient.OpenReportForm(ThisForm, SettingPage.Variant, FormParameters);
	
EndProcedure

&AtServer
Procedure SaveChartSettingServer()
	
	SaveSettings("Charts");
	CreateChartItems();
	RunBackgroundJobOnServer();
	
EndProcedure

#EndRegion 

#Region Periods

&AtClientAtServerNoContext
Function StandardPeriodPresentation(Period, PeriodBasis = Undefined)
	
	If TypeOf(Period) = Type("Structure") Then
		UpdatePeriodStartAndEndDates(Period, PeriodBasis);
	EndIf; 
	
	If Not ValueIsFilled(Period) Then
		Return NStr("en = 'Not selected'");
	ElsIf Period.Variant = StandardPeriodVariant.Custom Then
		
		If Not ValueIsFilled(Period.StartDate) Then
			Return StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'to %1'"),
				Format(Period.EndDate, "DLF=D"));
		ElsIf Not ValueIsFilled(Period.EndDate) Then
			Return StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'from %1'"),
				Format(Period.StartDate, "DLF=D"));
		Else
			
			Return PeriodPresentation(BegOfDay(Period.StartDate), 
				?(ValueIsFilled(Period.EndDate), 
				EndOfDay(Period.EndDate), 
				Period.EndDate)
				);
				
		EndIf;
		
	ElsIf Period.Variant = "PreviousFloatingPeriod" Then
		
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Previous period (%1)'"),
			PeriodPresentation(BegOfDay(Period.StartDate), EndOfDay(Period.EndDate)));
		
	ElsIf Period.Variant = "ForLastYear" Then
		
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Last year (%1)'"),
			PeriodPresentation(BegOfDay(Period.StartDate), EndOfDay(Period.EndDate)));
		
	ElsIf Period.Variant = "Last7DaysExceptForCurrentDay" Then
		Return NStr("en = 'Last 7 days except today'");
	Else
		Return String(Period);
	EndIf; 
	
EndFunction

&AtClientAtServerNoContext
Function StandardStartDatePresentation(Date, ComparisonDate = Undefined)
	
	If TypeOf(Date) = Type("Structure") Then
		UpdateDate(Date, ComparisonDate);
	EndIf; 
	
	If Not ValueIsFilled(Date) Then
		Return NStr("en = 'Not selected'");
	ElsIf Date.Variant = StandardBeginningDateVariant.Custom Then
		Return Format(Date.Date, "DLF=D");
	ElsIf Date.Variant = StandardBeginningDateVariant.BeginningOfThisDay Then
		Return NStr("en = 'Today, beginning of the day'");
	ElsIf Date.Variant = StandardBeginningDateVariant.BeginningOfNextDay Then
		Return NStr("en = 'Today, end of the day'");
	ElsIf Date.Variant = "SameDayLastWeek" Then
		
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Same day last week (%1, %2)'"),
			Format(Date.Date, "DLF=D"),
			Format(Date.Date, "DF=ddd"));
			
	ElsIf Date.Variant = "SameDayLastMonth" Then
		
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Same day last month (%1, %2)'"),
			Format(Date.Date, "DLF=D"),
			Format(Date.Date, "DF=ddd"));
			
	ElsIf Date.Variant = "SameDayLastYear" Then
			
		Return StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Same day last year (%1)'"),
			Format(Date.Date, "DLF=D"));
		
	Else
		Return String(Date);
	EndIf; 
	
EndFunction

&AtClientAtServerNoContext
Function PreviousDate(Val StandardDate, DateType)
	
	If IsBlankString(DateType) OR DateType = "Day" Then
		StandardDate.Date = StandardDate.Date - 3600 * 24;
	ElsIf DateType = "Week" Then
		StandardDate.Date = StandardDate.Date - 3600 * 24 * 7;
	ElsIf DateType = "Decade" Then
		StandardDate.Date = StandardDate.Date - 3600 * 24 * 10;
	ElsIf DateType = "Month" Then
		StandardDate.Date = AddMonth(StandardDate.Date, -1);
	ElsIf DateType = "Quarter" Then
		StandardDate.Date = AddMonth(StandardDate.Date, -3);
	ElsIf DateType = "HalfYear" Then
		StandardDate.Date = AddMonth(StandardDate.Date, -6);
	ElsIf DateType = "Year" Then
		StandardDate.Date = AddMonth(StandardDate.Date, -12);
	EndIf; 	
	
	Return StandardDate;
	
EndFunction

&AtClientAtServerNoContext
Function NextDate(Val StandardDate, DateType)
	
	If IsBlankString(DateType) OR DateType = "Day" Then
		StandardDate.Date = StandardDate.Date + 3600 * 24;
	ElsIf DateType = "Week" Then
		StandardDate.Date = StandardDate.Date + 3600 * 24 * 7;
	ElsIf DateType = "Decade" Then
		StandardDate.Date = StandardDate.Date + 3600 * 24 * 10;
	ElsIf DateType = "Month" Then
		StandardDate.Date = AddMonth(StandardDate.Date, 1);
	ElsIf DateType = "Quarter" Then
		StandardDate.Date = AddMonth(StandardDate.Date, 3);
	ElsIf DateType = "HalfYear" Then
		StandardDate.Date = AddMonth(StandardDate.Date, 6);
	ElsIf DateType = "Year" Then
		StandardDate.Date = AddMonth(StandardDate.Date, 12);
	EndIf; 	
	
	Return StandardDate;
	
EndFunction

&AtClientAtServerNoContext
Function PreviousPeriod(Val StandardPeriod, PeriodType)
	
	If TypeOf(StandardPeriod) = Type("Structure") Then
		UpdatePeriodStartAndEndDates(StandardPeriod);
	EndIf; 
	
	If IsBlankString(PeriodType) Then
		
		DayCount = (BegOfDay(StandardPeriod.EndDate) - BegOfDay(StandardPeriod.StartDate)) / 86400 + 1;
		
		Result = New StandardPeriod(
			BegOfDay(StandardPeriod.StartDate) - DayCount * 86400,
			BegOfDay(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "Day" Then 
		
		Result = New StandardPeriod(
			BegOfDay(StandardPeriod.StartDate) - 86400,
			BegOfDay(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "Week" Then 
		
		Result = New StandardPeriod(
			BegOfWeek(BegOfWeek(StandardPeriod.StartDate) - 1),
			BegOfWeek(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "Decade" Then 
		
		Result = New StandardPeriod(
			BegOfTenDays(StandardPeriod.StartDate - 10 * 86400),
			BegOfTenDays(StandardPeriod.StartDate) - 1
		);
	ElsIf PeriodType = "Month" Then
		
		Result = New StandardPeriod(
			BegOfMonth(AddMonth(StandardPeriod.StartDate, -1)),
			EndOfMonth(AddMonth(StandardPeriod.StartDate, -1))
		);
		
	ElsIf PeriodType = "Quarter" Then 
		
		Result = New StandardPeriod(
			BegOfQuarter(AddMonth(StandardPeriod.StartDate, -3)),
			EndOfQuarter(AddMonth(StandardPeriod.StartDate, -3))
		);
		
	ElsIf PeriodType = "HalfYear" Then 
		
		Result = New StandardPeriod(
			BegOfHalfYear(AddMonth(StandardPeriod.StartDate, -6)),
			EndOfHalfYear(AddMonth(StandardPeriod.StartDate, -6))
		);
		
	ElsIf PeriodType = "Year" Then 
		
		Result = New StandardPeriod(
			BegOfYear(AddMonth(StandardPeriod.StartDate, -12)),
			EndOfYear(AddMonth(StandardPeriod.StartDate, -12))
		);
		
	ElsIf PeriodType = "TillWeekEnd" Then 
		
		Result = New StandardPeriod(
			StandardPeriod.StartDate - 7 * 86400,
			BegOfWeek(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "FromBeginningOfWeek" Then
		
		Result = New StandardPeriod(
			BegOfWeek(BegOfWeek(StandardPeriod.StartDate) - 1),
			StandardPeriod.EndDate - 7 * 86400
		);
		
	ElsIf PeriodType = "UntilEndOfTenDayPeriod" Then
		
		TenDayPeriodDay	= TenDayPeriodDay(StandardPeriod.StartDate);
		BegOfTenDays	= BegOfTenDays(BegOfTenDays(StandardPeriod.StartDate) - 1);
		StartDate		= BegOfTenDays+(TenDayPeriodDay - 1) * 86400;
		
		If BegOfTenDays(StartDate) <> BegOfTenDays Then
			StartDate = BegOfDay(EndOfTenDays(BegOfTenDays));
		EndIf; 
		
		Result = New StandardPeriod(
			StartDate,
			BegOfTenDays(BegOfTenDays)
		);
		
	ElsIf PeriodType = "FromBeginningOfTenDayPeriod" Then 
		
		TenDayPeriodDay = TenDayPeriodDay(StandardPeriod.EndDate);
		BegOfTenDays	= BegOfTenDays(BegOfTenDays(StandardPeriod.StartDate) - 1);
		EndDate			= EndOfDay(BegOfTenDays + (TenDayPeriodDay - 1) * 86400);
		
		If BegOfTenDays(EndDate) <> BegOfTenDays Then
			EndDate = EndOfTenDays(BegOfTenDays);
		EndIf; 
		
		Result = New StandardPeriod(
			BegOfTenDays,
			EndDate
		);
		
	ElsIf PeriodType = "TillMonthEnd" Then 
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, -1),
			BegOfMonth(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "FromBeginningOfMonth" Then 
		
		Result = New StandardPeriod(
			BegOfMonth(BegOfMonth(StandardPeriod.StartDate) - 1),
			AddMonth(StandardPeriod.EndDate, -1)
		);
		
	ElsIf PeriodType = "UntilEndOfQuarter" Then 
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, -3),
			BegOfQuarter(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "FromBeginningOfQuarter" Then
		
		Result = New StandardPeriod(
			BegOfQuarter(BegOfQuarter(StandardPeriod.StartDate) - 1),
			AddMonth(StandardPeriod.EndDate, -3)
		);
		
	ElsIf PeriodType = "UntilEndOfHalfYear" Then
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, -6),
			BegOfHalfYear(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "FromBeginningOfHalfYear" Then
		
		Result = New StandardPeriod(
			BegOfHalfYear(BegOfHalfYear(StandardPeriod.StartDate) - 1),
			AddMonth(StandardPeriod.EndDate, -6)
		);
		
	ElsIf PeriodType = "TillYearEnd" Then
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, -12),
			BegOfYear(StandardPeriod.StartDate) - 1
		);
		
	ElsIf PeriodType = "FromYearStart" Then
		
		Result = New StandardPeriod(
			BegOfYear(BegOfYear(StandardPeriod.StartDate) - 1),
			AddMonth(StandardPeriod.EndDate, -12)
		);
		
	ElsIf PeriodType = "ForLastYear" Then
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, -12),
			AddMonth(StandardPeriod.EndDate, -12)
		);
		
	EndIf; 	 	
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function NextPeriod(Val StandardPeriod, PeriodType)
	
	If TypeOf(StandardPeriod) = Type("Structure") Then
		UpdatePeriodStartAndEndDates(StandardPeriod);
	EndIf; 
	
	If IsBlankString(PeriodType) Then
		
		DayCount = (BegOfDay(StandardPeriod.EndDate) - BegOfDay(StandardPeriod.StartDate)) / 86400 + 1;
		Result = New StandardPeriod(
			EndOfDay(StandardPeriod.EndDate) + 1,
			EndOfDay(StandardPeriod.EndDate) + DayCount * 86400
		);
		
	ElsIf PeriodType = "Day" Then 
		
		Result = New StandardPeriod(
			EndOfDay(StandardPeriod.EndDate) + 1,
			EndOfDay(StandardPeriod.EndDate) + 86400
		);
		
	ElsIf PeriodType = "Week" Then 
		
		Result = New StandardPeriod(
			EndOfWeek(StandardPeriod.EndDate) + 1,
			EndOfWeek(EndOfWeek(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "Decade" Then 
		
		Result = New StandardPeriod(
			EndOfTenDays(StandardPeriod.EndDate) + 1,
			EndOfTenDays(EndOfTenDays(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "Month" Then 
		
		Result = New StandardPeriod(
			BegOfMonth(AddMonth(StandardPeriod.EndDate, 1)),
			EndOfMonth(AddMonth(StandardPeriod.EndDate, 1))
		);
		
	ElsIf PeriodType = "Quarter" Then 
		
		Result = New StandardPeriod(
			BegOfQuarter(AddMonth(StandardPeriod.EndDate, 3)),
			EndOfQuarter(AddMonth(StandardPeriod.EndDate, 3))
		);
		
	ElsIf PeriodType = "HalfYear" Then 
		
		Result = New StandardPeriod(
			BegOfHalfYear(AddMonth(StandardPeriod.EndDate, 6)),
			EndOfHalfYear(AddMonth(StandardPeriod.EndDate, 6))
		);
		
	ElsIf PeriodType = "Year" Then 
		
		Result = New StandardPeriod(
			BegOfYear(AddMonth(StandardPeriod.EndDate, 12)),
			EndOfYear(AddMonth(StandardPeriod.EndDate, 12))
		);
		
	ElsIf PeriodType = "TillWeekEnd" Then 
		
		Result = New StandardPeriod(
			StandardPeriod.StartDate + 7 * 86400,
			EndOfWeek(EndOfWeek(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "FromBeginningOfWeek" Then 
		
		Result = New StandardPeriod(
			EndOfWeek(StandardPeriod.EndDate) + 1,
			StandardPeriod.EndDate + 7 * 86400
		);
		
	ElsIf PeriodType="UntilEndOfTenDayPeriod" Then
		
		TenDayPeriodDay = TenDayPeriodDay(StandardPeriod.StartDate);
		BegOfTenDays	= EndOfTenDays(StandardPeriod.EndDate) + 1;
		StartDate		= BegOfTenDays + (TenDayPeriodDay - 1) * 86400;
		
		If BegOfTenDays(StartDate) <> BegOfTenDays(BegOfTenDays) Then
			StartDate = BegOfDay(EndOfTenDays(BegOfTenDays));
		EndIf; 
		
		Result = New StandardPeriod(
			StartDate,
			EndOfTenDays(BegOfTenDays)
		);
		
	ElsIf PeriodType = "FromBeginningOfTenDayPeriod" Then 
		
		TenDayPeriodDay = TenDayPeriodDay(StandardPeriod.EndDate);
		BegOfTenDays	= EndOfTenDays(StandardPeriod.EndDate) + 1;
		EndDate			= EndOfDay(BegOfTenDays + (TenDayPeriodDay - 1 ) * 86400);
		
		If BegOfTenDays(EndDate) <> BegOfTenDays(BegOfTenDays) Then
			EndDate = EndOfTenDays(BegOfTenDays);
		EndIf; 
		
		Result = New StandardPeriod(
			BegOfTenDays,
			EndDate
		);
		
	ElsIf PeriodType = "TillMonthEnd" Then 
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, 1),
			EndOfMonth(EndOfMonth(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "FromBeginningOfMonth" Then 
		
		Result = New StandardPeriod(
			EndOfMonth(StandardPeriod.StartDate) + 1,
			AddMonth(StandardPeriod.EndDate, 1)
		);
		
	ElsIf PeriodType = "UntilEndOfQuarter" Then
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, 3),
			EndOfQuarter(EndOfQuarter(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "FromBeginningOfQuarter" Then
		
		Result = New StandardPeriod(
			EndOfQuarter(StandardPeriod.EndDate) + 1,
			AddMonth(StandardPeriod.EndDate, 3)
		);
		
	ElsIf PeriodType = "UntilEndOfHalfYear" Then
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, 6),
			EndOfHalfYear(EndOfHalfYear(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "FromBeginningOfHalfYear" Then
		
		Result = New StandardPeriod(
			EndOfHalfYear(StandardPeriod.EndDate) + 1,
			AddMonth(StandardPeriod.EndDate, 6)
		);
		
	ElsIf PeriodType = "TillYearEnd" Then 
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, 12),
			EndOfYear(EndOfYear(StandardPeriod.EndDate) + 1)
		);
		
	ElsIf PeriodType = "FromYearStart" Then
		
		Result = New StandardPeriod(
			EndOfYear(StandardPeriod.EndDate) + 1,
			AddMonth(StandardPeriod.EndDate, 12)
		);
		
	ElsIf PeriodType = "ForLastYear" Then 
		
		Result = New StandardPeriod(
			AddMonth(StandardPeriod.StartDate, 12),
			AddMonth(StandardPeriod.EndDate, 12)
		);
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Procedure UpdatePeriodStartAndEndDates(StandardPeriod, PeriodBasis = Undefined)

	If Not TypeOf(StandardPeriod) = Type("Structure") Then
		Return;
	EndIf; 
	
	If StandardPeriod.Variant = "Last7DaysExceptForCurrentDay" Then
		
		StandardPeriod.Insert("StartDate", BegOfDay(CurrentDate()) - 86400 * 7);
		StandardPeriod.Insert("EndDate", BegOfDay(CurrentDate()) - 1);
		
	ElsIf StandardPeriod.Variant = "ForLastYear" AND PeriodBasis <> Undefined Then
		
		Period = DriveClientServer.SamePeriodOfLastYear(PeriodBasis);
		StandardPeriod.Insert("StartDate",	Period.StartDate);
		StandardPeriod.Insert("EndDate",	Period.EndDate);
		
	ElsIf StandardPeriod.Variant = "PreviousFloatingPeriod" AND PeriodBasis <> Undefined Then
		
		Period = DriveClientServer.PreviousFloatingPeriod(PeriodBasis);
		StandardPeriod.Insert("StartDate",	Period.StartDate);
		StandardPeriod.Insert("EndDate",	Period.EndDate);
		
	EndIf; 	
	
EndProcedure

&AtClientAtServerNoContext
Procedure UpdateDate(StandardDate, ComparisonDate = Undefined)

	If Not TypeOf(StandardDate) = Type("Structure") Then
		Return;
	EndIf; 
	If StandardDate.Variant = "SameDayLastWeek" Then
		StandardDate.Insert("Date", BegOfDay(CurrentDate()) - 86400 * 7);
	ElsIf StandardDate.Variant = "SameDayLastMonth" Then
		StandardDate.Insert("Date", AddMonth(BegOfDay(CurrentDate()), -1));
	ElsIf StandardDate.Variant = "SameDayLastYear" Then
		StandardDate.Insert("Date", AddMonth(BegOfDay(CurrentDate()), -12));
	EndIf; 	
	
EndProcedure

// Returns the beginning of a ten-day period for the specified date
//
// Parameters:
//    ParameterDate - Date - Date of determining the beginning of a ten-day period
//
// Returns: 
//    *Date - Date of
// the beginning of a ten-day period
&AtServerNoContext
Function BegOfTenDays(ParameterDate)
	
	If TypeOf(ParameterDate) <> Type("Date") Then
		Return Undefined;
	EndIf;
	
	If Day(ParameterDate) < 11 Then
		Return Date(Year(ParameterDate), Month(ParameterDate), 1);
	EndIf;
	
	If Day(ParameterDate) < 21 Then
		Return Date(Year(ParameterDate), Month(ParameterDate), 11);
	EndIf;
	
	Return Date(Year(ParameterDate), Month(ParameterDate), 21);
	
EndFunction

// Returns ten-day period end for the specified date
//
// Parameters:
//    ParameterDate - Date - Date of determining the ten-day period end
//
// Returns: 
//    *Date - Date of
// the ten-day period end
&AtServerNoContext
Function EndOfTenDays(ParameterDate)
	
	If TypeOf(ParameterDate) <> Type("Date") Then
		Return Undefined;
	EndIf;
	
	If Day(ParameterDate) >= 21 Then
		Return EndOfMonth(ParameterDate);
	EndIf;
	
	If Day(ParameterDate) >= 11 Then
		Return EndOfDay(Date(Year(ParameterDate), Month(ParameterDate), 20));
	EndIf;
	
	Return EndOfDay(Date(Year(ParameterDate), Month(ParameterDate), 10));
	
EndFunction

// Returns a number of ten-day period day for the specified date
//
// Parameters:
//    ParameterDate - Date - Date of determining the beginning of a ten-day period
//
// Returns: 
//    * Number - Number of
// ten-day period day
&AtServerNoContext
Function TenDayPeriodDay(ParameterDate)
	
	If TypeOf(ParameterDate) <> Type("Date") Then
		Return Undefined;
	EndIf;
	
	Day = Day(ParameterDate);
	If Day = 31 Then
		Return 11;
	EndIf; 
	
	TenDayPeriodDay = Day % 10;
	If TenDayPeriodDay = 0 Then
		TenDayPeriodDay = 10;
	EndIf; 
	
	Return TenDayPeriodDay;
	
EndFunction

// Returns half-year periods of a ten-day period for the specified date
//
// Parameters:
//    ParameterDate - Date - Date of determining the beginning of a half-year period
//
// Returns: 
//    *Date - Half-year
// start date
&AtServerNoContext
Function BegOfHalfYear(ParameterDate)
	
	If TypeOf(ParameterDate) <> Type("Date") Then
		Return Undefined;
	EndIf;
	
	If Month(ParameterDate) < 7 Then
		Return BegOfYear(ParameterDate);
	Else
		Return AddMonth(BegOfYear(ParameterDate), 7);
	EndIf;
	
EndFunction

// Returns half-year end for the specified date
//
// Parameters:
//    ParameterDate - Date - Date of determining the end of a half-year period
//
// Returns: 
//    *Date - Half-year
// end date
&AtServerNoContext
Function EndOfHalfYear(ParameterDate)
	
	If TypeOf(ParameterDate) <> Type("Date") Then
		Return Undefined;
	EndIf;
	
	If Month(ParameterDate) < 7 Then
		Return EndOfMonth(AddMonth(BegOfYear(ParameterDate), 6));
	Else
		Return EndOfYear(ParameterDate);
	EndIf;
	
EndFunction

&AtClientAtServerNoContext
Function DateType(Val StandardDate)
	
	If StandardDate = Undefined 
		OR StandardDate.Variant = StandardBeginningDateVariant.Custom Then
		
		Return "";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisDay
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastDay
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextDay Then
		
		Return "Day";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisWeek
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastWeek
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextDay
		OR StandardDate.Variant = "SameDayLastWeek" Then
		
		Return "Week";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisTenDays
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastTenDays
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextTenDays Then
		
		Return "Decade";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisMonth
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastMonth
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextMonth
		OR StandardDate.Variant = "SameDayLastMonth" Then
		
		Return "Month";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisQuarter
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastQuarter
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextQuarter Then
		
		Return "Quarter";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisHalfYear
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastHalfYear
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextHalfYear Then
		
		Return "HalfYear";
		
	ElsIf StandardDate.Variant = StandardBeginningDateVariant.BeginningOfThisYear
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfLastYear
		OR StandardDate.Variant = StandardBeginningDateVariant.BeginningOfNextYear
		OR StandardDate.Variant = "SameDayLastYear" Then
		
		Return "Year";
		
	EndIf; 	
	
EndFunction

&AtClientAtServerNoContext
Function PeriodType(StandardPeriod)
	
	If StandardPeriod = Undefined
		OR StandardPeriod.Variant = StandardPeriodVariant.Last7Days
		OR StandardPeriod.Variant = StandardPeriodVariant.Next7Days
		OR StandardPeriod.Variant = "Last7DaysExceptForCurrentDay"
		OR StandardPeriod.Variant = "PreviousFloatingPeriod" Then
		
		Return "";
		
	ElsIf StandardPeriod.Variant="ForLastYear" Then
		Return "ForLastYear";
	ElsIf BegOfWeek(StandardPeriod.StartDate) = BegOfWeek(StandardPeriod.EndDate) AND
		BegOfWeek(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfWeek(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary week is selected as a period
		Return "Week";
		
	ElsIf BegOfMonth(StandardPeriod.StartDate) = BegOfMonth(StandardPeriod.EndDate) AND
		BegOfMonth(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfMonth(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary month is selected as a period
		Return "Month";
		
	ElsIf BegOfQuarter(StandardPeriod.StartDate) = BegOfQuarter(StandardPeriod.EndDate) AND
		BegOfQuarter(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfQuarter(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary quarter is selected as a period
		Return "Quarter";
		
	ElsIf BegOfHalfYear(StandardPeriod.StartDate) = BegOfHalfYear(StandardPeriod.EndDate) AND
		BegOfHalfYear(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfHalfYear(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary half-year is selected as a period
		Return "HalfYear";
		
	ElsIf BegOfYear(StandardPeriod.StartDate) = BegOfYear(StandardPeriod.EndDate) AND
		BegOfYear(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfYear(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary year is selected as a period
		Return "Year";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.Custom Then
		Return "";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.Yesterday
		OR StandardPeriod.Variant = StandardPeriodVariant.Today
		OR StandardPeriod.Variant = StandardPeriodVariant.Tomorrow Then
		
		Return "Day";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.LastWeek
		OR StandardPeriod.Variant = StandardPeriodVariant.NextWeek
		OR StandardPeriod.Variant = StandardPeriodVariant.ThisWeek Then
		
		Return "Week";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisWeek Then
		Return "TillWeekEnd";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisWeek
		OR StandardPeriod.Variant = StandardPeriodVariant.LastWeekTillSameWeekDay
		OR StandardPeriod.Variant = StandardPeriodVariant.NextWeekTillSameWeekDay Then
		
		Return "FromBeginningOfWeek";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.LastTenDays
		OR StandardPeriod.Variant = StandardPeriodVariant.NextTenDays
		OR StandardPeriod.Variant = StandardPeriodVariant.ThisTenDays Then
		
		Return "Decade";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisTenDays Then
		Return "UntilEndOfTenDayPeriod";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisTenDays
		OR StandardPeriod.Variant = StandardPeriodVariant.LastTenDaysTillSameDayNumber
		OR StandardPeriod.Variant = StandardPeriodVariant.NextTenDaysTillSameDayNumber Then
		
		Return "FromBeginningOfTenDayPeriod";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.LastMonth
		OR StandardPeriod.Variant = StandardPeriodVariant.NextMonth
		OR StandardPeriod.Variant = StandardPeriodVariant.ThisMonth Then
		
		Return "Month";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisMonth Then
		Return "TillMonthEnd";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisMonth
		OR StandardPeriod.Variant = StandardPeriodVariant.LastMonthTillSameDate
		OR StandardPeriod.Variant = StandardPeriodVariant.NextMonthTillSameDate Then
		
		Return "FromBeginningOfMonth";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.LastQuarter
		OR StandardPeriod.Variant = StandardPeriodVariant.NextQuarter
		OR StandardPeriod.Variant = StandardPeriodVariant.ThisQuarter Then
		
		Return "Quarter";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisQuarter Then
		Return "UntilEndOfQuarter";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisQuarter
		OR StandardPeriod.Variant = StandardPeriodVariant.LastQuarterTillSameDate
		OR StandardPeriod.Variant = StandardPeriodVariant.NextQuarterTillSameDate Then
		
		Return "FromBeginningOfQuarter";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.LastHalfYear
		OR StandardPeriod.Variant = StandardPeriodVariant.NextHalfYear
		OR StandardPeriod.Variant = StandardPeriodVariant.ThisHalfYear Then
		
		Return "HalfYear";
		
	ElsIf StandardPeriod.Variant=StandardPeriodVariant.TillEndOfThisHalfYear Then
		Return "UntilEndOfHalfYear";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisHalfYear
		OR StandardPeriod.Variant = StandardPeriodVariant.LastHalfYearTillSameDate
		OR StandardPeriod.Variant = StandardPeriodVariant.NextHalfYearTillSameDate Then
		
		Return "FromBeginningOfHalfYear";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.LastYear
		OR StandardPeriod.Variant = StandardPeriodVariant.NextYear
		OR StandardPeriod.Variant = StandardPeriodVariant.ThisYear Then
		
		Return "Year";
		
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.TillEndOfThisYear Then
		Return "TillYearEnd";
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.FromBeginningOfThisYear
		OR StandardPeriod.Variant = StandardPeriodVariant.LastYearTillSameDate
		OR StandardPeriod.Variant = StandardPeriodVariant.NextYearTillSameDate Then
		
		Return "FromYearStart";
		
	EndIf; 	
	
EndFunction

&AtClientAtServerNoContext
Function ComparisonPeriodByPeriod(StandardPeriod)
	
	If TypeOf(StandardPeriod) = Type("Structure") Then
		UpdatePeriodStartAndEndDates(StandardPeriod);
	EndIf; 
	
	If TypeOf(StandardPeriod) = Type("Structure") AND StandardPeriod.Variant = "Last7DaysExceptForCurrentDay" Then
		
		Result = New Structure;
		Result.Insert("Variant",	"PreviousFloatingPeriod");
		
		PreviousPeriod = DriveClientServer.PreviousFloatingPeriod(StandardPeriod);
		Result.Insert("StartDate",	PreviousPeriod.StartDate);
		Result.Insert("EndDate",	PreviousPeriod.EndDate);
		
		Return Result;
		
	ElsIf Not TypeOf(StandardPeriod) = Type("StandardPeriod") Then
		Return New StandardPeriod(StandardPeriodVariant.LastMonth);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.Today Then
		Return New StandardPeriod(StandardPeriodVariant.Yesterday);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisWeek Then
		Return New StandardPeriod(StandardPeriodVariant.LastWeekTillSameWeekDay);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisTenDays Then
		Return New StandardPeriod(StandardPeriodVariant.LastTenDaysTillSameDayNumber);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisMonth Then
		Return New StandardPeriod(StandardPeriodVariant.LastMonthTillSameDate);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisQuarter Then
		Return New StandardPeriod(StandardPeriodVariant.LastQuarterTillSameDate);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisHalfYear Then
		Return New StandardPeriod(StandardPeriodVariant.LastHalfYearTillSameDate);
	ElsIf StandardPeriod.Variant = StandardPeriodVariant.ThisYear Then
		Return New StandardPeriod(StandardPeriodVariant.LastYearTillSameDate);
	ElsIf BegOfWeek(StandardPeriod.StartDate) = BegOfWeek(StandardPeriod.EndDate) AND
		BegOfWeek(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfWeek(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary week is selected as a period
		StartDate	= BegOfWeek(BegOfWeek(StandardPeriod.StartDate)-1);
		EndDate		= BegOfWeek(StandardPeriod.StartDate)-1;
		
		Return New StandardPeriod(StartDate, EndDate);
		
	ElsIf BegOfMonth(StandardPeriod.StartDate) = BegOfMonth(StandardPeriod.EndDate) AND
		BegOfMonth(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfMonth(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary month is selected as a period
		StartDate	= BegOfMonth(BegOfMonth(StandardPeriod.StartDate)-1);
		EndDate		= BegOfMonth(StandardPeriod.StartDate)-1;
		
		Return New StandardPeriod(StartDate, EndDate);
		
	ElsIf BegOfQuarter(StandardPeriod.StartDate) = BegOfQuarter(StandardPeriod.EndDate) AND
		BegOfQuarter(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfQuarter(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary quarter is selected as a period
		StartDate	= BegOfQuarter(BegOfQuarter(StandardPeriod.StartDate)-1);
		EndDate		= BegOfQuarter(StandardPeriod.StartDate)-1;
		
		Return New StandardPeriod(StartDate, EndDate);
		
	ElsIf BegOfHalfYear(StandardPeriod.StartDate) = BegOfHalfYear(StandardPeriod.EndDate) AND
		BegOfHalfYear(StandardPeriod.StartDate) = BegOfDay(StandardPeriod.StartDate) AND
		EndOfHalfYear(StandardPeriod.EndDate) = EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary half-year is selected as a period
		StartDate	= BegOfQuarter(BegOfQuarter(StandardPeriod.StartDate)-1);
		EndDate		= BegOfQuarter(StandardPeriod.StartDate)-1;
		
		Return New StandardPeriod(StartDate, EndDate);
		
	ElsIf BegOfYear(StandardPeriod.StartDate)=BegOfYear(StandardPeriod.EndDate) AND
		BegOfYear(StandardPeriod.StartDate)=BegOfDay(StandardPeriod.StartDate) AND
		EndOfYear(StandardPeriod.EndDate)=EndOfDay(StandardPeriod.EndDate) Then
		
		// Whole arbitrary year is selected as a period
		StartDate	= BegOfYear(BegOfYear(StandardPeriod.StartDate)-1);
		EndDate		= BegOfYear(StandardPeriod.StartDate)-1;
		
		Return New StandardPeriod(StartDate, EndDate);
		
	ElsIf ValueIsFilled(StandardPeriod.StartDate) AND 
		BegOfYear(StandardPeriod.StartDate) = BegOfYear(StandardPeriod.EndDate) Then
		
		Result = New Structure;
		Result.Insert("Variant", "ForLastYear");
		Period = DriveClientServer.SamePeriodOfLastYear(StandardPeriod);
		
		If Period <> Undefined Then
			
			Result.Insert("StartDate",	Period.StartDate);
			Result.Insert("EndDate",	Period.EndDate);
			Return Result;
			
		Else
			Return Undefined;
		EndIf; 
		
	Else
		
		Result = New Structure;
		Result.Insert("Variant", "PreviousFloatingPeriod");
		
		Period = DriveClientServer.PreviousFloatingPeriod(StandardPeriod);
		
		If Period <> Undefined Then
			
			Result.Insert("StartDate",	Period.StartDate);
			Result.Insert("EndDate",	Period.EndDate);
			Return Result;
			
		Else
			Return Undefined;
		EndIf;
		
	EndIf; 	
	
EndFunction

&AtClientAtServerNoContext
Function CanMovePeriod(StandardPeriod)
	
	If StandardPeriod = Undefined Then
		Return False;
	EndIf;
	
	If StandardPeriod.Variant = "" Then
		Return False;
	EndIf; 
	
	If StandardPeriod.Variant = StandardPeriodVariant.Custom 
		AND (Not ValueIsFilled(StandardPeriod.StartDate)
			OR Not ValueIsFilled(StandardPeriod.EndDate)) Then
		
		Return False;
		
	EndIf;
	
	Return True;
	
EndFunction

&AtClientAtServerNoContext
Procedure UpdatePeriodPresentations(Form)
	
	// Visibility of groups of comparison parameter selection
	ComparisonDateVisibility = (Form.ComparisonDate <> Undefined);
	
	If Form.Items.GroupIndicatorsBalanceComparisonDate.Visible <> ComparisonDateVisibility Then
		Form.Items.GroupIndicatorsBalanceComparisonDate.Visible = ComparisonDateVisibility;
	EndIf; 
	
	ComparisonPeriodVisibility = (Form.ComparisonPeriod <> Undefined);
	
	If Form.Items.GroupIndicatorsTurnoversComparisonPeriod.Visible <> ComparisonPeriodVisibility Then
		Form.Items.GroupIndicatorsTurnoversComparisonPeriod.Visible = ComparisonPeriodVisibility;
	EndIf;
	
	// Availability of period offset buttons
	ButtonsAvailabilityPeriod = CanMovePeriod(Form.Period);
	
	If Form.Items.PeriodBack.Enabled <> ButtonsAvailabilityPeriod Then
		Form.Items.PeriodBack.Enabled = ButtonsAvailabilityPeriod;
		Form.Items.PeriodForward.Enabled = ButtonsAvailabilityPeriod;
	EndIf;       
	
	ButtonsAvailabilityComparisonPeriod = CanMovePeriod(Form.ComparisonPeriod);
	
	If Form.Items.ComparisonPeriodBack.Enabled <> ButtonsAvailabilityComparisonPeriod Then		
		Form.Items.ComparisonPeriodBack.Enabled = ButtonsAvailabilityComparisonPeriod;
		Form.Items.ComparisonPeriodForward.Enabled = ButtonsAvailabilityComparisonPeriod;		
	EndIf; 
	
	// Period presentations
	Form.Items.SelectDate.Title									= Upper(NStr("en = 'For today'"));
	Form.Items.SelectDate.ExtendedTooltip.Title					= Form.Items.SelectDate.Title;
	Form.Items.DecorationDateSelection.Title					= Upper(NStr("en = 'For today'"));
	Form.Items.DecorationDateSelection.ExtendedTooltip.Title	= Form.Items.DecorationDateSelection.Title;
	
	
	Presentation = StandardStartDatePresentation(Form.ComparisonDate, Form.Date);
	
	Form.Items.ComparisonDateSelection.Title					= NStr("en = 'Compare with:'") + " " + Presentation;
	Form.Items.ComparisonDateSelection.ExtendedTooltip.Title	= Presentation;
	Form.Items.DecorationComparisonDateSelection.Title			= NStr("en = 'Compare with:'") + " " + Presentation;
	Form.Items.DecorationComparisonDateSelection.ExtendedTooltip.Title	= Presentation;
	
	Form.Items.PeriodSelection.Title							= Upper(StandardPeriodPresentation(Form.Period));
	Form.Items.PeriodSelection.ExtendedTooltip.Title			= Form.Items.PeriodSelection.Title;
	Form.Items.DecorationPeriodSelection.Title					= Upper(StandardPeriodPresentation(Form.Period));
	Form.Items.DecorationPeriodSelection.ExtendedTooltip.Title	= Form.Items.DecorationPeriodSelection.Title;
	
	Presentation = StandardPeriodPresentation(Form.ComparisonPeriod, Form.Period); 
	
	Form.Items.ComparisonPeriodSelection.Title								= NStr("en = 'Compare with:'") + " " + Presentation;
	Form.Items.ComparisonPeriodSelection.ExtendedTooltip.Title				= Presentation;	
	Form.Items.DecorationComparisonPeriodSelection.Title					= NStr("en = 'Compare with:'") + " " + Presentation;
	Form.Items.DecorationComparisonPeriodSelection.ExtendedTooltip.Title	= Presentation;	
	
EndProcedure

#EndRegion 

&AtClient
Procedure UpdatePartially(Section, SavedPeriods = "")
	
	If IsBlankString(Section) Then
		Return;
	EndIf; 
	
	RunBackgroundJobOnServer(Section, SavedPeriods);
	
	If BackgroundJobRunning Then
		
		If Section = "Balance" Then
			Items.GroupIndicatorsBalance.Enabled = False;
		ElsIf Section = "Turnovers" Then
			Items.GroupIndicatorsTurnovers.Enabled = False;
		EndIf; 
		
	EndIf;
	
	StartAwaitingBackgroundJobCompletionOnClient();
	
EndProcedure

&AtServer
Procedure UpdateForm()
	
	DeleteItemsRecursively(Items.GroupIndicatorsBalance);
	DeleteItemsRecursively(Items.GroupIndicatorsTurnovers);
	AddedIndicators.Clear();
	DeleteItemsRecursively(Items.GroupAddedCharts);
	AddedCharts.Clear();
	LoadSettings();
	CreateItemsIndicators();
	CreateChartItems();
	RunBackgroundJobOnServer();
	
EndProcedure
 
&AtServer
Procedure RefreshData()
	
	UpdateIndicatorValues();
	UpdateChartValues();
	
EndProcedure

&AtServer
Procedure Initialization()
	
	// Populate indicator table
	// Sales
	AddIndicator("Sales", "Revenue", 			NStr("en = 'Sales'"), NStr("en = 'Revenue'"),, True, "NFD=; NZ=-", "DCS_AR_Sales", "Report.NetSales", "Default", "Total");
	AddIndicator("Sales", "Quantity", 			NStr("en = 'Sales'"), NStr("en = 'Sales qty'"),,, "NZ=-", "DCS_AR_Sales", "Report.NetSales", "Default", "Quantity");
	AddIndicator("Sales", "NumberOfDocuments", 	NStr("en = 'Sales'"), NStr("en = 'Sales transactions count'"),,, "NFD=; NZ=-", "DCS_AR_Sales", "Report.NetSales", "GrossProfitByManagers", "NumberOfDocuments");
	AddIndicator("Sales", "Cost", 				NStr("en = 'Sales'"), NStr("en = 'COGS'"),, True, "NFD=; NZ=-", "DCS_AR_Sales", "Report.NetSales", "GrossProfit", "Cost");
	AddIndicator("Sales", "Profit", 			NStr("en = 'Sales'"), NStr("en = 'Gross profit'"),, True, "NFD=; NZ=-", "DCS_AR_Sales", "Report.NetSales", "GrossProfit", "GrossProfit");
	AddIndicator("Sales", "Margin", 			NStr("en = 'Sales'"), NStr("en = 'Markup'"),,, "NZ=-", "DCS_AR_Sales", "Report.NetSales", "GrossProfit", "Margin");
	AddIndicator("Sales", "Profitability", 		NStr("en = 'Sales'"), NStr("en = 'Margin'"),,, "NZ=-", "DCS_AR_Sales", "Report.NetSales", "GrossProfit", "Profitability");

	// Goods
	AddIndicator("Products", "QuantityBalance", NStr("en = 'Goods'"), NStr("en = 'Stock qty'"), True,, "NZ=-", "DCS_AR_Inventory", "Report.StockStatement", "Balance",, "Inventory");
	AddIndicator("Products", "AmountBalance", 	NStr("en = 'Goods'"), NStr("en = 'Stock amount'"), True, True, "NFD=; NZ=-", "DCS_AR_Inventory", "Report.StockStatement", "Balance",, "Inventory");
	AddIndicator("Products", "QuantityReceipt", NStr("en = 'Goods'"), NStr("en = 'Inventory debit qty'"),,, "NZ=-", "DCS_AR_Inventory", "Report.StockStatement", "Statement");
	AddIndicator("Products", "AmountReceipt", 	NStr("en = 'Goods'"), NStr("en = 'Inventory debit amount'"),, True, "NFD=; NZ=-", "DCS_AR_Inventory", "Report.StockStatement", "Statement");
	AddIndicator("Products", "QuantityExpense", NStr("en = 'Goods'"), NStr("en = 'Inventory credit qty'"),,, "NZ=-", "DCS_AR_Inventory", "Report.StockStatement", "Statement");
	AddIndicator("Products", "AmountExpense", 	NStr("en = 'Goods'"), NStr("en = 'Inventory credit amount'"),, True, "NFD=; NZ=-", "DCS_AR_Inventory", "Report.StockStatement", "Statement");

	// Cash
	AddIndicator("Cash", "AmountBalance", 		NStr("en = 'Cash'"), NStr("en = 'Cash balance'"), True, True, "NFD=; NZ=-", "DCS_AR_Funds", "Report.CashBalance", "Balance",, "Funds");
	AddIndicator("Cash", "CashFlow", 			NStr("en = 'Cash'"), NStr("en = 'Net cash flow'"),, True, "NFD=; NZ=-", "DCS_AR_Funds", "Report.CashBalance", "Statement");
	AddIndicator("Cash", "Receipts", 			NStr("en = 'Cash'"), NStr("en = 'Cash receipts'"),, True, "NFD=; NZ=-", "DCS_AR_Funds", "Report.CashBalance", "Statement");
	AddIndicator("Cash", "Payments", 			NStr("en = 'Cash'"), NStr("en = 'Payments'"),, True, "NFD=; NZ=-", "DCS_AR_Funds", "Report.CashBalance", "Statement");

	IndicatorSettings.Sort("Presentation,ResourcePresentation");

	// Fill in chart table
	
	PropertySetsProducts = AttributeSets(Catalogs.AdditionalAttributesAndInformationSets.Catalog_Products);
	
	// "Sales dynamics" chart
	SeriesStructure = New Structure;
	AddPointSeriesDescription(SeriesStructure, "Total", 			NStr("en = 'Sales amount'"), NStr("en = 'Sales'"), ChartType.Column, True);
	AddPointSeriesDescription(SeriesStructure, "Quantity", 			NStr("en = 'Sales qty'"),, ChartType.Column);
	AddPointSeriesDescription(SeriesStructure, "NumberOfDocuments", NStr("en = 'Sales transactions count'"),, ChartType.Column);
	AddPointSeriesDescription(SeriesStructure, "Profit", 			NStr("en = 'Gross profit'"),, ChartType.Column, True);
	PresentationArray = New Array;
	PresentationArray.Add(NStr("en = 'COGS'"));
	PresentationArray.Add(NStr("en = 'Gross profit'"));
	AddPointSeriesDescription(SeriesStructure, "ProfitAndCost", PresentationArray, NStr("en = 'COGS and gross profit'"), ChartType.StackedColumn, True);
	PointStructure = New Structure;
	AddPointSeriesDescription(PointStructure, "Day", 	NStr("en = 'Days'"),,,, "DLF=D");
	AddPointSeriesDescription(PointStructure, "Week", 	NStr("en = 'Weeks'"),,,, "DLF=D");
	AddPointSeriesDescription(PointStructure, "Month", 	NStr("en = 'Months'"),,,, "DF='MMM yyyy'");
	AddChart("SalesDynamics", NStr("en = 'Sales overview'"), SeriesStructure, PointStructure, False, "DCS_AR_Sales", "Report.NetSales", "Default");  
	
	// "Sales structure" chart
	SeriesStructure = New Structure;
	AddPointSeriesDescription(SeriesStructure, "ProductsParent", 	NStr("en = 'Product groups'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "ProductsCategory", 	NStr("en = 'Categories of products'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Warehouse", 					NStr("en = 'Warehouses'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Products", 			NStr("en = 'Goods'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Counterparty", 					NStr("en = 'Customers'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Company", 						NStr("en = 'Companies'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Department", 					NStr("en = 'Departments'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Responsible", 					NStr("en = 'Sales managers'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Currency", 						NStr("en = 'Currency'"),, ChartType.Pie);
	
	PointStructure = New Structure;
	AddPointSeriesDescription(PointStructure, "Total", 				NStr("en = 'Revenue'"), NStr("en = 'Sales'"),, True);
	AddPointSeriesDescription(PointStructure, "Quantity", 			NStr("en = 'Sales qty'"));
	AddPointSeriesDescription(PointStructure, "NumberOfDocuments", 	NStr("en = 'Sales transactions count'"));
	AddPointSeriesDescription(PointStructure, "Profit", 			NStr("en = 'Gross profit'"),,, True);
	AddPointSeriesDescription(PointStructure, "ReturnsAmount", 		NStr("en = 'Sales return'"),,, True);
	AddPointSeriesDescription(PointStructure, "ReturnsQuantity", 	NStr("en = 'Sales return qty'"));
	AddChart("SalesStructure", 										NStr("en = 'Sales structure'"), SeriesStructure, PointStructure, False, "DCS_AR_Sales", "Report.NetSales", "Default");  
	
	// "Funds dynamics" chart
	SeriesStructure = New Structure;
	AddPointSeriesDescription(SeriesStructure, "AmountBalance", NStr("en = 'Cash balance'"), NStr("en = 'Cash balance'"), ChartType.Column, True);
	AddPointSeriesDescription(SeriesStructure, "AmountReceipt", NStr("en = 'Cash receipts'"), NStr("en = 'Cash receipts'"), ChartType.Column, True);
	AddPointSeriesDescription(SeriesStructure, "AmountExpense", NStr("en = 'Cash payments'"), NStr("en = 'Cash payments'"), ChartType.Column, True);
	PointStructure = New Structure;
	AddPointSeriesDescription(PointStructure, "Day", 	NStr("en = 'Days'"),,,, "DLF=D");
	AddPointSeriesDescription(PointStructure, "Week", 	NStr("en = 'Weeks'"),,,, "DLF=D");
	AddPointSeriesDescription(PointStructure, "Month", 	NStr("en = 'Months'"),,,, "DF='MMMM yyyy'");
	AddChart("FundsDynamics", NStr("en = 'Cash flow overview'"), SeriesStructure, PointStructure, False, "DCS_AR_Funds", "Report.CashBalance", "Statement");  
	
	// "Funds structure" chart
	SeriesStructure = New Structure;
	AddPointSeriesDescription(SeriesStructure, "BankAccountCashFund", 	NStr("en = 'Cash account'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Currency", 				NStr("en = 'Currency'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "Company", 				NStr("en = 'Company'"),, ChartType.Pie);
	AddPointSeriesDescription(SeriesStructure, "FundsType", 			NStr("en = 'Cash type'"),, ChartType.Pie);
	
	PointStructure = New Structure;
	AddPointSeriesDescription(PointStructure, "AmountBalance", NStr("en = 'Cash balance'"), NStr("en = 'Cash balance'"),, True);
	AddPointSeriesDescription(PointStructure, "AmountReceipt", NStr("en = 'Cash receipts'"), NStr("en = 'Cash receipts'"),, True);
	AddPointSeriesDescription(PointStructure, "AmountExpense", NStr("en = 'Cash payments'"), NStr("en = 'Cash payments'"),, True);
	
	// "Asset dynamics" chart
	SeriesStructure = New Structure;
	PresentationArray = New Array;
	PresentationArray.Add(NStr("en = 'AR'"));
	PresentationArray.Add(NStr("en = 'AP'"));
	PresentationArray.Add(NStr("en = 'Cash'"));
	PresentationArray.Add(NStr("en = 'Goods'"));
	PresentationArray.Add(NStr("en = 'Fixed assets'"));
	AddPointSeriesDescription(SeriesStructure, "Total", PresentationArray, NStr("en = 'Net assets'"), ChartType.StackedArea, True);
	PointStructure = New Structure;
	AddPointSeriesDescription(PointStructure, "Time", NStr("en = 'Time'"),,,, "DLF=D");

	ChartSettings.Sort("Presentation");

	// Other initialization operations
	
	ComplCurrencyCharacter = CommonUse.ObjectAttributeValue(DriveReUse.GetAccountCurrency(), "Description");
	
	DetermineBalanceInputModes();
	
EndProcedure

&AtServer
Procedure DetermineBalanceInputModes()
	
	Query = New Query;
	Query.Text =
	"SELECT TOP 1
	|	Funds.Recorder
	|FROM
	|	AccumulationRegister.CashAssets AS Funds
	|WHERE
	|	Not Funds.Recorder REFS Document.OpeningBalanceEntry
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	InventoryInWarehouses.Recorder
	|FROM
	|	AccumulationRegister.InventoryInWarehouses AS InventoryInWarehouses
	|WHERE
	|	Not InventoryInWarehouses.Recorder REFS Document.OpeningBalanceEntry
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	AccountsReceivable.Recorder
	|FROM
	|	AccumulationRegister.AccountsReceivable AS AccountsReceivable
	|WHERE
	|	Not AccountsReceivable.Recorder REFS Document.OpeningBalanceEntry
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT TOP 1
	|	AccountsPayable.Recorder
	|FROM
	|	AccumulationRegister.AccountsPayable AS AccountsPayable
	|WHERE
	|	Not AccountsPayable.Recorder REFS Document.OpeningBalanceEntry";
	Result = Query.ExecuteBatch();
	
	Modes = New Structure;
	Modes.Insert("Funds",		Result.Get(0).IsEmpty());
	Modes.Insert("Inventory",	Result.Get(1).IsEmpty());
	Modes.Insert("Customers",	Result.Get(2).IsEmpty());
	Modes.Insert("Vendors",		Result.Get(3).IsEmpty());
	
	BalanceInputModes = New FixedStructure(Modes);
	
	ThereBalanceInput = False;
	
	For Each Mode In BalanceInputModes Do
		If Not Mode.Value Then
			ThereBalanceInput = True;
		EndIf; 
	EndDo;
	
EndProcedure

&AtServer
Procedure SaveSettingsPeriods(SavedPeriods)
	
	Names = StringFunctionsClientServer.SplitStringIntoWordArray(SavedPeriods);
	For Each Name In Names Do
		CommonUse.CommonSettingsStorageSave("BusinessPulse", Name, ThisForm[Name]);
	EndDo; 
	
EndProcedure

&AtServer
Procedure SaveSettings(SettingsKind = "")

	If IsBlankString(SettingsKind) OR SettingsKind = "Indicators" Then
		
		Tab = AddedIndicators.Unload(, "Indicator, Resource, Presentation, Filters, Settings");
		CommonUse.CommonSettingsStorageSave("BusinessPulse", "Indicators", Tab);
		
	EndIf;
	
	If IsBlankString(SettingsKind) OR SettingsKind = "Charts" Then
		
		Tab = AddedCharts.Unload(, "Chart, Series, Point, Presentation, Period, ComparisonPeriod, Filters, Settings");
		CommonUse.CommonSettingsStorageSave("BusinessPulse", "Charts", Tab);
		
	EndIf; 
	
EndProcedure

&AtServer
Procedure ImportSettingsPeriods()
	
	Date = New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfNextDay);
	
	CurComparisonDate = CommonUse.CommonSettingsStorageImport("BusinessPulse", "ComparisonDate");
	
	If TypeOf(CurComparisonDate) <> Type("StandardBeginningDate") 
		AND TypeOf(CurComparisonDate) <> Type("Structure") 
		AND CurComparisonDate <> Undefined Then
		
		CurComparisonDate = Undefined;
		
	EndIf;
	
	ComparisonDate = CurComparisonDate;
	
	CurComparisonDateType = CommonUse.CommonSettingsStorageImport("BusinessPulse", "ComparisonDateType");
	
	If TypeOf(CurComparisonDateType) <> Type("String") Then
		CurComparisonDateType = DateType(ComparisonDate);
	EndIf; 
	
	ComparisonDateType = CurComparisonDateType;
	
	CurPeriod = CommonUse.CommonSettingsStorageImport("BusinessPulse", "Period");
	
	If TypeOf(CurPeriod)<>Type("StandardPeriod") 
		AND TypeOf(CurPeriod) <> Type("Structure") Then
		
		CurPeriod = New StandardPeriod(StandardPeriodVariant.ThisMonth);
		
	EndIf; 
	
	Period = CurPeriod;
	
	CurPeriodType = CommonUse.CommonSettingsStorageImport("BusinessPulse", "PeriodType");
	
	If TypeOf(CurPeriodType) <> Type("String") Then
		CurPeriodType = PeriodType(Period);
	EndIf; 
	
	PeriodType = CurPeriodType;
	
	CurComparisonPeriod = CommonUse.CommonSettingsStorageImport("BusinessPulse", "ComparisonPeriod");
	
	If TypeOf(CurComparisonPeriod) <> Type("StandardPeriod") 
		AND TypeOf(CurComparisonPeriod) <> Type("Structure") 
		AND CurComparisonPeriod <> Undefined Then
		
		CurComparisonPeriod = Undefined;
		
	EndIf; 
	
	ComparisonPeriod = CurComparisonPeriod;
	
	CurComparisonPeriodType = CommonUse.CommonSettingsStorageImport("BusinessPulse", "ComparisonPeriodType");
	
	If TypeOf(CurComparisonPeriodType) <> Type("String") Then
		CurComparisonPeriodType = PeriodType(ComparisonPeriod);
	EndIf; 
	
	ComparisonPeriodType = CurComparisonPeriodType;
	
EndProcedure

&AtServer
Procedure LoadSettings()
	
	IndicatorTable	= CommonUse.CommonSettingsStorageImport("BusinessPulse", "Indicators");
	ChartTable		= CommonUse.CommonSettingsStorageImport("BusinessPulse", "Charts");
	
	If IndicatorTable = Undefined Then
		DefaultIndicators();
	Else     
		
		AddedIndicators.Clear();
		
		For Each Str In IndicatorTable Do
			
			If Not IsBlankString(Str.Resource) Then
				
				FilterStructure = New Structure;
				FilterStructure.Insert("Indicator", Str.Indicator);
				FilterStructure.Insert("Resource", Str.Resource);
				Rows = IndicatorSettings.FindRows(FilterStructure);
				
				If Rows.Count() = 0 Then
					// Obsolete indicator
					Continue;
				EndIf;
				
			EndIf; 
			
			NewRow = AddedIndicators.Add();
			FillPropertyValues(NewRow, Str);
			
			If Not IsBlankString(Str.Resource) Then
				
				SettingPage				= Rows[0];
				NewRow.SettingLineID	= SettingPage.GetID();
				NewRow.Balance			= SettingPage.Balance;
				
				If Not IsBlankString(SettingPage.AccountingSection) Then
					NewRow.EnterBalance = BalanceInputModes[SettingPage.AccountingSection];
				EndIf; 
				
			EndIf; 
			
		EndDo;
		
	EndIf; 
	
	If ChartTable = Undefined Then
		DefaultCharts();
	Else
		
		AddedCharts.Clear();
		
		For Each Str In ChartTable Do
			
			FilterStructure = New Structure;
			FilterStructure.Insert("Chart", ?(ChartTable.Columns.Find("Indicator") = Undefined, Str.Chart, Str.Indicator));
			Rows = ChartSettings.FindRows(FilterStructure);
			
			If Rows.Count()=0 Then
				// Obsolete chart
				Continue;
			EndIf;
			
			SettingRow = Rows[0];
			
			If Not SettingRow.Series.Property(Str.Series) OR Not SettingRow.Points.Property(Str.Point) Then
				// Obsolete chart
				Continue;
			EndIf; 
			
			NewRow = AddedCharts.Add();
			FillPropertyValues(NewRow, Str);
			
			If Not ChartTable.Columns.Find("Indicator")=Undefined Then
				NewRow.Chart = Str.Indicator;
			EndIf; 
			
			NewRow.SettingLineID = Rows[0].GetID();
			
			If ValueIsFilled(NewRow.ComparisonPeriod) AND TypeOf(NewRow.ComparisonPeriod) = Type("StandardPeriod") Then
				
				PresentationArray = New Array;
				PresentationArray.Add(StandardPeriodPresentation(NewRow.Period));
				PresentationArray.Add(StandardPeriodPresentation(NewRow.ComparisonPeriod, NewRow.Period));
				NewRow.SeriesPresentations = New FixedArray(PresentationArray);
				
			ElsIf ValueIsFilled(NewRow.ComparisonPeriod) AND TypeOf(NewRow.ComparisonPeriod) = Type("StandardBeginningDate") Then
				
				PresentationArray = New Array;
				PresentationArray.Add(StandardStartDatePresentation(NewRow.Period));
				PresentationArray.Add(StandardStartDatePresentation(NewRow.ComparisonPeriod, NewRow.Period));
				NewRow.SeriesPresentations = New FixedArray(PresentationArray);
				
			ElsIf ValueIsFilled(NewRow.ComparisonPeriod) AND TypeOf(NewRow.ComparisonPeriod) = Type("Structure") Then
				
				PresentationArray = New Array;
				
				If NewRow.ComparisonPeriod.Variant = "SameDayLastWeek" 
					OR NewRow.ComparisonPeriod.Variant = "SameDayLastMonth" 
					OR NewRow.ComparisonPeriod.Variant = "SameDayLastYear" Then
					
					PresentationArray.Add(StandardStartDatePresentation(NewRow.Period));
					PresentationArray.Add(StandardStartDatePresentation(NewRow.ComparisonPeriod, NewRow.Period));
					
				Else
					
					PresentationArray.Add(StandardPeriodPresentation(NewRow.Period));
					PresentationArray.Add(StandardPeriodPresentation(NewRow.ComparisonPeriod, NewRow.Period));
					
				EndIf; 
				
				NewRow.SeriesPresentations = New FixedArray(PresentationArray);
				
			Else
				NewRow.SeriesPresentations = SettingRow.Series[Str.Series].Presentations;
			EndIf; 
			
			NewRow.PointPresentations = SettingRow.Points[Str.Point].Presentations;
			
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure DefaultIndicators()
	
	Period				= New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisYear);
	ComparisonPeriod	= New StandardPeriod(StandardPeriodVariant.LastYearTillSameDate);
	ComparisonDate		= New StandardBeginningDate(StandardBeginningDateVariant.BeginningOfThisWeek);
	UpdatePeriodPresentations(ThisForm);
	
	AddedIndicators.Clear();
	DisplayIndicator("Products",	"AmountBalance",	NStr("en = 'Products - Stock amount'"));
	DisplayIndicator("Products",	"QuantityBalance",	NStr("en = 'Products - Stock qty'"));
	DisplayIndicator("Cash",		"AmountBalance",	NStr("en = 'Cash - Cash balance'"));
	DisplayIndicator("Cash",		"Receipts",			NStr("en = 'Cash - Receipts'"));
	DisplayIndicator("Cash",		"Payments",			NStr("en = 'Cash - Payments'"));
	DisplayIndicator("Sales",		"Revenue",			NStr("en = 'Sales - Revenue'"));
	DisplayIndicator("Sales",		"Cost",				NStr("en = 'Sales - COGS'"));
	DisplayIndicator("Sales",		"Profit",			NStr("en = 'Sales - Gross profit'"));
	DisplayIndicator("Sales",		"Profitability",	NStr("en = 'Sales - Margin'"));
	
	SaveSettings("Indicators");
	SaveSettingsPeriods("ComparisonDate, Period, ComparisonPeriod");
	
EndProcedure

&AtServer
Procedure DefaultCharts()
	
	If GetFunctionalOption("UseRetail") AND ThereRetailSalesForTheLastWeek() Then
		
		ChartPeriod = New Structure;
		ChartPeriod.Insert("Variant", "Last7DaysExceptForCurrentDay");
		
		Structure 		= FilterStructure("RetailDocuments",, TRUE);
		FiltersArray	= New Array;
		FiltersArray.Add(Structure);
		DisplayChart(
			"SalesDynamics", 
			"ProfitAndCost", 
			"Day", 
			ChartPeriod,, 
			NStr("en = 'Sales overview'"),
			FiltersArray
		);
				
		DisplayChart(
			"RetailSalesStructure", 
			"ProductsCategory", 
			"Total", 
			ChartPeriod,, 
			NStr("en = 'Sales by categories'")
		);
					
	Else
		
		ChartPeriod = New StandardPeriod(StandardPeriodVariant.FromBeginningOfThisYear);
		
		DisplayChart(
			"SalesDynamics", 
			"ProfitAndCost", 
			"Month", 
			ChartPeriod,, 
			NStr("en = 'Sales overview'")
		);
		
		DisplayChart(
			"SalesStructure", 
			"ProductsCategory", 
			"Total", 
			ChartPeriod,, 
			NStr("en = 'Sales by categories'")
		);
		
	EndIf; 
	
	SaveSettings("Charts");
	
EndProcedure

&AtServerNoContext
Function ThereRetailSalesForTheLastWeek()
	
	Query = New Query;
	Query.SetParameter("CheckDate", BegOfDay(CurrentDate()) - 7 * 24 * 3600);
	Query.Text =
	"SELECT TOP 1
	|	Sales.Recorder AS Recorder
	|FROM
	|	AccumulationRegister.Sales AS Sales
	|WHERE
	|	(Sales.Recorder REFS Document.ShiftClosure
	|			OR Sales.Recorder REFS Document.SalesSlip
	|			OR Sales.Recorder REFS Document.ProductReturn)
	|	AND Sales.Period >= &CheckDate";
	
	Return Not Query.Execute().IsEmpty();
	
EndFunction

#Region CommonProceduresAndFunctions

&AtServerNoContext
Function FilterStructure(Field, ComparisonType = Undefined, Value = Undefined)
	
	FilterStructure = New Structure;
	FilterStructure.Insert("Field", Field);
	FilterStructure.Insert("ComparisonType", ?(ComparisonType = Undefined, DataCompositionComparisonType.Equal, ComparisonType));
	FilterStructure.Insert("Value", Value);
	
	Return FilterStructure;
	
EndFunction

&AtServer
Function AddCommand(GroupName, Suffix, Item, Action, Title, Picture)
	
	CommandName	= GroupName + Suffix;
	Command		= Commands.Find(CommandName);
	
	If Command = Undefined Then
		
		Command			= Commands.Add(CommandName);
		Command.Action	= Action;
		Command.Picture	= Picture;
		Command.Title	= Title;
		
	EndIf; 
	
	Button 				= Items.Add(Command.Name + StrReplace(String(New UUID), "-", ""), Type("FormButton"), Items[Item.Name + "ContextMenu"]);
	Button.Type			= FormButtonType.CommandBarButton;
	Button.CommandName	= Command.Name;
	Button.Picture		= Picture;
	Button.Title		= Title;
	
	Return Button;
	
EndFunction
 
&AtServer
Function FormatValue(Value, Str)
	
	If TypeOf(Value) = Type("FormattedString") Then
		Return Value;
	EndIf; 
	
	If TypeOf(Value) = Type("String") Then
		Return ToFormattedLine(Value);
	EndIf;
	
	SettingPage = IndicatorSettings.FindByID(Str.SettingLineID);
	
	If Not ValueIsFilled(Value) Then
		
		If IsBlankString(SettingPage.Format) Then
			Result = String(Value);
		Else
			Result = Format(Value, SettingPage.Format);
		EndIf;
		
	Else
		
		If IsBlankString(SettingPage.Format) Then
			Result = ToFormattedLine(String(Value));
		Else
			Result = ToFormattedLine(Format(Value, SettingPage.Format));
		EndIf;
		
		Result = New FormattedString(Result, 
			?(SettingPage.Currency AND ValueIsFilled(Value), 
				New FormattedString(" " + ComplCurrencyCharacter, New Font(New Font,, 8), StyleColors.FormTextColor), 
				"")
		);
		
	EndIf;
	
	Return Result;
	
EndFunction

&AtServer
Function ToFormattedLine(String, Ref = "")
	
	FractionalPartSeparator = Mid(Format(0.1), 2,1);
	
	If StrOccurrenceCount(String, FractionalPartSeparator) > 1 Then
		Return New FormattedString(String,,,, Ref);
	EndIf; 
	
	Position = Find(String, FractionalPartSeparator);
	
	If Position = 0 Then
		Return New FormattedString(String, New Font(New Font,,, True), StyleColors.FormTextColor,, Ref);
	Else
		
		TextBefore	= Left(String, Position-1);
		TextAfter	= Mid(String, Position);
		
		Return New FormattedString(
			New FormattedString(TextBefore, New Font(New Font,,, True), StyleColors.FormTextColor,, Ref),
			New FormattedString(TextAfter, New Font(New Font,, 8), StyleColors.FormTextColor,, Ref)
		);
		
	EndIf; 
	
EndFunction

&AtClientAtServerNoContext
Function PreviousItem(Item)
	
	Result = Undefined;
	
	For Each CurItem In Item.Parent.ChildItems Do
		
		If Item = CurItem Then
			Break;
		EndIf;
		
		Result = CurItem;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtClientAtServerNoContext
Function NextItem(Item)
	
	Result			= Undefined;
	CurrentFound	= False;
	NextFound		= False;
	
	For Each CurItem In Item.Parent.ChildItems Do
		
		If NextFound Then
			Result = CurItem;
			Break;
		EndIf; 
		
		If CurrentFound AND Not NextFound Then
			NextFound = True;
		EndIf; 
		
		If Item = CurItem Then
			CurrentFound = True;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

&AtServer
Function AttributeSets(Group)
	
	Query = New Query;
	Query.SetParameter("Group", Group);
	Query.Text =
	"SELECT
	|	AdditionalAttributesAndInformationSets.Ref
	|FROM
	|	Catalog.AdditionalAttributesAndInformationSets AS AdditionalAttributesAndInformationSets 
	|WHERE AdditionalAttributesAndInformationSets.Ref IN HIERARCHY(&Group)
	|	AND NOT AdditionalAttributesAndInformationSets.IsFolder
	|";
	
	Return Query.Execute().Unload().UnloadColumn("Ref");
	
EndFunction

&AtServerNoContext
Procedure AddQuickActionsToDesktop(RefreshInterface)
	
	SetPrivilegedMode(True);
	
	User = InfobaseUsers.CurrentUser();
	
	HomePageSettings = CommonUse.SystemSettingsStorageImport("General/HomePageSettings", "", , , User.Name);
	
	If TypeOf(HomePageSettings)<>Type("HomePageSettings") Then
		Return;
	EndIf;
	
	FormContent = HomePageSettings.GetForms();
	
	If FormContent.LeftColumn.Find("DataProcessor.BusinessPulse.Form.BusinessPulse") <> Undefined
		AND FormContent.LeftColumn.Find("DataProcessor.QuickActions.Form.QuickActions") = Undefined Then
		
		Index = FormContent.LeftColumn.Find("DataProcessor.BusinessPulse.Form.BusinessPulse");
		FormContent.LeftColumn.Insert(Index, "DataProcessor.QuickActions.Form.QuickActions");
		RefreshInterface = True;
		
	ElsIf FormContent.RightColumn.Find("DataProcessor.BusinessPulse.Form.BusinessPulse") <> Undefined
		AND FormContent.RightColumn.Find("DataProcessor.QuickActions.Form.QuickActions") = Undefined Then
		
		Index = FormContent.RightColumn.Find("DataProcessor.BusinessPulse.Form.BusinessPulse");
		FormContent.RightColumn.Insert(Index, "DataProcessor.QuickActions.Form.QuickActions");
		RefreshInterface = True;
		
	Else
		Return;
	EndIf;
	
	HomePageSettings.SetForms(FormContent);
	CommonUse.SystemSettingsStorageSave("General/HomePageSettings", "", HomePageSettings, , User.Name);
	
	SetPrivilegedMode(False);
	
EndProcedure

&AtServer
Procedure DeleteItemsRecursively(Group)
	
	While Group.ChildItems.Count() > 0 Do
		
		Item = Group.ChildItems[0];
		
		If TypeOf(Item) = Type("FormButton") Then
			Commands.Delete(Item.CommandName);
		ElsIf TypeOf(Item) = Type("FormGroup") Then
			DeleteItemsRecursively(Item);
		EndIf; 
		
		Items.Delete(Item);
		
	EndDo; 
	
EndProcedure

#EndRegion 

#EndRegion
 

﻿#Region GeneralPurposeProceduresAndFunctions

// Procedure writes the user setting parameter at server
//
// ParameterName - text parameter identifier 
// ParameterValue - parameter value for record
//
&AtServer
Procedure SetParameterAtServer(ParameterName, ParameterValue)
	
	CompositionSetup	= Report.SettingsComposer.Settings;
	FoundSetting	= CompositionSetup.DataParameters.Items.Find(ParameterName);
	
	If Not FoundSetting = Undefined Then
		
		FoundSetting.Use = True;
		FoundSetting.Value = ParameterValue;
		
		UserSettingsItem = Report.SettingsComposer.UserSettings.Items.Find(FoundSetting.UserSettingID);
		If UserSettingsItem <> Undefined Then
			UserSettingsItem.Use = True;
			UserSettingsItem.Value = ParameterValue;
		EndIf;
		
	EndIf;
		
EndProcedure

// Procedure sets new filter item value user settings of data composition
//
// CompositionFilterCorrespondence - compliance, contains setting filter items of data composition
// and its identifiers FilterItemFromParameters - form parameter structure item, contains key and
// value filter items UserSettingFilter - item collection of
// user setting filter FilterValue - filter
// value CompositionComparisonKind - comparsion kind
// of data composition Usage - filter use value of data composition
//
&AtServer
Procedure SetDataCompositionFilterItemAtServer(CompositionFilterCorrespondence, FilterItemName, UserSettingsFilter, FilterValue, CompositionComparisonType, Use)
	
	CompositionFilterNewField	= New DataCompositionField(FilterItemName);
	UserSettingIdentifyer	= CompositionFilterCorrespondence.Get(CompositionFilterNewField);
	
	If Not UserSettingIdentifyer = Undefined Then
		
		UserSettingsItem = UserSettingsFilter.Items.Find(UserSettingIdentifyer);
		
		If Not UserSettingsItem = Undefined Then
			
			UserSettingsItem.Use = Use;
			UserSettingsItem.ComparisonType = CompositionComparisonType;
			UserSettingsItem.RightValue = FilterValue;
			
		EndIf;
		
	EndIf;
	
EndProcedure

// Function creates, fills and returns setting filter item compliance of data composition and its identifiers
//
&AtServer
Function GetCompositionSettingsFilterItemsCorrespondenceAtServer()
	
	CompositionFilterCorrespondence = New Map();
	
	CompositionFilter	= Report.SettingsComposer.Settings.Filter;
	For Each CompositionFilterItem In CompositionFilter.Items Do
		
		CompositionFilterCorrespondence.Insert(CompositionFilterItem.LeftValue, CompositionFilterItem.UserSettingID);
		
	EndDo;
	
	Return CompositionFilterCorrespondence;
	
EndFunction

#EndRegion

#Region ProceduresAndFunctionsForControlOfTheFormAppearance

// Procedure sets the external period button kind on the form
//
// NameButtons - text button identifier which is to be set to the "Enabled" state.
// 				other buttons will change their state to "Disabled".
// 				If the button is not found, all buttons will change their state to "Disabled".
//
&AtClient
Procedure EnableButtonAtClient(ButttonName)
	
	If Not ValueIsFilled(ButttonName) Then
		
		SwitchingPeriods = "";
		
	Else
		
		SwitchingPeriods = ButttonName;
		
	EndIf;
	
EndProcedure

// Procedure sets the compositing data parameters and period label
// on the form by received parameters
//
// Changeable Parameters composing data:
// Begin of period - date, report generation beginning of the period 
// End of period - date, report generation end of the period
//
&AtServer
Procedure SetPeriod(PeriodName, Direction)
	
	BeginOfPeriodValue 		= BegOfDay(CurrentDate());
	ValueEndPeriod	= EndOfDay(CurrentDate());
	
	If PeriodName = "Week" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfWeek(EndOfPeriod + (86400 * 7 * Direction));
		ValueEndPeriod	= EndOfWeek(EndOfPeriod + (86400 * 7 * Direction));
		
	ElsIf PeriodName = "Month" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfMonth(AddMonth(EndOfPeriod, (1 * Direction)));
		ValueEndPeriod	= EndOfMonth(AddMonth(EndOfPeriod, (1 * Direction)));
		
	ElsIf PeriodName = "Quarter" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfQuarter(AddMonth(EndOfPeriod, (3 * Direction)));
		ValueEndPeriod	= EndOfQuarter(AddMonth(EndOfPeriod, (3 * Direction)));
		
	ElsIf PeriodName = "Year" Then
		
		EndOfPeriod = ?(EndOfPeriod = Date(1,1,1), CurrentDate(), EndOfPeriod);
		
		BeginOfPeriodValue 		= BegOfYear(AddMonth(EndOfPeriod, (12 * Direction)));
		ValueEndPeriod	= EndOfYear(AddMonth(EndOfPeriod, (12 * Direction)));
		
	EndIf;
		
	SetParameterAtServer("BeginOfPeriod", BeginOfPeriodValue);
	SetParameterAtServer("EndOfPeriod", ValueEndPeriod);
	
	BeginOfPeriod = BeginOfPeriodValue;
	EndOfPeriod = ValueEndPeriod;
	
	Result.Clear();
	
	// Indicate to user that it is necessary to generate (update) the report
	Result.Area(2,2,2,2).Text 		= NStr("en = 'The report is not generated. Click ""Run report"" to generate the report.'");
	Result.Area(2,2,2,2).TextColor 	= New Color(138,138,138);
	Result.Area(2,2,2,2).Font 		= New Font(Result.Area(2,2,2,2).Font, ,12);
	
EndProcedure

// Procedure generates and updates period label on the form
//
&AtClient
Procedure SetPeriodLabel()
	
	// If no button is enabled - Arbitrary period
	If IsBlankString(SwitchingPeriods) Then
		
		PeriodPresentation = "Arbitrary period";
		
	ElsIf Month(BeginOfPeriod) = Month(EndOfPeriod) Then
		
		DayOfScheduleBegin = Format(BeginOfPeriod, "DF=dd");
		DayOfScheduleEnd = Format(EndOfPeriod, "DF=dd");
		MonthOfScheduleEnd = Format(EndOfPeriod, "DF=MMM");
		YearOfSchedule = Format(Year(EndOfPeriod), "NG=0");
		
		PeriodPresentation = DayOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
		
	Else
		
		DayOfScheduleBegin = Format(BeginOfPeriod, "DF=dd");
		MonthOfScheduleBegin = Format(BeginOfPeriod, "DF=MMM");
		DayOfScheduleEnd = Format(EndOfPeriod, "DF=dd");
		MonthOfScheduleEnd = Format(EndOfPeriod, "DF=MMM");
		
		If Year(BeginOfPeriod) = Year(EndOfPeriod) Then
			YearOfSchedule = Format(Year(EndOfPeriod), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + ", " + YearOfSchedule;
			
		Else
			YearOfScheduleBegin = Format(Year(BeginOfPeriod), "NG=0");
			YearOfScheduleEnd = Format(Year(EndOfPeriod), "NG=0");
			PeriodPresentation = DayOfScheduleBegin + " " + MonthOfScheduleBegin + " " + YearOfScheduleBegin + " - " + DayOfScheduleEnd + " " + MonthOfScheduleEnd + " " + YearOfScheduleEnd;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	StandardProcessing = False;
	
	CurrencyTotals = Constants.PresentationCurrency.Get();
	SetParameterAtServer("CurrencyTotals", CurrencyTotals);
	
	// Buttons and parameters 
	If Parameters.Property("Period") Then
		
		If Not Parameters.Period = Undefined Then
			
			SwitchingPeriods = TrimAll(Parameters.Period);
			
			CurrentDate 	= CurrentDate();
			EndOfPeriod  	= Parameters["EndOfPeriod"];
			
			SetParameterAtServer("CurrentDate", CurrentDate);
			SetParameterAtServer("EndOfPeriod", EndOfPeriod);
			
		EndIf;
		
	Else
		
		SwitchingPeriods = "WeekPeriod";
		
		CurrentDate   = CurrentDate();
		BeginOfPeriod = BegOfWeek(CurrentDate());
		EndOfPeriod  = EndOfWeek(CurrentDate());
		
		SetParameterAtServer("CurrentDate", CurrentDate);
		SetParameterAtServer("BeginOfPeriod", BeginOfPeriod);
		SetParameterAtServer("EndOfPeriod", EndOfPeriod);
		
	EndIf;
	
	Items.SettingsComposerUserSettings.Visible = False;
	
	// Indicate to user that it is necessary to generate the report
	Result.Area(2,2,2,2).Text 		= NStr("en = 'The report is not generated. Click ""Run report"" to generate the report.'");
	Result.Area(2,2,2,2).TextColor 	= New Color(138,138,138);
	Result.Area(2,2,2,2).Font 		= New Font(Result.Area(2,2,2,2).Font, ,12);
	
	// Set data composition filters
	If TypeOf(Parameters.Filter) = Type("Structure") Then
		
		For Each FilterItemFromParameters In Parameters.Filter Do
		
			SetDataCompositionFilterItemAtServer(GetCompositionSettingsFilterItemsCorrespondenceAtServer(), 
					FilterItemFromParameters.Key, 
					Report.SettingsComposer.UserSettings, 
					FilterItemFromParameters.Value, 
					DataCompositionComparisonType.Equal,
					True);
			
		EndDo;
				
	EndIf;
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	SetPeriodLabel();
	
EndProcedure

// Procedure - event handler OnChange field "Setting composer user settings".
// In procedure situation is defined when change user date setting "Period start" or "Period end" period label on report
// form changes
//
&AtClient
Procedure SettingsComposerUserSettingsOnChange(Item)
	
	// Data composition ID
	DataCompositionID = Item.CurrentRow;
	DataCompositionObject = Report.SettingsComposer.UserSettings.GetObjectByID(DataCompositionID);
	
	If Not DataCompositionObject = Undefined
		AND TypeOf(DataCompositionObject) = Type("DataCompositionSettingsParameterValue") Then
		
		DisablePeriodButtons = False;
		
		If DataCompositionObject.Parameter = New DataCompositionParameter("CurrentDate") Then
			
			CommonUseClientServer.MessageToUser(NStr("en = 'It is impossible to change the current date.'"));
			DataCompositionObject.Value = CurrentDate();
			
		EndIf;
		
		If DataCompositionObject.Parameter = New DataCompositionParameter("EndOfPeriod") Then
			
			EndOfPeriod 			= Date(DataCompositionObject.Value);
			DisablePeriodButtons = True;
			
		EndIf;
		
		If DataCompositionObject.Parameter = New DataCompositionParameter("CurrencyTotals") Then
			
			CurrencyTotals			= DataCompositionObject.Value;
			
		EndIf;
		
		If DisablePeriodButtons Then
			
			EnableButtonAtClient(Undefined);
			
		EndIf;
		
	EndIf;
	
	SetPeriodLabel();
	
EndProcedure

&AtClient
Procedure SwitchingPeriodsOnChange(Item)
	
	If SwitchingPeriods = "WeekPeriod" Then
		
		WeekPeriod("");
		
	ElsIf SwitchingPeriods = "MonthPeriod" Then
		
		MonthPeriod("");
		
	ElsIf SwitchingPeriods = "QuarterPeriod" Then
		
		QuarterPeriod("");
		
	ElsIf SwitchingPeriods = "YearPeriod" Then
		
		YearPeriod("");
		
	EndIf;
	
EndProcedure

#Region FormCommandHandlers

// Procedure is called when clicking "Year" on the report form
// 
&AtClient
Procedure YearPeriod(Command)
	
	EnableButtonAtClient("YearPeriod");
	SetPeriod("Year", 0);
	SetPeriodLabel();
	
EndProcedure

// Procedure is called when clicking "Quarter" on the report form
// 
&AtClient
Procedure QuarterPeriod(Command)
	
	EnableButtonAtClient("QuarterPeriod");
	SetPeriod("Quarter", 0);
	SetPeriodLabel();
	
EndProcedure

// Procedure is called when clicking "Month" on the report form
// 
&AtClient
Procedure MonthPeriod(Command)
	
	EnableButtonAtClient("MonthPeriod");
	SetPeriod("Month", 0);
	SetPeriodLabel();
	
EndProcedure

// Procedure is called when clicking "Week" on the report form
// 
&AtClient
Procedure WeekPeriod(Command)
	
	EnableButtonAtClient("WeekPeriod");
	SetPeriod("Week", 0);
	SetPeriodLabel();
	
EndProcedure

// Procedure is called when currency change from report form
//
&AtClient
Procedure TotalsCurrencyOnChange(Item)
	
	SetParameterAtServer("CurrencyTotals", CurrencyTotals);
	
EndProcedure

// Procedure is called when clicking "Setting" on the report form
// 
&AtClient
Procedure Setting(Command)
	
	Items.Setting.Check 										= Not Items.Setting.Check;
	Items.SettingsComposerUserSettings.Visible = Items.Setting.Check;
	
EndProcedure

#EndRegion

#EndRegion

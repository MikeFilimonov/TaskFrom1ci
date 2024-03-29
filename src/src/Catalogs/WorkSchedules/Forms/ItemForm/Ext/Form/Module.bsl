﻿
#Region GeneralPurposeProceduresAndFunctions

// The procedure fills in the schedule by the template.
//
&AtClient
Procedure FillByTemplate()
	
	Object.DailySchedules.Clear();
	
	If Object.ScheduleType = PredefinedValue("Enum.WorkScheduleTypes.FiveDays") Then
		
		Object.WorkweekDuration = 40;
		For DayIndex = 1 To 5 Do
			Session = Object.DailySchedules.Add();
			Session.BeginTime = Date(1,1,1,8,0,0);
			Session.EndTime = Date(1,1,1,16,0,0);
			Session.DayNumber = DayIndex;
		EndDo;
		
	ElsIf Object.ScheduleType = PredefinedValue("Enum.WorkScheduleTypes.SixDays") Then
		
		Object.WorkweekDuration = 40;
		For DayIndex = 1 To 6 Do
			Session = Object.DailySchedules.Add();
			Session.BeginTime = Date(1,1,1,8,0,0);
			If DayIndex = 6 Then
				Session.EndTime = Date(1,1,1,13,0,0);
			Else
				Session.EndTime = Date(1,1,1,15,0,0);
			EndIf;
			Session.DayNumber = DayIndex;
		EndDo;
		
	ElsIf Object.ScheduleType = PredefinedValue("Enum.WorkScheduleTypes.ShiftWork") Then
		
		Session = Object.DailySchedules.Add();
		Session.DayNumber = 1;
		Session.BeginTime = Date(1,1,1,0,0,0);
		Session.EndTime = Date(1,1,1,23,59,59);
		Session = Object.DailySchedules.Add();
		Session.DayNumber = 2;
		Session = Object.DailySchedules.Add();
		Session.DayNumber = 3;
		
	ElsIf Object.ScheduleType = PredefinedValue("Enum.WorkScheduleTypes.CalendarDays") Then
		
		Object.WorkweekDuration = 56;
		For DayIndex = 1 To 7 Do
			Session = Object.DailySchedules.Add();
			Session.BeginTime = Date(1,1,1,8,0,0);
			Session.EndTime = Date(1,1,1,16,0,0);
			Session.DayNumber = DayIndex;
		EndDo;
		
	EndIf;
	
EndProcedure

// The procedure displays the schedule.
//
&AtServer
Procedure DisplaySchedule()
	
	If Object.ScheduleType = Enums.WorkScheduleTypes.ShiftWork Then
		Items.GroupTimetableSchedulePanel.Visible = True;
		DisplayShiftWorkSchedule();
		Items.GroupTimetableSchedule.Enabled = True;
	ElsIf ValueIsFilled(Object.ScheduleType) Then
		Items.GroupTimetableSchedulePanel.Visible = False;
		DisplayScheduleByDaysOfWeek();
		Items.GroupTimetableSchedule.Enabled = True;
	Else
		Items.GroupTimetableSchedule.Enabled = False;
	EndIf;
	
EndProcedure

// The procedure displays the schedule of the week type.
//
&AtServer
Procedure DisplayScheduleByDaysOfWeek()
	
	TimetableSchedule.Clear();
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableSchedule");
	TemplateArea = TimetableScheduleTemplate.GetArea("Header");
	TemplateArea.Parameters.TextColumn = "Week days";
	TimetableSchedule.Put(TemplateArea);
	TemplateArea = TimetableScheduleTemplate.GetArea("Calendar");
	TimetableSchedule.Put(TemplateArea);
	
	ArrayHoursTotal = New Array(7);
	For Ct = 0 To 6 Do
		ArrayHoursTotal[Ct] = 0;
	EndDo;
	
	For Each Period In Object.DailySchedules Do
		For CurColumn = 1 To 96 Do
			CurEndOfPeriod = '00010101' + CurColumn * 900 - 1;
			CurBeginOfPeriod = CurEndOfPeriod - 899;
			TableRow = Period.DayNumber + HeaderHeight;
			TableColumn = CurColumn + 2;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			If CurBeginOfPeriod >= Period.BeginTime
			  AND CurEndOfPeriod <= Period.EndTime Then
				Area.BackColor = StyleColors.WorktimeCompletelyBusy;
			EndIf;
		EndDo;
		HoursTotal = Period.EndTime - Period.BeginTime;
		ArrayHoursTotal[Period.DayNumber - 1] = ArrayHoursTotal[Period.DayNumber - 1] + HoursTotal;
	EndDo;
	
	TimetableSchedule.FixedTop = HeaderHeight;
	TimetableSchedule.FixedLeft = 2;
	
	DisplayHoursTotalAtServer(7);
	
EndProcedure

// The procedure displays the schedule of the shift type.
//
&AtServer
Procedure DisplayShiftWorkSchedule()
	
	TimetableSchedule.Clear();
	
	TimetableScheduleTemplate = Catalogs.WorkSchedules.GetTemplate("TimetableSchedule");
	TemplateArea = TimetableScheduleTemplate.GetArea("Header");
	TemplateArea.Parameters.TextColumn = "Schedule day";
	TimetableSchedule.Put(TemplateArea);
	AreaRowOfShiftWorkCalendar = TimetableScheduleTemplate.GetArea("RowOfShiftWorkCalendar");
	
	NumbersOfDaysTable = Object.DailySchedules.Unload(, "DayNumber");
	NumbersOfDaysTable.GroupBy("DayNumber");
	NumbersOfDaysTable.Sort("DayNumber Asc");
	
	For Each CurRowDayNumber In NumbersOfDaysTable Do
		TimetableSchedule.Put(AreaRowOfShiftWorkCalendar);
		Area = TimetableSchedule.Area("R" + String(CurRowDayNumber.DayNumber + HeaderHeight) + "C1");
		Area.Text = "Day " + String(CurRowDayNumber.DayNumber);
	EndDo;
	
	For Each Period In Object.DailySchedules Do
		For CurColumn = 1 To 96 Do
			CurEndOfPeriod = '00010101' + CurColumn * 900 - 1;
			CurBeginOfPeriod = CurEndOfPeriod - 899;
			TableRow = Period.DayNumber + HeaderHeight;
			TableColumn = CurColumn + 2;
			Area = TimetableSchedule.Area("R" + TableRow + "C" + TableColumn);
			If CurBeginOfPeriod >= Period.BeginTime
			  AND CurEndOfPeriod <= Period.EndTime Then
				Area.BackColor = StyleColors.WorktimeCompletelyBusy;
			EndIf;
		EndDo;
	EndDo;
	
	TimetableSchedule.FixedTop = HeaderHeight;
	TimetableSchedule.FixedLeft = 2;
	
	DisplayHoursTotalAtServer(NumbersOfDaysTable.Count());
	
EndProcedure

// The procedure displays the number of hours on the server.
//
&AtServer
Procedure DisplayHoursTotalAtServer(DaysNumber)
	
	Object.WorkweekDuration = 0;
	WorkweekDuration = 0;
	
	If DaysNumber = 0 Then
		Return;
	EndIf;
	
	ArrayHoursTotal = New Array(DaysNumber);
	For Ct = 0 To DaysNumber - 1 Do
		ArrayHoursTotal[Ct] = 0;
	EndDo;
	
	For Each Period In Object.DailySchedules Do
		HoursTotal = ?(Period.EndTime = Date(1, 1, 1, 23, 59, 59), Period.EndTime + 1, Period.EndTime) - Period.BeginTime;
		HoursTotal = ?(HoursTotal < 0, 0, HoursTotal);
		If ArrayHoursTotal.Count() >= Period.DayNumber Then
			ArrayHoursTotal[Period.DayNumber - 1] = ArrayHoursTotal[Period.DayNumber - 1] + HoursTotal;
		EndIf;
		WorkweekDuration = WorkweekDuration + HoursTotal;
	EndDo;
	
	For Ct = 1 To DaysNumber Do
		If ArrayHoursTotal[Ct-1] >= 86399 Then
			HoursTotalString = "24:00";
		Else
			HoursTotalString = Format(Date(1, 1, 1, Int(ArrayHoursTotal[Ct-1] / 3600), (ArrayHoursTotal[Ct-1] / 3600 - Int(ArrayHoursTotal[Ct-1] / 3600)) * 60, 0), "DF=HH:mm");
		EndIf;
		Area = TimetableSchedule.Area("R" + String(Ct + HeaderHeight) + "C2");
		Area.Text = ?(ValueIsFilled(HoursTotalString), HoursTotalString, "00:00");
	EndDo;
	
	Object.WorkweekDuration = WorkweekDuration / 3600;
	
EndProcedure

// The procedure displays the number of hours on the client.
//
&AtClient
Procedure DisplayHoursTotalAtClient(DaysNumber)
	
	Object.WorkweekDuration = 0;
	WorkweekDuration = 0;
	
	If DaysNumber = 0 Then
		Return;
	EndIf;
	
	ArrayHoursTotal = New Array(DaysNumber);
	For Ct = 0 To DaysNumber - 1 Do
		ArrayHoursTotal[Ct] = 0;
	EndDo;
	
	For Each Period In Object.DailySchedules Do
		HoursTotal = ?(Period.EndTime = Date(1, 1, 1, 23, 59, 59), Period.EndTime + 1, Period.EndTime) - Period.BeginTime;
		HoursTotal = ?(HoursTotal < 0, 0, HoursTotal);
		If ArrayHoursTotal.Count() >= Period.DayNumber Then
			ArrayHoursTotal[Period.DayNumber - 1] = ArrayHoursTotal[Period.DayNumber - 1] + HoursTotal;
		EndIf;
		WorkweekDuration = WorkweekDuration + HoursTotal;
	EndDo;
	
	For Ct = 1 To DaysNumber Do
		If ArrayHoursTotal[Ct-1] >= 86399 Then
			HoursTotalString = "24:00";
		Else
			HoursTotalString = Format(Date(1, 1, 1,Int(ArrayHoursTotal[Ct-1] / 3600), (ArrayHoursTotal[Ct-1] / 3600 - Int(ArrayHoursTotal[Ct-1] / 3600)) * 60, 0), "DF=HH:mm");
		EndIf;
		Area = TimetableSchedule.Area("R" + String(Ct + HeaderHeight) + "C2");
		Area.Text = ?(ValueIsFilled(HoursTotalString), HoursTotalString, "00:00");
	EndDo;
	
	Object.WorkweekDuration = WorkweekDuration / 3600;
	
EndProcedure

// The function returns the number of days in the schedule.
&AtClient
Function GetNumberOfDaysOfSchedule()
	
	If String(Object.ScheduleType) = "Shift work" Then
		CountOfArrayItems = Object.DailySchedules.Count();
		If CountOfArrayItems = 0 Then
			Return 0;
		EndIf;
		CountOfDifferentArrayItems = 1;
		For DayNumber = 1 To CountOfArrayItems - 1 Do
			Ct = DayNumber + 1;
			While Ct <= CountOfArrayItems AND Object.DailySchedules[DayNumber - 1].DayNumber <> Object.DailySchedules[Ct - 1].DayNumber Do
				Ct = Ct + 1;
				If Ct = CountOfArrayItems + 1 Then
					CountOfDifferentArrayItems = CountOfDifferentArrayItems + 1;
				EndIf;
			EndDo
		EndDo;
		Return CountOfDifferentArrayItems;
	ElsIf ValueIsFilled(Object.ScheduleType) Then
		Return 7;
	Else
		Return 0;
	EndIf;
	
EndFunction

// The procedure fills in the periods by the schedule.
//
&AtClient
Procedure FillPeriodsByTimetableSchedule(DaysNumber)
	
	Object.DailySchedules.Clear();
	IntervalIsOpened = False;
	
	For CurRow = HeaderHeight + 1 To DaysNumber + HeaderHeight Do
		
		EmptyDay = True;
		
		For CurColumn = 3 To 98 Do
			
			Area = TimetableSchedule.Area("R" + CurRow + "C" + CurColumn);
			If Area.BackColor = BusyPeriodColor Then
				If Not IntervalIsOpened Then
					IntervalIsOpened = True;
					NewRow = Object.DailySchedules.Add();
					NewRow.DayNumber = CurRow - HeaderHeight;
					NewRow.BeginTime = '00010101' + (CurColumn - 3) * 900;
					EmptyDay = False;
				EndIf;
			Else
				If IntervalIsOpened Then
					IntervalIsOpened = False;
					NewRow.EndTime = '00010101' + (CurColumn - 3) * 900;
				EndIf;
			EndIf;
			
			If CurColumn = 98 AND IntervalIsOpened Then
				IntervalIsOpened = False;
				NewRow.EndTime = '00010101' + 86399;
			EndIf;
			
		EndDo;
		
		If EmptyDay Then
			
			NewRow = Object.DailySchedules.Add();
			NewRow.DayNumber = CurRow - HeaderHeight;
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Procedure sets the color for the selected areas.
//
&AtClient
Procedure SetBackColorForChoosedAreas(DaysNumber, Color)
	
	SelectedAreas = TimetableSchedule.SelectedAreas;
	
	For Each CurArea In SelectedAreas Do
		
		If TypeOf(CurArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For CurRow = CurArea.Top To CurArea.Bottom Do
			For CurColumn = CurArea.Left To CurArea.Right Do
				If CurColumn >= 3 AND CurColumn <= 98 AND CurRow >= HeaderHeight + 1 AND CurRow <= DaysNumber + HeaderHeight Then
					Area = TimetableSchedule.Area("R" + CurRow + "C" + CurColumn);
					Area.BackColor = Color;
				EndIf;
			EndDo;
		EndDo;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	HeaderHeight = 3;
	
	FillTemplate = Object.ScheduleType;
	
	If ValueIsFilled(Object.Ref) Then
		Color = Object.Ref.Color.Get();
	Else
		CopyingValue = Undefined;
		Parameters.Property("CopyingValue", CopyingValue);
		If CopyingValue <> Undefined Then
			Color = CopyingValue.Color.Get();
		Else
			Color = New Color(0, 0, 0);
		EndIf;
	EndIf;
	
	BusyPeriodColor = StyleColors.WorktimeCompletelyBusy;
	ColorOfFreePeriod = StyleColors.WorktimeFreeAvailable;
	
	If Not ValueIsFilled(Object.BeginnigDate) Then
		Object.BeginnigDate = CurrentDate();
	EndIf;
		
	DisplaySchedule();
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("WritingWorkSchedule");
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.Color = New ValueStorage(Color);
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - Fill click handler.
//
&AtClient
Procedure Fill(Command)
	
	FillByTemplate();
	
EndProcedure

// Procedure - MarkSelectedAsWorking click handler.
//
&AtClient
Procedure MarkSelectedAsWorking(Command)
	
	DaysNumber = GetNumberOfDaysOfSchedule();
	SetBackColorForChoosedAreas(DaysNumber, BusyPeriodColor);
	FillPeriodsByTimetableSchedule(DaysNumber);
	DisplayHoursTotalAtClient(DaysNumber);
	
EndProcedure

// Procedure - handler of clicking the MarkSelectedAsNonWorking button.
//
&AtClient
Procedure MarkSelectedAsNonWorking(Command)
	
	DaysNumber = GetNumberOfDaysOfSchedule();
	SetBackColorForChoosedAreas(DaysNumber, ColorOfFreePeriod);
	FillPeriodsByTimetableSchedule(DaysNumber);
	DisplayHoursTotalAtClient(DaysNumber);
	
EndProcedure

// Procedure - AddDayToSchedule click handler .
//
&AtClient
Procedure AddDayToSchedule(Command)
	
	DaysNumber = GetNumberOfDaysOfSchedule();
	NewPeriod = Object.DailySchedules.Add();
	NewPeriod.DayNumber = DaysNumber + 1;
	DisplaySchedule();
	
EndProcedure

// Procedure - RemoveDayFromSchedule click handler.
//
&AtClient
Procedure RemoveDayFromSchedule(Command)
	
	DaysNumber = GetNumberOfDaysOfSchedule();
	SelectedAreas = TimetableSchedule.SelectedAreas;
	
	For Each CurArea In SelectedAreas Do
		
		If TypeOf(CurArea) <> Type("SpreadsheetDocumentRange") Then
			Continue;
		EndIf;
		
		For CurRow = CurArea.Top To CurArea.Bottom Do
			If CurRow >= HeaderHeight + 1 AND CurRow <= DaysNumber + HeaderHeight Then
				FilterParameters = New Structure;
				FilterParameters.Insert("DayNumber", CurRow - HeaderHeight);
				RowToDeleteArray = Object.DailySchedules.FindRows(FilterParameters);
				For Each RemovedRow In RowToDeleteArray Do
					Object.DailySchedules.Delete(RemovedRow);
				EndDo;
			EndIf;
		EndDo;
		
	EndDo;
	
	If Object.DailySchedules.Count() = 0 Then
		DisplaySchedule();
		Return;
	EndIf;
	
	Object.DailySchedules.Sort("DayNumber Asc");
	
	NumberOfPreviousDay = Object.DailySchedules[0].DayNumber;
	
	If NumberOfPreviousDay > 1 Then
		For Each CurRow In Object.DailySchedules Do
			CurRow.DayNumber = CurRow.DayNumber - NumberOfPreviousDay + 1;
		EndDo;
	EndIf;
	
	If Object.DailySchedules.Count() > 1 Then
		For Ct = 1 To Object.DailySchedules.Count() - 1 Do
			If Object.DailySchedules[Ct].DayNumber - NumberOfPreviousDay > 1 Then
				Object.DailySchedules[Ct].DayNumber = Object.DailySchedules[Ct].DayNumber - NumberOfPreviousDay + 1;
			Else
				NumberOfPreviousDay = Object.DailySchedules[Ct].DayNumber;
			EndIf;
		EndDo;
	EndIf;
	
	DisplaySchedule();
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - OnChange event handler of the FillTemplate field.
//
&AtClient
Procedure FillTemplateOnChange(Item)
	
	If Not ValueIsFilled(FillTemplate) Then
		FillByTemplate();
		DisplaySchedule();
	ElsIf ValueIsFilled(FillTemplate)
		AND FillTemplate <> Object.ScheduleType Then
		
		Mode			= QuestionDialogMode.YesNo;
		Text			= NStr("en = 'Schedule type is changed. The template will be refilled.'");
		Notification	= New NotifyDescription("FillTemplateOnChangeEnd", ThisForm);
		
		ShowQueryBox(Notification, Text, Mode);
		
	EndIf;
	
	FillTemplate = Object.ScheduleType;
	
EndProcedure

&AtClient
Procedure FillTemplateOnChangeEnd(Response,Parameters) Export

	If Response = DialogReturnCode.Yes Then
		FillByTemplate();
		DisplaySchedule();
	Else
		Object.ScheduleType = FillTemplate;
	EndIf;
	
	FillTemplate = Object.ScheduleType;
	
EndProcedure

// Procedure - SelectionStart event handler of the FillTemplate field.
//
&AtClient
Procedure FillTemplateStartChoice(Item, ChoiceData, StandardProcessing)
	
	FillTemplate = Object.ScheduleType;
	
EndProcedure

#EndRegion

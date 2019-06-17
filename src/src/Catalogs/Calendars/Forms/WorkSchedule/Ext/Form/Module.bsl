
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	DailySchedule = Parameters.WorkSchedule;
	
	For Each DetailsOfInterval In DailySchedule Do
		FillPropertyValues(WorkSchedule.Add(), DetailsOfInterval);
	EndDo;
	WorkSchedule.Sort("BeginTime");
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	Notification = New NotifyDescription("ChooseAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel, Exit);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	ChooseAndClose();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	Modified = False;
	NotifyChoice(Undefined);
	
EndProcedure

#Region FormItemsEventsHandlers

&AtClient
Procedure WorkScheduleOnEditEnd(Item, NewRow, CancelEdit)
		
	If CancelEdit Then
		Return;
	EndIf;
	
	WorkSchedulesClientServer.RestoreOrderRowsCollectionsAfterEditing(WorkSchedule, "BeginTime", Item.CurrentData);
	
EndProcedure

#EndRegion

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function DailySchedule()
	
	Cancel = False;
	
	DailySchedule = New Array;
	
	EndOfDay = Undefined;
	
	For Each TimetableString In WorkSchedule Do
		RowIndex = WorkSchedule.IndexOf(TimetableString);
		If TimetableString.BeginTime > TimetableString.EndTime 
			AND ValueIsFilled(TimetableString.EndTime) Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Start time is greater than the end time.'"), ,
				StringFunctionsClientServer.SubstituteParametersInString("WorkSchedule[%1].EndTime", RowIndex), ,
				Cancel);
		EndIf;
		If TimetableString.BeginTime = TimetableString.EndTime Then
			CommonUseClientServer.MessageToUser(
				NStr("en = 'Interval duration is not specified'"), ,
				StringFunctionsClientServer.SubstituteParametersInString("WorkSchedule[%1].EndTime", RowIndex), ,
				Cancel);
		EndIf;
		If EndOfDay <> Undefined Then
			If EndOfDay > TimetableString.BeginTime 
				Or Not ValueIsFilled(EndOfDay) Then
				CommonUseClientServer.MessageToUser(
					NStr("en = 'Overlapping intervals are detected'"), ,
					StringFunctionsClientServer.SubstituteParametersInString("WorkSchedule[%1].BeginTime", RowIndex), ,
					Cancel);
			EndIf;
		EndIf;
		EndOfDay = TimetableString.EndTime;
		DailySchedule.Add(New Structure("BeginTime, EndTime", TimetableString.BeginTime, TimetableString.EndTime));
	EndDo;
	
	If Cancel Then
		Return Undefined;
	EndIf;
	
	Return DailySchedule;
	
EndFunction

&AtClient
Procedure ChooseAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	DailySchedule = DailySchedule();
	If DailySchedule = Undefined Then
		Return;
	EndIf;
	
	Modified = False;
	NotifyChoice(New Structure("WorkSchedule", DailySchedule));
	
EndProcedure

#EndRegion

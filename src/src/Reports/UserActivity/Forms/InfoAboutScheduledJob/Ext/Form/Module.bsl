﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Report = Parameters.Report;
	ScheduledJobID = Parameters.ScheduledJobID;
	Title = Parameters.Title;
	
	If CommonUse.SubsystemExists("StandardSubsystems.ScheduledJobs") Then
		SubsystemScheduledJobsExist = True;
		Items.ChangeSchedule.Visible = True;
	Else
		Items.ChangeSchedule.Visible = False;
	EndIf;
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure ReportDetailsProcessing(Item, Details, StandardProcessing)
	
	StandardProcessing = False;
	StartDate = Details.Get(0);
	EndDate = Details.Get(1);
	SessionScheduledJobs.Clear();
	SessionScheduledJobs.Add(Details.Get(2)); 
	EventLogMonitorFilter = New Structure("Session, StartDate, EndDate", SessionScheduledJobs, StartDate, EndDate);
	OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", EventLogMonitorFilter);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ConfigureScheduleJobSchedule(Command)
	
	If ValueIsFilled(ScheduledJobID) Then
		
		Dialog = New ScheduledJobDialog(GetSchedule());
		
		NotifyDescription = New NotifyDescription("ConfigureScheduledJobScheduleEnd", ThisObject);
		Dialog.Show(NotifyDescription);
		
	Else
		ShowMessageBox(,NStr("en = 'Cannot get job schedule. The scheduled job might have been deleted or its name was not specified.'"));
	EndIf;
	
EndProcedure

&AtClient
Procedure GoToEventLogMonitor(Command)
	
	For Each Area In Report.SelectedAreas Do
		Details = Area.Details;
		If Details = Undefined
			OR Area.Top <> Area.Bottom Then
			ShowMessageBox(,NStr("en = 'Select a line or cell of the required job session'"));
			Return;
		EndIf;
		StartDate = Details.Get(0);
		EndDate = Details.Get(1);
		SessionScheduledJobs.Clear();
		SessionScheduledJobs.Add(Details.Get(2));
		EventLogMonitorFilter = New Structure("Session, StartDate, EndDate", SessionScheduledJobs, StartDate, EndDate);
		OpenForm("DataProcessor.EventLogMonitor.Form.EventLogMonitor", EventLogMonitorFilter);
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function GetSchedule()
	
	SetPrivilegedMode(True);
	
	ModuleScheduledJobsServer = CommonUse.CommonModule("ScheduledJobsServer");
	Return ModuleScheduledJobsServer.GetJobSchedule(
		ScheduledJobID);
	
EndFunction

&AtClient
Procedure ConfigureScheduledJobScheduleEnd(Schedule, AdditionalParameters) Export
	
	If Schedule <> Undefined Then
		SetJobSchedule(Schedule);
	EndIf;
	
EndProcedure

&AtServer
Procedure SetJobSchedule(Schedule)
	
	SetPrivilegedMode(True);
	
	ModuleScheduledJobsServer = CommonUse.CommonModule("ScheduledJobsServer");
	ModuleScheduledJobsServer.SetJobSchedule(
		ScheduledJobID,
		Schedule);
	
EndProcedure

#EndRegion

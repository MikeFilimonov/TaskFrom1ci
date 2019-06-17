#Region Variables

&AtClient
Var HandlerParameters;

#EndRegion

#Region EventHandlers

&AtClient
Procedure OnOpen(Cancel)
	Items.Pages.CurrentPage = Items.PageDescription;
	SetChangesInForm();
EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure Next(Command)
	
	If Items.Pages.CurrentPage = Items.PageResult Then
		Close();
	Else
		Items.Pages.CurrentPage = Items.PageFilling;
		AttachIdleHandler("Filling", 1, True);
	EndIf;
	
	SetChangesInForm();
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	If ValueIsFilled(BackgroundJobID) Then
		TerminateBackgroundJob(BackgroundJobID);
	EndIf;
	
	Close();
	
EndProcedure

&AtClient
Procedure InformationTextURLProcessing(Item, FormattedStringURL, StandardProcessing)
	StandardProcessing = False;
	OpenForm("DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledAndBackgroundJobs");
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure Filling()
	FillData();
EndProcedure

&AtClient
Procedure FillData()
	
	LoadingParameters = New Map();
	LoadingParameters.Insert("MessageText", "");
	LoadingParameters.Insert("LoadingIsCompleted", False);
	
	Result = RunBackgroundJob(LoadingParameters);
	
	StorageAddress = Result.StorageAddress;
	If Not Result.JobCompleted Then
		BackgroundJobID = Result.JobID;
		
		LongActionsClient.InitIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler("Attachable_CheckBackgroundJob", 1, True);
	Else
		LoadResult();
	EndIf;
	
EndProcedure

&AtServer
Procedure SetChangesInForm()
	
	If Items.Pages.CurrentPage = Items.PageDescription Then
		Items.FormNext.Title = NStr("en = 'Begin posting >>'");
		Items.FormNext.Enabled = True;
		Items.FormCancel.Enabled = True;
	ElsIf Items.Pages.CurrentPage = Items.PageFilling Then
		Items.FormNext.Visible = False;
		Items.FormCancel.Enabled = True;
	Else
		Items.FormNext.Title = NStr("en = 'Finish'");
		Items.FormNext.Enabled = True;
		Items.FormNext.Visible = True;
		Items.FormCancel.Visible = False;
	EndIf;
	
EndProcedure

&AtClient
Procedure LoadResult()
	
	Result = GetFromTempStorage(StorageAddress);
	
	EventName = NStr("en = 'FIFO. Posting documents on the ""Inventory cost layer"" register.'");
	
	If Result["LoadingIsCompleted"] Then
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventName,, Result["MessageText"],, True);
		EnableFIFO();
	Else
		EventLogMonitorClient.AddMessageForEventLogMonitor(EventName, "Error", Result["MessageText"],, True);
	EndIf;
	
	Items.Pages.CurrentPage = Items.PageResult;
	
	SetChangesInForm();
	
EndProcedure

&AtServerNoContext
Procedure EnableFIFO()
	Constants.UseFIFO.Set(True);
EndProcedure

#Region BackgroundJob

&AtServer
Function RunBackgroundJob(Parameters)
	
	If CommonUse.FileInfobase() Then
		StorageAddress = PutToTempStorage(Undefined, UUID);
		DataProcessors.FillCostLayerRegisters.Posting(Parameters, StorageAddress);
		Result = New Structure("JobCompleted, StorageAddress", True, StorageAddress);
	Else
		BackgroundJob = NStr("en = 'The documents is posting on the ""Inventory cost layer"" register.'");
		
		Result = LongActions.ExecuteInBackground(
			UUID,
			"DataProcessors.FillCostLayerRegisters.Posting",
			Parameters,
			BackgroundJob);
	EndIf;
	
	Return Result;
	
EndFunction

&AtServerNoContext
Procedure TerminateBackgroundJob(BackgroundJobID)
	
	BackgroundJob = BackgroundJobs.FindByUUID(BackgroundJobID);
	If BackgroundJob <> Undefined Then
		BackgroundJob.Cancel();
	EndIf;
	
EndProcedure

&AtClient
Procedure Attachable_CheckBackgroundJob()
	
	If BackgroundJobIsCompleted(BackgroundJobID) Then
		LoadResult();
	Else
		LongActionsClient.UpdateIdleHandlerParameters(HandlerParameters);
		AttachIdleHandler(
			"Attachable_CheckBackgroundJob",
			HandlerParameters.CurrentInterval,
			True);
	EndIf;
	
EndProcedure

&AtServerNoContext
Function BackgroundJobIsCompleted(BackgroundJobID)
	Return LongActions.JobCompleted(BackgroundJobID);
EndFunction

#EndRegion

#EndRegion
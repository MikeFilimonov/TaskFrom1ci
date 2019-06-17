
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	EndPointConnectionEventLogMonitorMessageText = MessageExchangeInternal.EndPointConnectionEventLogMonitorMessageText();
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(ThisObject);
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	WarningText = NStr("en = 'Do you want to cancel connection to the endpoint?'");
	Notification = New NotifyDescription("ConnectAndClose", ThisObject);
	CommonUseClient.ShowFormClosingConfirmation(Notification, Cancel, Exit, WarningText);
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure ToConnectEndPoint(Command)
	
	ConnectAndClose();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure ConnectAndClose(Result = Undefined, AdditionalParameters = Undefined) Export
	
	Status(NStr("en = 'Connecting the end point. Please wait...'"));
	
	Cancel = False;
	FillError = False;
	
	ConnectEndPointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en = 'There were errors when connecting to the end point.
		               |Do you want to open the event log?'");
		NotifyDescription = New NotifyDescription("OpenEventLogMonitor", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessageExchangeClient.EndPointAddedEventName());
	
	ShowUserNotification(,,NStr("en = 'Connection of endpoint successfully completed.'"));
	
	Modified = False;
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenEventLogMonitor(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMonitorEvent", EndPointConnectionEventLogMonitorMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ConnectEndPointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	MessageExchange.ToConnectEndPoint(
		Cancel,
		SenderSettingsWSURLWebService,
		SenderSettingsWSUserName,
		SenderSettingsWSPassword,
		RecipientSettingsWSURLWebService,
		RecipientSettingsWSUserName,
		RecipientSettingsWSPassword);
	
EndProcedure

#EndRegion

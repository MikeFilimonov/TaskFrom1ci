
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;

	LeadingEndPointSettingEventLogMonitorMessageText = MessageExchangeInternal.LeadingEndPointSettingEventLogMonitorMessageText();
	
	EndPoint = Parameters.EndPoint;
	
	// Read connection setting values.
	FillPropertyValues(ThisObject, InformationRegisters.ExchangeTransportSettings.TransportSettingsWS(EndPoint));
	
	Title = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = 'Set leading endpoint for ""%1""'"),
		CommonUse.ObjectAttributeValue(EndPoint, "Description"));
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)	
	
	If Exit Then
		WarningText = NStr("en = 'Operation will be terminated'"); 			
		Return;			
	EndIf;
	
	WarningText = NStr("en = 'Do you want to cancel operation?'");
	CommonUseClient.ShowArbitraryFormClosingConfirmation(
		ThisObject, Cancel, Exit, WarningText, "ForceCloseForm");
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Set(Command)
	
	Status(NStr("en = 'Setting the leading endpoint. Please wait...'"));
	
	Cancel = False;
	FillError = False;
	
	SetLeadingEndPointAtServer(Cancel, FillError);
	
	If FillError Then
		Return;
	EndIf;
	
	If Cancel Then
		
		NString = NStr("en = 'Errors occurred when setting the leading end point.
		               |Do you want to open the event log?'");
		NotifyDescription = New NotifyDescription("OpenEventLogMonitor", ThisObject);
		ShowQueryBox(NotifyDescription, NString, QuestionDialogMode.YesNo, ,DialogReturnCode.No);
		Return;
	EndIf;
	
	Notify(MessageExchangeClient.EventNameLeadingEndPointSet());
	
	ShowUserNotification(,, NStr("en = 'Leading endpoint is set successfully.'"));
	
	ForceCloseForm = True;
	
	Close();
	
EndProcedure

&AtClient
Procedure OpenEventLogMonitor(Response, AdditionalParameters) Export
	
	If Response = DialogReturnCode.Yes Then
		
		Filter = New Structure;
		Filter.Insert("EventLogMonitorEvent", LeadingEndPointSettingEventLogMonitorMessageText);
		OpenForm("DataProcessor.EventLogMonitor.Form", Filter, ThisObject);
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetLeadingEndPointAtServer(Cancel, FillError)
	
	If Not CheckFilling() Then
		FillError = True;
		Return;
	EndIf;
	
	WSConnectionSettings = DataExchangeServer.WSParameterStructure();
	
	FillPropertyValues(WSConnectionSettings, ThisObject);
	
	MessageExchangeInternal.SetLeadingEndPointAtSender(Cancel, WSConnectionSettings, EndPoint);
	
EndProcedure

#EndRegion

﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Skipping the initialization to guarantee that the form will be received if the AutoTest parameter is passed.
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	PatternData = Parameters.PatternData;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	// Peripherals
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		ErrorDescription = "";

		SupporTypesVO = New Array();
		SupporTypesVO.Add("MagneticCardReader");

		If Not EquipmentManagerClient.ConnectEquipmentByType(UUID, SupporTypesVO, ErrorDescription) Then
			MessageText = NStr("en = 'An error occurred while
			                   |connecting peripherals: ""%ErrorDescription%"".'");
			MessageText = StrReplace(MessageText, "%ErrorDescription%", ErrorDescription);
			CommonUseClientServer.MessageToUser(MessageText);
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure OnClose(Exit)
	// Peripherals
	SupporTypesVO = New Array();
	SupporTypesVO.Add("MagneticCardReader");

	EquipmentManagerClient.DisableEquipmentByType(UUID, SupporTypesVO);
	// End Peripherals
EndProcedure

&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "TracksData" Then
			If Parameter[1] = Undefined Then
				TracksData = Parameter[0];
			Else
				TracksData = Parameter[1][1];
			EndIf;
			
			ClearMessages();
			If Not EquipmentManagerClient.CodeCorrespondsToMCTemplate(TracksData, PatternData) Then
				CommonUseClientServer.MessageToUser(NStr("en = 'The card does not match template.'"));
				Return;
			EndIf;
			
			// Display encrypted fields
			If Parameter[1][3] = Undefined
				OR Parameter[1][3].Count() = 0 Then
				CommonUseClientServer.MessageToUser(NStr("en = 'Failed to identify any field. Maybe, template fields configured incorrectly.'"));
			Else
				TemplateFound = Undefined;
				For Each curTemplate In Parameter[1][3] Do
					If curTemplate.Pattern = PatternData.Ref Then
						TemplateFound = curTemplate;
					EndIf;
				EndDo;
				If TemplateFound = Undefined Then
					CommonUseClientServer.MessageToUser(NStr("en = 'The code does not match this template. Maybe, the template is configured incorrectly.'"));
				Else
					MessageText = NStr("en = 'The card matches the template and contains the following fields:'")+Chars.LF+Chars.LF;
					Iterator = 1;
					For Each curField In TemplateFound.TracksData Do
						MessageText = MessageText + String(Iterator)+". "+?(ValueIsFilled(curField.Field), String(curField.Field), "")+" = "+String(curField.FieldValue)+Chars.LF;
						Iterator = Iterator + 1;
					EndDo;
					ShowMessageBox(,MessageText, , NStr("en = 'Card code decryption result'"));
				EndIf;
			EndIf;
			
		EndIf;
	EndIf;
	// End Peripherals
EndProcedure

&AtClient
Procedure ExternalEvent(Source, Event, Data)
	
	If IsInputAvailable() Then
		
		DetailsEvents = New Structure();
		ErrorDescription  = "";
		DetailsEvents.Insert("Source", Source);
		DetailsEvents.Insert("Event",  Event);
		DetailsEvents.Insert("Data",   Data);
		
		Result = EquipmentManagerClient.GetEventFromDevice(DetailsEvents, ErrorDescription);
		If Result = Undefined Then 
			MessageText = NStr("en = 'An error occurred during the processing of external event from the device:'")
								+ Chars.LF + ErrorDescription;
			CommonUseClientServer.MessageToUser(MessageText);
		Else
			NotificationProcessing(Result.EventName, Result.Parameter, Result.Source);
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion
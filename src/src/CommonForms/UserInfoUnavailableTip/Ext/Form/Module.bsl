﻿
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	MessagePattern = NStr("en = 'You can not view the information on the %1 user as 
	                      |this is a service account which is provided for the service administrators.'");
	Items.SharedUser.Title = 
		StringFunctionsClientServer.SubstituteParametersInString(MessagePattern, Parameters.Key.Description);
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// MessageExchangeClient: the mechanism of the exchange messages.
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// Executes sending and receiving of system messages.
// 
Procedure SendAndReceiveMessages() Export
	
	Status(NStr("en = 'Sending and receiving messages.'"),,
			NStr("en = 'Please wait...'"), PictureLib.Information32);
	
	Cancel = False;
	
	MessageExchangeServerCall.SendAndReceiveMessages(Cancel);
	
	If Cancel Then
		
		Status(NStr("en = 'Errors occurred when sending and receiving messages.'"),,
				NStr("en = 'Use the event log to diagnose errors.'"), PictureLib.Error32);
		
	Else
		
		Status(NStr("en = 'Sending and receiving messages successfully completed.'"),,, PictureLib.Information32);
		
	EndIf;
	
	Notify(EventNameMessagesSendingAndReceivingPerformed());
	
EndProcedure

// Only for internal use.
//
// Returns:
// Row. 
//
Function EndPointAddedEventName() Export
	
	Return "MessageExchange.EndPointAdded";
	
EndFunction

// Only for internal use.
//
// Returns:
// Row. 
//
Function EventNameMessagesSendingAndReceivingPerformed() Export
	
	Return "MessageExchange.SendAndReceiveExecuted";
	
EndFunction

// Only for internal use.
//
// Returns:
// Row. 
//
Function EndPointFormClosedEventName() Export
	
	Return "MessageExchange.EndPointFormClosed";
	
EndFunction

// Only for internal use.
//
// Returns:
// Row. 
//
Function EventNameLeadingEndPointSet() Export
	
	Return "MessageExchange.LeadingEndPointSet";
	
EndFunction

#EndRegion

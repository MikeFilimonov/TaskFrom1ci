////////////////////////////////////////////////////////////////////////////////
// Subsystem "BaseFunctionality".
//
////////////////////////////////////////////////////////////////////////////////

#Region InternalInterface

// See IntegrationWith1CConnectClient.NotificationProcessing()
//
Procedure IntegrationWith1CConnectClientNotificationProcessing(EventName, Item) Export
	
	IntegrationWith1CConnectClient.NotificationProcessing(EventName, Item);
	
EndProcedure

#EndRegion

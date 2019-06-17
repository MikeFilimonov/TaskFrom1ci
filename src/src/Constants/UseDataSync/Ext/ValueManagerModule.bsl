#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	If Value = True Then
		
		DataSeparationEnabled = CommonUseReUse.DataSeparationEnabled();
		Constants.UseDataSyncInLocalMode.Set(NOT DataSeparationEnabled);
		Constants.UseDataSyncSaaS.Set(DataSeparationEnabled);
		
	Else
		
		Constants.UseDataSyncInLocalMode.Set(False);
		Constants.UseDataSyncSaaS.Set(False);
		
	EndIf;
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Value = True Then
		DataExchangeServer.OnDataSynchronizationEnabling(Cancel);
	Else
		DataExchangeServer.OnDataSynchronizationDisabling(Cancel);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
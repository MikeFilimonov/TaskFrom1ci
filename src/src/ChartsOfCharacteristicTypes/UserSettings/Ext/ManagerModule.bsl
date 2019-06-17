#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region UpdateHandlers

Procedure ProcessDataToUpgradeToNewVersion() Export
	
	// MarkBankPaymentsAsPaid
	Count = CountOfItemsWithCode(ChartsOfCharacteristicTypes.UserSettings.MarkBankPaymentsAsPaid.Code);
	If Count > 1 Then
		
		ChangedSetting = ChartsOfCharacteristicTypes.UserSettings.MarkBankPaymentsAsPaid.GetObject();
		ChangedSetting.SetNewCode();
		Try
			ChangedSetting.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error on write user setting MarkBankPaymentsAsPaid: %1'"),
			BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
			"InfobaseUpdate",
			EventLogLevel.Error,
			Metadata.ChartsOfCharacteristicTypes.UserSettings,
			,
			ErrorDescription);
		EndTry;
		
	EndIf;
	
	// ShowLeadConversionMessage
	Count = CountOfItemsWithCode(ChartsOfCharacteristicTypes.UserSettings.ConvertLeadWithoutMessage.Code);
	If Count > 1 Then
		
		ChangedSetting = ChartsOfCharacteristicTypes.UserSettings.ConvertLeadWithoutMessage.GetObject();
		ChangedSetting.SetNewCode();
		Try
			ChangedSetting.Write();
		Except
			ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'Error on write user setting ConvertLeadWithoutMessage: %1'"),
			BriefErrorDescription(ErrorInfo()));
			
			WriteLogEvent(
			"InfobaseUpdate",
			EventLogLevel.Error,
			Metadata.ChartsOfCharacteristicTypes.UserSettings,
			,
			ErrorDescription);
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function CountOfItemsWithCode(SearchCode)
	
	Count = 0;
	
	Query = New Query;
	Query.Text = 
		"SELECT
		|	COUNT(DISTINCT UserSettings.Ref) AS Count
		|FROM
		|	ChartOfCharacteristicTypes.UserSettings AS UserSettings
		|WHERE
		|	UserSettings.Code = &Code";
	
	Query.SetParameter("Code", SearchCode);
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		Count = SelectionDetailRecords.Count;
	EndIf;
	
	Return Count;
	
EndFunction

#EndRegion

#EndIf

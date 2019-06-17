
#Region EventHadlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	FillingValues = New Structure("Kind", CommandParameter);
	OpenForm("InformationRegister.ContactInformationVisibilitySettings.Form.EditingKindSettings",
		New Structure("Key,FillingValues", RecordKey(CommandParameter), FillingValues),
		CommandExecuteParameters.Source,
		CommandExecuteParameters.Uniqueness,
		CommandExecuteParameters.Window);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&НаСервере
Function RecordKey(Kind)
	
	Query = New Query;
	Query.Text = "SELECT
	             |	ContactInformationVisibilitySettings.Kind
	             |FROM
	             |	InformationRegister.ContactInformationVisibilitySettings AS ContactInformationVisibilitySettings
	             |WHERE
	             |	ContactInformationVisibilitySettings.Kind = &Kind";
	
	Query.SetParameter("Kind", Kind);
	If Query.Execute().IsEmpty() Then
		Return Undefined;
	EndIf;
	
	RecordKeyData = New Structure("Kind", Kind);
	Return InformationRegisters.ContactInformationVisibilitySettings.CreateRecordKey(RecordKeyData);
	
EndFunction

#EndRegion

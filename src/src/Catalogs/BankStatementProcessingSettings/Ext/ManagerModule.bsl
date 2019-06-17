#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

Procedure UpdateSettingsFromDataProcessor(SettingObject, DataProcessorRef) Export
	
	DataProc				= AdditionalReportsAndDataProcessors.GetObjectOfExternalDataProcessor(DataProcessorRef);
	SettingsFromDataProc	= DataProc.OnDefineSettings();
	
	FillPropertyValues(SettingObject, SettingsFromDataProc);
	
	TS = SettingObject.AdditionalSettings;
	TS.Clear();
	
	If SettingsFromDataProc.Property("AdditionalSettings") Then
		
		For Each AdditionalSetting In SettingsFromDataProc.AdditionalSettings Do
			
			NewSetting = TS.Add();
			NewSetting.Setting			= AdditionalSetting.Key;
			NewSetting.Value			= AdditionalSetting.Value;
			NewSetting.DefaultValue		= AdditionalSetting.Value;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Function GetAdditionalSettingsStructure(Ref) Export
	
	ReturnStructure = New Structure;
	
	For Each Row In Ref.AdditionalSettings Do
		ReturnStructure.Insert(Row.Setting, Row.Value);
	EndDo;
	
	Return ReturnStructure;
	
EndFunction

#EndRegion

#EndIf
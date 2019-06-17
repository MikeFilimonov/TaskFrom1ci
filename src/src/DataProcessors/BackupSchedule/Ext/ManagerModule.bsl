#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
		StandardProcessing = False;
		
		SetPrivilegedMode(True);
		
		Versions = GetWebServiceVersions();
		
		If Versions.Find("1.0.2.1") <> Undefined Then
			
			SelectedForm = "SettingWithIntervals";
			
			DataArea = CommonUse.SessionSeparatorValue();
			
			AdditionalParameters = DataAreasBackupDataFormsInterface.
			GetFormParametersSettings(DataArea);
			For Each KeyAndValue In AdditionalParameters Do
				Parameters.Insert(KeyAndValue.Key, KeyAndValue.Value);
			EndDo;
			
		ElsIf DataAreasBackupReUse.ServiceManagerSupportsBackup() Then
			
			SelectedForm = "SettingWithoutIntervals";
			
		Else
			Raise(NStr("en = 'Service manager does not support application backup'"));
		EndIf;
		
	#Else
		Raise(NStr("en = 'Service manager does not support application backup'"));
	#EndIf
	
EndProcedure

#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then
Function GetWebServiceVersions()
	
	Return CommonUse.GetInterfaceVersions(
		Constants.InternalServiceManagerURL.Get(),
		Constants.ServiceManagerOfficeUserName.Get(),
		Constants.ServiceManagerOfficeUserPassword.Get(),
		"ZoneBackupControl");

EndFunction
#EndIf

#EndRegion

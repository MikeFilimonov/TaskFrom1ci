
&AtClient
Procedure ListChange(Command)
	
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.List.CurrentRow);
	OpenParameters.Insert("ResourseAvailability", False);
	OpenForm("InformationRegister.CompanyResourceTypes.RecordForm", OpenParameters);
	
EndProcedure

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	StandardProcessing = False;
	OpenParameters = New Structure;
	OpenParameters.Insert("Key", Items.List.CurrentRow);
	OpenParameters.Insert("ResourseAvailability", False);
	OpenForm("InformationRegister.CompanyResourceTypes.RecordForm", OpenParameters);
	
EndProcedure

&AtClient
Procedure ListBeforeDelete(Item, Cancel)
	
	CurrentListRow = Items.List.CurrentData;
	If CurrentListRow <> Undefined Then
		If CurrentListRow.CompanyResourceType = PredefinedValue("Catalog.CompanyResourceTypes.AllResources") Then
			MessageText = NStr("en = 'Object is not deleted as the company resource should be included in the ""All resources"" kind.'");
			DriveClient.ShowMessageAboutError(ThisForm, MessageText, , , , Cancel);
		EndIf;
	EndIf;
	
EndProcedure

﻿#Region EventHandlers

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	For Each String In Metadata.DocumentJournals.ScheduledDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	WorkWithFilters.RestoreFilterSettings(ThisObject, List);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute DocumentType.
// 
Procedure DocumentTypeOnChange(Item)
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure

#EndRegion
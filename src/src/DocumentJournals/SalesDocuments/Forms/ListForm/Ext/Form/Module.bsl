#Region EventHandlers

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		Return;
	EndIf;
	
	For Each String In Metadata.DocumentJournals.SalesDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	Counterparty			 			= Settings.Get("Counterparty");
	Department		 			= Settings.Get("Department");
	Responsible		 			= Settings.Get("Responsible");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	DriveClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	DriveClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
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
// Procedure - event handler OnChange of attribute Department.
// 
Procedure DepartmentOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Responsible.
// 
Procedure ResponsibleOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Responsible", Responsible, ValueIsFilled(Responsible));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Counterparty.
// 
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Counterparty", Counterparty, ValueIsFilled(Counterparty));
	
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
		ParametersStructure.Insert("Counterparty", Counterparty);
		ParametersStructure.Insert("Department", Department);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure

#EndRegion
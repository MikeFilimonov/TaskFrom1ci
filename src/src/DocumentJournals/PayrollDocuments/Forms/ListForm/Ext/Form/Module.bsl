#Region FormEventHandlers
//

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Not CommonUse.OnCreateAtServer(ThisForm, Cancel, StandardProcessing) Then
		
		Return;
		
	EndIf;
	
	For Each String In Metadata.DocumentJournals.PayrollDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	List.Parameters.SetParameterValue("Employee", Employee);
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	Department			 		= Settings.Get("Department");
	Employee				 		= Settings.Get("Employee");
	RegistrationPeriod 				= Settings.Get("RegistrationPeriod");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	DriveClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
	List.Parameters.SetParameterValue("Employee", Employee);
	
	RegistrationPeriodPresentation = Format(RegistrationPeriod, "DF='MMMM yyyy'");
	
EndProcedure

&AtClient
// Procedure - form event handler ChoiceProcessing
//
Procedure ChoiceProcessing(ValueSelected, ChoiceSource)
	
	If TypeOf(ChoiceSource) = Type("ManagedForm")
		AND Find(ChoiceSource.FormName, "Calendar") > 0 Then
		
		RegistrationPeriod = EndOfDay(ValueSelected);
		DriveClient.OnChangeRegistrationPeriod(ThisForm);
		DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
		
	EndIf;
	
EndProcedure

#EndRegion

#Region EventHandlersOfFormAttributes
//

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
// Procedure - event handler Management of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodTuning(Item, Direction, StandardProcessing)
	
	DriveClient.OnRegistrationPeriodRegulation(ThisForm, Direction);
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
	
EndProcedure

&AtClient
// Procedure - event handler StartChoice of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing	 = False;
	
	CalendarDateOnOpen = ?(ValueIsFilled(RegistrationPeriod), RegistrationPeriod, DriveReUse.GetSessionCurrentDate());
	
	OpenForm("CommonForm.Calendar", DriveClient.GetCalendarGenerateFormOpeningParameters(CalendarDateOnOpen), ThisForm);
	
EndProcedure

&AtClient
// Procedure - event handler Clean of attribute RegistrationPeriod.
//
Procedure RegistrationPeriodClearing(Item, StandardProcessing)
	
	RegistrationPeriod = Undefined;
	DriveClient.OnChangeRegistrationPeriod(ThisForm);
	DriveClientServer.SetListFilterItem(List, "RegistrationPeriod", RegistrationPeriod, ValueIsFilled(RegistrationPeriod));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Department.
// 
Procedure DepartmentOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Department", Department, ValueIsFilled(Department));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Company attribute.
// 
Procedure CompanyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of attribute Employee.
// 
Procedure EmployeeOnChange(Item)
	
	List.Parameters.SetParameterValue("Employee", Employee);
	
EndProcedure

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	If ValueIsFilled(DocumentType) Then
		
		Cancel = True;
		
		ParametersStructure = New Structure();
		ParametersStructure.Insert("StructuralUnit", Department);
		ParametersStructure.Insert("RegistrationPeriod", RegistrationPeriod);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure

#EndRegion

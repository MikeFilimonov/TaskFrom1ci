#Region EventHandlers

&AtServer
// Procedure - form event handler OnCreateAtServer
// 
Procedure OnCreateAtServer(Cancel, StandardProcessing)
		
	For Each String In Metadata.DocumentJournals.WarehouseDocuments.RegisteredDocuments Do
		Items.DocumentType.ChoiceList.Add(String.Synonym, String.Synonym);
		DocumentTypes.Add(String.Synonym, String.Name);
	EndDo;
	
	// Setting the method of Business unit selection depending on FO.
	If Not Constants.UseSeveralDepartments.Get()
		AND Not Constants.UseSeveralWarehouses.Get() Then
		
		Items.Warehouse.ListChoiceMode = True;
		Items.Warehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainWarehouse);
		Items.Warehouse.ChoiceList.Add(Catalogs.BusinessUnits.MainDepartment);
		
	EndIf;
	
EndProcedure

// Procedure - form event handler "OnLoadDataFromSettingsAtServer".
//
&AtServer
Procedure OnLoadDataFromSettingsAtServer(Settings)
	
	Company				 		= Settings.Get("Company");
	DocumentTypePresentation 		= Settings.Get("DocumentTypePresentation");
	Warehouse				 			= Settings.Get("Warehouse");
	Period			 				= Settings.Get("Period");
	
	SelectedTypeOfDocument = DocumentTypes.FindByValue(DocumentTypePresentation);
	If SelectedTypeOfDocument = Undefined Then
		DocumentType = "";
	Else
		DocumentType = SelectedTypeOfDocument.Presentation;
	EndIf;
	
	DriveClientServer.SetListFilterItem(List, "Company", Company, ValueIsFilled(Company));
	DriveClientServer.SetListFilterItem(List, "Type", ?(ValueIsFilled(DocumentType), Type("DocumentRef." + DocumentType), Undefined), ValueIsFilled(DocumentType));
	DriveClientServer.SetListFilterItem(List, "Warehouse", Warehouse, ValueIsFilled(Warehouse));
	DriveClientServer.SetListFilterItem(List, "Date", Period, ValueIsFilled(Period));
	
EndProcedure

&AtClient
// Procedure - opening handler Warehouse.
//
Procedure WarehouseOpening(Item, StandardProcessing)
	
	If Items.Warehouse.ListChoiceMode
		AND Not ValueIsFilled(Warehouse) Then
		
		StandardProcessing = False;
		
	EndIf;
	
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
// Procedure - event handler OnChange of attribute StoragePlace.
// 
Procedure StoragePlaceOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Warehouse", Warehouse, ValueIsFilled(Warehouse));
	
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
		ParametersStructure.Insert("StructuralUnit", Warehouse);
		ParametersStructure.Insert("Company", Company);
		
		OpenForm("Document." + DocumentType + ".ObjectForm", New Structure("FillingValues", ParametersStructure));
		
	EndIf; 
	
EndProcedure

#EndRegion
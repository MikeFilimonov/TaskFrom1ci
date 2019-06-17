
&AtServer
// Procedure - OnCreateAtServer event handler.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Owner") Then
		
		OwnerObject = Parameters.Filter.Owner;
		
		If TypeOf(OwnerObject) = Type("CatalogRef.Products") Then
			
			If Not ValueIsFilled(OwnerObject)
				OR Not OwnerObject.ProductsType = Enums.ProductsTypes.InventoryItem
				AND Not OwnerObject.ProductsType = Enums.ProductsTypes.Service
				AND Not OwnerObject.ProductsType = Enums.ProductsTypes.Work Then
				
				AutoTitle = False;
				Title = NStr("en = 'Characteristics are stored only for inventory, services and work'");
				
				Items.List.ReadOnly = True;
				
			EndIf;
			
			SetOfAdditAttributes = OwnerObject.ProductsCategory.SetOfCharacteristicProperties;
			
		ElsIf TypeOf(OwnerObject) = Type("CatalogRef.ProductsCategories") Then
			
			SetOfAdditAttributes = OwnerObject.SetOfCharacteristicProperties;
			
		Else
			
			Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = False;
			
		EndIf;
		
	Else
		
		Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = False;
		
	EndIf;
	
	// StandardSubsystems.AdditionalReportsAndDataProcessors
	AdditionalReportsAndDataProcessors.OnCreateAtServer(ThisForm);
	// End StandardSubsystems.AdditionalReportsAndDataProcessors
	
	Items.ChangeSetOfAdditionalAttributesAndInformation.Visible = 
		AccessRight("Edit", Metadata.Catalogs.AdditionalAttributesAndInformationSets);
	
EndProcedure

&AtClient
// Procedure - event handler Execute Commands ChangeSetOfAdditionalAttributesAndInformation.
//
Procedure ChangeSetOfAdditionalAttributesAndInformation(Command)
	
	If ValueIsFilled(SetOfAdditAttributes) Then
		ParametersOfFormOfPropertiesSet = New Structure("Key", SetOfAdditAttributes);
		OpenForm("Catalog.AdditionalAttributesAndInformationSets.Form.ItemForm", ParametersOfFormOfPropertiesSet);
	Else
		ShowMessageBox(Undefined,NStr("en = 'Cannot receive the object property set. Perhaps, the necessary attributes are not filled in.'"));
	EndIf;
	
EndProcedure

#Region PerformanceMeasurements

&AtClient
Procedure ListBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	KeyOperation = "FormCreatingProductsCharacteristics";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

&AtClient
Procedure ListBeforeRowChange(Item, Cancel)
	
	KeyOperation = "FormOpeningProductsCharacteristics";
	PerformanceEstimationClientServer.StartTimeMeasurement(KeyOperation);
	
EndProcedure

#EndRegion

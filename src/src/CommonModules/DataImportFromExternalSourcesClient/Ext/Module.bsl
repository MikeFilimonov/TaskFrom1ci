
#Region ServiceProceduresAndFunctions

Procedure ShowDataImportFormFromExternalSource(DataLoadSettings, NotifyDescription, Owner) Export
	
	If Find(DataLoadSettings.DataImportFormNameFromExternalSources, "DataImportFromExternalSources") > 0 Then
		
		DataImportingParameters = New Structure("DataLoadSettings", DataLoadSettings);
		
	EndIf;
	
	DataImportingParameters_AddCounterparty(DataLoadSettings, Owner);
	
	OpenForm(DataLoadSettings.DataImportFormNameFromExternalSources, DataImportingParameters, Owner, , , , NotifyDescription, FormWindowOpeningMode.LockOwnerWindow);
	
EndProcedure

Procedure DataImportingParameters_AddCounterparty(DataLoadSettings, Owner)
	
	If Not DataLoadSettings.Property("TabularSectionFullName")
		OR NOT(DataLoadSettings.TabularSectionFullName = "PurchaseOrder.Inventory"
			OR DataLoadSettings.TabularSectionFullName = "GoodsReceipt.Products"
			OR DataLoadSettings.TabularSectionFullName = "SupplierInvoice.Inventory") Then
		Return;
	EndIf;
	
	DataLoadSettings.Insert("Supplier", Owner.Object.Counterparty);
	
EndProcedure

#EndRegion

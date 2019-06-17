#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Department
	 OR StructuralUnitType = Enums.BusinessUnitsTypes.Warehouse Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "RetailPriceKind");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount");
	EndIf;
	
	If StructuralUnitType = Enums.BusinessUnitsTypes.Retail Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "GLAccountInRetail");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "MarkupGLAccount");
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	GLAccountInRetail	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Inventory");
	MarkupGLAccount		= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("RetailMarkup");

EndProcedure

#EndRegion

#EndIf
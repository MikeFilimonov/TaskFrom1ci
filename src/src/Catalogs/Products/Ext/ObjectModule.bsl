#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If ProductsType = Enums.ProductsTypes.InventoryItem Then
		
		CheckedAttributes.Add("BusinessLine");
		CheckedAttributes.Add("ReplenishmentMethod");
		
	ElsIf ProductsType = Enums.ProductsTypes.Service Then
		
		CheckedAttributes.Add("BusinessLine");
		
	ElsIf ProductsType = Enums.ProductsTypes.Work Then
		
		CheckedAttributes.Add("BusinessLine");
		
	EndIf;
	
EndProcedure

// Procedure - event handler BeforeWrite object.
//
Procedure BeforeWrite(Cancel)
	
	ChangeDate = CurrentDate();
	
EndProcedure

// Procedure - event handler of the OnCopy object.
//
Procedure OnCopy(CopiedObject)
	
	If Not CopiedObject.IsFolder Then
		
		Specification = Undefined;
		PictureFile = Catalogs.ProductsAttachedFiles.EmptyRef();
		
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, FillingText, StandardProcessing)
	 
	If Not IsFolder Then
		ExpensesGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Expenses");
		InventoryGLAccount	= Catalogs.DefaultGLAccounts.GetDefaultGLAccount("Inventory");
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
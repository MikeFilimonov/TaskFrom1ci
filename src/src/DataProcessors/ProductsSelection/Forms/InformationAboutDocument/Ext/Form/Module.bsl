
#Region ServiceProceduresAndFunctions
//

&AtServer
// Procedure fills the decoration with the list of product types
//
Procedure FillProductsTypeLabel(ProductsType)
	
	For Each ItemOfList In ProductsType Do
		
		Items.DecorationProductsTypeContent.Title = Items.DecorationProductsTypeContent.Title + ?(IsBlankString(Items.DecorationProductsTypeContent.Title), "", ", ") + ItemOfList.Value;
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ProcedureFormEventHandlers
//

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillPropertyValues(Object, Parameters);
	
	FillProductsTypeLabel(Object.ProductsType);
	
	CommonUseClientServer.SetFormItemProperty(Items, "Company", "Visible", GetFunctionalOption("UseSeveralCompanies"));
	CommonUseClientServer.SetFormItemProperty(Items, "StructuralUnit", "Visible", GetFunctionalOption("UseSeveralWarehouses"));
	CommonUseClientServer.SetFormItemProperty(Items, "DiscountMarkupKind", "Visible", Parameters.DiscountsMarkupsVisible);
	
EndProcedure
 

#EndRegion

#Region ProcedureFormEventHandlers

&AtServer
// Procedure-handler of the OnCreateAtServer event.
// Performs initial attributes forms filling.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("Products") Then

		Products = Parameters.Filter.Products;

		If Products.ProductsType <> Enums.ProductsTypes.Work Then
			
			AutoTitle = False;
			Title = NStr("en = 'Standard hours are stored only for works'");

			Items.List.ReadOnly = True;
			
		EndIf;

	EndIf;
		
EndProcedure

#EndRegion

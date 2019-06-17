

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			OwnerType = Parameters.Filter.Owner.ProductsType;
			
			If (OwnerType = Enums.ProductsTypes.Operation
				OR OwnerType = Enums.ProductsTypes.Service
				OR (NOT Constants.UseProductionSubsystem.Get() AND OwnerType = Enums.ProductsTypes.InventoryItem)
				OR (NOT Constants.UseWorkOrders.Get() AND OwnerType = Enums.ProductsTypes.Work)) Then
			
				Message = New UserMessage();
				LabelText = NStr("en = 'BOM is not specified for products of the %EtcProducts% type.'");
				LabelText = StrReplace(LabelText, "%EtcProducts%", OwnerType);
				Message.Text = LabelText;
				Message.Message();
				Cancel = True;
				
			EndIf;
			
		EndIf;
		
	EndIf;
	
EndProcedure

#EndRegion

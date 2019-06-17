
#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		
		If ValueIsFilled(Parameters.Filter.Owner) Then
			
			If Not Parameters.Filter.Owner.UseBatches Then
				
				Message = New UserMessage();
		        Message.Text = NStr("en = 'Accounting by batches is not kept for products.'");
				Message.Message();
		        Cancel = True;
				
			EndIf;	
			
		EndIf;	
		
	EndIf;	

EndProcedure

#EndRegion

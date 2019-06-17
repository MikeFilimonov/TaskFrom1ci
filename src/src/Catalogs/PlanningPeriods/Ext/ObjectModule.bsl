#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If (NOT IsFolder) AND ValueIsFilled(StartDate)
		AND ValueIsFilled(EndDate) Then
		
		If StartDate > EndDate Then
			
			Message = New UserMessage;
			Message.Text = NStr("en = 'The Start date field value is greater than the End date field value.'");
			Message.Field = "Object.StartDate";
			Message.Message();
			
			Cancel = True;
			
		EndIf;
		
	EndIf;
	
	If (NOT IsFolder) AND (Ref = Catalogs.PlanningPeriods.Actual) Then
		
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "StartDate");
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "EndDate");
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
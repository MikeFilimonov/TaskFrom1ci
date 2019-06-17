#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure BeforeWrite(Cancel)
	
	// No execute action in the data exchange
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If IsNew() Then
		Created = CurrentSessionDate();
	EndIf;
	
	GenerateBasicInformation();
	
	AdditionalProperties.Insert("IsNew", IsNew());
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	NoncheckableAttributeArray = New Array;
	
	If Not ValueIsFilled(ClosureResult)
		OR ClosureResult = Enums.LeadClosureResult.ConvertedIntoCustomer Then
		NoncheckableAttributeArray.Add("RejectionReason");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If AdditionalProperties.Property("ActivityHasChanged") AND AdditionalProperties.ActivityHasChanged Then
		NewState = AdditionalProperties.NewState;
		WorkWithLeads.WriteCurrentAcrivity(Ref, NewState.Campaign, NewState.SalesRep, NewState.Activity);
	EndIf;
	
	If AdditionalProperties.Property("DoNotWriteToRegister") Then
		Return;
	ElsIf ValueIsFilled(ClosureDate) Then
		InformationRegisters.LeadKanban.DeleteLead(Ref);
	ElsIf AdditionalProperties.Property("LeadsKanban") Then
		InformationRegisters.LeadKanban.DragLead(
			AdditionalProperties.NewState.Activity,
			AdditionalProperties.NewState.Campaign,
			Ref,
			AdditionalProperties.LeadsKanban.Order);
	ElsIf AdditionalProperties.IsNew Then
		InformationRegisters.LeadKanban.AddLeadToEnd(Ref);
	ElsIf AdditionalProperties.Property("ActivityHasChanged") Then
		InformationRegisters.LeadKanban.DragLead(
			AdditionalProperties.NewState.Activity,
			AdditionalProperties.NewState.Campaign,
			Ref);
	EndIf;

EndProcedure

#EndRegion

#Region Private

// Procedure fills an auxiliary attribute "BasicInformation"
//
Procedure GenerateBasicInformation()
	
	RowsArray = New Array;
	
	If Not IsBlankString(Description) Then
		RowsArray.Add(Description);
	EndIf;
	
	CI = ContactInformation.Unload();
	CI.Sort("Kind");
	For Each RowCI In CI Do
		If IsBlankString(RowCI.Presentation) Then
			Continue;
		EndIf;
		RowsArray.Add(RowCI.Presentation);
	EndDo;
	
	ContactsTable = Contacts.Unload();
	For Each RowContant In ContactsTable Do
		If IsBlankString(RowContant.Representation) Then
			Continue;
		EndIf;
		RowsArray.Add(RowContant.Representation);
	EndDo;
		
	If Not IsBlankString(Note) Then
		RowsArray.Add(Note);
	EndIf;
	
	BasicInformation = StrConcat(RowsArray, Chars.LF);
	
EndProcedure

#EndRegion

#EndIf
#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If SendingMethod = Enums.MessageType.SMS Then
		CheckedAttributes.Delete(CheckedAttributes.Find("UserAccount"));
	EndIf;
	
EndProcedure

Procedure Filling(FillingData, StandardProcessing)
	If TypeOf(FillingData) = Type("DocumentRef.RequestForQuotation") Then
		// Filling the headline
		Content = FillingData.DescriptionOfTheRequirements;
		For Each CurRowSuppliers In FillingData.Suppliers Do
			NewRow = Recipients.Add();
			NewRow.Contact = CurRowSuppliers.ContactPerson;
			NewRow.HowToContact = CurRowSuppliers.Email;
		EndDo;
	EndIf;
EndProcedure

#EndRegion

#EndIf
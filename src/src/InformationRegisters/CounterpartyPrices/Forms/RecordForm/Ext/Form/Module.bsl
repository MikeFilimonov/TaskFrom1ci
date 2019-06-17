
&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(Products)
	
	Return Products.MeasurementUnit;
	
EndFunction

#Region ProcedureFormEventHandlers

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If RecordWasRecorded Then
		Notify("CounterpartyPriceChanged", RecordWasRecorded);
	EndIf;
	
EndProcedure

&AtServer
// Procedure - event handler BeforeWrite form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Modified Then
		CurrentObject.Author = Users.CurrentUser();
	EndIf; 
	
EndProcedure

&AtClient
// Procedure - event handler AfterWrite form.
//
Procedure AfterWrite(WriteParameters)
	RecordWasRecorded = True;
EndProcedure

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RecordWasRecorded = False;
	
	If ValueIsFilled(Record.SupplierPriceTypes) Then
		Counterparty = Record.SupplierPriceTypes.Owner;	
	EndIf; 
	
	If Not ValueIsFilled(Record.SourceRecordKey.SupplierPriceTypes) Then
		
		Record.Author = Users.CurrentUser();
		
		If Parameters.FillingValues.Property("Counterparty") AND ValueIsFilled(Parameters.FillingValues.Counterparty) Then
			Counterparty = Parameters.FillingValues.Counterparty;
		EndIf;
		
		If Parameters.Property("Counterparty") AND ValueIsFilled(Parameters.Counterparty) Then
			Counterparty = Parameters.Counterparty;	
		EndIf;
		
		If Parameters.FillingValues.Property("Products") AND ValueIsFilled(Parameters.FillingValues.Products) Then
			Record.MeasurementUnit = Parameters.FillingValues.Products.MeasurementUnit;	
		EndIf;
		
	EndIf;
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	Record.MeasurementUnit = GetDataProductsOnChange(Record.Products);
	
EndProcedure

&AtClient
// Procedure - event handler StartChoice input field PriceKind.
//
Procedure PriceTypestartChoice(Item, ChoiceData, StandardProcessing)
	
	If Not ValueIsFilled(Counterparty) Then
		
		StandardProcessing = False;
		MessageText = NStr("en = 'Specify the counterparty to select the price kind.'");
		CommonUseClientServer.MessageToUser(MessageText, , , "Counterparty");
		
	EndIf;
	
EndProcedure

#EndRegion

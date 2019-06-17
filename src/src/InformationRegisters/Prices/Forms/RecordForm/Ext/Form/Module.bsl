
&AtServerNoContext
// Receives the set of data from the server for the ProductsOnChange procedure.
//
Function GetDataProductsOnChange(Products)
	
	Return Products.MeasurementUnit;
	
EndFunction

&AtServerNoContext
// It receives data set from the server for procedure PriceKindOnChange.
//
Function GetDataPriceKindOnChange(PriceKind)
	
	DataStructure = New Structure;
	DataStructure.Insert("RoundUp", PriceKind.RoundUp);
	DataStructure.Insert("RoundingOrder", PriceKind.RoundingOrder);
	
	Return DataStructure;
	
EndFunction

#Region ProcedureFormEventHandlers

&AtServer
// Procedure - event handler OnCreateAtServer of the form.
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	RecordWasRecorded = False;
	
	If Not ValueIsFilled(Record.SourceRecordKey.PriceKind) Then
		
		Record.Author = Users.CurrentUser();
		
		If Parameters.Property("FillingValues") 
			AND TypeOf(Parameters.FillingValues) = Type("Structure")
			AND Parameters.FillingValues.Property("Products")
			AND ValueIsFilled(Parameters.FillingValues.Products) Then
			
			Record.MeasurementUnit = Parameters.FillingValues.Products.MeasurementUnit;
			
		EndIf;
		
	EndIf;
	
	If Not ValueIsFilled(Record.PriceKind) Then
		
		Record.PriceKind = Catalogs.PriceTypes.GetMainKindOfSalePrices();
		
	EndIf;
	
	RoundUp = Record.PriceKind.RoundUp;
	RoundingOrder = Record.PriceKind.RoundingOrder;
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	ReadOnly = Not AllowedEditDocumentPrices;
	
EndProcedure

&AtClient
// Procedure - event handler BeforeClose form.
//
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If RecordWasRecorded Then
		Notify("PriceChanged", RecordWasRecorded);
	EndIf;
	
EndProcedure

&AtServer
// Procedure - event handler BeforeWrite form.
//
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.PriceKind.CalculatesDynamically Then
		
		Message 		= New UserMessage;
		Message.Text 	= NStr("en = 'You cannot write data with dynamic price kinds.'");
		Message.Field 	= "Record.PriceKind";
		Message.Message();
		
		Cancel = True;
		
	EndIf;
	
	If Modified Then
		CurrentObject.Author = Users.CurrentUser();
	EndIf; 
	
EndProcedure

&AtClient
// BeforeRecord event handler procedure.
//
Procedure BeforeWrite(Cancel, WriteParameters)
	
	// StandardSubsystems.PerformanceMeasurement
	PerformanceEstimationClientServer.StartTimeMeasurement("RegisterProductsEntryPricesInformationInteractively");
	// StandardSubsystems.PerformanceMeasurement
	
EndProcedure

&AtClient
// Procedure - event handler AfterWrite form.
//
Procedure AfterWrite(WriteParameters)
	RecordWasRecorded = True;
EndProcedure

#EndRegion

#Region ProcedureHandlersOfTheFormAttributes

&AtClient
// Procedure - event handler OnChange of the Products input field.
//
Procedure ProductsOnChange(Item)
	
	Record.MeasurementUnit = GetDataProductsOnChange(Record.Products);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure PricesKindOnChange(Item)
	
	DataStructure = GetDataPriceKindOnChange(Record.PriceKind);
	RoundUp = DataStructure.RoundUp;
	RoundingOrder = DataStructure.RoundingOrder;
	
	Record.Price = DriveClientServer.RoundPrice(Record.Price, RoundingOrder, RoundUp);
	
EndProcedure

&AtClient
// Procedure - event handler OnChange of the Price input field.
//
Procedure PriceOnChange(Item)
	
	Record.Price = DriveClientServer.RoundPrice(Record.Price, RoundingOrder, RoundUp);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Creates Barcode EAN13.
//
&AtServerNoContext
Function GenerateBarcodeEAN13()
	
	Return InformationRegisters.Barcodes.GenerateBarcodeEAN13();
	
EndFunction

&AtServerNoContext
Function GenerateBarcodeEAN13TransportWeightGood(WeightProductPrefix = "1")
	
	Return InformationRegisters.Barcodes.GenerateBarcodeTransportWeightGoodsEAN13(WeightProductPrefix);
	
EndFunction

&AtServer
Procedure SetUOMVisible(Products)

	If ValueIsFilled(Products) Then
		Query = New Query;
		Query.Text = 
		"SELECT TOP 1
		|	UOM.Ref AS Ref
		|FROM
		|	Catalog.UOM AS UOM
		|WHERE
		|	UOM.Owner = &Products
		|	AND NOT UOM.DeletionMark";
		
		Query.SetParameter("Products", Products);
		QueryResult = Query.Execute();
		Items.MeasurementUnit.Visible = Not QueryResult.IsEmpty();
	Else
		Items.MeasurementUnit.Visible = False;
	EndIf;
	
EndProcedure

// Peripherals
&AtClient
Function BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	If BarcodesData.Count() > 0 Then
		Record.Barcode = BarcodesData[BarcodesData.Count() - 1].Barcode;
	EndIf;
	
	Return True;
	
EndFunction
// End Peripherals

// Procedure command handler  NewBarcode.
//
&AtClient
Procedure NewBarcode(Command)
	
	If UseOfflineExchangeWithPeripherals Then
		WeightProductPrefix = 1;
		ShowInputNumber(New NotifyDescription("NewBarcodeEnd", ThisObject, New Structure("WeightProductPrefix", WeightProductPrefix)), WeightProductPrefix, NStr("en = 'If the goods are sold by weight, enter prefix of the goods or click Cancel'"), 1, 0);
	Else
		Record.Barcode = GenerateBarcodeEAN13();
	EndIf;
	
EndProcedure

&AtClient
Procedure NewBarcodeEnd(Result1, AdditionalParameters) Export
    
    WeightProductPrefix = ?(Result1 = Undefined, AdditionalParameters.WeightProductPrefix, Result1);
    
    
    Result = (Result1 <> Undefined);
    If Result Then
        Record.Barcode = GenerateBarcodeEAN13TransportWeightGood(WeightProductPrefix);
    Else
        Record.Barcode = GenerateBarcodeEAN13();
    EndIf;

EndProcedure

#EndRegion

#Region FormEventsHandlers

// Procedure - OnCreateAtServer event handler.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetUOMVisible(Record.Products);
	
	// Peripherals
	UsePeripherals = DriveReUse.UsePeripherals();
	UseOfflineExchangeWithPeripherals = GetFunctionalOption("UseOfflineExchangeWithPeripherals");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnOpen.
//
&AtClient
Procedure OnOpen(Cancel)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
EndProcedure

// Procedure - event handler OnClose.
//
&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

// Procedure - event handler NotificationProcessing.
//
&AtClient
Procedure NotificationProcessing(EventName, Parameter, Source)
	
	// Peripherals
	If Source = "Peripherals"
	   AND IsInputAvailable() Then
		If EventName = "ScanData" Then
			// Transform preliminary to the expected format
			Data = New Array();
			If Parameter[1] = Undefined Then
				Data.Add(New Structure("Barcode, Quantity", Parameter[0], 1)); // Get a barcode from the basic data
			Else
				Data.Add(New Structure("Barcode, Quantity", Parameter[1][1], 1)); // Get a barcode from the additional data
			EndIf;

			BarcodesReceived(Data);
		ElsIf EventName = "DataCollectionTerminal" Then
			BarcodesReceived(Parameter);
		EndIf;
	EndIf;
	// End Peripherals
	
EndProcedure

// Procedure - event handler FillCheckProcessingAtServer.
//
&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	Barcodes.Barcode,
	|	Barcodes.Products,
	|	Barcodes.Characteristic,
	|	Barcodes.Batch,
	|	PRESENTATION(Barcodes.Products) AS ProductsPresentation,
	|	PRESENTATION(Barcodes.Characteristic) AS CharacteristicPresentation,
	|	PRESENTATION(Barcodes.Batch) AS BatchPresentation
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Barcode = &Barcode";
	
	Query.SetParameter("Barcode", Record.Barcode);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() // Barcode is already written in the database
		AND Record.SourceRecordKey.Barcode <> Record.Barcode Then
		
		ErrorDescription = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'This barcode is already specified for products %1'"),
				Selection.ProductsPresentation)
			+ ?(ValueIsFilled(Selection.Characteristic), " " + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Characteristic: %1'"), 
				Selection.CharacteristicPresentation),
				"")
			+ ?(ValueIsFilled(Selection.Batch), " " + StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Batch: %1'"),
				Selection.BatchPresentation), 
				"");
		
		DriveServer.ShowMessageAboutError(ThisForm, ErrorDescription, , , "Record.Barcode", Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure ProductsOnChangeAtServer()
	SetUOMVisible(Record.Products);
EndProcedure

&AtClient
Procedure ProductsOnChange(Item)
	ProductsOnChangeAtServer();
EndProcedure

#EndRegion

#Region Variables

&AtClient
Var ClosingProcessing;

&AtServer
Var UnknownBarcodes;

#EndRegion

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	UsePeripherals = DriveReUse.UsePeripherals();
	
	For Each RowOfBarcode In Parameters.UnknownBarcodes Do
		NewBarcode = Barcodes.Add();
		NewBarcode.Barcode = RowOfBarcode.Barcode;
		NewBarcode.Quantity = RowOfBarcode.Quantity;
	EndDo;
	
	UnknownBarcodes = Parameters.UnknownBarcodes;
	
EndProcedure

&AtServer
Procedure RegisterBarcodesAtServer()
	
	For Each RowOfBarcode In Barcodes Do
		
		If RowOfBarcode.Registered OR Not ValueIsFilled(RowOfBarcode.Products) Then
			Continue;
		EndIf;
		
		Try
			
			RecordManager = InformationRegisters.Barcodes.CreateRecordManager();
			RecordManager.Products = RowOfBarcode.Products;
			RecordManager.Characteristic = RowOfBarcode.Characteristic;
			RecordManager.Batch = RowOfBarcode.Batch;
			RecordManager.Barcode = RowOfBarcode.Barcode;
			RecordManager.Write();
			
			RowOfBarcode.RegisteredByProcessing = True;
			
		Except
		
		EndTry
		
	EndDo;
	
EndProcedure

&AtClient
Procedure MoveIntoDocument(Command)
	
	ClearMessages();
	
	If CheckFilling() Then
		
		RegisterBarcodesAtServer();
		
		FoundUnregisteredGoods = Barcodes.FindRows(New Structure("Registered, RegisteredByProcessing", False, False));
		If FoundUnregisteredGoods.Count() > 0 Then
			
			QuestionText = NStr("en = 'Some new barcodes do not linked to products.
			                    |The products will not be written to the document.
			                    |Put them aside as not scanned.'"
			);
			
			QuestionResult = Undefined;
			
			ShowQueryBox(New NotifyDescription("TransferToDocumentEnd", ThisObject), QuestionText, QuestionDialogMode.OKCancel);
			Return;
			
		EndIf;
		
		TransferToDocumentFragment();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure TransferToDocumentEnd(Result, AdditionalParameters) Export
	
	QuestionResult = Result;
	If QuestionResult = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	
	TransferToDocumentFragment();
	
EndProcedure

&AtClient
Procedure TransferToDocumentFragment()
	
	Var RegisteredBarcodes, FoundsRegisteredBarcodes, FoundDeferredProducts, FoundsBarcodes, DeferredProducts, ClosingParameter, ReceivedNewBarcodes, RowOfBarcode;
	
	RegisteredBarcodes = New Array;
	FoundsRegisteredBarcodes = Barcodes.FindRows(New Structure("RegisteredByProcessing", True));
	For Each RowOfBarcode In FoundsRegisteredBarcodes Do
		RegisteredBarcodes.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	DeferredProducts = New Array;
	FoundDeferredProducts = Barcodes.FindRows(New Structure("Registered, RegisteredByProcessing", False, False));
	For Each RowOfBarcode In FoundDeferredProducts Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ReceivedNewBarcodes = New Array;
	FoundsBarcodes = Barcodes.FindRows(New Structure("Registered", True));
	For Each RowOfBarcode In FoundsBarcodes Do
		ReceivedNewBarcodes.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes);
	ClosingProcessing = True;
	Close(ClosingParameter);
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	#If Not WebClient Then
	Beep();
	#EndIf
	
	// Peripherals
	EquipmentManagerClientOverridable.StartConnectingEquipmentOnFormOpen(ThisForm, "BarCodeScanner");
	// End Peripherals
	
	ClosingProcessing = False;
	CurrentItem = Items.Products;
	
EndProcedure

&AtServerNoContext
Function GetBarcodeData(Barcode)

	Query = New Query;
	Query.Text = 
	"SELECT
	|	Barcodes.Products,
	|	Barcodes.Characteristic,
	|	Barcodes.Batch
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Barcode = &Barcode";
	
	Query.SetParameter("Barcode", Barcode);
	
	Selection = Query.Execute().Select();
	If Selection.Next() Then
		BarcodeData = New Structure("Products, Characteristic, Batch");
		FillPropertyValues(BarcodeData, Selection);
		Return BarcodeData;
	Else
		Return Undefined;
	EndIf;
	
EndFunction

// Peripherals
&AtClient
Function BarcodesReceived(BarcodesData)
	
	Modified = True;
	
	For Each DataItem In BarcodesData Do
		FoundStrings = Barcodes.FindRows(New Structure("Barcode", DataItem.Barcode));
		If FoundStrings.Count() > 0 Then
			FoundStrings[0].Quantity = FoundStrings[0].Quantity + DataItem.Quantity;
		Else
			BarcodeData = GetBarcodeData(DataItem.Barcode);
			If BarcodeData = Undefined Then
				NewBarcode = Barcodes.Add();
				NewBarcode.Barcode = DataItem.Barcode;
				NewBarcode.Quantity = DataItem.Quantity;
			Else
				NewBarcode = Barcodes.Add();
				NewBarcode.Barcode   = DataItem.Barcode;
				NewBarcode.Quantity = DataItem.Quantity;
				FillPropertyValues(NewBarcode, BarcodeData);
				NewBarcode.Registered = True;
			EndIf;
		EndIf;
	EndDo;
	
	Return True;
	
EndFunction
// End Peripherals

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

&AtClient
Procedure OnClose(Exit)
	
	// Peripherals
	EquipmentManagerClientOverridable.StartDisablingEquipmentOnCloseForm(ThisForm);
	// End Peripherals
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query;
	Query.Text = 
	"SELECT TOP 1
	|	Barcodes.Barcode AS Barcode,
	|	Barcodes.Products AS Products,
	|	Barcodes.Characteristic AS Characteristic,
	|	Barcodes.Batch AS Batch,
	|	Barcodes.Products.Description AS ProductsPresentation,
	|	Barcodes.Characteristic.Description AS CharacteristicPresentation,
	|	Barcodes.Batch.Description AS BatchPresentation
	|FROM
	|	InformationRegister.Barcodes AS Barcodes
	|WHERE
	|	Barcodes.Barcode IN(&Barcodes)";
	
	Query.SetParameter("Barcodes", Barcodes.Unload(New Structure("Registered", False),"Barcode").UnloadColumn("Barcode"));
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() Then // Barcode is already written in the database
		
		TSRow = Barcodes.FindRows(New Structure("Barcode", Selection.Barcode))[0];
		
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
		
		CommonUseClientServer.MessageToUser(ErrorDescription,, "Barcodes["+Barcodes.IndexOf(TSRow)+"].Barcode",, Cancel);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command, Cancel = False)
	
	If Not ClosingProcessing Then
		
		NotifyDescription = New NotifyDescription("CancelEnd", ThisObject);
		
		QuestionText = NStr("en = 'All products will not be written to the document.
		                    |Put them aside as not scanned.'");
		
		ShowQueryBox(NotifyDescription, QuestionText, QuestionDialogMode.OKCancel);
		Return;
		
	EndIf;
	
	DeferredProducts = New Array;
	For Each RowOfBarcode In Barcodes Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, New Array, New Array);
	ClosingProcessing = True;
	Close(ClosingParameter);
	
EndProcedure

&AtClient
Procedure CancelEnd(Result, AdditionalParameters) Export
	
	If Result = DialogReturnCode.Cancel Then
		Return;
	EndIf;
	
	DeferredProducts = New Array;
	For Each RowOfBarcode In Barcodes Do
		DeferredProducts.Add(New Structure("Barcode, Quantity", RowOfBarcode.Barcode, RowOfBarcode.Quantity));
	EndDo;
	
	ClosingParameter = New Structure("DeferredProducts, RegisteredBarcodes, ReceivedNewBarcodes", DeferredProducts, New Array, New Array);
	ClosingProcessing = True;
	Try
		Close(ClosingParameter);
	Except
	EndTry;
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, WarningText, StandardProcessing)
	
	If Exit Then
		Return;
	EndIf;
	
	If Not ClosingProcessing Then
		Cancel(Undefined, Cancel);
	EndIf;
	
EndProcedure

&AtClient
Procedure BarcodesBeforeAddRow(Item, Cancel, Copy, Parent, Group)
	
	Cancel = True;
	
EndProcedure

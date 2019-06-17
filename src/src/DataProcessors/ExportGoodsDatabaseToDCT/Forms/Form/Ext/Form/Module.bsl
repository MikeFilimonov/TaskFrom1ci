
&AtServer
Procedure FillBaseOfGoods()
	
	Query = New Query(
	"SELECT
	|	Reg.Barcode AS Barcode,
	|	PRESENTATION(Reg.Products) AS Products,
	|	PRESENTATION(Reg.Characteristic) AS Characteristic,
	|	PRESENTATION(Reg.Batch) AS Batch
	|FROM
	|	InformationRegister.Barcodes AS Reg
	|
	|ORDER BY
	|	Reg.Barcode");
	
	CurTable = Query.Execute().Unload();
	
	ValueToFormAttribute(CurTable, "ExportingTable");
	
EndProcedure

&AtServer
Function GetProductBaseArray()
	
	CurTable = FormAttributeToValue("ExportingTable");
	
	ArrayExportings = New Array();
	
	For Each TSRow In CurTable Do
		StringStructure = New Structure(
			"Barcode, Products, MeasurementUnit, ProductsCharacteristic, ProductsSeries, Quality, Price, Quantity",
			TSRow.Barcode, TSRow.Products, TSRow.Batch, TSRow.Characteristic, "", "" , "", 0);
		ArrayExportings.Add(StringStructure);
	EndDo;
	
	Return ArrayExportings;
	
EndFunction

&AtClient
Procedure FillExecute()
	
	FillBaseOfGoods();
	
EndProcedure

&AtClient
Procedure ExportExecute()
	
	ErrorDescription = "";
	
	If EquipmentManagerClient.RefreshClientWorkplace() Then
		
		// Getting product base
		DCTTable = GetProductBaseArray();
		NotificationsAtExportVTSD = New NotifyDescription("ExportVTSDEnd", ThisObject);
		EquipmentManagerClient.StartDataExportVTSD(NotificationsAtExportVTSD, UUID, DCTTable);
		
	Else
		
		MessageText = NStr("en = 'First, you need to select the work place of the current session peripherals.'");
		CommonUseClientServer.MessageToUser(MessageText);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportVTSDEnd(Result, Parameters) Export
	
	If Result Then
		MessageText = NStr("en = 'The data was successfully uploaded into the shipping documents.'");
		CommonUseClientServer.MessageToUser(MessageText);
	EndIf;
	
EndProcedure

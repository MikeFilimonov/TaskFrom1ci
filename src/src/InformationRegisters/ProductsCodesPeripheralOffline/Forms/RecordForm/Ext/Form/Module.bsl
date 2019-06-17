
#Region FormEventHandlers

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	Query = New Query(
	"SELECT TOP 1
	|	ProductsCodesPeripheralOffline.Code AS Code
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|WHERE
	|	ProductsCodesPeripheralOffline.Code = &Code
	|	AND ProductsCodesPeripheralOffline.ExchangeRule = &ExchangeRule
	|	AND ProductsCodesPeripheralOffline.Products = VALUE(Catalog.Products.EmptyRef)
	|");
	
	Query.SetParameter("Code", CurrentObject.Code);
	Query.SetParameter("ExchangeRule", CurrentObject.ExchangeRule);
	
	If Not Query.Execute().IsEmpty() Then
		ToRemoveWrite = InformationRegisters.ProductsCodesPeripheralOffline.CreateRecordManager();
		ToRemoveWrite.Code = CurrentObject.Code;
		ToRemoveWrite.ExchangeRule = CurrentObject.ExchangeRule;
		ToRemoveWrite.Delete();
	EndIf;
	
	Code = PeripheralsOfflineServerCall.GetMaximumCode(Record.ExchangeRule)+1;
	While Code < CurrentObject.Code Do
		PeripheralsOfflineServerCall.DeleteCode(CurrentObject.ExchangeRule, Code);
		Code = Code+1;
	EndDo;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If Record.SourceRecordKey.Code <> CurrentObject.Code Then
		PeripheralsOfflineServerCall.DeleteCode(CurrentObject.ExchangeRule, Record.SourceRecordKey.Code);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillCheckProcessingAtServer(Cancel, CheckedAttributes)
	
	Query = New Query(
	"SELECT TOP 1
	|	ProductsCodesPeripheralOffline.Code AS Code,
	|	ProductsCodesPeripheralOffline.Products AS Products,
	|	ProductsCodesPeripheralOffline.Characteristic AS Characteristic,
	|	ProductsCodesPeripheralOffline.Batch AS Batch,
	|	ProductsCodesPeripheralOffline.MeasurementUnit AS MeasurementUnit,
	|	ProductsCodesPeripheralOffline.Products.Description AS ProductsPresentation,
	|	ProductsCodesPeripheralOffline.Characteristic.Description AS CharacteristicPresentation,
	|	ProductsCodesPeripheralOffline.Batch.Description AS BatchPresentation,
	|	ProductsCodesPeripheralOffline.MeasurementUnit.Description AS MeasurementUnitPresentation
	|FROM
	|	InformationRegister.ProductsCodesPeripheralOffline AS ProductsCodesPeripheralOffline
	|WHERE
	|	ProductsCodesPeripheralOffline.Code = &Code
	|	AND ProductsCodesPeripheralOffline.Products <> VALUE(Catalog.Products.EmptyRef)");
	
	Query.SetParameter("Code", Record.Code);
	
	Selection = Query.Execute().Select();
	
	If Selection.Next() // Barcode is already written in the database
		AND Record.SourceRecordKey.Code <> Record.Code Then
		
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

		CommonUseClientServer.MessageToUser(ErrorDescription,, "Record.Code",, Cancel);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CodesArray = GetFreeCodes().UnloadColumn("Code");
	Items.Code.ChoiceList.LoadValues(CodesArray);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Function GetFreeCodes()
	
	FreeCodes = PeripheralsOfflineServerCall.GetFreeCodes(Record.ExchangeRule, 20);
	NewRow = FreeCodes.Add();
	NewRow.Code = PeripheralsOfflineServerCall.GetMaximumCode(Record.ExchangeRule)+1;
	
	Return FreeCodes;
	
EndFunction

#EndRegion

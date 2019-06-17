#Region ProgramInterface

// Function exports the changes of products data in the equipment Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting 
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousExportProductsInEquipmentOffline(EquipmentType, DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation, ModifiedOnly = True) Export
	
	Status(NStr("en = 'Exporting goods to offline peripherals...'"));
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier In DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription = "";
		ClientID = New UUID;
		
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			StructureData = PeripheralsOfflineServerCall.GetDataForPettyCash(DeviceIdentifier, ModifiedOnly);
		Else
			StructureData = PeripheralsOfflineServerCall.GetDataForScales(DeviceIdentifier, ModifiedOnly);
		EndIf;
		
		If StructureData.Data.Count() = 0 Then
			Result = False;
			If StructureData.ExportedRowsWithErrorsCount = 0 Then
				ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(DeviceIdentifier, Undefined, ErrorsDescriptionFull, NStr("en = 'There is no data to export.'"));
			Else
				ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(DeviceIdentifier, Undefined, ErrorsDescriptionFull, StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Data is not exported. Errors detected: %1'"), StructureData.ExportedRowsWithErrorsCount));
			EndIf;
			Continue;
		EndIf;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ImportIntoEquipmentOfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, StructureData",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, StructureData 
			)
		);
		
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			EquipmentManagerClient.StartDataExportToCROffline(
				NotificationsOnCompletion, 
				ClientID,
				DeviceIdentifier,
				StructureData.Data,
				StructureData.PartialExport
			);
		Else
			EquipmentManagerClient.StartDataExportToScalesWithLabelsPrinting(
				NotificationsOnCompletion, 
				ClientID,
				DeviceIdentifier,
				StructureData.Data,
				StructureData.PartialExport
			);
		EndIf;
		
	EndDo;
	
EndProcedure

// Function clears the list of products in the equipment Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousClearProductsInEquipmentOffline(EquipmentType, DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation) Export
	
	Status(NStr("en = 'Clearing goods in offline peripherals...'"));
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier In DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription     = "";
		ClientID = New UUID;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ClearEquipmentBaseOfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation
			)
		);
		If EquipmentType = PredefinedValue("Enum.PeripheralTypes.CashRegistersOffline") Then
			EquipmentManagerClient.StartProductsCleaningInCROffline(
				NotificationsOnCompletion,
				ClientID,
				DeviceIdentifier
			);
		Else
			EquipmentManagerClient.StartClearingProductsInScalesWithLabelsPrinting(
				NotificationsOnCompletion,
				ClientID,
				DeviceIdentifier
			);
		EndIf;
	EndDo;
	
EndProcedure

// Function clears the list of products in the CR Offline.
//
// Parameters:
//  DeviceArray          - The <CatalogRef.Peripherals> array of refs to
//                         devices to which the changes are exported.
//  MessageText          - <String > Error message during data exporting
//  ShowMessageBox       - <Boolean > The flag that defines the option to show a warning message about the end of action
//
// Returns:
//  <Number> - Number of devices export to which is executed successfully.
//
Procedure AsynchronousImportReportAboutRetailSales(DeviceArray, MessageText = "", ShowMessageBox = True, NotificationOnImplementation) Export
	
	Status(NStr("en = 'Retail sales reports are being imported from the offline CR...'"));
	
	RetailSalesReports = New Array;
	
	Completed = 0;
	CurDevice = 0;
	NeedToPerform = DeviceArray.Count();
	
	ErrorsDescriptionFull = "";
	
	For Each DeviceIdentifier In DeviceArray Do
		
		CurDevice = CurDevice + 1;
		ThisIsLastDevice = CurDevice = NeedToPerform;
		ErrorDescription  = "";
		ClientID = New UUID;
		
		NotificationsOnCompletion = New NotifyDescription(
			"ImportReportCROfflineEnd",
			ThisObject,
			New Structure(
				"ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, RetailSalesReports",
				ErrorsDescriptionFull, Completed, NeedToPerform, DeviceIdentifier, ClientID, ThisIsLastDevice, ShowMessageBox, NotificationOnImplementation, RetailSalesReports
			)
		);
		EquipmentManagerClient.StartImportRetailSalesReportFromCROffline(
			NotificationsOnCompletion,
			ClientID,
			DeviceIdentifier
		);
		
	EndDo;
	
EndProcedure

#EndRegion

#Region ServiceProgramInterface

Procedure ImportIntoEquipmentOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Parameters.Completed = Parameters.Completed + 1;
	Else
		Parameters.ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(Parameters.DeviceIdentifier, Parameters.Output_Parameters, Parameters.ErrorsDescriptionFull, Parameters.ErrorDescription);
	EndIf;
	
	PeripheralsOfflineServerCall.OnProductsExportToDevice(Parameters.DeviceIdentifier, Parameters.StructureData, Result);
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousExportProductsInEquipmentOfflineFragment(Parameters);
	EndIf;
	
EndProcedure

Procedure ClearEquipmentBaseOfflineEnd(Result, Parameters) Export
	
	If Result Then
		Parameters.Completed = Parameters.Completed + 1;
	Else
		Parameters.ErrorsDescriptionFull = GenerateErrorDescriptionForDevice(Parameters.DeviceIdentifier, Parameters.Output_Parameters, Parameters.ErrorsDescriptionFull, Parameters.ErrorDescription);
	EndIf;
	
	PeripheralsOfflineServerCall.OnProductsClearingInDevice(Parameters.DeviceIdentifier, Result);
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousClearProductsInEquipmentOfflineFragment(Parameters);
	EndIf;

EndProcedure

Procedure ImportReportCROfflineEnd(Result, Parameters) Export
	
	If TypeOf(Result) = Type("Array")
		AND Result.Count() > 0 Then
		ShiftClosure = PeripheralsOfflineServerCall.WhenImportingReportAboutRetailSales(Parameters.DeviceIdentifier, Result);
		If ValueIsFilled(ShiftClosure) Then
			EquipmentManagerClient.StartCheckBoxReportImportedCROffline(
				Parameters.ClientID,
				Parameters.DeviceIdentifier
			);
			Parameters.RetailSalesReports.Add(ShiftClosure);
			Parameters.Completed = Parameters.Completed + 1;
		EndIf;
	EndIf;
	
	If Parameters.ThisIsLastDevice Then
		AsynchronousImportReportAboutRetailSalesFragment(Parameters);
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function GenerateErrorDescriptionForDevice(DeviceIdentifier, Output_Parameters, ErrorsDescriptionFull, ErrorDescription)
	
	Return ErrorsDescriptionFull
	      + Chars.LF
	      + StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Error description for the %1 device: %2'"), DeviceIdentifier, ErrorDescription)
	      + ?(Output_Parameters <> Undefined, Chars.LF + Output_Parameters[1], "");
	
EndFunction

Procedure AsynchronousExportProductsInEquipmentOfflineFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en = 'The goods have been successfully exported.'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'The goods have been successfully exported for %1 devices from %2.'"), Parameters.Completed, Parameters.NeedToPerform) + Parameters.ErrorsDescriptionFull;
		Else
			MessageText = NStr("en = 'Cannot export the goods:'") + Parameters.ErrorsDescriptionFull;
		EndIf;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en = 'Select a device for which the goods should be exported.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

Procedure AsynchronousClearProductsInEquipmentOfflineFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en = 'Goods are successfully cleared.'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Goods are successfully cleared for %1 devices out of %2. %3'"), Parameters.Completed, Parameters.NeedToPerform, Parameters.ErrorsDescriptionFull);
		Else
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Cannot clear the goods: %1'"), Parameters.ErrorsDescriptionFull);
		EndIf;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en = 'Select a device for which the goods should be cleared.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

Procedure AsynchronousImportReportAboutRetailSalesFragment(Parameters)
	
	If Parameters.NeedToPerform > 0 Then
		
		If Parameters.Completed = Parameters.NeedToPerform Then
			MessageText = NStr("en = 'The retail sales reports have been successfully imported.'");
		ElsIf Parameters.Completed > 0 Then
			MessageText = StringFunctionsClientServer.SubstituteParametersInString(NStr("en = 'Retail sales reports have been successfully imported for %1 devices from %2.'"), Parameters.Completed, Parameters.NeedToPerform) + Parameters.ErrorsDescriptionFull;
		Else
			MessageText = NStr("en = 'Cannot import retail sales reports:'") + Parameters.ErrorsDescriptionFull;
		EndIf;
		
		For Each ShiftClosure In Parameters.RetailSalesReports Do
			OpenForm("Document.ShiftClosure.ObjectForm", New Structure("Key, PostOnOpen", ShiftClosure, True));
		EndDo;
		
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, MessageText, 10);
		EndIf;
		
	Else
		If Parameters.ShowMessageBox Then
			ShowMessageBox(Undefined, NStr("en = 'Select a device for which the goods should be cleared.'"), 10);
		EndIf;
	EndIf;
	
	ExecuteNotifyProcessing(Parameters.NotificationOnImplementation, Parameters.Completed > 0);
	
EndProcedure

#EndRegion


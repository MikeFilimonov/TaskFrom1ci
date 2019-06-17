
#Region ProgramInterface

// Returns available equipment types list
//
Function GetAvailableEquipmentTypes() Export
	
	EquipmentList = New Array;

	// Bar code scanners
	EquipmentList.Add(Enums.PeripheralTypes.BarCodeScanner);
	// End Barcode scanners

	// Magnetic card readers
	EquipmentList.Add(Enums.PeripheralTypes.MagneticCardReader);
	// End Mangnet cards reader

	// Fiscal cash registers
	EquipmentList.Add(Enums.PeripheralTypes.FiscalRegister);
	// End Fiscal resgisters

	// Customer displays
	EquipmentList.Add(Enums.PeripheralTypes.CustomerDisplay);
	// End Customners displays

	// Data collection terminals
	EquipmentList.Add(Enums.PeripheralTypes.DataCollectionTerminal);
	// End Data collection terminals

	// POS terminals
	EquipmentList.Add(Enums.PeripheralTypes.POSTerminal);
    // End POS terminals
	
	// Electronic scales
	EquipmentList.Add(Enums.PeripheralTypes.ElectronicScales);
	// End Electronuc scales

	// Labels printing scales
	EquipmentList.Add(Enums.PeripheralTypes.LabelsPrintingScales);
	// End Scales with label printing

	// CR offline
	EquipmentList.Add(Enums.PeripheralTypes.CashRegistersOffline);
	// End CR offline
	
	Return EquipmentList;
	
EndFunction

// Returns availability flag for new drivers to the drivers catalog.
//
Function PossibilityToAddNewDrivers() Export
	
	YouCanAddNewDrivers = True;
	Return YouCanAddNewDrivers;
	
EndFunction

// Returns the flag showing that it is possible to call the separated data from the current session.
// Returns True if there is a call in the undivided configuration.
//
// Returns:
// Boolean.
//
Function CanUseSeparatedData() Export
	
	Return CommonUseReUse.CanUseSeparatedData();
	
EndFunction

// Update supplied drivers within the configuration
//                                   
Procedure RefreshSuppliedDrivers() Export
	
	// Bar code scanners
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.Handler1CBarCodeScannersNative,  "AddIn.InputDevice", "Driver1CNativeInputDevice", False, "8.1.8.1");
	
	// End Barcode scanners
	
	// Magnetic card readers
	
	// End Mangnet cards reader
	
	// Fiscal cash registers
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerZekaFiscalRegisters, , , False);
	Catalogs.HardwareDrivers.FillPredefinedItem(Enums.PeripheralDriverHandlers.HandlerTremolFiscalRegisters, "COMObject/Zfpcom.ZekaFP", , True);
	// End Fiscal resgisters
	
	// Customer displays
	
	// End Customners displays
	
	// Data collection terminals
	
	// End Data collection terminals
	
	// POS terminals
	
	// End POS terminals
	
	// Electronic scales
	
	// End Electronuc scales
	
	// Labels printing scales
	
	// End Scales with label printing
	
	// CR offline
	
	// End CR offline
	
EndProcedure

#EndRegion

#Region EquipmentOffline

// The function returns the goods sold by weight used to generate barcode.
// Used for loading to scales with printing labels
Function GetWeightProductPrefix(PeripheralsRef) Export
	
	Prefix = Undefined;
	Return Prefix;
	
EndFunction

// The function returns the prefix of piece goods used to generate barcode
// Used for loading to scales with printing labels
Function GetPieceProductPrefix(PeripheralsRef) Export
	
	Prefix = Undefined;
	Return Prefix;
	
EndFunction

#EndRegion

#Region WorkWithFormInstanceEquipment

// Additional redefined actions with controlled form
// in the Equipment instance for the OnCreateAtServer event
//
Procedure EquipmentInstanceOnCreateAtServer(Object, ThisForm, Cancel, Parameters, StandardProcessing) Export

EndProcedure

// Additional redefined actions with controlled form
// in the Equipment instance for "OnReadAtServer"
//
Procedure EquipmentInstanceOnReadAtServer(CurrentObject, ThisForm) Export

EndProcedure

// Additional  redefined actions with controlled form
// in the Equipment form for the BeforeRecordingOnServer event
//
Procedure EquipmentInstanceBeforeWriteAtServer(Cancel, CurrentObject, WriteParameters) Export

EndProcedure

// Additional  redefined actions with controlled form  in
// the Equipment instance for the OnWriteAtServer event
//
Procedure EquipmentInstanceOnWriteAtServer(Cancel, CurrentObject, WriteParameters) Export

EndProcedure

// Additional  redefined actions with controlled form
// in the Equipment instance for the AfterRecordedOnServer event
//
Procedure EquipmentInstanceAfterWriteAtServer(CurrentObject, WriteParameters) Export

EndProcedure

// Additional  redefined actions with controlled form
// in the Equipment instance for the ProcessingOnServerFillinCheck event
//
Procedure EquipmentInstanceFillCheckProcessingAtServer(Object, ThisForm, Cancel, CheckedAttributes) Export

EndProcedure

#EndRegion

#Region SupportCompatibility

// The function creates a node for this instance of peripherals and returns a link to it.
// Used before recording the element of the Peripherals catalog
Function GetDIBNode(PeripheralsObject) Export
	
	NodeObject = ExchangePlans.ExchangeWithOfflinePeripherals.CreateNode();
	NodeObject.SetNewCode();
	NodeObject.Description = PeripheralsObject.Description;
	NodeObject.Write();
	
	Return NodeObject.Ref;
	
EndFunction

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Subsystem "Additional reports and data processors".
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

#Region NamesOfObjectKinds

// Print form.
Function DataProcessorKindPrintForm() Export
	
	Return "PrintForm"; // not localized
	
EndFunction

// Object filling.
Function DataProcessorKindObjectFilling() Export
	
	Return "ObjectFill"; // not localized
	
EndFunction

// Creation of linked objects.
Function DataProcessorKindCreatingRelatedObjects() Export
	
	Return "CreatingLinkedObjects"; // not localized
	
EndFunction

// Assigned report.
Function DataProcessorKindReport() Export
	
	Return "Report"; // not localized
	
EndFunction

// Additional data processor.
Function DataProcessorKindAdditionalInformationProcessor() Export
	
	Return "AdditionalInformationProcessor"; // not localized
	
EndFunction

// Additional report.
Function DataProcessorKindAdditionalReport() Export
	
	Return "AdditionalReport"; // not localized
	
EndFunction

// SMS Provider.
Function DataProcessorKindSMSProvider() Export
	
	Return "SMSProvider"; // not localized
	
EndFunction

// ExchangeRatesImportProcessor.
Function DataProcessorKindExchangeRatesImportProcessor() Export
	
	Return "ExchangeRatesImportProcessor"; // not localized
	
EndFunction

// BankClassifierImportProcessor.
Function DataProcessorKindBankClassifierImportProcessor() Export
	
	Return "BankClassifierImportProcessor"; // not localized
	
EndFunction

// BankExchangeProcessor.
Function DataProcessorKindBankExchangeProcessor() Export
	
	Return "BankExchangeProcessor";
	
EndFunction

#EndRegion

#Region NamesOfCommandsKinds

// Client method call.
Function TypeCommandsClientMethodCall() Export
	
	Return "CallOfClientMethod"; // not localized
	
EndFunction

// Server method call.
Function TypeCommandsServerMethodCall() Export
	
	Return "CallOfServerMethod"; // not localized
	
EndFunction

// Opening a form.
Function TypeCommandsFormOpening() Export
	
	Return "FormOpening"; // not localized
	
EndFunction

// Filling a form.
Function TypeCommandsFillForm() Export
	
	Return "FillForm"; // not localized
	
EndFunction

// Script in safe mode.
Function TypeCommandsScriptInSafeMode() Export
	
	Return "ScriptInSafeMode"; // not localized
	
EndFunction

// Data import from file.
Function CommandTypeDataLoadFromFile() Export
	
	Return "DataLoadFromFile"; // not localized
	
EndFunction

#Region NamesOfFormTypes
// It is used when setting the assigned objects.

// List form identifier.
Function FormTypeList() Export
	
	Return "ListForm"; // not localized
	
EndFunction

// Object form identifier.
Function ObjectFormType() Export
	
	Return "ObjectForm"; // not localized
	
EndFunction

#EndRegion

#EndRegion

#Region OtherProceduresAndFunctions

// Filter for chooser or save dialogs of additional reports and data processors.
Function ChooserAndSaveDialog() Export
	
	Filter = NStr("en = 'External reports and data processors (*.%1, *.%2)|*.%1;*.%2|External reports (*.%1)|*.%1|External data processors (*.%2)|*.%2'");
	Filter = StringFunctionsClientServer.SubstituteParametersInString(Filter, "erf", "epf");
	Return Filter;
	
EndFunction

// Identifier that is used for desktop.
Function DesktopID() Export
	
	Return "Desktop"; // not localized
	
EndFunction

// Subsystem name.
Function SubsystemDescription(LanguageCode) Export
	
	Return NStr("en = 'Additional reports and data processors'", ?(LanguageCode = Undefined, CommonUseClientServer.MainLanguageCode(), LanguageCode));
	
EndFunction

#EndRegion

#EndRegion

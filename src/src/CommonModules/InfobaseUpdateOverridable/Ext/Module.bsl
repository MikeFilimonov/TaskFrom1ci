////////////////////////////////////////////////////////////////////////////////
// Subsystem "IB version update".
//
////////////////////////////////////////////////////////////////////////////////

#Region ApplicationInterface

// Called before the handlers of IB data update.
//
Procedure BeforeInformationBaseUpdating() Export
	
EndProcedure

// Outdated. You should use procedure WhenAddingSubsystems of common module ConfigurationSubsystemsOverridable.
//
// Called before the beginning of the IB data update.
// Returns IB update procedures-handlers list for all supported IB versions.
//
// Example of adding the procedure-processor to the list:
//    Handler = Handlers.Add();
//    Handler.Version = "1.1.0.0";
//    Handler.Procedure = "IBUpdate.SwitchToVersion_1_1_0_0";
//
// Returns:
//   ValueTable - column content see in UpdateResults.UpdateHandlersNewTable.
//
Function UpdateHandlers() Export
	
	Handlers = UpdateResults.NewUpdateHandlersTable();
	
	Return Handlers;
	
EndFunction

// It is called after completion of IB data update.
// 
// Parameters:
//   PreviousInfobaseVersion     - String    - IB version before update. 0.0.0.0 for an empty IB.
//   CurrentIBVersion            - String    - IB version after update.
//   ExecutedHandlers            - ValueTree - list of
//                                             completed update procedures-handlers grouped by version number.
//  For searching the completed handlers:
// 	For Each Version From ExecutedHandlers.Rows Cycle
//	
// 		If Version.Version =
// 			"*" Then the group of handlers which are always executed.
// 		Else
// 			group of handlers which are executed for certain version.
// 		EndIf;
//	
// 		For Each Handler From Version.Rows
// 			Cycle ...
// 		EndDo;
//	
// 	EndDo;
//
//   PutReleaseNotes - Boolean -	If true, then show the form with updates description.
//   ExclusiveMode               - Boolean - shows that the update was executed in an exclusive mode.
//                                 True    - update was executed in the exclusive mode.
// 
Procedure AfterInformationBaseUpdate(Val PreviousInfobaseVersion, Val CurrentIBVersion,
	Val ExecutedHandlers, PutReleaseNotes, ExclusiveMode) Export
	
EndProcedure

// It is called when you prepare a tabular document with application change description.
//   
// Parameters:
//   Template - SpreadsheetDocument - update description.
//   
// See also a common template ReleaseNotes.
//
Procedure OnPreparationOfUpdatesDescriptionTemplate(Val Template) Export
	
EndProcedure

// It is called to get the list of update handlers to be skipped.
// It is possible to disable only the update handlers with version number "*".
//
// Example of adding the disabled handler to the list:
//   NewExcept = DisconnectedHandlers.Add();
//   NewException.LibraryIdentifier = "StandardSubsystems";
//   NewExcept.Version = "*";
//   NewException.Procedure = "ReportsVariants.Update";
//
// Version - configuration version number in which
//          you need to disable the handler execution.
//
Procedure OnDisableUpdateHandlers(SwitchableHandlers) Export
	
EndProcedure

// Overrides the tooltip text indicating the path to the form "Application update results".
//
// Parameters:
//  ToolTipText - String - The tooltip wording.
//
Procedure WhenExplanationObtainingForApplicationUpdatingResults(ToolTipText) Export
	
EndProcedure

// Outdated. You should use procedure WhenExplanationObtainingForApplicationUpdatingResults.
// Overrides the tooltip text indicating the path to the form "Application update results".
//
// Parameters:
//  ToolTipText - String - The tooltip wording.
//
Procedure GetTextExplanationsForApplicationUpdateResults(ToolTipText) Export
	
EndProcedure

// Outdated. You should use procedure WhenDisconnectUpdateHandlers.
//
// It is called to get the list of update handlers which are not to be executed.
// It is possible to disable only the update handlers with version number "*".
//
// Example of adding the disabled handler to the list:
//   NewExcept = DisconnectedHandlers.Add();
//   NewException.LibraryIdentifier = "StandardSubsystems";
//   NewExcept.Version = "*";
//   NewException.Procedure = "ReportsVariants.Update";
//
// Version - configuration version number in which
//           you need to disable the handler execution.
//
Procedure AddDisablingUpdateHandlers(SwitchableHandlers) Export
	
EndProcedure

#EndRegion

#Region UpdateIB

// Procedure fills currency exchange rates on 01/01/2008.
//
Procedure FillExchangeRatesOn_01_01_2008(Currency) Export

	ExchangeRateDate = Date(2008, 1, 1);
	
	TableExchangeRates = InformationRegisters.ExchangeRates.CreateRecordManager();

	TableExchangeRates.Period    = ExchangeRateDate;
	TableExchangeRates.Currency    = Currency;
        
	If TableExchangeRates.Currency.Code = "643" Then
		TableExchangeRates.ExchangeRate = 1;
    ElsIf TableExchangeRates.Currency.Code = "978" Then
        TableExchangeRates.ExchangeRate = 35.9332;
	ElsIf TableExchangeRates.Currency.Code = "840" Then
		TableExchangeRates.ExchangeRate = 24.5462;
	EndIf;
	
	TableExchangeRates.Multiplicity = 1;
	TableExchangeRates.Write();

EndProcedure

#EndRegion


#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Function determines whether counterparty access groups are used or not.
//
//	Returns:
//		Boolean - If TRUE, it means that access groups are used
//
Function AccessGroupsAreUsed() Export
	
	Return
		GetFunctionalOption("UseRowLevelSecurity")
		AND GetFunctionalOption("UseCounterpartiesAccessGroups");
	
EndFunction

#EndRegion

#EndIf
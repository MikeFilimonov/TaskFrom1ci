#If Server Or ThickClientOrdinaryApplication Then

#Region ProgramInterface

// The procedure receives basic kind of the sale prices from user settings.
//
Function GetMainKindOfSalePrices() Export
	
	PriceTypesales = DriveReUse.GetValueByDefaultUser(UsersClientServer.AuthorizedUser(), "MainPriceTypesales");
	
	Return ?(ValueIsFilled(PriceTypesales), PriceTypesales, Catalogs.PriceTypes.Wholesale);
	
EndFunction

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#EndRegion

#EndIf
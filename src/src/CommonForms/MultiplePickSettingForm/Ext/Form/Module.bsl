#Region GeneralPurposeProceduresAndFunctions

&AtServer
// The procedure writes the filter settings to the user settings
//
Procedure WriteReportSettings()

	DriveServer.SetUserSetting(ShowBalance, 		"ShowBalance");
	DriveServer.SetUserSetting(ShowReserve, 		"ShowReserve");
	DriveServer.SetUserSetting(ShowAvailableBalance, "ShowAvailableBalance");
	DriveServer.SetUserSetting(ShowPrices, 		"ShowPrices");
	DriveServer.SetUserSetting(OutputBalancesMethod,	"OutputBalancesMethod");
	DriveServer.SetUserSetting(KeepCurrentHierarchy, "KeepCurrentHierarchy");
	
EndProcedure

&AtClient
// The procedure manages the availability of form items.
// 
// To minimize server calls the availability is controlled by the form pages
//
Procedure SetSwitchesEnabled(AvailabilityFlag)
	
	Items.GroupBalancesOutputMethod.CurrentPage = 
		?(AvailabilityFlag, 
			Items.GroupBalancesOutputMethod.ChildItems.PageSwitchAvailable, 
			Items.GroupBalancesOutputMethod.ChildItems.PageSwitchIsNotAvailable);
	
EndProcedure

#EndRegion

#Region FormEventHandlers

&AtServer
// Procedure - handler of the OnCreateAtServer event
//
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	User 			= Users.CurrentUser();
	OutputBalancesMethod	= DriveReUse.GetValueByDefaultUser(User, "OutputBalancesMethod");
	OutputBalancesMethod	= ?(ValueIsFilled(OutputBalancesMethod), OutputBalancesMethod, Enums.BalancesOutputMethodInSelection.InTable);
	
	SettingsStructure = New Structure("ShowBalance, ShowPrices, OutputBalancesMethod, KeepCurrentHierarchy",
				DriveReUse.GetValueByDefaultUser(User, "ShowBalance"),
				DriveReUse.GetValueByDefaultUser(User, "ShowPrices"),
				OutputBalancesMethod,
				DriveReUse.GetValueByDefaultUser(User, "KeepCurrentHierarchy"));
				
	// If redundancy is disabled, then there is no use to work with the redundancy switches and free balances
	InventoryReservationConstantValue = GetFunctionalOption("UseInventoryReservation"); 
	
	SettingsStructure.Insert("ShowReserve", 
		?(InventoryReservationConstantValue,
			DriveReUse.GetValueByDefaultUser(User, "ShowReserve"),
			False)
		);
		
	SettingsStructure.Insert("ShowAvailableBalance", 
		?(InventoryReservationConstantValue,
			DriveReUse.GetValueByDefaultUser(User, "ShowAvailableBalance"),
			False)
		);
		
	Items.ShowReserve.Enabled			= InventoryReservationConstantValue;
	Items.ShowAvailableBalance.Enabled	= InventoryReservationConstantValue;
	
	// Fill values
	FillPropertyValues(ThisForm, SettingsStructure);
	
EndProcedure

&AtClient
// Procedure - form event handler OnOpen
//
Procedure OnOpen(Cancel)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure

&AtClient
// Procedure - command handler "OK"
//
Procedure OK(Command)
	
	WriteReportSettings();
	Close(New Structure("ShowBalance, ShowReserve, ShowAvailableBalance, ShowPrices, OutputBalancesMethod, KeepCurrentHierarchy", 
			ShowBalance, 
			ShowReserve, 
			ShowAvailableBalance, 
			ShowPrices, 
			OutputBalancesMethod, 
			KeepCurrentHierarchy));
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ShowBalance attribute
//
Procedure ShowBalancesOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ShowReserve attribute
//
Procedure ShowReserveOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure

&AtClient
// Procedure - OnChange event handler of the ShowAvailableBalance attribute
//
Procedure ShowAvailableBalanceOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure

&AtClient
//  Procedure - OnChange event handler of the ShowPrices attribute
//
Procedure ShowPricesOnChange(Item)
	
	SetSwitchesEnabled(
							ShowBalance 
							OR ShowReserve 
							OR ShowAvailableBalance 
							OR ShowPrices);
	
EndProcedure

#EndRegion

#Region Private

#Region FormHeaderItemsEventHandlers
&AtClient
Procedure SetAsDefault(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined Or CurrentData.IsDefault Then
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Counterparty", CurrentData.Owner);
	ParametersStructure.Insert("NewDefaultShippingAddresses", CurrentData.Ref);
	
	SetAddressAsDefault(ParametersStructure);
	
	Items.List.Refresh();
	
EndProcedure

&AtServer
Procedure SetAddressAsDefault(ParametersStructure)
	
	ShippingAddressesServer.SetShippingAddressAsDefault(ParametersStructure);
	
EndProcedure

&AtClient
Procedure ChangeSelected(Command)
	GroupObjectsChangeClient.ChangeSelected(Items.List);
EndProcedure

#EndRegion

#EndRegion
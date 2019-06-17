#Region ListFormTableItemsEventHandlers

&AtClient
Procedure ListSelection(Item, SelectedRow, Field, StandardProcessing)
	
	CurrentRowData = Items.List.CurrentData;
	
	NotifyChoiceToParentForm(CurrentRowData);
	
EndProcedure

&AtClient
Procedure ListOnActivateRow(Item)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData <> Undefined Then
		Items.SetAsDefaultButton.Enabled = ValueIsFilled(CurrentData.ShippingAddress);
	EndIf;

EndProcedure

#EndRegion

#Region FormCommandsEventHandlers

&AtClient
Procedure SelectAddress(Command)
	
	CurrentRowData = Items.List.CurrentData;
	
	If CurrentRowData = Undefined Then
		Close();
	EndIf;
	
	NotifyChoiceToParentForm(CurrentRowData);
	
EndProcedure

&AtClient
Procedure SetAsDefault(Command)
	
	CurrentData = Items.List.CurrentData;
	
	If CurrentData = Undefined OR CurrentData.IsDefault OR ValueIsFilled(CurrentData.Counterparty) Then
		Return;
	EndIf;
	
	ParametersStructure = New Structure;
	ParametersStructure.Insert("Counterparty", CurrentData.Owner);
	ParametersStructure.Insert("NewDefaultShippingAddresses", CurrentData.ShippingAddress);
	
	SetAddressAsDefault(ParametersStructure);
	
	Items.List.Refresh();
	
EndProcedure

#EndRegion

#Region Private

&AtClient
Procedure NotifyChoiceToParentForm(CurrentRowData)
	
	ChoicedData = New Structure;
	
	If ValueIsFilled(CurrentRowData.Counterparty) Then
		ChoicedData.Insert("ShippingAddress", CurrentRowData.Counterparty);
	Else
		ChoicedData.Insert("ShippingAddress", CurrentRowData.ShippingAddress);
	EndIf;
	
	NotifyChoice(ChoicedData);
	
EndProcedure

&AtServer
Procedure SetAddressAsDefault(ParametersStructure)
	
	ShippingAddressesServer.SetShippingAddressAsDefault(ParametersStructure);
	
EndProcedure

#EndRegion

&AtClient
// Procedure - OnChange event handler of the Counterparty field
//
Procedure CounterpartyOnChange(Item)
	
	DriveClientServer.SetListFilterItem(List, "Owner", Counterparty, ValueIsFilled(Counterparty));
	
EndProcedure

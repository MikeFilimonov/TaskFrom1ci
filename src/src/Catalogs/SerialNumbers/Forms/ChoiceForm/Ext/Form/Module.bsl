
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Filter.Property("Owner") Then
		ThisObject.Title = "Serial numbers "+Parameters.Filter.Owner;
	ElsIf Parameters.Property("CurrentRow") AND ValueIsFilled(Parameters.CurrentRow) Then
		ThisObject.Title = "Serial numbers "+Parameters.CurrentRow.Owner;
	EndIf;
	
	If Parameters.Property("ShowSold") Then
		ShowSold = Parameters.ShowSold;
	Else	
		ShowSold = False;
	EndIf;
	
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	Items.Sold.Visible = ShowSold;
			
EndProcedure

&AtClient
Procedure SoldOnChange(Item)
	
	Items.Sold.Visible = ShowSold;
	List.Parameters.SetParameterValue("ShowSold", ShowSold);
	
EndProcedure

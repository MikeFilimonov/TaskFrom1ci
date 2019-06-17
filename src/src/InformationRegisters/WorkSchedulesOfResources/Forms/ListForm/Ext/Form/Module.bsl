
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("CompanyResource") Then
		DriveClientServer.SetListFilterItem(List, "CompanyResource", Parameters.CompanyResource);
	EndIf;
	
EndProcedure

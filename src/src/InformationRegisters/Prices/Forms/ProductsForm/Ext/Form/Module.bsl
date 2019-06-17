
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Price accessibility setup for editing.
	AllowedEditDocumentPrices = DriveAccessManagementReUse.AllowedEditDocumentPrices();
	
	Items.List.ReadOnly = Not AllowedEditDocumentPrices;
	
EndProcedure


#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetDynamicListParameters();
	
	Products = Parameters.Products;
	Characteristic = Parameters.Characteristic;
	Batch = Parameters.Batch;
	
EndProcedure

#EndRegion

#Region InternalProceduresAndFunctions

&AtServer
Procedure SetDynamicListParameters()
	
	ListReserveDecryption.Parameters.SetParameterValue("Company", DriveServer.GetCompany(Parameters.Company));
	ListReserveDecryption.Parameters.SetParameterValue("Products", Parameters.Products);
	ListReserveDecryption.Parameters.SetParameterValue("Characteristic", Parameters.Characteristic);
	ListReserveDecryption.Parameters.SetParameterValue("Batch", Parameters.Batch);
	
EndProcedure

#EndRegion


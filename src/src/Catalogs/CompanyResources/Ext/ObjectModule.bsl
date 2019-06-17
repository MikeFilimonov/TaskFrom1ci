#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

Procedure BeforeWrite(Cancel)
	
	If Not ValueIsFilled(ResourceValue) Then
		ResourceValue = Undefined;	
	EndIf;
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
EndProcedure

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then 
		Return;
	EndIf;
	
	RecordSet = InformationRegisters.CompanyResourceTypes.CreateRecordSet();
	RecordSet.Filter.CompanyResource.Set(Ref);
    RecordSet.Filter.CompanyResourceType.Set(Catalogs.CompanyResourceTypes.AllResources);
	
	NewRecord = RecordSet.Add();
	NewRecord.CompanyResourceType = Catalogs.CompanyResourceTypes.AllResources;
	NewRecord.CompanyResource = Ref;
	RecordSet.Write();
	
EndProcedure

#EndIf

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If (Parameters.FillingValues.Property("CompanyResourceType")
		AND ValueIsFilled(Parameters.FillingValues.CompanyResourceType))
		OR Parameters.Property("AvailabilityOfKind") Then
		
		Items.CompanyResourceType.ReadOnly = True;
		
		If Parameters.Property("ValueCompanyResourceType") Then
			Record.CompanyResourceType = Parameters.ValueCompanyResourceType;
		EndIf;
		
	ElsIf (Parameters.FillingValues.Property("CompanyResource")
		AND ValueIsFilled(Parameters.FillingValues.CompanyResource))
		OR Parameters.Property("ResourseAvailability") Then
		
		Items.CompanyResource.ReadOnly = True;
		
		If Record.CompanyResourceType = Catalogs.CompanyResourceTypes.AllResources Then
			Items.CompanyResourceType.ReadOnly = True;
		EndIf;
		
	ElsIf Parameters.Property("AvailabilityAllResources")
		AND Record.CompanyResourceType = Catalogs.CompanyResourceTypes.AllResources Then
		
		Items.CompanyResourceType.ReadOnly = True;
		
	ElsIf Parameters.CopyingValue <> Undefined 
		AND Parameters.CopyingValue.CompanyResourceType = Catalogs.CompanyResourceTypes.AllResources Then
		
		Items.CompanyResourceType.ReadOnly = True;
		
	EndIf;
	
EndProcedure

// Procedure - event handler AfterWrite form.
//
&AtClient
Procedure AfterWrite(WriteParameters)
	
	Notify("Record_CompanyResourceTypes");
	
EndProcedure

#EndRegion

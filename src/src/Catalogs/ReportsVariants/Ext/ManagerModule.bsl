#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Attributes that can be changed at once for multiple objects.
Function EditedAttributesInGroupDataProcessing() Export
	
	Result = New Array;
	Result.Add("Description");
	Result.Add("Author");
	Result.Add("ForAuthorOnly");
	
	Return Result;
	
EndFunction

#EndRegion

#EndIf

#Region ObjectHandlers

Procedure FormGetProcessing(FormType, Parameters, SelectedForm, AdditionalInfo, StandardProcessing)
	
	#If Server OR ThickClientOrdinaryApplication OR ExternalConnection Then
	
	// Override for favorites - instead of the card with the report placement
	// settings, its main form will be opened.
	If FormType = "ObjectForm" Then
		
		If Parameters.Property("LocationSetup") AND Parameters.LocationSetup Then
			Return;
		EndIf;
		
		VariantRef = CommonUseClientServer.StructureProperty(Parameters, "Key");
		If Not ValueIsFilled(VariantRef) Then
			Raise NStr("en = 'New report option can be created only from the report form'");
		EndIf;
		
		LocationSetup = CommonUseClientServer.StructureProperty(Parameters, "LocationSetup");
		If LocationSetup = True Then
			Return;
		EndIf;
		
		OpenParameters = ReportsVariants.OpenParameters(VariantRef);
		
		ReportsVariantsClientServer.AddKeyToStructure(OpenParameters, "TakeMeasurements", False);
		
		If OpenParameters.ReportType = "Internal" Then
			Type = "Report";
		ElsIf OpenParameters.ReportType = "Additional" Then
			
			Type = "ExternalReport";
			
			If Not OpenParameters.Property("Connected") Then
				ReportsVariants.WhenConnectingReport(OpenParameters);
			EndIf;
			
			If Not OpenParameters.Connected Then
				Raise NStr("en = 'External report option can be opened only from the report form.'");
			EndIf;
			
		Else
			Raise NStr("en = 'External report option can be opened only from the report form.'");
		EndIf;
		
		FullReportName = Type + "." + OpenParameters.ReportName;
		
		UniquenessKey = ReportsClientServer.UniquenessKey(FullReportName, OpenParameters.VariantKey);
		OpenParameters.Insert("PrintParametersKey",	UniquenessKey);
		OpenParameters.Insert("WindowOptionsKey",	UniquenessKey);
		
		StandardProcessing = False;
		
		If OpenParameters.ReportType = "Additional" Then // For the platform.
			
			SelectedForm = "Catalog.ReportVariants.Form.ItemForm";
			Parameters.Insert("ReportFormOpeningParameters", OpenParameters);
			
			Return;
			
		EndIf;
		
		SelectedForm = FullReportName + ".Form";
		CommonUseClientServer.ExpandStructure(Parameters, OpenParameters);
		
	EndIf;
	
	#EndIf	
	
EndProcedure

#EndRegion
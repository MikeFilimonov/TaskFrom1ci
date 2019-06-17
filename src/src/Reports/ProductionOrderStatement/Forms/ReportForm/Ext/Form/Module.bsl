// Parameters:
// Parameters - FormDataStructure - Report parameters
//
&AtServer
Procedure SetSelectionReport(Parameters) Export
	
	If Parameters.Property("Filter") AND Parameters.Filter.Property("ProductionOrder") Then
		
		DocumentParameter = Parameters.Filter.ProductionOrder;
		If TypeOf(DocumentParameter) = Type("Array") Then
			DocumentType = TypeOf(DocumentParameter[0]);		
		Else
			DocumentType = TypeOf(DocumentParameter);		
		EndIf;
		
		If DocumentType <> Type("DocumentRef.ProductionOrder") Then
		
			Query = New Query("SELECT DISTINCT
			                      |	DocumentSource.BasisDocument AS ProductionOrder
			                      |FROM
			                      |	Document.Production AS DocumentSource
			                      |WHERE
			                      |	DocumentSource.Ref IN(&DocumentParameter)");
								  
			Query.SetParameter("DocumentParameter", DocumentParameter);
			ResultTable = Query.Execute().Unload();
			Parameters.Filter.ProductionOrder = ResultTable.UnloadColumn("ProductionOrder");			
		
		EndIf;
		
	EndIf;
	
EndProcedure

#Region ProcedureFormEventHandlers

// Procedure - form event handler "OnCreateAtServer".
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetSelectionReport(Parameters);
	
EndProcedure

&AtServer
Procedure OnSaveUserSettingsAtServer(Settings)
	ReportsVariants.OnSaveUserSettingsAtServer(ThisObject, Settings);
EndProcedure

#EndRegion

#Region AddTheHandlersOfServiceEventssubscriptions

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	ServerHandlers["ServiceTechnology.DataExportImport\BeforeDataExport"].Add(
		"InfobaseUpdateServiceSaaSSTL");
	
	ServerHandlers["ServiceTechnology.DataExportImport\BeforeDataImport"].Add(
		"InfobaseUpdateServiceSaaSSTL");
	
EndProcedure

#EndRegion

#Region HandlersOfTheServiceEvents

// Called before data export.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - container manager that is used in the process of
//      data export. For more information, see a comment to the DataExportImportContainerManager application interface processor.
Procedure BeforeDataExport(Container) Export
	
	FileName = Container.CreateRandomFile("xml", SubsystemsVersionsDataForExportImportType());
	
	SubsystemVersions = New Structure();
	
	SubsystemDescriptions = StandardSubsystemsreuse.SubsystemDescriptions().ByNames;
	For Each SubsystemDescription In SubsystemDescriptions Do
		SubsystemVersions.Insert(SubsystemDescription.Key, UpdateResults.IBVersion(SubsystemDescription.Key));
	EndDo;
	
	DataExportImportService.WriteObjectToFile(SubsystemVersions, FileName);
	Container.SetObjectsQuantity(FileName, SubsystemVersions.Count());
	
EndProcedure

// Called before data import.
//
// Parameters:
//  Container - DataProcessorObject.DataExportImportContainerManager - manager
//    of a container that is used in the data import process. For more information, see a comment to the
//    DataExportImportContainerManager application interface processor.
//
Procedure BeforeDataImport(Container) Export
	
	FileName = Container.GetRandomFile(SubsystemsVersionsDataForExportImportType());
	
	SubsystemVersions = DataExportImportService.ReadObjectFromFile(FileName);
	
	BeginTransaction();
	
	Try
		
		For Each SubsystemVersion In SubsystemVersions Do
			InfobaseUpdateService.SetIBVersion(SubsystemVersion.Key, SubsystemVersion.Value, (SubsystemVersion.Key = Metadata.Name));
		EndDo;
		
		CommitTransaction();
		
	Except
		
		RollbackTransaction();
		Raise;
		
	EndTry;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Function SubsystemsVersionsDataForExportImportType()
	
	Return "1cfresh\ApplicationData\SubstemVersions";
	
EndFunction

#EndRegion

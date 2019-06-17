#Region ServiceProgramInterface

Function FileCatalogsAndStorageObjects() Export
	
	FileCatalogs = New Map();
	StorageObjectsInInfobase = New Map();
	
	Handlers = IntegrationHandlers();
	
	For Each Handler In Handlers Do
		
		HandlerModule = ServiceTechnologyIntegrationWithSSL.CommonModule(Handler);
		
		HandlerFilesCatalogs = HandlerModule.FileCatalogs();
		For Each HandlerFilesCatalog In HandlerFilesCatalogs Do
			FileCatalogs.Insert(HandlerFilesCatalog.FullName(), Handler);
		EndDo;
		
		HandlerStorageObjects = HandlerModule.InfobaseFilesStorageObjects();
		For Each HandlerStorageObject In HandlerStorageObjects Do
			StorageObjectsInInfobase.Insert(HandlerStorageObject.FullName(), Handler);
		EndDo;
		
	EndDo;
	
	Cache = New Structure("FileCatalogs, StorageObjects", FileCatalogs, StorageObjectsInInfobase);
	
	Return Cache;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function IntegrationHandlers()
	
	IntegrationHandlers = New Array();
	
	EventHandlers = CommonUse.ServiceEventProcessor(
		"ServiceTechnology.SaaS.FileFunctionsSaaS\OnFillFileFunctionsIntegrationHandlersSaaS");
	For Each EventHandler In EventHandlers Do
		EventHandler.Module.OnFillFileFunctionsIntegrationHandlersSaaS(IntegrationHandlers);
	EndDo;
	
	Return IntegrationHandlers;
	
EndFunction

#EndRegion

///////////////////////////////////////////////////////////////////////////////////
// Subsystem "Access management in service model".
//
///////////////////////////////////////////////////////////////////////////////////

#Region ServiceProgramInterface

// See details of the same procedure in the StandardSubsystemsServer module.
Procedure OnAddHandlersOfServiceEvents(ClientHandlers, ServerHandlers) Export
	
	// SERVERSIDE HANDLERS.
	
	If CommonUse.SubsystemExists("StandardSubsystems.SaaS.JobQueue") Then
		ServerHandlers[
			"StandardSubsystems.SaaS.JobQueue\ListOfTemplatesOnGet"].Add(
				"AccessManagementServiceSaaS");
	EndIf;
	
	If CommonUse.SubsystemExists("ServiceTechnology.DataExportImport") Then
		ServerHandlers[
			"ServiceTechnology.DataExportImport\AfterDataImportFromOtherMode"].Add(
				"AccessManagementServiceSaaS");
	EndIf;
	
EndProcedure

// Handler of the OnReceiveTemplatesList event.
//
// Forms a list of queue jobs templates
//
// Parameters:
//  Patterns - String array. You should add the names
//   of predefined undivided scheduled jobs in the parameter
//   that should be used as a template for setting a queue.
//
Procedure ListOfTemplatesOnGet(Patterns) Export
	
	Patterns.Add("DataFillingForAccessLimit");
	
EndProcedure

// Sets a flag in jobs queue for
// the use of the job that corresponds to a scheduled job for completion of access restriction data.
//
// Parameters:
//  Use - Boolean - new value of the usage check box.
//
Procedure SetDataFillingForAccessRestriction(Use) Export
	
	Pattern = JobQueue.TemplateByName("DataFillingForAccessLimit");
	
	JobFilter = New Structure;
	JobFilter.Insert("Pattern", Pattern);
	Jobs = JobQueue.GetJobs(JobFilter);
	
	JobParameters = New Structure("Use", Use);
	JobQueue.ChangeTask(Tasks[0].ID, JobParameters);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// It is called once data is imported
// from a local version to the service data area or vice versa.
//
Procedure AfterDataImportFromOtherMode() Export
	
	Catalogs.AccessGroupsProfiles.UpdateStandardProfiles(); 
	
EndProcedure

// Called when a message is processed http://www.1c.ru/SaaS/RemoteAdministration/App/a.b.c.d}SetFullControl.
//
// Parameters:
//  DataAreaUser - CatalogRef.Users - user 
//   whose membership in Administrators group should be changed.
//  AccessPermitted - Boolean - True - include user
//   in the group, False - exclude user from the group.
//
Procedure SetUserIdentityToAdministratorsGroup(Val DataAreaUser, Val AccessPermitted) Export
	
	GroupAdministrators = Catalogs.AccessGroups.Administrators;
	
	Block = New DataLock;
	LockItem = Block.Add("Catalog.AccessGroups");
	LockItem.SetValue("Ref", GroupAdministrators);
	Block.Lock();
	
	ObjectGroup = GroupAdministrators.GetObject();
	
	UserRow = ObjectGroup.Users.Find(DataAreaUser, "User");
	
	If AccessPermitted AND UserRow = Undefined Then
		
		UserRow = ObjectGroup.Users.Add();
		UserRow.User = DataAreaUser;
		ObjectGroup.Write();
		
	ElsIf Not AccessPermitted AND UserRow <> Undefined Then
		
		ObjectGroup.Users.Delete(UserRow);
		ObjectGroup.Write();
	Else
		AccessManagement.UpdateUsersRoles(DataAreaUser);
	EndIf;
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// The Current ToDos subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Returns the array of command interface subsystems
// which include the transferred metadata object.
//
// Parameters:
//  MetadataObjectName - String - Full metadata object name.
//
// Returns: 
//  Array - the array of application command interface subsystems.
//
Function SectionsForObject(MetadataObjectName) Export
	ObjectAffiliation = ToDoListServiceReUse.ObjectAffiliationToCommandInterfaceSections();
	Return ObjectAffiliation[MetadataObjectName];
EndFunction

#EndRegion


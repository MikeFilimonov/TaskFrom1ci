
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	GLAccountsInStorageAddress = Parameters.GLAccountsInStorageAddress;
	GLAccounts.Load(GetFromTempStorage(GLAccountsInStorageAddress));
	
EndProcedure

#EndRegion

#Region CommandHandlers

&AtClient
Procedure OK(Command)
	
	WriteGLAccountsToStorage();
	Close(DialogReturnCode.OK);

EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
// The procedure places pick-up results in the storage.
//
Procedure WriteGLAccountsToStorage() 
	
	PutToTempStorage(GLAccounts.Unload(), GLAccountsInStorageAddress);
	
EndProcedure

#EndRegion

////////////////////////////////////////////////////////////////////////////////
// Attached files subsystem.
//
////////////////////////////////////////////////////////////////////////////////

#Region ProgramInterface

// Allows to override files storage catalogs by owners types.
// 
// Parameters:
//  TypeFileOwner   - Reference type of the object to which the file is attached.
//
//  NamesOfCatalogs - Map that contains the catalogs names in the keys.
//                    When calling it contains the standard
//                    name of one catalog, that is marked as basic (if it exists).
//                    The main catalog is used for interactive communication
//                    with the user. To specify the basic catalog,
//                    it is necessary to set Map to True.
//                    If you set True more than once, there will be an error.
//
Procedure OnDeterminingFilesStorageCatalogs(TypeFileOwner, NamesOfCatalogs) Export
	
	KeysToDeleteArray = New Array;
	For Each KeyAndValue In NamesOfCatalogs Do
		If Metadata.Catalogs.Find(KeyAndValue.Key) = Undefined Then
			KeysToDeleteArray.Add(KeyAndValue.Key);
		EndIf;
	EndDo;
	For Each Element In KeysToDeleteArray Do
		NamesOfCatalogs.Delete(Element);
	EndDo;
	
EndProcedure

#EndRegion
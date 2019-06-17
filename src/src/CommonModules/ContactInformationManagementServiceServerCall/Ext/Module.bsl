////////////////////////////////////////////////////////////////////////////////////////////////////
// The Contact information subsystem.
// 
////////////////////////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

//  Returns enumeration value type of the contact information kind.
//
//  Parameters:
//      InformationKind - CatalogRef.ContactInformationTypes, Structure - source data.
//
//  Returns:
//      EnumRefContactInfomationTypes - value of the Type field.
//
Function TypeKindContactInformation(Val InformationKind) Export
	
	Return ContactInformationManagementService.TypeKindContactInformation(InformationKind);
	
EndFunction

#EndRegion

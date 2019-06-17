#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ProgramInterface

// Returns a list of
// attributes that can be edited using the objects batch change data processor.
//
Function EditedAttributesInGroupDataProcessing() Export
	
	EditableAttributes = New Array;
	Return EditableAttributes;
	
EndFunction

#EndRegion

#Region ServiceProceduresAndFunctions

Function SuppliedApllicationSettings(OnlyForInitialFill = False) Export
	
	Settings = New ValueTable;
	Settings.Columns.Add("Presentation");
	Settings.Columns.Add("ApplicationName");
	Settings.Columns.Add("ApplicationType");
	Settings.Columns.Add("SignAlgorithm");
	Settings.Columns.Add("HashAlgorithm");
	Settings.Columns.Add("EncryptionAlgorithm");
	Settings.Columns.Add("ID");
	
	TypeArray = New TypeDescription("Array");
	
	Settings.Columns.Add("SignAlgorithms",		TypeArray);
	Settings.Columns.Add("HashAlgorithms",		TypeArray);
	Settings.Columns.Add("EncryptAlgorithms",	TypeArray);
		
	// Microsoft Enhanced CSP
	Setting = Settings.Add();
	Setting.Presentation		= NStr("en = 'Microsoft Enhanced CSP'");
	Setting.ApplicationName		= "Microsoft Enhanced Cryptographic Provider v1.0";
	Setting.ApplicationType		= 1;
	Setting.SignAlgorithm		= "RSA_SIGN"; // One option.
	Setting.HashAlgorithm		= "MD5";      // Options: SHA1, MD2, MD4, MD5.
	Setting.EncryptionAlgorithm	= "RC2";      // Options: RC2, RC4, DES, 3DES.
	Setting.ID					= "MicrosoftEnhanced";
	
	Setting.SignAlgorithms.Add("RSA_SIGN");
	Setting.HashAlgorithms.Add("SHA-1");
	Setting.HashAlgorithms.Add("MD2");
	Setting.HashAlgorithms.Add("MD4");
	Setting.HashAlgorithms.Add("MD5");
	Setting.EncryptAlgorithms.Add("RC2");
	Setting.EncryptAlgorithms.Add("RC4");
	Setting.EncryptAlgorithms.Add("DES");
	Setting.EncryptAlgorithms.Add("3DES");
			
	Return Settings;
	
EndFunction

#Region InfoBaseUpdate

Procedure FillInitialSettings() Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	Applications.Ref AS Ref
	|FROM
	|	Catalog.DigitalSignatureAndEncryptionApplications AS Applications
	|WHERE
	|	Applications.ApplicationName = &ApplicationName
	|	AND Applications.ApplicationType = &ApplicationType";
	
	SuppliedSettings = SuppliedApllicationSettings(True);
	For Each SuppliedSetting In SuppliedSettings Do
		
		Query.SetParameter("ApplicationName", SuppliedSetting.ApplicationName);
		Query.SetParameter("ApplicationType", SuppliedSetting.ApplicationType);
		
		If Not Query.Execute().IsEmpty() Then
			Continue;
		EndIf;
		
		ApplicationObject = Catalogs.DigitalSignatureAndEncryptionApplications.CreateItem();
		FillPropertyValues(ApplicationObject, SuppliedSetting);
		ApplicationObject.Description = SuppliedSetting.Presentation;
		UpdateResults.WriteData(ApplicationObject);
		
	EndDo;
	
EndProcedure

#EndRegion

#EndRegion

#EndIf

#Region EventsHandlers

Procedure FormGetProcessing(FormKind, Parameters, SelectedForm, AdditionalInformation, StandardProcessing)
	
	If FormKind = "ListForm" Then
		StandardProcessing = False;
		Parameters.Insert("ShowApplicationPage");
		SelectedForm = Metadata.CommonForms.ElectronicSignatureAndEncriptionSettings;
	EndIf;
	
EndProcedure

Procedure ChoiceDataGetProcessing(ChoiceData, Parameters, StandardProcessing)
	
	Parameters.Filter.Insert("DeletionMark", False);
	
EndProcedure

#EndRegion

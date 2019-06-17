
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If ValueIsFilled(Parameters.CertificateAddress) Then
		CertificateData = GetFromTempStorage(Parameters.CertificateAddress);
		ElectronicSignature = New CryptoCertificate(CertificateData);
		CertificateAddress = PutToTempStorage(CertificateData, UUID);
		
	ElsIf ValueIsFilled(Parameters.Ref) Then
		CertificateAddress = CertificateAddress(Parameters.Ref, UUID);
		
		If CertificateAddress = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Unable to open the
				     |%1 certificate as it is not found in the catalog.'"), Parameters.Ref);
		EndIf;
	Else // Imprint
		CertificateAddress = CertificateAddress(Parameters.Imprint, UUID);
		
		If CertificateAddress = Undefined Then
			Raise StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = 'Unable to open certificate as it was
				     |not found using the %1 thumbprint.'"), Parameters.Imprint);
		EndIf;
	EndIf;
	
	If CertificateData = Undefined Then
		CertificateData = GetFromTempStorage(CertificateAddress);
		ElectronicSignature = New CryptoCertificate(CertificateData);
	EndIf;
	
	CertificateStructure = DigitalSignatureClientServer.FillCertificateStructure(ElectronicSignature);
	
	PurposeSigning = ElectronicSignature.UseToSign;
	PurposeEncryption = ElectronicSignature.UseForEncryption;
	
	Imprint      = CertificateStructure.Imprint;
	IssuedToWhom      = CertificateStructure.IssuedToWhom;
	WhoIssued       = CertificateStructure.WhoIssued;
	ValidUntil = CertificateStructure.ValidUntil;
	
	FillCertificatePurposeCodes(CertificateStructure.Purpose, PurposeCodes);
	
	FillSubjectProperties(ElectronicSignature);
	FillIssuerProperties(ElectronicSignature);
	
	InternalFieldsGroup = "Common";
	FillCertificateInternalFields();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure InternalFieldsGroupAfterChange(Item)
	
	FillCertificateInternalFields();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure SaveToFile(Command)
	
	DigitalSignatureServiceClient.SaveCertificate(, CertificateAddress);
	
EndProcedure

&AtClient
Procedure Validate(Command)
	
	DigitalSignatureClient.CheckCertificate(New NotifyDescription(
		"CheckEnd", ThisObject), CertificateAddress);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

// Continue the Check procedure.
&AtClient
Procedure CheckEnd(Result, NotSpecified) Export
	
	If Result = True Then
		ShowMessageBox(, NStr("en = 'ElectronicSignature is valid.'"));
		
	ElsIf Result <> Undefined Then
		ShowMessageBox(, NStr("en = 'ElectronicSignature is invalid due to:'")
			+ Chars.LF + Result);
	EndIf;
	
EndProcedure

&AtServer
Procedure FillSubjectProperties(ElectronicSignature)
	
	Collection = DigitalSignatureClientServer.CertificateSubjectProperties(ElectronicSignature);
	
	PropertiesPresentation = New ValueList;
	PropertiesPresentation.Add("CommonName",	NStr("en = 'Common name'"));
	PropertiesPresentation.Add("Country",		NStr("en = 'Country'"));
	PropertiesPresentation.Add("Region",		NStr("en = 'Region'"));
	PropertiesPresentation.Add("Settlement",	NStr("en = 'Settlement'"));
	PropertiesPresentation.Add("Street",		NStr("en = 'Street'"));
	PropertiesPresentation.Add("Company",		NStr("en = 'Company'"));
	PropertiesPresentation.Add("Department",	NStr("en = 'Department'"));
	PropertiesPresentation.Add("Position",		NStr("en = 'Position'"));
	PropertiesPresentation.Add("Email",			NStr("en = 'Email'"));
	PropertiesPresentation.Add("TIN",			NStr("en = 'TIN'"));
	PropertiesPresentation.Add("Surname",		NStr("en = 'Last name'"));
	PropertiesPresentation.Add("Name",			NStr("en = 'Name'"));
	PropertiesPresentation.Add("Patronymic",	NStr("en = 'Patronymic'"));
	
	For Each ItemOfList In PropertiesPresentation Do
		If Not ValueIsFilled(Collection[ItemOfList.Value]) Then
			Continue;
		EndIf;
		String = Subject.Add();
		String.Property = ItemOfList.Presentation;
		String.Value = Collection[ItemOfList.Value];
	EndDo;
	
EndProcedure

&AtServer
Procedure FillIssuerProperties(ElectronicSignature)
	
	Collection = DigitalSignatureClientServer.CertificateIssuerProperties(ElectronicSignature);
	
	PropertiesPresentation = New ValueList;
	PropertiesPresentation.Add("CommonName",	NStr("en = 'Common name'"));
	PropertiesPresentation.Add("Country",		NStr("en = 'Country'"));
	PropertiesPresentation.Add("Region",		NStr("en = 'Region'"));
	PropertiesPresentation.Add("Settlement",	NStr("en = 'Settlement'"));
	PropertiesPresentation.Add("Street",		NStr("en = 'Street'"));
	PropertiesPresentation.Add("Company",		NStr("en = 'Company'"));
	PropertiesPresentation.Add("Department",	NStr("en = 'Department'"));
	PropertiesPresentation.Add("Email",			NStr("en = 'Email'"));
	PropertiesPresentation.Add("TIN",			NStr("en = 'TIN'"));
	
	For Each ItemOfList In PropertiesPresentation Do
		If Not ValueIsFilled(Collection[ItemOfList.Value]) Then
			Continue;
		EndIf;
		String = Issuer.Add();
		String.Property = ItemOfList.Presentation;
		String.Value = Collection[ItemOfList.Value];
	EndDo;
	
EndProcedure

&AtServer
Procedure FillCertificateInternalFields()
	
	InnerContent.Clear();
	CertificateBinaryData = GetFromTempStorage(CertificateAddress);
	ElectronicSignature = New CryptoCertificate(CertificateBinaryData);
	
	If InternalFieldsGroup = "Common" Then
		AddProperty(ElectronicSignature, "Version",                    NStr("en = 'Version'"));
		AddProperty(ElectronicSignature, "StartDate",                NStr("en = 'Start date'"));
		AddProperty(ElectronicSignature, "EndDate",             NStr("en = 'End date'"));
		AddProperty(ElectronicSignature, "UseToSign",    NStr("en = 'Use for signature'"));
		AddProperty(ElectronicSignature, "UseForEncryption", NStr("en = 'Use for encryption'"));
		AddProperty(ElectronicSignature, "OpenKey",              NStr("en = 'Public key'"), True);
		AddProperty(ElectronicSignature, "Imprint",                 NStr("en = 'Thumbprint'"), True);
		AddProperty(ElectronicSignature, "SerialNumber",             NStr("en = 'Serial number'"), True);
	Else
		Collection = ElectronicSignature[InternalFieldsGroup];
		For Each KeyAndValue In Collection Do
			AddProperty(Collection, KeyAndValue.Key, KeyAndValue.Key);
		EndDo;
	EndIf;
	
EndProcedure

&AtServer
Procedure AddProperty(PropertyValues, Property, Presentation, LowerRegister = Undefined)
	
	Value = PropertyValues[Property];
	If TypeOf(Value) = Type("Date") Then
		Value = ToLocalTime(Value, SessionTimeZone());
	ElsIf TypeOf(Value) = Type("FixedArray") Then
		FixedArray = Value;
		Value = "";
		For Each ArrayElement In FixedArray Do
			Value = Value + ?(Value = "", "", Chars.LF) + TrimAll(ArrayElement);
		EndDo;
	EndIf;
	
	String = InnerContent.Add();
	String.Property = Presentation;
	
	If LowerRegister = True Then
		String.Value = Lower(Value);
	Else
		String.Value = Value;
	EndIf;
	
EndProcedure

// Converts certificates destinations to destination codes.
//  
// Parameters:
//  Purpose    - String - multiline certificate purpose, for example:
//                           Microsoft Encrypted File System (1.3.6.1.4.1.311.10.3.4)
//                           |Email Protection (1.3.6.1.5.5.7.3.4)
//                           |TLS Web Client Authentication (1.3.6.1.5.5.7.3.2).
//  
//  PurposeCodes - String - Destination codes 1.3.6.1.4.1.311.10.3.4, 1.3.6.1.5.5.7.3.4, 1.3.6.1.5.5.7.3.2.
//
&AtServer
Procedure FillCertificatePurposeCodes(Purpose, PurposeCodes)
	
	SetPrivilegedMode(True);
	
	Codes = "";
	
	For IndexOf = 1 To StrLineCount(Purpose) Do
		
		String = StrGetLine(Purpose, IndexOf);
		CurrentCode = "";
		
		Position = StringFunctionsClientServer.FindCharFromEnd(String, "(");
		If Position <> 0 Then
			CurrentCode = Mid(String, Position + 1, StrLen(String) - Position - 1);
		EndIf;
		
		If ValueIsFilled(CurrentCode) Then
			Codes = Codes + ?(Codes = "", "", ", ") + TrimAll(CurrentCode);
		EndIf;
		
	EndDo;
	
	PurposeCodes = Codes;
	
EndProcedure

&AtServer
Function CertificateAddress(RefsThumbprint, FormID = Undefined)
	
	CertificateData = Undefined;
	
	If TypeOf(RefsThumbprint) = Type("CatalogRef.DigitalSignaturesAndEncryptionKeyCertificates") Then
		Storage = CommonUse.ObjectAttributeValue(RefsThumbprint, "CertificateData");
		If TypeOf(Storage) = Type("ValueStorage") Then
			CertificateData = Storage.Get();
		EndIf;
	Else
		Query = New Query;
		Query.SetParameter("Imprint", RefsThumbprint);
		Query.Text =
		"SELECT
		|	Certificates.CertificateData
		|FROM
		|	Catalog.DigitalSignaturesAndEncryptionKeyCertificates AS Certificates
		|WHERE
		|	Certificates.Imprint = &Imprint";
		
		Selection = Query.Execute().Select();
		If Selection.Next() Then
			CertificateData = Selection.CertificateData.Get();
		Else
			ElectronicSignature = DigitalSignatureService.GetCertificateByImprint(RefsThumbprint, False, False);
			If ElectronicSignature <> Undefined Then
				CertificateData = ElectronicSignature.Unload();
			EndIf;
		EndIf;
	EndIf;
	
	If TypeOf(CertificateData) = Type("BinaryData") Then
		Return PutToTempStorage(CertificateData, FormID);
	EndIf;
	
	Return Undefined;
	
EndFunction

#EndRegion

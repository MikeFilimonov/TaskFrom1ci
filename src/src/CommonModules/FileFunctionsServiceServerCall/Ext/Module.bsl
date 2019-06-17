﻿////////////////////////////////////////////////////////////////////////////////
// Subsystem "File functions".
//
////////////////////////////////////////////////////////////////////////////////

#Region ServiceProceduresAndFunctions

// See this procedure in module FileFunctionsService.
Procedure WriteTextExtractionResult(FileOrVersionRef,
                                            ExtractionResult,
                                            TextTemporaryStorageAddress) Export
	
	FileFunctionsService.WriteTextExtractionResult(
		FileOrVersionRef,
		ExtractionResult,
		TextTemporaryStorageAddress);
	
EndProcedure

// Only for internal use.
Procedure CheckSignatures(SourceData, RowsData) Export
	
	If Not CommonUse.SubsystemExists("StandardSubsystems.DigitalSignature") Then
		Return;
	EndIf;
	ModuleDigitalSignature = CommonUse.CommonModule("DigitalSignature");
	
	CryptoManager = ModuleDigitalSignature.CryptoManager("SignatureCheck");
	
	For Each SignatureRow In RowsData Do
		
		ErrorDescription = "";
		SignatureVerified = ModuleDigitalSignature.VerifySignature(CryptoManager,
			SourceData, SignatureRow.SignatureAddress, ErrorDescription);
		
		If SignatureVerified Then
			SignatureRow.Status  = NStr("en = 'Correct'");
			SignatureRow.Wrong = False;
		Else
			SignatureRow.Status  = NStr("en = 'Incorrect'") + ". " + ErrorDescription;
			SignatureRow.Wrong = True;
		EndIf;
	EndDo;
	
EndProcedure

#EndRegion
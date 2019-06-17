
#Region FormEventHadlers

&AtServer
Procedure AfterWriteAtServer(CurrentObject, WriteParameters)
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// Handler of the subsystem prohibiting the object attribute editing.
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	// StandardSubsystems.Properties
	PropertiesManagement.BeforeWriteAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	DriveClientServer.SetPictureForComment(Items.GroupComment, Object.Comment);
	
	// StandardSubsystems.ObjectsAttributesEditProhibition
	ObjectsAttributesEditProhibition.LockAttributes(ThisForm);
	// End StandardSubsystems.ObjectsAttributesEditProhibition
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnCreateAtServer(ThisForm, Object, "GroupAdditionalAttributes");
	// End StandardSubsystems.Properties
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	// StandardSubsystems.Properties
	PropertiesManagement.OnReadAtServer(ThisForm, CurrentObject);
	// End StandardSubsystems.Properties
	
EndProcedure

#EndRegion

#Region FormItemEventHadlers

&AtClient
Procedure DocumentKindOnChange(Item)
	
	Object.Description = GenerateDescription(Object.DocumentKind, Object.Number, Object.IssueDate);
	
EndProcedure

&AtClient
Procedure NumberOnChange(Item)
	
	Object.Description = GenerateDescription(Object.DocumentKind, Object.Number, Object.IssueDate);
	
EndProcedure

&AtClient
Procedure IssueDateOnChange(Item)
	
	Object.Description = GenerateDescription(Object.DocumentKind, Object.Number, Object.IssueDate);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Function GenerateDescription(DocumentKind, Number, IssueDate)
	
	TextName = StringFunctionsClientServer.SubstituteParametersInString(
		NStr("en = '%1 #%2 %3'"),
		TrimAll(String(DocumentKind)),
		TrimAll(Number),
		?(ValueIsFilled(IssueDate), 
			NStr("en = 'dated'") + " " + Format(IssueDate, "DLF=D"),
			""));
		
	Return TextName;
	
EndFunction

#EndRegion

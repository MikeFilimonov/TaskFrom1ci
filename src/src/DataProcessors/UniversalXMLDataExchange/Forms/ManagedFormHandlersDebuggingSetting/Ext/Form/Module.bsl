﻿
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	// Access right check should be the first one.
	If Not AccessRight("Administration", Metadata) Then
		Raise NStr("en = 'Data processor use in interactive mode is available to administrator only.'");
	EndIf;
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	Object.ExchangeFileName = Parameters.ExchangeFileName;
	Object.ExchangeRulesFilename = Parameters.ExchangeRulesFilename;
	Object.EventHandlersExternalDataProcessorFileName = Parameters.EventHandlersExternalDataProcessorFileName;
	Object.AlgorithmsDebugMode = Parameters.AlgorithmsDebugMode;
	Object.EventHandlersReadFromFileOfExchangeRules = Parameters.EventHandlersReadFromFileOfExchangeRules;
	
	FormTitle = NStr("en = 'Configure handler debugging on data %Event%'");	
	Event = ?(Parameters.EventHandlersReadFromFileOfExchangeRules, NStr("en = 'export'"), NStr("en = 'import'"));
	FormTitle = StrReplace(FormTitle, "%Event%", Event);
	Title = FormTitle;
	
	ButtonTitle = NStr("en = 'Generate %Event% debug engine'");
	Event = ?(Parameters.EventHandlersReadFromFileOfExchangeRules, NStr("en = 'export'"), NStr("en = 'import'"));
	ButtonTitle = StrReplace(ButtonTitle, "%Event%", Event);
	Items.ExportCodeHandlers.Title = ButtonTitle;
	
	SetVisible();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure AlgorythmsDebuggingOnChange(Item)
	
	AlgorythmsDebuggingOnChangeAtServer();
	
EndProcedure

&AtClient
Procedure EventHandlersExternalDataProcessorFileNameStartChoice(Item, ChoiceData, StandardProcessing)
	
	FileDialog = New FileDialog(FileDialogMode.Open);
	
	FileDialog.Filter     = NStr("en = 'External data processor file of event handlers (*.epf)|*.epf'");
	FileDialog.Extension = "epf";
	FileDialog.Title = NStr("en = 'Select file'");
	FileDialog.Preview = False;
	FileDialog.FilterIndex = 0;
	FileDialog.FullFileName = Item.EditText;
	FileDialog.CheckFileExist = True;
	
	If FileDialog.Choose() Then
		
		Object.EventHandlersExternalDataProcessorFileName = FileDialog.FullFileName;
		
		EventHandlersExternalDataProcessorFileNameOnChange(Item)
		
	EndIf;
	
EndProcedure

&AtClient
Procedure EventHandlersExternalDataProcessorFileNameOnChange(Item)
	
	SetVisible();
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure Done(Command)
	
	ClearMessages();
	
	If IsBlankString(Object.EventHandlersExternalDataProcessorFileName) Then
		
		MessageToUser(NStr("en = 'Specify a name of the external data processor file.'"), "EventHandlersExternalDataProcessorFileName");
		Return;
		
	EndIf;
	
	EventHandlersExternalDataProcessorFile = New File(Object.EventHandlersExternalDataProcessorFileName);
	If Not EventHandlersExternalDataProcessorFile.Exist() Then
		
		MessageToUser(NStr("en = 'The specified file of external data processor does not exist.'"), "EventHandlersExternalDataProcessorFileName");
		Return;
		
	EndIf;
	
	CloseParameters = New Structure;
	CloseParameters.Insert("EventHandlersExternalDataProcessorFileName", Object.EventHandlersExternalDataProcessorFileName);
	CloseParameters.Insert("AlgorithmsDebugMode", Object.AlgorithmsDebugMode);
	CloseParameters.Insert("ExchangeRulesFilename", Object.ExchangeRulesFilename);
	CloseParameters.Insert("ExchangeFileName", Object.ExchangeFileName);
	
	Close(CloseParameters);
	
EndProcedure

&AtClient
Procedure OpenFile(Command)
	
	ShowEventHandlersInWindow();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetVisible()
	
	AlgorythmsDebuggingOnChangeAtServer();
	
	// Selection red assistant steps which are executed incorrectly.
	SetBorderSelection("Group_Step_4", IsBlankString(Object.EventHandlersExternalDataProcessorFileName));
	
	Items.OpenFile.Enabled = Not IsBlankString(Object.TemporaryFileNameOfEventHandlers);
	
EndProcedure

&AtServer
Procedure SetBorderSelection(NameFrames, OneMustHighlightFrame = False) 
	
	AssistantStepBorder = Items[NameFrames];
	
	If OneMustHighlightFrame Then
		
		AssistantStepBorder.TitleTextColor = StyleColors.SpecialTextColor;
		
	Else
		
		AssistantStepBorder.TitleTextColor = New Color;
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportCodeHandlers(Command)
	
	// Perhaps export was already executed previously...
	If Not IsBlankString(Object.TemporaryFileNameOfEventHandlers) Then
		
		ButtonList = New ValueList;
		ButtonList.Add(DialogReturnCode.Yes, NStr("en = 'Export again'"));
		ButtonList.Add(DialogReturnCode.No, NStr("en = 'Open module'"));
		ButtonList.Add(DialogReturnCode.Cancel);
		
		NotifyDescription = New NotifyDescription("ExportHandlerCodeEnd", ThisObject);
		ShowQueryBox(NotifyDescription, NStr("en = 'Debug engine with handler code is already exported.'"), ButtonList,,DialogReturnCode.No);
		
	Else
		
		ExportHandlerCodeEnd(DialogReturnCode.Yes, Undefined);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ExportHandlerCodeEnd(Result, AdditionalParameters) Export
	
	ThereAreExportErrors = False;
	
	If Result = DialogReturnCode.Yes Then
		
		ItIsExportedWithErrors = False;
		ExportHandlersEventAtServer(ItIsExportedWithErrors);
		
	ElsIf Result = DialogReturnCode.Cancel Then
		
		Return;
		
	EndIf;
	
	If Not ThereAreExportErrors Then
		
		SetVisible();
		
		ShowEventHandlersInWindow();
		
	EndIf;
	
EndProcedure

&AtClient
Procedure ShowEventHandlersInWindow()
	
	HandlerFile = New File(Object.TemporaryFileNameOfEventHandlers);
	If HandlerFile.Exist() AND HandlerFile.Size() <> 0 Then
		TextDocument = New TextDocument;
		TextDocument.Read(Object.TemporaryFileNameOfEventHandlers);
		TextDocument.Show(NStr("en = 'Handler debug engine'"));
	EndIf;
	
	ErrorFile = New File(Object.TemporaryFileNameOfExchangeProtocol);
	If ErrorFile.Exist() AND ErrorFile.Size() <> 0 Then
		TextDocument = New TextDocument;
		TextDocument.Read(Object.TemporaryFileNameOfEventHandlers);
		TextDocument.Show(NStr("en = 'An error occurred when exporting the handler module'"));
	EndIf;
	
EndProcedure

&AtServer
Procedure ExportHandlersEventAtServer(Cancel)
	
	ObjectForServer = FormAttributeToValue("Object");
	FillPropertyValues(ObjectForServer, Object);
	ObjectForServer.ExportEventHandlers(Cancel);
	ValueToFormAttribute(ObjectForServer, "Object");
	
EndProcedure

&AtServer
Procedure AlgorythmsDebuggingOnChangeAtServer()
	
	ToolTip = Items.HintAlgorithmsDebugging;
	
	ToolTip.CurrentPage = ToolTip.ChildItems["Group_"+Object.AlgorithmsDebugMode];
	
EndProcedure

&AtClientAtServerNoContext
Procedure MessageToUser(Text, DataPath = "")
	
	Message = New UserMessage;
	Message.Text = Text;
	Message.DataPath = DataPath;
	Message.Message();
	
EndProcedure

#EndRegion


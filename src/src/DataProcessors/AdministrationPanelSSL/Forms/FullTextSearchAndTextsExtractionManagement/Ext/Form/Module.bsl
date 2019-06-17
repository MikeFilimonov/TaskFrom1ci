#Region Variables

&AtClient
Var RefreshInterface;

#EndRegion

#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	SetConditionalAppearance();
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	// Attribute values of the form
	RunMode = CommonUseReUse.ApplicationRunningMode();
	RunMode = New FixedStructure(RunMode);
	
	// Attribute values of the form
	ExtractFileTextsAtServer = ConstantsSet.ExtractFileTextsAtServer;
	
	// Visible settings on launch.
	If RunMode.File Then
		Items.GroupAutomaticTextExtraction.Visible = False;
		AutoTitle = False;
		Title = NStr("en = 'Manage full-text search'");
		Items.SectionDescription.Title = NStr("en = 'Enabling and disabling of full-text search, update of full-text search index.'");
	EndIf;
	
	// Items state update.
	SetEnabled();
	
	StandardSubsystemsServer.SetGroupHeadersDisplay(
		ThisObject, "GroupAutomaticTextExtraction");
	
EndProcedure

&AtClient
Procedure OnClose(Exit)
	
	If Exit Then
		Return;
	EndIf;

	RefreshApplicationInterface();
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure UseFullTextSearchOnChange(Item)
	If UseFullTextSearch = 0 Then // Previous value - 2 (3rd mode).
		UseFullTextSearch = 1;
	ElsIf UseFullTextSearch = 2 Then // Previous value - 1 (True).
		UseFullTextSearch = 0;
	EndIf;
	
	Attachable_OnAttributeChange(Item, True);
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure UpdateIndex(Command)
	Status(
		NStr("en = 'Full text index is being updated...
		     |Please, wait.'"));
	
	UpdateIndexServer();
	
	Status(NStr("en = 'Full-text index is updated.'"));
EndProcedure

&AtClient
Procedure ClearIndex(Command)
	Status(
		NStr("en = 'Full-text index is being cleared...
		     |Please, wait.'"));
	
	ClearIndexServer();
	
	Status(NStr("en = 'Cleanup of full-text index is completed.'"));
EndProcedure

&AtClient
Procedure EditScheduledJob(Command)
	OpenableFormName = "DataProcessor.ScheduledAndBackgroundJobs.Form.ScheduledJob";
	
	FormParameters = New Structure;
	FormParameters.Insert("Action", "Change");
	FormParameters.Insert("ID", String(PredefinedJobScheduleID("TextExtraction")));
	
	FormOwner = Undefined;
	UniquenessOfForm = False;
	WindowOfForm = Undefined;
	
	OpenForm(OpenableFormName, FormParameters, FormOwner, UniquenessOfForm, WindowOfForm);
EndProcedure

&AtClient
Procedure RunExtractionTexts(Command)
	If RunMode.Local Or RunMode.Standalone Then
		OpenableFormName = "DataProcessor.AutomaticTextsExtraction.Form";
	Else
		OpenableFormName = "DataProcessor.AutomaticTextExtractionForAllDataAreas.Form";
	EndIf;
	OpenForm(OpenableFormName);
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtClient
Procedure Attachable_OnAttributeChange(Item, RefreshingInterface = True)
	
	Result = OnAttributeChangeServer(Item.Name);
	
	If Result.Property("FailedToSetFullTextSearchMode") Then
		// Displaying of the warning message.
		QuestionText = NStr("en = 'To change the full-text search mode it is required to complete the all users'' sessions except the current one.'");
		
		Buttons = New ValueList;
		Buttons.Add("ActiveUsers", NStr("en = 'Active users'"));
		Buttons.Add(DialogReturnCode.Cancel);
		
		Handler = New NotifyDescription("AtAttributeChangeAfterAnsweringQuestion", ThisObject);
		ShowQueryBox(Handler, QuestionText, Buttons, , "ActiveUsers");
		Return;
	EndIf;
	
	If RefreshingInterface Then		
		RefreshInterface = True;
		AttachIdleHandler("RefreshApplicationInterface", 1, True);
	EndIf;
	
	StandardSubsystemsClient.ShowExecutionResult(ThisObject, Result);
	
EndProcedure

&AtServer
Procedure SetConditionalAppearance()

	ConditionalAppearance.Items.Clear();

	//

	Item = ConditionalAppearance.Items.Add();

	ItemField = Item.Fields.Items.Add();
	ItemField.Field = New DataCompositionField(Items.IndexStatus.Name);

	FilterElement = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	FilterElement.LeftValue = New DataCompositionField("IndexTrue");
	FilterElement.ComparisonType = DataCompositionComparisonType.Equal;
	FilterElement.RightValue = False;

	Item.Appearance.SetParameterValue("Font", New Font(WindowsFonts.DefaultGUIFont, , , True, False, False, False, ));

EndProcedure

&AtClient
Procedure AtAttributeChangeAfterAnsweringQuestion(Response, ExecuteParameters) Export
	If Response = "ActiveUsers" Then
		OpenForm("DataProcessor.ActiveUsers.Form");
	EndIf;
EndProcedure

&AtServer
Procedure UpdateIndexServer()
	FullTextSearch.UpdateIndex(False, False);
	SetEnabled("Command.UpdateIndex");
EndProcedure

&AtServer
Procedure ClearIndexServer()
	FullTextSearch.ClearIndex();
	SetEnabled("Command.ClearIndex");
EndProcedure

&AtServerNoContext
Function PredefinedJobScheduleID(PredefinedName)
	PredefinedMetadata = Metadata.ScheduledJobs.Find(PredefinedName);
	If PredefinedMetadata = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The ""%1"" scheduled job is not found in the metadata.'"),
			PredefinedName);
	EndIf;
	
	ScheduledJob = ScheduledJobs.FindPredefined(PredefinedMetadata);
	If ScheduledJob = Undefined Then
		Raise StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'The ""%1"" scheduled job is not found.'"),
			PredefinedName);
	EndIf;
	
	Return ScheduledJob.UUID;
EndFunction

&AtServer
Procedure UpdateScheduledJobs(Use)
	
	Task = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.FullTextSearchUpdateIndex);
	Task.Use = Use;
	Task.Write();
	
	Task = ScheduledJobs.FindPredefined(Metadata.ScheduledJobs.FullTextSearchIndexMerge);
	Task.Use = Use;
	Task.Write();
	
	If CommonUse.SubsystemExists("StandardSubsystems.FileFunctions") Then
		ModuleFileFunctions = CommonUse.CommonModule("FileFunctions");
		Task = ScheduledJobs.FindPredefined("TextExtraction");
		Task.Use = Use;
		Task.Write();
	EndIf;
	
EndProcedure

&AtClient
Procedure RefreshApplicationInterface()
	
	If RefreshInterface = True Then
		RefreshInterface = False;
		RefreshReusableValues();
		RefreshInterface();
	EndIf;
	
EndProcedure

&AtServer
Function OnAttributeChangeServer(ItemName)
	
	Result = New Structure;
	
	AttributePathToData = Items[ItemName].DataPath;
	
	SaveAttributeValue(AttributePathToData, Result);
	
	SetEnabled(AttributePathToData);
	
	If Result.Property("FailedToSetFullTextSearchMode") Then
		Return Result;
	EndIf;
	
	RefreshReusableValues();
	
	Return Result;
	
EndFunction

&AtServer
Procedure SaveAttributeValue(AttributePathToData, Result)
	// Save attribute values not connected with constants directly (one-to-one ratio).
	If AttributePathToData = "" Then
		Return;
	EndIf;
	
	// Definition of constant name.
	ConstantName = "";
	If Lower(Left(AttributePathToData, 13)) = Lower("ConstantsSet.") Then
		// If the path to attribute data is specified through "ConstantsSet".
		ConstantName = Mid(AttributePathToData, 14);
	Else
		// Definition of name and attribute value record in the corresponding constant from "ConstantsSet".
		// Used for the attributes of the form directly connected with constants (one-to-one ratio).
		If AttributePathToData = "ExtractFileTextsAtServer" Then
			ConstantName = "ExtractFileTextsAtServer";
			ConstantsSet.ExtractFileTextsAtServer = ExtractFileTextsAtServer;
		ElsIf AttributePathToData = "UseFullTextSearch" Then
			Try
				If UseFullTextSearch Then
					FullTextSearch.SetFullTextSearchMode(FullTextSearchMode.Enable);
				Else
					FullTextSearch.SetFullTextSearchMode(FullTextSearchMode.Disable);
				EndIf;
			Except
				Result.Insert("FailedToSetFullTextSearchMode", True);
				Return;
			EndTry;
			ConstantName = "UseFullTextSearch";
			ConstantsSet.UseFullTextSearch = UseFullTextSearch;
			UpdateScheduledJobs(UseFullTextSearch);
		EndIf;
	EndIf;
	
	// Saving the constant value.
	If ConstantName <> "" Then
		ConstantManager = Constants[ConstantName];
		ConstantValue = ConstantsSet[ConstantName];
		
		If ConstantManager.Get() <> ConstantValue Then
			ConstantManager.Set(ConstantValue);
		EndIf;
		
		StandardSubsystemsClientServer.ExecutionResultAddNotificationOfOpenForms(Result, "Record_ConstantsSet", New Structure, ConstantName);
		// StandardSubsystems.ReportsVariants
		ReportsVariants.AddNotificationOnValueChangeConstants(Result, ConstantManager);
		// End StandardSubsystems.ReportsVariants
	EndIf;
	
EndProcedure

&AtServer
Procedure SetEnabled(AttributePathToData = "")
	
	If AttributePathToData = "" Or AttributePathToData = "UseFullTextSearch" Then
		
		If ConstantsSet.UseFullTextSearch <> FullTextSearchServer.OperationsAllowed() Then
			UseFullTextSearch = 2;
		Else
			UseFullTextSearch = ConstantsSet.UseFullTextSearch;
		EndIf;
		Items.GroupFullTextSearchManagement.Enabled = (UseFullTextSearch = 1);
		Items.GroupAutomaticTextExtraction.Enabled = (UseFullTextSearch = 1);
		
	EndIf;
	
	If AttributePathToData = ""
		Or AttributePathToData = "UseFullTextSearch"
		Or AttributePathToData = "Command.UpdateIndex"
		Or AttributePathToData = "Command.ClearIndex" Then
		
		If UseFullTextSearch = 1 Then
			UpdateDateIndex = FullTextSearch.UpdateDate();
			IndexTrue = FullTextSearchServer.SearchIndexTrue();
			FlagEnabled = Not IndexTrue;
			If IndexTrue Then
				IndexStatus = NStr("en = 'No update required'");
			Else
				IndexStatus = NStr("en = 'Update required'");
			EndIf;
		Else
			UpdateDateIndex = '00010101';
			IndexTrue = False;
			FlagEnabled = False;
			IndexStatus = NStr("en = 'Full-text search is disabled'");
		EndIf;
		
		Items.UpdateIndex.Enabled = FlagEnabled;
		
	EndIf;
	
	If AttributePathToData = "" Or AttributePathToData = "ExtractFileTextsAtServer" Then
		
		Items.EditScheduledJob.Enabled = ConstantsSet.ExtractFileTextsAtServer;
		Items.RunExtractionTexts.Enabled = Not ConstantsSet.ExtractFileTextsAtServer;
		
	EndIf;
	
EndProcedure

#EndRegion


#Region GeneralPurposeProceduresAndFunctions

// Procedure fills form attributes from parameters.
//
&AtServer
Procedure FillAttributesByParameters()
	
	If Parameters.Property("TimeLimitFrom") Then
		TimeLimitFrom = Parameters.TimeLimitFrom;
		TimeLimitFromOnOpen = Parameters.TimeLimitFrom;
	EndIf;
	
	If Parameters.Property("TimeLimitTo") Then
		TimeLimitTo = Parameters.TimeLimitTo;
		TimeLimitToOnOpen = Parameters.TimeLimitTo;
	EndIf;
	
	If Parameters.Property("RepetitionFactorOFDay") Then
		RepetitionFactorOFDay = Parameters.RepetitionFactorOFDay;
		RepetitionFactorOFDayOnOpen = Parameters.RepetitionFactorOFDay;
	EndIf;
	
	If Parameters.Property("ShowWorkOrders") Then
		If Parameters.ShowWorkOrders Then
			ShowDocuments = "WorkOrders";
			ShowDocumentsOnOpen = "WorkOrders";
		EndIf
	EndIf;
	
	If Parameters.Property("ShowProductionOrders") Then
		If Parameters.ShowProductionOrders Then
			If IsBlankString(ShowDocuments) Then
				ShowDocuments = "ProductionOrders";
				ShowDocumentsOnOpen = "ProductionOrders";
			Else
				ShowDocuments =  "AllDocuments";
				ShowDocumentsOnOpen = "AllDocuments";
			EndIf;
		EndIf;
	EndIf;
	
	If Parameters.Property("WorkSchedules") Then
		If Parameters.WorkSchedules Then
			Items.ShowedDocuments.ChoiceList.Delete(1);
		Else
			Items.ShowedDocuments.ChoiceList.Delete(0);
		EndIf;
	EndIf;
	
EndProcedure

// Procedure checks if the form was modified.
//
&AtClient
Procedure CheckIfFormWasModified()
	
	WereMadeChanges = False;
	
	ChangesShowDocuments = ?(ShowDocumentsOnOpen <> ShowDocuments, False, True);
	ChangesTimeLimitFrom = ?(TimeLimitFromOnOpen <> TimeLimitFrom, False, True);
	ChangesTimeLimitTo = ?(TimeLimitToOnOpen <> TimeLimitTo, False, True);
	ChangesRepetitionFactorOFDay = ?(RepetitionFactorOFDayOnOpen <> RepetitionFactorOFDay, False, True);
	
	If ChangesShowDocuments
	 OR ChangesTimeLimitFrom
	 OR ChangesTimeLimitTo
	 OR ChangesRepetitionFactorOFDay Then
		WereMadeChanges = True;
	EndIf;
	
EndProcedure

&AtClient
// The procedure allows to receive a list for the time selection divided by hours
//
Function GetListSelectTime(DateForChoice)

	WorkingDayBeginning      = '00010101000000';
	WorkingDayEnd   = '00010101235959';

	TimeList = New ValueList;
	WorkingDayBeginning = BegOfHour(BegOfDay(DateForChoice) +
		Hour(WorkingDayBeginning) * 3600 +
		Minute(WorkingDayBeginning)*60);
	WorkingDayEnd = EndOfHour(BegOfDay(DateForChoice) +
		Hour(WorkingDayEnd) * 3600 +
		Minute(WorkingDayEnd)*60);

	ListTime = WorkingDayBeginning;
	While BegOfHour(ListTime) <= BegOfHour(WorkingDayEnd) Do
		If Not ValueIsFilled(ListTime) Then
			TimePresentation = "00:00";
		Else
			TimePresentation = Format(ListTime,"DF=HH:mm");
		EndIf;

		TimeList.Add(ListTime, TimePresentation);

		ListTime = ListTime + 3600;
	EndDo;

	Return TimeList;

EndFunction

#EndRegion

#Region ProcedureFormEventHandlers

// Procedure - event handler OnCreateAtServer of the form.
// The procedure implements
// - initializing the form parameters.
//
&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillAttributesByParameters();
	
	WereMadeChanges = False;
	
EndProcedure

&AtClient
Procedure OnOpen(Cancel)
	
	DriveClientServer.FillListByList(GetListSelectTime(TimeLimitFrom),Items.TimeLimitFrom.ChoiceList);
	DriveClientServer.FillListByList(GetListSelectTime(TimeLimitTo),Items.TimeLimitTo.ChoiceList);
	
EndProcedure

#EndRegion

#Region ProcedureActionsOfTheFormCommandPanels

// Procedure - event handler of clicking the OK button.
//
&AtClient
Procedure CommandOK(Command)
	
	CheckIfFormWasModified();
	
	StructureOfFormAttributes = New Structure;
	
	StructureOfFormAttributes.Insert("WereMadeChanges", WereMadeChanges);
	
	StructureOfFormAttributes.Insert("ShowWorkOrders", ShowDocuments = "WorkOrders");
	StructureOfFormAttributes.Insert("ShowProductionOrders", ShowDocuments = "ProductionOrders");
	
	If ShowDocuments = "AllDocuments" Then
		StructureOfFormAttributes.Insert("ShowWorkOrders", True);
		StructureOfFormAttributes.Insert("ShowProductionOrders", True);
	EndIf;
	
	StructureOfFormAttributes.Insert("TimeLimitFrom", TimeLimitFrom);
	StructureOfFormAttributes.Insert("TimeLimitTo", TimeLimitTo);
	
	StructureOfFormAttributes.Insert("RepetitionFactorOFDay", RepetitionFactorOFDay);
	
	Close(StructureOfFormAttributes);
	
EndProcedure

#EndRegion

#Region ProcedureEventHandlersOfFormAttributes

// Procedure - OnChange event handler of the TimeLimitationFrom attribute.
//
&AtClient
Procedure TimeLimitFromOnChange(Item)
	
	If TimeLimitTo <= TimeLimitFrom 
		AND TimeLimitTo <> '00010101000000'
		AND TimeLimitFrom <> '00010101000000' Then
		TimeLimitTo = TimeLimitFrom + 1800;
		Return;
	EndIf;
	
EndProcedure

// Procedure - OnChange event handler of the TimeLimitationTo attribute.
//
&AtClient
Procedure TimeLimitToOnChange(Item)
	
	If TimeLimitTo <= TimeLimitFrom 
		AND TimeLimitTo <> '00010101000000'
		AND TimeLimitFrom <> '00010101000000' Then
		CommonUseClientServer.MessageToUser(NStr("en = 'End time cannot be less or equal to start time.'"));
		TimeLimitTo = TimeLimitFrom + 1800;
		Return;
	EndIf;
	
EndProcedure

#EndRegion

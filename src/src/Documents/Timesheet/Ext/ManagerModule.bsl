#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region ServiceProceduresAndFunctions

// Initializes the tables of values that contain the data of the document table sections.
// Saves the tables of values in the properties of the structure "AdditionalProperties".
//
Procedure InitializeDocumentData(DocumentTimesheet, StructureAdditionalProperties) Export

	If DocumentTimesheet.DataInputMethod = Enums.TimeDataInputMethods.TotalForPeriod Then
	
		QueryText = "";
		For Counter = 1 To 6 Do
		
			QueryText = 	QueryText + ?(Counter > 1, "	
			|UNION ALL
			| 
			|", "") + 
			"SELECT
			|	&Company AS Company,
			|	TimesheetHoursWorkedPerPeriod.Ref.RegistrationPeriod 	AS Period,
			|	TRUE									 					AS TotalForPeriod,
			|	TimesheetHoursWorkedPerPeriod.Employee 					AS Employee,
			|	TimesheetHoursWorkedPerPeriod.Ref.StructuralUnit 	AS StructuralUnit,
			|	TimesheetHoursWorkedPerPeriod.Position 					AS Position,
			|	TimesheetHoursWorkedPerPeriod.TimeKind" + Counter + " 	AS TimeKind,
			|	TimesheetHoursWorkedPerPeriod.Days" + Counter + " 		AS Days,
			|	TimesheetHoursWorkedPerPeriod.Hours" + Counter + " 		AS Hours
			|FROM
			|	Document.Timesheet.HoursWorkedPerPeriod AS TimesheetHoursWorkedPerPeriod
			|WHERE
			|	TimesheetHoursWorkedPerPeriod.TimeKind" + Counter + " <> VALUE(Catalog.PayCodes.EmptyRef) And TimesheetHoursWorkedPerPeriod.Ref = &Ref
			|	";
		
		EndDo; 
		
	Else        
		
		QueryText = "";
		For Counter = 1 To 31 Do
		
			QueryText = QueryText + ?(Counter > 1, "	
			|UNION ALL
			| 
			|", "") + 
			"SELECT
			|	&Company 															AS Company,
			|	FALSE									 								AS TotalForPeriod,
			|	TimesheetHoursWorkedByDays.Employee 								AS Employee,
			|	TimesheetHoursWorkedByDays.Ref.StructuralUnit 				AS StructuralUnit,
			|	TimesheetHoursWorkedByDays.Position 								AS Position,
			|	DATEADD(TimesheetHoursWorkedByDays.Ref.RegistrationPeriod, Day, " + (Counter - 1) + ") AS Period, 
			|	1 AS Days, 
			|	TimesheetHoursWorkedByDays.FirstTimeKind" + Counter + " 			AS TimeKind, 
			|	TimesheetHoursWorkedByDays.FirstHours" + Counter + " 				AS Hours
			|FROM
			|	Document.Timesheet.HoursWorkedByDays AS TimesheetHoursWorkedByDays
			|WHERE
			|	TimesheetHoursWorkedByDays.Ref = &Ref
			|	AND TimesheetHoursWorkedByDays.FirstTimeKind" + Counter + " <> VALUE(Catalog.PayCodes.EmptyRef)
			|		
			|UNION ALL
			|
			|SELECT
			|	&Company,
			|	FALSE,
			|	TimesheetHoursWorkedByDays.Employee,
			|	TimesheetHoursWorkedByDays.Ref.StructuralUnit,
			|	TimesheetHoursWorkedByDays.Position,
			|	DATEADD(TimesheetHoursWorkedByDays.Ref.RegistrationPeriod, Day, " + (Counter - 1) + "), 
|	1, 
|	TimesheetHoursWorkedByDays.SecondTimeKind" + Counter + ",
			|	TimesheetHoursWorkedByDays.SecondHours" + Counter + "
			|FROM
			|	Document.Timesheet.HoursWorkedByDays AS
			|TimesheetHoursWorkedByDays
			|	WHERE TimesheetHoursWorkedByDays.Ref =
			|	&Ref AND TimesheetHoursWorkedByDays.SecondTimeKind" + Counter + " <> VALUE(Catalog.PayCodes.EmptyRef)
			|		
			|UNION ALL
			|
			|SELECT
			|	&Company,
			|	FALSE,
			|	TimesheetHoursWorkedByDays.Employee,
			|	TimesheetHoursWorkedByDays.Ref.StructuralUnit,
			|	TimesheetHoursWorkedByDays.Position,
			|	DATEADD(TimesheetHoursWorkedByDays.Ref.RegistrationPeriod, Day, " + (Counter - 1) + "),
|	 1, 
|	TimesheetHoursWorkedByDays.ThirdTimeKind" + Counter + ",
			|	TimesheetHoursWorkedByDays.ThirdHours" + Counter + "
			|FROM
			|	Document.Timesheet.HoursWorkedByDays
			|AS
			|	TimesheetHoursWorkedByDays WHERE TimesheetHoursWorkedByDays.Ref
			|	= &Ref AND TimesheetHoursWorkedByDays.ThirdTimeKind" + Counter + " <> VALUE(Catalog.PayCodes.EmptyRef)
			|";	
		
		EndDo;
		
	EndIf; 
		
	Query = New Query(QueryText);
	
	Query.SetParameter("Ref", DocumentTimesheet);
	Query.SetParameter("Company", StructureAdditionalProperties.ForPosting.Company);
	
	StructureAdditionalProperties.TableForRegisterRecords.Insert("ScheduleTable", Query.Execute().Unload());
	
EndProcedure

// Function checks whether data should be added to the worked time
Function AddToHoursWorked(TimeKind)
	
	If TimeKind = Catalogs.PayCodes.Holidays
		OR TimeKind = Catalogs.PayCodes.Overtime
		OR TimeKind = Catalogs.PayCodes.Work Then
	
		Return True;	
	Else	
		Return False;	
	EndIf; 
	
EndFunction

#EndRegion

#Region PrintInterface

Function PrintForm(ObjectsArray, PrintObjects)
	
	SpreadsheetDocument = New SpreadsheetDocument;
	SpreadsheetDocument.PrintParametersKey = "PrintParameters_Timesheet";
	
	FirstDocument = True;
	
	For Each CurrentDocument In ObjectsArray Do
		
		If Not FirstDocument Then
			SpreadsheetDocument.PutHorizontalPageBreak();
		EndIf;
		FirstDocument = False;
		
		FirstLineNumber = SpreadsheetDocument.TableHeight + 1;
		
		Query = New Query();
		Query.SetParameter("CurrentDocument", CurrentDocument);
		Query.Text = 
		"SELECT
		|	Timesheet.Date AS DocumentDate,
		|	Timesheet.StructuralUnit AS StructuralUnit,
		|	Timesheet.RegistrationPeriod AS RegistrationPeriod,
		|	Timesheet.Number,
		|	Timesheet.Company.Prefix AS Prefix,
		|	Timesheet.Company.DescriptionFull,
		|	Timesheet.Company,
		|	Timesheet.DataInputMethod
		|FROM
		|	Document.Timesheet AS Timesheet
		|WHERE
		|	Timesheet.Ref = &CurrentDocument";
		
		Header = Query.Execute().Select();
		Header.Next();
		
		If Header.DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
			SpreadsheetDocument.PrintParametersKey = "PARAMETERS_PRINT_Timesheet_Template";		
			Template = PrintManagement.PrintedFormsTemplate("Document.Timesheet.PF_MXL_Template");
		Else
			SpreadsheetDocument.PrintParametersKey = "PRINTING_PARAMETERS_Timesheet_TemplateFree";		
			Template = PrintManagement.PrintedFormsTemplate("Document.Timesheet.PF_MXL_TemplateComposite");
		EndIf;
		
		AreaDocumentHeader = Template.GetArea("DocumentHeader");
		AreaHeader          = Template.GetArea("Header");
		AreaDetails         = Template.GetArea("Details");
		FooterArea         = Template.GetArea("Footer");
		
		If Header.DocumentDate < Date('20110101') Then
			DocumentNumber = DriveServer.GetNumberForPrinting(Header.Number, Header.Prefix);
		Else
			DocumentNumber = ObjectPrefixationClientServer.GetNumberForPrinting(Header.Number, True, True);
		EndIf;		
		
		AreaDocumentHeader.Parameters.NameOfOrganization = Header.CompanyDescriptionFull;
		AreaDocumentHeader.Parameters.NameDeparnments = Header.StructuralUnit;
		AreaDocumentHeader.Parameters.DocumentNumber = DocumentNumber;
		AreaDocumentHeader.Parameters.DateOfFilling = Header.DocumentDate;
		AreaDocumentHeader.Parameters.DateBeg = Header.RegistrationPeriod;
		AreaDocumentHeader.Parameters.DateEnd = EndOfMonth(Header.RegistrationPeriod);
				
		SpreadsheetDocument.Put(AreaDocumentHeader);
		SpreadsheetDocument.Put(AreaHeader);
		                                             
		Query = New Query;
		Query.SetParameter("Ref",   CurrentDocument);
		Query.SetParameter("RegistrationPeriod",   Header.RegistrationPeriod);
		
		If Header.DataInputMethod = Enums.TimeDataInputMethods.ByDays Then
				
			Query.Text =
			"SELECT
			|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
			|	ChangeHistoryOfIndividualNamesSliceLast.Name,
			|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic,
			|	TimesheetHoursWorkedByDays.Employee,
			|	TimesheetHoursWorkedByDays.Position,
			|	TimesheetHoursWorkedByDays.FirstTimeKind1,
			|	TimesheetHoursWorkedByDays.FirstTimeKind2,
			|	TimesheetHoursWorkedByDays.FirstTimeKind3,
			|	TimesheetHoursWorkedByDays.FirstTimeKind4,
			|	TimesheetHoursWorkedByDays.FirstTimeKind5,
			|	TimesheetHoursWorkedByDays.FirstTimeKind6,
			|	TimesheetHoursWorkedByDays.FirstTimeKind7,
			|	TimesheetHoursWorkedByDays.FirstTimeKind8,
			|	TimesheetHoursWorkedByDays.FirstTimeKind9,
			|	TimesheetHoursWorkedByDays.FirstTimeKind10,
			|	TimesheetHoursWorkedByDays.FirstTimeKind11,
			|	TimesheetHoursWorkedByDays.FirstTimeKind12,
			|	TimesheetHoursWorkedByDays.FirstTimeKind13,
			|	TimesheetHoursWorkedByDays.FirstTimeKind14,
			|	TimesheetHoursWorkedByDays.FirstTimeKind15,
			|	TimesheetHoursWorkedByDays.FirstTimeKind16,
			|	TimesheetHoursWorkedByDays.FirstTimeKind17,
			|	TimesheetHoursWorkedByDays.FirstTimeKind18,
			|	TimesheetHoursWorkedByDays.FirstTimeKind19,
			|	TimesheetHoursWorkedByDays.FirstTimeKind20,
			|	TimesheetHoursWorkedByDays.FirstTimeKind21,
			|	TimesheetHoursWorkedByDays.FirstTimeKind22,
			|	TimesheetHoursWorkedByDays.FirstTimeKind23,
			|	TimesheetHoursWorkedByDays.FirstTimeKind24,
			|	TimesheetHoursWorkedByDays.FirstTimeKind25,
			|	TimesheetHoursWorkedByDays.FirstTimeKind26,
			|	TimesheetHoursWorkedByDays.FirstTimeKind27,
			|	TimesheetHoursWorkedByDays.FirstTimeKind28,
			|	TimesheetHoursWorkedByDays.FirstTimeKind29,
			|	TimesheetHoursWorkedByDays.FirstTimeKind30,
			|	TimesheetHoursWorkedByDays.FirstTimeKind31,
			|	TimesheetHoursWorkedByDays.SecondTimeKind1,
			|	TimesheetHoursWorkedByDays.SecondTimeKind2,
			|	TimesheetHoursWorkedByDays.SecondTimeKind3,
			|	TimesheetHoursWorkedByDays.SecondTimeKind4,
			|	TimesheetHoursWorkedByDays.SecondTimeKind5,
			|	TimesheetHoursWorkedByDays.SecondTimeKind6,
			|	TimesheetHoursWorkedByDays.SecondTimeKind7,
			|	TimesheetHoursWorkedByDays.SecondTimeKind8,
			|	TimesheetHoursWorkedByDays.SecondTimeKind9,
			|	TimesheetHoursWorkedByDays.SecondTimeKind10,
			|	TimesheetHoursWorkedByDays.SecondTimeKind11,
			|	TimesheetHoursWorkedByDays.SecondTimeKind12,
			|	TimesheetHoursWorkedByDays.SecondTimeKind13,
			|	TimesheetHoursWorkedByDays.SecondTimeKind14,
			|	TimesheetHoursWorkedByDays.SecondTimeKind15,
			|	TimesheetHoursWorkedByDays.SecondTimeKind16,
			|	TimesheetHoursWorkedByDays.SecondTimeKind17,
			|	TimesheetHoursWorkedByDays.SecondTimeKind18,
			|	TimesheetHoursWorkedByDays.SecondTimeKind19,
			|	TimesheetHoursWorkedByDays.SecondTimeKind20,
			|	TimesheetHoursWorkedByDays.SecondTimeKind21,
			|	TimesheetHoursWorkedByDays.SecondTimeKind22,
			|	TimesheetHoursWorkedByDays.SecondTimeKind23,
			|	TimesheetHoursWorkedByDays.SecondTimeKind24,
			|	TimesheetHoursWorkedByDays.SecondTimeKind25,
			|	TimesheetHoursWorkedByDays.SecondTimeKind26,
			|	TimesheetHoursWorkedByDays.SecondTimeKind27,
			|	TimesheetHoursWorkedByDays.SecondTimeKind28,
			|	TimesheetHoursWorkedByDays.SecondTimeKind29,
			|	TimesheetHoursWorkedByDays.SecondTimeKind30,
			|	TimesheetHoursWorkedByDays.SecondTimeKind31,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind1,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind2,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind3,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind4,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind5,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind6,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind7,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind8,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind9,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind10,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind11,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind12,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind13,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind14,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind15,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind16,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind17,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind18,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind19,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind20,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind21,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind22,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind23,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind24,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind25,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind26,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind27,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind28,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind29,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind30,
			|	TimesheetHoursWorkedByDays.ThirdTimeKind31,
			|	TimesheetHoursWorkedByDays.FirstHours1,
			|	TimesheetHoursWorkedByDays.FirstHours2,
			|	TimesheetHoursWorkedByDays.FirstHours3,
			|	TimesheetHoursWorkedByDays.FirstHours4,
			|	TimesheetHoursWorkedByDays.FirstHours5,
			|	TimesheetHoursWorkedByDays.FirstHours6,
			|	TimesheetHoursWorkedByDays.FirstHours7,
			|	TimesheetHoursWorkedByDays.FirstHours8,
			|	TimesheetHoursWorkedByDays.FirstHours9,
			|	TimesheetHoursWorkedByDays.FirstHours10,
			|	TimesheetHoursWorkedByDays.FirstHours11,
			|	TimesheetHoursWorkedByDays.FirstHours12,
			|	TimesheetHoursWorkedByDays.FirstHours13,
			|	TimesheetHoursWorkedByDays.FirstHours14,
			|	TimesheetHoursWorkedByDays.FirstHours15,
			|	TimesheetHoursWorkedByDays.FirstHours16,
			|	TimesheetHoursWorkedByDays.FirstHours17,
			|	TimesheetHoursWorkedByDays.FirstHours18,
			|	TimesheetHoursWorkedByDays.FirstHours19,
			|	TimesheetHoursWorkedByDays.FirstHours20,
			|	TimesheetHoursWorkedByDays.FirstHours21,
			|	TimesheetHoursWorkedByDays.FirstHours22,
			|	TimesheetHoursWorkedByDays.FirstHours23,
			|	TimesheetHoursWorkedByDays.FirstHours24,
			|	TimesheetHoursWorkedByDays.FirstHours25,
			|	TimesheetHoursWorkedByDays.FirstHours26,
			|	TimesheetHoursWorkedByDays.FirstHours27,
			|	TimesheetHoursWorkedByDays.FirstHours28,
			|	TimesheetHoursWorkedByDays.FirstHours29,
			|	TimesheetHoursWorkedByDays.FirstHours30,
			|	TimesheetHoursWorkedByDays.FirstHours31,
			|	TimesheetHoursWorkedByDays.SecondHours1,
			|	TimesheetHoursWorkedByDays.SecondHours2,
			|	TimesheetHoursWorkedByDays.SecondHours3,
			|	TimesheetHoursWorkedByDays.SecondHours4,
			|	TimesheetHoursWorkedByDays.SecondHours5,
			|	TimesheetHoursWorkedByDays.SecondHours6,
			|	TimesheetHoursWorkedByDays.SecondHours7,
			|	TimesheetHoursWorkedByDays.SecondHours8,
			|	TimesheetHoursWorkedByDays.SecondHours9,
			|	TimesheetHoursWorkedByDays.SecondHours10,
			|	TimesheetHoursWorkedByDays.SecondHours11,
			|	TimesheetHoursWorkedByDays.SecondHours12,
			|	TimesheetHoursWorkedByDays.SecondHours13,
			|	TimesheetHoursWorkedByDays.SecondHours14,
			|	TimesheetHoursWorkedByDays.SecondHours15,
			|	TimesheetHoursWorkedByDays.SecondHours16,
			|	TimesheetHoursWorkedByDays.SecondHours17,
			|	TimesheetHoursWorkedByDays.SecondHours18,
			|	TimesheetHoursWorkedByDays.SecondHours19,
			|	TimesheetHoursWorkedByDays.SecondHours20,
			|	TimesheetHoursWorkedByDays.SecondHours21,
			|	TimesheetHoursWorkedByDays.SecondHours22,
			|	TimesheetHoursWorkedByDays.SecondHours23,
			|	TimesheetHoursWorkedByDays.SecondHours24,
			|	TimesheetHoursWorkedByDays.SecondHours25,
			|	TimesheetHoursWorkedByDays.SecondHours26,
			|	TimesheetHoursWorkedByDays.SecondHours27,
			|	TimesheetHoursWorkedByDays.SecondHours28,
			|	TimesheetHoursWorkedByDays.SecondHours29,
			|	TimesheetHoursWorkedByDays.SecondHours30,
			|	TimesheetHoursWorkedByDays.SecondHours31,
			|	TimesheetHoursWorkedByDays.ThirdHours1,
			|	TimesheetHoursWorkedByDays.ThirdHours2,
			|	TimesheetHoursWorkedByDays.ThirdHours3,
			|	TimesheetHoursWorkedByDays.ThirdHours4,
			|	TimesheetHoursWorkedByDays.ThirdHours5,
			|	TimesheetHoursWorkedByDays.ThirdHours6,
			|	TimesheetHoursWorkedByDays.ThirdHours7,
			|	TimesheetHoursWorkedByDays.ThirdHours8,
			|	TimesheetHoursWorkedByDays.ThirdHours9,
			|	TimesheetHoursWorkedByDays.ThirdHours10,
			|	TimesheetHoursWorkedByDays.ThirdHours11,
			|	TimesheetHoursWorkedByDays.ThirdHours12,
			|	TimesheetHoursWorkedByDays.ThirdHours13,
			|	TimesheetHoursWorkedByDays.ThirdHours14,
			|	TimesheetHoursWorkedByDays.ThirdHours15,
			|	TimesheetHoursWorkedByDays.ThirdHours16,
			|	TimesheetHoursWorkedByDays.ThirdHours17,
			|	TimesheetHoursWorkedByDays.ThirdHours18,
			|	TimesheetHoursWorkedByDays.ThirdHours19,
			|	TimesheetHoursWorkedByDays.ThirdHours20,
			|	TimesheetHoursWorkedByDays.ThirdHours21,
			|	TimesheetHoursWorkedByDays.ThirdHours22,
			|	TimesheetHoursWorkedByDays.ThirdHours23,
			|	TimesheetHoursWorkedByDays.ThirdHours24,
			|	TimesheetHoursWorkedByDays.ThirdHours25,
			|	TimesheetHoursWorkedByDays.ThirdHours26,
			|	TimesheetHoursWorkedByDays.ThirdHours27,
			|	TimesheetHoursWorkedByDays.ThirdHours28,
			|	TimesheetHoursWorkedByDays.ThirdHours29,
			|	TimesheetHoursWorkedByDays.ThirdHours30,
			|	TimesheetHoursWorkedByDays.ThirdHours31,
			|	TimesheetHoursWorkedByDays.Employee.Code AS TabNumber
			|FROM
			|	Document.Timesheet.HoursWorkedByDays AS TimesheetHoursWorkedByDays
			|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&RegistrationPeriod, ) AS ChangeHistoryOfIndividualNamesSliceLast
			|		ON TimesheetHoursWorkedByDays.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
			|WHERE
			|	TimesheetHoursWorkedByDays.Ref = &Ref
			|
			|ORDER BY
			|	TimesheetHoursWorkedByDays.LineNumber";
			
			Selection = Query.Execute().Select();
            				
			NPP = 0;
			While Selection.Next() Do
				FirstHalfHour = 0;
				DaysOfFirstHalf = 0;
				HoursSecondHalf = 0;
				DaysSecondHalf = 0;
				NPP = NPP + 1;				
				AreaDetails.Parameters.SerialNumber = NPP;
				AreaDetails.Parameters.Fill(Selection);
				If ValueIsFilled(Selection.Surname) Then
					Initials = DriveServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
				Else
					Initials = "";
				EndIf;
				AreaDetails.Parameters.DescriptionEmployee = ?(ValueIsFilled(Initials), Initials, Selection.Employee);
				
				For Counter = 1 To 15 Do
					
				    RowTypeOfTime = "" + Selection["FirstTimeKind" + Counter] + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondTimeKind" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdTimeKind" + Counter], "");
					StringHours = "" + ?(Selection["FirstHours" + Counter] = 0, "", Selection["FirstHours" + Counter]) + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondHours" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdHours" + Counter], "");
								 
					AreaDetails.Parameters["Char" + Counter] = RowTypeOfTime;			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = StringHours;			 
								 
					Hours = ?(AddToHoursWorked(Selection["FirstTimeKind" + Counter]), Selection["FirstHours" + Counter], 0) 
							+ ?(AddToHoursWorked(Selection["SecondTimeKind" + Counter]), Selection["SecondHours" + Counter], 0) 
							+ ?(AddToHoursWorked(Selection["ThirdTimeKind" + Counter]), Selection["ThirdHours" + Counter], 0);
					FirstHalfHour = FirstHalfHour +  Hours;
					DaysOfFirstHalf = DaysOfFirstHalf + ?(Hours > 0, 1, 0);
					
				EndDo; 
				
				For Counter = 16 To Day(EndOfMonth(CurrentDocument.RegistrationPeriod)) Do
					
				    RowTypeOfTime = "" + Selection["FirstTimeKind" + Counter] + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondTimeKind" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdTimeKind" + Counter], "");
					StringHours = "" + ?(Selection["FirstHours" + Counter] = 0, "", Selection["FirstHours" + Counter]) + ?(ValueIsFilled(Selection["SecondTimeKind" + Counter]), "/" + Selection["SecondHours" + Counter], "") + ?(ValueIsFilled(Selection["ThirdTimeKind" + Counter]), "/" + Selection["ThirdHours" + Counter], "");
								 
					AreaDetails.Parameters["Char" + Counter] = RowTypeOfTime;			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = StringHours;			 
								 
					Hours = ?(AddToHoursWorked(Selection["FirstTimeKind" + Counter]), Selection["FirstHours" + Counter], 0) 
							+ ?(AddToHoursWorked(Selection["SecondTimeKind" + Counter]), Selection["SecondHours" + Counter], 0) 
							+ ?(AddToHoursWorked(Selection["ThirdTimeKind" + Counter]), Selection["ThirdHours" + Counter], 0);
					HoursSecondHalf = HoursSecondHalf + Hours;
					DaysSecondHalf = DaysSecondHalf + ?(Hours > 0, 1, 0);
					
				EndDo; 
				
				For Counter = Day(EndOfMonth(CurrentDocument.RegistrationPeriod)) + 1 To 31 Do
					
				    AreaDetails.Parameters["Char" + Counter] = "X";			 
					AreaDetails.Parameters["AdditionalValue" + Counter] = "X";
					
				EndDo; 
				
				AreaDetails.Parameters.FirstHalfHour = FirstHalfHour;
				AreaDetails.Parameters.DaysOfFirstHalf = DaysOfFirstHalf;
				AreaDetails.Parameters.HoursSecondHalf = HoursSecondHalf;
				AreaDetails.Parameters.DaysSecondHalf = DaysSecondHalf;
				AreaDetails.Parameters.DaysPerMonth = DaysOfFirstHalf + DaysSecondHalf;
				AreaDetails.Parameters.HoursPerMonth = FirstHalfHour + HoursSecondHalf;
				
				SpreadsheetDocument.Put(AreaDetails);
			EndDo;
			
		Else
		
			Query.Text =
			"SELECT
			|	ChangeHistoryOfIndividualNamesSliceLast.Surname,
			|	ChangeHistoryOfIndividualNamesSliceLast.Name,
			|	ChangeHistoryOfIndividualNamesSliceLast.Patronymic,
			|	TimesheetHoursWorkedPerPeriod.Employee,
			|	TimesheetHoursWorkedPerPeriod.Position,
			|	TimesheetHoursWorkedPerPeriod.Employee.Code AS TabNumber,
			|	TimesheetHoursWorkedPerPeriod.TimeKind1,
			|	TimesheetHoursWorkedPerPeriod.Hours1,
			|	TimesheetHoursWorkedPerPeriod.Days1,
			|	TimesheetHoursWorkedPerPeriod.TimeKind2,
			|	TimesheetHoursWorkedPerPeriod.Hours2,
			|	TimesheetHoursWorkedPerPeriod.Days2,
			|	TimesheetHoursWorkedPerPeriod.TimeKind3,
			|	TimesheetHoursWorkedPerPeriod.Hours3,
			|	TimesheetHoursWorkedPerPeriod.Days3,
			|	TimesheetHoursWorkedPerPeriod.TimeKind4,
			|	TimesheetHoursWorkedPerPeriod.Hours4,
			|	TimesheetHoursWorkedPerPeriod.Days4,
			|	TimesheetHoursWorkedPerPeriod.TimeKind5,
			|	TimesheetHoursWorkedPerPeriod.Hours5,
			|	TimesheetHoursWorkedPerPeriod.Days5,
			|	TimesheetHoursWorkedPerPeriod.TimeKind6,
			|	TimesheetHoursWorkedPerPeriod.Hours6,
			|	TimesheetHoursWorkedPerPeriod.Days6
			|FROM
			|	Document.Timesheet.HoursWorkedPerPeriod AS TimesheetHoursWorkedPerPeriod
			|		LEFT JOIN InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(&RegistrationPeriod, ) AS ChangeHistoryOfIndividualNamesSliceLast
			|		ON TimesheetHoursWorkedPerPeriod.Employee.Ind = ChangeHistoryOfIndividualNamesSliceLast.Ind
			|WHERE
			|	TimesheetHoursWorkedPerPeriod.Ref = &Ref
			|
			|ORDER BY
			|	TimesheetHoursWorkedPerPeriod.LineNumber";
			
			Selection = Query.Execute().Select();		
				
			NPP = 0;
			While Selection.Next() Do
				NPP = NPP + 1;
				AreaDetails.Parameters.SerialNumber = NPP;
				AreaDetails.Parameters.Fill(Selection);
				If ValueIsFilled(Selection.Surname) Then
					Initials = DriveServer.GetSurnameNamePatronymic(Selection.Surname, Selection.Name, Selection.Patronymic, True);
				Else
					Initials = "";
				EndIf;
				AreaDetails.Parameters.DescriptionEmployee = ?(ValueIsFilled(Initials), Initials, Selection.Employee);
				
				RowTypeOfTime = "" + Selection.TimeKind1 + ?(ValueIsFilled(Selection.TimeKind2), "/" + Selection.TimeKind2, "") + ?(ValueIsFilled(Selection.TimeKind3), "/" + Selection.TimeKind3, "") + ?(ValueIsFilled(Selection.TimeKind4), "/" + Selection.TimeKind4, "") + ?(ValueIsFilled(Selection.TimeKind5), "/" + Selection.TimeKind5, "") + ?(ValueIsFilled(Selection.TimeKind6), "/" + Selection.TimeKind6, "");
				StringHours = "" + ?(Selection.TimeKind1 = 0, "", Selection.Hours1) + ?(ValueIsFilled(Selection.TimeKind2), "/" + Selection.Hours2, "") + ?(ValueIsFilled(Selection.TimeKind3), "/" + Selection.Hours3, "") + ?(ValueIsFilled(Selection.TimeKind4), "/" + Selection.Hours4, "") + ?(ValueIsFilled(Selection.TimeKind5), "/" + Selection.Hours5, "") + ?(ValueIsFilled(Selection.TimeKind6), "/" + Selection.Hours6, "");
				
				AreaDetails.Parameters.Char1 = RowTypeOfTime;			 
				AreaDetails.Parameters.AdditionalValue1 = StringHours;					 
				
				AreaDetails.Parameters.HoursPerMonth = ?(AddToHoursWorked(Selection.TimeKind1), Selection.Hours1, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind2), Selection.Hours2, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind3), Selection.Hours3, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind4), Selection.Hours4, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind5), Selection.Hours5, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind6), Selection.Hours6, 0);
					
				AreaDetails.Parameters.DaysPerMonth = ?(AddToHoursWorked(Selection.TimeKind1), Selection.Days1, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind2), Selection.Days2, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind3), Selection.Days3, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind4), Selection.Days4, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind5), Selection.Days5, 0) 
							+ ?(AddToHoursWorked(Selection.TimeKind6), Selection.Days6, 0);
					
				SpreadsheetDocument.Put(AreaDetails);
			EndDo;
		
		EndIf; 			
		
		Heads = DriveServer.OrganizationalUnitsResponsiblePersons(CurrentDocument.Company, CurrentDocument.Date);
		FooterArea.Parameters.Fill(Heads);
		SpreadsheetDocument.Put(FooterArea);
		
		PrintManagement.SetDocumentPrintArea(SpreadsheetDocument, FirstLineNumber, PrintObjects, CurrentDocument);
	
	EndDo;
	
	SpreadsheetDocument.FitToPage = True;
	
	Return SpreadsheetDocument;
	
EndFunction

// Generate printed forms of objects
//
// Incoming:
//   TemplateNames    - String    - Names of layouts separated
//   by commas ObjectsArray  - Array    - Array of refs to objects that
//   need to be printed PrintParameters - Structure - Structure of additional printing parameters
//
// Outgoing:
//   PrintFormsCollection - Values table - Generated
//   table documents OutputParameters       - Structure        - Parameters of generated table documents
//
Procedure Print(ObjectsArray, PrintParameters, 
	
	PrintFormsCollection, PrintObjects, OutputParameters) Export
	
	If PrintManagement.NeedToPrintTemplate(PrintFormsCollection, "Timesheet") Then
		
		PrintManagement.OutputSpreadsheetDocumentToCollection(PrintFormsCollection, "Timesheet", "Working hours accounting timesheet", PrintForm(ObjectsArray, PrintObjects));
		
	EndIf;
	
	// parameters of sending printing forms by email
	DriveServer.FillSendingParameters(OutputParameters.SendingParameters, ObjectsArray, PrintFormsCollection);
	
EndProcedure

// Fills in Sales order printing commands list
// 
// Parameters:
//   PrintCommands - ValueTable - see fields' content in the PrintManagement.CreatePrintCommandsCollection function.
//
Procedure AddPrintCommands(PrintCommands) Export
	
	PrintCommand = PrintCommands.Add();
	PrintCommand.ID = "Timesheet";
	PrintCommand.Presentation = NStr("en = 'Time recording sheet'");
	PrintCommand.FormsList = "DocumentForm,ListForm";
	PrintCommand.CheckPostingBeforePrint = False;
	PrintCommand.Order = 1;
	
EndProcedure

#EndRegion

#EndIf
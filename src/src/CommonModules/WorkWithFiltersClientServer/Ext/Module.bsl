
Procedure SetFilterByPeriod(FilterList, StartDate, EndDate, FieldFilterName = "Date") Export
	
	// Filter by period
	GroupFilterByPeriod = CommonUseClientServer.CreateGroupOfFilterItems(
		FilterList.Items,
		"Period",
		DataCompositionFilterItemsGroupType.AndGroup);
	
	CommonUseClientServer.AddCompositionItem(
		GroupFilterByPeriod,
		FieldFilterName,
		DataCompositionComparisonType.GreaterOrEqual,
		StartDate,
		"StartDate",
		ValueIsFilled(StartDate));
	
	CommonUseClientServer.AddCompositionItem(
		GroupFilterByPeriod,
		FieldFilterName,
		DataCompositionComparisonType.LessOrEqual,
		EndDate,
		"EndDate",
		ValueIsFilled(EndDate));
		
EndProcedure
	
Function RefreshPeriodPresentation(Period) Export
	
	If Not ValueIsFilled(Period) Or (Not ValueIsFilled(Period.StartDate) AND Not ValueIsFilled(Period.EndDate)) Then
		PeriodPresentation = NStr("en = 'Period is not set'");
	Else
		EndDate = ?(ValueIsFilled(Period.EndDate), EndOfDay(Period.EndDate), Period.EndDate);
		If EndDate < Period.StartDate Then
			#If Client Then
			DriveClient.ShowMessageAboutError(Undefined, NStr("en = 'Selected date end of the period, which is less than the start date.'"));
			#EndIf
			PeriodPresentation = NStr("en = 'from'") + " " +Format(Period.StartDate,"DLF=D");
		Else
			PeriodPresentation = NStr("en = 'for'") + " " + Lower(PeriodPresentation(Period.StartDate, EndDate));
		EndIf; 
	EndIf;
	
	Return PeriodPresentation;
	
EndFunction


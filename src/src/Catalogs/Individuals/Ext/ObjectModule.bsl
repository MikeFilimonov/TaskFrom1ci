#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		DescriptionFullRecordSet = InformationRegisters.ChangeHistoryOfIndividualNames.CreateRecordSet();
		RecordDate = BegOfDay(CurrentSessionDate());
		
		Query = New Query("SELECT
		                      |	ChangeHistoryOfIndividualNamesSliceLast.Surname,
		                      |	ChangeHistoryOfIndividualNamesSliceLast.Name,
		                      |	ChangeHistoryOfIndividualNamesSliceLast.Patronymic
		                      |FROM
		                      |	InformationRegister.ChangeHistoryOfIndividualNames.SliceLast(, Ind = &Ind) AS ChangeHistoryOfIndividualNamesSliceLast");
							  
		Query.SetParameter("Ind", Ref);
		QueryResult = Query.Execute();
		
		// Set is already written
		If QueryResult.IsEmpty() Then
			Period = ?(ValueIsFilled(BirthDate), Birthdate, RecordDate);
		Else
			QueryResultSelection = QueryResult.Select();
			QueryResultSelection.Next();
			
			If QueryResultSelection.Surname = LastName
				AND QueryResultSelection.Name = FirstName
				AND QueryResultSelection.Patronymic = MiddleName Then
				Return;
			EndIf;
			Period = RecordDate;
		EndIf;

		WriteSet = DescriptionFullRecordSet.Add();
		WriteSet.Period		= Period;
		WriteSet.Name		= FirstName;
		WriteSet.Surname	= LastName;
		WriteSet.Patronymic	= MiddleName;
		
		If DescriptionFullRecordSet.Count() > 0 AND ValueIsFilled(DescriptionFullRecordSet[0].Period) Then
			
			DescriptionFullRecordSet[0].Ind = Ref;
			
			DescriptionFullRecordSet.Filter.Ind.Use			= True;
			DescriptionFullRecordSet.Filter.Ind.Value		= DescriptionFullRecordSet[0].Ind;
			DescriptionFullRecordSet.Filter.Period.Use		= True;
			DescriptionFullRecordSet.Filter.Period.Value	= DescriptionFullRecordSet[0].Period;
			If Not ValueIsFilled(WriteSet.Name + WriteSet.Patronymic + WriteSet.Surname) Then
				WriteSet.Name		= FirstName;
				WriteSet.Surname	= LastName;
				WriteSet.Patronymic	= MiddleName;
			EndIf;
			
			DescriptionFullRecordSet.Write(True);
			
		EndIf;	
		
	EndIf;
	
EndProcedure

#EndRegion

#EndIf
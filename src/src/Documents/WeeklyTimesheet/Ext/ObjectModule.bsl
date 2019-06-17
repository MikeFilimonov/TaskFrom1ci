#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventsHandlers

// Procedure - handler of the FillingProcessor event.
//
Procedure Filling(FillingData, StandardProcessing) Export
	
	If TypeOf(FillingData) = Type("Structure")
	   AND FillingData.Property("Basis")
	   AND TypeOf(FillingData.Basis)= Type("DocumentRef.ObsoleteWorkOrder") Then
		
		Query = New Query(
		"SELECT
		|	WorkOrderHeader.Company AS Company,
		|	WorkOrderHeader.Employee AS Employee,
		|	WorkOrderHeader.StructuralUnit AS StructuralUnit,
		|	WorkOrderWorks.WorkKind AS WorkKind,
		|	WorkOrderWorks.Customer AS Customer,
		|	WorkOrderWorks.Products AS Products,
		|	WorkOrderWorks.Characteristic AS Characteristic,
		|	WorkOrderWorks.Ref.PriceKind AS PriceKind,
		|	ISNULL(WorkOrderWorks.Price, 0) AS Price,
		|	ISNULL(WorkOrderWorks.DurationInHours, 0) AS Duration,
		|	WorkOrderWorks.BeginTime AS BeginTime,
		|	WorkOrderWorks.EndTime AS EndTime,
		|	WorkOrderWorks.Day AS Day,
		|	ISNULL(WeekDay(WorkOrderWorks.Day), 1) AS WeekDay
		|FROM
		|	Document.ObsoleteWorkOrder AS WorkOrderHeader
		|		LEFT JOIN Document.ObsoleteWorkOrder.Works AS WorkOrderWorks
		|		ON WorkOrderHeader.Ref = WorkOrderWorks.Ref
		|WHERE
		|	WorkOrderHeader.Ref = &Ref
		|	AND (ISNULL(WorkOrderWorks.LineNumber, 0) = 0
		|			OR WorkOrderWorks.LineNumber IN (&ArrayNumbersRows))
		|
		|ORDER BY
		|	WorkKind,
		|	Customer,
		|	Products,
		|	Characteristic,
		|	PriceKind,
		|	Price,
		|	WeekDay,
		|	BeginTime,
		|	EndTime
		|TOTALS BY
		|	WorkKind,
		|	Customer,
		|	Products,
		|	Characteristic,
		|	PriceKind,
		|	Price");
	
		Query.SetParameter("Ref", FillingData.Basis);
		Query.SetParameter("ArrayNumbersRows", FillingData.RowArray);
		
		SelectionWorkKind = Query.Execute().Select(QueryResultIteration.ByGroups, "WorkKind");
		
		WeekDays = New Map;
		WeekDays.Insert(1, "Mo");
		WeekDays.Insert(2, "Tu");
		WeekDays.Insert(3, "We");
		WeekDays.Insert(4, "Th");
		WeekDays.Insert(5, "Fr");
		WeekDays.Insert(6, "Sa");
		WeekDays.Insert(7, "Su");
		
		While SelectionWorkKind.Next() Do
			CustomerSelection = SelectionWorkKind.Select(QueryResultIteration.ByGroups, "Customer");
			While CustomerSelection.Next() Do
				SelectionProducts = CustomerSelection.Select(QueryResultIteration.ByGroups, "Products");
				While SelectionProducts.Next() Do
					SelectionCharacteristic = SelectionProducts.Select(QueryResultIteration.ByGroups, "Characteristic");
					While SelectionCharacteristic.Next() Do
						SelectionPriceKind = SelectionCharacteristic.Select(QueryResultIteration.ByGroups, "PriceKind");
						While SelectionPriceKind.Next() Do
						SelectionPrice = SelectionPriceKind.Select(QueryResultIteration.ByGroups, "Price");
							While SelectionPrice.Next() Do
								FirstIndex = Undefined;
								LastIndex = Undefined;
								
								Selection = SelectionPrice.Select();
								While Selection.Next() Do
									
									DateFrom = ?(ValueIsFilled(Selection.Day), BegOfWeek(Selection.Day), BegOfWeek(CurrentDate()));
									DateTo = ?(ValueIsFilled(Selection.Day), EndOfWeek(Selection.Day), EndOfWeek(CurrentDate()));
									Company = Selection.Company;
									Employee = Selection.Employee;
									StructuralUnit = Selection.StructuralUnit;
									
									If FirstIndex = Undefined Then
										
										NewRow = Operations.Add();
										NewRow.WorkKind = Selection.WorkKind;
										NewRow.Customer = Selection.Customer;
										NewRow.Products = Selection.Products;
										NewRow.Characteristic = Selection.Characteristic;
										NewRow.PriceKind = Selection.PriceKind;
										NewRow.Tariff = Selection.Price;
										NewRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = Selection.Duration;
										NewRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] = Selection.BeginTime;
										NewRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] = Selection.EndTime;
										NewRow.Total = Selection.Duration;
										NewRow.Amount = NewRow.Total * NewRow.Tariff;
										
										FirstIndex = Operations.IndexOf(NewRow);
										LastIndex = FirstIndex;
									
									Else
										
										StringFound = False;
										
										For Counter = FirstIndex To LastIndex Do
											
											CurrentRow = Operations.Get(Counter);
											
											If CurrentRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = 0 Then
											
												CurrentRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = Selection.Duration;
												CurrentRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] = Selection.BeginTime;
												CurrentRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] = Selection.EndTime;
												CurrentRow.Total = CurrentRow.Total + Selection.Duration;
												CurrentRow.Amount = CurrentRow.Amount + Selection.Duration * CurrentRow.Tariff;
												
												StringFound = True;
												
												Break;
											
											EndIf;
										
										EndDo;
										
										If Not StringFound Then
										
											NewRow = Operations.Add();
											NewRow.WorkKind = Selection.WorkKind;
											NewRow.Customer = Selection.Customer;
											NewRow.Products = Selection.Products;
											NewRow.Characteristic = Selection.Characteristic;
											NewRow.PriceKind = Selection.PriceKind;
											NewRow.Tariff = Selection.Price;
											NewRow[WeekDays.Get(Selection.WeekDay) + "Duration"] = Selection.Duration;
											NewRow[WeekDays.Get(Selection.WeekDay) + "BeginTime"] = Selection.BeginTime;
											NewRow[WeekDays.Get(Selection.WeekDay) + "EndTime"] = Selection.EndTime;
											NewRow.Total = Selection.Duration;
											NewRow.Amount = NewRow.Total * NewRow.Tariff;
											
											LastIndex = Operations.IndexOf(NewRow);
										
										EndIf;
										
									EndIf;
								
								EndDo;
								
							EndDo;
							
						EndDo;
						
					EndDo;
					
				EndDo;
				
			EndDo;
			
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - event handler FillCheckProcessing object.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)

	If DataExchange.Load Then
		Return;
	EndIf;

	WeekDays = New Map;
	WeekDays.Insert(1, "Mo");
	WeekDays.Insert(2, "Tu");
	WeekDays.Insert(3, "We");
	WeekDays.Insert(4, "Th");
	WeekDays.Insert(5, "Fr");
	WeekDays.Insert(6, "Sa");
	WeekDays.Insert(7, "Su");
	
	WeekDaysPres = New Map;
	WeekDaysPres.Insert(1, NStr("en = 'Monday'"));
	WeekDaysPres.Insert(2, NStr("en = 'Tuesday'"));
	WeekDaysPres.Insert(3, NStr("en = 'Wednesday'"));
	WeekDaysPres.Insert(4, NStr("en = 'Thursday'"));
	WeekDaysPres.Insert(5, NStr("en = 'Friday'"));
	WeekDaysPres.Insert(6, NStr("en = 'Saturday'"));
	WeekDaysPres.Insert(7, NStr("en = 'Sunday'"));
	
	For Each TSRow In Operations Do
		
		For Counter = 1 To 7 Do
		
			// 1. Time is filled, but duration is not filled.
			If (ValueIsFilled(TSRow[WeekDays.Get(Counter) + "BeginTime"]) 
				OR ValueIsFilled(TSRow[WeekDays.Get(Counter) + "EndTime"])) 
				AND Not ValueIsFilled(TSRow[WeekDays.Get(Counter) + "Duration"])  Then
				
				MessageText = StrTemplate(NStr("en = 'The %1 column in row No. %2 is filled in incorrectly.'"), 
											WeekDaysPres.Get(Counter), TSRow.LineNumber);
				DriveServer.ShowMessageAboutError(
					,
					MessageText,
					"Operations",
					TSRow.LineNumber,
					WeekDays.Get(Counter) + "Duration",
					Cancel
				);
				
			EndIf;
			
			// 2. Duration is filled, but time is not filled.
			If ValueIsFilled(TSRow[WeekDays.Get(Counter) + "Duration"]) 
				AND Not ValueIsFilled(TSRow[WeekDays.Get(Counter) + "EndTime"])  Then
				
				MessageText = StrTemplate(NStr("en = 'The %1 column in row No. %2 is filled in incorrectly.'"), 
											WeekDaysPres.Get(Counter), TSRow.LineNumber);
				DriveServer.ShowMessageAboutError(
					,
					MessageText,
					"Operations",
					TSRow.LineNumber,
					WeekDays.Get(Counter) + "EndTime",
					Cancel
				);
				
			EndIf;
		
		EndDo;			
	
	EndDo;
	
EndProcedure

// Procedure - event handler FillingProcessor object.
//
Procedure Posting(Cancel, PostingMode)

	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	Documents.WeeklyTimesheet.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	DriveServer.ReflectObsoleteWorkOrders(AdditionalProperties, RegisterRecords, Cancel);

	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

// Procedure - event handler UndoPosting object.
//
Procedure UndoPosting(Cancel)

	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
EndProcedure

#EndRegion

#EndIf
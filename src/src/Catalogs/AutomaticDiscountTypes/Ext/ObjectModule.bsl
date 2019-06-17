#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region PredeterminedProceduresEventsHandlers

// Procedure - BeforeWrite event handler.
//
Procedure BeforeWrite(Cancel)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not IsFolder Then
		
		If DeletionMark AND Acts Then
			Acts = False;
		EndIf;
		
		IsClarificationByProducts = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProducts, ProductsGroupsPriceGroups.Count() > 0, False);
		IsClarificationByProductsCategories = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProductsCategories, ProductsGroupsPriceGroups.Count() > 0, False);
		IsClarificationByPriceGroups = ?(RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByPriceGroups, ProductsGroupsPriceGroups.Count() > 0, False);
		
		ThereIsSchedule = False;
		For Each CurrentTimetableString In TimeByDaysOfWeek Do
			If CurrentTimetableString.Selected Then
				ThereIsSchedule = True;
				Break;
			EndIf;
		EndDo;
		
		IsRestrictionOnRecipientsCounterparties = DiscountRecipientsCounterparties.Count() > 0;
		IsRestrictionByRecipientsWarehouses = DiscountRecipientsWarehouses.Count() > 0;
		
		If RestrictionByProductsVariant = Enums.DiscountApplyingFilterType.ByProducts Then
			Query = New Query;
			Query.Text = 
				"SELECT
				|	AutomaticDiscountsProductsGroupsPriceGroups.ValueClarification
				|INTO TU_AutomaticDiscountsProductsGroupsPriceGroups
				|FROM
				|	&ProductsGroupsPriceGroups AS AutomaticDiscountsProductsGroupsPriceGroups
				|;
				|
				|////////////////////////////////////////////////////////////////////////////////
				|SELECT TOP 1
				|	TU_AutomaticDiscountsProductsGroupsPriceGroups.ValueClarification
				|FROM
				|	TU_AutomaticDiscountsProductsGroupsPriceGroups AS TU_AutomaticDiscountsProductsGroupsPriceGroups
				|WHERE
				|	TU_AutomaticDiscountsProductsGroupsPriceGroups.ValueClarification.IsFolder";
			
			Query.SetParameter("ByProducts", RestrictionByProductsVariant);
			Query.SetParameter("ProductsGroupsPriceGroups", ProductsGroupsPriceGroups.Unload());
			
			Result = Query.Execute();
			
			ThereAreFoldersToBeClarifiedByProducts = Not Result.IsEmpty();
		Else
			ThereAreFoldersToBeClarifiedByProducts = False;
		EndIf;
		
		// To remove rows without conditions.
		MRowsToDelete = New Array;
		For Each CurrentCondition In ConditionsOfAssignment Do
			If CurrentCondition.AssignmentCondition.IsEmpty() Then
				MRowsToDelete.Add(CurrentCondition);
			EndIf;
		EndDo;
		
		For Each RemovedRow In MRowsToDelete Do
			ConditionsOfAssignment.Delete(RemovedRow);
		EndDo;
		
	EndIf;
	
EndProcedure

// Procedure - FillCheckProcessing event handler.
//
Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If IsFolder Then
		Return;
	EndIf;
	
	NoncheckableAttributeArray = New Array;
	
	If AssignmentMethod <> Enums.DiscountValueType.Amount Then
		NoncheckableAttributeArray.Add("AssignmentCurrency");
	EndIf;
	
	CommonUse.DeleteUnverifiableAttributesFromArray(CheckedAttributes, NoncheckableAttributeArray);
	
EndProcedure

// Procedure - FillingProcessor event handler.
//
Procedure Filling(FillingData, FillingText, StandardProcessing)
	
	If Not IsFolder Then
		AssignmentCurrency = Constants.PresentationCurrency.Get();
	Else
		SharedUsageVariant = Constants.DefaultDiscountsApplyingRule.Get();
	EndIf;
	
EndProcedure

Procedure UpdateInformationInServiceInformationRegister(Cancel)
	
	SetPrivilegedMode(True);
	
	// Update information in service information register used to optimize
	// number of cases which require to calculate automatic discounts.
	RecordManager = InformationRegisters.ServiceAutomaticDiscounts.CreateRecordManager();
	
	Block = New DataLock;
	LockItem = Block.Add();
	LockItem.Region = "InformationRegister.ClosingDates";
	LockItem.Mode = DataLockMode.Exclusive;
	
	BeginTransaction();
	Try
		Block.Lock();
		RecordManager.Read();
			
		Query = New Query;
		Query.Text = 
			"SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.ConditionsOfAssignment AS AutomaticDiscountsAssignmentCondition
			|WHERE
			|	AutomaticDiscountsAssignmentCondition.AssignmentCondition.AssignmentCondition = &ForOneTimeSalesVolume
			|	AND AutomaticDiscountsAssignmentCondition.AssignmentCondition.UseRestrictionCriterionForSalesVolume = &Amount
			|	AND AutomaticDiscountsAssignmentCondition.Ref.Acts
			|	AND Not AutomaticDiscountsAssignmentCondition.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.ConditionsOfAssignment AS AutomaticDiscountsAssignmentCondition
			|WHERE
			|	AutomaticDiscountsAssignmentCondition.AssignmentCondition.AssignmentCondition = &ForKitPurchase
			|	AND AutomaticDiscountsAssignmentCondition.Ref.Acts
			|	AND Not AutomaticDiscountsAssignmentCondition.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.DiscountRecipientsCounterparties AS AutomaticDiscountsDiscountRecipientsCounterparties
			|WHERE
			|	AutomaticDiscountsDiscountRecipientsCounterparties.Ref.Acts
			|	AND Not AutomaticDiscountsDiscountRecipientsCounterparties.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.DiscountRecipientsWarehouses AS AutomaticDiscountsDiscountRecipientsWarehouses
			|WHERE
			|	AutomaticDiscountsDiscountRecipientsWarehouses.Ref.Acts
			|	AND Not AutomaticDiscountsDiscountRecipientsWarehouses.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes.TimeByDaysOfWeek AS AutomaticDiscountsTimeByWeekDays
			|WHERE
			|	AutomaticDiscountsTimeByWeekDays.Ref.Acts
			|	AND Not AutomaticDiscountsTimeByWeekDays.Ref.DeletionMark
			|;
			|
			|////////////////////////////////////////////////////////////////////////////////
			|SELECT ALLOWED TOP 1
			|	TRUE AS Field1
			|FROM
			|	Catalog.AutomaticDiscountTypes AS AutomaticDiscountTypes
			|WHERE
			|	Not AutomaticDiscountTypes.DeletionMark
			|	AND AutomaticDiscountTypes.Acts";
		
		Query.SetParameter("ForOneTimeSalesVolume", Enums.DiscountCondition.ForOneTimeSalesVolume);
		Query.SetParameter("ForKitPurchase", Enums.DiscountCondition.ForKitPurchase);
		Query.SetParameter("Amount", Enums.DiscountSalesAmountLimit.Amount);
		Query.SetParameter("Ref", Ref);
		
		MResults = Query.ExecuteBatch();
		
		// There is a discount depending on the amount.
		Selection = MResults[0].Select();
		RecordManager.AmountDependingDiscountsAvailable = Selection.Next();
		
		// There is a discount for complete purchase.
		Selection = MResults[1].Select();
		RecordManager.PurchaseSetDependingDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by counterparties.
		Selection = MResults[2].Select();
		RecordManager.CounterpartyRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with restriction by counterparties.
		Selection = MResults[3].Select();
		RecordManager.WarehouseRecipientDiscountsAvailable = Selection.Next();
		
		// There are discounts with timetable.
		Selection = MResults[4].Select();
		RecordManager.ScheduleDiscountsAvailable = Selection.Next();
		
		RecordManager.Write();
		
		// There are applicable discounts.
		Selection = MResults[5].Select();
		Constants.ThereAreAutomaticDiscounts.Set(Selection.Next());
		
		CommitTransaction();
	Except
		RollbackTransaction();
		Cancel = True;
		ErrorPresentation = BriefErrorDescription(ErrorInfo());
	EndTry;
	
	SetPrivilegedMode(False);
	
	WriteLogEvent(
			NStr("en = 'Automatic discounts.Service information on automatic discounts'",
			     CommonUseClientServer.MainLanguageCode()),
			?(Cancel, EventLogLevel.Error, EventLogLevel.Information),
			,
			,
			ErrorPresentation,
			EventLogEntryTransactionMode.Independent);
	
	If Cancel Then
		Raise
			NStr("en = 'Failed to record service information on automatic discounts and extra charges.
			     |Details in the event log.'");
	EndIf;
	
EndProcedure

// Procedure - event handler OnWrite.
//
Procedure OnWrite(Cancel)
	
	If DataExchange.Load Then
		If Not (AdditionalProperties.Property("RegisterServiceAutomaticDiscounts")
			AND AdditionalProperties.RegisterServiceAutomaticDiscounts = False) Then
			UpdateInformationInServiceInformationRegister(Cancel);
		EndIf;
		
		Return;
	EndIf;
	
	UpdateInformationInServiceInformationRegister(Cancel);
	
EndProcedure

#EndRegion

#EndIf
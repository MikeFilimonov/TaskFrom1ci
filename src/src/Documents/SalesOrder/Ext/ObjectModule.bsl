#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

#Region EventHandlers

Procedure OnCopy(CopiedObject)
	
	FillOnCopy();
	Prepayment.Clear();

EndProcedure

Procedure Filling(FillingData, StandardProcessing) Export
	
	If CommonUse.ReferenceTypeValue(FillingData) Then
		ObjectFillingDrive.FillDocument(ThisObject, FillingData, "FillingHandler");
	Else
		ObjectFillingDrive.FillDocument(ThisObject, FillingData);
	EndIf;
	
	FillByDefault();
	
EndProcedure

Procedure BeforeWrite(Cancel, WriteMode, PostingMode)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Closed And OrderState = DriveReUse.GetOrderStatus("SalesOrderStatuses", "Completed") Then 
		MessageText = StringFunctionsClientServer.SubstituteParametersInString(
			NStr("en = 'You cannot make changes to a completed %1.'"), Ref);
		CommonUseClientServer.MessageToUser(MessageText,,,,);
		Return;
	EndIf;

	If ShipmentDatePosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Inventory Do
			If TabularSectionRow.ShipmentDate <> ShipmentDate Then
				TabularSectionRow.ShipmentDate = ShipmentDate;
			EndIf;
		EndDo;
	EndIf;
	
	If ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		
		For Each Row In Inventory Do
			If Not ValueIsFilled(Row.ShipmentDate) Then
				Continue;
			EndIf;
			ShipmentDate = Row.ShipmentDate;
			Break;
		EndDo;
		
	EndIf;
	
	If WorkKindPosition = Enums.AttributeStationing.InHeader Then
		For Each TabularSectionRow In Works Do
			TabularSectionRow.WorkKind = WorkKind;
		EndDo;
	EndIf;
	
	If ValueIsFilled(Counterparty)
		AND Not Counterparty.DoOperationsByContracts
		AND Not ValueIsFilled(Contract) Then
		
		Contract = Counterparty.ContractByDefault;
		
	EndIf;
	
	DocumentAmount = Inventory.Total("Total") + Works.Total("Total");
	
	ChangeDate = CurrentDate();
	
	If NOT ValueIsFilled(DeliveryOption) OR DeliveryOption = Enums.DeliveryOptions.SelfPickup Then
		ClearDeliveryAttributes();
	ElsIf DeliveryOption <> Enums.DeliveryOptions.LogisticsCompany Then
		ClearDeliveryAttributes("LogisticsCompany");
	EndIf;
	
	AdditionalProperties.Insert("WriteMode", WriteMode);
	
EndProcedure

Procedure Posting(Cancel, PostingMode)
	
	// Initialization of additional properties for document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Initialization of document data
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesOrderDocumentPostingInitialization");
	
	Documents.SalesOrder.InitializeDocumentData(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Registering in accounting sections
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesOrderDocumentPostingActivitiesCreation");

	DriveServer.ReflectInventoryFlowCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectSalesOrders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventoryDemand(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectBackorders(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInventory(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectPaymentCalendar(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectInvoicesAndOrdersPayment(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectUsingPaymentTermsInDocuments(Ref, Cancel);
	
	//Restore records in offline registers
	DriveServer.ReflectInventoryCostLayer(AdditionalProperties, RegisterRecords, Cancel);
	DriveServer.ReflectLandedCosts(AdditionalProperties, RegisterRecords, Cancel);
	
	// Writing of record sets
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesOrderDocumentPostingActivitiesRecord");
	
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	PerformanceEstimationClientServer.StartTimeMeasurement("SalesOrderDocumentPostingControl");
	
	Documents.SalesOrder.RunControl(ThisObject, AdditionalProperties, Cancel);
	
	DriveServer.CreateRecordsInTasksRegisters(ThisObject, Cancel);
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
	AdditionalProperties.ForPosting.StructureTemporaryTables.TempTablesManager.Close();
	
EndProcedure

Procedure UndoPosting(Cancel)
	
	Closed = False;
	
	// Initialization of additional properties to undo document posting
	DriveServer.InitializeAdditionalPropertiesForPosting(Ref, AdditionalProperties);
	
	// Preparation of record sets
	DriveServer.PrepareRecordSetsForRecording(ThisObject);
	
	// Writing of record sets
	DriveServer.WriteRecordSets(ThisObject);
	
	// Control
	Documents.SalesOrder.RunControl(ThisObject, AdditionalProperties, Cancel, True);
	
	DriveServer.ReflectTasksForUpdatingStatuses(Ref, Cancel);
	
EndProcedure

Procedure FillCheckProcessing(Cancel, CheckedAttributes)
	
	If DataExchange.Load Then
		Return;
	EndIf;
	
	If Not Counterparty.DoOperationsByContracts Then
		DriveServer.DeleteAttributeBeingChecked(CheckedAttributes, "Contract");
	EndIf;
	
	If ShipmentDatePosition = Enums.AttributeStationing.InTabularSection Then
		CheckedAttributes.Delete(CheckedAttributes.Find("ShipmentDate"));
	Else
		CheckedAttributes.Delete(CheckedAttributes.Find("Inventory.ShipmentDate"));
	EndIf;
	
	If Inventory.Total("Reserve") > 0 Then
		
		For Each StringInventory In Inventory Do
		
			If StringInventory.Reserve > 0
			AND Not ValueIsFilled(StructuralUnitReserve) Then
				
				MessageText = NStr("en = 'The reserve warehouse is required.'");
				DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "StructuralUnitReserve", Cancel);
				
			EndIf;
		
		EndDo;
	
	EndIf;
	
	If SetPaymentTerms
		AND CashAssetsType = Enums.CashAssetTypes.Noncash Then
		
		CheckedAttributes.Add("BankAccount")
		
	ElsIf SetPaymentTerms
		AND CashAssetsType = Enums.CashAssetTypes.Cash Then
		
		CheckedAttributes.Add("PettyCash");
				
	EndIf;
	
	If SetPaymentTerms
		AND PaymentCalendar.Count() = 1
		AND Not ValueIsFilled(PaymentCalendar[0].PaymentDate) Then
		
		MessageText = NStr("en = 'The payment date is required.'");
		DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "PaymentDate", Cancel);
		
		PaymentDateAttributes = CheckedAttributes.Find("PaymentCalendar.PaymentDate");
		If PaymentDateAttributes <> Undefined Then
			CheckedAttributes.Delete(PaymentDateAttributes);
		EndIf;
		
	EndIf;
	
	If Constants.UseInventoryReservation.Get() Then
		
		If OperationKind = Enums.OperationTypesSalesOrder.OrderForSale Then
			
			For Each StringInventory In Inventory Do
				
				If StringInventory.Reserve > StringInventory.Quantity Then
					
					DriveServer.ShowMessageAboutError(
						ThisObject,
						StringFunctionsClientServer.SubstituteParametersInString(
							NStr("en = 'The quantity of items to be reserved in line #%1 of the Goods list exceeds the available quantity.'"),
							StringInventory.LineNumber),
						"Inventory",
						StringInventory.LineNumber,
						"Reserve",
						Cancel);
					
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	If Not Constants.UseSalesOrderStatuses.Get() Then
		
		If Not ValueIsFilled(OrderState) Then
			MessageText = NStr("en = 'The order status is required. Specify the available statuses in Accounting settings > Sales.'");
			DriveServer.ShowMessageAboutError(ThisObject, MessageText, , , "OrderState", Cancel);
		EndIf;
		
	EndIf;
	
	// 100% discount.
	ThereAreManualDiscounts = GetFunctionalOption("UseManualDiscounts");
	ThereAreAutomaticDiscounts = GetFunctionalOption("UseAutomaticDiscounts"); // AutomaticDiscounts
	
	If ThereAreManualDiscounts OR ThereAreAutomaticDiscounts Then
		For Each StringInventory In Inventory Do
			
			// AutomaticDiscounts
			CurAmount					= StringInventory.Price * StringInventory.Quantity;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * StringInventory.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, StringInventory.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If StringInventory.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(StringInventory.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Amount is required in line #%1 of the Products list.'"),
						StringInventory.LineNumber),
					"Inventory",
					StringInventory.LineNumber,
					"Amount",
					Cancel);
					
			EndIf;
		EndDo;
	EndIf;
	
	If ThereAreManualDiscounts Then
		For Each WorkRow In Works Do
			
			// AutomaticDiscounts
			CurAmount					= WorkRow.Price * WorkRow.Quantity;
			ManualDiscountCurAmount		= ?(ThereAreManualDiscounts, ROUND(CurAmount * WorkRow.DiscountMarkupPercent / 100, 2), 0);
			AutomaticDiscountCurAmount	= ?(ThereAreAutomaticDiscounts, WorkRow.AutomaticDiscountAmount, 0);
			CurAmountDiscounts			= ManualDiscountCurAmount + AutomaticDiscountCurAmount;
			
			If WorkRow.DiscountMarkupPercent <> 100 AND CurAmountDiscounts < CurAmount
				AND Not ValueIsFilled(WorkRow.Amount) Then
				
				DriveServer.ShowMessageAboutError(
					ThisObject,
					StringFunctionsClientServer.SubstituteParametersInString(
						NStr("en = 'Amount is required in line #%1 of the Works list.'"),
						WorkRow.LineNumber),
					"Works",
					WorkRow.LineNumber,
					"Amount",
					Cancel);
				
			EndIf;
		EndDo;
	EndIf;
	
	// Also check filling of the employees Earnings
	Documents.SalesOrder.ArePerformersWithEmptyEarningSum(Performers);
	
	//Payment calendar
	Amount = Inventory.Total("Amount") + Works.Total("Amount");
	VATAmount = Inventory.Total("VATAmount") + Works.Total("VATAmount");
	PaymentTermsServer.CheckCorrectPaymentCalendar(ThisObject, Cancel, Amount, VATAmount);
	
EndProcedure

#EndRegion

#Region DocumentFillingProcedures

Procedure FillingHandler(FillingData) Export
	
	If Not ValueIsFilled(FillingData) Then
		Return;
	EndIf;
	
	If Not CommonUse.ReferenceTypeValue(FillingData) Then
		Return;
	EndIf;
	
	If Not ValueIsFilled(TabularSectionName(FillingData)) Then
		Return;
	EndIf;
	
	QueryResult = QueryDataForFilling(FillingData).Execute();
	
	If QueryResult.IsEmpty() Then
		Return;
	EndIf;
	
	SelectionHeader = QueryResult.Select();
	SelectionHeader.Next();
	
	FillPropertyValues(ThisObject, SelectionHeader);
	
	If DocumentCurrency <> Constants.FunctionalCurrency.Get() Then
		CurrencyStructure = InformationRegisters.ExchangeRates.GetLast(Date, New Structure("Currency", Contract.SettlementsCurrency));
		ExchangeRate = CurrencyStructure.ExchangeRate;
		Multiplicity = CurrencyStructure.Multiplicity;
	EndIf;
	
	Inventory.Clear();
	TabularSectionSelection = SelectionHeader[TabularSectionName(FillingData)].Select();
	While TabularSectionSelection.Next() Do
		NewRow	= Inventory.Add();
		FillPropertyValues(NewRow, TabularSectionSelection);
		NewRow.ProductsTypeInventory = (TabularSectionSelection.ProductsProductsType = Enums.ProductsTypes.InventoryItem);
	EndDo;
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		SelectionDiscountsMarkups = SelectionHeader.DiscountsMarkups.Select();
		While SelectionDiscountsMarkups.Next() Do
			FillPropertyValues(DiscountsMarkups.Add(), SelectionDiscountsMarkups);
		EndDo;
	EndIf;
	
	DocumentAmount = Inventory.Total("Total");
	
	// Payment calendar
	PaymentCalendar.Clear();
	
	Query = New Query;
	Query.SetParameter("Date", ?(ValueIsFilled(Date), Date, CurrentDate()));
	Query.SetParameter("Quote", FillingData);
	Query.Text = 
	"SELECT
	|	DATEADD(&Date, DAY, DATEDIFF(Calendar.Ref.Date, Calendar.PaymentDate, DAY)) AS PaymentDate,
	|	Calendar.PaymentPercentage AS PaymentPercentage,
	|	Calendar.PaymentAmount AS PaymentAmount,
	|	Calendar.PaymentVATAmount AS PaymentVATAmount
	|FROM
	|	Document.Quote.PaymentCalendar AS Calendar
	|WHERE
	|	Calendar.Ref IN(&Quote)";
	
	Selection = Query.Execute().Select();
	While Selection.Next() Do
		NewLine = PaymentCalendar.Add();
		FillPropertyValues(NewLine, Selection);
	EndDo;
	
	SetPaymentTerms = PaymentCalendar.Count() > 0;
	
EndProcedure

Function QueryDataForFilling(FillingData)
	
	Wizard = New QuerySchema;
	Batch = Wizard.QueryBatch[0];
	Batch.SelectAllowed = True;
	Operator0 = Batch.Operators[0];
	Operator0.Sources.Add(FillingData.Metadata().FullName());
	For Each HeaderFieldDescription In HeaderFieldsDescription(FillingData) Do
		Operator0.SelectedFields.Add(HeaderFieldDescription.Key);
		If ValueIsFilled(HeaderFieldDescription.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = HeaderFieldDescription.Value;
		EndIf;
	EndDo;
	
	For Each CurFieldDescriptionTabularSectionInventory In FieldsDescriptionTabularSectionInventory(FillingData) Do
		Operator0.SelectedFields.Add(
		StringFunctionsClientServer.SubstituteParametersInString(
		"%1.%2",
		TabularSectionName(FillingData),
		CurFieldDescriptionTabularSectionInventory.Key));
		If ValueIsFilled(CurFieldDescriptionTabularSectionInventory.Value) Then
			Batch.Columns[Batch.Columns.Count() - 1].Alias = CurFieldDescriptionTabularSectionInventory.Value;
		EndIf;
	EndDo;
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		Operator0.SelectedFields.Add("DiscountsMarkups.ConnectionKey");
		Operator0.SelectedFields.Add("DiscountsMarkups.DiscountMarkup");
		Operator0.SelectedFields.Add("DiscountsMarkups.Amount");
	EndIf;
	
	Operator0.Filter.Add("Ref = &Parameter");
	If TypeOf(FillingData) = Type("DocumentRef.Quote") Then
		Operator0.Filter.Add("Inventory.Variant = PreferredVariant");
	EndIf;
	
	Result = New Query(Wizard.GetQueryText());
	Result.SetParameter("Parameter", FillingData);
	
	Return Result;
	
EndFunction

Function TabularSectionName(FillingData)
	
	TabularSectionNames = New Map;
	TabularSectionNames[Type("DocumentRef.Quote")] = "Inventory";
	
	Return TabularSectionNames[TypeOf(FillingData)];
	
EndFunction

Function HeaderFieldsDescription(FillingData)
	
	Result = New Map;
	
	FillingDataMetadata = FillingData.Metadata();
	
	Result.Insert("Ref", "BasisDocument");
	Result.Insert("Company");
	
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DiscountPercentByDiscountCard");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "ExchangeRate");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Multiplicity");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "AmountIncludesVAT");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "VATTaxation");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Contract");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "Counterparty");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "DocumentCurrency");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "BankAccount");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "PettyCash");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "CashAssetsType");
	AddAttributeIfItIsInDocument(Result, FillingDataMetadata, "SalesRep");
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		Result.Insert("DiscountsAreCalculated");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure AddAttributeIfItIsInDocument(ResultMap, FillingDataMetadata, AttributeName)
	
	If CommonUse.IsObjectAttribute(AttributeName, FillingDataMetadata) Then
		ResultMap.Insert(AttributeName);
	EndIf;
	
EndProcedure

Function FieldsDescriptionTabularSectionInventory(FillingData)
	
	Result = New Map;
	Result.Insert("Products");
	Result.Insert("Products.ProductsType");
	Result.Insert("Characteristic");
	Result.Insert("Content");
	Result.Insert("MeasurementUnit");
	Result.Insert("Quantity");
	Result.Insert("Price");
	Result.Insert("DiscountMarkupPercent");
	Result.Insert("Amount");
	Result.Insert("VATRate");
	Result.Insert("VATAmount");
	Result.Insert("Total");
	
	If GetFunctionalOption("UseAutomaticDiscounts") Then
		Result.Insert("ConnectionKey");
		Result.Insert("AutomaticDiscountAmount");
		Result.Insert("AutomaticDiscountsPercent");
	EndIf;
	
	Return Result;
	
EndFunction

Procedure FillTabularSectionPerformersByResources(PerformersConnectionKey) Export
	
	EmployeeArray	= New Array();
	ArrayOfTeams 		= New Array();
	For Each TSRow In CompanyResources Do
		
		If ValueIsFilled(TSRow.CompanyResource) Then
			
			ResourceValue = TSRow.CompanyResource.ResourceValue;
			If TypeOf(ResourceValue) = Type("CatalogRef.Employees") Then
				
				EmployeeArray.Add(ResourceValue);
				
			ElsIf TypeOf(ResourceValue) = Type("CatalogRef.Teams") Then
				
				ArrayOfTeams.Add(ResourceValue);
				
			EndIf;
			
		EndIf;
		
	EndDo;
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	EmployeesTable.Employee AS Employee,
	|	EmployeesTable.Description AS Description,
	|	CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType
	|INTO TemporaryTableEmployeesAndEarningDeductionSorts
	|FROM
	|	(SELECT
	|		Employees.Ref AS Employee,
	|		Employees.Description AS Description
	|	FROM
	|		Catalog.Employees AS Employees
	|	WHERE
	|		Employees.Ref IN(&EmployeeArray)
	|	
	|	GROUP BY
	|		Employees.Ref,
	|		Employees.Description
	|	
	|	UNION
	|	
	|	SELECT
	|		WorkgroupsContent.Employee,
	|		WorkgroupsContent.Employee.Description
	|	FROM
	|		Catalog.Teams.Content AS WorkgroupsContent
	|	WHERE
	|		WorkgroupsContent.Ref IN(&ArrayOfTeams)) AS EmployeesTable
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality
	|					AND EarningAndDeductionType IN (VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))) AS CompensationPlanSliceLast
	|		ON EmployeesTable.Employee = CompensationPlanSliceLast.Employee
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Description AS Description,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType AS EarningAndDeductionType,
	|	1 AS LPF,
	|	CompensationPlanSliceLast.Amount * EarningCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * EarningCurrencyRate.Multiplicity) AS AmountEarningDeduction
	|FROM
	|	TemporaryTableEmployeesAndEarningDeductionSorts AS TemporaryTableEmployeesAndEarningDeductionSorts
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS CompensationPlanSliceLast
	|		ON TemporaryTableEmployeesAndEarningDeductionSorts.Employee = CompensationPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType = CompensationPlanSliceLast.EarningAndDeductionType
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS EarningCurrencyRate
	|		ON (CompensationPlanSliceLast.Currency = EarningCurrencyRate.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("ToDate", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	Query.SetParameter("EmployeeArray", EmployeeArray);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow In Works Do
			
			If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Work Then
				
				For Each TSRow In EmployeesTable Do
					
					NewRow = Performers.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow In EmployeesTable Do
			
			NewRow = Performers.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillTabularSectionPerformersByTeams(ArrayOfTeams, PerformersConnectionKey) Export
	
	Query = New Query;
	Query.Text =
	"SELECT
	|	WorkgroupsContent.Employee AS Employee,
	|	WorkgroupsContent.Employee.Description AS Description,
	|	CompensationPlanSliceLast.EarningAndDeductionType AS EarningAndDeductionType
	|INTO TemporaryTableEmployeesAndEarningDeductionSorts
	|FROM
	|	Catalog.Teams.Content AS WorkgroupsContent
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality
	|					AND EarningAndDeductionType IN (VALUE(Catalog.EarningAndDeductionTypes.PieceRatePay), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayPercent), VALUE(Catalog.EarningAndDeductionTypes.PieceRatePayFixedAmount))) AS CompensationPlanSliceLast
	|		ON WorkgroupsContent.Employee = CompensationPlanSliceLast.Employee
	|WHERE
	|	WorkgroupsContent.Ref IN(&ArrayOfTeams)
	|;
	|
	|////////////////////////////////////////////////////////////////////////////////
	|SELECT
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Employee AS Employee,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.Description AS Description,
	|	TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType AS EarningAndDeductionType,
	|	1 AS LPF,
	|	CompensationPlanSliceLast.Amount * EarningCurrencyRate.ExchangeRate * DocumentCurrencyRate.Multiplicity / (DocumentCurrencyRate.ExchangeRate * EarningCurrencyRate.Multiplicity) AS AmountEarningDeduction
	|FROM
	|	TemporaryTableEmployeesAndEarningDeductionSorts AS TemporaryTableEmployeesAndEarningDeductionSorts
	|		LEFT JOIN InformationRegister.CompensationPlan.SliceLast(
	|				&ToDate,
	|				Company = &Company
	|					AND Actuality) AS CompensationPlanSliceLast
	|		ON TemporaryTableEmployeesAndEarningDeductionSorts.Employee = CompensationPlanSliceLast.Employee
	|			AND TemporaryTableEmployeesAndEarningDeductionSorts.EarningAndDeductionType = CompensationPlanSliceLast.EarningAndDeductionType
	|		LEFT JOIN InformationRegister.ExchangeRates.SliceLast(&ToDate, ) AS EarningCurrencyRate
	|		ON (CompensationPlanSliceLast.Currency = EarningCurrencyRate.Currency),
	|	InformationRegister.ExchangeRates.SliceLast(&ToDate, Currency = &DocumentCurrency) AS DocumentCurrencyRate
	|
	|ORDER BY
	|	Description";
	
	Query.SetParameter("ToDate", Date);
	Query.SetParameter("Company", Company);
	Query.SetParameter("DocumentCurrency", DocumentCurrency);
	Query.SetParameter("ArrayOfTeams", ArrayOfTeams);
	
	ResultsArray = Query.ExecuteBatch();
	EmployeesTable = ResultsArray[1].Unload();
	
	If PerformersConnectionKey = Undefined Then
		
		For Each TabularSectionRow In Works Do
			
			If TabularSectionRow.Products.ProductsType = Enums.ProductsTypes.Work Then
				
				For Each TSRow In EmployeesTable Do
					
					NewRow = Performers.Add();
					FillPropertyValues(NewRow, TSRow);
					NewRow.ConnectionKey = TabularSectionRow.ConnectionKey;
					
				EndDo;
				
			EndIf;
			
		EndDo;
		
	Else
		
		For Each TSRow In EmployeesTable Do
			
			NewRow = Performers.Add();
			FillPropertyValues(NewRow, TSRow);
			NewRow.ConnectionKey = PerformersConnectionKey;
			
		EndDo;
		
	EndIf;
	
EndProcedure

Procedure FillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	TableOfPeriods = New ValueTable();
	TableOfPeriods.Columns.Add("ShipmentDate");
	TableOfPeriods.Columns.Add("StringInventory");
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			NewRow = TableOfPeriods.Add();
			NewRow.ShipmentDate = StringInventory.ShipmentDate;
			NewRow.StringInventory = StringInventory;
		EndDo;
		
		TotalBalance = Selection.QuantityBalance;
		TableOfPeriods.Sort("ShipmentDate");
		For Each TableOfPeriodsRow In TableOfPeriods Do
			StringInventory = TableOfPeriodsRow.StringInventory;
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
		TableOfPeriods.Clear();
		
	EndDo;
	
EndProcedure

Procedure GoodsFillColumnReserveByBalances() Export
	
	Inventory.LoadColumn(New Array(Inventory.Count()), "Reserve");
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure GoodsFillColumnReserveByReserves() Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	TableInventory.ProductsTypeInventory";
	
	Query.SetParameter("TableInventory", Inventory.Unload());
	Query.SetParameter("Order", Ref);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Inventory.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				
				TotalBalance = 0;
				
			Else
				
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure MaterialsFillColumnReserveByBalances(MaterialsConnectionKey) Export
	
	If MaterialsConnectionKey = Undefined Then
		Materials.LoadColumn(New Array(Materials.Count()), "Reserve");
	Else
		SearchResult = Materials.FindRows(New Structure("ConnectionKey", MaterialsConnectionKey));
		For Each TabularSectionRow In SearchResult Do
			TabularSectionRow.Reserve = 0;
		EndDo;
	EndIf;
	
	TempTablesManager = New TempTablesManager;
	
		Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						UNDEFINED AS SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Date);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				StringInventory.Reserve = TotalBalance;
				TotalBalance = 0;
			Else
				StringInventory.Reserve = StringInventory.Quantity;
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
			EndIf;
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure MaterialsFillColumnReserveByReserves(MaterialsConnectionKey) Export
	
	TempTablesManager = New TempTablesManager;
	
	Query = New Query;
	Query.TempTablesManager = TempTablesManager;
	Query.Text =
	"SELECT
	|	TableInventory.Products AS Products,
	|	TableInventory.Characteristic AS Characteristic,
	|	TableInventory.Batch AS Batch,
	|	&Order AS SalesOrder
	|INTO TemporaryTableInventory
	|FROM
	|	&TableInventory AS TableInventory
	|WHERE
	|	CASE
	|			WHEN &SelectionByKeyLinks
	|				THEN TableInventory.ConnectionKey = &ConnectionKey
	|			ELSE TRUE
	|		END";
	
	Query.SetParameter("TableInventory", Materials.Unload());
	Query.SetParameter("SelectionByKeyLinks", ?(MaterialsConnectionKey = Undefined, False, True));
	Query.SetParameter("ConnectionKey", MaterialsConnectionKey);
	Query.SetParameter("Order", Ref);
	Query.Execute();
	
	Query.Text =
	"SELECT
	|	InventoryBalances.Company AS Company,
	|	InventoryBalances.StructuralUnit AS StructuralUnit,
	|	InventoryBalances.GLAccount AS GLAccount,
	|	InventoryBalances.SalesOrder AS SalesOrder,
	|	InventoryBalances.Products AS Products,
	|	InventoryBalances.Characteristic AS Characteristic,
	|	InventoryBalances.Batch AS Batch,
	|	SUM(InventoryBalances.QuantityBalance) AS QuantityBalance
	|FROM
	|	(SELECT
	|		InventoryBalances.Company AS Company,
	|		InventoryBalances.StructuralUnit AS StructuralUnit,
	|		InventoryBalances.GLAccount AS GLAccount,
	|		InventoryBalances.SalesOrder AS SalesOrder,
	|		InventoryBalances.Products AS Products,
	|		InventoryBalances.Characteristic AS Characteristic,
	|		InventoryBalances.Batch AS Batch,
	|		InventoryBalances.QuantityBalance AS QuantityBalance
	|	FROM
	|		AccumulationRegister.Inventory.Balance(
	|				,
	|				(Company, StructuralUnit, GLAccount, Products, Characteristic, Batch, SalesOrder) In
	|					(SELECT
	|						&Company,
	|						&StructuralUnit,
	|						TableInventory.Products.InventoryGLAccount,
	|						TableInventory.Products,
	|						TableInventory.Characteristic,
	|						TableInventory.Batch,
	|						TableInventory.SalesOrder
	|					FROM
	|						TemporaryTableInventory AS TableInventory
	|					WHERE
	|						TableInventory.SalesOrder <> UNDEFINED)) AS InventoryBalances
	|	
	|	UNION ALL
	|	
	|	SELECT
	|		DocumentRegisterRecordsInventory.Company,
	|		DocumentRegisterRecordsInventory.StructuralUnit,
	|		DocumentRegisterRecordsInventory.GLAccount,
	|		DocumentRegisterRecordsInventory.SalesOrder,
	|		DocumentRegisterRecordsInventory.Products,
	|		DocumentRegisterRecordsInventory.Characteristic,
	|		DocumentRegisterRecordsInventory.Batch,
	|		CASE
	|			WHEN DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|				THEN ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|			ELSE -ISNULL(DocumentRegisterRecordsInventory.Quantity, 0)
	|		END
	|	FROM
	|		AccumulationRegister.Inventory AS DocumentRegisterRecordsInventory
	|	WHERE
	|		DocumentRegisterRecordsInventory.Recorder = &Ref
	|		AND DocumentRegisterRecordsInventory.Period <= &Period
	|		AND DocumentRegisterRecordsInventory.RecordType = VALUE(AccumulationRecordType.Expense)
	|		AND DocumentRegisterRecordsInventory.SalesOrder <> UNDEFINED) AS InventoryBalances
	|
	|GROUP BY
	|	InventoryBalances.Company,
	|	InventoryBalances.StructuralUnit,
	|	InventoryBalances.GLAccount,
	|	InventoryBalances.SalesOrder,
	|	InventoryBalances.Products,
	|	InventoryBalances.Characteristic,
	|	InventoryBalances.Batch";
	
	Query.SetParameter("Period", Finish);
	Query.SetParameter("Ref", Ref);
	Query.SetParameter("Company", DriveServer.GetCompany(Company));
	Query.SetParameter("StructuralUnit", StructuralUnitReserve);
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	While Selection.Next() Do
		
		StructureForSearch = New Structure;
		If MaterialsConnectionKey <> Undefined Then
			StructureForSearch.Insert("ConnectionKey", MaterialsConnectionKey);
		EndIf;
		StructureForSearch.Insert("Products", Selection.Products);
		StructureForSearch.Insert("Characteristic", Selection.Characteristic);
		StructureForSearch.Insert("Batch", Selection.Batch);
		
		TotalBalance = Selection.QuantityBalance;
		ArrayOfRowsInventory = Materials.FindRows(StructureForSearch);
		For Each StringInventory In ArrayOfRowsInventory Do
			
			TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance / StringInventory.MeasurementUnit.Factor);
			If StringInventory.Quantity >= TotalBalance Then
				TotalBalance = 0;
			Else
				
				TotalBalance = TotalBalance - StringInventory.Quantity;
				TotalBalance = ?(TypeOf(StringInventory.MeasurementUnit) = Type("CatalogRef.UOMClassifier"), TotalBalance, TotalBalance * StringInventory.MeasurementUnit.Factor);
				
			EndIf;
			
		EndDo;
		
	EndDo;
	
EndProcedure

Procedure FillOnCopy()
	
	If Constants.UseSalesOrderStatuses.Get() Then
		User = Users.CurrentUser();
		SettingValue = DriveReUse.GetValueByDefaultUser(User, "StatusOfNewSalesOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.SalesOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.SalesOrdersInProgressStatus.Get();
	EndIf;
	
	Closed = False;
	
EndProcedure

Procedure FillByDefault()

	If Constants.UseSalesOrderStatuses.Get() Then
		SettingValue = DriveReUse.GetValueByDefaultUser(Users.CurrentUser(), "StatusOfNewSalesOrder");
		If ValueIsFilled(SettingValue) Then
			If OrderState <> SettingValue Then
				OrderState = SettingValue;
			EndIf;
		Else
			OrderState = Catalogs.SalesOrderStatuses.Open;
		EndIf;
	Else
		OrderState = Constants.SalesOrdersInProgressStatus.Get();
	EndIf;

EndProcedure

Procedure FillPaymentCalendarFromContract() Export
	
	Query = New Query("
	|SELECT
	|	Table.Term AS Term,
	|	Table.DuePeriod AS DuePeriod,
	|	Table.PaymentPercentage AS PaymentPercentage
	|FROM
	|	Catalog.CounterpartyContracts.StagesOfPayment AS Table
	|WHERE
	|	Table.Ref = &Ref
	|");
	
	Query.SetParameter("Ref", Contract);
	
	Result = Query.Execute();
	DataSelection = Result.Select();
	
	If Result.IsEmpty() Then
		Return;
	EndIf;
	
	PaymentCalendar.Clear();
	
	TotalAmountForCorrectBalance = 0;
	TotalVATForCorrectBalance = 0;
	
	TotalAmount = Inventory.Total("Amount") + Works.Total("Amount");
	TotalVAT = Inventory.Total("VATAmount") + Works.Total("VATAmount");
	
	DocumentDate = ?(ValueIsFilled(Date), Date, CurrentDate());
	
	While DataSelection.Next() Do
		
		NewLine = PaymentCalendar.Add();
		
		If DataSelection.Term = Enums.PaymentTerm.PaymentInAdvance Then
			NewLine.PaymentDate = DocumentDate - DataSelection.DuePeriod * 86400;
		Else
			NewLine.PaymentDate = DocumentDate + DataSelection.DuePeriod * 86400;
		EndIf;
		
		NewLine.PaymentPercentage = DataSelection.PaymentPercentage;
		NewLine.PaymentAmount = Round(TotalAmount * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		NewLine.PaymentVATAmount = Round(TotalVAT * NewLine.PaymentPercentage / 100, 2, RoundMode.Round15as20);
		
		TotalAmountForCorrectBalance = TotalAmountForCorrectBalance + NewLine.PaymentAmount;
		TotalVATForCorrectBalance = TotalVATForCorrectBalance + NewLine.PaymentVATAmount;
		
	EndDo;
	
	// correct balance
	NewLine.PaymentAmount = NewLine.PaymentAmount + (TotalAmount - TotalAmountForCorrectBalance);
	NewLine.PaymentVATAmount = NewLine.PaymentVATAmount + (TotalVAT - TotalVATForCorrectBalance);
	
	SetPaymentTerms = True;
	CashAssetsType = CommonUse.ObjectAttributeValue(Contract, "PaymentMethod");
	
	If CashAssetsType = Enums.CashAssetTypes.Noncash Then
		BankAccountByDefault = CommonUse.ObjectAttributeValue(Company, "BankAccountByDefault");
		If ValueIsFilled(BankAccountByDefault) Then
			BankAccount = BankAccountByDefault;
		EndIf;
	ElsIf CashAssetsType = Enums.CashAssetTypes.Cash Then
		PettyCashByDefault = CommonUse.ObjectAttributeValue(Company, "PettyCashByDefault");
		If ValueIsFilled(PettyCashByDefault) Then
			PettyCash = PettyCashByDefault;
		EndIf;
	EndIf;
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure ClearDeliveryAttributes(FieldsToClear = "")
	
	ClearStructure = New Structure;
	ClearStructure.Insert("ShippingAddress",	Undefined);
	ClearStructure.Insert("ContactPerson",		Undefined);
	ClearStructure.Insert("Incoterms",			Undefined);
	ClearStructure.Insert("DeliveryTimeFrom",	Undefined);
	ClearStructure.Insert("DeliveryTimeTo",		Undefined);
	ClearStructure.Insert("GoodsMarking",		Undefined);
	ClearStructure.Insert("LogisticsCompany",	Undefined);
	
	If IsBlankString(FieldsToClear) Then
		FillPropertyValues(ThisObject, ClearStructure);
	Else
		FillPropertyValues(ThisObject, ClearStructure, FieldsToClear);
	EndIf;
	
EndProcedure

#EndRegion

#EndIf

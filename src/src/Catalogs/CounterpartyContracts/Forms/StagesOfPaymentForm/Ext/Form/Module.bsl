
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	SetConditionalAppearance();
	
	If Parameters.Property("AutoTest") Then
		Return;
	EndIf;
	
	FillPropertyValues(Object, Parameters);
	Object.StagesOfPayment.Clear();
	
	FillStagesOfPaymentFromTempStorage(Parameters.AddressInTempStorage);
	CalculateTotalPaymentTerms(ThisForm);
	
	SetEarlyPaymentDiscountsVisible();
	
EndProcedure

&AtClient
Procedure BeforeClose(Cancel, Exit, MessageText, StandardProcessing)
	
	StandardProcessing = False;
	
	If CloseFormWithoutConfirmation Then
		Return;
	EndIf;
	
	If Modified AND Not Exit Then
		
		Cancel = True;
		ShowQueryBox(
			New NotifyDescription("BeforeCloseEnd", ThisObject),
			NStr("en = 'All changes will be lost. Continue?'"),
			QuestionDialogMode.OKCancel);
			
	EndIf;
	
EndProcedure

&AtClient
Procedure BeforeCloseEnd(Result, Parameters) Export
	
	If Result = DialogReturnCode.OK Then
		
		CloseFormWithoutConfirmation = True;
		Close();
		
	EndIf;
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	CalculateTotalPaymentTerms(ThisForm);
EndProcedure

#EndRegion

#Region FormItemEventHandlersHead

&AtServer
Procedure FillStagesOfPaymentFromTempStorage(AddressInTempStorage)
	
	StructureForTables = GetFromTempStorage(AddressInTempStorage);
	
	Object.StagesOfPayment.Load(StructureForTables.StagesOfPayment);
	Object.EarlyPaymentDiscounts.Load(StructureForTables.EarlyPaymentDiscounts);
	
EndProcedure

#EndRegion

#Region FormItemEventHandlersFormTableStagesOfPayment

&AtClient
Procedure StagesOfPaymentAfterDeleteRow(Item)
	CalculateTotalPaymentTerms(ThisForm);
EndProcedure

&AtClient
Procedure StagesOfPaymentOnEditEnd(Item, NewRow, CancelEdit)
	CalculateTotalPaymentTerms(ThisForm);
EndProcedure

#EndRegion

#Region EventHandlers

&AtClient
Procedure OK(Command)
	
	ClearMessages();
	
	If Not Modified Then
		Close();
	ElsIf StagesOfPaymentIsCorrect() AND CheckEarlyPaymentDiscounts() Then
		
		ObjectStructure = New Structure();
		ObjectStructure.Insert("PaymentMethod", Object.PaymentMethod);
		ObjectStructure.Insert("ProvideEPD", Object.ProvideEPD);
		ObjectStructure.Insert("AddressInTempStorage", PutToTempStorageAtServer());
		
		CloseFormWithoutConfirmation = True;
		Close(ObjectStructure);
		
	EndIf;
	
EndProcedure

&AtClient
Procedure Cancel(Command)
	
	CloseFormWithoutConfirmation = True;
	
	Close();
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure SetConditionalAppearance()
	
	ConditionalAppearance.Items.Clear();
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentDuePeriod.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.IncorrectDuePeriod");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentPercentageOfPayment.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.IncorrectPersentageOfPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = True;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.OverdueDataColor);
	
	//
	
	Item = ConditionalAppearance.Items.Add();
	
	FieldsOfItem = Item.Fields.Items.Add();
	FieldsOfItem.Field = New DataCompositionField(Items.StagesOfPaymentPercentageOfPayment.Name);
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.IncorrectPersentageOfPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.Equal;
	ItemFilter.RightValue = False;
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("Object.StagesOfPayment.LineNumber");
	ItemFilter.ComparisonType = DataCompositionComparisonType.LessOrEqual;
	ItemFilter.RightValue = New DataCompositionField("LineNumberOfTheTotalPayment");
	
	ItemFilter = Item.Filter.Items.Add(Type("DataCompositionFilterItem"));
	ItemFilter.LeftValue = New DataCompositionField("LineNumberOfTheTotalPayment");
	ItemFilter.ComparisonType = DataCompositionComparisonType.NotEqual;
	ItemFilter.RightValue = 0;
	
	Item.Appearance.SetParameterValue("TextColor", StyleColors.ResultSuccessColor);
	
EndProcedure

&AtServer
Function StagesOfPaymentIsCorrect()
	
	Cancel = False;
	
	NumberOfStages = Object.StagesOfPayment.Count();
	For CurrentIndex = 0 To NumberOfStages - 1 Do
		
		CurrentLine = Object.StagesOfPayment[CurrentIndex];
		
		ErrorAddress = " " + NStr("en = 'in line %1 the Payment terms tab'");
		
		ErrorAddress = StrReplace(ErrorAddress, "%1", CurrentLine.LineNumber);
		
		If Not ValueIsFilled(CurrentLine.Term) Then
			
			ErrorText = NStr("en = 'Сolumn ""Term"" is empty'");
			PathToTabularSection = CommonUseClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				CurrentLine.LineNumber,
				"Term");
			
			CommonUseClientServer.MessageToUser(
				ErrorText + ErrorAddress,
				,
				PathToTabularSection,
				,
				Cancel);
				
		EndIf;
			
		If Not ValueIsFilled(CurrentLine.PaymentPercentage) Then
			
			ErrorText = NStr("en = 'Сolumn ""% of payment"" is empty'");
			PathToTabularSection = CommonUseClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				CurrentLine.LineNumber,
				"PaymentPercentage");
				
			CommonUseClientServer.MessageToUser(
				ErrorText + ErrorAddress,
				,
				PathToTabularSection,
				,
				Cancel);
				
		EndIf;
			
	EndDo;
		
	If NumberOfStages > 0 
		AND Object.StagesOfPayment.Total("PaymentPercentage") <> 100 Then
			
		ErrorText = NStr("en = 'Percetange amount in the Payment terms tab should be equal to 100%'");
			
		CommonUseClientServer.MessageToUser(ErrorText, , "PaymentPercentage", , Cancel);
		
	EndIf;
	
	CheckStagesOfPayment(Cancel);
	
	Return Not Cancel;
	
EndFunction

&AtServer
Function PutToTempStorageAtServer()
	
	StructureForTables = New Structure;
	StructureForTables.Insert("StagesOfPayment", Object.StagesOfPayment.Unload());
	StructureForTables.Insert("EarlyPaymentDiscounts", Object.EarlyPaymentDiscounts.Unload());
	
	Return PutToTempStorage(StructureForTables, UUID);
	
EndFunction

&AtClientAtServerNoContext
Procedure CalculateTotalPaymentTerms(Form)
	
	PaymentPercentageTotal = 0;
	PreviousDuePeriod = 0;
	Form.LineNumberOfTheTotalPayment = 0;
	
	For Each CurrentRow In Form.Object.StagesOfPayment Do
		
		PaymentPercentageTotal = PaymentPercentageTotal + CurrentRow.PaymentPercentage;
		CurrentRow.IncorrectPersentageOfPayment = (PaymentPercentageTotal > 0);
		If PaymentPercentageTotal = 100 Then 
			Form.LineNumberOfTheTotalPayment = CurrentRow.LineNumber;
		EndIf;
		
		CurrentRow.IncorrectDuePeriod = (PreviousDuePeriod > CurrentRow.DuePeriod);
		PreviousDuePeriod = CurrentRow.DuePeriod;
		
	EndDo;
	
EndProcedure

&AtServer
Procedure CheckStagesOfPayment(Cancel)
	
	Query = New Query("
	|SELECT
	|	Stages.LineNumber AS LineNumber,
	|	Stages.DuePeriod AS DuePeriodValue,
	|	Stages.Term AS TermValue
	|INTO TempStages
	|FROM
	|	&StagesOfPayment AS Stages
	|;
	|
	|////////////////////////////////////////////
	|SELECT
	|	Table.LineNumber AS LineNumber,
	|	Table.DuePeriodValue AS DuePeriodValue,
	|	Table.TermValue AS TermValue,
	|	CASE WHEN Table.TermValue = VALUE(Enum.PaymentTerm.EmptyRef)
	|		THEN 0
	|		ELSE Table.TermValue.Order
	|	END AS TermOrderValue
	|FROM
	|	TempStages AS Table
	|
	|ORDER BY
	|	LineNumber");
	
	Query.SetParameter("StagesOfPayment", Object.StagesOfPayment.Unload());
	
	DataSelection = Query.Execute().Select();
	
	PreviousTermOrderValue = 0;
	PreviousDuePeriodValue = 0;
	PreviousTermValue = Undefined;
	
	While DataSelection.Next() Do
		
		If PreviousTermOrderValue > DataSelection.TermOrderValue Then
			
			ErrorText = NStr("en = 'The term %1 in line %2 can''t follow the term %3 in line %4'");
			
			TextMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorText,
				DataSelection.TermValue,
				DataSelection.LineNumber,
				PreviousTermValue,
				DataSelection.LineNumber - 1);
				
			PathToTabularSection = "Object." + CommonUseClientServer.PathToTabularSection(
				"Object.StagesOfPayment",
				DataSelection.LineNumber,
				"Term");
			
			CommonUseClientServer.MessageToUser(
				TextMessage,
				,
				PathToTabularSection,
				,
				Cancel);
				
			EndIf;
			
			If DataSelection.TermValue = Enums.PaymentTerm.Net // Current stage is Net
				AND DataSelection.TermOrderValue <> PreviousTermOrderValue Then // And previous stage isn't Net
				PreviousDuePeriodValue = 0;
			EndIf;
			
			PreviousTermOrderValue = DataSelection.TermOrderValue;
			
			If PreviousDuePeriodValue > DataSelection.DuePeriodValue Then
				
				ErrorText = NStr("en = 'The Due date in line %1 must be not least then the Due date in line %2'");
				
				TextMessage = StringFunctionsClientServer.SubstituteParametersInString(ErrorText,
					DataSelection.LineNumber,
					DataSelection.LineNumber - 1);
					
				PathToTabularSection = "Object." + CommonUseClientServer.PathToTabularSection(
					"Object.StagesOfPayment",
					DataSelection.LineNumber,
					"DueDate");
			
				CommonUseClientServer.MessageToUser(
					TextMessage,
					,
					PathToTabularSection,
					,
					Cancel);
					
			EndIf;
			
			PreviousDuePeriodValue = DataSelection.DuePeriodValue;
			PreviousTermValue = DataSelection.TermValue;
			
	EndDo;
	
EndProcedure

&AtServer
Function CheckEarlyPaymentDiscounts()
	
	Return EarlyPaymentDiscountsServer.CheckEarlyPaymentDiscounts(Object.EarlyPaymentDiscounts, Object.ProvideEPD);
	
EndFunction

&AtServer
Procedure SetEarlyPaymentDiscountsVisible()
	
	VisibleFlag = (Object.ContractKind = Enums.ContractType.WithCustomer
		OR Object.ContractKind = Enums.ContractType.WithVendor);
	
	Items.EarlyPaymentDiscountsGroup.Visible = VisibleFlag;
	
EndProcedure

#EndRegion
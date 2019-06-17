
Function TitleStagesOfPayment(Form) Export
	
	Object = Form.Object;
	ArrayOfString = New Array;
	
	If (Object.ContractKind = PredefinedValue("Enum.ContractType.WithCustomer")
		OR Object.ContractKind = PredefinedValue("Enum.ContractType.WithVendor")) Then
		
		PaymentDiscounts = Object.EarlyPaymentDiscounts;
		For each TableRow In PaymentDiscounts Do
			
			If ArrayOfString.Count() > 0 Then
				TextOr = StringFunctionsClientServer.SubstituteParametersInString(" %1 ", NStr("en = 'or'"));
				ArrayOfString.Add(TextOr);
			EndIf;
			
			PaymentDiscountsText = StringFunctionsClientServer.SubstituteParametersInString(
				"%1/%2",
				TableRow.Discount,
				TableRow.Period);
			
			ArrayOfString.Add(PaymentDiscountsText);
			
		EndDo;
		
		If ArrayOfString.Count() > 0 Then
			ArrayOfString.Add(", ");
		EndIf;
		
	EndIf;
	
	PaymentMethod = Object.PaymentMethod;
	StagesOfPayment = Object.StagesOfPayment;
	CountOfStagesOfPayment = StagesOfPayment.Count();
	
	Appearance = OptionAppearanceTitleStagesOfPayment();
	
	ArrayOfString.Add(StagePresentation(PaymentMethod));
	
	StagesOfPaymentText = "";
	If CountOfStagesOfPayment = 0 Then
		
		ArrayOfString.Add(", ");
		ArrayOfString.Add(NStr("en = 'payment terms are not set'"));
		
	ElsIf CountOfStagesOfPayment <= 2 Then
		
		ArrayOfString.Add(" ");
		For Count = 1 To CountOfStagesOfPayment Do
			
			PaymentLine = StagesOfPayment[Count - 1];
			StagesOfPaymentText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 %2% %3 days'"),
				StagePresentation(PaymentLine.Term),
				PaymentLine.PaymentPercentage,
				PaymentLine.DuePeriod);
			ArrayOfString.Add(StagesOfPaymentText);
			ArrayOfString.Add(", ");
			
		EndDo;
		
		ArrayOfString.Delete(ArrayOfString.Count() - 1);
		
	Else
		ArrayOfString.Add(" ");
		
		StagesOfPaymentText = NStr("en = 'in %1 transactions'");
		StagesOfPaymentText = StrReplace(StagesOfPaymentText, "%1", Format(CountOfStagesOfPayment, "NZ=0"));
		
		ArrayOfString.Add(StagesOfPaymentText);
	EndIf;
	
	Return New FormattedString(ArrayOfString);
	
EndFunction

Function OptionAppearanceTitleStagesOfPayment() Export
	
	Options = New Structure();
	
	Options.Insert("ColorAttention", WebColors.FireBrick);
	Options.Insert("ColorSelect",  New Color(22, 39, 121));
	Options.Insert("DateFormat", "DLF=D");
	Options.Insert("PartFormat","ND=3; NFD=; NZ=0");
	
	Return Options;
	
EndFunction

Function StagePresentation(PaymentMethod) Export
	
	Presentation = "";
	
	If Not ValueIsFilled(PaymentMethod) Then
		Presentation = NStr("en = 'Not specified'");
	ElsIf PaymentMethod = PredefinedValue("Enum.CashAssetTypes.Cash") Then
		Presentation = NStr("en = 'Cash payment'");
	ElsIf PaymentMethod = PredefinedValue("Enum.CashAssetTypes.Noncash") Then
		Presentation = NStr("en = 'Electronic payment'");
	Else
		Presentation = String(PaymentMethod);
	EndIf;
	
	Return Presentation;
	
EndFunction

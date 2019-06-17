
Function TitlePaymentTerms(Object) Export
	
	PaymentMethod = Object.CashAssetsType;
	PaymentTerms = Object.PaymentCalendar;
	CountOfPaymentTerms = PaymentTerms.Count();
	MetadataObject = Object.Metadata();
	
	If CommonUse.IsObjectAttribute("ShipmentDate", MetadataObject) Then
		MovementDate = Object.ShipmentDate;
	ElsIf CommonUse.IsObjectAttribute("ReceiptDate", MetadataObject) Then
		MovementDate = Object.ReceiptDate;
	Else
		MovementDate = Object.Date;
	EndIf;
	
	Appearance = StagesOfPaymentClientServer.OptionAppearanceTitleStagesOfPayment();
	
	ArrayOfString = New Array;
	ArrayOfString.Add(StagesOfPaymentClientServer.StagePresentation(PaymentMethod));
	
	PaymentTermsText = "";
	If  CountOfPaymentTerms = 0 Then
		
		ArrayOfString.Add(", ");
		ArrayOfString.Add(New FormattedString(NStr("en = 'payment terms are not set'"),, Appearance.ColorAttention));
		
	ElsIf CountOfPaymentTerms <= 2 Then
		
		ArrayOfString.Add(" ");
		For Count = 1 To CountOfPaymentTerms Do
			
			PaymentLine = PaymentTerms[Count - 1];
			PaymentTermsText = StringFunctionsClientServer.SubstituteParametersInString(
				NStr("en = '%1 %2%'"),
				?(PaymentLine.PaymentDate < MovementDate,
					String(PredefinedValue("Enum.PaymentTerm.PaymentInAdvance")),
					String(PredefinedValue("Enum.PaymentTerm.Net"))),
				PaymentLine.PaymentPercentage);
			ArrayOfString.Add(PaymentTermsText);
			ArrayOfString.Add(", ");
			
		EndDo;
		
		ArrayOfString.Delete(ArrayOfString.Count() - 1);
		
	Else
		ArrayOfString.Add(" ");
		
		PaymentTermsText = NStr("en = 'in %1 transactions'");
		PaymentTermsText = StrReplace(PaymentTermsText, "%1", Format(CountOfPaymentTerms, "NZ=0"));
		
		ArrayOfString.Add(PaymentTermsText);
	EndIf;
	
	Return New FormattedString(ArrayOfString);
	
EndFunction

Procedure CheckCorrectPaymentCalendar(Object, Cancel, Amount, VATAmount) Export
	
	Ref = Object.Ref;
	
	If Object.SetPaymentTerms Then
		
		Errors = Undefined;
		
		If Object.PaymentCalendar.Count() = 0 Then
			
			TextMessage = NStr("en = 'Please fill the payment terms or clear the ""Set payment terms"" check box.'");
			CommonUseClientServer.MessageToUser(TextMessage, Ref, , "SetPaymentTerms", Cancel);
			
		Else
			
			PaymentPercentage = Object.PaymentCalendar.Total("PaymentPercentage");
			
			If PaymentPercentage <> 100 Then
				
				TextMessage = NStr("en = 'Percetange amount in the Payment terms tab should be equal to 100%'");
				CommonUseClientServer.AddUserError(Errors, "", TextMessage, "");
				
			EndIf;
			
			TextMessage = NStr("en = 'Incorrect %1 in the Payment terms tab. The difference is %2'");
			
			PaymentAmount = Object.PaymentCalendar.Total("PaymentAmount");
			PaymentVATAmount = Object.PaymentCalendar.Total("PaymentVATAmount");
			
			If (PaymentAmount <> Amount OR VATAmount <> PaymentVATAmount) AND PaymentPercentage = 100 Then
				
				AmountForCorrectBalance = 0;
				VATForCorrectBalance = 0;
				
				For Each Line In Object.PaymentCalendar Do
					
					Line.PaymentAmount = Round(Amount * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
					Line.PaymentVATAmount = Round(VATAmount * Line.PaymentPercentage / 100, 2, RoundMode.Round15as20);
					
					AmountForCorrectBalance = AmountForCorrectBalance + Line.PaymentAmount;
					VATForCorrectBalance = VATForCorrectBalance + Line.PaymentVATAmount;
					
				EndDo;
				
				Line.PaymentAmount = Line.PaymentAmount + (Amount - AmountForCorrectBalance);
				Line.PaymentVATAmount = Line.PaymentVATAmount + (VATAmount - VATForCorrectBalance);
				
				PaymentAmount = Object.PaymentCalendar.Total("PaymentAmount");
				PaymentVATAmount = Object.PaymentCalendar.Total("PaymentVATAmount");
				
			EndIf;
			
			If PaymentAmount <> Amount Then
				
				QuantityPayment = Amount - PaymentAmount;
				NameOfItem = NStr("en = 'payment amount'");
				TextError = StringFunctionsClientServer.SubstituteParametersInString(TextMessage, NameOfItem, QuantityPayment);
				
				CommonUseClientServer.AddUserError(Errors, "", TextError, "");
				
			EndIf;
			
			If VATAmount <> PaymentVATAmount Then
				
				QuantityVAT = VATAmount - PaymentVATAmount;
				NameOfItem = NStr("en = 'VAT amount'");
				TextError = StringFunctionsClientServer.SubstituteParametersInString(TextMessage, NameOfItem, QuantityVAT);
				
				CommonUseClientServer.AddUserError(Errors, "", TextError, "");
				
			EndIf;
			
		EndIf;
		
		If Object.CashAssetsType = Enums.CashAssetTypes.Cash
			AND Not ValueIsFilled(Object.PettyCash) Then
			
			TextMessage = NStr("en = 'Fill-in the Cash account'");
			CommonUseClientServer.AddUserError(Errors, "", TextMessage, "");
				
		EndIf;
		
		If Object.CashAssetsType = Enums.CashAssetTypes.Noncash
			AND Not ValueIsFilled(Object.BankAccount) Then
			
			TextMessage = NStr("en = 'Fill-in the Bank account'");
			CommonUseClientServer.AddUserError(Errors, "", TextMessage, "");
				
		EndIf;
		
		If Errors <> Undefined Then
			
			CommonUseClientServer.ShowErrorsToUser(Errors, Cancel);
			
		EndIf;
		
	EndIf;
	
EndProcedure

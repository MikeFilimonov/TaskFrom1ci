
#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return if the form for analysis is received.
		Return;
	EndIf;
	
	If Object.Ref.IsEmpty() Then
		
		If Parameters.Property("CurrencyCode") Then
			Object.Code = Parameters.CurrencyCode;
		EndIf;
		
		If Parameters.Property("ShortDescription") Then
			Object.Description = Parameters.ShortDescription;
		EndIf;
		
		If Parameters.Property("DescriptionFull") Then
			Object.DescriptionFull = Parameters.DescriptionFull;
		EndIf;
		
		If Parameters.Property("Importing") AND Parameters.Importing Then
			Object.SetRateMethod = Enums.ExchangeRateSetupMethod.ExportFromInternet;
		Else 
			Object.SetRateMethod = Enums.ExchangeRateSetupMethod.ManualInput;
		EndIf;
		
		If Parameters.Property("InWordParametersInHomeLanguage") Then
			Object.InWordParametersInHomeLanguage = Parameters.InWordParametersInHomeLanguage;
		EndIf;
		
		FillFormByObject();
		
	EndIf;
	
	SetFormItems();
	FillLanguageChoiceList();
	
EndProcedure

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	FillFormByObject();
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	CurrentObject.InWordParametersInHomeLanguage	= InWordParametersInHomeLanguage(ThisObject);
	CurrentObject.InWordParametersInEnglish			= InWordParametersInEnglish(ThisObject);
	
EndProcedure

#EndRegion

#Region HeaderFormItemsEventsHandlers

&AtClient
Procedure MainCurrencyStartChoice(Item, ChoiceData, StandardProcessing)
	
	StandardProcessing = False;
	PrepareChoiceDataOfSubordinateCurrency(ChoiceData, Object.Ref);
	
EndProcedure

&AtClient
Procedure AmountNumberOnChange(Item)
	
	SetAmountInWords();
	
EndProcedure

&AtClient
Procedure InWordsField4InEnglishOnChange(Item)
	SetWritingParametersDeclensions(ThisObject);
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField4InEnglishAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField4InEnglishTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8InEnglishOnChange(Item)
	SetWritingParametersDeclensions(ThisObject);
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField8InEnglishAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField8InEnglishTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure InWordsField1InEnglishOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField2InEnglishOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField3InEnglishOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField5InEnglishOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField6InEnglishOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure InWordsField7InEnglishOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure FractionLengthOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure NumberInWordsLanguageOnChange(Item)
	SetAmountInWords();
EndProcedure

&AtClient
Procedure FractionLengthAutoComplete(Item, Text, ChoiceData, Wait, StandardProcessing)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure FractionLengthTextEditEnd(Item, Text, ChoiceData, StandardProcessing)
	
	ChoiceData = TextEditEndByListChoice(Item, Text, StandardProcessing);
	
EndProcedure

&AtClient
Procedure CurrencyRateOnChange(Item)
	SetFormItems();
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

&AtServer
Procedure FillFormByObject()
	
	ReadWritingParameters();
	
	SetWritingParametersDeclensions(ThisObject);
	SetAmountInWords();
	
EndProcedure

&AtClientAtServerNoContext
Function InWordParametersInHomeLanguage(Form)
	
	Return Form.InWordsField1HomeLanguage + ", "
			+ Form.InWordsField2HomeLanguage + ", "
			+ Form.InWordsField3HomeLanguage + ", "
			+ Lower(Left(Form.InWordsField4HomeLanguage, 1)) + ", "
			+ Form.InWordsField5HomeLanguage + ", "
			+ Form.InWordsField6HomeLanguage + ", "
			+ Form.InWordsField7HomeLanguage + ", "
			+ Lower(Left(Form.InWordsField8HomeLanguage, 1)) + ", "
			+ Form.FractionalPartLength;
	
EndFunction

&AtClientAtServerNoContext
Function InWordParametersInEnglish(Form)
	
	Return Form.InWordsField1HomeLanguage + ", "
			+ Form.InWordsField2HomeLanguage + ", "
			+ Form.InWordsField5HomeLanguage + ", "
			+ Form.InWordsField6HomeLanguage + ", "
			+ Form.FractionalPartLength;
	
EndFunction

&AtServer
Procedure SetAmountInWords()
	
	FormatParameter = "";
	
	If ValueIsFilled(Object.NumberInWordsLanguage) Then
		FormatParameter = "L=" + Object.NumberInWordsLanguage;
	EndIf;
	
	AmountInWords = DriveServer.FormatPaymentDocumentAmountInWords(AmountNumber, Object.InWordParametersInHomeLanguage,, FormatParameter);
	
EndProcedure

&AtServer
Procedure ReadWritingParameters()
	
	// Reads recipe parameters and fills corresponding dialog fields.
	
	ParameterString = StrReplace(Object.InWordParametersInHomeLanguage, ",", Chars.LF);
	
	InWordsField1HomeLanguage = TrimAll(StrGetLine(ParameterString, 1));
	InWordsField2HomeLanguage = TrimAll(StrGetLine(ParameterString, 2));
	InWordsField3HomeLanguage = TrimAll(StrGetLine(ParameterString, 3));
	
	Gender = TrimAll(StrGetLine(ParameterString, 4));
	
	If	  Lower(Gender) = "m" Then
		InWordsField4HomeLanguage = "Male";
	ElsIf Lower(Gender) = "G" Then
		InWordsField4HomeLanguage = "Female";
	ElsIf Lower(Gender) = "From" Then
		InWordsField4HomeLanguage = "Neuter";
	EndIf;
	
	InWordsField5HomeLanguage = TrimAll(StrGetLine(ParameterString, 5));
	InWordsField6HomeLanguage = TrimAll(StrGetLine(ParameterString, 6));
	InWordsField7HomeLanguage = TrimAll(StrGetLine(ParameterString, 7));
	
	Gender = TrimAll(StrGetLine(ParameterString, 8));
	
	If	  Lower(Gender = "m") Then
		InWordsField8HomeLanguage = "Male";
	ElsIf Lower(Gender = "G") Then
		InWordsField8HomeLanguage = "Female";
	ElsIf Lower(Gender = "From") Then
		InWordsField8HomeLanguage = "Neuter";
	EndIf;
	
	FractionalPartLength     = TrimAll(StrGetLine(ParameterString, 9));
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetWritingParametersDeclensions(Form)
	
	// Header declension recipe parameters.
	
	Items = Form.Items;
	
	If Form.InWordsField4HomeLanguage = "Female" Then
		Items.InWordsField1HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField2HomeLanguage.Title = NStr("en = 'Two'");
	ElsIf Form.InWordsField4HomeLanguage = "Male" Then
		Items.InWordsField1HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField2HomeLanguage.Title = NStr("en = 'Two'");
	Else
		Items.InWordsField1HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField2HomeLanguage.Title = NStr("en = 'Two'");
	EndIf;
	
	If Form.InWordsField8HomeLanguage = "Female" Then
		Items.InWordsField5HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField6HomeLanguage.Title = NStr("en = 'Two'");
	ElsIf Form.InWordsField8HomeLanguage = "Male" Then
		Items.InWordsField5HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField6HomeLanguage.Title = NStr("en = 'Two'");
	Else
		Items.InWordsField5HomeLanguage.Title = NStr("en = 'One'");
		Items.InWordsField6HomeLanguage.Title = NStr("en = 'Two'");
	EndIf;
	
EndProcedure

&AtServerNoContext
Procedure PrepareChoiceDataOfSubordinateCurrency(ChoiceData, Ref)
	
	// Prepares choice list for subordinated currency
	// so that the subordinated currency didn't get to the list.
	
	ChoiceData = New ValueList;
	
	Query = New Query;
	
	Query.Text = "SELECT Ref, DescriptionFull
	               |FROM
	               |	Catalog.Currencies
	               |WHERE
	               |	Ref <> &Ref
	               |AND
	               |	MainCurrency  = Value(Catalog.Currencies.EmptyRef)
	               |ORDER BY DescriptionFull";
	
	Query.Parameters.Insert("Ref", Ref);
	
	Selection = Query.Execute().Select();
	
	While Selection.Next() Do
		ChoiceData.Add(Selection.Ref, Selection.DescriptionFull);
	EndDo;
	
EndProcedure

&AtClient
Function AutoCompleteByChoiceList(Item, Text, StandardProcessing)
	
	// Input management secondary function.
	
	For Each ChoiceItem In Item.ChoiceList Do
		If Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			StandardProcessing = False;
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Function TextEditEndByListChoice(Item, Text, StandardProcessing)
	
	// Input management secondary function.
	
	StandardProcessing = False;
	
	For Each ChoiceItem In Item.ChoiceList Do
		If Upper(Text) = Upper(ChoiceItem.Presentation) Then
			StandardProcessing = True;
		ElsIf Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			StandardProcessing = False;
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtServer
Procedure SetFormItems()
	
	Items.GroupMarkupOnRateOtherCurrency.Enabled	= Object.SetRateMethod = PredefinedValue("Enum.ExchangeRateSetupMethod.MarkupOnExchangeRateOfOtherCurrencies");
	Items.GroupRateCalculationFormula.Enabled		= Object.SetRateMethod = PredefinedValue("Enum.ExchangeRateSetupMethod.CalculationByFormula");
	
EndProcedure

&AtServer
Procedure FillLanguageChoiceList()
	
	ChoiceList = Items.NumberInWordsLanguage.ChoiceList;
	
	ChoiceList.Add("sq_AL", "Albanian (Albania)");
	ChoiceList.Add("ar_DZ", "Arabic (Algeria)");
	ChoiceList.Add("ar_BH", "Arabic (Bahrain)");
	ChoiceList.Add("ar_EG", "Arabic (Egypt)");
	ChoiceList.Add("ar_IQ", "Arabic (Iraq)");
	ChoiceList.Add("ar_JO", "Arabic (Jordan)");
	ChoiceList.Add("ar_KW", "Arabic (Kuwait)");
	ChoiceList.Add("ar_LB", "Arabic (Lebanon)");
	ChoiceList.Add("ar_LY", "Arabic (Libya)");
	ChoiceList.Add("ar_MA", "Arabic (Morocco)");
	ChoiceList.Add("ar_OM", "Arabic (Oman)");
	ChoiceList.Add("ar_QA", "Arabic (Qatar)");
	ChoiceList.Add("ar_SA", "Arabic (Saudi Arabia)");
	ChoiceList.Add("ar_SD", "Arabic (Sudan)");
	ChoiceList.Add("ar_SY", "Arabic (Syria)");
	ChoiceList.Add("ar_TN", "Arabic (Tunisia)");
	ChoiceList.Add("ar_AE", "Arabic (United Arab Emirates)");
	ChoiceList.Add("ar_YE", "Arabic (Yemen)");
	ChoiceList.Add("be_BY", "Belarusian (Belarus)");
	ChoiceList.Add("bg_BG", "Bulgarian (Bulgaria)");
	ChoiceList.Add("ca_ES", "Catalan (Spain)");
	ChoiceList.Add("zh_CN", "Chinese (China)");
	ChoiceList.Add("zh_HK", "Chinese (Hong Kong)");
	ChoiceList.Add("zh_SG", "Chinese (Singapore)");
	ChoiceList.Add("zh_TW", "Chinese (Taiwan)");
	ChoiceList.Add("hr_HR", "Croatian (Croatia)");
	ChoiceList.Add("cs_CZ", "Czech (Czech Republic)");
	ChoiceList.Add("da_DK", "Danish (Denmark)");
	ChoiceList.Add("nl_BE", "Dutch (Belgium)");
	ChoiceList.Add("nl_NL", "Dutch (Netherlands)");
	ChoiceList.Add("en_AU", "English (Australia)");
	ChoiceList.Add("en_CA", "English (Canada)");
	ChoiceList.Add("en_IN", "English (India)");
	ChoiceList.Add("en_IE", "English (Ireland)");
	ChoiceList.Add("en_MT", "English (Malta)");
	ChoiceList.Add("en_NZ", "English (New Zealand)");
	ChoiceList.Add("en_PH", "English (Philippines)");
	ChoiceList.Add("en_SG", "English (Singapore)");
	ChoiceList.Add("en_ZA", "English (South Africa)");
	ChoiceList.Add("en_GB", "English (United Kingdom)");
	ChoiceList.Add("en_US", "English (United States)");
	ChoiceList.Add("et_EE", "Estonian (Estonia)");
	ChoiceList.Add("fi_FI", "Finnish (Finland)");
	ChoiceList.Add("fr_BE", "French (Belgium)");
	ChoiceList.Add("fr_CA", "French (Canada)");
	ChoiceList.Add("fr_FR", "French (France)");
	ChoiceList.Add("fr_LU", "French (Luxembourg)");
	ChoiceList.Add("fr_CH", "French (Switzerland)");
	ChoiceList.Add("de_AT", "German (Austria)");
	ChoiceList.Add("de_DE", "German (Germany)");
	ChoiceList.Add("de_LU", "German (Luxembourg)");
	ChoiceList.Add("de_CH", "German (Switzerland)");
	ChoiceList.Add("el_CY", "Greek (Cyprus)");
	ChoiceList.Add("el_GR", "Greek (Greece)");
	ChoiceList.Add("iw_IL", "Hebrew (Israel)");
	ChoiceList.Add("hi_IN", "Hindi (India)");
	ChoiceList.Add("hu_HU", "Hungarian (Hungary)");
	ChoiceList.Add("is_IS", "Icelandic (Iceland)");
	ChoiceList.Add("in_ID", "Indonesian (Indonesia)");
	ChoiceList.Add("ga_IE", "Irish (Ireland)");
	ChoiceList.Add("it_IT", "Italian (Italy)");
	ChoiceList.Add("it_CH", "Italian (Switzerland)");
	ChoiceList.Add("ja_JP", "Japanese (Japan)");
	ChoiceList.Add("ko_KR", "Korean (South Korea)");
	ChoiceList.Add("lv_LV", "Latvian (Latvia)");
	ChoiceList.Add("lt_LT", "Lithuanian (Lithuania)");
	ChoiceList.Add("mk_MK", "Macedonian (Macedonia)");
	ChoiceList.Add("ms_MY", "Malay (Malaysia)");
	ChoiceList.Add("mt_MT", "Maltese (Malta)");
	ChoiceList.Add("no_NO", "Norwegian (Norway)");
	ChoiceList.Add("pl_PL", "Polish (Poland)");
	ChoiceList.Add("pt_BR", "Portuguese (Brazil)");
	ChoiceList.Add("pt_PT", "Portuguese (Portugal)");
	ChoiceList.Add("ro_RO", "Romanian (Romania)");
	ChoiceList.Add("ru_RU", "Russian (Russia)");
	ChoiceList.Add("sr_BA", "Serbian (Bosnia and Herzegovina)");
	ChoiceList.Add("sr_ME", "Serbian (Montenegro)");
	ChoiceList.Add("sr_CS", "Serbian (Serbia and Montenegro)");
	ChoiceList.Add("sr_RS", "Serbian (Serbia)");
	ChoiceList.Add("sk_SK", "Slovak (Slovakia)");
	ChoiceList.Add("sl_SI", "Slovenian (Slovenia)");
	ChoiceList.Add("es_AR", "Spanish (Argentina)");
	ChoiceList.Add("es_BO", "Spanish (Bolivia)");
	ChoiceList.Add("es_CL", "Spanish (Chile)");
	ChoiceList.Add("es_CO", "Spanish (Colombia)");
	ChoiceList.Add("es_CR", "Spanish (Costa Rica)");
	ChoiceList.Add("es_DO", "Spanish (Dominican Republic)");
	ChoiceList.Add("es_EC", "Spanish (Ecuador)");
	ChoiceList.Add("es_SV", "Spanish (El Salvador)");
	ChoiceList.Add("es_GT", "Spanish (Guatemala)");
	ChoiceList.Add("es_HN", "Spanish (Honduras)");
	ChoiceList.Add("es_MX", "Spanish (Mexico)");
	ChoiceList.Add("es_NI", "Spanish (Nicaragua)");
	ChoiceList.Add("es_PA", "Spanish (Panama)");
	ChoiceList.Add("es_PY", "Spanish (Paraguay)");
	ChoiceList.Add("es_PE", "Spanish (Peru)");
	ChoiceList.Add("es_PR", "Spanish (Puerto Rico)");
	ChoiceList.Add("es_ES", "Spanish (Spain)");
	ChoiceList.Add("es_US", "Spanish (United States)");
	ChoiceList.Add("es_UY", "Spanish (Uruguay)");
	ChoiceList.Add("es_VE", "Spanish (Venezuela)");
	ChoiceList.Add("sv_SE", "Swedish (Sweden)");
	ChoiceList.Add("th_TH", "Thai (Thailand)");
	ChoiceList.Add("tr_TR", "Turkish (Turkey)");
	ChoiceList.Add("uk_UA", "Ukrainian (Ukraine)");
	ChoiceList.Add("vi_VN", "Vietnamese (Vietnam)");
	
EndProcedure

#EndRegion

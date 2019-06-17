#If Server Or ThickClientOrdinaryApplication Or ExternalConnection Then

// Procedure initializes banks list update.
//
Procedure RefreshBanksFromClassifier(ParametersStructure, StorageAddress) Export
	
	BanksArray        = New Array();
	DataForFilling = New Structure();
	
	SuccessfullyUpdated = WorkWithBanksOverridable.RefreshBanksFromClassifier(,
		CommonUse.SessionSeparatorValue());
	
	DataForFilling.Insert("SuccessfullyUpdated",   SuccessfullyUpdated);
	PutToTempStorage(DataForFilling, StorageAddress);
	
EndProcedure

#Region PrintInterface

// Fills in the list of printing commands.
// 
// Parameters:
//   PrintCommands - ValueTable - see the fields content in the PrintManagement.CreatePrintCommandsCollection function
//
Procedure AddPrintCommands(PrintCommands) Export
	
	
	
EndProcedure

#EndRegion

#Region ProgramInterface
	
// Function generates query result by
// bank classifier with filter by Code, correspondent account, name or city
//
// Parameters:
// Code - String (9) - Bank
// code BalancedAccount - String (20) - Correspondent account of the bank
//
// Returns:
// QueryResult - Query result by classifier.
//
Function GetQueryResultByClassifier(Code) Export
	
	If IsBlankString(Code)Then
		Query = New Query;
		Return Query.Execute().Select();
	EndIf;
	
	QueryBuilder = New QueryBuilder;
	QueryBuilder.Text =
	"SELECT
	|	BankClassifier.Code AS Code,
	|	BankClassifier.Description,
	|	BankClassifier.City,
	|	BankClassifier.Address,
	|	BankClassifier.Ref
	|FROM
	|	Catalog.BankClassifier AS BankClassifier
	|WHERE
	|	NOT BankClassifier.IsFolder
	|{WHERE
	|	BankClassifier.Code}
	|{ORDER BY
	|	Description}";
	
	Filter = QueryBuilder.Filter;
	
	If ValueIsFilled(Code) Then
		Filter.Add("Code");
		Filter.Code.Value = TrimAll(Code);
		Filter.Code.ComparisonType = ComparisonType.Contains;
		Filter.Code.Use = True;
	EndIf;
	
	Order = QueryBuilder.Order;
	Order.Add("Description");
	
	QueryBuilder.Execute();
	QueryResult = QueryBuilder.Result;
	
	Return QueryResult;
	
EndFunction

// Function receives references table for banks by Code or correspondent account.
//
// Parameters:
// Field - String - Field name (Code) Value - String - Value Code
//
// Returns:
// ValueTable - Found banks
//
Function GetBanksTableByAttributes(Field, Value) Export
	
	BanksTable = New ValueTable;
	Columns = BanksTable.Columns;
	Columns.Add("Ref");
	Columns.Add("Code");
	
	ThisIsCode = False;
	If Find(Field, "Code") <> 0 Then
		ThisIsCode = True;
	EndIf;
	
	If ThisIsCode AND StrLen(Value) > 6 Then
		
		If ThisIsCode Then
			
			QueryResult = GetDataFromBanks(Value);
			
		EndIf;
		
		If Not QueryResult.IsEmpty() Then
			
			Selection = QueryResult.Select();
			While Selection.Next() Do
				
				NewRow = BanksTable.Add();
				FillPropertyValues(NewRow, Selection);
				
			EndDo;
			
		EndIf;
		
		If BanksTable.Count() = 0 Then
			
			AddBanksFromClassifier(
				?(ThisIsCode, Value, ""), // Code
				BanksTable
			);
			
		EndIf;
		
	EndIf;
	
	Return BanksTable;
	
EndFunction

#EndRegion 

#Region ServiceProceduresAndFunctions

// Procedure adds new bank
// from classifier by Code value or correspondent account.
//
// Parameters:
// Code - String (9) - Bank
// account of the BanksTable bank account - ValueTable - Banks table
//
Procedure AddBanksFromClassifier(Code, BanksTable)
	
	SetPrivilegedMode(True);

	QueryResult = GetQueryResultByClassifier(Code);
	
	BankClassifierArray = New Array;
	
	Selection = QueryResult.Select();
	While Selection.Next() Do
		BankClassifierArray.Add(Selection.Ref);
	EndDo;
	
	If BankClassifierArray.Count() > 0 Then
		
		BanksArray = WorkWithBanksOverridable.BankClassificatorSelection(BankClassifierArray);
		
	Else
		
		Return;
		
	EndIf;
	
	BankFound = False;
	For Each FoundBank In BanksArray Do
		
		SearchByCode		= Not IsBlankString(Code) AND Not FoundBank.IsFolder;
		
		If SearchByCode 
			AND FoundBank.Code = Code Then
			
			BankFound = True;
			
		ElsIf SearchByCode 
			AND Find(FoundBank.Code, Code) > 0 Then
			
			BankFound = True;
			
		EndIf;
		
		If BankFound Then
			
			NewRow = BanksTable.Add();
			FillPropertyValues(NewRow, FoundBank);
			
		EndIf;
		
	EndDo;
	
EndProcedure

// Returns data source focusing on the configuration work mode
// 
Function GetDataSource()
	
	Query = New Query("SELECT * FROM Catalog.Banks");
	Return Query.Execute();
	
EndFunction

// Add report builder filter item
//
Procedure AddFilterItemOfFilterBuilder(Builder, Name, Value, ComparisonTypeValue)
	
	If ValueIsFilled(Value) Then
		
		FilterItem = Builder.Filter.Add(Name);
		
	Else
		
		Return;
		
	EndIf;
	
	FilterItem.ComparisonType = ComparisonTypeValue;
	FilterItem.Value = Value;
	FilterItem.Use = True;
	
EndProcedure

// Function generates query result by
// bank classifier with filter by Code, bank name, city
//
// - data separation is enabled, data source is bank classifier catalog.
// - data separation is not enabled, data source is template attached to banks catalog
//
// Parameters:
// Code - String (9) - Bank
// code BalancedAccount - String (20) - Correspondent account of the bank
//
// Returns:
// QueryResult - Query result by classifier.
//
Function GetDataFromBanks(Code)
	
	Builder = New QueryBuilder;
	Builder.DataSource = New DataSourceDescription(GetDataSource());
	
	AddFilterItemOfFilterBuilder(Builder, "Code", 		TrimAll(Code), 		ComparisonType.Contains);
	
	Builder.Execute();
	
	Return Builder.Result;
	
EndFunction

#EndRegion 

#EndIf
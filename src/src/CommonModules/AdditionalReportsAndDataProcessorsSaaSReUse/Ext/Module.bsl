////////////////////////////////////////////////////////////////////////////////
// Additional Reports and data processors in Service Models subsystem,
//  procedures and functions with the repeated use of return values.
// 
////////////////////////////////////////////////////////////////////////////////

#Region ProgrammingInterface

// The function returns an array containing the
//  AdditionalReportsAndDataProcessors catalog attribute names that you can not change if there are connections with the
//  supplied data processors.
//
Function ControlledAttributes() Export
	
	Result = New Array();
	Result.Add("SafeMode");
	Result.Add("DataProcessorStorage");
	Result.Add("ObjectName");
	Result.Add("Version");
	Result.Add("Kind");
	
	Return New FixedArray(Result);
	
EndFunction

// The function returns the matching
//  of ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS enums items to the detailed description of disable reason.
//
Function ExtendedDescriptionsReasonsLock() Export
	
	Reasons = Enums.ReasonsForDisablingAdditionalReportsAndDataProcessorsSaaS;
	
	Result = New Map();
	Result.Insert(Reasons.BlockAdministratorService, NStr("en = 'Use of additional data processor is prohibited as service rules were violated.'"));
	Result.Insert(Reasons.BlockingByOwner, NStr("en = 'Use of additional data processor is prohibited by the data processor owner.'"));
	Result.Insert(Reasons.ConfigurationVersionUpdate, NStr("en = 'Additional data processor is temporarily unavailable as the application is being updated. It may take several minutes. We apologize for the inconvenience.'"));
	
	Return New FixedMap(Result);
	
EndFunction

#EndRegion

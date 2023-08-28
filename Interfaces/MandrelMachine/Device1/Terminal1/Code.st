// Terminal1 code
VAR_GLOBAL
    old_Unit_ManMode        : BOOL;
END_VAR

FUNCTION TIMED_LOOP
	CheckAlarm(); 
    CheckAlrm_Reset();    
    IF (old_Unit_ManMode <> Unit.ManMode) THEN
        old_Unit_ManMode:= Unit.ManMode;
        GotoMask(Main_1);
    END_IF;
    IF (MaskActive) THEN
        GotoLoop(Loop_Clone_2);
    END_IF;
END_FUNCTION

FUNCTION Main_1_PRG
	GotoLoop(Loop_Settings);
END_FUNCTION

FUNCTION Terminal1_ESC
	GotoLoop(Loop_Main);
END_FUNCTION

FUNCTION Main_1_ESC
	GotoLoop(Loop_Info);
END_FUNCTION

VAR_GLOBAL   
    LastValidRecord                                 : DINT;  // Index of the last valid record
    LastActAlrm                                     : DINT;  // Index of the last active alarm
    infoLogOk, AlrmLogInfoErr                       : DINT;  // result of function GetAlarmLogInfo
	AlrmIdx, AlrmCode                               : DINT;  // Used on GetAlarmInfo
    AlrmLogsIdx, AlrmLogCode, AlrmLogsTot           : DINT;  // Used on GetAlarmLogInfo
    AlrmLogEventType                                : USINT; // Type of alarm event
    AlrmStoredVarReal1, AlrmStoredVarReal2          : REAL;  // Alarm variable stored  
    EnStoredVar1_REAL, EnStoredVar2_REAL            : BOOL;  // Stored alarm variable enable
    N_Alrms,N_Alrms_Prev                            : DINT;  // Current and previous alarm number
    KeyAlarmAutorepeatActive                        : BOOL;  // Single alarm reset management
    ClrAutoResCounters                              : BOOL;  // Enable for ClrAutoResCounters statement
    AlrmLogsIdxTemp,AlrmLogCodeTemp,AlrmLogTimeTemp : DINT;  // Temporary variables for alarm information
    AlrmLogEventTypeTemp                            : USINT; // Temporary variables for "AlrmLogInfoErr" statement
    AlrmLogDelete                                   : BOOL;  // Alarm log delete enable 
    EnCheckAlarm                                    : BOOL;  // Enable check alarm function 
    En_CheckAlrm_Reset                              : BOOL;  // Enable the alarm check after a Global alarm Reset
    ShowTemp                                        : BOOL;  // Show Board temperature if the function is implemented on the target (only c.pCO)
    isActiveAlarmLoop                               : BOOL;  // Флаг, находимся ли мы в списке активных аварий
    isNoAlarmMask                                   : BOOL;  // Флаг, находимся ли мы в маске Нет аварий
END_VAR


FUNCTION gotoAlarmLog        
                                
    AlrmLogsTot:= GetAlarmLogsCount();
    // Show last alarm log                            
    IF AlrmLogsTot > 0 THEN                                       
        AlrmLogsIdx:=1;
        infoLogOk:=GetAlarmLogInfo(AlrmLogsIdx, AlrmLogCode,  AlrmLogEventType, Alarms.AlrmLogTime);
        CheckStoredVar_Log(); 
    ELSE
        AlrmLogsIdx:=0;
        infoLogOk:=-1;
    END_IF;

    IF infoLogOk = 0 THEN                                         
        LastValidRecord:= AlrmLogsIdx;
        GotoLoop(ALRMLOGS);
    ELSE
        GotoMask(Alrms_NoLog);                                   
    END_IF;

END_FUNCTION

FUNCTION CheckStoredVar_Log                                                   // This function let you sample the sampled variables on Alarm table
    
    // --- Logged alarms ---// 
    IF GetAlarmLogStoredVar(AlrmLogsIdx, 1, AlrmStoredVarReal1) <> 0 THEN 
        EnStoredVar1_REAL := FALSE;                                           // If is present, enable the fields
    ELSE
        EnStoredVar1_REAL := TRUE;                                            // else, don't enable the fields
    END_IF;
    
    IF GetAlarmLogStoredVar(AlrmLogsIdx, 2, AlrmStoredVarReal2) <> 0 THEN
        EnStoredVar2_REAL := FALSE;     
    ELSE
        EnStoredVar2_REAL := TRUE; 
    END_IF;
    
END_FUNCTION

FUNCTION CheckAlarm                     // Check active alarms
    
    N_Alrms := GetAlarmsCount();        // Number of active alarms

    //isAlarm := N_Alrms <> 0;      

    IF (N_Alrms > N_Alrms_Prev) THEN      // Activate the buzzer and alarm led if any alarm is present
        //IF GeneralMng.RESERVED3 THEN       
        //__SYSVA_MANUAL_BUZZER_ON:= TRUE;
        //__SYSVA_MANUAL_BUZZER_OFF:= FALSE;
        //END_IF;
        SetLedStatus(12,2);
        EnCheckAlarm := TRUE;  
        // Обновление списка активных аварий если находимся в маске "Нет аварий" или в списке активных аварий
        IF (isNoAlarmMask) OR (isActiveAlarmLoop)THEN
            CheckActiveAlarm();
        END_IF;                          
    ELSIF (N_Alrms = 0) AND (N_Alrms < N_Alrms_Prev) THEN // Turn off the buzzer and alarm led if there aren't active alarms
        __SYSVA_MANUAL_BUZZER_OFF:= TRUE;    
        __SYSVA_MANUAL_BUZZER_ON:= FALSE;    
        SetLedStatus(12,0);  
         // Обновление списка активных аварий если находимся в списке активных аварий
        IF (isActiveAlarmLoop) THEN            
            CheckActiveAlarm();       
        END_IF;  
    ELSIF N_Alrms < N_Alrms_Prev THEN  // когда количество аварий уменьшилось (но не равно 0) - обновляем список
        IF (isActiveAlarmLoop) THEN  
            CheckActiveAlarm();       
        END_IF;
    END_IF;
  
    N_Alrms_Prev := N_Alrms;             // Save the previous number of alarm to the actual
END_FUNCTION

FUNCTION CheckActiveAlarm  
              
    VAR
        infoOk:DINT;
    END_VAR
    
    //MaskPos:= MASK_POS_MAIN;
    SetLedStatus(7,0);
    EnCheckAlarm := FALSE;

    N_Alrms := GetAlarmsCount();            // Get active alarms number

    __SYSVA_MANUAL_BUZZER_OFF:= TRUE;       // Every time i enter alarm mask, turn off the buzzer
    __SYSVA_MANUAL_BUZZER_ON:= FALSE;


    IF N_Alrms > 0 THEN                     // If there's a new alarm and alarm key is pressed,                                 
        SetLedStatus(12, 1);                // then fix the alarm led
        AlrmIdx := 1;
        infoOk:= GetAlarmInfo(AlrmIdx, AlrmCode , Alarms.AlrmTime); // Call GetAlarmInfo to show first alarm active
        CheckStoredVar_Alrm();
        isActiveAlarmLoop:= TRUE;
        isNoAlarmMask:=     FALSE;
        GotoLoop(ACTIVEALARMS);
    ELSE
        AlrmIdx := 0;
        SetLedStatus(12, 0);                
        IF __SYSVA_KEY_COUNTER <= 1 THEN
            isNoAlarmMask:=     TRUE;
            isActiveAlarmLoop:= FALSE;
            GotoMask(Alrms_NoAlrms);        // If there are no active alarms, goto no_alarms loop
        ELSIF __SYSVA_KEY_COUNTER >= 3 THEN // Try to reset alarms also if no alarms(due to remote devices)
            ResetAlarms();
            //Alarms.AlrmResByPGD1:=TRUE;
            AlrmIdx:= 0;
        END_IF;
    END_IF;
END_FUNCTION

FUNCTION CheckStoredVar_Alrm                                                  // This function let you sample the sampled variables on Alarm table
    
    // --- Active alarms ---// 
    IF GetAlarmStoredVar(AlrmIdx, 1, AlrmStoredVarReal1) <> 0 THEN            // Control if there's any variable to be sampled
        EnStoredVar1_REAL := FALSE;                                           // If is present, enable the fields
    ELSE
        EnStoredVar1_REAL := TRUE;                                            // else, don't enable the fields
    END_IF;

    IF GetAlarmStoredVar(AlrmIdx, 2, AlrmStoredVarReal2) <> 0 THEN
        EnStoredVar2_REAL := FALSE;     
    ELSE
        EnStoredVar2_REAL := TRUE; 
    END_IF;
    
END_FUNCTION

FUNCTION CheckAlrm_Reset
    // Check the active alarms after a Global/Single alarm reset
    IF En_CheckAlrm_Reset THEN
        IF N_Alrms = 0 THEN
            GotoMask(Alrms_NoAlrms);      
        ELSE          
            CheckActiveAlarm();
        END_IF;
        En_CheckAlrm_Reset := FALSE;
    END_IF;
END_FUNCTION

FUNCTION ResetGlobalAlarm
    IF __SYSVA_KEY_COUNTER >= 3 THEN        // If I hold down the alarm button for more 
            ResetAlarms();                  // than 3 seconds then resets all alarms
            //Alarms.AlrmResByPGD1 := TRUE;           
            AlrmIdx:= 1;
            En_CheckAlrm_Reset := TRUE;     // Enable the CheckAlrm_Reset function
    END_IF;
END_FUNCTION

FUNCTION ScrollAlarm_UP                                // Navigation trought active alarm mask
                                        
    N_Alrms := GetAlarmsCount();                       // Get active alarms count
    IF N_Alrms > 0 THEN                                // If there are active alarms,
        IF AlrmIdx > 1 AND AlrmIdx <= N_Alrms THEN     // and i'm not in the last alarm, then show me the previous alarm
            AlrmIdx:= AlrmIdx-1;
        ELSIF AlrmIdx = 1 THEN                         // If i'm in the last alarm, show next mask(Alarm_Reset)
            AlrmIdx:= 0;
            GotoPreviousMask();
        ELSIF AlrmIdx = 0 AND N_Alrms <> 0 THEN        // If i'm in the "Alarm_Reset" mask, go to Alarm_Active mask
            AlrmIdx := N_Alrms;
            GotoPreviousMask(); 
        END_IF;
        GetAlarmInfo(AlrmIdx, AlrmCode, Alarms.AlrmTime);     // Get alarm info by index
        CheckStoredVar_Alrm(); 
    ELSIF N_Alrms = 0 THEN                             // If there are no alarms, show No_alarms mask
        GotoMask(Alrms_NoAlrms);
    END_IF;

END_FUNCTION

FUNCTION ScrollAlarm_DOWN                              // Navigation trought active alarm mask

    N_Alrms := GetAlarmsCount();                       // Get active alarms count
    IF AlrmIdx = 0 AND N_Alrms <> 0 THEN               // If i'm in the "Alarm_Reset" mask, go to Alarm_Active mask
        GotoNextMask();
    END_IF; 
                                            
    IF N_Alrms >= 0 AND N_Alrms <> 0 THEN              // If there are active alarms,
        IF AlrmIdx >= 0 AND AlrmIdx < N_Alrms THEN     // and i'm not in the last alarm, then show me the next alarm
            AlrmIdx:= AlrmIdx+1;
        ELSIF AlrmIdx >= N_Alrms THEN                  // If i'm in the last alarm, show next mask(Alarm_Reset)
            AlrmIdx:= 0;
            GotoNextMask();
        END_IF;
        GetAlarmInfo(AlrmIdx, AlrmCode, Alarms.AlrmTime);     // Get alarm info by index
        CheckStoredVar_Alrm(); 
    ELSIF N_Alrms = 0 THEN                             // If there are no alarms, show No_alarms mask 
        GotoMask(Alrms_NoAlrms);
    END_IF;

END_FUNCTION

FUNCTION ScrollAlarmLog_UP 
     
    IF AlrmLogsIdx = 1 THEN                                         // If I'm displaying the first log alarm, then beep              
        Beep();
    ELSE
        AlrmLogsIdx:= AlrmLogsIdx-1;                                // else, decrease the alarm log index
        AlrmLogsIdxTemp:= AlrmLogsIdxTemp - 1;                      
        AlrmLogInfoErr:=GetAlarmLogInfo(AlrmLogsIdx, AlrmLogCode,   // Get information about alarm logs
                                    AlrmLogEventType, Alarms.AlrmLogTime);
        CheckStoredVar_Log();                                           // Show me sampled values if there are
    END_IF;
                                                     
END_FUNCTION

FUNCTION ScrollAlarmLog_DOWN  
  
    AlrmLogsIdxTemp := AlrmLogsIdx;
    AlrmLogsIdxTemp:= AlrmLogsIdxTemp + 1;
    AlrmLogInfoErr:=GetAlarmLogInfo(AlrmLogsIdxTemp, AlrmLogCodeTemp,       // Get information about alarm logs
                                    AlrmLogEventTypeTemp, AlrmLogTimeTemp);
    IF AlrmLogInfoErr = 1 THEN                                              // If I'm displaying the last log alarm, then beep
        Beep();
    ELSE
        IF AlrmLogsIdx < 64 THEN
            AlrmLogsIdx:= AlrmLogsIdx + 1;                                   // else, increase the alarm log index 
            AlrmLogInfoErr:=GetAlarmLogInfo(AlrmLogsIdx, AlrmLogCode,        // Get information about alarm logs
                                        AlrmLogEventType, Alarms.AlrmLogTime);
            CheckStoredVar_Log();                                                // Show me sampled values if there are
        ELSE
            AlrmLogsIdx := 64;
            Beep();
        END_IF;    
    END_IF;
   
END_FUNCTION

FUNCTION Dummy_Class_UP
	GotoPreviousMask();
END_FUNCTION

FUNCTION Dummy_Class_DOWN
	GotoNextMask();
END_FUNCTION


FUNCTION Main_3_ENTER
    BlowingON := TRUE;
	MaskActive:= FALSE;
    GotoLoop(Loop_Main);
END_FUNCTION

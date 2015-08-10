@{
    # Commands that will be included in the tutorial sessions
    "TutorialCommands" = @(
        "Get-ChildItem"
    )
    "TutorialData" = @(    
    ,@{
        "instruction" = "Let us try to use Get-Command. Start by typing Get-Command Get-ChildItem"
        "hints" = @{
            1 = "Type Get-Command Get-ChildItem into the terminal"
        }
        # has output but no answer so the tutorial will match result of user command with output
        "output"= @"
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Cmdlet          Get-ChildItem                                      3.1.0.0    Microsoft.PowerShell.Management
"@
    }
    ,@{
        "instruction" = "Now let's try to find the get-help command";
        # has answers but no output so the tutorial will match the result of running the first answer with the result of user command
        "answers" = @(
            "Get-Command Get-Help"
        )
        "hints" = @{
            1 = "Use Get-Command with Get-Help as the parameter"
            "Get-Command help" = "Close but help is not the same as get-help"
        }
    }
    ,@{
        # has both answers and output so the tutorial will match the answer with user answer and prints out output
        "instruction" = "Now let's try to get-command with wild card. Find commands starting with stop";
        "answers" = @(
            "Get-Command stop*"
        );
        "hints" = @{
            1 = "Use Get-Command with stop*"
            "Get-Command stop" = "Don't forget the *"
        }
        "output"=@"
CommandType     Name                                               Version    Source
-----------     ----                                               -------    ------
Function        Stop-DscConfiguration                              1.1        PSDesiredStateConfiguration
Function        Stop-Dtc                                           1.0.0.0    MsDtc
Function        Stop-DtcTransactionsTraceSession                   1.0.0.0    MsDtc
Function        Stop-NetEventSession                               1.0.0.0    NetEventPacketCapture
Function        Stop-PcsvDevice                                    1.0.0.0    PcsvDevice
Function        Stop-ScheduledTask                                 1.0.0.0    ScheduledTasks
Function        Stop-Trace                                         1.0.0.0    PSDiagnostics
Cmdlet          Stop-Computer                                      3.1.0.0    Microsoft.PowerShell.Management
Cmdlet          Stop-DtcDiagnosticResourceManager                  1.0.0.0    MsDtc
Cmdlet          Stop-Job                                           3.0.0.0    Microsoft.PowerShell.Core
Cmdlet          Stop-Process                                       3.1.0.0    Microsoft.PowerShell.Management
Cmdlet          Stop-Service                                       3.1.0.0    Microsoft.PowerShell.Management
Cmdlet          Stop-Transcript                                    3.0.0.0    Microsoft.PowerShell.Host
Cmdlet          Stop-VM                                            1.1        Hyper-V
Cmdlet          Stop-VMFailover                                    1.1        Hyper-V
Cmdlet          Stop-VMInitialReplication                          1.1        Hyper-V
Cmdlet          Stop-VMReplication                                 1.1        Hyper-V
"@
    }
)
}
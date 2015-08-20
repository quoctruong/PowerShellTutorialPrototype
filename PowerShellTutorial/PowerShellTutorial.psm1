$script:xmlTutorial = @"
<?xml version="1.0" encoding="utf-8"?>
<LocalTutorialData>
</LocalTutorialData>
"@

$script:simpleTutorialData = @"
@{{
    "TutorialCommands" = @(
        # Provide commands that the user can use in the tutorial session here
{0}
    )
    "TutorialData" = @(
    @{{
        "instruction" = "provide your instruction here"
        "answers" = @(
            "Get-CorrectAnswer1"
            "Get-CorrectAnswer2"
        );
        "hints" = @{{
            # The key can be numbers or string.
            # If it is a number, the hint will be printed out after that many attempts.
            # If it is a string, the hint will be printed out if the users put in 
            # that string as their answers.
            1 = "first hint"
            2 = "second hint"
        }}
        # this tutorial step will be mocked if both output and answers keys are present
        # this means the answer is not run at all
        "output"="This is what will be printed for the user"
    }},
    @{{
        "instruction" = "second step in tutorial";
        "answers" = @(
            "Get-AnotherCorrectAnswer"
        );
        "hints" = @{{
            "Get-AnotherAnswer" = "Almost correct. Check your noun"
        }}
        "output"="This is what I want the user to see"
    }},
    @{{
        "instruction" = "second step in tutorial";
        "hints" = @{{
            "Get-AnotherAnswer" = "Almost correct. Check your noun"
        }}
        # if this key is supplied, then there should not be answers or output keys
        # this command will be run after the user's input to verify that the user
        # has the correct response
        "verification"="`$true"
    }}
    )
}}
"@

$script:resumeTutorial = $false
$script:xmlPath = Join-Path $([System.Environment]::GetFolderPath("LocalApplicationData")) PowerShellTutorial\Tutorial.xml

function Get-Response ([string]$response)
{
    $tokens = @()
    $parse = [System.Management.Automation.Language.Parser]::ParseInput($response, [ref]$tokens, [ref]$null);

    $result = ""

    for($i = 0; $i -lt $tokens.Length; $i += 1) {
        $result += $tokens[$i].Text
        $result += " "
    }

    return $result.Trim()
}

function Write-Answer ([string]$output)
{
    if ($output -ne $null) {
        Write-Host "$output"
    }

    Write-Host -ForegroundColor Green "Correct!`n"

}

function Get-TutorialPromptOrAnswer([string[]]$prompt)
{
    $index = 0
    Write-Host -NoNewline -ForegroundColor Yellow $prompt[$index]
    $index += 1
    $index %= $prompt.Length
    $instruction = ""
    $line = 0
    while ($true) {
        $response = Read-Host
        if ([string]::IsNullOrWhiteSpace($response)) {
            break
        }

        $response = $response.Trim()

        if ($line -gt 0) {
            $instruction += "`n"
        }
        $instruction += $response
        Write-Host -NoNewline -ForegroundColor Yellow $prompt[$index]
        $index += 1
        $index %= $prompt.Length
        $line += 1
    }

    return $instruction
}

<#
.Synopsis
   Stop a Tutorial session that you are in. The tutorial session can be restored
   later with Restore-Tutorial
.EXAMPLE
   Stop-Tutorial
#>
function Stop-Tutorial
{
    [CmdletBinding()]
    Param()
    Begin
    {
    }
    Process
    {
        $tutorialNode = Update-TutorialNode $script:DataPath $Global:TutorialIndex
        CleanUpTutorial
        $Error.Clear()
    }
    End
    {
    }
}

function CleanUpTutorial {
    # clean up the prompt
    Set-Content Function:\prompt $Global:OldPrompt -ErrorAction SilentlyContinue

    # make all commands visible again
    if ($Global:AllCommandsBeforeTutorial -ne $null) {
        $Global:AllCommandsBeforeTutorial | ForEach-Object {$_.Visibility = "Public"}
    }

    # Return the sessionstate to original setting
    foreach ($application in $Global:OldApplications) {
        $ExecutionContext.SessionState.Applications.Add($application)
    }

    foreach ($script in $Global:OldScripts) {
        $ExecutionContext.SessionState.Scripts.Add($script)
    }

    # Remove the proxy functions
    Remove-Item Function:\Out-Default -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-List -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-Table -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-Wide -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-Custom -Force -ErrorAction SilentlyContinue

    # Remove variables
    $VariablesToCleanUp = @("OldPrompt", "LastOutput", "TutorialAttempts", "TutorialAlmostCorrect", "TutorialIndex",
                            "TutorialHint", "ResultFromAnswer", "TutorialBlocks", "OutputErrorToPipeLine", "Formatted",
                            "TutorialPrompt", "OldApplications", "OldScripts", "TutorialVerfication")

    foreach ($variable in $VariablesToCleanUp) {
        if (Test-Path "Variable:\$variable") {
            Remove-Variable -Name $variable -Scope Global -ErrorAction SilentlyContinue
        }
    }
}

# Returns a string that represents the TutorialCommands key value section of the dictionary in tutorial data file
function CreateTutorialCommandSection([string[]]$tutorialCommands) {
    $output = ""
    if ($null -ne $tutorialCommands -and $tutorialCommands.Count -gt 0) {
        foreach ($cmd in $tutorialCommands) {
            $output += "`t`t`"$cmd`"$newline"
        }
    }

    return $output
}

# Create a tutorial in a module
# ModulePath is the path to the module
# TutorialCommands is an optional parameter which is list of allowed commands
function CreateTutorialInModule([string]$modulePath, [System.Management.Automation.PSCmdlet]$callerPScmdlet, [string[]]$tutorialCommands) {
    $tutorialData = $script:simpleTutorialData -f (CreateTutorialCommandSection $tutorialCommands)

    if ($Interactive) {
        $newline = [System.Environment]::NewLine

        $fileOutput = "@{$newline"

        if ($null -ne $tutorialCommands -and $tutorialCommands.Count -gt 0) {
            $fileOutput += "`t`"TutorialCommands`" = @($newline"

            $fileOutput += CreateTutorialCommandSection $tutorialCommands

            $fileOutput += "`t)$newline"
        }

        $fileOutput += "`t`"TutorialData`" = @($newline"

        while ($true) {              
            $indentation = "`t`t"
            Write-Host -ForegroundColor Cyan "$($newline)Write your instruction here. Input a new line to move on to verification"
            $instruction = Get-TutorialPromptOrAnswer "Instruction> "        

            if ($instruction.IndexOf("`n") -gt 0) {
                $instruction = "@`"$newline$($instruction.Trim())$newline`"@"
            } else {
                $instruction = "`"$instruction`""
            }

            Write-Host -ForegroundColor Cyan "$($newline)Write the command to verify your response here. Input a new line to move on to hints if you provide a command,$($newline)else you will be moved on to answers"

            $verifications = Get-TutorialPromptOrAnswer "Verification> "

            $verifications = $verifications.Split("`n")
            $verificationOutputs = ""

            foreach ($verification in $verifications) {
                $verification = $verification.Trim()
                if (-not [string]::IsNullOrWhiteSpace($verification)) {
                    $verificationOutputs += $verification
                }

                # verification has length longer than 1, attach newline
                if ($verifications.Length -gt 1) {
                    $verificationOutputs += $newline
                }
            }

            $hasVerification = -not [string]::IsNullOrWhiteSpace($verificationOutputs)

            if ($verifications.IndexOf("`n") -gt 0) {
                $verificationOutputs = "@`"$newline$($verificationOutputs.Trim())$newline`"@"
            } else {
                $verificationOutputs = "`"$verificationOutputs`""
            }

            # only move to hint if there is no verification
            if (-not $hasVerification) {
                Write-Host -ForegroundColor Cyan "$($newline)Write your acceptable answers here. Input a new line to move on to hints"

                $answers = Get-TutorialPromptOrAnswer "Answers> "

                $answersOutput = ""
    
                if (-not [string]::IsNullOrWhiteSpace($answers)) {
                    $answers = $answers.Split("`n")

                    $answersOutput = "@($newline"
                    foreach ($answer in $answers) {
                        $answersOutput += "$indentation`t`"$($answer.Trim())`"$newline"
                    }
                    $answersOutput += "$indentation)$newline"
                }
            }

            Write-Host -ForegroundColor Cyan "$($newline)There are two parts of a hint: trigger and the hint itself.$newline"`
            "The trigger can be a number, which will correspond to the number of times a user will have to enter the response incorrectly for the hint to appear.$newline"`
            "The trigger can also be a string, which will correspond to the incorrect input that a user will have to enter for the hint to disappear.$newline"`
            "The hint itself correspond to the output.$newline"`
            "Input a new line to move on to output (if you did not supply verification)"

            $hints = Get-TutorialPromptOrAnswer "Trigger> ", "Hint> "
    
            $hints = $hints.Split("`n")

            $lengthOfHint = $hints.Length

            if (($lengthOfHint % 2) -eq 1) {
                $lengthOfHint = $lengthOfHint - 1
            }

            $hintsOutput = ""

            if ($lengthOfHint -gt 0) {
                $hintsOutput = "@{$newline"
        
                # now we have even number of the inputs

                for ($i = 0; $i -lt $lengthOfHint/2; $i += 1) {
                    $key = $hints[2*$i]
                    $value = $hints[2*$i+1]
                    if ([string]::IsNullOrWhiteSpace($key) -or [string]::IsNullOrWhiteSpace($value)) {
                        continue;
                    }
            
                    [int]$keyNumber = $null
                    if ([int32]::TryParse($key.Trim(), [ref]$keyNumber)) {
                        $hintsOutput += "$indentation`t$keyNumber = `"$($value.Trim())`"$newline"
                    }
                    else {
                        $hintsOutput += "$indentation`t`"$key`" = `"$($value.Trim())`"$newline"
                    }

                }

                $hintsOutput += "$indentation}$newline"
            }

            if (-not $hasVerification) {
                Write-Host -ForegroundColor Cyan "$($newline)Write your output here, otherwise it will be the output of the first acceptable response$($newline). If you want to pipe the output from a command, type Run-Command: <Your Command>. Input a new line to move on to the next tutorial block"

                $outputs = Get-TutorialPromptOrAnswer "Output> "

                $outputs = $outputs.Split("`n")
                $outputsOutput = ""

                foreach ($output in $outputs) {
                    $output = $output.Trim()
                    if ($output.StartsWith("Run-Command:", "CurrentCultureIgnoreCase")) {
                        $command = $output.Substring("Run-Command:".Length).Trim();
                        try {
                            $output = Invoke-Expression $command | Out-String
                        }
                        catch { }
                    }

                    $outputsOutput += $output

                    if ($outputs.Length -gt 1) {
                        $outputsOutput += $newline
                    }
                }

                if ($outputsOutput.IndexOf("`n") -gt 0) {
                    $outputsOutput = "@`"$newline$($outputsOutput.Trim())$newline`"@"
                } else {
                    $outputsOutput = "`"$outputsOutput`""
                }
            }

            $tutorialBlock = "`t,@{$newline"
            $tutorialBlock += "$indentation`"instruction`" = $instruction"
            $tutorialBlock += $newline

            if (-not [string]::IsNullOrWhiteSpace($hintsOutput)) {
                $tutorialBlock += "$indentation`"hints`" = $hintsOutput"
                $tutorialBlock += $newline
            }

            if (-not [string]::IsNullOrWhiteSpace($verificationOutputs)) {
                $tutorialBlock += "$indentation`"verification`" = $verificationOutputs"
                $tutorialBlock += $newline
            }

            if (-not [string]::IsNullOrWhiteSpace($answersOutput)) {
                $tutorialBlock += "$indentation`"answers`" = $answersOutput"
                $tutorialBlock += $newline
            }

            if (-not [string]::IsNullOrWhiteSpace($outputsOutput)) {
                $tutorialBlock += "$indentation`"output`" = $outputsOutput"
            }
            $tutorialBlock += $newline
            $tutorialBlock += "`t}$newline"

            $fileOutput += $tutorialBlock
            Write-Host -ForegroundColor Cyan "Tutorial block created."
    
            if ($PSCmdlet.ShouldContinue("Create more tutorial block?", "Confirm creating more tutorial block")) {
                continue;
            }
            else {
                break;
            }
        }

        $fileOutput += "`t)$newline}"
        $tutorialData = $fileOutput

    }

    $global:tutorialData = $tutorialData
    $global:modulePath = $modulePath

    $tutorialFolder = Join-Path $modulePath "Tutorial"

    if (-not [System.IO.Directory]::Exists($tutorialFolder)) {
        mkdir $tutorialFolder -ErrorAction Stop
    }

    [System.IO.File]::WriteAllText("$tutorialFolder\$Name.TutorialData.psd1", $tutorialData)

}

# Utility to throw an errorrecord
function ThrowError
{
    param
    (        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.Management.Automation.PSCmdlet]
        $CallerPSCmdlet,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]        
        $ExceptionName,

        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ExceptionMessage,
        
        [System.Object]
        $ExceptionObject,
        
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [System.String]
        $ErrorId,

        [parameter(Mandatory = $true)]
        [ValidateNotNull()]
        [System.Management.Automation.ErrorCategory]
        $ErrorCategory
    )
        
    CleanUpTutorial
    $exception = New-Object $ExceptionName $ExceptionMessage;
    $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception, $ErrorId, $ErrorCategory, $ExceptionObject    
    $CallerPSCmdlet.ThrowTerminatingError($errorRecord)
}


<#
.Synopsis
   Add a tutorial to an existing module
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
#>
function Add-Tutorial
{
    [CmdletBinding(SupportsShouldProcess)]
    Param
    (
        # The name of the tutorial
        [Parameter(Mandatory=$true,
                   Position=0)]
        [string]
        $Name,
        # if this is true then user will create the tutorial from the terminal
        [switch]
        $Interactive,
        # Allowed commands in the tutorial session
        [string[]]
        $TutorialCommands
    )
    Begin
    {
        try {
            Import-Module $Name
            $modulePath = Split-Path (Get-Module $Name).Path
        }
        catch {
            $exception = New-Object "System.ArgumentException" "Module $Name cannot be found";
            $errorRecord = New-Object System.Management.Automation.ErrorRecord $exception "System.ArgumentException", InvalidArgument, $directory    
            $PSCmdlet.ThrowTerminatingError($errorRecord)
        }
    }
    Process
    {
        CreateTutorialInModule $modulePath $PSCmdlet $TutorialCommands
    }
    End
    {
    }
}

<#
.Synopsis
   Generate a tutorial
.DESCRIPTION
   To create a new tutorial, run New-Tutorial -Name <TutorialName> -Destination <Destination>

   If Destination is not supplied, the tutorial folder will be created in the current directory.

   The data file contains a hashtable with 2 keys: TutorialCommands and TutorialData.

   The value of TutorialCommands is an array of command names that are allowed in the tutorial. You can populate this array by providing a -Commands <List of commands> parameters to either New-Tutorial or Add-Tutorial cmdlet.

   The value of TutorialData is an array of hashtables, each of which corresponds to a step in the tutorial. There are 4 possible keys in the hashtable:

   Instruction: The instruction of this step

   Answers: An array of acceptable responses

   Hints: A hashtable. The key can be either number or string:

   If the key is a number, then the corresponding value will be displayed if the user fails to provide the correct answer within that number of attempt.
   If the key is a string, then the corresponding value will be displayed if the user enters that string.
   Output: The output provided by the tutorial when the user enters the correct answer.

   If a block has no answers and no output entry, then the user is always correct.

   If a block has answers but not output entry, then the result of running the first answer will be compared to the result of the command that the user provides to determine whether the user is correct.

   If a block has output but not answers entry, then the value of the output entry will be compared to the result of running the command that the user provides to determine whether the user is correct.

   If a block has both answers and output entry, then we will check to see whether the command that the user provides fall into the list of answers to determine whether the user is correct. Any error resulted from running the user's command and the first answer will be suppressed (so basically this can be thought of as a form of mocking).

   You can directly edit the data file to create as many steps as you want to.
.EXAMPLE
   New-Tutorial -Name MyNewTutorial -TutorialCommands @("Get-MyObject")
   New-Tutorial -Name MyNewTutorial -Destination "C:\Testing"
#>
function New-Tutorial
{
    [CmdletBinding(SupportsShouldProcess)]
    Param
    (
        # The name of the tutorial
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        # if this is true then user will create the tutorial from the terminal
        [switch]
        $Interactive,
        # List of commands that will be allowed to run
        [string[]]
        [ValidateNotNullOrEmpty()]
        $TutorialCommands,
        # Destination to save the tutorial (if blanked, this will save to current folder)
        [string]
        [ValidateNotNullOrEmpty()]
        $Destination
    )

    Begin
    {
        # If path is not supplied, use current directory
        if ([string]::IsNullOrWhiteSpace($Destination)) {
            $InstallationFolder = Resolve-Path '.\'
        }
        else {
            # If path supplied is wrong, raise error
            if (-not (Test-Path $Destination)) {
                ThrowError -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage "Destination $Destination does not exists" `
                            -ErrorId "DirectoryDoesNotExists" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidArgument `
                            -ExceptionObject "$Destination"
            }

            $InstallationFolder = Resolve-Path $Destination
        }

        # Try to make the directory
        $directory = mkdir "$($InstallationFolder.Path)\$Name" -ErrorAction Stop
        $moduleManifestCommand = Get-Command New-ModuleManifest
        if ($moduleManifestCommand.Parameters.ContainsKey("Tags")) {
            # If tags is supported
            New-ModuleManifest "$($directory.FullName)\$Name.psd1" -Tags "PowerShellTutorial"
        }
        else {
            New-ModuleManifest "$($directory.FullName)\$Name.psd1" 
        }
    }
    Process
    {
        CreateTutorialInModule $directory.FullName $PSCmdlet $TutorialCommands
    }
    End
    {
    }
}

# Returns the Tutorial on this machine
function Get-Tutorial
{
    [CmdletBinding()]
    Param(
    )

    Begin
    {
    }

    Process
    {
        # Check whether there is a tutorial folder and a tutorialdata.psd1
        Get-Module -ListAvailable `
            | Where-Object {(-not [string]::IsNullOrWhiteSpace($_.Path)) -and (Test-Path (Join-Path (Join-Path (Split-Path $_.Path) "Tutorial") "$($_.Name).TutorialData.psd1"))} `
            | Format-Table -Property ModuleType, Name
    }

    End
    {
    }
}

<#
.Synopsis
   Restore a Tutorial that was stopped before.
.EXAMPLE
   Restore-Tutorial -Name <TutorialName>
#>
function Restore-Tutorial
{
    [CmdletBinding()]
    [Alias()]
    [OutputType([int])]
    Param
    (
        # Name of the tutorial
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
    )

    Begin
    {
    }
    Process
    {
        # no save data. just start as a new tutorial
        if (-not (Test-Path $script:xmlPath)) {
            Start-Tutorial $Name
        }
        else {
            $tutorialDataPath = ResolveTutorialDataPath $Name
            $tutorialNode = Update-TutorialNode $tutorialDataPath

            if ($tutorialNode -ne $null -and $tutorialNode.Block -ne $null)
            {
                $script:resumeTutorial = $true
                Start-Tutorial $tutorialDataPath -Block $tutorialNode.Block
            }
        }
    }
    End
    {
        $script:resumeTutorial = $false
    }
}

function Update-TutorialNode ([string]$Name, [int]$block=-1)
{
    $xml = [xml] (Get-Content $script:xmlPath)
    if ($xml.LocalTutorialData -ne $null -and $xml.LocalTutorialData.ChildNodes -ne $null) {
        $tutorialBlock = $xml.LocalTutorialData.ChildNodes | Where-Object { $_.Name -eq $Name } | Select-Object -First 1

        # update case
        if ($tutorialBlock -ne $null -and $block -ne -1) {
            [void]$tutorialBlock.SetAttribute("Block", $block)
            [void]$xml.Save($script:xmlPath)
        }

        return $tutorialBlock
    }

    return $null
}

# Start a new tutorial block
function StartTutorialBlock {
    $Global:TutorialAttempts = 0
    $Global:TutorialIndex += 1
    $i = $Global:TutorialIndex

    # no more block so clean up
    if ($i -ge $Global:TutorialBlocks.Count) {
        CleanUpTutorial
        $Error.Clear()
        return
    }

    $currentTutorialBlock = $Global:TutorialBlocks[$i]

    # If a tutorial block has a verification key, then it should not contain
    # either answer or output
    if ($currentTutorialBlock.ContainsKey("verification") -and `
        ($currentTutorialBlock.ContainsKey("answers") -or $currentTutorialBlock.ContainsKey("output"))) {
                ThrowError -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage "Tutorial Block $i contains both verification and output or answers key." `
                            -ErrorId "TutorialBlocksMalformed" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidArgument `
                            -ExceptionObject "$currentTutorialBlock"
    }

    $Global:TutorialPrompt = "[$i] PSTutorial> "

    $instruction = $currentTutorialBlock["instruction"]
    [string[]] $acceptableResponses = $currentTutorialBlock["answers"]
    $Global:TutorialHint = ""
    $Global:TutorialAlmostCorrect = ""
    $Global:TutorialVerification = $currentTutorialBlock["verification"]

    $Global:ResultFromAnswer = ""

    # we only run the first answer if acceptable response is not null and output is not null.
    # otherwise we don't run the first answer because the author may be mocking  
    # we also don't run the first answer if there is a verification
    if ($acceptableResponses -ne $null -and $acceptableResponses.Count -gt 0 `
        -and (-not [string]::IsNullOrWhiteSpace($currentTutorialBlock["output"])) `
        -and (-not [string]::IsNullOrWhiteSpace($Global:TutorialVerification))) {
        try {
            $Global:ResultFromAnswer = Invoke-Expression $acceptableResponses[0] | Out-String
        }
        catch {
            # If we can't invoke then return empty string
            $Global:ResultFromAnswer = ""
        }
        finally {
            $Error.Clear()
        }
    }
    
    Write-Host -ForegroundColor Cyan "$instruction `n"

    Write-Host
}

# Verify answer and checks whether we can move on to the next block
function TutorialMoveOn {
    if ($Global:TutorialAttempts -eq -1) {
        StartTutorialBlock
        return
    }

    $i = $Global:TutorialIndex

    $instruction = $Global:TutorialBlocks[$i]["instruction"]
    [hashtable] $hints = $Global:TutorialBlocks[$i]["hints"]
    [string[]] $acceptableResponses = $Global:TutorialBlocks[$i]["answers"]

    # Getting the last index History
    $lastHistoryIndex = (Get-History | Select-Object -Last 1).Id

    # if count catch up with id, user has input something
    if ($lastHistoryIndex -eq $Global:HistoryId) {
        [string]$response = (Get-History -Id $Global:HistoryId)
        $Global:HistoryId += 1
    }        

    # Verification time
    if ([string]::IsNullOrWhiteSpace($response)) {
        return
    }

    # See whether we can use verify first
    if (-not [string]::IsNullOrWhiteSpace($Global:TutorialVerification)) {
        $verification = $false

        try {
            $verification = Invoke-Expression $Global:TutorialVerification | Select-Object -Last 1
        }
        catch {}

        # answer is correct!
        if ($verification -eq $true) {
            Write-Answer
            StartTutorialBlock
            return
        }
    }
    else {
        # the author does not supply verify keyword
        $result = $Global:LastOutput | Out-String     
        [string]$expectedOutput = $Global:TutorialBlocks[$i]["output"]    
                
        # we match output result if no answers are supplied
        if ($null -eq $acceptableResponses) {
            # if output is null, then nothing to do
            if ([string]::IsNullOrWhiteSpace($expectedOutput)) {
                # don't report error here
                $Error.Clear()
                StartTutorialBlock
                return
            }
                    
            # output is not null, we match
            if (($expectedOutput -replace '\s+',' ').Trim() -ieq ($result -replace '\s+',' ').Trim()) {            
                Write-PSError
                Write-Answer
                StartTutorialBlock
                return
            }
        }

        #here the acceptable response is not null
        if ($response -iin $acceptableResponses) {
            # acceptable response
            if (-not [string]::IsNullOrWhiteSpace($expectedOutput)) {
                # Mocking so clear possible error
                $Error.Clear()
                Write-Answer $expectedOutput
            }
            else {                        
                Write-PSError
                Write-Answer
            }

            StartTutorialBlock
            return
        }

        # here, response is not in acceptableResponses
        Write-PSError

        # we try to match user response with the result from one of the acceptable response
        if (-not [string]::IsNullOrWhiteSpace($result)) {
            if (($result -replace '\s+',' ').Trim() -ieq ($Global:ResultFromAnswer -replace '\s+',' ').Trim()) {
                Write-Answer
                StartTutorialBlock
                return
            }
        }
    }

    # incorrect answer
    Write-Host -ForegroundColor Red "$response is not correct`n"            

    if ($hints -ne $null -and $hints.ContainsKey($response)) {
        $Global:TutorialAlmostCorrect = $hints[$response]
    }
    else
    {
        $Global:TutorialAttempts += 1
    }

    # after we finished veryfing answer, if there is no change, we print out the same prompt
    if ($hints -ne $null -and $hints.ContainsKey($Global:TutorialAttempts)) {
        $Global:TutorialHint = $hints[$Global:TutorialAttempts]
    }
    
    if (-not [string]::IsNullOrWhiteSpace($Global:TutorialAlmostCorrect)) {
        Write-Host -ForegroundColor Green "Hints: $Global:TutorialAlmostCorrect`n"
        $Global:TutorialAlmostCorrect = ""
    }
    elseif (-not [string]::IsNullOrWhiteSpace($Global:TutorialHint)) {
        Write-Host -ForegroundColor Green "Hints: $Global:TutorialHint`n"
    }
    
    Write-Host -ForegroundColor Cyan "$instruction `n"

    Write-Host
}

# Given a string which can be either name or path, returns path to .TutorialData.psd1 file
function ResolveTutorialDataPath ([string]$TutorialNameOrPath) {
    if (Test-Path $TutorialNameOrPath) {
        $tutorialPath = Resolve-Path $TutorialNameOrPath
        # if the path is a psd1 folder
        if ($tutorialPath.Path.EndsWith(".TutorialData.psd1")) {
            $tutorialDataPath = $tutorialPath.Path
        }
        else {
            # if path is tutorial folder itself
            if ([System.IO.Path]::GetFileName($tutorialPath.Path) -eq "Tutorial") {
                $tutorialDirectory = $tutorialPath.Path
            }
            else {
                # checks that it has subdirectory tutorial folder
                [System.IO.DirectoryInfo]$tutorialDirectoryInfo = Get-ChildItem $tutorialPath.Path | Where-Object {$_ -is [System.IO.DirectoryInfo] -and $_.Name -eq "Tutorial"} | Select-Object -First 1
                if ($tutorialDirectoryInfo -ne $null) {
                    $tutorialDirectory = $tutorialDirectoryInfo.FullName
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($tutorialDirectory)) {
                [System.IO.FileInfo]$tutorialDataPathFileInfo = Get-ChildItem $tutorialDirectory | Where-Object {$_ -is [System.IO.FileInfo] -and $_.Name.EndsWith(".TutorialData.psd1")} | Select-Object -First 1
                if ($tutorialDataPathFileInfo -ne $null) {
                    $tutorialDataPath = $tutorialDataPathFileInfo.FullName
                }
            }
        }
                
    }
    else {
        Import-Module $TutorialNameOrPath -Global
        $module = (Get-Module $TutorialNameOrPath)
        # get the path to the tutorialdata.psd1 file
        $tutorialDataPath = Join-Path (Join-Path (Split-Path $module.Path) "Tutorial") "$Name.TutorialData.psd1"
    }

    return $tutorialDataPath
}

<#
.Synopsis
   Start a Tutorial session. Supply the name of the Tutorial, which is the name
   of a module that contains a Tutorial folder.
   You can also supply a path to a folder that contains a tutorial folder.
.EXAMPLE
   Start-Tutorial Get-CommandTutorial
#>
function Start-Tutorial
{
    [CmdletBinding()]
    Param
    (
        # Name of the tutorial
        [Parameter(Mandatory=$true,
                   Position=0)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name,
        [int]
        $Block=0
    )

    Begin
    {
        # Wrapper for Out-Default that saves the last object written
        # and handles missing commands if the command is a directory
        # or an URL. 
        #
        function Global:Out-Default
        {
            [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113362', RemotingCapability='None')]
            param(
                [switch]
                ${Transcript},

                [Parameter(ValueFromPipeline=$true)]
                [psobject]
                ${InputObject})

            begin
            {
                $wrappedCmdlet = $ExecutionContext.InvokeCommand.GetCmdlet(
                "Out-Default")
                $scriptCmdlet = { & $wrappedCmdlet @PSBoundParameters }
                $steppablePipeline = $scriptCmdlet.GetSteppablePipeline()
                $steppablePipeline.Begin($pscmdlet)
                $captured = @()
            }
            process {

                $captured += $_
                # Only output to error pipeline if we told the process to do so
                if ($_ -isnot [System.Management.Automation.ErrorRecord] -or $Global:OutputErrorToPipeLine -eq $true)
                {
                    $steppablePipeline.Process($_)
                    $Error.Add($_)
                }
            }
            end {
                if ($global:Formatted -eq $true) {
                    $global:Formatted = $false
                }
                else {
                    $global:LastOutput = $captured
                }
                $steppablePipeline.End()
            }
        }

        function Global:Format-Custom
        {
        [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113301')]
        param(
            [Parameter(Position=0)]
            [System.Object[]]
            ${Property},

            [ValidateRange(1, 2147483647)]
            [int]
            ${Depth},

            [System.Object]
            ${GroupBy},

            [string]
            ${View},

            [switch]
            ${ShowError},

            [switch]
            ${DisplayError},

            [switch]
            ${Force},

            [ValidateSet('CoreOnly','EnumOnly','Both')]
            [string]
            ${Expand},

            [Parameter(ValueFromPipeline=$true)]
            [psobject]
            ${InputObject})

        begin
        {
            try {
                $outBuffer = $null
                if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
                {
                    $PSBoundParameters['OutBuffer'] = 1
                }
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Format-Custom', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($PSCmdlet)
                $captured = @()
            } catch {
                throw
            }
        }

        process
        {
            try {
                $captured += $_
                $steppablePipeline.Process($_)
            } catch {
                throw
            }
        }

        end
        {
            try {
                $global:Formatted = $true
                $PSBoundParameters["InputObject"] = $captured
                $global:LastOutput = Microsoft.PowerShell.Utility\Format-Custom @PSBoundParameters
                $steppablePipeline.End()
            } catch {
                throw
            }
        }
        <#

        .ForwardHelpTargetName Microsoft.PowerShell.Utility\Format-Custom
        .ForwardHelpCategory Cmdlet

        #>
        }

        function Global:Format-List
        {
        [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113302')]
        param(
            [Parameter(Position=0)]
            [System.Object[]]
            ${Property},

            [System.Object]
            ${GroupBy},

            [string]
            ${View},

            [switch]
            ${ShowError},

            [switch]
            ${DisplayError},

            [switch]
            ${Force},

            [ValidateSet('CoreOnly','EnumOnly','Both')]
            [string]
            ${Expand},

            [Parameter(ValueFromPipeline=$true)]
            [psobject]
            ${InputObject})

        begin
        {
            try {
                $outBuffer = $null
                if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
                {
                    $PSBoundParameters['OutBuffer'] = 1
                }
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Format-List', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($PSCmdlet)
                $captured = @()
            } catch {
                throw
            }
        }

        process
        {
            try {
                $captured += $_
                $steppablePipeline.Process($_)
            } catch {
                throw
            }
        }

        end
        {
            try {
                $global:Formatted = $true
                $global:LastOutput = Microsoft.PowerShell.Utility\Format-List @PSBoundParameters
                $steppablePipeline.End()
            } catch {
                throw
            }
        }
        <#

        .ForwardHelpTargetName Microsoft.PowerShell.Utility\Format-List
        .ForwardHelpCategory Cmdlet

        #>
        }

        function Global:Format-Table
        {
        [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113303')]
        param(
            [switch]
            ${AutoSize},

            [switch]
            ${HideTableHeaders},

            [switch]
            ${Wrap},

            [Parameter(Position=0)]
            [System.Object[]]
            ${Property},

            [System.Object]
            ${GroupBy},

            [string]
            ${View},

            [switch]
            ${ShowError},

            [switch]
            ${DisplayError},

            [switch]
            ${Force},

            [ValidateSet('CoreOnly','EnumOnly','Both')]
            [string]
            ${Expand},

            [Parameter(ValueFromPipeline=$true)]
            [psobject]
            ${InputObject})

        begin
        {
            try {
                $outBuffer = $null
                if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
                {
                    $PSBoundParameters['OutBuffer'] = 1
                }
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Format-Table', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($PSCmdlet)
                $captured = @()
            } catch {
                throw
            }
        }

        process
        {
            try {
                $captured += $_
                $steppablePipeline.Process($_)
            } catch {
                throw
            }
        }

        end
        {
            try {
                $global:Formatted = $true
                $PSBoundParameters["InputObject"] = $captured
                $global:LastOutput = Microsoft.PowerShell.Utility\Format-Table @PSBoundParameters
                $steppablePipeline.End()
            } catch {
                throw
            }
        }
        <#

        .ForwardHelpTargetName Microsoft.PowerShell.Utility\Format-Table
        .ForwardHelpCategory Cmdlet

        #>
        }

        function Global:Format-Wide
        {
        [CmdletBinding(HelpUri='http://go.microsoft.com/fwlink/?LinkID=113304')]
        param(
            [Parameter(Position=0)]
            [System.Object]
            ${Property},

            [switch]
            ${AutoSize},

            [ValidateRange(1, 2147483647)]
            [int]
            ${Column},

            [System.Object]
            ${GroupBy},

            [string]
            ${View},

            [switch]
            ${ShowError},

            [switch]
            ${DisplayError},

            [switch]
            ${Force},

            [ValidateSet('CoreOnly','EnumOnly','Both')]
            [string]
            ${Expand},

            [Parameter(ValueFromPipeline=$true)]
            [psobject]
            ${InputObject})

        begin
        {
            try {
                $outBuffer = $null
                if ($PSBoundParameters.TryGetValue('OutBuffer', [ref]$outBuffer))
                {
                    $PSBoundParameters['OutBuffer'] = 1
                }
                $wrappedCmd = $ExecutionContext.InvokeCommand.GetCommand('Microsoft.PowerShell.Utility\Format-Wide', [System.Management.Automation.CommandTypes]::Cmdlet)
                $scriptCmd = {& $wrappedCmd @PSBoundParameters }
                $steppablePipeline = $scriptCmd.GetSteppablePipeline($myInvocation.CommandOrigin)
                $steppablePipeline.Begin($PSCmdlet)
                $captured = @()
            } catch {
                throw
            }
        }

        process
        {
            try {
                $captured += $_
                $steppablePipeline.Process($_)
            } catch {
                throw
            }
        }

        end
        {
            try {
                $global:Formatted = $true
                $PSBoundParameters["InputObject"] = $captured
                $global:LastOutput = Microsoft.PowerShell.Utility\Format-Wide @PSBoundParameters
                $steppablePipeline.End()
            } catch {
                throw
            }
        }
        <#

        .ForwardHelpTargetName Microsoft.PowerShell.Utility\Format-Wide
        .ForwardHelpCategory Cmdlet

        #>

        }

        $Global:OldPrompt = Get-Content Function:\prompt

        try {
            # resolve the path
            $script:DataPath = ResolveTutorialDataPath $Name

            if (Test-Path $script:DataPath) 
            {
                $tutorialDataFileName = [System.IO.Path]::GetFileName($script:DataPath)
                $tutorialDict = Import-LocalizedData -BaseDirectory (Split-Path $script:DataPath) -FileName $tutorialDataFileName

                # Get the name of the tutorial
                $Name = $tutorialDataFileName.Substring(0, $tutorialDataFileName.IndexOf(".TutorialData.psd1"))
            }

            if ($null -eq $tutorialDict -or (-not $tutorialDict.ContainsKey("TutorialData"))) {
                ThrowError -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage "Tutorial $Name does not have any tutorial data" `
                            -ErrorId "NoTutorialData" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData `
                            -ExceptionObject "$Name"
            }


            if (-not $script:resumeTutorial) {
                $xmlFolder = [System.IO.Path]::GetDirectoryName($script:xmlPath)

                if (-not (Test-Path $xmlFolder)) {
                    $xmlDir = mkdir $xmlFolder
                }

                if (-not (Test-Path $script:xmlPath)) {
                    # if the xml does not exist we have to create it
                    $xml = [xml] $script:xmlTutorial
                }
                else {            
                    $xml = [xml] (Get-Content $script:xmlPath)
                    $tutorialBlock = Update-TutorialNode $script:DataPath $Block
                }

                # if null then it does not exist so we have to create it
                if ($tutorialBlock -eq $null) {
                    $tutorialNode = $xml.CreateElement("Tutorial")
                    [void]$tutorialNode.SetAttribute("Name", $script:DataPath)
                    [void]$tutorialNode.SetAttribute("Block", $Block)
                    [void]$xml.SelectSingleNode("//LocalTutorialData").AppendChild($tutorialNode)
                    [void]$xml.Save($script:xmlPath)
                }
            }

            $global:TutorialBlocks = $tutorialDict["TutorialData"]

            $RequiredCommands = @("Get-Command",
                                "Get-FormatData",
                                "Out-Default",
                                "Select-Object",
                                "Measure-Object",
                                "prompt",
                                "TabExpansion2",
                                "PSConsoleHostReadLine",
                                "Get-History",
                                "Get-Help",
                                "ForEach-Object",
                                "Where-Object",
                                "Out-String",
                                "Format-List",
                                "Format-Table",
                                "Format-Wide",
                                "Format-Custom"
                                )  

            if ($tutorialDict.ContainsKey("TutorialCommands")) {
                $RequiredCommands += $tutorialDict["TutorialCommands"]
            }          

            $Global:OldApplications = [System.Collections.ArrayList]::new($ExecutionContext.SessionState.Applications)
            $Global:OldScripts = [System.Collections.ArrayList]::new($ExecutionContext.SessionState.Scripts)

            $Global:AllCommandsBeforeTutorial = Get-Command -CommandType Cmdlet,Alias,Function

            # Don't display commands that are not from tutorialdemo and commands that are not from the module
            $Global:AllCommandsBeforeTutorial `
                | Where-Object {$RequiredCommands -notcontains $_.Name -and $_.ModuleName -ne "PowerShellTutorial" -and $_.ModuleName -ne $module.Name} `
                | ForEach-Object {$_.Visibility = "Private"}

            $global:TutorialAttempts = -1
        }
        catch
        {
            CleanUpTutorial
            throw
        }

    }
    Process
    {

        Write-Host -ForegroundColor Cyan "Welcome to $Name tutorial`n"
        Write-Host -ForegroundColor Cyan "Type Stop-Tutorial anytime to quit the tutorial. Your progress will be saved`n"
        if ($global:TutorialBlocks -is [hashtable]) {
            $global:TutorialBlocks = ,$global:TutorialBlocks
        }

        $global:TutorialIndex = $Block-1

        # Account for the start-tutorial
        $Global:HistoryId = ((Get-History) | Select-Object -Last 1).Id + 2

        function global:prompt {
            . $function:TutorialMoveOn
            return $Global:TutorialPrompt
        }
    }
    End
    {
    }
}

function Write-PSError {
    if ($error.Count -gt 0) {
        $Global:OutputErrorToPipeLine = $true
        foreach ($err in $error) {
            Write-Error $err
        }
        
        $error.Clear()
        $Global:OutputErrorToPipeLine = $false
    }
}
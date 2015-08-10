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
        # this will be mocked out if it is provided.
        # otherwise, the output will be from running the first answers command
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

function Stop-Tutorial {
    $tutorialNode = Update-TutorialNode $Name $i
    CleanUpTutorial
    return
}

function CleanUpTutorial {
    # clean up the prompt
    Set-Content Function:\prompt $Global:OldPrompt -ErrorAction SilentlyContinue

    # make all commands visible again
    if ($Global:AllCommandsBeforeTutorial -ne $null) {
        $Global:AllCommandsBeforeTutorial | ForEach-Object {$_.Visibility = "Public"}
    }

    # Return the sessionstate to original setting
    $ExecutionContext.SessionState.Applications.AddRange($Global:OldApplications)
    $ExecutionContext.SessionState.Scripts.AddRange($Global:OldScripts)

    # Remove the proxy functions
    Remove-Item Function:\Out-Default -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-List -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-Table -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-Wide -Force -ErrorAction SilentlyContinue
    Remove-Item Function:\Format-Custom -Force -ErrorAction SilentlyContinue

    # Remove variables
    Remove-Variable $Global:OldPrompt -ErrorAction SilentlyContinue
    Remove-Variable $Global:LastOutput -ErrorAction SilentlyContinue
    Remove-Variable $Global:TutorialAttempts -ErrorAction SilentlyContinue
    Remove-Variable $Global:TutorialAlmostCorrect -ErrorAction SilentlyContinue
    Remove-Variable $Global:TutorialIndex -ErrorAction SilentlyContinue
    Remove-Variable $Global:TutorialHint -ErrorAction SilentlyContinue
    Remove-Variable $Global:ResultFromAnswer -ErrorAction SilentlyContinue
    Remove-Variable $Global:TutorialBlocks -ErrorAction SilentlyContinue
    Remove-Variable $Global:OutputErrorToPipeLine -ErrorAction SilentlyContinue
    Remove-Variable $Global:Formatted -ErrorAction SilentlyContinue
    Remove-Variable $Global:TutorialPrompt -ErrorAction SilentlyContinue
    Remove-Variable $Global:OldApplications -ErrorAction SilentlyContinue
    Remove-Variable $Global:OldScripts -ErrorAction SilentlyContinue
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
            Write-Host -ForegroundColor Cyan "$($newline)Write your instruction here. Input a new line to move on to answers"
            $instruction = Get-TutorialPromptOrAnswer "Instruction> "        

            if ($instruction.IndexOf("`n") -gt 0) {
                $instruction = "@`"$newline$($instruction.Trim())$newline`"@"
            } else {
                $instruction = "`"$instruction`""
            }

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

            Write-Host -ForegroundColor Cyan "$($newline)There are two parts of a hint: trigger and the hint itself.$newline"`
            "The trigger can be a number, which will correspond to the number of times a user will have to enter the response incorrectly for the hint to appear.$newline"`
            "The trigger can also be a string, which will correspond to the incorrect input that a user will have to enter for the hint to disappear.$newline"`
            "The hint itself correspond to the output.$newline"`
            "Input a new line to move on to output"

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

            $tutorialBlock = "`t,@{$newline"
            $tutorialBlock += "$indentation`"instruction`" = $instruction"
            $tutorialBlock += $newline

            if (-not [string]::IsNullOrWhiteSpace($hintsOutput)) {
                $tutorialBlock += "$indentation`"hints`" = $hintsOutput"
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

    ise "$tutorialFolder\$Name.TutorialData.psd1"

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
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
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
        $TutorialCommands
    )

    Begin
    {
        $myDocuments = [System.Environment]::GetFolderPath("mydocuments");
        $moduleFolder = "$myDocuments\WindowsPowerShell\Modules"
        if ([System.IO.Directory]::Exists("$moduleFolder\$Name")) {
            ThrowError -ExceptionName "System.ArgumentException" `
                        -ExceptionMessage "Directory $Name already exists" `
                        -ErrorId "DirectoryExists" `
                        -CallerPSCmdlet $PSCmdlet `
                        -ErrorCategory InvalidArgument `
                        -ExceptionObject "$moduleFolder\$Name"
        }

        $directory = mkdir $moduleFolder\$Name
        $moduleManifestCommand = Get-Command New-ModuleManifest
        if ($moduleManifestCommand.Parameters.ContainsKey("Tags")) {
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
   Short description
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
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
        if (-not (Test-Path $xmlPath)) {
            Start-Tutorial $Name
        }
        else {
            $tutorialNode = Update-TutorialNode $Name

            if ($tutorialNode -ne $null -and $tutorialNode.Block -ne $null)
            {
                $script:resumeTutorial = $true
                Start-Tutorial $Name -Block $tutorialNode.Block
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
function global:StartTutorialBlock {
    $Global:TutorialAttempts = 0
    $Global:TutorialIndex += 1
    $i = $Global:TutorialIndex

    # no more block so clean up
    if ($i -ge $Global:TutorialBlocks.Count) {
        CleanUpTutorial
        return
    }

    $Global:TutorialPrompt = "[$i] PSTutorial> "

    $instruction = $Global:TutorialBlocks[$i]["instruction"]
    [string[]] $acceptableResponses = $Global:TutorialBlocks[$i]["answers"]
    $Global:TutorialHint = ""
    $Global:TutorialAlmostCorrect = ""

    $Global:ResultFromAnswer = ""

    

    if ($acceptableResponses -ne $null -and $acceptableResponses.Count -gt 0) {
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
function global:TutorialMoveOn {
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

    $result = $Global:LastOutput | Out-String     
    [string]$expectedOutput = $Global:TutorialBlocks[$i]["output"]    
                
    #$result = Invoke-Expression $response | Out-String

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

<#
.Synopsis
   Start a tutorial session
.DESCRIPTION
   Long description
.EXAMPLE
   Example of how to use this cmdlet
.EXAMPLE
   Another example of how to use this cmdlet
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

        if (-not $script:resumeTutorial) {
            $xmlFolder = [System.IO.Path]::GetDirectoryName($script:xmlPath)

            if (-not (Test-Path $xmlFolder)) {
                $xmlDir = mkdir $xmlFolder
            }

            if (-not (Test-Path $script:xmlPath)) {
                # if the xml 
                $xml = [xml] $script:xmlTutorial
            }
            else {            
                $xml = [xml] (Get-Content $xmlPath)
            }

            $tutorialNode = $xml.CreateElement("Tutorial")
            [void]$tutorialNode.SetAttribute("Name", $Name)
            [void]$tutorialNode.SetAttribute("Block", $Block)
            [void]$xml.SelectSingleNode("//LocalTutorialData").AppendChild($tutorialNode)
            [void]$xml.Save($xmlPath)
        }

        $Global:OldPrompt = Get-Content Function:\prompt

        try {
            Import-Module $Name -Global
            $module = (Get-Module $Name)
            $tutorialDict = Import-LocalizedData -BaseDirectory (Join-Path (Split-Path $module.Path) "Tutorial") -FileName "$Name.TutorialData.psd1"

            if ($null -eq $tutorialDict -or (-not $tutorialDict.ContainsKey("TutorialData"))) {
                ThrowError -ExceptionName "System.ArgumentException" `
                            -ExceptionMessage "Tutorial $Name does not have any tutorial data" `
                            -ErrorId "NoTutorialData" `
                            -CallerPSCmdlet $PSCmdlet `
                            -ErrorCategory InvalidData `
                            -ExceptionObject "$Name"
            }

            $global:TutorialBlocks = $tutorialDict["TutorialData"]

            $RequiredCommands = @("Get-Command",
                                "Get-FormatData",
                                "Out-Default",
                                "Select-Object",
                                "Measure-Object",
                                "prompt",
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
                | Where-Object {$RequiredCommands -notcontains $_.Name -and $_.ModuleName -ne "TutorialDemo" -and $_.ModuleName -ne $module.Name} `
                | ForEach-Object {$_.Visibility = "Private"}

            $global:TutorialAttempts = -1
        }
        catch
        {
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

function Write-PSError([powershell]$ps) {
    if ($error.Count -gt 0) {
        $Global:OutputErrorToPipeLine = $true
        foreach ($err in $error) {
            Write-Error $err
        }
        
        $error.Clear()
        $Global:OutputErrorToPipeLine = $false
    }
}
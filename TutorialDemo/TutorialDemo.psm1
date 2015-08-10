$script:xmlTutorial = @"
<?xml version="1.0" encoding="utf-8"?>
<LocalTutorialData>
</LocalTutorialData>
"@

$script:simpleTutorialData = @"
@(
    @{
        "instruction" = "provide your instruction here"
        "answers" = @(
            "Get-CorrectAnswer1"
            "Get-CorrectAnswer2"
        );
        "hints" = @{
            # The key can be numbers or string.
            # If it is a number, the hint will be printed out after that many attempts.
            # If it is a string, the hint will be printed out if the users put in 
            # that string as their answers.
            1 = "first hint"
            2 = "second hint"
        }
        # this will be mocked out if it is provided.
        # otherwise, the output will be from running the first answers command
        "output"="This is what will be printed for the user"
    },
    @{
        "instruction" = "second step in tutorial";
        "answers" = @(
            "Get-AnotherCorrectAnswer"
        );
        "hints" = @{
            "Get-AnotherAnswer" = "Almost correct. Check your noun"
        }
        "output"="This is what I want the user to see"
    }
)
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
        Write-Host "$output`n"
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


function CreateTutorialInModule([string]$modulePath, [System.Management.Automation.PSCmdlet]$callerPScmdlet) {
    $tutorialData = $script:simpleTutorialData

    if ($Interactive) {
        $newline = [System.Environment]::NewLine

        $fileOutput = "@($newline"

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
    
            $answers = $answers.Split("`n")

            $answersOutput = "@($newline"
            foreach ($answer in $answers) {
                $answersOutput += "$indentation`t`"$($answer.Trim())`"$newline"
            }
            $answersOutput += "$indentation)$newline"

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

            $tutorialBlock += "$indentation`"answers`" = $answersOutput"
            $tutorialBlock += $newline

            $tutorialBlock += "$indentation`"output`" = $outputsOutput"
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

        $fileOutput += ")"
        $tutorialData = $fileOutput

    }

    $locale = Join-Path $modulePath (Get-WinSystemLocale).Name

    if (-not [System.IO.Directory]::Exists($locale)) {
        mkdir $locale -ErrorAction Stop
    }

    [System.IO.File]::WriteAllText("$locale\$Name.TutorialData.psd1", $tutorialData)

    ise "$locale\$Name.TutorialData.psd1"

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
        $Interactive
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
        CreateTutorialInModule $modulePath $PSCmdlet
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
        [string]
        $Name,
        # if this is true then user will create the tutorial from the terminal
        [switch]
        $Interactive
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
        CreateTutorialInModule $directory.FullName $PSCmdlet
    }
    End
    {
    }
}

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
        [string[]] $paths = $env:PSModulePath.Split(';')

        foreach ($path in $paths) {
            if (Test-Path $path) {
                $modules = @()
                $children = Get-ChildItem $path;
                if ($children -ne $null -and $children.Length -gt 0) {
                    foreach ($child in $children) {
                        $manifest = Join-Path $child.FullName "$($child.Name).psd1"
                        if (Test-Path $manifest) {
                            $contents = Get-Content -Raw $manifest
                            # contains the key word powershell tutorial. now we call test-modulemanifest
                            if ($contents.IndexOf("PowerShellTutorial") -ge 0) {
                                $moduleInfo = Test-ModuleManifest $manifest
                                if ($moduleInfo.Tags -contains "PowerShellTutorial") {
                                    $modules += $moduleInfo
                                }
                            }
                        }
                    }
                }

                if ($modules.Count -gt 0) {
                    $modules | Format-Table -Property ModuleType, Name -AutoSize
                }
            }
        }
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
    $Global:TutorialPrompt = "[$i] PSTutorial> "

    $instruction = $Global:TutorialBlocks[$i]["instruction"]
    [string[]] $acceptableResponses = $Global:TutorialBlocks[$i]["answers"]
    $Global:TutorialHint = ""
    $Global:TutorialAlmostCorrect = ""

    $Global:ResultFromAnswer = ""

    if ($acceptableResponses -ne $null -and $acceptableResponses.Count -gt 0) {
        $Global:ResultFromAnswer = Invoke-Expression $acceptableResponses[0] | Out-String
        $Error.Clear()
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
        $Global:TutorialAttempts += 1;
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

        try {
            "Importing Module"
            Import-Module $Name -Verbose
            $module = (Get-Module $Name)
            $global:TutorialBlocks = Import-LocalizedData -BaseDirectory (Split-Path $module.Path) -FileName "$Name.TutorialData.psd1"

            <#$RequiredCommands = @("Get-Command",
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
                                         "Format-Custom",
                                         "Get-Module"
                                         )            

            #$ExecutionContext.SessionState.Applications.Clear()
            #$ExecutionContext.SessionState.Scripts.Clear()            

            # Don't display commands that are not from tutorialdemo and commands that are not from the module
            $global:commands = Get-Command -CommandType Cmdlet, alias, function | Where-Object {$RequiredCommands -notcontains $_.Name -and $_.ModuleName -ne "TutorialDemo"}
            $global:commands | ForEach-Object {$_.Visibility="Private"}

            $global:commands | Where-Object {$_.ModuleName -eq $module.Name} | ForEach-Object {$_.Visibility = "Public"}
            #>

            $Global:TutorialAttempts = -1
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

        <#for ($i = $Block; $i -lt $blocks.Length; $i += 1) {
            $prompt = "[$i] PSTutorial> "
            $instruction = $blocks[$i]["instruction"]
            [hashtable] $hints = $blocks[$i]["hints"]
            [string[]] $acceptableResponses = $blocks[$i]["answers"]

            $resultFromAnswer = ""

            if ($acceptableResponses -ne $null -and $acceptableResponses.Count -gt 0) {
                $resultFromAnswer = Invoke-Expression $acceptableResponses[0] | Out-String
                $Error.Clear()
            }
        
            $response = ""
            $attempts = 0
            $almostCorrect = ""
            $hint = ""

            while ($true)
            {
                if ($hints -ne $null -and $hints.ContainsKey($attempts)) {
                    $hint = $hints[$attempts]
                }
    
                if (-not [string]::IsNullOrWhiteSpace($almostCorrect)) {
                    Write-Host -ForegroundColor Green "Hints: $almostCorrect`n"
                    $almostCorrect = ""
                }
                elseif (-not [string]::IsNullOrWhiteSpace($hint)) {
                    Write-Host -ForegroundColor Green "Hints: $hint`n"
                }
    
                Write-Host -ForegroundColor Cyan "$instruction `n"
                Write-Host -ForegroundColor Yellow -NoNewline $prompt
                [string]$response = Get-Response (Read-Host)

                if ($response -contains "$") {
                    $response = $response -replace "$", "`$"
                }

                Write-Host

                if ([string]::IsNullOrWhiteSpace($response)) {
                    $attempts += 1;
                    continue;
                }
                
                switch ($response.ToLower()) {
                    "stop-tutorial" {
                        $tutorialNode = Update-TutorialNode $Name $i
                        return
                    }
                } 
                
                [string]$expectedOutput = $blocks[$i]["output"]    
                
                $result = Invoke-Expression $response | Out-String

                # we match output result if no answers are supplied
                if ($null -eq $acceptableResponses) {
                    # if output is null, then nothing to do
                    if ([string]::IsNullOrWhiteSpace($expectedOutput)) {
                        # don't report error here
                        $Error.Clear()
                        break
                    }
                    
                    # output is not null, we match
                    if (($expectedOutput -replace '\s+',' ').Trim() -ieq ($result -replace '\s+',' ').Trim()) {
                        Write-PSError
                        Write-Answer $expectedOutput
                        break
                    }
                }

                #here the acceptable response is not null
                if ($response -iin $acceptableResponses) {
                    # acceptable response
                    if (-not [string]::IsNullOrWhiteSpace($expectedOutput)) {
                        # Mocking so clear possible error
                        $error.Clear()
                        Write-Answer $expectedOutput
                    }
                    else {                        
                        Write-PSError
                        Write-Answer $result
                    }

                    break
                }

                # here, response is not in acceptableResponses
                Write-PSError

                # we try to match user response with the result from one of the acceptable response
                if (-not [string]::IsNullOrWhiteSpace($result)) {
                    if (($result -replace '\s+',' ').Trim() -ieq ($resultFromAnswer -replace '\s+',' ').Trim()) {
                        Write-Answer $resultFromAnswer
                        break
                    }

                    # write the result user got from terminal
                    Write-Host $result
                }

                # incorrect answer
                Write-Host -ForegroundColor Red "$response is not correct`n"            

                if ($hints -ne $null -and $hints.ContainsKey($response)) {
                    $almostCorrect = $hints[$response]
                    continue
                }

                $attempts += 1
            }
        }
        #>
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
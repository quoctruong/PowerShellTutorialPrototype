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

function Write-Answer ([string]$answer)
{
    if ($answer -ne $null) {
        Write-Host -ForegroundColor Green "Correct!`n"

        Write-Host "$answer`n"
    }

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
    }
    Process
    {
        $myDocuments = [System.Environment]::GetFolderPath("mydocuments");
        $moduleFolder = "$myDocuments\WindowsPowerShell\Modules"
        $directory = mkdir $moduleFolder\$Name
        $moduleManifestCommand = Get-Command New-ModuleManifest
        if ($moduleManifestCommand.Parameters.ContainsKey("Tags")) {
            New-ModuleManifest "$($directory.FullName)\$Name.psd1" -Tags "PowerShellTutorial"
        }
        else {
            New-ModuleManifest "$($directory.FullName)\$Name.psd1" 
        }

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

                Write-Host -ForegroundColor Cyan "$($newline)Write your output here. If you want to pipe the output from a command, type Run-Command: <Your Command>. Input a new line to move on to the next tutorial block"

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
            $global:fileOutput = $fileOutput

        }

        [System.IO.File]::WriteAllText("$($directory.FullName)\$Name.data.psd1", $tutorialData)

        ise "$($directory.FullName)\$Name.data.psd1"
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
    }
    Process
    {
        try {
            Import-Module $Name
            $module = (Get-Module $Name)
            $contents = Get-Content -Path (Join-Path (Split-Path $module.Path) "$Name.data.psd1") -Raw
            $scriptblock = [scriptblock]::Create($contents)
            [string[]] $allowedCommands = @()
            $scriptblock.CheckRestrictedLanguage($allowedCommands, $null, $true)
            $blocks = $scriptblock.InvokeReturnAsIs()
        }
        catch
        {
            throw
        }

        Write-Host -ForegroundColor Cyan "Welcome to $Name tutorial`n"
        Write-Host -ForegroundColor Cyan "Type Stop-Tutorial anytime to quit the tutorial. Your progress will be saved`n"
        if ($blocks -is [hashtable]) {
            $blocks = ,$blocks
        }

        for ($i = $Block; $i -lt $blocks.Length; $i += 1) {
            $prompt = "[$i] PSTutorial> "
            $instruction = $blocks[$i]["instruction"]
            [hashtable] $hints = $blocks[$i]["hints"]
            [string[]] $acceptableResponses = $blocks[$i]["answers"]
        
            $response = ""
            $attempts = 0
            $almostCorrect = ""
            $hint = ""

            while ($true)
            {
                if ($hints -ne $null -and $hints.ContainsKey($attempts)) {
                    $hint = $hints[$attempts]
                }
    
                if ($almostCorrect -ne "") {
                    Write-Host -ForegroundColor Green "Hints: $almostCorrect`n"
                    $almostCorrect = ""
                }
                elseif ($hint -ne "") {
                    Write-Host -ForegroundColor Green "Hints: $hint`n"
                }
    
                Write-Host -ForegroundColor Cyan "$instruction `n"
                Write-Host -ForegroundColor Yellow -NoNewline $prompt
                [string]$response = Get-Response (Read-Host)

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

                if ($response -inotin $acceptableResponses) {
                    Write-Host -ForegroundColor Red "$response is not correct`n"            

                    if ($hints -ne $null -and $hints.ContainsKey($response)) {
                        $almostCorrect = $hints[$response]
                        continue
                    }
                }
                else {
                    Write-Answer $blocks[$i]["output"]
                    break;
                }

                $attempts += 1
            }
   
        }
    }
    End
    {
    }
}
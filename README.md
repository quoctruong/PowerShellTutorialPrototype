# Installation

Download the prototype (using Download Zip button).

Right click, select Properties. Then click on Unblock.

Unzip the tutorial and place the TutorialDemo folder in C:\Program Files\WindowsPowerShell\Modules

# Start a Tutorial

A sample tutorial is included in the zip file (the name of the tutorial is Get-CommandTutorial).
Place the Get-CommandTutorial folder in C:\Program Files\WindowsPowerShell\Modules.

Now open PowerShell and simply run Start-Tutorial <TutorialName> to use the tutorial.
In the case of Get-CommandTutorial, the command would be `Start-Tutorial Get-CommandTutorial`.

The structure of a tutorial is `<ModuleWithTutorialName>/Tutorial/<TutorialName>.TutorialData.psd1` where the TutorialName
should be the same as ModuleName.

Using this structure, you can also start a tutorial by supplying the path to either:

1. The <TutorialName>.TutorialData.psd1 file directly

2. The path to the "Tutorial" folder

3. The path to the Module folder

If you don't want to use directory, you can simply supply the name of the module itself (as long as the module is placed
in a module location specified by $PSModulePath)

Anytime you want to stop the tutorial with the intent of resuming it later, simply run `Stop-Tutorial`.

# Resume a Tutorial

To resume a tutorial, run `Restore-Tutorial <TutorialName>`.
For example, `Restore-Tutorial Get-CommandTutorial`

# Show tutorials on your machine

To show the available tutorials, run `Get-Tutorial`

# Create a new tutorial

To create a new tutorial, run `New-Tutorial <TutorialName>`.

This will create a folder with the structure `<TutorialName>\Tutorial\<TutorialName>.TutorialData.psd1`
in the current directory.

If you want to place this folder elsewhere, simply add `-Destination <Location>`.

For example, if I want to place it in my module directory, I will run:

`New-Tutorial <TutorialName> -Destination "C:\Program Files\WindowsPowerShell\Modules"`

To add a tutorial to an existing module, run `Add-Tutorial <ModuleName>`. This will create a Tutorial folder with
the structure `Tutorial\<ModuleName>.TutorialData.psd1` under the directory of the module.

You can edit a tutorial by editing the `<TutorialName>.TutorialData.psd1` that is created.

The data file contains a hashtable with 2 keys: TutorialCommands and TutorialData.

The value of TutorialCommands is an array of command names that are allowed in the tutorial. You can populate this array
by providing a `-Commands <List of commands>` parameters to either `New-Tutorial` or `Add-Tutorial` cmdlet.

The value of TutorialData is an array of hashtables, each of which corresponds to a step in the tutorial.
There are 5 possible keys in the hashtable:

1. Instruction: The instruction of this step

2. Verification: Contains the command that can be used to verify the answer. The command should return boolean value.
If this field exists, then answers and output field should not exist.

2. Answers: An array of acceptable responses

3. Hints: A hashtable. The key can be either number or string:
  1. If the key is a number, then the corresponding value will be displayed if the user fails to provide
the correct answer within that number of attempt.
  2. If the key is a string, then the corresponding value will be displayed if the user enters that string.

4. Output: The output provided by the tutorial when the user enters the correct answer.

If a block has no verification, no answers and no output entry, then the user is always correct.

If a block has verification entry, then that command will be run everytime the user output the answer to check
whether the answer is correct. Otherwise, we will use answers and output entry to determine the answer.

If a block has answers but not output entry, then the result of running the first answer will be compared to the
result of the command that the user provides to determine whether the user is correct.

If a block has output but not answers entry, then the value of the output entry will be compared to the result of running the command that the user provides to determine whether the user is correct.

If a block has both answers and output entry, then we will check to see whether the command that the user provides fall into the list of answers to determine whether the user is correct. Any error resulted from running the user's command and the first answer will be suppressed (so basically this can be thought of as a form of mocking).

You can directly edit the data file to create as many steps as you want to.

You can also run `New-Tutorial <TutorialName> -Interactive` to create the data on the terminal.

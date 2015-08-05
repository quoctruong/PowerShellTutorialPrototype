# Installation

Download the prototype (using Download Zip button).

Right click, select Properties. Then click on Unblock.

Unzip the tutorial and place the TutorialDemo folder in C:\Program Files\WindowsPowerShell\Modules

# Start a Tutorial

A sample tutorial is included in the zip file (the name of the tutorial is Get-CommandTutorial).
Place the Get-CommandTutorial folder in C:\Program Files\WindowsPowerShell\Modules.

Now open PowerShell and simply run Start-Tutorial <TutorialName> to use the tutorial.
In the case of Get-CommandTutorial, the command would be `Start-Tutorial Get-CommandTutorial`.

Anytime you want to stop the tutorial with the intent of resuming it later, simply run `Stop-Tutorial`.

# Resume a Tutorial

To resume a tutorial, run `Restore-Tutorial <TutorialName>`.
For example, `Restore-Tutorial Get-CommandTutorial`

# Show tutorials on your machine

To show the available tutorials, run `Get-Tutorial`

# Create a new tutorial

To create a new tutorial, run `New-Tutorial <TutorialName>`

To add a tutorial to an existing module, run `Add-Tutorial <ModuleName>`

After that, a data file that contains the Tutorial information will be opened in the ISE.

The data file contains an array of hashtable where it hashtable corresponds to a step in the tutorial.
There are 4 possible keys in the hashtable:

1. Instruction: The instruction of this step

2. Answers: An array of acceptable response

3. Hints: A hashtable. The key can be either number or string:
  1. If the key is a number, then the corresponding value will be displayed if the user fails to provide
the correct answer within that number of attempt.
  2. If the key is a string, then the corresponding value will be displayed if the user enters that string.

4. Output: The output provided by the tutorial when the user enters the correct answer.

You can directly edit the data file to create as many steps as you want to.

You can also run `New-Tutorial <TutorialName> -Interactive` to create the data on the terminal.

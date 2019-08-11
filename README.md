# getChromeExtensions
Get all of currently installed chrome extensions from all users and profiles.
Available for MacOS, Linux and Win10!

On MacOS/Linux, open terminal and run:
  chmod u+x getChromeExtensions.py
  ./getChromeExtensions.py
In order to get information from all users, it should run with "sudo":
  sudo ./getChromeExtensions.py
  
On Win10, open powershell and run:
  ./getChromeExtensions.ps1
In case you get an error regarding "Execution Policy", just run:
  powershell.exe -executionpolicy bypass -file FULLFILEPATHHERE
For example:
  powershell.exe -executionpolicy bypass -file "c:\cyberiko\getChromeExtensions.ps1"
In order to get information from all users, it should run with admin privileges (Run As Administrator) 
  



# getChromeExtensions 
  Get all of currently installed chrome extensions from all users and profiles.
  </br>
  In addition, it will extract all of the URLs and IPs which are inside the js/json/txt/html/md files of the extensions.
  </br>
  Available for MacOS, Linux and Win10!
</br>
 <b> --> On Win10 it will also verify the URLs against urlhaus db!</b>


## On MacOS/Linux, open terminal and run:
   
  	chmod u+x getChromeExtensions.py
  	./getChromeExtensions.py [checkExtensions]
   
    
In order to get information from all users, it should run with "sudo":</br>
  
  	sudo ./getChromeExtensions.py [checkExtensions]
   
    
## Please note that "requests" library is required
 
## On Win10, open powershell and run:</b>
    
    ./getChromeExtensions.ps1
    Get-ChromeExtensions [-checkURLs]
    
In case you get an error regarding "Execution Policy", just run:
    
    powershell.exe -executionpolicy bypass -file FULLFILEPATHHERE
    
For example:
    
    powershell.exe -executionpolicy bypass -file "c:\cyberiko\getChromeExtensions.ps1"
    
In order to get information from all users, it should run with admin privileges (Run As Administrator) 
  


## By Tomer Haimof

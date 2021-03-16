# IPU-Installer

IPU Installer is an application developed by Johan Schrewelius to help with feature updates for Windows 10 where a task sequence might not be suitable. It also helps minimize the down-time for your end users since they can use the computer as the upgrade runs in the background.\
This script is meant to make it easier to implement the solution, you still have to read the documentation though!\
Don't skip that please!

## What does the script do?
Download the source files from https://onevinn.schrewelius.it/Files/IPUInstaller/IPUInstaller.zip  
Imports IPU Installer app and Deployment Scheduler app to ConfigMgr.\
Deploys IPU Installer app and Deployment Scheduler app to the correct collections.\
Creates all the collections including the correct rules.\
Creates a new Device Collection folder that will house the newly created collections.\
Creates a new Client Policy with a more frequent schedule for Hardware Inventory. Sets PS executionpolicy to ByPass\
Deploys the Client Policy to the newly created collections to be used with IPU Installer.

## Current limitations:
The script will not update or import any .mof files, you will currently have to this manually.\
If you run the script before you edit and import the .mof files it will tell you that your environment doesn't meet the requirements yet.  
You will still get the apps but the collections won't be created. Please fix the hardware inventory classes according to the documentation and run the script again to successfully complete the installation.

## Planned features:
Maybe some sort of handling of the .mof files? :)

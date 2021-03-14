# IPU-Installer

These PS-scripts will automate the installation and configuration of IPU-Installer. Download the scripts and add them to the root of 'IPUInstaller'-folder
that you will find here: https://onevinn.schrewelius.it/index.html

## What does the script do?
Creates all the collections including the correct rules.\
Creates a new Device Collection folder that will house the newly created collections.\
Creates a new Client Policy with the "correct" (recommended) schedule for Hardware Inventory\
Deploys the Client Policy to the newly created collections to be used with IPU Installer.

## Current limitations:
The script will not update or import any .mof files, you will currently have to this manually.\
The script will not create either of the applications for you, that is the IPUInstaller.exe app and the DeploymentScheduler app.

## Planned features:
I'm hoping to fully automate the entire installation but I have no ETA on this. Not even sure if there's even a demand :D\
Built it mainly for myself and my co-workers that will be interested in using this awesome tool from Johan.
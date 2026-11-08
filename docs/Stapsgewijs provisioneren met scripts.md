vagrant winrm client -s powershell -c "Get-WindowsCapability -Online -Name Rsat.* | ? State -eq Installed | select Name"

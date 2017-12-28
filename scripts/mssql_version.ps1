$ver = Invoke-Sqlcmd -Query "SELECT @@VERSION;" -QueryTimeout 3

write-host $ver.Column1
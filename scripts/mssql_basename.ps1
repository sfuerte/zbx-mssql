#функция для приведения к формату который понимает zabbix / the function is to bring to the format understands zabbix
function convertto-encoding ([string]$from, [string]$to){
    begin{
        $encfrom = [system.text.encoding]::getencoding($from)
        $encto = [system.text.encoding]::getencoding($to)
    }
    process{
        $bytes = $encto.getbytes($_)
        $bytes = [system.text.encoding]::convert($encfrom, $encto, $bytes)
        $encto.getstring($bytes)
    }
}

#Get Installed SQL Instances.
#Tested on MS SQL Server 2014 and 2016.
$SQLDataSet = New-Object System.Data.DataSet
$SQLInstances = Get-Itemproperty -path 'HKLM:\software\microsoft\Microsoft SQL Server' | Select-Object -expandproperty installedinstances

#Create list for JSON array.
$jsonlist = "{`n"
$jsonlist += " `"data`":[`n"

$idxI = 1

#Loop through each Instance and create a database connection.
foreach ($i in $SQLInstances)
{
    #Задаем переменные для подключение к MSSQL. $uid и $pwd нужны для проверки подлинности windows / We define the variables for connecting to MS SQL. $uid и $pwd need to authenticate windows
    #This will append the Instane name to Hostname.
    $SQLServer = $(hostname.exe) + "\$i"
    #$uid = "Login" 
    #$pwd = "Password"
    
    #Создаем подключение к MSSQL / Create a connection to MSSQL

    #Если проверка подлинности windows / If windows authentication
    #$connectionString = "Server = $SQLServer; User ID = $uid; Password = $pwd;"

    #Если Интегрированная проверка подлинности / If integrated authentication
    $connectionString = "Server = $SQLServer; Integrated Security = True;"

    $connection = New-Object System.Data.SqlClient.SqlConnection
    $connection.ConnectionString = $connectionString
    $connection.Open()

    #Создаем запрос непосредственно к MSSQL / Create a request directly to MSSQL
    $SqlCmd = New-Object System.Data.SqlClient.SqlCommand  
    $SqlCmd.CommandText = "SELECT name FROM  sysdatabases"
    $SqlCmd.Connection = $Connection
    $SqlAdapter = New-Object System.Data.SqlClient.SqlDataAdapter
    $SqlAdapter.SelectCommand = $SqlCmd
    $DataSet = New-Object System.Data.DataSet
    $SqlAdapter.Fill($DataSet) > $null
    $Connection.Close()

    #Получили список баз. Записываем в переменную. / We get a list of databases. Write to the variable.
    $basename = $DataSet.Tables[0]


    #Парсим и передаем список баз в zabbix. В последней строке нужно вывести имя бызы без запятой в конце. / Parse and pass a list of databases in zabbix. In the last line need to display the database name without a comma at the end.
    $idx = 1

    #Loop through each Database from each Instance.
    foreach ($name in $basename)
    {       
       $jsonlist+= "{ `"{#DBNAME}`" : `"" + $name.name + "`", `"{#SQLINSTANCE}`" : `"MSSQL$" + $i + "`" }" | convertto-encoding "cp866" "utf-8"
       
       #If not the last line, add comma.
       #Had to add extra loop per instance so that it doesn't omit after each Instance block.
        if ($idxI -ge $SQLInstances.Count)
        {        
            if ($idx -ge $basename.Rows.Count)
            {         
                $jsonlist+= ""
            }

            else
            {
                $jsonlist+= ",`n"
            }
        }        
        else{
             $jsonlist+= ",`n"
        }
        $idx++;
    }
    $idxI++;
}

$jsonlist += " ]`n"
$jsonlist += "}"

#Output array.
write-host $jsonlist

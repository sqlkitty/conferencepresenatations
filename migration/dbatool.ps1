$scred = Get-Credential sa
$dcred = Get-Credential miadmin
$params = @{
  Source = "your_sql_server_name"
  Destination = "copy_your_mi_name_from_azure,3342"
  SourceSqlCredential = $scred
  DestinationSqlCredential =$dcred
}     

Start-DbaMigration @params -Force -Exclude Databases -Verbose 



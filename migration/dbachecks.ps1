$Date = Get-Date -Format "yyyy-MM-dd"
  Invoke-DbcCheck -Show Fails -SqlInstance "dbopsmi.public.rand0m1234.database.windows.net,3342" -SqlCredential (Get-Credential yourmiadmin) `
  -ExcludeCheck Backup, HADR, Domain, LogShipping, AgentServiceAccount, IdentityUsage, FutureFileGrowth, FKCKTrusted, GuestUserConnect, `
  ValidDatabaseOwner, InvalidDatabaseOwner, InstanceConnection, SqlEngineServiceAccount, TempDbConfiguration, BackupPathAccess, DefaultFilePath, `
  DAC, MaxMemory, OrphanedFile, ServerNameMatch, MemoryDump, SupportedBuild, DefaultBackupCompression, ErrorLog, CrossDBOwnershipChaining, DefaultTrace, `
   OLEAutomationProceduresDisabled, RemoteAccessDisabled, SystemFull, UserFull, UserDiff, Userrog ` 
   -Passthru | Convert-DbcResult | Set-DbcFile -FilePath C:\windows\temp\ -FileName DbcCheck_$Date -FileType csv
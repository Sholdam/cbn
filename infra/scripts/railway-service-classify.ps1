param()

[pscustomobject]@{
    ActiveStorageService = $env:ACTIVE_STORAGE_SERVICE
    HasStorageBucket = -not [string]::IsNullOrWhiteSpace($env:STORAGE_BUCKET_NAME)
    HasStorageEndpoint = -not [string]::IsNullOrWhiteSpace($env:STORAGE_ENDPOINT)
    HasN8nEncryptionKey = -not [string]::IsNullOrWhiteSpace($env:N8N_ENCRYPTION_KEY)
    HasTelegramSession = -not [string]::IsNullOrWhiteSpace($env:TELEGRAM_SESSION)
} | Format-List

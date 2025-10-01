PS C:\WINDOWS\system32> # Comando básico para probar recomendaciones
>> $body = @{
>>     userPreferences = "Me gustan las películas de acción y ciencia ficción"
>>     ratedMovies = @()
>>     watchedMovies = @()
>> } | ConvertTo-Json
>>
>> try {
>>     $response = Invoke-WebRequest -Uri "https://randommoviev10-production.up.railway.app/api/recommendations" -Method POST -Headers @{"x-app-signature"="randomovie_2024_secure_signature"; "Content-Type"="application/json"} -Body $body -TimeoutSec 30
>>     Write-Host "Status: $($response.StatusCode)"
>>     Write-Host "Content: $($response.Content)"
>> } catch {
>>     Write-Host "Error: $($_.Exception.Message)"
>> }
Error: Error en el servidor remoto: (500) Error interno del servidor.
PS C:\WINDOWS\system32> # Comando detallado para diagnosticar
>> $body = @{
>>     userPreferences = "Me gustan las películas de terror y suspenso"
>>     ratedMovies = @(@{ title = "The Exorcist"; rating = 9; genre = "Horror" })
>>     watchedMovies = @(@{ title = "Saw"; genre = "Horror" })
>>     type = "preferences"
>> } | ConvertTo-Json -Depth 3
>>
>> Write-Host "Enviando solicitud a Groq..."
>> try {
>>     $response = Invoke-WebRequest -Uri "https://randommoviev10-production.up.railway.app/api/recommendations" -Method POST -Headers @{"x-app-signature"="randomovie_2024_secure_signature"; "Content-Type"="application/json"} -Body $body -TimeoutSec 30
>>     Write-Host "✅ Status: $($response.StatusCode)"
>>     Write-Host "📄 Response: $($response.Content)"
>> } catch {
>>     Write-Host "❌ Error: $($_.Exception.Message)"
>>     if ($_.Exception.Response) {
>>         Write-Host "Response Status: $($_.Exception.Response.StatusCode)"
>>         Write-Host "Response Content: $($_.Exception.Response.Content)"
>>     }
>> }
Enviando solicitud a Groq...
❌ Error: Error en el servidor remoto: (500) Error interno del servidor.
Response Status: InternalServerError
Response Content:
PS C:\WINDOWS\system32> # Comando simple para ver solo el error
>> try {
>>     $response = Invoke-WebRequest -Uri "https://randommoviev10-production.up.railway.app/api/recommendations" -Method POST -Headers @{"x-app-signature"="randomovie_2024_secure_signature"; "Content-Type"="application/json"} -Body '{"userPreferences":"test"}' -TimeoutSec 10
>> } catch {
>>     Write-Host "Error: $($_.Exception.Message)"
>> }
Error: Error en el servidor remoto: (500) Error interno del servidor.
PS C:\WINDOWS\system32>

# Script untuk menjalankan Flutter dengan env variables dari .env

# Baca .env file
$env_content = Get-Content ".env"
$env_vars = @{}

foreach ($line in $env_content) {
    if ($line -match '^\s*([^=]+)=(.*)$') {
        $key = $matches[1].Trim()
        $value = $matches[2].Trim()
        $env_vars[$key] = $value
    }
}

$supabaseUrl = $env_vars['SUPABASE_URL']
$supabaseAnonKey = $env_vars['SUPABASE_ANON_KEY']

Write-Host "🚀 Starting Flutter with Supabase configuration..." -ForegroundColor Green
Write-Host "URL: $supabaseUrl" -ForegroundColor Cyan

flutter run `
  --dart-define=SUPABASE_URL=$supabaseUrl `
  --dart-define=SUPABASE_ANON_KEY=$supabaseAnonKey

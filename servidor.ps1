# Servidor local del torneo (Coliseo Arena Gamer).
# Sirve las paginas de esta carpeta en http://localhost y deja que lean torneo.xlsx
# aunque Excel lo tenga abierto. Solo acepta conexiones de esta misma PC.
$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$root = [IO.Path]::GetFullPath($root).TrimEnd('\') + '\'
$types = @{
  '.html' = 'text/html; charset=utf-8'; '.xlsx' = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
  '.js' = 'text/javascript'; '.css' = 'text/css'; '.png' = 'image/png'; '.webp' = 'image/webp'; '.ico' = 'image/x-icon'
}
$listener = $null; $port = 0
foreach ($p in 8080..8090) {
  try {
    $l = New-Object System.Net.HttpListener
    $l.Prefixes.Add("http://localhost:$p/")
    $l.Start(); $listener = $l; $port = $p; break
  } catch { }
}
if (-not $listener) { Write-Host 'No pude abrir ningun puerto entre 8080 y 8090.'; Read-Host 'Enter para salir'; exit 1 }

$url = "http://localhost:$port/"
Write-Host ''
Write-Host '  COLISEO ARENA GAMER - Torneo CS2 Wingman' -ForegroundColor Magenta
Write-Host ''
Write-Host "  Control:            ${url}index.html"
Write-Host "  Proyector Tabla:    ${url}tabla.html"
Write-Host "  Proyector Playoffs: ${url}playoffs.html"
Write-Host ''
Write-Host '  Deja esta ventana abierta durante todo el torneo. Cerrala para apagar el servidor.' -ForegroundColor Yellow
Write-Host ''
Start-Process "${url}index.html"

while ($listener.IsListening) {
  $ctx = $listener.GetContext()
  $res = $ctx.Response
  try {
    $name = [Uri]::UnescapeDataString($ctx.Request.Url.AbsolutePath.TrimStart('/'))
    if ($name -eq '') { $name = 'index.html' }
    $full = [IO.Path]::GetFullPath((Join-Path $root $name))
    if (-not $full.StartsWith($root, [StringComparison]::OrdinalIgnoreCase) -or -not [IO.File]::Exists($full)) {
      $res.StatusCode = 404
    } else {
      # FileShare ReadWrite: permite leer aunque Excel tenga el archivo abierto
      $fs = [IO.File]::Open($full, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::ReadWrite)
      try { $ms = New-Object IO.MemoryStream; $fs.CopyTo($ms); $bytes = $ms.ToArray() } finally { $fs.Close() }
      $ext = [IO.Path]::GetExtension($full).ToLower()
      $ct = $types[$ext]; if (-not $ct) { $ct = 'application/octet-stream' }
      $res.ContentType = $ct
      $res.Headers.Add('Cache-Control', 'no-store')
      $res.Headers.Add('X-Guardado', [IO.File]::GetLastWriteTime($full).ToString('HH:mm:ss'))
      $res.ContentLength64 = $bytes.Length
      $res.OutputStream.Write($bytes, 0, $bytes.Length)
    }
  } catch {
    try { $res.StatusCode = 503 } catch { }
  } finally {
    try { $res.Close() } catch { }
  }
}

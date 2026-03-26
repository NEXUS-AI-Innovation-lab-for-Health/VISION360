Param()
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$vendor = Join-Path $PSScriptRoot 'vendor'
New-Item -ItemType Directory -Force -Path $vendor | Out-Null
Write-Host 'Downloading TensorFlow.js and COCO-SSD…'
Invoke-WebRequest -Uri 'https://cdn.jsdelivr.net/npm/@tensorflow/tfjs@4.12.0/dist/tf.min.js' -OutFile (Join-Path $vendor 'tf.min.js')
Invoke-WebRequest -Uri 'https://cdn.jsdelivr.net/npm/@tensorflow-models/coco-ssd@2.2.2' -OutFile (Join-Path $vendor 'coco-ssd.min.js')
Write-Host 'Done. Files:'
Get-ChildItem $vendor | Format-Table Name,Length,LastWriteTime -AutoSize


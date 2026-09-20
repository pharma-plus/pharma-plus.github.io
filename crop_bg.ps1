Add-Type -AssemblyName System.Drawing
$root = 'C:\Users\Merouan\Documents\Default Project\pharma-maroc-gold'
$src = [System.Drawing.Image]::FromFile("$root\frontend\assets\images\connexion photo 4.png")
Write-Host ("src: {0}x{1}" -f $src.Width, $src.Height)
$rect = New-Object System.Drawing.Rectangle(20, 25, 725, 530)
$bmp = New-Object System.Drawing.Bitmap($rect.Width, $rect.Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$dest = New-Object System.Drawing.Rectangle(0, 0, $rect.Width, $rect.Height)
$g.DrawImage($src, $dest, $rect, [System.Drawing.GraphicsUnit]::Pixel)
$g.Dispose()
$enc = [System.Drawing.Imaging.ImageCodecInfo]::GetImageEncoders() | Where-Object { $_.MimeType -eq 'image/jpeg' }
$ep = New-Object System.Drawing.Imaging.EncoderParameters(1)
$ep.Param[0] = New-Object System.Drawing.Imaging.EncoderParameter([System.Drawing.Imaging.Encoder]::Quality, ([long]85))
$bmp.Save("$root\images\pharma_login_background.jpg", $enc, $ep)
$bmp.Save("$root\frontend\assets\images\pharma_login_background.jpg", $enc, $ep)
$bmp.Dispose(); $src.Dispose(); $ep.Dispose()
Write-Host 'done'

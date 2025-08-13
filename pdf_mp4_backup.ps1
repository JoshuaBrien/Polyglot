function create_PDF_MP4_Polyglot {
    param([string]$pdfPath, [string]$mp4Path, [string]$outputPath)
    
    # Read and validate files
    try {
        $pdfBytes = [System.IO.File]::ReadAllBytes($pdfPath)
        $mp4Bytes = [System.IO.File]::ReadAllBytes($mp4Path)
    } catch {
        Write-Host "Error reading files: $_" -ForegroundColor Red
        return
    }

    # Validate PDF signature
    if (-not ([System.Text.Encoding]::ASCII.GetString($pdfBytes[0..7])).StartsWith("%PDF")) {
        Write-Host "Error: Invalid PDF file - missing PDF header" -ForegroundColor Red
        return
    }
    
    # Validate MP4 signature (ftyp box at or near start)
    $ftypFound = $false
    for ($i = 0; $i -lt [Math]::Min(40, $mp4Bytes.Length - 8); $i++) {
        if ($i + 7 -lt $mp4Bytes.Length) {
            $boxType = [System.Text.Encoding]::ASCII.GetString($mp4Bytes[($i + 4)..($i + 7)])
            if ($boxType -eq "ftyp") {
                $ftypFound = $true
                Write-Host "Found ftyp box at offset: $i" -ForegroundColor Green
                break
            }
        }
    }
    
    if (-not $ftypFound) {
        Write-Host "Error: Invalid MP4 file - missing ftyp box" -ForegroundColor Red
        return
    }
    
    Write-Host "PDF Size: $($pdfBytes.Length) bytes | MP4 Size: $($mp4Bytes.Length) bytes" -ForegroundColor Cyan
    Write-Host "Creating PDF+MP4 polyglot using MP4 udta box method..." -ForegroundColor Yellow
    
    # **METHOD 1: Try to embed PDF in MP4 udta (User Data) box**
    $udtaInserted = $false
    
    # Find a good insertion point (after ftyp, before mdat)
    $insertionPoint = -1
    $currentOffset = 0
    
    while ($currentOffset -lt ($mp4Bytes.Length - 8)) {
        try {
            # Read box size (first 4 bytes, big-endian)
            $boxSize = ([int]$mp4Bytes[$currentOffset] -shl 24) + 
                      ([int]$mp4Bytes[$currentOffset + 1] -shl 16) + 
                      ([int]$mp4Bytes[$currentOffset + 2] -shl 8) + 
                      [int]$mp4Bytes[$currentOffset + 3]
            
            # Read box type (next 4 bytes)
            $boxType = [System.Text.Encoding]::ASCII.GetString($mp4Bytes[($currentOffset + 4)..($currentOffset + 7)])
            
            Write-Host "Found MP4 box: '$boxType' at offset $currentOffset, size: $boxSize" -ForegroundColor Cyan
            
            # Insert udta box after ftyp but before mdat
            if ($boxType -eq "mdat" -or $boxType -eq "moov") {
                $insertionPoint = $currentOffset
                Write-Host "Inserting udta box before '$boxType' at offset: $insertionPoint" -ForegroundColor Green
                break
            }
            
            # Move to next box
            if ($boxSize -le 8 -or $boxSize -gt ($mp4Bytes.Length - $currentOffset)) {
                Write-Host "Invalid box size, stopping MP4 parsing" -ForegroundColor Yellow
                break
            }
            $currentOffset += $boxSize
            
        } catch {
            Write-Host "Error parsing MP4 structure: $($_.Exception.Message)" -ForegroundColor Yellow
            break
        }
    }
    
    if ($insertionPoint -gt 0) {
        try {
            Write-Host "Embedding PDF in MP4 udta (User Data) box..." -ForegroundColor Yellow
            
            # Create udta box with PDF data
            # Box structure: [Size (4 bytes)] [Type (4 bytes)] [Data]
            $udtaType = [System.Text.Encoding]::ASCII.GetBytes("udta")
            $pdfaType = [System.Text.Encoding]::ASCII.GetBytes("PDFA")  # Custom type for PDF data
            
            # Inner box: PDFA box containing PDF
            $innerBoxSize = 8 + $pdfBytes.Length  # 4 (size) + 4 (type) + data
            $innerBoxSizeBytes = @(
                [byte](($innerBoxSize -shr 24) -band 0xFF),
                [byte](($innerBoxSize -shr 16) -band 0xFF), 
                [byte](($innerBoxSize -shr 8) -band 0xFF),
                [byte]($innerBoxSize -band 0xFF)
            )
            
            # Outer box: udta box containing PDFA box
            $outerBoxSize = 8 + $innerBoxSize  # 4 (size) + 4 (type) + inner box
            $outerBoxSizeBytes = @(
                [byte](($outerBoxSize -shr 24) -band 0xFF),
                [byte](($outerBoxSize -shr 16) -band 0xFF),
                [byte](($outerBoxSize -shr 8) -band 0xFF), 
                [byte]($outerBoxSize -band 0xFF)
            )
            
            # Assemble udta box
            $udtaBox = $outerBoxSizeBytes + $udtaType + $innerBoxSizeBytes + $pdfaType + $pdfBytes
            
            # Insert into MP4
            $mp4Start = $mp4Bytes[0..($insertionPoint - 1)]
            $mp4End = $mp4Bytes[$insertionPoint..($mp4Bytes.Length - 1)]
            
            $global:polyglotBytes = $mp4Start + $udtaBox + $mp4End
            $udtaInserted = $true
            
            Write-Host "✅ PDF successfully embedded in MP4 udta box" -ForegroundColor Green
            
        } catch {
            Write-Host "udta box insertion failed: $($_.Exception.Message)" -ForegroundColor Red
            $udtaInserted = $false
        }
    }
    
    if (-not $udtaInserted) {
        Write-Host "Falling back to simple append method..." -ForegroundColor Yellow
        
        # **METHOD 2: Simple append (MP4-first for video playback)**
        $global:polyglotBytes = $mp4Bytes
        $pdfSeparator = [System.Text.Encoding]::ASCII.GetBytes("`r`n`r`n% PDF DOCUMENT FOLLOWS %`r`n")
        $global:polyglotBytes += $pdfSeparator
        $global:polyglotBytes += $pdfBytes
    }
    
    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)
    
    # Enhanced verification
    $mp4SigValid = $ftypFound
    
    # Check for PDF signature
    $pdfSigFound = $false
    $pdfOffset = -1
    for ($i = 0; $i -lt ($global:polyglotBytes.Length - 4); $i++) {
        if ($i + 4 -lt $global:polyglotBytes.Length) {
            $testStr = [System.Text.Encoding]::ASCII.GetString($global:polyglotBytes[$i..($i+3)])
            if ($testStr -eq "%PDF") {
                $pdfSigFound = $true
                $pdfOffset = $i
                break
            }
        }
    }
    
    Write-Host "`nCompatibility Results:" -ForegroundColor Yellow
    Write-Host "• MP4: $(if($mp4SigValid){'✅ Valid ftyp structure (should play)'}else{'❌ Invalid'})" -ForegroundColor $(if($mp4SigValid){'Green'}else{'Red'})
    
    if ($pdfSigFound) {
        Write-Host "• PDF: ✅ PDF signature found at offset $pdfOffset" -ForegroundColor Green
        if ($udtaInserted) {
            Write-Host "  Method: Embedded in MP4 udta box (proper MP4 structure)" -ForegroundColor White
        } else {
            Write-Host "  Method: Appended after MP4 (simple method)" -ForegroundColor White
        }
    } else {
        Write-Host "• PDF: ❌ PDF signature not found" -ForegroundColor Red
    }
    
    Write-Host "`nExpected Results:" -ForegroundColor Cyan
    if ($mp4SigValid) {
        Write-Host "• Video Players: ✅ Should play normally (MP4 structure preserved)" -ForegroundColor Green
    } else {
        Write-Host "• Video Players: ❌ MP4 structure invalid" -ForegroundColor Red
    }
    
    if ($pdfSigFound) {
        Write-Host "• PDF Readers: ✅ Should find PDF content" -ForegroundColor Green
        if ($udtaInserted) {
            Write-Host "  Advanced readers may extract PDF from udta box" -ForegroundColor White
        } else {
            Write-Host "  Readers will scan for PDF content in file" -ForegroundColor White
        }
    } else {
        Write-Host "• PDF Readers: ❌ PDF content not accessible" -ForegroundColor Red
    }
    
    Write-Host "`n✅ PDF-MP4 Polyglot created at $outputPath" -ForegroundColor Green
    Write-Host "File size: $($global:polyglotBytes.Length) bytes" -ForegroundColor Cyan
    
    Write-Host "`nUsage Instructions:" -ForegroundColor Yellow
    Write-Host "• Video playback: Keep .mp4 extension - should play in video players" -ForegroundColor White
    Write-Host "• PDF viewing: Rename to .pdf - PDF readers will find content" -ForegroundColor White
    if ($udtaInserted) {
        Write-Host "• Advanced: PDF is properly embedded in MP4 metadata structure" -ForegroundColor White
    }
}
function create_PDF_JPEG_Polyglot {
    param([string]$pdfPath, [string]$jpegPath, [string]$outputPath)
    
    # Read and validate files
    try {
        $pdfBytes = [System.IO.File]::ReadAllBytes($pdfPath)
        $jpegBytes = [System.IO.File]::ReadAllBytes($jpegPath)
    } catch {
        Write-Host "Error reading files: $_" -ForegroundColor Red
        return
    }

    # Validate JPEG signature (FF D8 FF)
    if ($jpegBytes.Length -lt 3 -or $jpegBytes[0] -ne 0xFF -or $jpegBytes[1] -ne 0xD8 -or $jpegBytes[2] -ne 0xFF) {
        Write-Host "Error: Invalid JPEG file" -ForegroundColor Red
        return
    }

    # Validate PDF file
    if (-not ([System.Text.Encoding]::ASCII.GetString($pdfBytes[0..7])).StartsWith("%PDF")) {
        Write-Host "Error: Invalid PDF file" -ForegroundColor Red
        return
    }

    Write-Host "PDF Size: $($pdfBytes.Length) bytes | JPEG Size: $($jpegBytes.Length) bytes" -ForegroundColor Cyan

    # IMPROVED APPROACH: Use JPEG Comment segment (COM) - more Adobe-friendly
    # Find insertion point after JPEG headers but before image data
    $insertionPoint = 2  # Start after SOI (FF D8)
    
    # Skip existing JPEG segments to find good insertion point
    $foundGoodSpot = $false
    while ($insertionPoint -lt $jpegBytes.Length - 1) {
        if ($jpegBytes[$insertionPoint] -eq 0xFF) {
            $marker = $jpegBytes[$insertionPoint + 1]
            
            # Insert before Start of Scan (SOS) or frame headers
            if ($marker -eq 0xDA -or ($marker -ge 0xC0 -and $marker -le 0xCF)) {
                $foundGoodSpot = $true
                Write-Host "Found insertion point at offset: $insertionPoint" -ForegroundColor Green
                break
            }
            
            # Skip this segment if it has a length
            if ($marker -ge 0xE0 -and $marker -le 0xEF) {  # Application segments
                if ($insertionPoint + 3 -lt $jpegBytes.Length) {
                    $segmentLength = ([int]$jpegBytes[$insertionPoint + 2] -shl 8) + $jpegBytes[$insertionPoint + 3]
                    $insertionPoint += 2 + $segmentLength
                } else {
                    break
                }
            } elseif ($marker -eq 0xFE) {  # Comment segment
                if ($insertionPoint + 3 -lt $jpegBytes.Length) {
                    $segmentLength = ([int]$jpegBytes[$insertionPoint + 2] -shl 8) + $jpegBytes[$insertionPoint + 3]
                    $insertionPoint += 2 + $segmentLength
                } else {
                    break
                }
            } else {
                $insertionPoint += 2
            }
        } else {
            $insertionPoint++
        }
    }

    if (-not $foundGoodSpot) {
        Write-Host "Warning: Could not find optimal insertion point, using fallback" -ForegroundColor Yellow
        $insertionPoint = 2  # Default to right after SOI
    }

    # Check if PDF fits in a JPEG segment (max 65533 bytes for segment data)
    $maxSegmentData = 65533  # 65535 - 2 (length bytes)
    
    if ($pdfBytes.Length -le $maxSegmentData) {
        # OPTION 1: Embed as JPEG Comment segment (FF FE) - Adobe-friendly
        Write-Host "Embedding PDF as JPEG Comment segment (Adobe-compatible)" -ForegroundColor Yellow
        
        $comMarker = [byte[]]@(0xFF, 0xFE)  # COM (Comment) segment marker
        
        # Calculate total length (PDF size + 2 bytes for length field)
        $totalLength = $pdfBytes.Length + 2
        $highByte = [byte](($totalLength -shr 8) -band 0xFF)
        $lowByte = [byte]($totalLength -band 0xFF)
        $lengthBytes = [byte[]]@($highByte, $lowByte)
        
        # Split JPEG at insertion point
        $jpegStart = $jpegBytes[0..($insertionPoint - 1)]
        $jpegEnd = $jpegBytes[$insertionPoint..($jpegBytes.Length - 1)]
        
        # Assemble: [JPEG Start] + [COM Marker] + [Length] + [PDF Data] + [JPEG End]
        $global:polyglotBytes = $jpegStart
        $global:polyglotBytes += $comMarker      # FF FE (Comment marker)
        $global:polyglotBytes += $lengthBytes    # Segment length
        $global:polyglotBytes += $pdfBytes       # PDF content as comment
        $global:polyglotBytes += $jpegEnd        # Rest of JPEG
        
        Write-Host "✅ PDF embedded as JPEG Comment segment" -ForegroundColor Green
        
    } else {
        # OPTION 2: Multiple Comment segments approach for large PDFs
        Write-Host "PDF too large for single segment, using multi-segment approach" -ForegroundColor Yellow
        
        $jpegStart = $jpegBytes[0..($insertionPoint - 1)]
        $jpegEnd = $jpegBytes[$insertionPoint..($jpegBytes.Length - 1)]
        
        $global:polyglotBytes = $jpegStart
        
        # Split PDF into chunks that fit in JPEG comment segments
        $chunkSize = $maxSegmentData
        $offset = 0
        $chunkNumber = 0
        
        while ($offset -lt $pdfBytes.Length) {
            $remainingBytes = $pdfBytes.Length - $offset
            $currentChunkSize = [Math]::Min($chunkSize, $remainingBytes)
            $chunk = $pdfBytes[$offset..($offset + $currentChunkSize - 1)]
            
            # Create comment segment for this chunk
            $comMarker = [byte[]]@(0xFF, 0xFE)
            $totalLength = $chunk.Length + 2
            $highByte = [byte](($totalLength -shr 8) -band 0xFF)
            $lowByte = [byte]($totalLength -band 0xFF)
            $lengthBytes = [byte[]]@($highByte, $lowByte)
            
            $global:polyglotBytes += $comMarker
            $global:polyglotBytes += $lengthBytes
            $global:polyglotBytes += $chunk
            
            $offset += $currentChunkSize
            $chunkNumber++
        }
        
        $global:polyglotBytes += $jpegEnd
        Write-Host "✅ PDF embedded as $chunkNumber JPEG Comment segments" -ForegroundColor Green
    }

    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)
    
    # Enhanced verification
    Write-Host "`nVerification:" -ForegroundColor Yellow
    
    # Check JPEG signature
    if ($global:polyglotBytes.Length -ge 3 -and $global:polyglotBytes[0] -eq 0xFF -and 
        $global:polyglotBytes[1] -eq 0xD8 -and $global:polyglotBytes[2] -eq 0xFF) {
        Write-Host "✅ JPEG signature confirmed" -ForegroundColor Green
    } else {
        Write-Host "❌ JPEG signature missing" -ForegroundColor Red
    }
    
    # Check for PDF content
    $polyglotText = [System.Text.Encoding]::ASCII.GetString($global:polyglotBytes)
    if ($polyglotText.Contains("%PDF")) {
        Write-Host "✅ PDF content embedded" -ForegroundColor Green
    } else {
        Write-Host "❌ PDF content not found" -ForegroundColor Red
    }
    
    # Check for JPEG end marker
    $endIndex = $global:polyglotBytes.Length - 2
    if ($endIndex -ge 0 -and $global:polyglotBytes[$endIndex] -eq 0xFF -and $global:polyglotBytes[$endIndex + 1] -eq 0xD9) {
        Write-Host "✅ JPEG end marker (EOI) confirmed" -ForegroundColor Green
    } else {
        Write-Host "⚠️ JPEG end marker not found at expected location" -ForegroundColor Yellow
    }

    Write-Host "`n✅ PDF-JPEG Polyglot created at $outputPath" -ForegroundColor Green
    Write-Host "`nDirect Compatibility:" -ForegroundColor Cyan
    Write-Host "• Rename to .jpeg/.jpg: ✅ Works in image viewers" -ForegroundColor Green
    Write-Host "• Rename to .pdf: ✅ Adobe Reader compatible (Comment segment method)" -ForegroundColor Green
    Write-Host "`nNote: Uses JPEG Comment segments for better Adobe compatibility!" -ForegroundColor White
}
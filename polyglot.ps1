# By JOB


# global variables
$global:file1path = $null
$global:file2path = $null
$global:outputpath = $null
$global:file1ext = $null
$global:file2ext = $null

# global vars used for polyglot creation
$global:polyglotbytes = $null
$global:polyglotFunctions = @{
    "pdf-zip"   = { param($f1, $f2, $out) create_PDF_ZIP_Polyglot -pdfPath $f1 -zipPath $f2 -outputPath $out }
    "html-zip"  = { param($f1, $f2, $out) create_HTML_ZIP_Polyglot -htmlPath $f1 -zipPath $f2 -outputPath $out }
    "xml-zip"   = { param($f1, $f2, $out) create_XML_ZIP_Polyglot -xmlPath $f1 -zipPath $f2 -outputPath $out }
    "pdf-jpeg"  = { param($f1, $f2, $out) create_PDF_JPEG_Polyglot -pdfPath $f1 -jpegPath $f2 -outputPath $out }
    "zip-jpeg"  = { param($f1, $f2, $out) create_ZIP_JPEG_Polyglot -zipPath $f1 -jpegPath $f2 -outputPath $out }
    "pdf-png"   = { param($f1, $f2, $out) create_PDF_PNG_Polyglot -pdfPath $f1 -pngPath $f2 -outputPath $out }
    "zip-png"   = { param($f1, $f2, $out) create_ZIP_PNG_Polyglot -zipPath $f1 -pngPath $f2 -outputPath $out } 
    "zip-mp4"   = { param($f1, $f2, $out) create_ZIP_MP4_Polyglot -zipPath $f1 -mp4Path $f2 -outputPath $out }
    
}


function validate_file{
    param([string]$filePath, [string]$expectedExtension, [string]$fileDescription)
    
    # Check existence and extension in one go
    if (-not (Test-Path $filePath)) {
        Write-Host "$fileDescription does not exist: $filePath" -ForegroundColor Red
        return $false
    }
    
    $actualExt = [System.IO.Path]::GetExtension($filePath).ToLower()
    $expectedExt = ".$expectedExtension".ToLower()
    
    if ($actualExt -ne $expectedExt) {
        Write-Host "$fileDescription has wrong extension. Expected: $expectedExt, Got: $actualExt" -ForegroundColor Red
        return $false
    }
    
    Write-Host "$fileDescription validated: $filePath" -ForegroundColor Green
    return $true
}

function get_validated_file{
    param([string]$fileNumber, [string]$expectedExtension)
    
    do {
        $filePath = Read-Host "Enter path for file $fileNumber ($expectedExtension)"
        $isValid = validate_file -filePath $filePath -expectedExtension $expectedExtension -fileDescription "File $fileNumber"
        
        if (-not $isValid) {
            Write-Host "Please enter a valid $expectedExtension file path." -ForegroundColor Yellow
        }
    } while (-not $isValid)
    
    return $filePath
}

function enter_file_paths{
    # Get validated file paths
    $global:file1path = get_validated_file -fileNumber "1" -expectedExtension $global:file1ext
    $global:file2path = get_validated_file -fileNumber "2" -expectedExtension $global:file2ext
    
    # Get output path (no validation needed)
    $global:outputpath = Read-Host "Enter output file path"

    # Create polyglot
    polyglot_creator -file1ext $global:file1ext -file1path $global:file1path -file2ext $global:file2ext -file2path $global:file2path -output $global:outputpath
}

function files2_menu{
    Write-Host "Choose file to be embedded in (file a2)"
    Write-Host "[1] .zip ( will need to rename to .rar or .7z as .zip is hella strict on the signature like why the f-)"
    Write-Host "[2] .jpeg"
    Write-Host "[3] .png"
    Write-Host "[4] .mp4"
    $choice = Read-Host "Enter your choice"
    switch($choice){
        1{
            $global:file2ext = "zip"
            enter_file_paths
        }
        
        2{
            $global:file2ext = "jpeg"
            enter_file_paths
        }
        3{
            $global:file2ext = "png"
            enter_file_paths
        }
        4{
            $global:file2ext = "mp4"
            enter_file_paths
        }
        default{
            Write-Host "Invalid choice, please try again."
            files2_menu
        }
    }
}

function files1_menu{
    Write-Host "
    (                                       
 )\ )      (               (          )  
(()/(      )\ (     (  (   )\      ( /(  
 /(_)) (  ((_))\ )  )\))( ((_) (   )\()) 
(_))   )\  _ (()/( ((_))\  _   )\ (_))/  
| _ \ ((_)| | )(_)) (()(_)| | ((_)| |_   
|  _// _ \| || || |/ _` | | |/ _ \|  _|  
|_|  \___/|_| \_, |\__, | |_|\___/ \__|  
               |__/ |___/                 

    "
    Write-Host "Choose a file to be embedded (file 1)"
    Write-Host "Note: only .pdf + .zip works with adobe, rest doesnt"
    Write-Host "[1] .pdf"
    Write-Host "[2] .html"
    Write-Host "[3] .xml"
    Write-Host "[4] .zip (will need to rename to .rar or .7z as .zip is hella strict on the signature like why the f-)"
    $choice = Read-Host "Enter your choice"
    switch($choice){
        1{
            $global:file1ext = "pdf"
            files2_menu
        }
        2{
            $global:file1ext = "html"
            files2_menu
        }
        3{
            $global:file1ext = "xml"
            files2_menu
        }
        4{
            $global:file1ext = "zip"
            files2_menu
        }
        default{
            Write-Host "Invalid choice, please try again."
            main_menu
        }
    }
}

function modify_ZIP_EOCD_for_comment {
    param(
        [byte[]]$zipBytes,
        [byte[]]$commentData,
        [string]$description = "data"
    )
    
    # Find EOCD signature (50 4B 05 06)
    $eocdFound = $false
    $eocdOffset = -1
    
    Write-Host "Searching for EOCD in ZIP file..." -ForegroundColor Yellow
    
    # Search from end of file backwards
    for ($i = $zipBytes.Length - 22; $i -ge 0; $i--) {
        if ($zipBytes[$i] -eq 0x50 -and $zipBytes[$i+1] -eq 0x4B -and 
            $zipBytes[$i+2] -eq 0x05 -and $zipBytes[$i+3] -eq 0x06) {
            $eocdOffset = $i
            $eocdFound = $true
            Write-Host "Found EOCD at offset: 0x$($i.ToString('X8')) ($i)" -ForegroundColor Green
            break
        }
    }

    if (-not $eocdFound) {
        Write-Host "Error: End of Central Directory (EOCD) record not found in ZIP file" -ForegroundColor Red
        return $null
    }

    # Extract original EOCD and get current comment length
    $originalEOCD = $zipBytes[$eocdOffset..($zipBytes.Length - 1)]
    $originalCommentLength = [BitConverter]::ToUInt16($zipBytes[($eocdOffset + 20)..($eocdOffset + 21)], 0)
    
    Write-Host "Original comment length: $originalCommentLength bytes" -ForegroundColor Cyan
    Write-Host "New comment ($description): $($commentData.Length) bytes" -ForegroundColor Cyan

    # Handle comment size limitation (ZIP comment max is 65535 bytes)
    $actualCommentData = if ($commentData.Length -le 65535) { 
        $commentData 
    } else { 
        Write-Host "Warning: $description too large for ZIP comment, truncating to 65535 bytes" -ForegroundColor Yellow
        $commentData[0..65534] 
    }

    # Build modified ZIP structure
    $zipWithoutEOCD = $zipBytes[0..($eocdOffset - 1)]
    
    # Create modified EOCD with new comment
    $modifiedEOCD = $originalEOCD[0..19]  # Keep first 20 bytes (everything except comment length)
    
    # Set new comment length (little-endian format)
    $newCommentLength = [uint16]$actualCommentData.Length
    $commentLengthBytes = [BitConverter]::GetBytes($newCommentLength)
    if (-not [BitConverter]::IsLittleEndian) {
        [Array]::Reverse($commentLengthBytes)
    }
    $modifiedEOCD += $commentLengthBytes

    # Assemble final structure: [ZIP without EOCD] + [Comment Data] + [Modified EOCD]
    $modifiedZipBytes = $zipWithoutEOCD + $actualCommentData + $modifiedEOCD

    #Write-Host " ZIP EOCD modification completed" -ForegroundColor Green
    #Write-Host "  Original ZIP size: $($zipBytes.Length) bytes" -ForegroundColor White
    #Write-Host "  Modified ZIP size: $($modifiedZipBytes.Length) bytes" -ForegroundColor White
    #Write-Host "  Comment embedded: $($actualCommentData.Length) bytes" -ForegroundColor White

    return @{
        ModifiedZipBytes = $modifiedZipBytes
        CommentData = $actualCommentData
        CommentLength = $actualCommentData.Length
        EOCDOffset = $eocdOffset
        OriginalCommentLength = $originalCommentLength
    }
}

# supports only 2 rn
function polyglot_creator{
    param([string]$file1ext, [string]$file1path, [string]$file2ext, [string]$file2path, [string]$output)
    
    # Create combination key
    $combinationKey = "$file1ext-$file2ext"
    
    # Check if combination is supported
    if ($global:polyglotFunctions.ContainsKey($combinationKey)) {
        Write-Host "Creating $file1ext + $file2ext polyglot..." -ForegroundColor Cyan
        
        try {
            # Execute the corresponding function
            & $global:polyglotFunctions[$combinationKey] $file1path $file2path $output
            Write-Host "Polyglot creation completed at $output" -ForegroundColor Cyan
        } catch {
            Write-Host "Error creating polyglot: $($_.Exception.Message)" -ForegroundColor Red
        }
    } else {
        Write-Host "
        Unsupported combination: $file1ext + $file2ext" -ForegroundColor Red
        Write-Host "Supported combinations:" -ForegroundColor Yellow
        $global:polyglotFunctions.Keys | Sort-Object | ForEach-Object {
            Write-Host "  . $_" -ForegroundColor White
        }
    }
}

# Naming convention should be file1_file2_Polyglot 

# __ + ZIP
function create_PDF_ZIP_Polyglot{ 
    param([string]$pdfPath, [string]$zipPath, [string]$outputPath)

    # Read input files
    $pdfBytes = [System.IO.File]::ReadAllBytes($pdfPath)
    $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
    
    #Create polyglot ( PDF first approach )
    $pdfText = [System.Text.Encoding]::ASCII.GetString($pdfBytes)
    $eofIndex = $pdfText.LastIndexOf("%%EOF")
    $pdfStart = $pdfBytes[0..([System.Text.Encoding]::ASCII.GetBytes($pdfText.Substring(0, $eofIndex)).Length - 1)]
    $pdfEnd = [System.Text.Encoding]::ASCII.GetBytes($pdfText.Substring($eofIndex))
    $streamSection = [System.Text.Encoding]::ASCII.GetBytes(@"

stream
"@) + $zipBytes + [System.Text.Encoding]::ASCII.GetBytes(@"

endstream

"@)
    $global:polyglotBytes = $pdfStart + $streamSection + $pdfEnd 

    #Output file
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)

}

function create_HTML_ZIP_Polyglot{
    param([string]$htmlPath, [string]$zipPath, [string]$outputPath)

    # Read input files
    $htmlBytes = [System.IO.File]::ReadAllBytes($htmlPath)
    $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)

    # Create polyglot (ZIP-first approach)
    $global:polyglotBytes = $zipBytes # Start with ZIP data
    $separator = [System.Text.Encoding]::UTF8.GetBytes("`n`n")
    $global:polyglotBytes += $separator
    $global:polyglotBytes += $htmlBytes

    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)

}

# Parser error but fill is still valid so
function create_XML_ZIP_Polyglot{
    param (
        [string]$zipPath,
        [string]$xmlPath,
        [string]$outputPath
    )

    # Read input files
    $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
    $xmlBytes = [System.IO.File]::ReadAllBytes($xmlPath)

    # Validate XML (look for <?xml or <root>, approximate check)
    $xmlFound = $false
    $xmlText = [System.Text.Encoding]::UTF8.GetString($xmlBytes)
    if ($xmlText -match "<\?xml" -or $xmlText -match "<[a-zA-Z]+>") {
        $xmlFound = $true
    }
    if (-not $xmlFound) {
        Write-Output "Error: $xmlPath is not a valid XML file (<?xml or root element not found)" - -ForegroundColor Red
        exit
    }

    # Create polyglot
    $polyglotBytes = $zipBytes
    $polyglotBytes += $xmlBytes

    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $polyglotBytes)
    

}

# __ + JPEG
function create_PDF_JPEG_Polyglot {
    param([string]$pdfPath, [string]$jpegPath, [string]$outputPath)
    
    #Read from files
    $pdfBytes = [System.IO.File]::ReadAllBytes($pdfPath)
    $jpegBytes = [System.IO.File]::ReadAllBytes($jpegPath)
    # Create polyglot using JPEG Comment segment
    # 
    $insertionPoint = 2

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
        $comMarker = [byte[]]@(0xFF, 0xFE)  # COM (Comment) segment marker
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
        
        Write-Host "PDF embedded as JPEG Comment segment" -ForegroundColor Green
        
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
        Write-Host "PDF embedded as $chunkNumber JPEG Comment segments" -ForegroundColor Green
    }

    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)

}
function create_ZIP_JPEG_Polyglot{
    param([string]$zipPath, [string]$jpegPath, [string]$outputPath)

    # Read input files
    $jpegBytes = [System.IO.File]::ReadAllBytes($jpegPath)
    $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
    
    # Validate files
    if ($zipBytes.Length -lt 4 -or $zipBytes[0] -ne 0x50 -or $zipBytes[1] -ne 0x4B) {
        Write-Host "Error: Invalid ZIP file - missing PK signature" -ForegroundColor Red
        return
    }
    
    if ($jpegBytes.Length -lt 2 -or $jpegBytes[0] -ne 0xFF -or $jpegBytes[1] -ne 0xD8) {
        Write-Host "Error: Invalid JPEG file - missing JPEG signature" -ForegroundColor Red
        return
    }
    
    #Create polyglot
    $global:polyglotBytes = $jpegBytes
    $zipSeparator = [System.Text.Encoding]::ASCII.GetBytes("`n`n% ZIP ARCHIVE DATA FOLLOWS %`n")
    $global:polyglotBytes += $zipSeparator
    $global:polyglotBytes += $zipBytes
    
    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)

    
}



# __ + PNG

# Helper function to calculate CRC32 (required for PNG chunks)
function Get-CRC32 {
    param([byte[]]$data)
    
    # CRC32 lookup table (IEEE 802.3 polynomial)
    $crcTable = @(
        0x00000000, 0x77073096, 0xEE0E612C, 0x990951BA, 0x076DC419, 0x706AF48F,
        0xE963A535, 0x9E6495A3, 0x0EDB8832, 0x79DCB8A4, 0xE0D5E91E, 0x97D2D988,
        0x09B64C2B, 0x7EB17CBD, 0xE7B82D07, 0x90BF1D91, 0x1DB71064, 0x6AB020F2,
        0xF3B97148, 0x84BE41DE, 0x1ADAD47D, 0x6DDDE4EB, 0xF4D4B551, 0x83D385C7,
        0x136C9856, 0x646BA8C0, 0xFD62F97A, 0x8A65C9EC, 0x14015C4F, 0x63066CD9,
        0xFA0F3D63, 0x8D080DF5, 0x3B6E20C8, 0x4C69105E, 0xD56041E4, 0xA2677172,
        0x3C03E4D1, 0x4B04D447, 0xD20D85FD, 0xA50AB56B, 0x35B5A8FA, 0x42B2986C,
        0xDBBBC9D6, 0xACBCF940, 0x32D86CE3, 0x45DF5C75, 0xDCD60DCF, 0xABD13D59,
        0x26D930AC, 0x51DE003A, 0xC8D75180, 0xBFD06116, 0x21B4F4B5, 0x56B3C423,
        0xCFBA9599, 0xB8BDA50F, 0x2802B89E, 0x5F058808, 0xC60CD9B2, 0xB10BE924,
        0x2F6F7C87, 0x58684C11, 0xC1611DAB, 0xB6662D3D, 0x76DC4190, 0x01DB7106,
        0x98D220BC, 0xEFD5102A, 0x71B18589, 0x06B6B51F, 0x9FBFE4A5, 0xE8B8D433,
        0x7807C9A2, 0x0F00F934, 0x9609A88E, 0xE10E9818, 0x7F6A0DBB, 0x086D3D2D,
        0x91646C97, 0xE6635C01, 0x6B6B51F4, 0x1C6C6162, 0x856530D8, 0xF262004E,
        0x6C0695ED, 0x1B01A57B, 0x8208F4C1, 0xF50FC457, 0x65B0D9C6, 0x12B7E950,
        0x8BBEB8EA, 0xFCB9887C, 0x62DD1DDF, 0x15DA2D49, 0x8CD37CF3, 0xFBD44C65,
        0x4DB26158, 0x3AB551CE, 0xA3BC0074, 0xD4BB30E2, 0x4ADFA541, 0x3DD895D7,
        0xA4D1C46D, 0xD3D6F4FB, 0x4369E96A, 0x346ED9FC, 0xAD678846, 0xDA60B8D0,
        0x44042D73, 0x33031DE5, 0xAA0A4C5F, 0xDD0D7CC9, 0x5005713C, 0x270241AA,
        0xBE0B1010, 0xC90C2086, 0x5768B525, 0x206F85B3, 0xB966D409, 0xCE61E49F,
        0x5EDEF90E, 0x29D9C998, 0xB0D09822, 0xC7D7A8B4, 0x59B33D17, 0x2EB40D81,
        0xB7BD5C3B, 0xC0BA6CAD, 0xEDB88320, 0x9ABFB3B6, 0x03B6E20C, 0x74B1D29A,
        0xEAD54739, 0x9DD277AF, 0x04DB2615, 0x73DC1683, 0xE3630B12, 0x94643B84,
        0x0D6D6A3E, 0x7A6A5AA8, 0xE40ECF0B, 0x9309FF9D, 0x0A00AE27, 0x7D079EB1,
        0xF00F9344, 0x8708A3D2, 0x1E01F268, 0x6906C2FE, 0xF762575D, 0x806567CB,
        0x196C3671, 0x6E6B06E7, 0xFED41B76, 0x89D32BE0, 0x10DA7A5A, 0x67DD4ACC,
        0xF9B9DF6F, 0x8EBEEFF9, 0x17B7BE43, 0x60B08ED5, 0xD6D6A3E8, 0xA1D1937E,
        0x38D8C2C4, 0x4FDFF252, 0xD1BB67F1, 0xA6BC5767, 0x3FB506DD, 0x48B2364B,
        0xD80D2BDA, 0xAF0A1B4C, 0x36034AF6, 0x41047A60, 0xDF60EFC3, 0xA867DF55,
        0x316E8EEF, 0x4669BE79, 0xCB61B38C, 0xBC66831A, 0x256FD2A0, 0x5268E236,
        0xCC0C7795, 0xBB0B4703, 0x220216B9, 0x5505262F, 0xC5BA3BBE, 0xB2BD0B28,
        0x2BB45A92, 0x5CB36A04, 0xC2D7FFA7, 0xB5D0CF31, 0x2CD99E8B, 0x5BDEAE1D,
        0x9B64C2B0, 0xEC63F226, 0x756AA39C, 0x026D930A, 0x9C0906A9, 0xEB0E363F,
        0x72076785, 0x05005713, 0x95BF4A82, 0xE2B87A14, 0x7BB12BAE, 0x0CB61B38,
        0x92D28E9B, 0xE5D5BE0D, 0x7CDCEFB7, 0x0BDBDF21, 0x86D3D2D4, 0xF1D4E242,
        0x68DDB3F8, 0x1FDA836E, 0x81BE16CD, 0xF6B9265B, 0x6FB077E1, 0x18B74777,
        0x88085AE6, 0xFF0F6A70, 0x66063BCA, 0x11010B5C, 0x8F659EFF, 0xF862AE69,
        0x616BFFD3, 0x166CCF45, 0xA00AE278, 0xD70DD2EE, 0x4E048354, 0x3903B3C2,
        0xA7672661, 0xD06016F7, 0x4969474D, 0x3E6E77DB, 0xAED16A4A, 0xD9D65ADC,
        0x40DF0B66, 0x37D83BF0, 0xA9BCAE53, 0xDEBB9EC5, 0x47B2CF7F, 0x30B5FFE9,
        0xBDBDF21C, 0xCABAC28A, 0x53B39330, 0x24B4A3A6, 0xBAD03605, 0xCDD70693,
        0x54DE5729, 0x23D967BF, 0xB3667A2E, 0xC4614AB8, 0x5D681B02, 0x2A6F2B94,
        0xB40BBE37, 0xC30C8EA1, 0x5A05DF1B, 0x2D02EF8D
    )
    
    try {
        $crc = [uint32]0xFFFFFFFF
        
        foreach ($byte in $data) {
            $tableIndex = ($crc -bxor $byte) -band 0xFF
            $crc = (($crc -shr 8) -band 0x00FFFFFF) -bxor $crcTable[$tableIndex]
        }
        
        return $crc -bxor 0xFFFFFFFF
    } catch {
        Write-Host "CRC32 calculation error: $($_.Exception.Message)" -ForegroundColor Red
        return 0
    }
}
function create_PDF_PNG_Polyglot {
    param([string]$pdfPath, [string]$pngPath, [string]$outputPath)
    
    # Read files
    $pdfBytes = [System.IO.File]::ReadAllBytes($pdfPath)
    $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)


    # Validate PNG signature and PDF header
    $pngSignature = [byte[]]@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    
    if ($pngBytes.Length -lt 8) {
        Write-Host "Error: Invalid PNG file" -ForegroundColor Red
        return
    }
    for ($i = 0; $i -lt 8; $i++) {
        if ($pngBytes[$i] -ne $pngSignature[$i]) {
            Write-Host "Error: Invalid PNG file - missing PNG signature at byte $i" -ForegroundColor Red
            return
        }
    }
        
    if (-not ([System.Text.Encoding]::ASCII.GetString($pdfBytes[0..7])).StartsWith("%PDF")) {
        Write-Host "Error: Invalid PDF file" -ForegroundColor Red
        return
    }

    # Find IDAT chunk insertion point
    $insertionPoint = 8
    $foundIDAT = $false
    $maxIterations = 100
    
    for ($i = 0; $i -lt $maxIterations -and $insertionPoint -lt ($pngBytes.Length - 12); $i++) {
        try {
            $chunkType = [System.Text.Encoding]::ASCII.GetString($pngBytes[($insertionPoint + 4)..($insertionPoint + 7)])
            if ($chunkType -eq "IDAT") {
                $foundIDAT = $true
                Write-Host "Found IDAT chunk at offset: $insertionPoint" -ForegroundColor Green
                break
            }
            
            $chunkLength = ([int]$pngBytes[$insertionPoint] -shl 24) + ([int]$pngBytes[$insertionPoint + 1] -shl 16) + 
                          ([int]$pngBytes[$insertionPoint + 2] -shl 8) + [int]$pngBytes[$insertionPoint + 3]
            
            if ($chunkLength -lt 0 -or $chunkLength -gt ($pngBytes.Length - $insertionPoint)) { break }
            
            $nextPoint = $insertionPoint + 8 + $chunkLength + 4
            if ($nextPoint -le $insertionPoint) { break }
            $insertionPoint = $nextPoint
        } catch { break }
    }
    
    # Create polyglot based on success/failure
    if (-not $foundIDAT -or $pdfBytes.Length -gt 16777216) {
        Write-Host "Using simple append method" -ForegroundColor Yellow
        $global:polyglotBytes = $pngBytes + [System.Text.Encoding]::ASCII.GetBytes("`n`n%% PDF DOCUMENT STARTS HERE %%`n") + $pdfBytes
    } else {
        # PNG chunk embedding method
        try {
            $chunkType = [System.Text.Encoding]::ASCII.GetBytes("pDFs")
            $crc32 = Get-CRC32 -data ($chunkType + $pdfBytes)
            
            # Build chunk bytes (PowerShell 5 compatible)
            $lengthBytes = @([byte](($pdfBytes.Length -shr 24) -band 0xFF), [byte](($pdfBytes.Length -shr 16) -band 0xFF), 
                           [byte](($pdfBytes.Length -shr 8) -band 0xFF), [byte]($pdfBytes.Length -band 0xFF))
            $crcBytes = @([byte](($crc32 -shr 24) -band 0xFF), [byte](($crc32 -shr 16) -band 0xFF),
                        [byte](($crc32 -shr 8) -band 0xFF), [byte]($crc32 -band 0xFF))
            
            # Assemble polyglot
            $global:polyglotBytes = $pngBytes[0..($insertionPoint - 1)] + $lengthBytes + $chunkType + $pdfBytes + $crcBytes + $pngBytes[$insertionPoint..($pngBytes.Length - 1)]
            Write-Host "PDF embedded as PNG chunk (pDFs)" -ForegroundColor Green
        } catch {
            Write-Host "Chunk embedding failed, using append method" -ForegroundColor Yellow
            $global:polyglotBytes = $pngBytes + [System.Text.Encoding]::ASCII.GetBytes("`n`n%% PDF DOCUMENT STARTS HERE %%`n") + $pdfBytes
        }
    }

    # Write and verify
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)
}
function create_ZIP_PNG_Polyglot {
    param([string]$zipPath, [string]$pngPath, [string]$outputPath)
    
    # Read and validate files
    $pngBytes = [System.IO.File]::ReadAllBytes($pngPath)
    $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)
    
    # Validate PNG signature
    $pngSignature = [byte[]]@(0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A)
    for ($i = 0; $i -lt 8; $i++) {
        if ($pngBytes[$i] -ne $pngSignature[$i]) {
            Write-Host "Error: Invalid PNG file - missing PNG signature at byte $i" -ForegroundColor Red
            return
        }
    }
    
    # Validate ZIP signature
    if ($zipBytes.Length -lt 4 -or $zipBytes[0] -ne 0x50 -or $zipBytes[1] -ne 0x4B) {
        Write-Host "Error: Invalid ZIP file - missing PK signature" -ForegroundColor Red
        return
    }

    
    # Find IDAT chunk for insertion point
    $insertionPoint = 8
    $foundIDAT = $false
    $maxIterations = 100
    
    for ($i = 0; $i -lt $maxIterations -and $insertionPoint -lt ($pngBytes.Length - 12); $i++) {
        try {
            $chunkType = [System.Text.Encoding]::ASCII.GetString($pngBytes[($insertionPoint + 4)..($insertionPoint + 7)])
            if ($chunkType -eq "IDAT") {
                $foundIDAT = $true
                Write-Host "Found IDAT chunk at offset: $insertionPoint" -ForegroundColor Green
                break
            }
            
            $chunkLength = ([int]$pngBytes[$insertionPoint] -shl 24) + ([int]$pngBytes[$insertionPoint + 1] -shl 16) + 
                          ([int]$pngBytes[$insertionPoint + 2] -shl 8) + [int]$pngBytes[$insertionPoint + 3]
            
            if ($chunkLength -lt 0 -or $chunkLength -gt ($pngBytes.Length - $insertionPoint)) { break }
            
            $nextPoint = $insertionPoint + 8 + $chunkLength + 4
            if ($nextPoint -le $insertionPoint) { break }
            $insertionPoint = $nextPoint
        } catch { break }
    }
    
    # Create polyglot
    if ($foundIDAT -and $zipBytes.Length -le 16777216) {
        # Method 1: Embed ZIP as custom PNG chunk
        try {
            $chunkType = [System.Text.Encoding]::ASCII.GetBytes("ziPs")
            $crc32 = Get-CRC32 -data ($chunkType + $zipBytes)
            
            # Build chunk bytes
            $lengthBytes = @([byte](($zipBytes.Length -shr 24) -band 0xFF), [byte](($zipBytes.Length -shr 16) -band 0xFF), 
                           [byte](($zipBytes.Length -shr 8) -band 0xFF), [byte]($zipBytes.Length -band 0xFF))
            $crcBytes = @([byte](($crc32 -shr 24) -band 0xFF), [byte](($crc32 -shr 16) -band 0xFF),
                        [byte](($crc32 -shr 8) -band 0xFF), [byte]($crc32 -band 0xFF))
            
            # Assemble polyglot with embedded chunk
            $global:polyglotBytes = $pngBytes[0..($insertionPoint - 1)] + $lengthBytes + $chunkType + $zipBytes + $crcBytes + $pngBytes[$insertionPoint..($pngBytes.Length - 1)]
            
            # Add ZIP at end for extraction compatibility
            $zipSeparator = [System.Text.Encoding]::ASCII.GetBytes("`n`n% ZIP ARCHIVE DATA FOLLOWS %`n")
            $global:polyglotBytes += $zipSeparator
            $global:polyglotBytes += $zipBytes
            
            Write-Host "ZIP embedded as PNG chunk (ziPs) + appended at end" -ForegroundColor Green
        } catch {
            Write-Host "Chunk embedding failed, using append method" -ForegroundColor Yellow
            $global:polyglotBytes = $pngBytes + $zipSeparator + $zipBytes
        }
    } else {
        # Method 2: Simple append method
        Write-Host "Using simple append method" -ForegroundColor Yellow
        $zipSeparator = [System.Text.Encoding]::ASCII.GetBytes("`n`n% ZIP ARCHIVE DATA FOLLOWS %`n")
        $global:polyglotBytes = $pngBytes + $zipSeparator + $zipBytes
    }

    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)
    Write-Output "Polyglot created at $outputPath"
    
}


# __ + MP4
function create_ZIP_MP4_Polyglot {
    param([string]$zipPath, [string]$mp4Path, [string]$outputPath)
    
    # Read from files
    $mp4Bytes = [System.IO.File]::ReadAllBytes($mp4Path)
    $zipBytes = [System.IO.File]::ReadAllBytes($zipPath)


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

    # Validate ZIP signature
    if ($zipBytes.Length -lt 4 -or $zipBytes[0] -ne 0x50 -or $zipBytes[1] -ne 0x4B) {
        Write-Host "Error: Invalid ZIP file - missing PK signature" -ForegroundColor Red
        return
    }
    
    
    if (-not $ftypFound) {
        Write-Host "Error: Invalid MP4 file - missing ftyp box" -ForegroundColor Red
        return
    }
        
    # Create polyglot using simple append method to not break mp4 internal structure
    $global:polyglotBytes = $mp4Bytes
    $zipSeparator = [System.Text.Encoding]::ASCII.GetBytes("`n`n% ZIP ARCHIVE DATA FOLLOWS %`n")
    $global:polyglotBytes += $zipSeparator
    $global:polyglotBytes += $zipBytes
    
    # Write output
    [System.IO.File]::WriteAllBytes($outputPath, $global:polyglotBytes)
    Write-Output "Polyglot created at $outputPath"
    
}


files1_menu

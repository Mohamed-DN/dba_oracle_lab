param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

$haDir = Join-Path $RepositoryRoot "docs\02_core_dba\04_high_availability_and_rac"
$projectDir = Join-Path $haDir "SHAMS_PROJECT"
$artifactDir = Join-Path $RepositoryRoot "artifacts\shams_project"

$fullSources = @(
    (Join-Path $projectDir "GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md"),
    (Join-Path $projectDir "GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md")
)
$runSources = @(
    (Join-Path $projectDir "RUN_SHEET_01_M24SHAMS_SINGLE_NON_CDB.md")
)
$portfolioSources = @(
    (Join-Path $projectDir "GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md"),
    (Join-Path $projectDir "GUIDA_02_M24SHAMS_SINGLE_CDB_DATAGUARD_OBSERVER.md"),
    (Join-Path $projectDir "GUIDA_03_M24SHAMS_RAC_NON_CDB_DATAGUARD_OBSERVER.md"),
    (Join-Path $projectDir "GUIDA_04_M24SHAMS_RAC_CDB_DATAGUARD_OBSERVER.md"),
    (Join-Path $projectDir "GUIDA_05_OBSERVER_FSFO_PEYTECH.md"),
    (Join-Path $projectDir "GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md"),
    (Join-Path $projectDir "GUIDA_07_HOST_RAC_GRID_ASM_19C.md"),
    (Join-Path $projectDir "GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md")
)
$variantRunSources = @(
    (Join-Path $projectDir "RUN_SHEET_02_SHAMS_PROJECT_VARIANTI.md")
)

New-Item -ItemType Directory -Force -Path $artifactDir | Out-Null

function Get-CleanText {
    param([string]$Text)

    $clean = $Text
    $clean = $clean -replace '\*\*', ''
    $clean = $clean.Replace([string][char]0x60, '')
    $clean = $clean -replace '\[([^\]]+)\]\([^)]+\)', '$1'
    $clean = $clean -replace '^\s*>\s*', ''
    return $clean
}

function Add-Paragraph {
    param(
        $Document,
        [string]$Text,
        [string]$Style = "Normal"
    )

    $paragraph = $Document.Paragraphs.Add()
    $paragraph.Range.Text = (Get-CleanText $Text)
    $paragraph.Range.Style = $Style
    $paragraph.Range.InsertParagraphAfter()
}

function Add-CodeBlock {
    param(
        $Document,
        [System.Collections.Generic.List[string]]$Lines
    )

    if ($Lines.Count -eq 0) {
        return
    }

    $paragraph = $Document.Paragraphs.Add()
    $paragraph.Range.Text = ($Lines -join "`r")
    $paragraph.Range.Font.Name = "Consolas"
    $paragraph.Range.Font.Size = 7
    $paragraph.Range.Shading.BackgroundPatternColor = 0xF2F2F2
    $paragraph.Range.ParagraphFormat.SpaceAfter = 4
    $paragraph.Range.InsertParagraphAfter()
}

function ConvertTo-TableCells {
    param([string]$Line)

    return @(
        $Line.Trim().Trim([char]"|").Split("|") |
            ForEach-Object { (Get-CleanText $_.Trim()) }
    )
}

function Add-MarkdownTable {
    param(
        $Document,
        [System.Collections.Generic.List[string]]$Lines
    )

    if ($Lines.Count -lt 2) {
        foreach ($line in $Lines) {
            Add-Paragraph -Document $Document -Text $line
        }
        return
    }

    $dataRows = [System.Collections.Generic.List[object]]::new()
    foreach ($line in $Lines) {
        if ($line -match "^\|\s*:?-{3,}") {
            continue
        }
        $dataRows.Add((ConvertTo-TableCells $line))
    }

    if ($dataRows.Count -eq 0) {
        return
    }

    $columns = $dataRows[0].Count
    $range = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
    $table = $Document.Tables.Add($range, $dataRows.Count, $columns)
    $table.Style = "Table Grid"
    $table.AllowAutoFit = $true
    $table.AutoFitBehavior(2)

    for ($row = 0; $row -lt $dataRows.Count; $row++) {
        for ($column = 0; $column -lt $columns; $column++) {
            $cell = $table.Cell($row + 1, $column + 1)
            $cell.Range.Text = $dataRows[$row][$column]
            $cell.Range.Font.Name = "Aptos"
            $cell.Range.Font.Size = 7.5
            if ($row -eq 0) {
                $cell.Range.Font.Bold = $true
                $cell.Shading.BackgroundPatternColor = 0xE6E6E6
            }
        }
    }

    $range = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
    $range.InsertParagraphAfter()
}

function Set-DocumentStyle {
    param(
        $Document,
        [string]$HeaderText
    )

    $Document.PageSetup.TopMargin = 42
    $Document.PageSetup.BottomMargin = 42
    $Document.PageSetup.LeftMargin = 48
    $Document.PageSetup.RightMargin = 48

    $normal = $Document.Styles.Item("Normal")
    $normal.Font.Name = "Aptos"
    $normal.Font.Size = 9
    $normal.ParagraphFormat.SpaceAfter = 3

    foreach ($name in @("Title", "Heading 1", "Heading 2", "Heading 3")) {
        $style = $Document.Styles.Item($name)
        $style.Font.Name = "Aptos Display"
        $style.Font.Color = 0x753B00
        $style.ParagraphFormat.SpaceBefore = 6
        $style.ParagraphFormat.SpaceAfter = 3
    }

    $Document.Styles.Item("Title").Font.Size = 20
    $Document.Styles.Item("Heading 1").Font.Size = 15
    $Document.Styles.Item("Heading 2").Font.Size = 12
    $Document.Styles.Item("Heading 3").Font.Size = 10

    $header = $Document.Sections.Item(1).Headers.Item(1).Range
    $header.Text = $HeaderText
    $header.Font.Name = "Aptos"
    $header.Font.Size = 8
    $header.ParagraphFormat.Alignment = 1

    $footer = $Document.Sections.Item(1).Footers.Item(1).Range
    $footer.Text = "SHAMS PROJECT | Oracle 19c Data Guard | Documento operativo"
    $footer.Font.Name = "Aptos"
    $footer.Font.Size = 8
    $footer.ParagraphFormat.Alignment = 1
}

function Add-Markdown {
    param(
        $Document,
        [string]$Path,
        [bool]$AddPageBreak
    )

    if ($AddPageBreak) {
        $range = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
        $range.InsertBreak(7)
    }

    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $index = 0
    $inCode = $false
    $codeLines = [System.Collections.Generic.List[string]]::new()

    while ($index -lt $lines.Count) {
        $line = $lines[$index]

        if ($line -match '^```') {
            if ($inCode) {
                Add-CodeBlock -Document $Document -Lines $codeLines
                $codeLines.Clear()
            }
            $inCode = -not $inCode
            $index++
            continue
        }

        if ($inCode) {
            $codeLines.Add($line)
            $index++
            continue
        }

        if ($line -match "^\|") {
            $tableLines = [System.Collections.Generic.List[string]]::new()
            while ($index -lt $lines.Count -and $lines[$index] -match "^\|") {
                $tableLines.Add($lines[$index])
                $index++
            }
            Add-MarkdownTable -Document $Document -Lines $tableLines
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            $index++
            continue
        }

        $text = $line
        $style = "Normal"

        if ($line -match "^# (.+)$") {
            $text = $Matches[1]
            $style = "Title"
        }
        elseif ($line -match "^## (.+)$") {
            $text = $Matches[1]
            $style = "Heading 1"
        }
        elseif ($line -match "^### (.+)$") {
            $text = $Matches[1]
            $style = "Heading 2"
        }
        elseif ($line -match "^#### (.+)$") {
            $text = $Matches[1]
            $style = "Heading 3"
        }
        elseif ($line -match "^[*-] (.+)$") {
            $text = [char]0x2022 + " " + $Matches[1]
        }

        Add-Paragraph -Document $Document -Text $text -Style $style
        $index++
    }

    if ($codeLines.Count -gt 0) {
        Add-CodeBlock -Document $Document -Lines $codeLines
    }
}

function Export-Package {
    param(
        [string[]]$Sources,
        [string]$DocxPath,
        [string]$PdfPath,
        [string]$Title,
        [string]$HeaderText
    )

    $word = New-Object -ComObject Word.Application
    $word.Visible = $false
    $word.DisplayAlerts = 0

    try {
        $document = $word.Documents.Add()
        Set-DocumentStyle -Document $document -HeaderText $HeaderText

        $first = $true
        foreach ($source in $Sources) {
            Add-Markdown -Document $document -Path $source -AddPageBreak:(-not $first)
            $first = $false
        }

        $document.RemoveDocumentInformation(99)
        $document.SaveAs2($DocxPath, 16)
        $document.ExportAsFixedFormat($PdfPath, 17)
        $document.Close()
    }
    finally {
        $word.Quit()
        [System.Runtime.InteropServices.Marshal]::ReleaseComObject($word) |
            Out-Null
        [GC]::Collect()
        [GC]::WaitForPendingFinalizers()
    }
}

Export-Package `
    -Sources $fullSources `
    -DocxPath (Join-Path $artifactDir "M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.docx") `
    -PdfPath (Join-Path $artifactDir "M24SHAMS_SOP_ENTERPRISE_STAGING_DATAGUARD_NON_CDB.pdf") `
    -Title "M24SHAMS - SOP Enterprise Staging Data Guard Non-CDB" `
    -HeaderText "M24SHAMS | SOP Enterprise Staging Data Guard"

Export-Package `
    -Sources $runSources `
    -DocxPath (Join-Path $artifactDir "M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.docx") `
    -PdfPath (Join-Path $artifactDir "M24SHAMS_RUN_SHEET_STAGING_DATAGUARD.pdf") `
    -Title "M24SHAMS - Run Sheet Staging Data Guard" `
    -HeaderText "M24SHAMS | Run Sheet Staging Data Guard"

Export-Package `
    -Sources $portfolioSources `
    -DocxPath (Join-Path $artifactDir "SHAMS_PROJECT_PORTFOLIO_ENTERPRISE_19C.docx") `
    -PdfPath (Join-Path $artifactDir "SHAMS_PROJECT_PORTFOLIO_ENTERPRISE_19C.pdf") `
    -Title "SHAMS PROJECT - Portfolio Enterprise Oracle 19c Data Guard" `
    -HeaderText "SHAMS PROJECT | Portfolio Enterprise Oracle 19c Data Guard"

Export-Package `
    -Sources $variantRunSources `
    -DocxPath (Join-Path $artifactDir "SHAMS_PROJECT_RUN_SHEET_VARIANTI.docx") `
    -PdfPath (Join-Path $artifactDir "SHAMS_PROJECT_RUN_SHEET_VARIANTI.pdf") `
    -Title "SHAMS PROJECT - Run Sheet Scelta Blueprint" `
    -HeaderText "SHAMS PROJECT | Run Sheet Scelta Blueprint"

Write-Host "Artifact generati in $artifactDir"

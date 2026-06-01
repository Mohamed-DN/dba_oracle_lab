param(
    [string]$RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot "..\..")).Path
)

$ErrorActionPreference = "Stop"

# Documents skill preset: compact_reference_guide.
# Word COM uses points for layout geometry: 468pt = 9360 DXA, 6pt = 120 DXA.
$DesignPreset = "compact_reference_guide"

$haDir = Join-Path $RepositoryRoot "docs\02_core_dba\04_high_availability_and_rac"
$projectDir = Join-Path $haDir "SHAMS_PROJECT"
$artifactDir = Join-Path $RepositoryRoot "artifacts\shams_project"

$fullSources = @(
    (Join-Path $projectDir "GUIDA_00_BASELINE_COMUNE_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_01_M24SHAMS_SINGLE_NON_CDB_DATAGUARD.md"),
    (Join-Path $projectDir "GUIDA_06_HOST_SINGLE_ORACLE_RESTART_ASM_19C.md"),
    (Join-Path $projectDir "GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_09_DATAGUARD_NETWORK_BROKER_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_11_DATAGUARD_EVIDENCE_DRILL_TESTBOOK_PEYTECH_19C.md")
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
    (Join-Path $projectDir "GUIDA_08_DBCA_GUI_FIELD_MATRIX_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_09_DATAGUARD_NETWORK_BROKER_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_10_ACTIVE_DATAGUARD_SERVIZI_ROLE_BASED_PEYTECH_19C.md"),
    (Join-Path $projectDir "GUIDA_11_DATAGUARD_EVIDENCE_DRILL_TESTBOOK_PEYTECH_19C.md")
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
        [string]$Style = "Normal",
        [string]$ListKind = "",
        [bool]$PageBreakBefore = $false
    )

    $paragraph = $Document.Paragraphs.Add()
    $paragraph.Range.Text = (Get-CleanText $Text)
    $paragraph.Range.Style = $Style
    if ($PageBreakBefore) {
        $paragraph.Range.ParagraphFormat.PageBreakBefore = -1
    }
    if ($ListKind -eq "Bullet") {
        $paragraph.Range.ListFormat.ApplyBulletDefault()
    }
    elseif ($ListKind -eq "Number") {
        $paragraph.Range.ListFormat.ApplyNumberDefault()
    }
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
    # Use manual line breaks inside one paragraph so code formatting and
    # shading remain stable across Word and LibreOffice renderers.
    $paragraph.Range.Text = ($Lines -join "`v")
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
        [System.Collections.Generic.List[string]]$Lines,
        [bool]$AppendSeparator = $true
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
    $table.AllowAutoFit = $false
    $table.AutoFitBehavior(0)
    $table.PreferredWidthType = 3
    $table.PreferredWidth = 468
    $table.TopPadding = 4
    $table.BottomPadding = 4
    $table.LeftPadding = 6
    $table.RightPadding = 6
    $columnWidths = switch ($columns) {
        1 { @(468) }
        2 { @(135, 333) }
        3 { @(108, 252, 108) }
        4 { @(72, 180, 126, 90) }
        default {
            $equalWidth = 468 / $columns
            @(1..$columns | ForEach-Object { $equalWidth })
        }
    }
    for ($column = 1; $column -le $columns; $column++) {
        $table.Columns.Item($column).SetWidth([single]$columnWidths[$column - 1], 0)
    }

    for ($row = 0; $row -lt $dataRows.Count; $row++) {
        for ($column = 0; $column -lt $columns; $column++) {
            $cell = $table.Cell($row + 1, $column + 1)
            $cell.Range.Text = $dataRows[$row][$column]
            $cell.Range.Font.Name = "Aptos"
            $cell.Range.Font.Size = 7.5
            if ($row -eq 0) {
                $cell.Range.Font.Bold = $true
                $cell.Shading.BackgroundPatternColor = 0xF5EEE8
            }
        }
    }
    if ($dataRows.Count -ge 12) {
        $table.Rows.Item(1).HeadingFormat = -1
    }

    if ($AppendSeparator) {
        # Insert the separator at the terminal document marker. Appending to
        # the whole document can extend the last table with an empty row.
        $separator = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
        $separator.InsertAfter("`r")
    }
}

function Set-DocumentStyle {
    param(
        $Document,
        [string]$HeaderText
    )

    $Document.PageSetup.TopMargin = 72
    $Document.PageSetup.BottomMargin = 72
    $Document.PageSetup.LeftMargin = 72
    $Document.PageSetup.RightMargin = 72
    $Document.PageSetup.PageWidth = 612
    $Document.PageSetup.PageHeight = 792
    $Document.PageSetup.HeaderDistance = 35
    $Document.PageSetup.FooterDistance = 35

    $normal = $Document.Styles.Item("Normal")
    $normal.Font.Name = "Calibri"
    $normal.Font.Size = 11
    $normal.ParagraphFormat.SpaceAfter = 6
    $normal.ParagraphFormat.LineSpacingRule = 5
    $normal.ParagraphFormat.LineSpacing = 13.75

    foreach ($name in @("Title", "Heading 1", "Heading 2")) {
        $style = $Document.Styles.Item($name)
        $style.Font.Name = "Calibri"
        $style.Font.Color = 0xB5742E
    }
    $Document.Styles.Item("Heading 3").Font.Name = "Calibri"
    $Document.Styles.Item("Heading 3").Font.Color = 0x784D1F

    $Document.Styles.Item("Title").Font.Size = 23
    $Document.Styles.Item("Title").ParagraphFormat.SpaceAfter = 12
    $Document.Styles.Item("Title").ParagraphFormat.KeepWithNext = -1
    $Document.Styles.Item("Heading 1").Font.Size = 16
    $Document.Styles.Item("Heading 1").ParagraphFormat.SpaceBefore = 18
    $Document.Styles.Item("Heading 1").ParagraphFormat.SpaceAfter = 10
    $Document.Styles.Item("Heading 1").ParagraphFormat.KeepWithNext = -1
    $Document.Styles.Item("Heading 2").Font.Size = 13
    $Document.Styles.Item("Heading 2").ParagraphFormat.SpaceBefore = 14
    $Document.Styles.Item("Heading 2").ParagraphFormat.SpaceAfter = 7
    $Document.Styles.Item("Heading 2").ParagraphFormat.KeepWithNext = -1
    $Document.Styles.Item("Heading 3").Font.Size = 12
    $Document.Styles.Item("Heading 3").ParagraphFormat.SpaceBefore = 10
    $Document.Styles.Item("Heading 3").ParagraphFormat.SpaceAfter = 5
    $Document.Styles.Item("Heading 3").ParagraphFormat.KeepWithNext = -1

    $header = $Document.Sections.Item(1).Headers.Item(1).Range
    $header.Text = $HeaderText
    $header.Font.Name = "Calibri"
    $header.Font.Size = 8
    $header.ParagraphFormat.Alignment = 1

    $footer = $Document.Sections.Item(1).Footers.Item(1).Range
    $footer.Text = "SHAMS PROJECT | Oracle 19c Data Guard | Documento operativo | Pagina "
    $footer.Collapse(0)
    $Document.Fields.Add($footer, 33) | Out-Null
    $footer.Font.Name = "Calibri"
    $footer.Font.Size = 8
    $footer.ParagraphFormat.Alignment = 1
}

function Add-Cover {
    param(
        $Document,
        [string]$Title
    )

    $range = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()
    $range.InsertParagraphAfter()

    Add-Paragraph -Document $Document -Text "SHAMS PROJECT" -Style "Heading 2"
    Add-Paragraph -Document $Document -Text $Title -Style "Title"
    Add-Paragraph -Document $Document -Text "Oracle Database 19c | Data Guard Enterprise Blueprint" -Style "Heading 2"
    Add-Paragraph -Document $Document -Text "Documento operativo PEYTECH - verificare sempre blueprint, ambiente, licenze e placeholder prima dell'esecuzione."

    $range = $Document.Range($Document.Content.End - 1, $Document.Content.End - 1)
    $range.InsertBreak(7)
}

function Add-Markdown {
    param(
        $Document,
        [string]$Path,
        [bool]$AddPageBreak
    )

    $lines = @(Get-Content -LiteralPath $Path -Encoding UTF8)
    $index = 0
    $inCode = $false
    # LibreOffice renders a phantom table fragment when PageBreakBefore
    # immediately follows a table. Keep source chapters flowing naturally;
    # title styles are configured with KeepWithNext.
    $pageBreakBefore = $false
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
            $hasMoreContent = $false
            for ($scan = $index; $scan -lt $lines.Count; $scan++) {
                if (-not [string]::IsNullOrWhiteSpace($lines[$scan])) {
                    $hasMoreContent = $true
                    break
                }
            }
            Add-MarkdownTable -Document $Document -Lines $tableLines -AppendSeparator:$hasMoreContent
            continue
        }

        if ([string]::IsNullOrWhiteSpace($line)) {
            $index++
            continue
        }

        $text = $line
        $style = "Normal"
        $listKind = ""

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
            $text = $Matches[1]
            $listKind = "Bullet"
        }
        elseif ($line -match "^\d+\. (.+)$") {
            $text = $Matches[1]
            $listKind = "Number"
        }

        Add-Paragraph -Document $Document -Text $text -Style $style -ListKind $listKind -PageBreakBefore:$pageBreakBefore
        $pageBreakBefore = $false
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
        Add-Cover -Document $document -Title $Title

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

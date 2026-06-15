$script:nHigh=0; $script:nMedium=0; $script:nLow=0; $script:nOK=0
function W($line) {
    Write-Output $line
    if     ($line -match '\[HIGH\]')   { $script:nHigh++   }
    elseif ($line -match '\[MEDIUM\]') { $script:nMedium++ }
    elseif ($line -match '\[LOW\]')    { $script:nLow++    }
    elseif ($line -match '\[OK\]')     { $script:nOK++     }
}

function Invoke-ROT13([string]$s) {
    -join ($s.ToCharArray() | ForEach-Object {
        $c=[int]$_
        if    ($c-ge 65 -and $c-le 90)  {[char](65+(($c-65+13)%26))}
        elseif($c-ge 97 -and $c-le 122) {[char](97+(($c-97+13)%26))}
        else  {$_}
    })
}

$suspectPat  = "cheat|hack|inject|bypass|loader|trainer|aimbot|wallhack|kiddion|ozark|cherax|yimmen|eulen|interwebz|neverlose|aimware|osiris|fatality|onetap|skeet|xenos|dumper|exploit|modmen"
$legitProcs  = @("svchost","csrss","lsass","winlogon","services","smss","wininit","explorer",
                 "dwm","conhost","spoolsv","audiodg","taskhostw","MsMpEng","SearchIndexer",
                 "WmiPrvSE","dllhost","fontdrvhost","sihost","ctfmon","RuntimeBroker")

$allProcs = Get-Process -ErrorAction SilentlyContinue

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
W ""
W "  REEK — Anti-Cheat Scanner AIO v3"
W "  Date : $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')"
W "  PC : $env:COMPUTERNAME  |  User : $env:USERNAME"
if (-not $isAdmin) { W "  [HIGH] ATTENTION : Non execute en tant qu administrateur — resultats incomplets !" }
else { W "  [~] Execution : Administrateur confirme" }
W ""

# ══════════════════════════════════════════════════════════════════════════
W "  01. Prefetch"
$found = $false
try {
    $pfDir = "C:\Windows\Prefetch"
    if (Test-Path $pfDir) {
        $pfFiles = Get-ChildItem $pfDir -Filter "*.pf" -ErrorAction SilentlyContinue
        W "  [~] Total prefetch : $($pfFiles.Count) entrees"
        $cheatPF = $pfFiles | Where-Object {
            $_.Name -match "CHEAT|HACK|INJECT|BYPASS|LOADER|KIDDION|OZARK|CHERAX|EULEN|AIMWARE|INTERWEBZ|NEVERLOSE|OSIRIS|SKEET|ONETAP|FATALITY|XENOS|X64DBG|OLLYDBG|CHEATENGINE|PROCESSHACKER|DNSPY|MINHOOK|DUMPER|TRAINER"
        }
        foreach ($pf in $cheatPF | Sort-Object LastWriteTime -Descending) {
            $exe  = $pf.Name -replace "-[A-F0-9]{8}\.pf$",""
            $last = $pf.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            W "  [HIGH] $exe  (derniere execution : $last)"
            $found = $true
        }
        # Afficher les 25 fichiers prefetch les plus recents
        W "  [~] Derniers programmes executes :"
        foreach ($pf in $pfFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 25) {
            $exe  = $pf.Name -replace "-[A-F0-9]{8}\.pf$",""
            $last = $pf.LastWriteTime.ToString("yyyy-MM-dd HH:mm")
            W "  [~]   $exe — $last"
        }
        $recentPF = $pfFiles | Where-Object { (Get-Date)-$_.LastWriteTime -lt [TimeSpan]::FromDays(30) }
        foreach ($pf in $recentPF | Select-Object -First 80) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($pf.FullName)
                $text  = [System.Text.Encoding]::Unicode.GetString($bytes)
                if ($text -match "\\TEMP\\|\\DOWNLOADS\\|USERS\\PUBLIC\\") {
                    $exe = $pf.Name -replace "-[A-F0-9]{8}\.pf$",""
                    if ($exe -match $suspectPat -or $text -match $suspectPat) {
                        W "  [HIGH] Exec depuis emplacement suspect : $exe  ($($pf.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))"
                        $found = $true
                    }
                }
            } catch {}
        }
        if (-not $found) { W "  [OK] Aucun prefetch suspect detecte" }
    } else { W "  [~] Prefetch inaccessible (admin requis ?)" }
} catch { W "  [~] Erreur : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  02. Amcache"
$found = $false
$amcacheSrc = "C:\Windows\AppCompat\Programs\Amcache.hve"
$amcacheTmp = "$env:TEMP\AmcacheReek.hve"
$amcacheKey = "HKLM\AmcacheReekTmp"
try {
    if (Test-Path $amcacheSrc) {
        $fs  = [System.IO.File]::Open($amcacheSrc,'Open','Read','ReadWrite')
        $buf = New-Object byte[] $fs.Length
        [void]$fs.Read($buf,0,$buf.Length); $fs.Close()
        [System.IO.File]::WriteAllBytes($amcacheTmp,$buf)
        reg load $amcacheKey $amcacheTmp 2>$null | Out-Null
        if ($LASTEXITCODE -eq 0) {
            $invPath = "HKLM:\AmcacheReekTmp\Root\InventoryApplicationFile"
            if (Test-Path $invPath) {
                $entries = Get-ChildItem $invPath -ErrorAction SilentlyContinue
                W "  [~] Entrees Amcache : $($entries.Count)"
                $recent = $entries | Where-Object { (Get-Date)-$_.LastWriteTime -lt [TimeSpan]::FromDays(60) }
                foreach ($e in $recent) {
                    $p = Get-ItemProperty $e.PSPath -ErrorAction SilentlyContinue
                    $name=$p.Name; $pub=$p.Publisher; $isPe=$p.IsPeFile; $isOs=$p.IsOsComponent
                    if (-not $name) { continue }
                    if ($name -match $suspectPat) { W "  [HIGH] Amcache — suspect : $name  (pub: $pub)"; $found=$true }
                    elseif ($isPe -eq 1 -and $isOs -eq 0 -and (-not $pub -or $pub -eq "")) {
                        W "  [MEDIUM] Amcache — binaire sans editeur : $name"; $found=$true
                    }
                }
            }
            [GC]::Collect(); Start-Sleep -Milliseconds 300
            reg unload $amcacheKey 2>$null | Out-Null
        } else { W "  [~] Chargement Amcache echoue (fichier verrouille)" }
        Remove-Item $amcacheTmp -ErrorAction SilentlyContinue
    } else { W "  [~] Amcache.hve introuvable" }
} catch { W "  [~] Erreur Amcache : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun binaire suspect dans Amcache" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  03. Shimcache"
$found = $false
try {
    $shimProp = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCompatCache" -Name AppCompatCache -ErrorAction SilentlyContinue
    if ($shimProp) {
        $raw   = $shimProp.AppCompatCache
        $text  = [System.Text.Encoding]::Unicode.GetString($raw)
        $paths = ($text -split "`0") | Where-Object { $_ -match "^[A-Za-z]:\\" -and $_.Length -gt 5 } | Select-Object -Unique
        W "  [~] Entrees Shimcache : $(($paths|Measure-Object).Count)"
        foreach ($p in $paths) {
            if ($p -match $suspectPat) { W "  [HIGH] Shimcache — cheat : $p"; $found=$true }
            elseif ($p -match "\\Temp\\|\\Downloads\\|Users\\Public\\" -and $p -match "\.exe$") {
                W "  [MEDIUM] Shimcache — emplacement anormal : $p"; $found=$true
            }
        }
        if (-not $found) { W "  [OK] Aucun chemin suspect dans Shimcache" }
    } else { W "  [~] AppCompatCache inaccessible" }
} catch { W "  [~] Erreur Shimcache : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  04. UserAssist"
$found = $false
try {
    $uaBase = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\UserAssist"
    if (Test-Path $uaBase) {
        Get-ChildItem $uaBase -ErrorAction SilentlyContinue | ForEach-Object {
            $ck = Join-Path $_.PSPath "Count"
            if (-not (Test-Path $ck)) { return }
            $props = Get-ItemProperty $ck -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                $decoded = Invoke-ROT13 $_.Name
                $val = $_.Value; $runCount=0; $lastRun=$null
                if ($val -is [byte[]] -and $val.Length -ge 16) {
                    $runCount = [BitConverter]::ToInt32($val,4)
                    $ft = [BitConverter]::ToInt64($val,8)
                    if ($ft -gt 0) { try { $lastRun=[DateTime]::FromFileTimeUtc($ft).ToLocalTime().ToString("yyyy-MM-dd HH:mm") } catch {} }
                }
                if ($decoded -match $suspectPat) {
                    W "  [HIGH] UserAssist suspect : $decoded  [x$runCount, $lastRun]"; $found=$true
                } elseif ($decoded -match "\\Temp\\|\\Downloads\\" -and $decoded -match "\.exe") {
                    W "  [MEDIUM] Exec emplacement anormal : $decoded  [x$runCount]"; $found=$true
                }
            }
        }
    }
} catch { W "  [~] Erreur UserAssist : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune entree UserAssist suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  05. Fichiers recents"
$found = $false
try {
    $recentDir = "$env:APPDATA\Microsoft\Windows\Recent"
    if (Test-Path $recentDir) {
        $recent = Get-ChildItem $recentDir -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending
        W "  [~] Total fichiers recents : $($recent.Count)"
        foreach ($f in $recent | Select-Object -First 100) {
            $name = $f.Name -replace "\.lnk$",""
            if ($name -match $suspectPat) {
                W "  [HIGH] Recent suspect : $name  ($($f.LastWriteTime.ToString('yyyy-MM-dd HH:mm')))"; $found=$true
            } elseif ($name -match "\.(exe|dll|bat|ps1|cmd|vbs)$") {
                W "  [MEDIUM] Executable recent : $name  ($($f.LastWriteTime.ToString('yyyy-MM-dd')))"; $found=$true
            } elseif ($name -match "\.(zip|rar|7z)$") {
                W "  [LOW] Archive recente : $name  ($($f.LastWriteTime.ToString('yyyy-MM-dd')))"
            }
        }
        if (-not $found) { W "  [OK] Aucun fichier suspect dans Recent" }
    }
} catch { W "  [~] Erreur Recent : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  06. Jump Lists"
$found = $false
try {
    $jlDir = "$env:APPDATA\Microsoft\Windows\Recent\AutomaticDestinations"
    if (Test-Path $jlDir) {
        $jlFiles = Get-ChildItem $jlDir -Filter "*.automaticDestinations-ms" -ErrorAction SilentlyContinue
        W "  [~] Jump Lists : $($jlFiles.Count)"
        foreach ($jl in $jlFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 25) {
            try {
                $bytes = [System.IO.File]::ReadAllBytes($jl.FullName)
                $utext = [System.Text.Encoding]::Unicode.GetString($bytes)
                $atext = [System.Text.Encoding]::ASCII.GetString($bytes)
                if ($utext -match $suspectPat -or $atext -match $suspectPat) {
                    W "  [HIGH] Jump List suspect : $($jl.Name)  ($($jl.LastWriteTime.ToString('yyyy-MM-dd')))"; $found=$true
                } elseif ($utext -match "\\Temp\\|\\Downloads\\" -and ($utext -match "\.exe|\.dll")) {
                    W "  [MEDIUM] Jump List — chemin anormal : $($jl.Name)"; $found=$true
                }
            } catch {}
        }
        if (-not $found) { W "  [OK] Aucun Jump List suspect" }
    } else { W "  [~] Dossier Jump Lists inaccessible" }
} catch { W "  [~] Erreur Jump Lists : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  07. BAM"
$found = $false
try {
    $bamBase = "HKLM:\SYSTEM\CurrentControlSet\Services\bam\State\UserSettings"
    if (Test-Path $bamBase) {
        $bamEntries = New-Object 'System.Collections.Generic.List[pscustomobject]'
        Get-ChildItem $bamBase -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS|^Version|^Sequence" } | ForEach-Object {
                $exePath=$_.Name; $val=$_.Value; $ts=$null
                if ($val -is [byte[]] -and $val.Length -ge 8) {
                    try { $ft=[BitConverter]::ToInt64($val,0); if($ft-gt 0){$ts=[DateTime]::FromFileTimeUtc($ft).ToLocalTime().ToString("yyyy-MM-dd HH:mm")} } catch {}
                }
                $bamEntries.Add([pscustomobject]@{Path=$exePath;Time=$ts})
                if ($exePath -match $suspectPat) {
                    W "  [HIGH] BAM — cheat : $exePath  ($ts)"; $found=$true
                } elseif ($exePath -match "\\Temp\\|\\Downloads\\|Users\\Public\\" -and $exePath -match "\.exe") {
                    W "  [MEDIUM] BAM — emplacement anormal : $exePath  ($ts)"; $found=$true
                }
            }
        }
        W "  [~] Total entrees BAM : $($bamEntries.Count)"
        W "  [~] Activite recente (20 derniers) :"
        foreach ($e in $bamEntries | Sort-Object Time -Descending | Select-Object -First 20) {
            $name = Split-Path $e.Path -Leaf
            W "  [~]   $name — $($e.Time)"
        }
    } else { W "  [~] BAM non disponible (admin requis)" }
} catch { W "  [~] Erreur BAM : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune trace BAM suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  08. DAM"
$found = $false
try {
    $damBase = "HKLM:\SYSTEM\CurrentControlSet\Services\dam\State\UserSettings"
    if (Test-Path $damBase) {
        Get-ChildItem $damBase -ErrorAction SilentlyContinue | ForEach-Object {
            $props = Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS|^Version" } | ForEach-Object {
                $exePath=$_.Name; $val=$_.Value; $ts=$null
                if ($val -is [byte[]] -and $val.Length -ge 8) {
                    try { $ft=[BitConverter]::ToInt64($val,0); if($ft-gt 0){$ts=[DateTime]::FromFileTimeUtc($ft).ToLocalTime().ToString("yyyy-MM-dd HH:mm")} } catch {}
                }
                if ($exePath -match $suspectPat) {
                    W "  [HIGH] DAM — cheat : $exePath  ($ts)"; $found=$true
                } elseif ($exePath -match "\\Temp\\|\\Downloads\\" -and $exePath -match "\.exe") {
                    W "  [MEDIUM] DAM — emplacement anormal : $exePath  ($ts)"; $found=$true
                }
            }
        }
    } else { W "  [~] DAM non disponible" }
} catch { W "  [~] Erreur DAM : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune trace DAM suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  09. Dossiers connus"
$found = $false
try {
    @($env:APPDATA,$env:LOCALAPPDATA,$env:ProgramData,$env:TEMP) | Select-Object -Unique | ForEach-Object {
        $dir = $_; if (-not (Test-Path $dir)) { return }
        Get-ChildItem $dir -Directory -ErrorAction SilentlyContinue | ForEach-Object {
            $d = $_
            $isHidden = $d.Attributes -band [System.IO.FileAttributes]::Hidden
            $isRecent = (Get-Date)-$d.CreationTime -lt [TimeSpan]::FromDays(14)
            $isSuspect= $d.Name -match $suspectPat
            if ($isHidden -and $isSuspect) { W "  [HIGH] Dossier cache suspect : $($d.FullName)"; $found=$true }
            elseif ($isHidden) { W "  [MEDIUM] Dossier cache : $($d.FullName)"; $found=$true }
            elseif ($isRecent -and $isSuspect) { W "  [HIGH] Dossier suspect recent : $($d.FullName)  ($($d.CreationTime.ToString('yyyy-MM-dd')))"; $found=$true }
        }
    }
} catch { W "  [~] Erreur dossiers : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun dossier cache ou suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  10. Fichiers connus"
$found = $false
try {
    @($env:APPDATA,$env:LOCALAPPDATA,$env:TEMP,"$env:USERPROFILE\Desktop","$env:USERPROFILE\Documents") | ForEach-Object {
        $loc=$_; if (-not (Test-Path $loc)) { return }
        Get-ChildItem $loc -Include "*.exe","*.dll","*.sys","*.bat","*.ps1" -Recurse -Depth 3 -ErrorAction SilentlyContinue |
            Where-Object { (Get-Date)-$_.LastWriteTime -lt [TimeSpan]::FromDays(30) } | Select-Object -First 40 | ForEach-Object {
                $sig = Get-AuthenticodeSignature $_.FullName -ErrorAction SilentlyContinue
                if ($_.Name -match $suspectPat) {
                    W "  [HIGH] Fichier suspect : $($_.Name)  ($($_.DirectoryName), sig:$($sig.Status))"; $found=$true
                } elseif ($_.Extension -in ".exe",".dll",".sys" -and $sig.Status -eq "NotSigned") {
                    W "  [MEDIUM] Binaire non signe : $($_.Name)  ($($_.DirectoryName))"; $found=$true
                }
            }
    }
} catch { W "  [~] Erreur fichiers : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun fichier suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  11. Fichiers supprimes"
$found = $false
try {
    # fsutil peut bloquer sur gros disque : lancer en job avec timeout 15s
    $usnJob = Start-Job { & fsutil usn readjournal C: /csv 2>$null | Select-String "FileDelete|Rename" | Select-Object -Last 500 }
    $done = $usnJob | Wait-Job -Timeout 15
    if ($done) {
        $usnOut = Receive-Job $usnJob
        $suspDel = $usnOut | Where-Object { $_ -match $suspectPat -or ($_.ToString() -match "\.(exe|dll|sys)" -and $_.ToString() -match "Temp|AppData|Download") }
        W "  [~] USN Journal : $($usnOut.Count) suppressions/renommages recentes"
        foreach ($line in $suspDel | Select-Object -Last 15) {
            $l = $line.ToString(); W "  [MEDIUM] USN — suppression suspecte : $($l.Substring(0,[Math]::Min(120,$l.Length)))"; $found=$true
        }
    } else {
        Stop-Job $usnJob; W "  [~] USN Journal : timeout (journal trop grand, ignore)"
    }
    Remove-Job $usnJob -Force 2>$null
} catch { W "  [~] Erreur USN : $($_.Exception.Message)" }
try {
    $del4663 = Get-WinEvent -FilterHashtable @{LogName='Security';Id=4663;StartTime=(Get-Date).AddHours(-48)} -MaxEvents 100 -ErrorAction SilentlyContinue
    $exeDels  = $del4663 | Where-Object { $_.Message -match "\.exe|\.dll|\.sys" }
    if ($exeDels.Count -gt 5) { W "  [MEDIUM] $($exeDels.Count) executables supprimes (4663, 48h)"; $found=$true }
} catch {}
if (-not $found) { W "  [OK] Aucune suppression suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  12. Corbeille"
$found = $false
try {
    $shell = New-Object -ComObject Shell.Application
    $bin   = $shell.Namespace(0xA)
    if ($bin) {
        $items = $bin.Items(); $total = $items.Count()
        W "  [~] Corbeille : $total element(s)"
        for ($i=0; $i -lt [Math]::Min($total,100); $i++) {
            $item = $items.Item($i); $name = $item.Name
            if ($name -match "\.(exe|dll|sys|bat|ps1)$") {
                if ($name -match $suspectPat) { W "  [HIGH] Executable suspect : $name"; $found=$true }
                else { W "  [MEDIUM] Executable supprime : $name"; $found=$true }
            } elseif ($name -match "\.(zip|rar|7z)$") { W "  [LOW] Archive supprimee : $name" }
        }
    }
} catch {}
Get-ChildItem "C:\`$Recycle.Bin" -Recurse -ErrorAction SilentlyContinue |
    Where-Object { $_.Extension -in ".exe",".dll",".sys",".zip",".rar",".bat" } |
    ForEach-Object {
        if ($_.Name -match $suspectPat) { W "  [HIGH] Corbeille suspect : $($_.Name)"; $found=$true }
        else { W "  [LOW] Corbeille : $($_.Name)" }
    }
if (-not $found) { W "  [OK] Aucun executable suspect dans la corbeille" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  13. Dossiers temporaires"
$found = $false
try {
    @($env:TEMP,$env:TMP,"$env:SystemRoot\Temp","$env:LOCALAPPDATA\Temp") | Select-Object -Unique | ForEach-Object {
        $td=$_; if (-not (Test-Path $td)) { return }
        $allExe = Get-ChildItem $td -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in ".exe",".dll",".sys" }
        W "  [~] $td — $($allExe.Count) binaires"
        $allExe | Where-Object { (Get-Date)-$_.CreationTime -lt [TimeSpan]::FromDays(7) } | ForEach-Object {
            $sig = Get-AuthenticodeSignature $_.FullName -ErrorAction SilentlyContinue
            $age = $_.CreationTime.ToString("yyyy-MM-dd HH:mm")
            if ($_.Name -match $suspectPat) { W "  [HIGH] Temp — suspect : $($_.Name)  ($age)"; $found=$true }
            elseif ($sig.Status -eq "NotSigned") { W "  [MEDIUM] Temp — non signe : $($_.Name)  ($age, $([Math]::Round($_.Length/1KB))KB)"; $found=$true }
            else { W "  [LOW] Temp — exe : $($_.Name)  ($age)" }
        }
        Get-ChildItem $td -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in ".zip",".rar",".7z" -and (Get-Date)-$_.CreationTime -lt [TimeSpan]::FromDays(3) } |
            ForEach-Object { W "  [MEDIUM] Temp — archive : $($_.Name)  ($($_.CreationTime.ToString('yyyy-MM-dd')))"; $found=$true }
    }
} catch { W "  [~] Erreur dossiers temporaires : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun executable suspect dans Temp" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  14. Telechargements"
$found = $false
try {
    $dlDir = "$env:USERPROFILE\Downloads"
    if (Test-Path $dlDir) {
        $dlFiles = Get-ChildItem $dlDir -Recurse -Depth 2 -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in ".exe",".dll",".sys",".zip",".rar",".7z",".msi",".bat",".ps1" }
        W "  [~] Telechargements exe/archives : $($dlFiles.Count)"
        foreach ($dl in $dlFiles | Sort-Object LastWriteTime -Descending | Select-Object -First 40) {
            $sig  = Get-AuthenticodeSignature $dl.FullName -ErrorAction SilentlyContinue
            $zone = Get-Content "$($dl.FullName):Zone.Identifier" -ErrorAction SilentlyContinue
            $web  = [bool]($zone -match "ZoneId=3")
            $age  = $dl.LastWriteTime.ToString("yyyy-MM-dd")
            $size = [Math]::Round($dl.Length/1KB)
            if ($dl.Name -match $suspectPat) {
                W "  [HIGH] DL suspect : $($dl.Name)  ($age, ${size}KB)"; $found=$true
            } elseif ($dl.Extension -in ".exe",".dll" -and $sig.Status -eq "NotSigned" -and $web) {
                W "  [MEDIUM] DL non signe depuis Internet : $($dl.Name)  ($age, ${size}KB)"; $found=$true
            } else {
                W "  [~]   $($dl.Name)  ($age, ${size}KB, internet:$web)"
            }
        }
        if (-not $found) { W "  [OK] Aucun telechargement suspect" }
    } else { W "  [~] Dossier Telechargements introuvable" }
} catch { W "  [~] Erreur telechargements : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  15. Run / RunOnce"
$found = $false
@("HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
  "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run",
  "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce",
  "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run") | ForEach-Object {
    $key=$_; if (-not (Test-Path $key)) { return }
    $props = Get-ItemProperty $key -ErrorAction SilentlyContinue; if (-not $props) { return }
    $props.PSObject.Properties | Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
        $val=[string]$_.Value
        $exePath=($val -replace '^"([^"]+)".*','$1').Trim('"').Split(' ')[0]
        $sig=$null
        if (Test-Path $exePath -ErrorAction SilentlyContinue) { $sig=Get-AuthenticodeSignature $exePath -ErrorAction SilentlyContinue }
        if ($val -match $suspectPat -or $_.Name -match $suspectPat) { W "  [HIGH] Startup suspect : $($_.Name) = $val"; $found=$true }
        elseif ($val -match "\\Temp\\|\\AppData\\Roaming\\(?!Microsoft)") { W "  [HIGH] Startup emplacement anormal : $($_.Name) = $val"; $found=$true }
        elseif ($sig -and $sig.Status -eq "NotSigned") { W "  [MEDIUM] Startup non signe : $($_.Name) = $val"; $found=$true }
        else { W "  [LOW] Startup : $($_.Name)" }
    }
}
@("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
  "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp") | ForEach-Object {
    Get-ChildItem $_ -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.Name -match $suspectPat) { W "  [HIGH] Startup folder : $($_.Name)"; $found=$true }
        else { W "  [LOW] Startup folder : $($_.Name)" }
    }
}
if (-not $found) { W "  [OK] Aucun demarrage automatique suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  16. Services Windows"
$found = $false
try {
    $svcs = Get-WmiObject Win32_Service -ErrorAction SilentlyContinue
    W "  [~] Total services : $($svcs.Count)"
    $svcsRunning = $svcs | Where-Object { $_.State -eq "Running" }
    W "  [~] Services en cours ($($svcsRunning.Count)) :"
    foreach ($svc in $svcsRunning | Sort-Object Name | Select-Object -First 30) {
        W "  [~]   $($svc.Name) — $($svc.DisplayName)"
    }
    foreach ($svc in $svcs) {
        $path=$svc.PathName; if (-not $path) { continue }
        $exePath=($path -replace '^"([^"]+)".*','$1').Trim('"').Split(' ')[0]
        $sig=$null
        if (Test-Path $exePath -ErrorAction SilentlyContinue) { $sig=Get-AuthenticodeSignature $exePath -ErrorAction SilentlyContinue }
        if ($svc.Name -match $suspectPat -or $path -match $suspectPat) { W "  [HIGH] Service suspect : $($svc.Name)  —  $path"; $found=$true }
        elseif ($path -match "\\Temp\\|\\AppData\\") { W "  [HIGH] Service depuis Temp/AppData : $($svc.Name)  —  $path"; $found=$true }
        elseif ($sig -and $sig.Status -eq "NotSigned" -and $svc.StartMode -eq "Auto") { W "  [MEDIUM] Service auto non signe : $($svc.Name)"; $found=$true }
    }
} catch { W "  [~] Erreur services : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun service suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  17. Pilotes installes"
$found = $false
try {
    $drivers = Get-WmiObject Win32_SystemDriver -ErrorAction SilentlyContinue
    W "  [~] Total pilotes : $($drivers.Count)"
    foreach ($drv in $drivers | Where-Object { $_.State -eq "Running" }) {
        $path=$drv.PathName; if (-not $path) { continue }
        $sig = Get-AuthenticodeSignature $path -ErrorAction SilentlyContinue
        $isMS= $sig -and $sig.SignerCertificate -and $sig.SignerCertificate.Subject -match "Microsoft"
        if ($drv.Name -match $suspectPat -or $path -match $suspectPat) { W "  [HIGH] Pilote suspect : $($drv.Name)  —  $path  (sig:$($sig.Status))"; $found=$true }
        elseif ($sig -and $sig.Status -eq "NotSigned") { W "  [MEDIUM] Pilote non signe : $($drv.Name)  —  $path"; $found=$true }
        elseif (-not $isMS -and $sig -and $sig.Status -eq "Valid") { W "  [LOW] Pilote tiers : $($drv.Name)  ($($sig.SignerCertificate.Subject.Split(',')[0]))" }
    }
} catch { W "  [~] Erreur pilotes : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun pilote suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  18. Registre"
$found = $false
try {
    @("HKCU:\Software\Kiddions","HKCU:\Software\Stand","HKCU:\Software\Cherax","HKCU:\Software\2Take1",
      "HKCU:\Software\Eulen","HKCU:\Software\Ozark","HKCU:\Software\YimMenu","HKCU:\Software\Aimware",
      "HKCU:\Software\Interwebz","HKCU:\Software\Neverlose","HKCU:\Software\Osiris","HKCU:\Software\Onetap",
      "HKCU:\Software\Cheat Engine","HKLM:\SOFTWARE\Cheat Engine","HKLM:\SOFTWARE\WinRing0_1_2_0") | ForEach-Object {
        if (Test-Path $_) { W "  [HIGH] Cle cheat : $_"; $found=$true }
    }
    @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
      "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall") | ForEach-Object {
        if (-not (Test-Path $_)) { return }
        Get-ChildItem $_ -ErrorAction SilentlyContinue | ForEach-Object {
            $n=(Get-ItemProperty $_.PSPath -Name DisplayName -ErrorAction SilentlyContinue).DisplayName
            if ($n -match $suspectPat -or $n -match "Cheat Engine|OpenIV|Mod Menu") { W "  [MEDIUM] Uninstall suspect : $n"; $found=$true }
        }
    }
    Get-ChildItem "HKCU:\Software" -ErrorAction SilentlyContinue |
        Where-Object { (Get-Date)-$_.LastWriteTime -lt [TimeSpan]::FromDays(14) -and $_.PSChildName -match $suspectPat } |
        ForEach-Object { W "  [HIGH] Cle HKCU suspecte recente : $($_.PSChildName)  ($($_.LastWriteTime.ToString('yyyy-MM-dd')))"; $found=$true }
} catch { W "  [~] Erreur registre : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun artefact suspect dans le registre" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  19. Programmes installes"
$found = $false
$recent14 = (Get-Date).AddDays(-14)
try {
    @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
      "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall") | ForEach-Object {
        if (-not (Test-Path $_)) { return }
        Get-ChildItem $_ -ErrorAction SilentlyContinue | ForEach-Object {
            $p=Get-ItemProperty $_.PSPath -ErrorAction SilentlyContinue
            $name=$p.DisplayName; $pub=$p.Publisher; $install=$p.InstallDate
            if (-not $name) { return }
            $dt=$null
            if ($install -match "^\d{8}$") { try { $dt=[DateTime]::ParseExact($install,"yyyyMMdd",$null) } catch {} }
            if ($name -match $suspectPat -or $name -match "Cheat Engine|mod menu|hack tool") {
                W "  [HIGH] Programme suspect : $name  ($pub)"; $found=$true
            } elseif ($dt -and $dt -gt $recent14 -and $name -notmatch "Microsoft|Visual C|.NET|DirectX|NVIDIA|Intel|AMD") {
                W "  [LOW] Installe recemment : $name  ($($dt.ToString('yyyy-MM-dd')))"
            }
        }
    }
} catch { W "  [~] Erreur programmes : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun programme suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  20. Processus actifs"
$found = $false
try {
    W "  [~] Processus actifs : $($allProcs.Count)"
    W "  [~] Liste des processus non-systeme :"
    foreach ($p in $allProcs) {
        if ($legitProcs -contains $p.Name) { continue }
        $path = try { $p.MainModule.FileName } catch { $null }
        if (-not $path) {
            W "  [~]   $($p.Name) (PID $($p.Id)) — chemin inaccessible"
            continue
        }
        $sig = Get-AuthenticodeSignature $path -ErrorAction SilentlyContinue
        $unsigned = $sig.Status -eq "NotSigned"
        $isTemp   = $path -match "\\Temp\\|\\AppData\\Roaming\\(?!Microsoft)"
        $mem = [Math]::Round($p.WorkingSet64/1MB)
        if ($p.Name -match $suspectPat -or $path -match $suspectPat) {
            W "  [HIGH] Processus suspect : $($p.Name) (PID $($p.Id))  —  $path"; $found=$true
        } elseif ($isTemp -and $unsigned) {
            W "  [HIGH] Non signe depuis Temp : $($p.Name)  —  $path"; $found=$true
        } elseif ($unsigned -and $p.WorkingSet64 -gt 50MB) {
            W "  [MEDIUM] Non signe ($($mem)MB) : $($p.Name)  —  $path"; $found=$true
        } else {
            $sigStatus = if ($sig) { $sig.Status } else { "?" }
            W "  [~]   $($p.Name) (PID $($p.Id), $($mem)MB) — $sigStatus"
        }
    }
} catch { W "  [~] Erreur processus : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Tous les processus semblent legitimes" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  21. DLL chargees"
$found = $false
try {
    $gameProcs = $allProcs | Where-Object { $_.Name -match "GTA5|FiveM|r5apex|NBA2K|CS2|steam|eac_launcher" }
    foreach ($gp in $gameProcs | Select-Object -First 4) {
        try {
            foreach ($mod in $gp.Modules) {
                $dp=$mod.FileName
                if ($dp -match "\\Temp\\|\\AppData\\Roaming\\(?!Microsoft)|Users\\Public\\") { W "  [HIGH] DLL injectee dans $($gp.Name) : $dp"; $found=$true }
                elseif ($dp -match $suspectPat) { W "  [HIGH] DLL suspecte dans $($gp.Name) : $($mod.ModuleName)"; $found=$true }
            }
        } catch {}
    }
    @("minhook.dll","minhook64.dll","cheat.dll","hack.dll","inject.dll","bypass.dll","loader.dll","aimbot.dll","libmem.dll") | ForEach-Object {
        if (Test-Path "C:\Windows\System32\$_")  { W "  [HIGH] DLL System32 : $_"; $found=$true }
        if (Test-Path "C:\Windows\SysWOW64\$_") { W "  [HIGH] DLL SysWOW64 : $_"; $found=$true }
    }
} catch { W "  [~] Erreur DLL : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune DLL suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  22. Processus anormaux"
$found = $false
$expectedPaths = @{
    "svchost"  ="C:\Windows\System32\svchost.exe";"lsass"="C:\Windows\System32\lsass.exe"
    "csrss"    ="C:\Windows\System32\csrss.exe";"winlogon"="C:\Windows\System32\winlogon.exe"
    "explorer" ="C:\Windows\explorer.exe";"services"="C:\Windows\System32\services.exe"
    "smss"     ="C:\Windows\System32\smss.exe";"wininit"="C:\Windows\System32\wininit.exe"
    "taskhostw"="C:\Windows\System32\taskhostw.exe";"spoolsv"="C:\Windows\System32\spoolsv.exe"
    "dwm"      ="C:\Windows\System32\dwm.exe"
}
try {
    foreach ($p in $allProcs) {
        $exp=$expectedPaths[$p.Name.ToLower()]; if (-not $exp) { continue }
        $actual = try { $p.MainModule.FileName } catch { $null }
        if ($actual -and $actual.ToLower() -ne $exp.ToLower()) {
            W "  [HIGH] Usurpation : $($p.Name) — attendu $exp — reel $actual"; $found=$true
        }
    }
    $sysNames=@("svchost","lsass","csrss","winlogon","explorer","services","smss","wininit")
    foreach ($p in $allProcs) {
        foreach ($sn in $sysNames) {
            if ($p.Name -ne $sn -and $p.Name -like "*$sn*" -and $p.Name.Length -le $sn.Length+2 -and $p.Name.Length -ge $sn.Length) {
                W "  [HIGH] Typosquatting de $sn : $($p.Name) (PID $($p.Id))"; $found=$true
            }
        }
    }
} catch { W "  [~] Erreur processus anormaux : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun processus usurpateur" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  23. Injections detectables"
$found = $false
try {
    $targetProcs = $allProcs | Where-Object { $_.Name -match "GTA5|FiveM|r5apex|NBA2K|CS2|steam" }
    foreach ($tp in $targetProcs) {
        try {
            foreach ($mod in $tp.Modules) {
                $mp=$mod.FileName
                if ($mp -match "\\Temp\\|\\AppData\\Roaming\\(?!Microsoft)|Users\\Public\\") { W "  [HIGH] Injection probable ($($tp.Name)) : $mp"; $found=$true }
                elseif ($mp -notmatch "Steam\\steamapps|Windows\\|Program Files") {
                    $sig=Get-AuthenticodeSignature $mp -ErrorAction SilentlyContinue
                    if ($sig -and $sig.Status -eq "NotSigned") { W "  [MEDIUM] DLL non signee dans $($tp.Name) : $($mod.ModuleName)"; $found=$true }
                }
            }
        } catch {}
    }
    foreach ($p in $allProcs) {
        if ($legitProcs -contains $p.Name) { continue }
        if ($p.MainWindowHandle -ne [IntPtr]::Zero) { continue }
        $path = try { $p.MainModule.FileName } catch { $null }
        if ($path -and $path -match "\\AppData\\Roaming\\(?!Microsoft)|\\Temp\\" -and $path -match "\.exe$") {
            W "  [MEDIUM] Processus cache AppData/Temp : $($p.Name)  —  $path"; $found=$true
        }
    }
} catch { W "  [~] Erreur injections : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune injection detectable" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  24. Handles ouverts"
$found = $false
try {
    $totalHandles = ($allProcs | Measure-Object HandleCount -Sum).Sum
    W "  [~] Total handles systeme : $totalHandles"
    $allProcs | Where-Object { $_.HandleCount -gt 2000 } | Sort-Object HandleCount -Descending | Select-Object -First 10 | ForEach-Object {
        $path = try { $_.MainModule.FileName } catch { "?" }
        $sig  = Get-AuthenticodeSignature $path -ErrorAction SilentlyContinue
        if ($_.HandleCount -gt 5000 -and $sig.Status -eq "NotSigned") { W "  [HIGH] Handles anormaux ($($_.HandleCount)) non signe : $($_.Name)"; $found=$true }
        elseif ($_.HandleCount -gt 3000) { W "  [MEDIUM] Handles eleves ($($_.HandleCount)) : $($_.Name)"; $found=$true }
        else { W "  [LOW] Handles : $($_.Name) ($($_.HandleCount))" }
    }
} catch { W "  [~] Erreur handles : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun handle anormal" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  25. Drivers non signes"
$found = $false
try {
    W "  [~] Analyse des drivers System32 (timeout 60s)..."
    $drvJob = Start-Job {
        Get-ChildItem "C:\Windows\System32\drivers" -Filter "*.sys" -ErrorAction SilentlyContinue | ForEach-Object {
            $sig = Get-AuthenticodeSignature $_.FullName -ErrorAction SilentlyContinue
            if     ($sig.Status -eq "NotSigned")    { "NOTSIGNED:$($_.Name)" }
            elseif ($sig.Status -eq "HashMismatch") { "MISMATCH:$($_.Name)" }
        }
    }
    $done = $drvJob | Wait-Job -Timeout 60
    if ($done) {
        $results = Receive-Job $drvJob
        foreach ($r in $results) {
            if     ($r -like "NOTSIGNED:*") { W "  [HIGH] Driver non signe : $($r.Substring(10))"; $found=$true }
            elseif ($r -like "MISMATCH:*")  { W "  [HIGH] Driver modifie : $($r.Substring(9))";   $found=$true }
        }
    } else {
        Stop-Job $drvJob
        W "  [~] Scan drivers : timeout 60s depasse, ignore"
    }
    Remove-Job $drvJob -Force 2>$null
} catch { W "  [~] Erreur drivers signes : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Tous les drivers System32 sont signes" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  26. Drivers recents"
$found = $false
try {
    $recentDrv = Get-ChildItem "C:\Windows\System32\drivers" -Filter "*.sys" -ErrorAction SilentlyContinue |
        Where-Object { (Get-Date)-$_.LastWriteTime -lt [TimeSpan]::FromDays(30) } | Sort-Object LastWriteTime -Descending
    W "  [~] Drivers modifies (30j) : $($recentDrv.Count)"
    foreach ($d in $recentDrv) {
        $sig = Get-AuthenticodeSignature $d.FullName -ErrorAction SilentlyContinue
        $isMS= $sig -and $sig.SignerCertificate -and $sig.SignerCertificate.Subject -match "Microsoft"
        $age = $d.LastWriteTime.ToString("yyyy-MM-dd")
        if ($d.Name -match $suspectPat) { W "  [HIGH] Driver suspect recent : $($d.Name)  ($age)"; $found=$true }
        elseif ($sig.Status -eq "NotSigned") { W "  [HIGH] Driver recent non signe : $($d.Name)  ($age)"; $found=$true }
        elseif (-not $isMS -and $sig.Status -eq "Valid") { W "  [LOW] Driver tiers recent : $($d.Name)  ($age)" }
    }
} catch { W "  [~] Erreur drivers recents : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun driver suspect recent" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  27. Services noyau"
$found = $false
try {
    $kSvcs = Get-WmiObject Win32_SystemDriver -ErrorAction SilentlyContinue | Where-Object { $_.State -eq "Running" }
    W "  [~] Services noyau actifs : $($kSvcs.Count)"
    $msExcl = @("ntfs","acpi","null","beep","wdfilter","wdnisdrv","wdboot","mssecflt","volmgr","disk","storport","tcpip","fltmgr","ksecdd","msrpc")
    foreach ($svc in $kSvcs) {
        if ($msExcl -contains $svc.Name.ToLower()) { continue }
        $path=$svc.PathName; $sig=$null
        if ($path -and (Test-Path $path)) { $sig=Get-AuthenticodeSignature $path -ErrorAction SilentlyContinue }
        $isMS=$sig -and $sig.SignerCertificate -and $sig.SignerCertificate.Subject -match "Microsoft"
        if ($svc.Name -match $suspectPat) { W "  [HIGH] Service noyau suspect : $($svc.Name)  —  $path"; $found=$true }
        elseif ($sig -and $sig.Status -eq "NotSigned") { W "  [HIGH] Service noyau non signe : $($svc.Name)"; $found=$true }
        elseif (-not $isMS -and $sig -and $sig.Status -eq "Valid") { W "  [LOW] Service noyau tiers : $($svc.Name)  ($($sig.SignerCertificate.Subject.Split(',')[0]))" }
    }
} catch { W "  [~] Erreur services noyau : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun service noyau suspect" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  28. Integrite systeme"
$found = $false
try {
    @("WinDefend","MpsSvc","wscsvc","EventLog","CryptSvc") | ForEach-Object {
        $svc=Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -ne "Running") { W "  [HIGH] Service critique arrete : $_  ($($svc.Status))"; $found=$true }
    }
    $mp = Get-MpComputerStatus -ErrorAction SilentlyContinue
    if ($mp) {
        if (-not $mp.RealTimeProtectionEnabled) { W "  [HIGH] Protection temps reel desactivee"; $found=$true }
        if (-not $mp.AntivirusEnabled)          { W "  [HIGH] Antivirus desactive"; $found=$true }
        if ($mp.TamperProtectionSource -ne "Antimalware") { W "  [HIGH] Tamper Protection : $($mp.TamperProtectionSource)"; $found=$true }
        if (-not $found) { W "  [OK] Defender actif (defs: $($mp.AntivirusSignatureLastUpdated.ToString('yyyy-MM-dd')))" }
        $excl=Get-MpPreference -ErrorAction SilentlyContinue
        if ($excl) {
            foreach ($ep in $excl.ExclusionPath) {
                if ($ep -match "AppData|Temp|Downloads|cheat|hack|GTA|FiveM") { W "  [HIGH] Exclusion Defender suspecte : $ep"; $found=$true }
            }
        }
    }
    try {
        $sb=Confirm-SecureBootUEFI -ErrorAction SilentlyContinue
        if ($sb -eq $false) { W "  [MEDIUM] Secure Boot desactive" }
        elseif ($sb -eq $true) { W "  [OK] Secure Boot actif" }
    } catch {}
} catch { W "  [~] Erreur integrite : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Integrite systeme preservee" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  29. Cache DNS"
$found = $false
try {
    $dnsOut = & ipconfig /displaydns 2>$null
    @("neverlose.cc","aimware.net","interwebz.cc","osiris.cc","onetap.su","fatality.win",
      "skeet.cc","leet.cx","gamesense.pub","pandora.to","kiddions.com","stand.gg","cherax.gg",
      "ozark.gg","hvh.gg","yim.gg","supremacy.cc","ezz.gg") | ForEach-Object {
        if ($dnsOut -match [regex]::Escape($_)) { W "  [HIGH] Domaine cheat resolu : $_"; $found=$true }
    }
    $totalDns = ($dnsOut | Where-Object { $_ -match "Nom d|Record Name" }).Count
    W "  [~] Entrees cache DNS : $totalDns"
    if (-not $found) { W "  [OK] Aucun domaine cheat dans le cache DNS" }
} catch { W "  [~] Erreur cache DNS : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  30. Connexions reseau"
$found = $false
try {
    $conns = Get-NetTCPConnection -ErrorAction SilentlyContinue
    $estab = $conns | Where-Object { $_.State -eq "Established" }
    W "  [~] Connexions TCP etablies : $($estab.Count)"
    foreach ($c in $estab) {
        $proc = $allProcs | Where-Object { $_.Id -eq $c.OwningProcess } | Select-Object -First 1
        $pn   = if ($proc) { $proc.Name } else { "PID $($c.OwningProcess)" }
        if ($proc -and $proc.Name -match $suspectPat) {
            W "  [HIGH] Connexion suspecte : $pn -> $($c.RemoteAddress):$($c.RemotePort)"; $found=$true
        } elseif ($c.RemotePort -gt 50000 -and $proc) {
            $path=try{$proc.MainModule.FileName}catch{$null}
            $sig=if($path){Get-AuthenticodeSignature $path -ErrorAction SilentlyContinue}else{$null}
            if ($sig -and $sig.Status -eq "NotSigned") { W "  [MEDIUM] Port eleve proc non signe : $pn -> $($c.RemoteAddress):$($c.RemotePort)"; $found=$true }
            else { W "  [~]   $pn -> $($c.RemoteAddress):$($c.RemotePort)" }
        } else {
            W "  [~]   $pn -> $($c.RemoteAddress):$($c.RemotePort)"
        }
    }
    $conns | Where-Object { $_.State -eq "Listen" -and $_.LocalPort -notin @(80,443,135,445,139,3389,5040,7680) } | ForEach-Object {
        $lp=$_
        $proc=$allProcs | Where-Object { $_.Id -eq $lp.OwningProcess } | Select-Object -First 1
        $pn=if($proc){$proc.Name}else{"?"}
        if ($pn -match $suspectPat) { W "  [HIGH] Port ecoute suspect : $($lp.LocalPort) ($pn)"; $found=$true }
        else { W "  [~]   Ecoute port $($lp.LocalPort) ($pn)" }
    }
} catch { W "  [~] Erreur connexions : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune connexion suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  31. Pare-feu Windows"
$found = $false
try {
    $rules = Get-NetFirewallRule -ErrorAction SilentlyContinue
    W "  [~] Regles pare-feu : $($rules.Count)"
    foreach ($r in $rules) {
        if ($r.Action -eq "Block" -and $r.DisplayName -match "EasyAntiCheat|BattlEye|Vanguard|FACEIT|EAC|VAC") {
            W "  [HIGH] Anti-cheat bloque : $($r.DisplayName)"; $found=$true
        }
        if ($r.DisplayName -match $suspectPat) { W "  [HIGH] Regle suspecte : $($r.DisplayName)  ($($r.Action)/$($r.Direction))"; $found=$true }
    }
    Get-NetFirewallProfile -ErrorAction SilentlyContinue | Where-Object { $_.Enabled -eq $false } | ForEach-Object {
        W "  [MEDIUM] Profil pare-feu desactive : $($_.Name)"; $found=$true
    }
} catch { W "  [~] Erreur pare-feu : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucune regle pare-feu suspecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  32. Historique reseau"
$found = $false
try {
    $wlan = & netsh wlan show profiles 2>$null
    $profiles = $wlan | Where-Object { $_ -match "All User Profile|Profil de tous les utilisateurs" }
    W "  [~] Profils WiFi : $($profiles.Count)"
    foreach ($p in $profiles | Select-Object -First 10) {
        $pname=($p -split ":")[1].Trim(); W "  [~] WiFi : $pname"
    }
    $netReg = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\NetworkList\Signatures\Unmanaged"
    if (Test-Path $netReg) { W "  [~] Reseaux historiques : $((Get-ChildItem $netReg -ErrorAction SilentlyContinue).Count)" }
    $arp = & arp -a 2>$null | Where-Object { $_ -match "dynamic|dynamique" }
    W "  [~] Entrees ARP : $($arp.Count)"
    # Hosts file
    $hosts = Get-Content "C:\Windows\System32\drivers\etc\hosts" -ErrorAction SilentlyContinue
    foreach ($line in $hosts | Where-Object { $_ -notmatch "^#" -and $_.Trim() -ne "" }) {
        if ($line -match "easy\.ac|battleye\.com|eac\.|vanguard\.|faceit\.com") {
            W "  [HIGH] Hosts bloque anti-cheat : $($line.Trim())"; $found=$true
        } elseif ($line -notmatch "localhost|127\.0\.0\.1|::1") {
            W "  [MEDIUM] Entree hosts non standard : $($line.Trim())"; $found=$true
        }
    }
    if (-not $found) { W "  [OK] Historique reseau examine" }
} catch { W "  [~] Erreur historique reseau : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  33. Outils d'analyse"
$found = $false
$tools = @{
    "x64dbg"        = @("$env:PROGRAMFILES\x64dbg","$env:APPDATA\x64dbg","$env:USERPROFILE\Downloads\x64dbg")
    "OllyDbg"       = @("$env:PROGRAMFILES\OllyDbg")
    "dnSpy"         = @("$env:LOCALAPPDATA\dnSpy","$env:USERPROFILE\Downloads\dnSpy")
    "IDA Pro"       = @("$env:PROGRAMFILES\IDA Pro","$env:PROGRAMFILES(x86)\IDA")
    "ProcessHacker" = @("$env:PROGRAMFILES\Process Hacker 2")
    "Cheat Engine"  = @("$env:PROGRAMFILES\Cheat Engine","$env:PROGRAMFILES(x86)\Cheat Engine")
    "Wireshark"     = @("$env:PROGRAMFILES\Wireshark","$env:PROGRAMFILES(x86)\Wireshark")
    "Fiddler"       = @("$env:LOCALAPPDATA\Programs\Fiddler","$env:PROGRAMFILES\Fiddler 4")
    "ReClass.NET"   = @("$env:USERPROFILE\Downloads\ReClass","$env:USERPROFILE\Desktop\ReClass")
    "HxD"           = @("$env:PROGRAMFILES\HxD")
    "Xenos Injector"= @("$env:USERPROFILE\Downloads\Xenos","$env:USERPROFILE\Desktop\Xenos")
}
foreach ($tool in $tools.GetEnumerator()) {
    $tname=$tool.Key
    $running=$allProcs | Where-Object { $_.Name -match ($tname -replace " ",".*" -replace "\.","\.") } | Select-Object -First 1
    if ($running) { W "  [MEDIUM] Outil en cours : $tname (PID $($running.Id))"; $found=$true }
    foreach ($path in $tool.Value) {
        if (Test-Path $path) { W "  [LOW] Outil installe : $tname  ($path)"; $found=$true }
    }
}
if (Test-Path "C:\Windows\Prefetch") {
    Get-ChildItem "C:\Windows\Prefetch" -Filter "*.pf" -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match "X64DBG|OLLYDBG|WINDBG|DNSPY|IDAQ|CHEATENGINE|PROCESSHACK|WIRESHARK|FIDDLER|RECLASS" } |
        ForEach-Object {
            W "  [LOW] Outil utilise anterieurement : $($_.Name -replace '-[A-F0-9]{8}\.pf$','')  ($($_.LastWriteTime.ToString('yyyy-MM-dd')))"; $found=$true
        }
}
if (-not $found) { W "  [OK] Aucun outil d'analyse detecte" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  34. Virtualisation"
$found = $false
try {
    $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue
    $model=$cs.Model; $mfr=$cs.Manufacturer
    W "  [~] Modele : $mfr $model"
    if ($model -match "VMware|VirtualBox|KVM|QEMU|Parallels|HVM|Xen" -or $mfr -match "VMware|innotek|QEMU|Parallels") {
        W "  [HIGH] Machine virtuelle : $mfr $model"; $found=$true
    }
    @("vmtools","VBoxService","VBoxGuest","vmbus","vmicheartbeat","prl_strg","xenbus") | ForEach-Object {
        $svc=Get-Service -Name $_ -ErrorAction SilentlyContinue
        if ($svc -and $svc.Status -eq "Running") { W "  [HIGH] Service VM actif : $_"; $found=$true }
    }
    @("HKLM:\SOFTWARE\VMware, Inc.","HKLM:\SOFTWARE\Oracle\VirtualBox Guest Additions",
      "HKLM:\SOFTWARE\Microsoft\Virtual Machine\Guest\Parameters") | ForEach-Object {
        if (Test-Path $_) { W "  [MEDIUM] Artefact VM registre : $_"; $found=$true }
    }
    try {
        $hv=Get-ComputerInfo -Property HyperVisorPresent -ErrorAction SilentlyContinue
        if ($hv -and $hv.HyperVisorPresent) { W "  [LOW] Hyperviseur actif (Hyper-V/VBS)" }
    } catch {}
    if (-not $found) { W "  [OK] Aucun indicateur de virtualisation" }
} catch { W "  [~] Erreur virtualisation : $($_.Exception.Message)" }

# ══════════════════════════════════════════════════════════════════════════
W ""; W "  35. Journaux Windows"
$found = $false
try {
    # 7045 — nouveau service (14j)
    $svcEvts = Get-WinEvent -FilterHashtable @{LogName='System';Id=7045;StartTime=(Get-Date).AddDays(-14)} -MaxEvents 30 -ErrorAction SilentlyContinue
    foreach ($e in $svcEvts) {
        $line=$e.Message.Split([char]10)[0].Trim()
        if ($line -match $suspectPat -or $line -match "Temp|AppData") { W "  [HIGH] Service installe (7045) : $line"; $found=$true }
        else { W "  [LOW] Service installe (7045) : $line" }
    }
    # 1102 — journal efface (30j)
    $cleared=Get-WinEvent -FilterHashtable @{LogName='Security';Id=1102;StartTime=(Get-Date).AddDays(-30)} -MaxEvents 5 -ErrorAction SilentlyContinue
    foreach ($e in $cleared) { W "  [HIGH] Journal securite efface le $($e.TimeCreated.ToString('yyyy-MM-dd HH:mm'))"; $found=$true }
    # 4688 — processus suspects (48h)
    $p4688=Get-WinEvent -FilterHashtable @{LogName='Security';Id=4688;StartTime=(Get-Date).AddHours(-48)} -MaxEvents 200 -ErrorAction SilentlyContinue
    foreach ($e in $p4688 | Where-Object { $_.Message -match $suspectPat }) {
        $line=($e.Message -replace '\s+',' ').Trim()
        W "  [HIGH] Processus suspect (4688) : $($line.Substring(0,[Math]::Min(120,$line.Length)))"; $found=$true
    }
    # PowerShell Operational 4104 (3j)
    $ps4104=Get-WinEvent -FilterHashtable @{LogName='Microsoft-Windows-PowerShell/Operational';Id=4104;StartTime=(Get-Date).AddDays(-3)} -MaxEvents 50 -ErrorAction SilentlyContinue
    foreach ($e in $ps4104 | Where-Object { $_.Message -match "IEX|Invoke-Expression|DownloadFile|DownloadString|WebClient" }) {
        W "  [HIGH] Script PS suspect (4104) : $($e.Message.Trim().Substring(0,[Math]::Min(100,$e.Message.Length)))"; $found=$true
    }
    # Crashs anti-cheat (1000, 7j)
    $crashes=Get-WinEvent -FilterHashtable @{LogName='Application';Id=1000;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 50 -ErrorAction SilentlyContinue
    foreach ($c in $crashes | Where-Object { $_.Message -match "EasyAntiCheat|BattlEye|vgc|FACEIT" }) {
        W "  [MEDIUM] Crash anti-cheat : $($c.Message.Split([char]10)[0].Trim())"; $found=$true
    }
    # Driver suspects (219, 7j)
    $drv219=Get-WinEvent -FilterHashtable @{LogName='System';Id=219;StartTime=(Get-Date).AddDays(-7)} -MaxEvents 20 -ErrorAction SilentlyContinue
    foreach ($e in $drv219 | Where-Object { $_.Message -match $suspectPat }) {
        W "  [HIGH] Driver suspect charge (219) : $($e.Message.Split([char]10)[0].Trim())"; $found=$true
    }
} catch { W "  [~] Erreur journaux : $($_.Exception.Message)" }
if (-not $found) { W "  [OK] Aucun evenement suspect dans les journaux" }

# ══ Resume ════════════════════════════════════════════════════════════════
$score = [Math]::Min(100, $script:nHigh*25 + $script:nMedium*8 + $script:nLow*2)
W ""
W "  ─────────────────────────────────────────"
W "  [HIGH] : $($script:nHigh)  |  [MEDIUM] : $($script:nMedium)  |  [LOW] : $($script:nLow)  |  [OK] : $($script:nOK)"
W "  Score : $score / 100"
if    ($score -ge 50)          { W "  [HIGH] CRITIQUE — Evidence forte ($score/100)" }
elseif($script:nHigh -gt 0)   { W "  [HIGH] ATTENTION — Menaces detectees ($score/100)" }
elseif($script:nMedium -gt 2) { W "  [MEDIUM] AVERTISSEMENTS — Verifications recommandees ($score/100)" }
else                           { W "  [OK] Systeme propre — aucune menace ($score/100)" }
W ""
W "  Scan termine."

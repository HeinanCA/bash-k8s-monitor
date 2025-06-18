#!/usr/bin/env bash
set -euo pipefail
source /opt/config.env

csv="$CSV_PATH"
out="$DASH_PATH"
mkdir -p "$out"

# gnuplot template (heredoc into gnuplot)
plot_metric() {
  local col="$1" title="$2" ylab="$3" file="$4"
  gnuplot <<-EOF
    set terminal png size 960,480
    set datafile separator ','
    set timefmt "%s"
    set xdata time
    set format x "%H:%M"
    set xlabel "Time (UTC)"
    set ylabel "$ylab"
    set grid
    set output "$out/$file"
    plot "$csv" using 1:$col with lines title "$title"
EOF
}

plot_metric 2  "CPU (%)"          "Percent"     cpu.png
plot_metric 3  "Memory Used (B)"  "Bytes"       mem.png
plot_metric 5  "Disk Reads/s"     "Sectors"     disk_r.png
plot_metric 6  "Disk Writes/s"    "Sectors"     disk_w.png
plot_metric 7  "Net RX (B)"       "Bytes"       net_rx.png
plot_metric 8  "Net TX (B)"       "Bytes"       net_tx.png
plot_metric 9  "Load 1‑min"       ""            load1.png
plot_metric 10 "Load 5‑min"       ""            load5.png
plot_metric 11 "Load 15‑min"      ""            load15.png

# Generate HTML wrapper
cat >"$out/index.html" <<HTML
<!DOCTYPE html><html lang="en"><head>
<meta charset="utf-8"><title>Bash‑K8s Node Dashboard</title>
<meta http-equiv="refresh" content="30">
<style>body{font-family:sans-serif;background:#111;color:#eee;text-align:center}
img{max-width:95%;margin:5px;border:1px solid #444;border-radius:4px}</style>
</head><body>
<h1>Node Graphs – updated $(date -u +"%Y‑%m‑%d %H:%M:%S UTC")</h1>
$(for f in *.png; do echo "<img src=\"$f\">"; done)
</body></html>
HTML
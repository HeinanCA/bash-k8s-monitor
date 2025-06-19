#!/usr/bin/env bash
set -euo pipefail
source /opt/config.env

csv="$CSV_PATH"
out="$DASH_PATH"
mkdir -p "$out"
echo $out

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

plot_metric 2 "CPU (%)" "Percent" cpu.png
plot_metric 3 "Memory Used (B)" "Bytes" mem.png
plot_metric 5 "Disk Reads/s" "Sectors" disk_r.png
plot_metric 6 "Disk Writes/s" "Sectors" disk_w.png
plot_metric 7 "Net RX (B)" "Bytes" net_rx.png
plot_metric 8 "Net TX (B)" "Bytes" net_tx.png
plot_metric 9 "Load 1‑min" "" load1.png
plot_metric 10 "Load 5‑min" "" load5.png
plot_metric 11 "Load 15‑min" "" load15.png

# Get system info for dashboard
current_time=$(date -u '+%Y-%m-%d %H:%M:%S UTC')
uptime_info=$(uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}' | xargs)
metric_count=$(find "$out" -name "*.png" 2>/dev/null | wc -l)

# Generate modern HTML dashboard
cat >"$out/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>🩺 Bash-K8s Node Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%);
            color: #e2e8f0;
            min-height: 100vh;
            padding: 20px;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        header {
            text-align: center;
            margin-bottom: 40px;
            padding: 30px 0;
        }
        
        h1 {
            font-size: 2.5rem;
            font-weight: 700;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
        }
        
        .subtitle {
            font-size: 1.1rem;
            color: #94a3b8;
            margin-bottom: 15px;
        }
        
        .last-update {
            font-size: 0.9rem;
            color: #64748b;
            display: inline-flex;
            align-items: center;
            gap: 5px;
            background: rgba(255, 255, 255, 0.05);
            padding: 8px 16px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }
        
        .metric-card {
            background: rgba(255, 255, 255, 0.08);
            border-radius: 16px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid rgba(255, 255, 255, 0.1);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .metric-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
            border-color: rgba(102, 126, 234, 0.5);
        }
        
        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: linear-gradient(90deg, #667eea, #764ba2);
            opacity: 0;
            transition: opacity 0.3s ease;
        }
        
        .metric-card:hover::before {
            opacity: 1;
        }
        
        .metric-title {
            font-size: 1.1rem;
            font-weight: 600;
            margin-bottom: 15px;
            display: flex;
            align-items: center;
            gap: 8px;
            color: #f1f5f9;
        }
        
        .metric-icon {
            font-size: 1.2rem;
        }
        
        .metric-card img {
            width: 100%;
            height: auto;
            border-radius: 8px;
            border: 1px solid rgba(255, 255, 255, 0.1);
            transition: transform 0.3s ease;
        }
        
        .metric-card:hover img {
            transform: scale(1.02);
        }
        
        .system-overview {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 15px;
            margin-bottom: 30px;
        }
        
        .overview-card {
            background: rgba(255, 255, 255, 0.05);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            border: 1px solid rgba(255, 255, 255, 0.1);
            transition: all 0.3s ease;
        }
        
        .overview-card:hover {
            background: rgba(255, 255, 255, 0.08);
            transform: translateY(-2px);
        }
        
        .overview-title {
            font-size: 0.9rem;
            color: #94a3b8;
            margin-bottom: 8px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .overview-value {
            font-size: 1.5rem;
            font-weight: 700;
            color: #f1f5f9;
        }
        
        .status-indicator {
            display: inline-block;
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: #10b981;
            margin-right: 8px;
            animation: pulse 2s infinite;
        }
        
        @keyframes pulse {
            0%, 100% { opacity: 1; }
            50% { opacity: 0.5; }
        }
        
        footer {
            text-align: center;
            padding: 30px 0;
            color: #64748b;
            font-size: 0.9rem;
            border-top: 1px solid rgba(255, 255, 255, 0.1);
            margin-top: 40px;
        }
        
        .footer-link {
            color: #667eea;
            text-decoration: none;
            transition: color 0.3s ease;
        }
        
        .footer-link:hover {
            color: #764ba2;
        }
        
        @media (max-width: 768px) {
            .metrics-grid {
                grid-template-columns: 1fr;
            }
            
            h1 {
                font-size: 2rem;
            }
            
            .container {
                padding: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <h1>🩺 Bash-K8s Node Dashboard</h1>
            <div class="subtitle">Real-time system metrics • Zero dependencies</div>
            <div class="last-update">
                <span class="status-indicator"></span>
                Last updated: TIMESTAMP_PLACEHOLDER
            </div>
        </header>
        
        <div class="system-overview">
            <div class="overview-card">
                <div class="overview-title">Node Status</div>
                <div class="overview-value">🟢 Healthy</div>
            </div>
            <div class="overview-card">
                <div class="overview-title">Uptime</div>
                <div class="overview-value">UPTIME_PLACEHOLDER</div>
            </div>
            <div class="overview-card">
                <div class="overview-title">Metrics</div>
                <div class="overview-value">METRIC_COUNT_PLACEHOLDER Active</div>
            </div>
            <div class="overview-card">
                <div class="overview-title">Auto Refresh</div>
                <div class="overview-value">30s</div>
            </div>
        </div>
        
        <div class="metrics-grid">
HTML

# Add metric cards dynamically based on existing PNGs
declare -A metric_info=(
  ["cpu.png"]="🖥️|CPU Usage"
  ["mem.png"]="🧠|Memory Usage"
  ["disk_r.png"]="💾|Disk Reads"
  ["disk_w.png"]="💿|Disk Writes"
  ["net_rx.png"]="📡|Network RX"
  ["net_tx.png"]="📤|Network TX"
  ["load1.png"]="⚖️|Load Average (1m)"
  ["load5.png"]="⚖️|Load Average (5m)"
  ["load15.png"]="⚖️|Load Average (15m)"
)

for png_file in cpu.png mem.png disk_r.png disk_w.png net_rx.png net_tx.png load1.png load5.png load15.png; do
  if [[ -f "$out/$png_file" ]]; then
    IFS='|' read -r icon title <<<"${metric_info[$png_file]}"
    cat >>"$out/index.html" <<EOF
            <div class="metric-card">
                <div class="metric-title">
                    <span class="metric-icon">$icon</span>
                    $title
                </div>
                <img src="$png_file" alt="$title Graph">
            </div>
EOF
  fi
done

# Close HTML structure
cat >>"$out/index.html" <<'HTML'
        </div>
        
        <footer>
            Powered by <a href="https://github.com/HeinanCA/bash-k8s-monitor" class="footer-link">Bash-K8s-Monitor</a> • 
            Built with 💚 by <a href="https://htdevops.top" class="footer-link">HT DevOps</a>
        </footer>
    </div>
</body>
</html>
HTML

# Replace placeholders with actual values
sed -i "s/TIMESTAMP_PLACEHOLDER/$current_time/g" "$out/index.html"
sed -i "s/UPTIME_PLACEHOLDER/$uptime_info/g" "$out/index.html"
sed -i "s/METRIC_COUNT_PLACEHOLDER/$metric_count/g" "$out/index.html"

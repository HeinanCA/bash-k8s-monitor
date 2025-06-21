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
hostname=$(hostname)

# Generate simple HTML dashboard that just shows the PNG images
cat >"$out/index.html" <<'HTML'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="utf-8">
    <title>🩺 System Dashboard</title>
    <meta http-equiv="refresh" content="30">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <style>
        :root {
            --bg-primary: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%);
            --bg-secondary: rgba(255, 255, 255, 0.08);
            --text-primary: #e2e8f0;
            --text-secondary: #94a3b8;
            --border-color: rgba(255, 255, 255, 0.1);
            --gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        }
        
        [data-theme="light"] {
            --bg-primary: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
            --bg-secondary: rgba(0, 0, 0, 0.04);
            --text-primary: #1e293b;
            --text-secondary: #475569;
            --border-color: rgba(0, 0, 0, 0.1);
        }
        
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        
        body {
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: var(--bg-primary);
            color: var(--text-primary);
            min-height: 100vh;
            padding: 20px;
            transition: all 0.3s ease;
        }
        
        .container {
            max-width: 1400px;
            margin: 0 auto;
        }
        
        .header {
            text-align: center;
            margin-bottom: 2rem;
            position: relative;
        }
        
        h1 {
            font-size: 2.5rem;
            font-weight: 700;
            background: var(--gradient-primary);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 1rem;
        }
        
        .theme-toggle {
            position: absolute;
            top: 0;
            right: 0;
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 50%;
            width: 50px;
            height: 50px;
            display: flex;
            align-items: center;
            justify-content: center;
            cursor: pointer;
            font-size: 1.5rem;
            transition: all 0.3s ease;
        }
        
        .theme-toggle:hover {
            transform: scale(1.1);
        }
        
        .status-bar {
            display: flex;
            justify-content: center;
            gap: 2rem;
            margin-bottom: 2rem;
            flex-wrap: wrap;
        }
        
        .status-item {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 8px;
            padding: 0.75rem 1.5rem;
            font-size: 0.9rem;
            color: var(--text-secondary);
        }
        
        .charts-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(500px, 1fr));
            gap: 2rem;
        }
        
        .chart-card {
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 1.5rem;
            transition: all 0.3s ease;
        }
        
        .chart-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px rgba(0, 0, 0, 0.3);
        }
        
        .chart-title {
            font-size: 1.2rem;
            font-weight: 600;
            margin-bottom: 1rem;
            display: flex;
            align-items: center;
            gap: 0.5rem;
            color: var(--text-primary);
        }
        
        .chart-image {
            width: 100%;
            height: auto;
            border-radius: 8px;
            border: 1px solid var(--border-color);
        }
        
        .footer {
            text-align: center;
            margin-top: 2rem;
            padding: 1rem;
            color: var(--text-secondary);
        }
        
        @media (max-width: 768px) {
            .charts-grid {
                grid-template-columns: 1fr;
            }
            
            .status-bar {
                flex-direction: column;
                align-items: center;
            }
            
            h1 {
                font-size: 2rem;
            }
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🩺 System Dashboard</h1>
            <div class="theme-toggle" onclick="toggleTheme()">
                <span id="themeIcon">🌙</span>
            </div>
        </div>
        
        <div class="status-bar">
            <div class="status-item">
                🖥️ Server: HOSTNAME_PLACEHOLDER
            </div>
            <div class="status-item">
                ⏱️ Uptime: UPTIME_PLACEHOLDER
            </div>
            <div class="status-item">
                🔄 Last Update: TIMESTAMP_PLACEHOLDER
            </div>
            <div class="status-item">
                📊 Metrics: METRIC_COUNT_PLACEHOLDER active
            </div>
        </div>
        
        <div class="charts-grid">
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
            <div class="chart-card">
                <div class="chart-title">
                    <span>$icon</span>
                    <span>$title</span>
                </div>
                <img src="$png_file" alt="$title Graph" class="chart-image">
            </div>
EOF
  fi
done

# Close HTML structure
cat >>"$out/index.html" <<'HTML'
        </div>
        
        <div class="footer">
            Auto-refresh every 30 seconds • Generated by Bash System Monitor
            <br>
            Powered by <a href="https://github.com/HeinanCA/bash-k8s-monitor" class="footer-link">Bash-K8s-Monitor</a> • 
            <br>
            Built with 💚 by <a href="https://htdevops.top" class="footer-link">HT DevOps</a>
        </div>
    </div>
    
    <script>
        function toggleTheme() {
            const body = document.body;
            const icon = document.getElementById('themeIcon');
            
            if (body.hasAttribute('data-theme')) {
                body.removeAttribute('data-theme');
                icon.textContent = '🌙';
                localStorage.setItem('theme', 'dark');
            } else {
                body.setAttribute('data-theme', 'light');
                icon.textContent = '☀️';
                localStorage.setItem('theme', 'light');
            }
        }
        
        // Load saved theme
        if (localStorage.getItem('theme') === 'light') {
            document.body.setAttribute('data-theme', 'light');
            document.getElementById('themeIcon').textContent = '☀️';
        }
    </script>
</body>
</html>
HTML

# Replace placeholders with actual values
sed -i "s/HOSTNAME_PLACEHOLDER/$hostname/g" "$out/index.html"
sed -i "s/TIMESTAMP_PLACEHOLDER/$current_time/g" "$out/index.html"
sed -i "s/UPTIME_PLACEHOLDER/$uptime_info/g" "$out/index.html"
sed -i "s/METRIC_COUNT_PLACEHOLDER/$metric_count/g" "$out/index.html"

echo "✅ Simple dashboard generated at $out/index.html"
echo "📊 Displays PNG charts generated by gnuplot"
echo "🔄 Auto-refresh every 30 seconds"
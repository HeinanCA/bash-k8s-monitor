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

# Generate modern HTML dashboard with dark/light mode toggle
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
        
        :root {
            /* Dark mode colors (default) */
            --bg-primary: linear-gradient(135deg, #0f0f23 0%, #1a1a2e 100%);
            --bg-secondary: rgba(255, 255, 255, 0.08);
            --bg-tertiary: rgba(255, 255, 255, 0.05);
            --text-primary: #e2e8f0;
            --text-secondary: #94a3b8;
            --text-tertiary: #64748b;
            --text-accent: #f1f5f9;
            --border-color: rgba(255, 255, 255, 0.1);
            --border-hover: rgba(102, 126, 234, 0.5);
            --card-hover-bg: rgba(255, 255, 255, 0.08);
            --gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --gradient-accent: linear-gradient(90deg, #667eea, #764ba2);
            --shadow-hover: rgba(0, 0, 0, 0.3);
        }
        
        [data-theme="light"] {
            /* Light mode colors */
            --bg-primary: linear-gradient(135deg, #f8fafc 0%, #e2e8f0 100%);
            --bg-secondary: rgba(0, 0, 0, 0.04);
            --bg-tertiary: rgba(0, 0, 0, 0.02);
            --text-primary: #1e293b;
            --text-secondary: #475569;
            --text-tertiary: #64748b;
            --text-accent: #0f172a;
            --border-color: rgba(0, 0, 0, 0.1);
            --border-hover: rgba(102, 126, 234, 0.3);
            --card-hover-bg: rgba(0, 0, 0, 0.06);
            --gradient-primary: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            --gradient-accent: linear-gradient(90deg, #667eea, #764ba2);
            --shadow-hover: rgba(0, 0, 0, 0.1);
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
        
        .theme-toggle {
            position: fixed;
            top: 20px;
            right: 20px;
            background: var(--bg-secondary);
            border: 1px solid var(--border-color);
            border-radius: 50px;
            padding: 8px;
            cursor: pointer;
            display: flex;
            align-items: center;
            gap: 8px;
            transition: all 0.3s ease;
            backdrop-filter: blur(10px);
            z-index: 1000;
        }
        
        .theme-toggle:hover {
            background: var(--card-hover-bg);
            transform: scale(1.05);
        }
        
        .theme-icon {
            width: 24px;
            height: 24px;
            display: flex;
            align-items: center;
            justify-content: center;
            font-size: 16px;
            transition: all 0.3s ease;
        }
        
        .theme-icon.inactive {
            opacity: 0.4;
            transform: scale(0.8);
        }
        
        header {
            text-align: center;
            margin-bottom: 40px;
            padding: 30px 0;
        }
        
        h1 {
            font-size: 2.5rem;
            font-weight: 700;
            background: var(--gradient-primary);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            background-clip: text;
            margin-bottom: 10px;
        }
        
        .subtitle {
            font-size: 1.1rem;
            color: var(--text-secondary);
            margin-bottom: 15px;
        }
        
        .last-update {
            font-size: 0.9rem;
            color: var(--text-tertiary);
            display: inline-flex;
            align-items: center;
            gap: 5px;
            background: var(--bg-tertiary);
            padding: 8px 16px;
            border-radius: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid var(--border-color);
        }
        
        .metrics-grid {
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(400px, 1fr));
            gap: 25px;
            margin-bottom: 30px;
        }
        
        .metric-card {
            background: var(--bg-secondary);
            border-radius: 16px;
            padding: 20px;
            backdrop-filter: blur(10px);
            border: 1px solid var(--border-color);
            transition: all 0.3s ease;
            position: relative;
            overflow: hidden;
        }
        
        .metric-card:hover {
            transform: translateY(-5px);
            box-shadow: 0 20px 40px var(--shadow-hover);
            border-color: var(--border-hover);
        }
        
        .metric-card::before {
            content: '';
            position: absolute;
            top: 0;
            left: 0;
            right: 0;
            height: 3px;
            background: var(--gradient-accent);
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
            color: var(--text-accent);
        }
        
        .metric-icon {
            font-size: 1.2rem;
        }
        
        .metric-card img {
            width: 100%;
            height: auto;
            border-radius: 8px;
            border: 1px solid var(--border-color);
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
            background: var(--bg-tertiary);
            border-radius: 12px;
            padding: 20px;
            text-align: center;
            border: 1px solid var(--border-color);
            transition: all 0.3s ease;
        }
        
        .overview-card:hover {
            background: var(--card-hover-bg);
            transform: translateY(-2px);
        }
        
        .overview-title {
            font-size: 0.9rem;
            color: var(--text-secondary);
            margin-bottom: 8px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }
        
        .overview-value {
            font-size: 1.5rem;
            font-weight: 700;
            color: var(--text-accent);
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
            color: var(--text-tertiary);
            font-size: 0.9rem;
            border-top: 1px solid var(--border-color);
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
            
            .theme-toggle {
                top: 10px;
                right: 10px;
            }
        }
    </style>
</head>
<body>
    <div class="theme-toggle" onclick="toggleTheme()">
        <div class="theme-icon" id="darkIcon">🌙</div>
        <div class="theme-icon" id="lightIcon">☀️</div>
    </div>
    
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

# Close HTML structure with JavaScript for theme toggle
cat >>"$out/index.html" <<'HTML'
        </div>
        
        <footer>
            Powered by <a href="https://github.com/HeinanCA/bash-k8s-monitor" class="footer-link">Bash-K8s-Monitor</a> • 
            Built with 💚 by <a href="https://htdevops.top" class="footer-link">HT DevOps</a>
        </footer>
    </div>
    
    <script>
        // Theme toggle functionality
        function toggleTheme() {
            const body = document.body;
            const darkIcon = document.getElementById('darkIcon');
            const lightIcon = document.getElementById('lightIcon');
            
            if (body.hasAttribute('data-theme') && body.getAttribute('data-theme') === 'light') {
                // Switch to dark mode
                body.removeAttribute('data-theme');
                darkIcon.classList.remove('inactive');
                lightIcon.classList.add('inactive');
                localStorage.setItem('theme', 'dark');
            } else {
                // Switch to light mode
                body.setAttribute('data-theme', 'light');
                darkIcon.classList.add('inactive');
                lightIcon.classList.remove('inactive');
                localStorage.setItem('theme', 'light');
            }
        }
        
        // Initialize theme on page load
        function initTheme() {
            const savedTheme = localStorage.getItem('theme');
            const darkIcon = document.getElementById('darkIcon');
            const lightIcon = document.getElementById('lightIcon');
            
            if (savedTheme === 'light') {
                document.body.setAttribute('data-theme', 'light');
                darkIcon.classList.add('inactive');
                lightIcon.classList.remove('inactive');
            } else {
                // Default to dark mode
                darkIcon.classList.remove('inactive');
                lightIcon.classList.add('inactive');
            }
        }
        
        // Initialize theme when page loads
        document.addEventListener('DOMContentLoaded', initTheme);
        
        // Handle theme preference changes from other tabs
        window.addEventListener('storage', function(e) {
            if (e.key === 'theme') {
                initTheme();
            }
        });
    </script>
</body>
</html>
HTML

# Replace placeholders with actual values
sed -i "s/TIMESTAMP_PLACEHOLDER/$current_time/g" "$out/index.html"
sed -i "s/UPTIME_PLACEHOLDER/$uptime_info/g" "$out/index.html"
sed -i "s/METRIC_COUNT_PLACEHOLDER/$metric_count/g" "$out/index.html"

#!/usr/bin/env bash
set -euo pipefail

source /opt/config.env

csv="$CSV_PATH"
mkdir -p "$(dirname "$csv")"

# Initialise header if file is empty
if [[ ! -s $csv ]]; then
  echo "timestamp,cpu_pct,mem_used,mem_total,disk_r_s,disk_w_s,net_rx,net_tx,load1,load5,load15" >"$csv"
fi

# Helpers --------------------------------------------------------------------
read_cpu() { awk '/cpu /{for(i=2;i<=NF;++i)s+=$i; idle=$5; print s,idle}' </proc/stat; }
read_mem() { awk '/MemTotal/{t=$2}/MemAvailable/{a=$2}END{print t-a,t}' </proc/meminfo; }
read_disk() { awk '$3=="sda"{r=$6; w=$10}END{print r,w}' </proc/diskstats; }
read_net() { awk '$1=="eth0:"{rx=$2; tx=$10}END{print rx,tx}' </proc/net/dev; }
read_load() { awk '{print $1,$2,$3}' </proc/loadavg; }

# CPU delta calculation -------------------------------------------------------
read _prev_total _prev_idle < <(read_cpu)
sleep 1
read _total _idle < <(read_cpu)
cpu_pct=$(awk -v t1="$_prev_total" -v i1="$_prev_idle" -v t2="$_total" -v i2="$_idle" \
  'BEGIN{dt=t2-t1; di=i2-i1; printf "%.2f", (dt-di)*100/dt}')

# Other metrics ---------------------------------------------------------------
read mem_used mem_total < <(read_mem)
read disk_r disk_w < <(read_disk)
read net_rx net_tx < <(read_net)
read l1 l5 l15 < <(read_load)

# Write one CSV line ----------------------------------------------------------
printf "%(%s)T,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n" -1 \
  "$cpu_pct" "$mem_used" "$mem_total" "$disk_r" "$disk_w" \
  "$net_rx" "$net_tx" "$l1" "$l5" "$l15" >>"$csv"

# Rotation --------------------------------------------------------------------
lines=$(wc -l <"$csv")
if ((lines > MAX_LINES)); then
  ts=$(date +%s)
  mv "$csv" "${csv%.db}.$ts.bak"
  touch "$csv"
  echo "timestamp,cpu_pct,mem_used,mem_total,disk_r_s,disk_w_s,net_rx,net_tx,load1,load5,load15" >"$csv"
  # Purge old backups
  ls -1tr "${csv%.db}".*.bak 2>/dev/null | head -n -"${MAX_ROTATED_FILES}" | xargs -r rm -f
fi

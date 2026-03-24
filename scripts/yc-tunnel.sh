#!/usr/bin/env bash
set -euo pipefail

# Open an SSH tunnel to a Paperclip VM and open the UI in the browser.
# Runs on your LOCAL machine.
#
# Usage:
#   ./scripts/yc-tunnel.sh <VM_IP> [options]
#
# Options:
#   --user <name>      SSH username (default: ubuntu)
#   --key  <path>      Path to SSH private key
#   --port <port>      Local + remote port (default: 3100)
#   --add-ssh-config   Add Host entry to ~/.ssh/config and exit
#   --fg               Run in foreground instead of background (default: background)
#   --stop             Kill existing tunnel on <port> and exit
#
# Examples:
#   ./scripts/yc-tunnel.sh 51.250.1.100
#   ./scripts/yc-tunnel.sh 51.250.1.100 --user yc-user --key ~/.ssh/yc_key
#   ./scripts/yc-tunnel.sh 51.250.1.100 --add-ssh-config
#   ./scripts/yc-tunnel.sh 51.250.1.100 --stop

# ── Colours ───────────────────────────────────────────────────────────────────
green()  { echo -e "\033[32m$*\033[0m"; }
yellow() { echo -e "\033[33m$*\033[0m"; }
red()    { echo -e "\033[31m$*\033[0m"; }
bold()   { echo -e "\033[1m$*\033[0m"; }

# ── Defaults ──────────────────────────────────────────────────────────────────
VM_IP=""
VM_USER="ubuntu"
SSH_KEY=""
PORT=3100
ADD_CONFIG=false
FOREGROUND=false
STOP_MODE=false

# ── Parse args ────────────────────────────────────────────────────────────────
if [[ $# -eq 0 ]]; then
  red "Usage: $0 <VM_IP> [options]"
  exit 1
fi

# First positional arg is VM_IP
if [[ "$1" != --* ]]; then
  VM_IP="$1"
  shift
fi

while [[ $# -gt 0 ]]; do
  case "$1" in
    --user)           VM_USER="$2"; shift 2 ;;
    --key)            SSH_KEY="$2"; shift 2 ;;
    --port)           PORT="$2"; shift 2 ;;
    --add-ssh-config) ADD_CONFIG=true; shift ;;
    --fg)             FOREGROUND=true; shift ;;
    --stop)           STOP_MODE=true; shift ;;
    *) red "Unknown option: $1"; exit 1 ;;
  esac
done

if [[ -z "$VM_IP" ]]; then
  red "VM_IP is required as the first argument"
  exit 1
fi

SSH_ARGS=(-o StrictHostKeyChecking=accept-new -o ConnectTimeout=10)
[[ -n "$SSH_KEY" ]] && SSH_ARGS+=(-i "$SSH_KEY")
SSH_ARGS+=("${VM_USER}@${VM_IP}")

# ── Stop mode ─────────────────────────────────────────────────────────────────
if [[ "$STOP_MODE" == "true" ]]; then
  PID=$(lsof -ti "TCP:${PORT}" -sTCP:LISTEN 2>/dev/null || true)
  if [[ -n "$PID" ]]; then
    kill "$PID"
    green "Killed tunnel on port ${PORT} (PID ${PID})"
  else
    yellow "No tunnel found on port ${PORT}"
  fi
  exit 0
fi

# ── Add ~/.ssh/config entry ───────────────────────────────────────────────────
if [[ "$ADD_CONFIG" == "true" ]]; then
  SSH_CONFIG="$HOME/.ssh/config"
  HOST_ALIAS="paperclip-vm"

  if grep -q "Host ${HOST_ALIAS}" "$SSH_CONFIG" 2>/dev/null; then
    yellow "Host '${HOST_ALIAS}' already exists in $SSH_CONFIG — skipping"
  else
    mkdir -p "$HOME/.ssh"
    {
      echo ""
      echo "Host ${HOST_ALIAS}"
      echo "    HostName ${VM_IP}"
      echo "    User ${VM_USER}"
      [[ -n "$SSH_KEY" ]] && echo "    IdentityFile ${SSH_KEY}"
      echo "    LocalForward ${PORT} localhost:${PORT}"
      echo "    ServerAliveInterval 60"
    } >> "$SSH_CONFIG"
    chmod 600 "$SSH_CONFIG"
    green "Added Host '${HOST_ALIAS}' to $SSH_CONFIG"
  fi

  echo
  bold "Now you can open the tunnel with:"
  echo "  ssh -fN ${HOST_ALIAS}"
  echo "  Then open: http://localhost:${PORT}"
  exit 0
fi

# ── Check if port already in use ──────────────────────────────────────────────
if lsof -ti "TCP:${PORT}" -sTCP:LISTEN &>/dev/null; then
  yellow "Port ${PORT} is already in use locally."
  yellow "If it's an old tunnel, stop it first:"
  yellow "  $0 ${VM_IP} --stop"
  yellow "Or kill it manually: kill \$(lsof -ti TCP:${PORT})"
  exit 1
fi

# ── Banner ────────────────────────────────────────────────────────────────────
echo
bold "Opening SSH tunnel → ${VM_USER}@${VM_IP}:${PORT}"

# ── Check VM connectivity ─────────────────────────────────────────────────────
if ! ssh -q "${SSH_ARGS[@]}" -o BatchMode=yes exit 2>/dev/null; then
  red "Cannot connect to ${VM_USER}@${VM_IP}"
  red "Check: VM is running, security group allows SSH from your IP, key is correct"
  exit 1
fi

# ── Open tunnel ───────────────────────────────────────────────────────────────
TUNNEL_CMD=(ssh -N -L "${PORT}:localhost:${PORT}" "${SSH_ARGS[@]}")

if [[ "$FOREGROUND" == "true" ]]; then
  green "Tunnel open (foreground) — press Ctrl+C to stop"
  echo "  http://localhost:${PORT}"
  echo
  "${TUNNEL_CMD[@]}"
else
  "${TUNNEL_CMD[@]}" &
  TUNNEL_PID=$!
  disown "$TUNNEL_PID"

  # Give it a moment to establish
  sleep 1

  if ! kill -0 "$TUNNEL_PID" 2>/dev/null; then
    red "Tunnel failed to start — try with --fg to see the error"
    exit 1
  fi

  # Wait for Paperclip to respond through the tunnel
  echo -n "Waiting for Paperclip..."
  READY=false
  for i in $(seq 1 20); do
    if curl -sf "http://localhost:${PORT}/api/health" &>/dev/null; then
      READY=true
      break
    fi
    echo -n "."
    sleep 1
  done
  echo

  echo
  if [[ "$READY" == "true" ]]; then
    green "Tunnel is open (PID ${TUNNEL_PID})"
    green "Paperclip is ready!"
  else
    yellow "Tunnel is open (PID ${TUNNEL_PID})"
    yellow "Paperclip not responding yet — it may still be starting up"
  fi

  echo
  bold "  Open: http://localhost:${PORT}"
  echo
  bold "  Stop tunnel:"
  echo "    $0 ${VM_IP} --stop"
  echo "    # or: kill ${TUNNEL_PID}"
  echo

  # Try to open browser (works on macOS and Linux with xdg-open)
  URL="http://localhost:${PORT}"
  if command -v open &>/dev/null; then
    open "$URL" 2>/dev/null || true
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$URL" 2>/dev/null || true
  fi
fi

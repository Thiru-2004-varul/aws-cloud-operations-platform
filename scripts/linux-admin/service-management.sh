#!/bin/bash

ACTION=${1:-status}
SERVICE=${2:-flask-app}

echo "========== SERVICE MANAGEMENT =========="
echo "Action  : $ACTION"
echo "Service : $SERVICE"
echo "Date    : $(date)"
echo ""

case $ACTION in
  status)
    echo "--- Service Status ---"
    systemctl status $SERVICE --no-pager
    echo ""
    echo "--- Last 20 Log Lines ---"
    journalctl -u $SERVICE --no-pager -n 20
    ;;

  restart)
    echo "Restarting $SERVICE..."
    systemctl restart $SERVICE
    sleep 3
    systemctl status $SERVICE --no-pager
    echo ""
    echo "--- Post-restart health check ---"
    curl -s http://localhost:80/health || echo "Health check failed"
    ;;

  stop)
    echo "Stopping $SERVICE..."
    systemctl stop $SERVICE
    systemctl status $SERVICE --no-pager
    ;;

  start)
    echo "Starting $SERVICE..."
    systemctl start $SERVICE
    sleep 3
    systemctl status $SERVICE --no-pager
    ;;

  all)
    echo "--- All Running Services ---"
    systemctl list-units --type=service --state=running --no-pager
    ;;

  failed)
    echo "--- All Failed Services ---"
    systemctl list-units --type=service --state=failed --no-pager
    ;;

  *)
    echo "Usage: $0 [status|restart|stop|start|all|failed] [service-name]"
    ;;
esac

echo "=========================================="
# AgentOS System Service Definitions

## Hermes Agent Service

File: /etc/systemd/system/hermes-agent.service

```
[Unit]
Description=Hermes AI Agent Service
After=network.target
Wants=network.target

[Service]
Type=simple
User=agent
Group=agent
WorkingDirectory=/home/agent
ExecStart=/usr/local/bin/hermes start
ExecStop=/usr/local/bin/hermes stop
Restart=on-failure
RestartSec=5s

# Security settings
NoNewPrivileges=true
ProtectSystem=strict
ProtectHome=read-only
PrivateTmp=true
ReadWritePaths=/home/agent/.hermes

# Environment
Environment="HERMES_HOME=/home/agent/.hermes"
Environment="PYTHONUNBUFFERED=1"

[Install]
WantedBy=multi-user.target
```

## AgentOS Desktop Service

File: /etc/systemd/system/agentos-desktop.service

```
[Unit]
Description=AgentOS Desktop Environment
After=network.target hermes-agent.service
Wants=hermes-agent.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/gnome-session
ExecStopPost=/bin/sh -c 'pkill -u agent'

[Install]
WantedBy=graphical.target
```
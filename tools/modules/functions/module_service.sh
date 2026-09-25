# service.sh

# internal functions

# Init system: systemd when booted with it (the check sd_booted() uses), otherwise
# sysvinit with /etc/init.d scripts (Devuan / Pivuan).
_srv_is_systemd() { [[ -d /run/systemd/system ]]; }

_srv_system_running()
{
	if _srv_is_systemd; then
		[[ $(systemctl is-system-running) =~ ^(running|degraded)$ ]]
	else
		# sysvinit: a normal runlevel means a live system (in a chroot or container runlevel prints "unknown")
		[[ $(runlevel 2> /dev/null) =~ [[:space:]][1-5]$ ]]
	fi
}

# sysvinit: map unit names to /etc/init.d script names, one per line; options (-*) are dropped and
# units without a script are skipped. "ssh.service" -> ssh, NetworkManager -> network-manager,
# display-manager -> the display manager in /etc/X11/default-display-manager.
_srv_sysv_names()
{
	local unit name
	for unit in "$@"; do
		[[ "$unit" == -* ]] && continue
		name="${unit%.service}"
		case "$name" in
			NetworkManager) name="network-manager" ;;
			display-manager) name="$(basename "$(cat /etc/X11/default-display-manager 2> /dev/null)" 2> /dev/null)" ;;
		esac
		[[ -n "$name" && -x "/etc/init.d/$name" ]] && echo "$name"
	done
}

# sysvinit: run "service <name> <action>" for each unit; fails if any unit has no script or the action fails.
_srv_sysv_service()
{
	local action="$1" name rc=0
	shift
	local names
	names=$(_srv_sysv_names "$@")
	[[ -n "$names" ]] || return 1
	for name in $names; do
		service "$name" "$action" || rc=1
	done
	return $rc
}

# sysvinit: run "update-rc.d <name> <args...>" for each unit.
_srv_sysv_rcd()
{
	local action="$1" name rc=0
	shift
	local names
	names=$(_srv_sysv_names "$@")
	[[ -n "$names" ]] || return 1
	for name in $names; do
		case "$action" in
			enable)
				# "defaults" adds missing links, "enable" turns disabled (K) links back into start links
				update-rc.d "$name" defaults > /dev/null 2>&1
				update-rc.d "$name" enable > /dev/null 2>&1 || rc=1
				;;
			*) update-rc.d "$name" "$action" > /dev/null 2>&1 || rc=1 ;;
		esac
	done
	return $rc
}

declare -A module_options
module_options+=(
	["srv_active,author"]="@dimitry-ishenko"
	["srv_active,desc"]="Check if service is active"
	["srv_active,example"]="srv_active ssh.service"
	["srv_active,feature"]="srv_active"
	["srv_active,status"]="Interface"
)

srv_active()
{
	# fail inside container
	if _srv_is_systemd; then
		_srv_system_running && systemctl is-active --quiet "$@"
	else
		_srv_system_running && _srv_sysv_service status "$@" > /dev/null 2>&1
	fi
}

declare -A module_options
module_options+=(
	["srv_daemon_reload,author"]="@dimitry-ishenko"
	["srv_daemon_reload,desc"]="Reload systemd configuration"
	["srv_daemon_reload,example"]="srv_daemon_reload"
	["srv_daemon_reload,feature"]="srv_daemon_reload"
	["srv_daemon_reload,status"]="Interface"
)

srv_daemon_reload()
{
	# ignore inside container
	# (nothing to reload on sysvinit)
	_srv_is_systemd && _srv_system_running && systemctl daemon-reload || true
}

module_options+=(
	["srv_disable,author"]="@dimitry-ishenko"
	["srv_disable,desc"]="Disable service"
	["srv_disable,example"]="srv_disable ssh.service"
	["srv_disable,feature"]="srv_disable"
	["srv_disable,status"]="Interface"
)

srv_disable()
{
	if _srv_is_systemd; then systemctl disable "$@"; else _srv_sysv_rcd disable "$@"; fi
}

module_options+=(
	["srv_enable,author"]="@dimitry-ishenko"
	["srv_enable,desc"]="Enable service"
	["srv_enable,example"]="srv_enable ssh.service"
	["srv_enable,feature"]="srv_enable"
	["srv_enable,status"]="Interface"
)

srv_enable()
{
	if _srv_is_systemd; then systemctl enable "$@"; else _srv_sysv_rcd enable "$@"; fi
}

module_options+=(
	["srv_enabled,author"]="@dimitry-ishenko"
	["srv_enabled,desc"]="Check if service is enabled"
	["srv_enabled,example"]="srv_enabled ssh.service"
	["srv_enabled,feature"]="srv_enabled"
	["srv_enabled,status"]="Interface"
)

srv_enabled()
{
	if _srv_is_systemd; then
		systemctl is-enabled "$@"
	else
		# like systemctl: print enabled/disabled per unit, succeed only if all are enabled
		local unit name rc=0
		for unit in "$@"; do
			[[ "$unit" == -* ]] && continue
			name=$(_srv_sysv_names "$unit")
			if [[ -n "$name" ]] && compgen -G "/etc/rc[2-5].d/S??${name}" > /dev/null; then
				echo "enabled"
			else
				echo "disabled"
				rc=1
			fi
		done
		return $rc
	fi
}

module_options+=(
	["srv_mask,author"]="@dimitry-ishenko"
	["srv_mask,desc"]="Mask service"
	["srv_mask,example"]="srv_mask ssh.service"
	["srv_mask,feature"]="srv_mask"
	["srv_mask,status"]="Interface"
)

srv_mask()
{
	# sysvinit has no masking; the closest is not starting at boot
	if _srv_is_systemd; then systemctl mask "$@"; else _srv_sysv_rcd disable "$@"; fi
}

module_options+=(
	["srv_reload,author"]="@dimitry-ishenko"
	["srv_reload,desc"]="Reload service"
	["srv_reload,example"]="srv_reload ssh.service"
	["srv_reload,feature"]="srv_reload"
	["srv_reload,status"]="Interface"
)

srv_reload()
{
	# ignore inside container
	if _srv_is_systemd; then
		_srv_system_running && systemctl reload "$@" || true
	else
		_srv_system_running && { _srv_sysv_service reload "$@" 2> /dev/null || _srv_sysv_service force-reload "$@"; } || true
	fi
}

module_options+=(
	["srv_restart,author"]="@dimitry-ishenko"
	["srv_restart,desc"]="Restart service"
	["srv_restart,example"]="srv_restart ssh.service"
	["srv_restart,feature"]="srv_restart"
	["srv_restart,status"]="Interface"
)

srv_restart()
{
	# ignore inside container
	if _srv_is_systemd; then
		_srv_system_running && systemctl restart "$@" || true
	else
		_srv_system_running && _srv_sysv_service restart "$@" || true
	fi
}

module_options+=(
	["srv_start,author"]="@dimitry-ishenko"
	["srv_start,desc"]="Start service"
	["srv_start,example"]="srv_start ssh.service"
	["srv_start,feature"]="srv_start"
	["srv_start,status"]="Interface"
)

srv_start()
{
	# ignore inside container
	if _srv_is_systemd; then
		_srv_system_running && systemctl start "$@" || true
	else
		_srv_system_running && _srv_sysv_service start "$@" || true
	fi
}

module_options+=(
	["srv_status,author"]="@dimitry-ishenko"
	["srv_status,desc"]="Show service status information"
	["srv_status,example"]="srv_status ssh.service"
	["srv_status,feature"]="srv_status"
	["srv_status,status"]="Interface"
)

srv_status()
{
	if _srv_is_systemd; then systemctl status "$@"; else _srv_sysv_service status "$@"; fi
}

module_options+=(
	["srv_stop,author"]="@dimitry-ishenko"
	["srv_stop,desc"]="Stop service"
	["srv_stop,example"]="srv_stop ssh.service"
	["srv_stop,feature"]="srv_stop"
	["srv_stop,status"]="Interface"
)

srv_stop()
{
	# ignore inside container
	if _srv_is_systemd; then
		_srv_system_running && systemctl stop "$@" || true
	else
		_srv_system_running && _srv_sysv_service stop "$@" || true
	fi
}

module_options+=(
	["srv_unmask,author"]="@dimitry-ishenko"
	["srv_unmask,desc"]="Unmask service"
	["srv_unmask,example"]="srv_unmask ssh.service"
	["srv_unmask,feature"]="srv_unmask"
	["srv_unmask,status"]="Interface"
)

srv_unmask()
{
	# sysvinit has no masking (srv_mask disables instead; use srv_enable to undo it)
	if _srv_is_systemd; then systemctl unmask "$@"; else return 0; fi
}

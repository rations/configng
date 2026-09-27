module_options+=(
	["module_networkmanager,author"]="@rations"
	["module_networkmanager,feature"]="module_networkmanager"
	["module_networkmanager,desc"]="Pivuan: switch from ifupdown to NetworkManager, and edit its connections with nmtui"
	["module_networkmanager,example"]="help status switch connections"
	["module_networkmanager,status"]="Active"
	["module_networkmanager,arch"]="arm64 amd64 armhf riscv64"
)
#
# Pivuan (Devuan) networking. The console image runs ifupdown (Ethernet and
# the first-login Wi-Fi network in /etc/network/interfaces.d); desktop installs
# hand the interfaces over to NetworkManager. "switch" does the same handover
# without a desktop, and "connections" opens nmtui (Wi-Fi, Ethernet, fixed
# addresses, DNS, hotspot, bridges).
#
# Usage: module_networkmanager <help|status|switch|connections>
#
function module_networkmanager() {
	local commands
	IFS=' ' read -r -a commands <<< "${module_options["module_networkmanager,example"]}"

	case "$1" in
		"${commands[0]}")
			echo -e "\nUsage: ${module_options["module_networkmanager,feature"]} <command>"
			echo -e "Commands: ${module_options["module_networkmanager,example"]}"
			echo "Available commands:"
			echo -e "\tstatus\t\t- Succeed when NetworkManager manages the network."
			echo -e "\tswitch\t\t- Install NetworkManager and hand the ifupdown interfaces over to it."
			echo -e "\tconnections\t- Edit network connections (nmtui)."
			echo
		;;
		"${commands[1]}")
			# NetworkManager is installed and ifupdown no longer configures an
			# interface from interfaces.d (source-directory only reads names made
			# of letters, digits, - and _).
			pkg_installed network-manager || return 1
			local f
			for f in /etc/network/interfaces.d/*; do
				[[ -f "$f" && "$(basename "$f")" =~ ^[A-Za-z0-9_-]+$ ]] || continue
				awk '$1 == "iface" && $2 != "lo" { found = 1 } END { exit !found }' "$f" && return 1
			done
			return 0
		;;
		"${commands[2]}")
			if [[ "$2" != "--yes" ]] && ! dialog_yesno "Switch to NetworkManager" \
				"NetworkManager will manage Ethernet and Wi-Fi instead of ifupdown. A Wi-Fi network set up in the first-login wizard is carried over.\n\nThe network drops for a few seconds. If you are connected over SSH, reconnect afterwards (the address can change).\n\nAfterwards use Network > Network connections (nmtui) to add or change connections.\n\nContinue?" \
				"Switch" "Cancel" 16 76; then
				return 0
			fi
			# Keep going if the SSH session carrying this terminal goes away.
			trap '' HUP
			if ! pkg_installed network-manager; then
				pkg_update
				pkg_install --no-install-recommends network-manager || { trap - HUP; return 1; }
			fi
			# "mode" is read by the handover: empty means a live system (not an image build).
			# shellcheck disable=SC2034
			local mode="" out
			out=$(_module_desktops_ifupdown_to_networkmanager "${desktops_dir}/networking" 2>&1)
			trap - HUP
			show_message <<< "${out:+${out}\n\n}NetworkManager now manages the network.\nChange connections with Network > Network connections, or run: sudo nmtui"
		;;
		"${commands[3]}")
			if ! command -v nmtui > /dev/null; then
				echo "nmtui not found: switch to NetworkManager first" >&2
				return 1
			fi
			nmtui
		;;
		*)
			module_networkmanager "${commands[0]}"
		;;
	esac
}

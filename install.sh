#!/usr/bin/env bash
set -euo pipefail

repo_url="${REPO_URL:-https://github.com/ledangquangdangquang/UbuntuConfig.git}"
repo_dir="${REPO_DIR:-$HOME/UbuntuConfig}"
profile=""
backup_ext="${HM_BACKUP_EXT:-backup}"

info() {
	printf '\033[1;34m==>\033[0m %s\n' "$*"
}

warn() {
	printf '\033[1;33m==>\033[0m %s\n' "$*"
}

die() {
	printf '\033[1;31merror:\033[0m %s\n' "$*" >&2
	exit 1
}

print_banner() {
	clear || true
	cat <<'EOF'
  _          _                                                     _
 | | ___  __| | __ _ _ __   __ _  __ _ _   _  __ _ _ __   __ _  __| | __ _ _ __   __ _  __ _ _   _  __ _ _ __   __ _
 | |/ _ \/ _` |/ _` | '_ \ / _` |/ _` | | | |/ _` | '_ \ / _` |/ _` |/ _` | '_ \ / _` |/ _` | | | |/ _` | '_ \ / _` |
 | |  __/ (_| | (_| | | | | (_| | (_| | |_| | (_| | | | | (_| | (_| | (_| | | | | (_| | (_| | |_| | (_| | | | | (_| |
 |_|\___|\__,_|\__,_|_| |_|\__, |\__, |\__,_|\__,_|_| |_|\__, |\__,_|\__,_|_| |_|\__, |\__, |\__,_|\__,_|_| |_|\__, |
                           |___/    |_|                  |___/                   |___/    |_|                  |___/
EOF
}

ensure_command() {
	command -v "$1" >/dev/null 2>&1
}

ensure_dependencies() {
	local missing_packages=()

	if ! ensure_command curl; then
		missing_packages+=(curl)
	fi

	if ! ensure_command git; then
		missing_packages+=(git)
	fi

	if ! ensure_command xz; then
		missing_packages+=(xz-utils)
	fi

	if [ "${#missing_packages[@]}" -gt 0 ]; then
		ensure_command sudo || die "sudo is required to install: ${missing_packages[*]}"
		info "Installing missing package(s): ${missing_packages[*]}"
		wait_for_apt
		sudo apt-get update
		wait_for_apt
		sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "${missing_packages[@]}"
	fi

	if [ ! -d /etc/ssl/certs ]; then
		warn "Could not find /etc/ssl/certs. If downloads fail, install ca-certificates."
	fi
}

wait_for_apt() {
	local locks=(
		/var/lib/dpkg/lock
		/var/lib/dpkg/lock-frontend
		/var/lib/apt/lists/lock
		/var/cache/apt/archives/lock
	)
	local waited=0
	local max_wait=300

	while sudo fuser "${locks[@]}" >/dev/null 2>&1; do
		if [ "$waited" -ge "$max_wait" ]; then
			die "APT is still locked after ${max_wait}s. Close Software Updater/App Center, then run the install command again."
		fi

		if [ "$waited" -eq 0 ]; then
			warn "APT is busy; waiting for Ubuntu's updater to finish"
		fi

		sleep 5
		waited=$((waited + 5))
	done
}

enable_flakes() {
	local nix_conf="$HOME/.config/nix/nix.conf"

	mkdir -p "$(dirname "$nix_conf")"
	touch "$nix_conf"

	if ! grep -Eq '(^|[[:space:]])nix-command([[:space:]]|$)' "$nix_conf" ||
		! grep -Eq '(^|[[:space:]])flakes([[:space:]]|$)' "$nix_conf"; then
		info "Enabling nix-command and flakes"
		printf '\nexperimental-features = nix-command flakes\n' >>"$nix_conf"
	fi
}

install_i3() {
	ensure_command sudo || die "sudo is required to install i3"
	local keyring_deb="/tmp/sur5r-keyring.deb"
	local version_codename

	version_codename="$(grep '^VERSION_CODENAME=' /etc/os-release | cut -f2 -d=)"

	info "Adding sur5r i3 repository keyring"
	wait_for_apt
	sudo apt-get update
	wait_for_apt
	curl -fsSL "https://debian.sur5r.net/i3/pool/main/s/sur5r-keyring/sur5r-keyring_2025.12.14_all.deb" \
		-o "$keyring_deb" || die "Failed to download sur5r-keyring"
	sudo apt install -y "$keyring_deb"
	rm -f "$keyring_deb"

	info "Adding sur5r i3 source"
	printf '%s\n' "deb [signed-by=/usr/share/keyrings/sur5r-keyring.gpg] http://debian.sur5r.net/i3/ ${version_codename} universe" \
		| sudo tee /etc/apt/sources.list.d/sur5r-i3.list >/dev/null

	info "Installing i3"
	wait_for_apt
	sudo apt-get update
	wait_for_apt
	sudo DEBIAN_FRONTEND=noninteractive apt-get install -y i3
}

load_nix_profile() {
	if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
		# shellcheck disable=SC1091
		. "$HOME/.nix-profile/etc/profile.d/nix.sh"
	fi

	if [ -e "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh" ]; then
		# shellcheck disable=SC1091
		. "/nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh"
	fi
}

install_nix() {
	if ensure_command nix; then
		return
	fi

	info "Installing Nix in single-user mode"
	curl -fsSL https://nixos.org/nix/install | sh -s -- --no-daemon --yes
	load_nix_profile
	ensure_command nix || die "Nix was installed, but the nix command is not available yet. Open a new terminal and run this script again."
}
prepare_repo() {
	if [ -d "$repo_dir/.git" ]; then
		info "Found existing UbuntuConfig at $repo_dir"
		return
	fi
	if [ -e "$repo_dir" ]; then
		die "$repo_dir exists but is not a Git repository"
	fi

	info "Cloning dotfiles into $repo_dir"
	git clone "$repo_url" "$repo_dir"
}

get_target_user() {
	id -un
}

configure_flake_user() {
	local flake_file="$repo_dir/flake.nix"
	local current_user

	profile="$(get_target_user)"
	if [[ ! "$profile" =~ ^[a-z_][a-z0-9_-]*$ ]] || ! getent passwd "$profile" >/dev/null; then
		die "Cannot configure Home Manager for invalid or unknown user: $profile"
	fi

	current_user="$(sed -nE 's/^[[:space:]]*user = "([^"]+)";$/\1/p' "$flake_file")"
	[ -n "$current_user" ] || die "Could not find the user setting in $flake_file"

	if [ "$current_user" != "$profile" ]; then
		info "Configuring flake user: $profile"
		sed -Ei 's/^([[:space:]]*user = ")[^"]+(";)$/\1'"$profile"'\2/' "$flake_file"
	fi
}

verify_repo() {
	if [ ! -f "$repo_dir/flake.nix" ] ||
		[ ! -f "$repo_dir/home.nix" ] ||
		! grep -Fq '"alacritty"' "$repo_dir/modules/dotfiles.nix" ||
		! grep -Eq '^[[:space:]]*alacritty([[:space:]]|$)' "$repo_dir/modules/packages.nix" ||
		[ ! -f "$repo_dir/dotfiles/alacritty/alacritty.toml" ]; then
		die "Repo at $repo_dir does not contain the expected alacritty config. Check that it is on the latest main branch."
	fi

	info "Repo commit: $(git -C "$repo_dir" rev-parse --short HEAD)"
}

switch_home_manager() {
	info "Applying Home Manager profile: $profile"
	if ensure_command home-manager; then
		home-manager switch -b "$backup_ext" --flake "$repo_dir#$profile"
	else
		nix run github:nix-community/home-manager -- switch -b "$backup_ext" --flake "$repo_dir#$profile"
	fi
}

set_default_shell() {
	local zsh_path="$HOME/.nix-profile/bin/zsh"
	local current_shell

	if [ ! -x "$zsh_path" ]; then
		warn "Could not find $zsh_path; skipping default shell change"
		return
	fi

	current_shell="$(getent passwd "$profile" | cut -d: -f7)"
	if [ "$current_shell" = "$zsh_path" ]; then
		info "Default shell is already zsh"
		return
	fi

	if ! grep -Fxq "$zsh_path" /etc/shells; then
		ensure_command sudo || die "sudo is required to add $zsh_path to /etc/shells"
		info "Adding Nix zsh to /etc/shells"
		printf '%s\n' "$zsh_path" | sudo tee -a /etc/shells >/dev/null
	fi

	info "Changing default shell for $profile to zsh"
	chsh -s "$zsh_path" "$profile"
}

main() {
	print_banner
	ensure_dependencies
	install_i3
	install_nix
	enable_flakes
	load_nix_profile
	prepare_repo
	verify_repo
	configure_flake_user
	switch_home_manager
	set_default_shell
	info "Done. Restart your shell if new commands are not available yet."
}

main "$@"

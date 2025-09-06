# shellcheck shell=bash

# shellcheck disable=SC2329,SC2317
info() { printf '\e[1;34minfo:\e[0m  %s\n' "$*" >&2; }
# shellcheck disable=SC2329,SC2317
warn() { printf '\e[1;35mwarn:\e[0m  %s\n' "$*" >&2; }
# shellcheck disable=SC2329,SC2317
error() { printf '\e[1;31merror:\e[0m %s\n' "$*" >&2; }

_status=0
trap "_status=1 _localstatus=\$?" ERR

if (($# == 0)); then
	set -- activate
elif (($# > 1)); then
	error "Too many arguments"
	exit 1
fi

case "$1" in
activate)
	DEACTIVATE=
	;;
deactivate)
	DEACTIVATE=1
	;;
*)
	error "Unknown command '$1'; expected 'activate' or 'deactivate'"
	exit 1
	;;
esac

# Ensure a consistent umask.
umask 0022

# (de)activate smfh manifest
declare _smfhManifest _smfhGcRoot
_smfhOldManifest=$(readlink -f "$_smfhGcRoot")
[[ -e "$_smfhOldManifest" ]] || _smfhOldManifest=

if ((DEACTIVATE)); then
	smfh deactivate "${_smfhOldManifest:-$_smfhManifest}"
else
	if [[ -n "$_smfhOldManifest" ]]; then
		smfh diff "$_smfhManifest" "$_smfhOldManifest" || exit
	else
		smfh activate "$_smfhManifest" || exit
	fi
fi

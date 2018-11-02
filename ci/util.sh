#!/usr/bin/env bash
# Utility script used to interact with a deployment
# @author Tim Rozet (trozet@redhat.com)

VALID_CMDS="undercloud overcloud opendaylight debug-stack mock-detached -h --help"
SSH_OPTIONS=(-o StrictHostKeyChecking=no -o GlobalKnownHostsFile=/dev/null -o UserKnownHostsFile=/dev/null -o LogLevel=error)

##connects to undercloud
##params: user to login with, command to execute on undercloud (optional)
function undercloud_connect {
  local user=$1

  if [ -z "$1" ]; then
    echo "Missing required argument: user to login as to undercloud"
    return 1
  fi

  if [ -z "$2" ]; then
    ssh ${SSH_OPTIONS[@]} ${user}@$(get_undercloud_ip)
  else
    ssh ${SSH_OPTIONS[@]} -T ${user}@$(get_undercloud_ip) "$2"
  fi
}

##outputs the Undercloud's IP address
##params: none
function get_undercloud_ip {
  echo $(arp -an | grep $(virsh domiflist undercloud | grep default |\
    awk '{print $5}') | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")
}

##connects to overcloud nodes
##params: node to login to, command to execute on overcloud (optional)
function overcloud_connect {
  local node
  local node_output
  local node_ip

  if [ -z "$1" ]; then
    echo "Missing required argument: overcloud node to login to"
    return 1
  elif ! echo "$1" | grep -E "(controller|compute)[0-9]+" > /dev/null; then
    echo "Invalid argument: overcloud node to login to must be in the format: \
controller<number> or compute<number>"
    return 1
  fi

  node_output=$(undercloud_connect "stack" "source stackrc; nova list")
  node=$(echo "$1" | sed -E 's/([a-zA-Z]+)([0-9]+)/\1-\2/')

  node_ip=$(echo "$node_output" | grep "$node " | grep -Eo "[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")

  if [ "$node_ip" == "" ]; then
    echo -e "Unable to find IP for ${node} in \n${node_output}"
    return 1
  fi

  if [ -z "$2" ]; then
    ssh ${SSH_OPTIONS[@]} heat-admin@${node_ip}
  else
    ssh ${SSH_OPTIONS[@]} -T heat-admin@${node_ip} "$2"
  fi
}

##connects to opendaylight karaf console
##params: None
function opendaylight_connect {
  local opendaylight_ip
  opendaylight_ip=$(undercloud_connect "stack" "cat overcloudrc | grep SDN_CONTROLLER_IP | grep -Eo [0-9]+\.[0-9]+\.[0-9]+\.[0-9]+")

  if [ "$opendaylight_ip" == "" ]; then
    echo -e "Unable to find IP for OpenDaylight in overcloudrc"
    return 1
  else
    echo -e "Connecting to ODL Karaf console.  Default password is 'karaf'"
  fi

  ssh -p 8101 ${SSH_OPTIONS[@]} karaf@${opendaylight_ip}
}

##outputs heat stack deployment failures
##params: none
function debug_stack {
  source ~/stackrc
  openstack stack failures list overcloud --long
}

resolve_cmd() {
  local given=$1
  shift
  local list=($*)
  local inv=(${list[*]##${given}*})
  local OIFS=$IFS; IFS='|'; local pat="${inv[*]}"; IFS=$OIFS
  shopt -s extglob
  echo "${list[*]##+($pat)}"
  shopt -u extglob
}

display_usage() {
  echo -e "Usage:\n$0 subcommand [ arguments ]\n"
  echo -e "Arguments:\n"
  echo -e "   undercloud [ user [ command ] ]   Connect to Undercloud VM as user and optionally execute a command"
  echo -e "                                     user    Optional: Defaults to 'stack'"
  echo -e "                                     command Optional: Defaults to none"
  echo -e ""
  echo -e "   opendaylight                      Connect to OpenDaylight Karaf console"
  echo -e ""
  echo -e "   overcloud  [ node [ command ] ]   Connect to an Overcloud node and optionally execute a command"
  echo -e "                                     node    Required: in format controller|compute<number>.  Example: controller0"
  echo -e "                                     command Optional: Defaults to none"
  echo -e ""
  echo -e "   debug-stack                       Print parsed deployment failures to stdout"
  echo -e ""
  echo -e "   mock-detached on | off            Add firewall rules to the jump host to mock a detached deployment\n"
}

##translates the command line argument
##params: $@ the entire command line is passed
##usage: parse_cmd_line() "$@"
parse_cmdline() {
  local match

  match=($(resolve_cmd $1 $VALID_CMDS))
  if [ ${#match[*]} -gt 1 ]; then
    echo "$1 is ambiguous, possible matches: ${match[*]}" >&2
    exit 1
  elif [ ${#match[*]} -lt 1 ]; then
    echo "$1 is not a recognized command.  Use -h to see acceptable list" >&2
    exit 1
  else
    match=$(echo $match | tr -d ' ')
  fi

  case "$match" in
        -h|--help)
                display_usage
                exit 0
            ;;
        undercloud)
                if [ -z "$2" ]; then
                  # connect as stack by default
                  undercloud_connect stack
                elif [ -z "$3" ]; then
                  undercloud_connect "$2"
                else
                  undercloud_connect "$2" "$3"
                fi
                exit 0
            ;;
        overcloud)
                if [ -z "$2" ]; then
                  overcloud_connect
                elif [ -z "$3" ]; then
                  overcloud_connect "$2"
                else
                  overcloud_connect "$2" "$3"
                fi
                exit 0
            ;;
        opendaylight)
                opendaylight_connect
                exit 0
            ;;
        debug-stack)
                undercloud_connect stack "$(typeset -f debug_stack); debug_stack"
                exit 0
            ;;
        mock-detached)
                if [ "$2" == "on" ]; then
                    echo "Ensuring we can talk to gerrit.opnfv.org"
                    iptables -A OUTPUT -p tcp -d gerrit.opnfv.org --dport 443 -j ACCEPT
                    echo "Blocking output http (80) traffic"
                    iptables -A OUTPUT -p tcp --dport 80 -j REJECT
                    iptables -A FORWARD -p tcp --dport 80 -j REJECT
                    echo "Blocking output https (443) traffic"
                    iptables -A OUTPUT -p tcp --dport 443 -j REJECT
                    iptables -A FORWARD -p tcp --dport 443 -j REJECT
                    echo "Blocking output dns (53) traffic"
                    iptables -A FORWARD -p tcp --dport 53 -j REJECT
                elif [ "$2" == "off" ]; then
                    echo "Cleaning gerrit.opnfv.org specific rule"
                    iptables -D OUTPUT -p tcp -d gerrit.opnfv.org --dport 443 -j ACCEPT
                    echo "Allowing output http (80) traffic"
                    iptables -D OUTPUT -p tcp --dport 80 -j REJECT
                    iptables -D FORWARD -p tcp --dport 80 -j REJECT
                    echo "Allowing output https (443) traffic"
                    iptables -D OUTPUT -p tcp --dport 443 -j REJECT
                    iptables -D FORWARD -p tcp --dport 443 -j REJECT
                    echo "Allowing output dns (53) traffic"
                    iptables -D OUTPUT -p tcp --dport 53 -j REJECT
                    iptables -D FORWARD -p tcp --dport 53 -j REJECT
                else
                    display_usage
                fi
                exit 0
            ;;
        *)
                echo -e "\n\nThis script is used to interact with Apex deployments\n\n"
                echo "Use -h to display help"
                exit 1
            ;;
  esac
}


main() {
  parse_cmdline "$@"
}

main "$@"

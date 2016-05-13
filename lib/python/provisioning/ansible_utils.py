import logging

from tempfile import NamedTemporaryFile

import ansible
import ansible.playbook
from ansible.playbook import PlayBook
from ansible.callbacks import AggregateStats
from ansible.callbacks import PlaybookRunnerCallbacks
from ansible.callbacks import PlaybookCallbacks
from ansible import utils

logger = logging.getLogger('ansible_utils')


def apply_playbook(playbook_path, hosts_inv, host_user, ssh_priv_key_file_path, variables=None):
    """
    Executes an Ansible playbook to the given host
    :param hosts_inv: a list of hostnames/ip addresses to which to apply the Ansible playbook
    :param playbook_path: the (relative) path to the Ansible playbook
    :param variables: a dictionary containing any variables needed by the Jinga 2 templates
    :return: None
    """
    hosts_inv = __create_inventory(hosts_inv, variables)
    logger.info("Hosts Inventory for applying playbook - " + hosts_inv)

    stats = AggregateStats()
    run_cb = PlaybookRunnerCallbacks(stats, verbose=utils.VERBOSITY)
    pb_cb = PlaybookCallbacks(verbose=utils.VERBOSITY)

    # TODO - need to find a better means of finding this playbook.
    runner = PlayBook(playbook=playbook_path, host_list=hosts_inv, remote_user=host_user,
                      private_key_file=ssh_priv_key_file_path, callbacks=pb_cb, runner_callbacks=run_cb, stats=stats)
    # TODO - check status and log
    data = runner.run()
    return data


def __create_inventory(hosts, variables):
    """
    Returns an inventory object to be used by the playbook
    :param hosts: a list of hostnames/IPs
    :param variables: a dictionary of substitution variables
    :return: the value to place into the PlayBook's constructor argument host_list
    """
    inventory_contents = "[this]"
    for host in hosts:
        inventory_contents += '\n' + host

    if variables and len(variables) > 0:
        inventory_contents += '\n[this:vars]'
        for key, value in variables.iteritems():
            inventory_contents += '\n' + key + '=' + value

    hosts = NamedTemporaryFile(delete=False)
    hosts.write(inventory_contents)
    hosts.close()

    return hosts.name

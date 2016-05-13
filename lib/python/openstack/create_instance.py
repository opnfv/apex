import time
import logging
import re

from paramiko import SSHClient
import paramiko

import nova_utils

logger = logging.getLogger('create_instance')

VM_BOOT_TIMEOUT = 1200
POLL_INTERVAL = 3


class OpenStackVmInstance:
    """
    Class responsible for creating a VM instance in OpenStack
    """

    def __init__(self, os_creds, name, flavor, image_creator, ports, remote_user, keypair_creator=None,
                 floating_ip_conf=None, userdata=None):
        """
        Constructor
        :param os_creds: The connection credentials to the OpenStack API
        :param name: The name of the OpenStack instance to be deployed
        :param flavor: The size of the VM to be deployed (i.e. 'm1.small')
        :param image_creator: The object responsible for creating the OpenStack image on which to deploy the VM
        :param ports: List of ports (NICs) to deploy to the VM
        :param remote_user: The sudo user
        :param keypair_creator: The object responsible for creating the keypair for this instance (Optional)
        :param floating_ip_conf: The configuration for the addition of a floating IP to an instance (Optional)
        :param userdata: The post installation script as a string or a file object (Optional)
        :raises Exception
        """
        self.os_creds = os_creds
        self.name = name
        self.image_creator = image_creator
        self.ports = ports
        self.remote_user = remote_user
        self.keypair_creator = keypair_creator
        self.floating_ip_conf = floating_ip_conf
        self.floating_ip = None
        self.userdata = userdata
        self.vm = None
        self.nova = nova_utils.nova_client(os_creds)

        # Validate that the flavor is supported
        self.flavor = self.nova.flavors.find(name=flavor)
        if not self.flavor:
            raise Exception

    def create(self):
        """
        Creates a VM instance
        :return: The VM reference object
        """
        # TODO - need to query instances and not deploy if one exists
        servers = self.nova.servers.list()
        for server in servers:
            if server.name == self.name:
                self.vm = server
                logger.info('Found existing machine with name - ' + self.name)
                return self.vm

        nics = []
        for port in self.ports:
            kv = dict()
            kv['port-id'] = port['port']['id']
            nics.append(kv)

        logger.info('Creating VM with name - ' + self.name)
        keypair_name = None
        if self.keypair_creator:
            keypair_name = self.keypair_creator.keypair_settings.name

        self.vm = self.nova.servers.create(
            name=self.name,
            flavor=self.flavor,
            image=self.image_creator.image,
            nics=nics,
            key_name=keypair_name,
            userdata=self.userdata)

        logger.info('Created instance with name - ' + self.name)

        if self.floating_ip_conf:
            for port in self.ports:
                if port['port']['name'] == self.floating_ip_conf['port_name']:
                    self.floating_ip = nova_utils.create_floating_ip(self.nova, self.floating_ip_conf['ext_net'])
                    logger.info('Created floating IP ' + self.floating_ip.ip)
                    self._add_floating_ip(port['port']['dns_assignment'][0]['ip_address'])

        return self.vm

    def clean(self):
        """
        Destroys the VM instance
        """

        if self.vm:
            try:
                self.nova.servers.delete(self.vm)
            except Exception as e:
                logger.error('Error deleting VM')

        if self.floating_ip:
            try:
                nova_utils.delete_floating_ip(self.nova, self.floating_ip)
            except Exception as e:
                logger.error('Error deleting Floating IP')

    def _add_floating_ip(self, port_ip, timeout=30, poll_interval=POLL_INTERVAL):
        """
        Returns True when active else False
        TODO - Make timeout and poll_interval configurable...
        """
        count = timeout / poll_interval
        while count > 0:
            logger.debug('Attempting to add floating IP to instance')
            try:
                self.vm.add_floating_ip(self.floating_ip, port_ip)
                logger.info('Added floating IP to port IP - ' + port_ip)
                return
            except Exception as e:
                logger.warn('Error adding floating IP to instance')
                time.sleep(poll_interval)
                pass
        logger.error('Timeout attempting to add the floating IP to instance.')

    def config_rpm_nics(self):
        """
        Responsible for configuring NICs on RPM systems where the instance has more than one configured port
        :return: None
        """
        if len(self.ports) > 1 and self.vm_active(block=True) and self.vm_ssh_active(block=True):
            for port in self.ports:
                port_index = self.ports.index(port)
                if port_index > 0:
                    nic_name = 'eth' + repr(port_index)
                    self._config_rpm_nic(nic_name, port)
                    logger.info('Configured NIC - ' + nic_name)

    def _config_rpm_nic(self, nic_name, port):
        """
        Although ports/NICs can contain multiple IPs, this code currently only supports the first.

        Your CWD at this point must be the SDN directory.
        TODO - fix this restriction.

        :param nic_name: Name of the interface
        :param port: The port information containing the expected IP values.
        """
        from ansible.playbook import PlayBook
        from ansible.callbacks import AggregateStats
        from ansible.callbacks import PlaybookRunnerCallbacks
        from ansible.callbacks import PlaybookCallbacks
        from ansible import utils
        import jinja2
        from tempfile import NamedTemporaryFile

        ip = port['port']['fixed_ips'][0]['ip_address']

        inventory = """
        [this]
        {{ floating_ip }}

        [this:vars]
        nic_name={{nic_name}}
        nic_ip={{nic_ip}}
        """

        inventory_template = jinja2.Template(inventory)
        rendered_inventory = inventory_template.render({
            'floating_ip': self.floating_ip.ip,
            'nic_name': nic_name,
            'nic_ip': ip
        })

        hosts = NamedTemporaryFile(delete=False)
        hosts.write(rendered_inventory)
        hosts.close()

        stats = AggregateStats()
        run_cb = PlaybookRunnerCallbacks(stats, verbose=utils.VERBOSITY)
        pb_cb = PlaybookCallbacks(verbose=utils.VERBOSITY)

        # TODO - need to find a better means of finding this playbook.
        runner = PlayBook(playbook='../ansible/centos-network-setup/playbooks/configure_host.yml',
                          host_list=hosts.name,
                          remote_user=self.remote_user,
                          private_key_file=self.keypair_creator.keypair_settings.private_filepath,
                          callbacks=pb_cb, runner_callbacks=run_cb, stats=stats)
        data = runner.run()
        if data.get(ip):
            if data[ip]['ok'] > 0:
                logger.info("Configure network status OK - " + repr(data[ip]['ok']))
            if data[ip]['failures'] > 0:
                logger.warn("Configure network status FAILURES - " + repr(data[ip]['failures']))
            if data[ip]['unreachable'] > 0:
                logger.warn("Configure network status UNREACHABLE - " + repr(data[ip]['unreachable']))
        else:
            logger.warn("No status returned for IP in question")

    def vm_active(self, block=False, timeout=VM_BOOT_TIMEOUT, poll_interval=POLL_INTERVAL):
        """
        Returns true when the VM status returns 'ACTIVE'
        :param block: When true, thread will block until active or timeout value in seconds has been exceeded (False)
        :param timeout: The timeout value
        :param poll_interval: The polling interval in seconds
        :return: T/F
        """
        # sleep and wait for VM status change
        count = timeout / poll_interval
        while count > 0:
            if not block:
                count = 0
            status = self._active()
            if status:
                return True
            time.sleep(poll_interval)
            count -= 1
        return False

    def _active(self):
        """
        Returns True when active else False
        :return: T/F
        """
        instance = self.nova.servers.get(self.vm.id)
        if not instance:
            logger.warn('Cannot find instance with id - ' + self.vm.id)
            return False

        if instance.status == 'ERROR':
            raise Exception('Instance had an error during deployment')
        logger.debug('Instance status is - ' + instance.status)
        return instance.status == 'ACTIVE'

    def vm_ssh_active(self, block=False, timeout=VM_BOOT_TIMEOUT, poll_interval=POLL_INTERVAL):
        """
        Returns true when the VM can be accessed via SSH
        :param block: When true, thread will block until active or timeout value in seconds has been exceeded (False)
        :param timeout: The timeout value
        :param poll_interval: The polling interval
        :return: T/F
        """
        # sleep and wait for VM status change
        count = timeout / poll_interval
        while count > 0:
            if not block:
                count = 0
            status = self._ssh_active()
            if status:
                return True
            time.sleep(poll_interval)
            count -= 1
        return False

    def _ssh_active(self):
        """
        Returns True when can create a SSH session else False
        :return: T/F
        """
        ssh = SSHClient()
        ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
        proxy = None
        if self.os_creds.proxy:
            tokens = re.split(':', self.os_creds.proxy)
            proxy = paramiko.ProxyCommand('ssh/corkscrew ' + tokens[0] + ' ' + tokens[1] + ' '
                                          + self.floating_ip.ip + ' 22')

        try:
            ssh.connect(self.floating_ip.ip, username=self.remote_user,
                        key_filename=self.keypair_creator.keypair_settings.private_filepath, sock=proxy)
            return True
        except Exception as e:
            return False
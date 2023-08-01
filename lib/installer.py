##
##

from __future__ import (absolute_import, division, print_function)
__metaclass__ = type

from ansible.executor.task_queue_manager import TaskQueueManager
from ansible.module_utils.common.collections import ImmutableDict
from ansible.inventory.manager import InventoryManager
from ansible.parsing.dataloader import DataLoader
from ansible.playbook.play import Play
from ansible.vars.manager import VariableManager
from ansible import context
from lib.callback import ResultsCollectorJSONCallback


class InstallPackages(object):

    def __init__(self, packages: list[str]):
        self.package_list = packages

    def install(self):
        host_list = ['localhost']
        context.CLIARGS = ImmutableDict(connection='smart', module_path=['/usr/share/ansible'], forks=10, become=None,
                                        become_method=None, become_user=None, check=False, diff=False, verbosity=0)
        sources = ','.join(host_list)
        if len(host_list) == 1:
            sources += ','

        loader = DataLoader()
        passwords = dict(vault_pass='secret')

        results_callback = ResultsCollectorJSONCallback()

        inventory = InventoryManager(loader=loader, sources=sources)

        variable_manager = VariableManager(loader=loader, inventory=inventory)

        tqm = TaskQueueManager(
            inventory=inventory,
            variable_manager=variable_manager,
            loader=loader,
            passwords=passwords,
            stdout_callback=results_callback,
        )

        play_source = dict(
            name="Ansible Play",
            hosts=host_list,
            gather_facts='no',
            tasks=[
                dict(action=dict(module='ansible.builtin.package', args=dict(name=self.package_list, state='latest'))),
            ]
        )

        play = Play().load(play_source, variable_manager=variable_manager, loader=loader)

        try:
            tqm.run(play)
        finally:
            tqm.cleanup()
            if loader:
                loader.cleanup_all_tmp_files()

        print("UP ***********")
        for host, result in results_callback.host_ok.items():
            print('{0} >>> {1}'.format(host, result._result['stdout']))

        print("FAILED *******")
        for host, result in results_callback.host_failed.items():
            print('{0} >>> {1}'.format(host, result._result['msg']))

        print("DOWN *********")
        for host, result in results_callback.host_unreachable.items():
            print('{0} >>> {1}'.format(host, result._result['msg']))

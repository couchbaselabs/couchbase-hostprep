##
##

import csv


class OSRelease(object):

    def __init__(self, filename: str = "/etc/os-release"):
        self.os_release = filename
        self.os_info = {}
        self.os_name = None
        self.os_major_release = None
        self.os_minor_release = None

        self.as_dict()
        self.os_name = self.os_info['ID']
        self.os_major_release = self.os_info['VERSION_ID'].split('.')[0]
        try:
            self.os_minor_release = self.os_info['VERSION_ID'].split('.')[1]
        except IndexError:
            pass

    def as_dict(self):
        with open(self.os_release) as data:
            reader = csv.reader(data, delimiter="=")
            self.os_info = {rows[0]: rows[1] for rows in reader}

    @property
    def os_id(self):
        return self.os_name

    @property
    def major_rel(self):
        return int(self.os_major_release)

    @property
    def minor_rel(self):
        return int(self.os_minor_release)
